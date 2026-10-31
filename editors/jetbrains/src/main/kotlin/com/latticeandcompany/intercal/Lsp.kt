package com.latticeandcompany.intercal

import com.intellij.execution.configurations.GeneralCommandLine
import com.intellij.openapi.extensions.PluginAware
import com.intellij.openapi.extensions.PluginDescriptor
import com.intellij.openapi.project.Project
import com.intellij.openapi.vfs.VirtualFile
import com.intellij.platform.lsp.api.Lsp4jClient
import com.intellij.platform.lsp.api.LspServer
import com.intellij.platform.lsp.api.LspServerListener
import com.intellij.platform.lsp.api.LspServerManager
import com.intellij.platform.lsp.api.LspServerNotificationsHandler
import com.intellij.platform.lsp.api.LspServerState
import com.intellij.platform.lsp.api.LspServerSupportProvider
import com.intellij.platform.lsp.api.ProjectWideLspServerDescriptor
import com.intellij.platform.lsp.api.customization.LspCodeLensCustomizer
import com.intellij.platform.lsp.api.customization.LspCodeLensSupport
import com.intellij.platform.lsp.api.customization.LspCustomization
import com.intellij.platform.lsp.api.customization.LspSemanticTokensCustomizer
import com.intellij.platform.lsp.api.customization.LspSemanticTokensSupport
import org.eclipse.lsp4j.DidChangeConfigurationParams
import org.eclipse.lsp4j.InitializeResult
import org.eclipse.lsp4j.Range
import org.eclipse.lsp4j.TextDocumentIdentifier
import org.eclipse.lsp4j.TextEdit
import org.eclipse.lsp4j.jsonrpc.services.JsonNotification
import org.eclipse.lsp4j.jsonrpc.services.JsonRequest
import org.eclipse.lsp4j.services.LanguageServer
import java.util.concurrent.CompletableFuture

class IntercalLspServerSupportProvider : LspServerSupportProvider, PluginAware {
    private var pluginVersion = "unknown"

    override fun setPluginDescriptor(pluginDescriptor: PluginDescriptor) {
        pluginVersion = pluginDescriptor.version
    }

    override fun fileOpened(project: Project, file: VirtualFile, serverStarter: LspServerSupportProvider.LspServerStarter) {
        if (!file.isIntercal) return
        val cli = Cli.find()
        if (cli == null) {
            Notices.missing(project)
            return
        }
        serverStarter.ensureServerStarted(IntercalLspServerDescriptor(project, cli, pluginVersion))
    }
}

class IntercalLspServerDescriptor(project: Project, private val cli: Cli, private val pluginVersion: String) : ProjectWideLspServerDescriptor(project, "INTERCAL") {
    override fun isSupportedFile(file: VirtualFile): Boolean = file.isIntercal || file.isHtml

    override fun getLanguageId(file: VirtualFile): String = if (file.isHtml) "html" else "intercal"

    override fun createCommandLine(): GeneralCommandLine =
        GeneralCommandLine(cli.path.toString(), "lsp")

    override fun createInitializationOptions(): Any =
        IntercalSettings.getInstance().compilerFlags() + ("politenessInStatusBar" to false)

    override fun findFileByUri(fileUri: String): VirtualFile? =
        if (LibraryFiles.isLibraryUri(fileUri)) LibraryFiles.getInstance(project).open(fileUri) else super.findFileByUri(fileUri)

    override fun getFileUri(file: VirtualFile): String = LibraryFiles.uriOf(file) ?: super.getFileUri(file)

    override val lsp4jServerClass: Class<out LanguageServer> = IntercalLsp4jServer::class.java

    override fun createLsp4jClient(handler: LspServerNotificationsHandler): Lsp4jClient = IntercalLsp4jClient(handler)

    override val lspServerListener: LspServerListener = object : LspServerListener {
        override fun serverInitialized(params: InitializeResult) {
            val serverVersion = params.serverInfo?.version
            if (serverVersion != pluginVersion) Notices.wrongVersion(project, cli.name, pluginVersion, serverVersion)
        }

        override fun serverStopped(shutdownNormally: Boolean) {
            if (!shutdownNormally) Notices.crashed(project, cli.name)
        }
    }

    override val lspCustomization: LspCustomization = object : LspCustomization() {
        override val codeLensCustomizer: LspCodeLensCustomizer = LspCodeLensSupport()
        override val semanticTokensCustomizer: LspSemanticTokensCustomizer = LspSemanticTokensSupport()
    }

    private val VirtualFile.isHtml: Boolean get() = extension.equals("html", ignoreCase = true)
}

/** The INTERCAL extensions to LSP, as documented in packages/ciwapa_lsp/README.md. */
interface IntercalLsp4jServer : LanguageServer {
    @JsonRequest("intercal/librarySource")
    fun librarySource(params: LibrarySourceParams): CompletableFuture<LibrarySource>

    @JsonRequest("intercal/toggleComment")
    fun toggleComment(params: ToggleCommentParams): CompletableFuture<List<TextEdit>>
}

data class LibrarySourceParams(val uri: String)

data class LibrarySource(val text: String?)

data class ToggleCommentParams(val textDocument: TextDocumentIdentifier, val range: Range)

class IntercalLsp4jClient(handler: LspServerNotificationsHandler) : Lsp4jClient(handler) {
    /** VS Code shows this in its status bar. Here the server puts the same ratio in an inlay hint instead. */
    @Suppress("unused")
    @JsonNotification("intercal/politeness")
    fun politeness(params: Any?) = Unit
}

object IntercalServers {
    fun running(project: Project): LspServer? =
        LspServerManager.getInstance(project)
            .getServersForProvider(IntercalLspServerSupportProvider::class.java)
            .firstOrNull { it.state == LspServerState.Running }

    fun restart(project: Project) =
        LspServerManager.getInstance(project).stopAndRestartIfNeeded(IntercalLspServerSupportProvider::class.java)

    fun sendSettings(project: Project) {
        val settings = mapOf("intercal" to IntercalSettings.getInstance().compilerFlags())
        running(project)?.sendNotification { it.workspaceService.didChangeConfiguration(DidChangeConfigurationParams(settings)) }
    }
}
