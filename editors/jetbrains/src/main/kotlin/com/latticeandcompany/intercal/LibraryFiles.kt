package com.latticeandcompany.intercal

import com.intellij.openapi.application.ApplicationManager
import com.intellij.openapi.components.Service
import com.intellij.openapi.components.service
import com.intellij.openapi.project.Project
import com.intellij.openapi.util.Key
import com.intellij.openapi.vfs.VirtualFile
import com.intellij.platform.ide.progress.runWithModalProgressBlocking
import com.intellij.platform.lsp.api.LspServer
import com.intellij.testFramework.LightVirtualFile
import org.eclipse.lsp4j.services.LanguageServer
import java.util.concurrent.ConcurrentHashMap

/**
 * The system library and EXTRACAL's library, as read-only documents (R6, Q165). Their `ciwapa-lib:` URIs come from the
 * server, and so does their text, through `intercal/librarySource`. Nothing is written to disk.
 */
@Service(Service.Level.PROJECT)
class LibraryFiles(private val project: Project) {
    private val opened = ConcurrentHashMap<String, LightVirtualFile>()

    fun open(uri: String): VirtualFile? {
        opened[uri]?.let { return it }
        val text = fetch(uri) ?: return null
        val file = LightVirtualFile(uri.removePrefix(SCHEME).trimStart('/'), IntercalFileType, text).apply {
            isWritable = false
            putUserData(uriKey, uri)
        }
        return opened.putIfAbsent(uri, file) ?: file
    }

    private fun fetch(uri: String): String? {
        val server = IntercalServers.running(project) ?: return null
        val request = { lsp4j: LanguageServer -> (lsp4j as IntercalLsp4jServer).librarySource(LibrarySourceParams(uri)) }
        val source = if (ApplicationManager.getApplication().isDispatchThread) {
            runWithModalProgressBlocking(project, "Fetching the INTERCAL library") { server.sendRequest(request) }
        } else {
            server.sendRequestSync(LspServer.DEFAULT_REQUEST_TIMEOUT_MS, request)
        }
        return source?.text
    }

    companion object {
        private const val SCHEME = "ciwapa-lib:"
        private val uriKey = Key.create<String>("intercal.libraryUri")

        fun getInstance(project: Project): LibraryFiles = project.service()

        fun isLibraryUri(uri: String): Boolean = uri.startsWith(SCHEME)

        fun uriOf(file: VirtualFile): String? = file.getUserData(uriKey)
    }
}
