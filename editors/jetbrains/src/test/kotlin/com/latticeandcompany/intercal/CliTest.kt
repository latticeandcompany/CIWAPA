package com.latticeandcompany.intercal

import com.intellij.openapi.keymap.KeymapManager
import com.intellij.testFramework.fixtures.BasePlatformTestCase
import java.nio.file.Files
import java.nio.file.Path

class CliTest : BasePlatformTestCase() {
    private fun onPath(vararg names: String): (String) -> Path? = { name -> if (name in names) Path.of("/bin/$name") else null }

    fun testIoiBeatsCiwapa() {
        assertEquals("ioi-llvm", Cli.find("", Flavor.LLVM, onPath("ciwapa-llvm", "ioi-llvm"))?.name)
    }

    fun testCiwapaWhenItIsAllThereIs() {
        assertEquals("ciwapa-llvm", Cli.find("", Flavor.LLVM, onPath("ciwapa-llvm", "ioi-dart"))?.name)
    }

    fun testTheFlavorPicksTheCli() {
        assertEquals("ciwapa-dart", Cli.find("", Flavor.DART, onPath("ioi-llvm", "ciwapa-dart"))?.name)
    }

    fun testNothingOnPathFindsNothing() {
        assertNull(Cli.find("", Flavor.LLVM, onPath()))
    }

    fun testServerPathWinsAndMustExist() {
        val server = Files.createTempFile("my-server", "")
        try {
            assertEquals(server, Cli.find(server.toString(), Flavor.LLVM, onPath("ioi-llvm"))?.path)
            assertTrue(Cli(server).speaksInterstates)
        } finally {
            Files.delete(server)
        }
        assertNull(Cli.find(server.toString(), Flavor.LLVM, onPath("ioi-llvm")))
    }

    fun testOnlyIoiSpeaksInterstates() {
        assertFalse(Cli(Path.of("/bin/ciwapa-llvm")).speaksInterstates)
        assertTrue(Cli(Path.of("/bin/ioi-dart.exe")).speaksInterstates)
        assertEquals("ioi-dart", Cli(Path.of("/bin/ioi-dart.exe")).name)
    }

    fun testRunAndBuildCallTheCli() {
        val cli = Cli(Path.of("/bin/ioi-dart"))
        assertEquals(listOf("/bin/ioi-dart", "run", "/w/a.i"), cli.commandLine("run", "/w/a.i"))
        assertEquals(listOf("/bin/ioi-dart", "build", "/w/a.i"), cli.commandLine("build", "/w/a.i"))
        assertEquals(
            listOf("/bin/ioi-dart", "run", "/w/a.i", "--traditional", "--clockface"),
            cli.commandLine("run", "/w/a.i", traditional = true, clockface = true),
        )
    }

    fun testToggleCommentHasTheCommentShortcut() {
        val keymap = KeymapManager.getInstance().activeKeymap
        val comment = keymap.getShortcuts("CommentByLineComment").toList()
        assertFalse(comment.isEmpty())
        assertEquals(comment, keymap.getShortcuts("Intercal.ToggleComment").toList())
    }
}
