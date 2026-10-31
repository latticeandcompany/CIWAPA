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

    companion object {
        /** The discovery order every INTERCAL extension follows: the setting, then `ioi-<flavor>`, then `ciwapa-<flavor>`. */
        fun find(settings: IntercalSettings = IntercalSettings.getInstance()): Cli? {
            if (settings.serverPath.isNotEmpty()) {
                val configured = Path.of(settings.serverPath)
                return if (Files.isRegularFile(configured)) Cli(configured) else null
            }
            return (onPath("ioi-${settings.flavor.id}") ?: onPath("ciwapa-${settings.flavor.id}"))?.let(::Cli)
        }

        private fun onPath(name: String): Path? {
            val executable = if (SystemInfo.isWindows) "$name.exe" else name
            return PathEnvironmentVariableUtil.findInPath(executable)?.toPath()
        }
    }
}
