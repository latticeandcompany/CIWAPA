package com.latticeandcompany.intercal

import com.intellij.notification.NotificationAction
import com.intellij.notification.NotificationGroupManager
import com.intellij.notification.NotificationType
import com.intellij.openapi.options.ShowSettingsUtil
import com.intellij.openapi.project.Project
import java.util.concurrent.ConcurrentHashMap

/** The three ways the server can let you down. Each is announced once per IDE session, which is plenty. */
enum class Trouble {
    MISSING,
    CRASHED,
    WRONG_VERSION,
}

object Notices {
    private val alreadySaid = ConcurrentHashMap.newKeySet<Trouble>()

    fun missing(project: Project) {
        val flavor = IntercalSettings.getInstance().flavor.id
        say(
            project,
            Trouble.MISSING,
            "No INTERCAL compiler found",
            "Looked for ioi-$flavor and ciwapa-$flavor on your PATH and found neither, which is the most " +
                "sensible outcome INTERCAL has to offer. Install a CIWAPA release, or point the INTERCAL settings at one.",
        )
    }

    fun crashed(project: Project, cli: String) = say(
        project,
        Trouble.CRASHED,
        "The INTERCAL language server crashed",
        "$cli lsp stopped without saying goodbye. If it keeps happening, check which binary the INTERCAL settings point at.",
    )

    fun wrongVersion(project: Project, cli: String, pluginVersion: String, serverVersion: String?) = say(
        project,
        Trouble.WRONG_VERSION,
        "INTERCAL versions disagree",
        "This plugin is version $pluginVersion, but $cli is version ${serverVersion ?: "(it wouldn't say)"}. " +
            "They ship together and expect to match exactly. Install matching versions, or point the INTERCAL settings at the right binary.",
    )

    private fun say(project: Project, trouble: Trouble, title: String, content: String) {
        if (!alreadySaid.add(trouble)) return
        NotificationGroupManager.getInstance()
            .getNotificationGroup("INTERCAL")
            .createNotification(title, content, NotificationType.WARNING)
            .addAction(openSettings())
            .notify(project)
    }

    fun openSettings(): NotificationAction =
        NotificationAction.create("Open INTERCAL settings") { event, _ -> showSettings(event.project) }

    fun showSettings(project: Project?) =
        ShowSettingsUtil.getInstance().showSettingsDialog(project, IntercalConfigurable::class.java)
}
