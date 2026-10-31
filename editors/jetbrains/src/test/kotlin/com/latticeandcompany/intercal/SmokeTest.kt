package com.latticeandcompany.intercal

import com.intellij.lang.annotation.HighlightSeverity
import com.intellij.openapi.actionSystem.IdeActions
import com.intellij.openapi.fileEditor.FileEditorManager
import com.intellij.openapi.util.TextRange
import com.intellij.openapi.util.Disposer
import com.intellij.openapi.vfs.VirtualFile
import com.intellij.platform.lsp.api.LspServer
import com.intellij.platform.lsp.api.LspServerManager
import com.intellij.platform.lsp.api.LspServerManagerListener
import com.intellij.platform.lsp.api.LspServerState
import com.intellij.testFramework.PlatformTestUtil
import com.intellij.testFramework.UsefulTestCase
import com.intellij.testFramework.builders.EmptyModuleFixtureBuilder
import com.intellij.testFramework.fixtures.CodeInsightTestFixture
import com.intellij.testFramework.fixtures.IdeaTestFixtureFactory
import com.intellij.testFramework.fixtures.impl.TempDirTestFixtureImpl
import java.nio.file.Files
import java.nio.file.Path
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * R12's definition of done, headless: open a sample, see the real server's diagnostic, follow a go to definition.
 * The server is the linux binary at .cache/build/ciwapa-llvm, passed in by Gradle as `intercal.server`.
 */
class SmokeTest : UsefulTestCase() {
    private lateinit var fixture: CodeInsightTestFixture

    override fun setUp() {
        super.setUp()
        val factory = IdeaTestFixtureFactory.getFixtureFactory()
        val project = factory.createFixtureBuilder(name)
        fixture = factory.createCodeInsightFixture(project.fixture, TempDirTestFixtureImpl())
        project.addModule(EmptyModuleFixtureBuilder::class.java).addContentRoot(fixture.tempDirPath)
        fixture.testDataPath = Path.of("src/test/testData").toAbsolutePath().toString()
        fixture.setUp()

        val server = System.getProperty("intercal.server").orEmpty()
        assertTrue("No server at '$server'. Build it first (see editors/jetbrains/build.gradle.kts).", Files.isExecutable(Path.of(server)))
        IntercalSettings.getInstance().state.serverPath = server
    }

    override fun tearDown() {
        try {
            IntercalSettings.getInstance().loadState(IntercalState())
            fixture.tearDown()
        } catch (failure: Throwable) {
            addSuppressedException(failure)
        } finally {
            super.tearDown()
        }
    }

    fun testDiagnosticThenDefinition() {
        val file = fixture.copyFileToProject("smoke.i")
        assertTrue(file.isIntercal)
        awaitDiagnostics(file) { fixture.openFileInEditor(file) }

        val errors = fixture.doHighlighting(HighlightSeverity.ERROR)
        assertTrue(
            "Expected E182 from the server, got ${errors.map { it.description }}",
            errors.any { it.description.orEmpty().startsWith("ICL182I") },
        )

        val use = fixture.editor.document.text.indexOf("(1) NEXT") + 1
        fixture.editor.caretModel.moveToOffset(use)
        fixture.performEditorAction(IdeActions.ACTION_GOTO_DECLARATION)
        PlatformTestUtil.waitWithEventsDispatching(
            "Go to definition from (1) NEXT never reached the statement labelled (1)",
            { fixture.editor.caretModel.logicalPosition.line == 1 },
            10,
        )
        assertEquals(0, fixture.editor.caretModel.logicalPosition.column)
    }

    fun testLibraryLabelsOpenReadOnlyLibrarySource() {
        val file = fixture.copyFileToProject("library.i")
        awaitDiagnostics(file) { fixture.openFileInEditor(file) }

        fixture.editor.caretModel.moveToOffset(fixture.editor.document.text.indexOf("(1009)") + 1)
        fixture.performEditorAction(IdeActions.ACTION_GOTO_DECLARATION)
        val editors = FileEditorManager.getInstance(fixture.project)
        PlatformTestUtil.waitWithEventsDispatching(
            "Go to definition from (1009) NEXT never opened the system library",
            { editors.selectedTextEditor?.virtualFile?.let(LibraryFiles::uriOf) != null },
            10,
        )
        val library = editors.selectedTextEditor!!
        val libraryFile = library.virtualFile!!
        assertEquals("ciwapa-lib:/syslib.i", LibraryFiles.uriOf(libraryFile))
        assertFalse(libraryFile.isWritable)
        assertFalse(libraryFile.isInLocalFileSystem)
        val line = library.document.getText(
            TextRange(library.document.getLineStartOffset(library.caretModel.logicalPosition.line), library.document.getLineEndOffset(library.caretModel.logicalPosition.line)),
        )
        assertTrue("The caret should be on the statement labelled (1009), not on '$line'", line.startsWith("(1009)"))
    }

    private fun awaitDiagnostics(target: VirtualFile, open: () -> Unit) {
        val received = AtomicInteger()
        val stopped = AtomicBoolean()
        val listening = Disposer.newDisposable()
        try {
            LspServerManager.getInstance(fixture.project).addLspServerManagerListener(
                object : LspServerManagerListener {
                    override fun diagnosticsReceived(lspServer: LspServer, file: VirtualFile) {
                        if (file == target) received.incrementAndGet()
                    }

                    override fun serverStateChanged(lspServer: LspServer) {
                        if (lspServer.state == LspServerState.ShutdownUnexpectedly) stopped.set(true)
                    }
                },
                listening,
                true,
            )
            open()
            PlatformTestUtil.waitWithEventsDispatching(
                "No diagnostics from the server for ${target.name} within 30 seconds",
                { received.get() > 0 || stopped.get() },
                30,
            )
            assertFalse("The server stopped unexpectedly", stopped.get())
        } finally {
            Disposer.dispose(listening)
        }
    }
}
