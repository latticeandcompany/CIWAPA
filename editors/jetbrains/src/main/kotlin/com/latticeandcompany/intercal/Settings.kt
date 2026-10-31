package com.latticeandcompany.intercal

import com.intellij.openapi.components.BaseState
import com.intellij.openapi.components.Service
import com.intellij.openapi.components.SimplePersistentStateComponent
import com.intellij.openapi.components.State
import com.intellij.openapi.components.Storage
import com.intellij.openapi.components.service
import com.intellij.openapi.fileChooser.FileChooserDescriptorFactory
import com.intellij.openapi.options.BoundConfigurable
import com.intellij.openapi.project.ProjectManager
import com.intellij.openapi.ui.DialogPanel
import com.intellij.ui.EditorNotifications
import com.intellij.ui.dsl.builder.AlignX
import com.intellij.ui.dsl.builder.bindItem
import com.intellij.ui.dsl.builder.bindSelected
import com.intellij.ui.dsl.builder.bindText
import com.intellij.ui.dsl.builder.panel
import com.intellij.ui.dsl.listCellRenderer.textListCellRenderer

enum class Flavor(val id: String) {
    LLVM("llvm"),
    DART("dart"),
}

class IntercalState : BaseState() {
    var serverPath by string("")
    var flavor by enum(Flavor.LLVM)
    var traditional by property(false)
    var clockface by property(false)
}

@Service(Service.Level.APP)
@State(name = "IntercalSettings", storages = [Storage("intercal.xml")])
class IntercalSettings : SimplePersistentStateComponent<IntercalState>(IntercalState()) {
    val serverPath: String get() = state.serverPath.orEmpty().trim()
    val flavor: Flavor get() = state.flavor
    val traditional: Boolean get() = state.traditional
    val clockface: Boolean get() = state.clockface

    /** What the server reads from initializationOptions and didChangeConfiguration. */
    fun compilerFlags(): Map<String, Boolean> = mapOf("traditional" to traditional, "clockface" to clockface)

    companion object {
        fun getInstance(): IntercalSettings = service()
    }
}

class IntercalConfigurable : BoundConfigurable("INTERCAL") {
    private val settings = IntercalSettings.getInstance()

    override fun createPanel(): DialogPanel = panel {
        group("Language Server") {
            row("Server path:") {
                textFieldWithBrowseButton(FileChooserDescriptorFactory.singleFile().withTitle("Choose ciwapa-* or ioi-*"))
                    .bindText({ settings.state.serverPath.orEmpty() }, { settings.state.serverPath = it.trim() })
                    .align(AlignX.FILL)
                    .comment("Leave empty to look for ioi-&lt;flavor&gt;, then ciwapa-&lt;flavor&gt;, on your PATH.")
            }
            row("Flavor:") {
                comboBox(Flavor.entries, textListCellRenderer { it?.id })
                    .bindItem({ settings.state.flavor }, { settings.state.flavor = it ?: Flavor.LLVM })
                    .comment("Which compiler runs the server and the Run and Build actions. Both disappoint equally.")
            }
        }
        group("Compiler Flags") {
            row {
                checkBox("--traditional")
                    .bindSelected({ settings.state.traditional }, { settings.state.traditional = it })
                    .comment("Diagnose as C-INTERCAL's traditional mode would.")
            }
            row {
                checkBox("--clockface")
                    .bindSelected({ settings.state.clockface }, { settings.state.clockface = it })
                    .comment("IIII instead of IV, as on clocks. It changes the output, never the errors.")
            }
        }
    }

    override fun apply() {
        val before = settings.state.copyForComparison()
        super.apply()
        val after = settings.state.copyForComparison()
        if (before == after) return
        for (project in ProjectManager.getInstance().openProjects) {
            if (before.server != after.server) IntercalServers.restart(project) else IntercalServers.sendSettings(project)
            EditorNotifications.getInstance(project).updateAllNotifications()
        }
    }

    private data class Snapshot(val server: Pair<String, Flavor>, val flags: Pair<Boolean, Boolean>)

    private fun IntercalState.copyForComparison() =
        Snapshot(serverPath.orEmpty().trim() to flavor, traditional to clockface)
}
