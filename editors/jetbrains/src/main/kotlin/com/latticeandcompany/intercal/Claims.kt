package com.latticeandcompany.intercal

import com.intellij.ide.util.PropertiesComponent
import com.intellij.openapi.fileEditor.FileEditor
import com.intellij.openapi.fileTypes.FileType
import com.intellij.openapi.fileTypes.impl.FileTypeOverrider
import com.intellij.openapi.project.DumbAware
import com.intellij.openapi.project.Project
import com.intellij.openapi.project.ProjectManager
import com.intellij.openapi.util.Key
import com.intellij.openapi.vfs.VirtualFile
import com.intellij.ui.EditorNotificationPanel
import com.intellij.ui.EditorNotificationProvider
import com.intellij.ui.EditorNotifications
import com.intellij.util.FileContentUtilCore
import java.io.IOException
import java.util.function.Function
import javax.swing.JComponent

/** R11: which files are INTERCAL. `.i` and `.xc` are shared with SWIG and XMOS XC, so they have to earn it. */
object Claims {
    val alwaysIntercal: Set<String> =
        (2..7).flatMap { listOf("${it}i", "${it}xc") }.toSet() + setOf("ioi", "2ioi")

    private val ambiguous = setOf("i", "xc")
    private val statement = Regex("""^\s*(\(\d+\)\s*)?(PLEASE|DO)\b""")
    private const val LINES_TO_CHECK = 50
    private const val BYTES_TO_READ = 64 * 1024
    private const val YES = "intercal.claims.yes"
    private const val NO = "intercal.claims.no"
    private val contentCheck = Key.create<Pair<Long, Boolean>>("intercal.claims.contentCheck")

    fun isAmbiguous(file: VirtualFile): Boolean =
        !file.isDirectory && file.extension?.lowercase() in ambiguous

    fun looksLikeIntercal(text: CharSequence): Boolean =
        text.lineSequence().take(LINES_TO_CHECK).any { statement.containsMatchIn(it) }

    fun contentLooksLikeIntercal(file: VirtualFile): Boolean {
        val stamp = file.modificationStamp
        file.getUserData(contentCheck)?.let { (checkedAt, verdict) -> if (checkedAt == stamp) return verdict }
        val verdict = try {
            val bytes = file.inputStream.use { it.readNBytes(BYTES_TO_READ) }
            looksLikeIntercal(String(bytes, Charsets.UTF_8))
        } catch (_: IOException) {
            false
        }
        file.putUserData(contentCheck, stamp to verdict)
        return verdict
    }

    /** The user's answer to "open it as INTERCAL anyway?" in [project], or null if nobody asked yet. */
    fun answer(project: Project, file: VirtualFile): Boolean? {
        val properties = PropertiesComponent.getInstance(project)
        return when (file.url) {
            in properties.getList(YES).orEmpty() -> true
            in properties.getList(NO).orEmpty() -> false
            else -> null
        }
    }

    fun remember(project: Project, file: VirtualFile, asIntercal: Boolean) {
        val properties = PropertiesComponent.getInstance(project)
        val (keep, drop) = if (asIntercal) YES to NO else NO to YES
        properties.setList(keep, properties.getList(keep).orEmpty() + file.url)
        properties.setList(drop, properties.getList(drop).orEmpty() - file.url)
        FileContentUtilCore.reparseFiles(file)
        EditorNotifications.getInstance(project).updateNotifications(file)
        if (asIntercal) IntercalServers.restart(project)
    }

    fun isClaimed(file: VirtualFile): Boolean {
        if (!isAmbiguous(file)) return false
        val answers = ProjectManager.getInstanceIfCreated()?.openProjects.orEmpty()
            .filterNot { it.isDisposed }
            .mapNotNull { answer(it, file) }
        return answers.firstOrNull() ?: contentLooksLikeIntercal(file)
    }
}

class ClaimOverrider : FileTypeOverrider {
    override fun getOverriddenFileType(file: VirtualFile): FileType? =
        if (Claims.isClaimed(file)) IntercalFileType else null
}

class ClaimPrompt : EditorNotificationProvider, DumbAware {
    override fun collectNotificationData(project: Project, file: VirtualFile): Function<in FileEditor, out JComponent?>? {
        if (!Claims.isAmbiguous(file) || file.isIntercal || Claims.answer(project, file) != null) return null
        return Function { editor ->
            EditorNotificationPanel(editor, EditorNotificationPanel.Status.Info).apply {
                text = "This .${file.extension} doesn't look like INTERCAL. Open it as INTERCAL anyway?"
                createActionLabel("Open as INTERCAL") { Claims.remember(project, file, asIntercal = true) }
                createActionLabel("No, it's something sensible") { Claims.remember(project, file, asIntercal = false) }
            }
        }
    }
}
