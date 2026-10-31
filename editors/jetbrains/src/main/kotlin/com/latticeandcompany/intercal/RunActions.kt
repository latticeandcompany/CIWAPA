package com.latticeandcompany.intercal

import com.intellij.execution.ExecutionException
import com.intellij.execution.RunContentExecutor
import com.intellij.execution.configurations.GeneralCommandLine
import com.intellij.execution.process.KillableColoredProcessHandler
import com.intellij.execution.process.ProcessTerminatedListener
import com.intellij.notification.NotificationGroupManager
import com.intellij.notification.NotificationType
import com.intellij.openapi.actionSystem.ActionUpdateThread
import com.intellij.openapi.actionSystem.AnActionEvent
import com.intellij.openapi.actionSystem.CommonDataKeys
import com.intellij.openapi.fileEditor.FileDocumentManager
import com.intellij.openapi.project.DumbAwareAction
import com.intellij.openapi.project.Project
import com.intellij.openapi.vfs.VirtualFile

/** R13: Run this file and Build this file, which are `<cli> run <file>` and `<cli> build <file>` in the Run tool window. */
sealed class CliFileAction(private val command: String) : DumbAwareAction() {
    override fun getActionUpdateThread(): ActionUpdateThread = ActionUpdateThread.BGT

    override fun update(e: AnActionEvent) {
        val file = e.getData(CommonDataKeys.VIRTUAL_FILE)
        e.presentation.isEnabledAndVisible = file != null && file.isInLocalFileSystem && file.isIntercal
    }

    override fun actionPerformed(e: AnActionEvent) {
        val project = e.project ?: return
        val file = e.getData(CommonDataKeys.VIRTUAL_FILE) ?: return
        val cli = Cli.find() ?: return complain(project, "No INTERCAL compiler found", "Install a CIWAPA release, or point the INTERCAL settings at one.")
        FileDocumentManager.getInstance().getDocument(file)?.let { FileDocumentManager.getInstance().saveDocument(it) }
        start(project, cli, file)
    }

    private fun start(project: Project, cli: Cli, file: VirtualFile) {
        val settings = IntercalSettings.getInstance()
        val commandLine = GeneralCommandLine(cli.commandLine(command, file.path, settings.traditional, settings.clockface))
            .withWorkingDirectory(file.parent.toNioPath())
        val handler = try {
            KillableColoredProcessHandler(commandLine)
        } catch (failure: ExecutionException) {
            return complain(project, "Couldn't start ${cli.name}", failure.message ?: "It wouldn't say why.")
        }
        ProcessTerminatedListener.attach(handler)
        RunContentExecutor(project, handler)
            .withTitle("${cli.name} $command ${file.name}")
            .withRerun { start(project, cli, file) }
            .withActivateToolWindow(true)
            .run()
    }

    private fun complain(project: Project, title: String, content: String) {
        NotificationGroupManager.getInstance()
            .getNotificationGroup("INTERCAL")
            .createNotification(title, content, NotificationType.ERROR)
            .addAction(Notices.openSettings())
            .notify(project)
    }
}

class RunFileAction : CliFileAction("run")

class BuildFileAction : CliFileAction("build")
