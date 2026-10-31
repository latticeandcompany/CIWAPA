package com.latticeandcompany.intercal

import com.intellij.testFramework.fixtures.BasePlatformTestCase

class ClaimsTest : BasePlatformTestCase() {
    override fun getTestDataPath(): String = "src/test/testData"

    fun testTheUnambiguousExtensionsAreAlwaysIntercal() {
        for (extension in listOf("2i", "7i", "3xc", "7xc", "ioi", "2ioi")) {
            val file = myFixture.addFileToProject("anything.$extension", "this is not INTERCAL at all").virtualFile
            assertTrue(".$extension should be INTERCAL", file.isIntercal)
        }
    }

    fun testAnIWithAStatementIsIntercal() {
        assertTrue(myFixture.copyFileToProject("nine.i").isIntercal)
    }

    fun testAStatementWithALabelCounts() {
        assertTrue(Claims.looksLikeIntercal("Some prose first.\n\n(10) PLEASE GIVE UP\n"))
    }

    fun testOnlyTheFirstFiftyLinesAreChecked() {
        assertFalse(Claims.looksLikeIntercal("nothing to see here\n".repeat(50) + "DO GIVE UP\n"))
        assertTrue(Claims.looksLikeIntercal("nothing to see here\n".repeat(49) + "DO GIVE UP\n"))
    }

    fun testDoMustBeAWord() {
        assertFalse(Claims.looksLikeIntercal("DOUBLE trouble\nPLEASED to meet you\n"))
    }

    fun testSwigIsLeftAlone() {
        assertFalse(myFixture.copyFileToProject("swig.i").isIntercal)
        assertFalse(myFixture.addFileToProject("board.xc", "#include <xs1.h>\nint main() { return 0; }\n").virtualFile.isIntercal)
    }

    fun testTheAnswerIsRememberedForThatFile() {
        val swig = myFixture.copyFileToProject("swig.i")
        val other = myFixture.addFileToProject("other.i", "int other;\n").virtualFile
        assertNull(Claims.answer(project, swig))

        Claims.remember(project, swig, asIntercal = true)
        assertEquals(true, Claims.answer(project, swig))
        assertTrue(swig.isIntercal)
        assertNull(Claims.answer(project, other))
        assertFalse(other.isIntercal)

        Claims.remember(project, swig, asIntercal = false)
        assertEquals(false, Claims.answer(project, swig))
        assertFalse(swig.isIntercal)
    }

    fun testIntercalWrittenLaterBeatsARememberedNo() {
        val file = myFixture.addFileToProject("later.i", "").virtualFile
        Claims.remember(project, file, asIntercal = false)
        assertFalse(file.isIntercal)
        com.intellij.openapi.application.WriteAction.runAndWait<Throwable> {
            com.intellij.openapi.vfs.VfsUtil.saveText(file, "PLEASE GIVE UP\n")
        }
        assertTrue(Claims.isClaimed(file))
    }
}
