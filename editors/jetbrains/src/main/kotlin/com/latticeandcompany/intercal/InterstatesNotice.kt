package com.latticeandcompany.intercal

import com.intellij.openapi.fileEditor.FileEditor
import com.intellij.openapi.project.DumbAware
import com.intellij.openapi.project.Project
import com.intellij.openapi.vfs.VirtualFile
import com.intellij.ui.EditorNotificationPanel
import com.intellij.ui.EditorNotificationProvider
import java.util.function.Function
import javax.swing.JComponent

/** With only `ciwapa-*` installed, `.ioi` files would get silence from the server. This says why instead. */
class InterstatesNotice : EditorNotificationProvider, DumbAware {
    override fun collectNotificationData(project: Project, file: VirtualFile): Function<in FileEditor, out JComponent?>? {
        if (!file.isInterstates) return null
        val cli = Cli.find() ?: return null
        if (cli.speaksInterstates) return null
        val ioi = "ioi-${IntercalSettings.getInstance().flavor.id}"
        return Function { editor ->
            EditorNotificationPanel(editor, EditorNotificationPanel.Status.Warning).apply {
                text = "Only ${cli.name} is installed, and it has never heard of Interstates. " +
                    "Install $ioi (the $ioi release archive) for .ioi files."
                createActionLabel("Open INTERCAL settings") { Notices.showSettings(project) }
            }
        }
    }
}
