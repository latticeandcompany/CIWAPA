package com.latticeandcompany.intercal

import com.intellij.execution.configurations.PathEnvironmentVariableUtil
import com.intellij.openapi.util.SystemInfo
import java.nio.file.Files
import java.nio.file.Path

/** A compiler CLI, which is also the language server (`<cli> lsp`) and what Run and Build call. */
data class Cli(val path: Path) {
    val name: String get() = path.fileName.toString().removeSuffix(".exe")

    /** `ciwapa-*` never learned Interstates, so `.ioi` files need `ioi-*`. */
    val speaksInterstates: Boolean get() = !name.startsWith("ciwapa-")

    /** What Run and Build start: `<cli> run <file>` or `<cli> build <file>`, with the settings' compiler flags. */
    fun commandLine(command: String, file: String, traditional: Boolean = false, clockface: Boolean = false): List<String> =
        listOfNotNull(path.toString(), command, file, "--traditional".takeIf { traditional }, "--clockface".takeIf { clockface })

    companion object {
        fun find(settings: IntercalSettings = IntercalSettings.getInstance()): Cli? = find(settings.serverPath, settings.flavor)

        /** The discovery order every INTERCAL extension follows: the setting, then `ioi-<flavor>`, then `ciwapa-<flavor>`. */
        fun find(serverPath: String, flavor: Flavor, onPath: (String) -> Path? = ::onPath): Cli? {
            if (serverPath.isNotEmpty()) {
                val configured = Path.of(serverPath)
                return if (Files.isRegularFile(configured)) Cli(configured) else null
            }
            return (onPath("ioi-${flavor.id}") ?: onPath("ciwapa-${flavor.id}"))?.let(::Cli)
        }

        private fun onPath(name: String): Path? {
            val executable = if (SystemInfo.isWindows) "$name.exe" else name
            return PathEnvironmentVariableUtil.findInPath(executable)?.toPath()
        }
    }
}
