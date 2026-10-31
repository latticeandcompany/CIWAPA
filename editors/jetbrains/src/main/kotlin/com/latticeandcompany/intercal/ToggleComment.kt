package com.latticeandcompany.intercal

import com.intellij.openapi.actionSystem.ActionPromoter
import com.intellij.openapi.actionSystem.ActionUpdateThread
import com.intellij.openapi.actionSystem.AnAction
import com.intellij.openapi.actionSystem.AnActionEvent
import com.intellij.openapi.actionSystem.CommonDataKeys
import com.intellij.openapi.actionSystem.DataContext
import com.intellij.openapi.command.WriteCommandAction
import com.intellij.openapi.editor.Document
import com.intellij.openapi.editor.Editor
import com.intellij.openapi.fileEditor.FileDocumentManager
import com.intellij.openapi.project.DumbAwareAction
import com.intellij.platform.ide.progress.runWithModalProgressBlocking
import org.eclipse.lsp4j.Position
import org.eclipse.lsp4j.Range
import org.eclipse.lsp4j.TextEdit

/**
 * Comment with Line Comment, for INTERCAL (R9). The server knows where statements start and end, so it does the work
 * through `intercal/toggleComment`: `DO X` becomes `PLEASE NOTE X`, which never runs, and back again.
 */
class ToggleCommentAction : DumbAwareAction() {
    override fun getActionUpdateThread(): ActionUpdateThread = ActionUpdateThread.BGT

    override fun update(e: AnActionEvent) {
        val file = e.getData(CommonDataKeys.VIRTUAL_FILE)
        e.presentation.isEnabledAndVisible = e.getData(CommonDataKeys.EDITOR) != null && file != null && file.isIntercal
    }

    override fun actionPerformed(e: AnActionEvent) {
        val project = e.project ?: return
        val editor = e.getData(CommonDataKeys.EDITOR) ?: return
        val file = FileDocumentManager.getInstance().getFile(editor.document) ?: return
        val server = IntercalServers.running(project) ?: return Notices.missing(project)
        val document = editor.document
        val stamp = document.modificationStamp
        val identifier = server.getDocumentIdentifier(file)
        val ranges = selectedRanges(editor)
        val edits = runWithModalProgressBlocking(project, "Toggling comments") {
            ranges.flatMap { range ->
                server.sendRequest { (it as IntercalLsp4jServer).toggleComment(ToggleCommentParams(identifier, range)) }.orEmpty()
            }
        }
        if (edits.isEmpty() || document.modificationStamp != stamp) return
        WriteCommandAction.runWriteCommandAction(project, "Comment with Line Comment", null, { apply(document, edits) })
    }

    private fun selectedRanges(editor: Editor): List<Range> = editor.caretModel.allCarets.map { caret ->
        Range(positionOf(editor.document, caret.selectionStart), positionOf(editor.document, caret.selectionEnd))
    }

    /** LSP counts UTF-16 units from the start of the line, which is exactly what a Document's offsets are. */
    private fun positionOf(document: Document, offset: Int): Position {
        val line = document.getLineNumber(offset)
        return Position(line, offset - document.getLineStartOffset(line))
    }

    private fun apply(document: Document, edits: List<TextEdit>) {
        val byOffset = edits.distinct()
            .map { offsetOf(document, it.range.start) to (offsetOf(document, it.range.end) to it.newText) }
            .sortedByDescending { it.first }
        var limit = document.textLength
        for ((start, rest) in byOffset) {
            val (end, text) = rest
            if (end > limit) continue
            document.replaceString(start, end, text)
            limit = start
        }
    }

    private fun offsetOf(document: Document, position: Position): Int {
        val line = position.line.coerceIn(0, maxOf(document.lineCount - 1, 0))
        val lineStart = if (document.lineCount == 0) 0 else document.getLineStartOffset(line)
        val lineEnd = if (document.lineCount == 0) 0 else document.getLineEndOffset(line)
        return (lineStart + position.character).coerceAtMost(lineEnd)
    }
}

/** Lets [ToggleCommentAction] take the comment shortcut in INTERCAL files, and leaves it alone everywhere else. */
class ToggleCommentPromoter : ActionPromoter {
    override fun promote(actions: List<AnAction>, context: DataContext): List<AnAction> =
        actions.filterIsInstance<ToggleCommentAction>()
}
