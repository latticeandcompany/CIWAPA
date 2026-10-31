package com.latticeandcompany.intercal

import com.intellij.notification.Notification
import com.intellij.notification.Notifications
import com.intellij.testFramework.fixtures.BasePlatformTestCase
import org.eclipse.lsp4j.InitializeResult
import org.eclipse.lsp4j.ServerCapabilities
import org.eclipse.lsp4j.ServerInfo
import java.nio.file.Path

class VersionTest : BasePlatformTestCase() {
    fun testAMismatchedServerIsSaidOnce() {
        val said = mutableListOf<Notification>()
        project.messageBus.connect(testRootDisposable).subscribe(
            Notifications.TOPIC,
            object : Notifications {
                override fun notify(notification: Notification) {
                    said.add(notification)
                }
            },
        )
        val descriptor = IntercalLspServerDescriptor(project, Cli(Path.of("/bin/ioi-llvm")), "0.0.0")
        fun initialized(version: String) =
            descriptor.lspServerListener.serverInitialized(InitializeResult(ServerCapabilities(), ServerInfo("ioi-llvm", version)))

        initialized("0.0.0")
        assertEmpty(said)
        initialized("9.9.9")
        initialized("9.9.9")
        assertEquals(1, said.size)
        assertTrue(said.single().content.contains("ioi-llvm is version 9.9.9"))
    }
}
