import { dirname } from 'node:path';
import * as vscode from 'vscode';
import type { TextEdit } from 'vscode-languageclient/node';
import { isInterstates } from './claiming';
import { type CliCommand, cliArguments } from './invocation';
import { installInterstates, notRunning, serverMissing } from './messages';
import { noticeOnce } from './notices';
import type { ServerController } from './server';
import { shellLine } from './shellLine';

const toggleComment = async (server: ServerController): Promise<void> => {
	const editor = vscode.window.activeTextEditor;
	if (editor === undefined || editor.document.languageId !== 'intercal' || editor.document.uri.scheme !== 'file') {
		return;
	}
	const client = await server.ready();
	if (client === undefined) {
		void vscode.window.showWarningMessage(notRunning);
		return;
	}
	const { document } = editor;
	const uri = client.code2ProtocolConverter.asUri(document.uri);
	const replies = await Promise.all(
		editor.selections.map((selection) =>
			client.sendRequest<TextEdit[] | null>('intercal/toggleComment', {
				textDocument: { uri },
				range: client.code2ProtocolConverter.asRange(selection)
			})
		)
	);
	const unique = new Map<string, TextEdit>();
	for (const edit of replies.flatMap((reply) => reply ?? [])) {
		unique.set(JSON.stringify(edit), edit);
	}
	const edits = await client.protocol2CodeConverter.asTextEdits([...unique.values()]);
	if (edits === undefined || edits.length === 0) {
		return;
	}
	await editor.edit((builder) => edits.forEach((edit) => builder.replace(edit.range, edit.newText)));
};

let terminal: vscode.Terminal | undefined;

const runCli = async (server: ServerController, command: CliCommand, target?: vscode.Uri): Promise<void> => {
	const uri = target ?? vscode.window.activeTextEditor?.document.uri;
	if (uri === undefined || uri.scheme !== 'file') {
		return;
	}
	const document = vscode.workspace.textDocuments.find((open) => open.uri.toString() === uri.toString());
	if (document?.isDirty === true) {
		await document.save();
	}
	const { server: cli, looked } = server.discovery();
	const settings = server.settings();
	if (cli === undefined) {
		void noticeOnce('missing', 'error', serverMissing(looked, settings.serverPath !== ''));
		return;
	}
	if (!cli.speaksInterstates && isInterstates(uri.fsPath)) {
		void vscode.window.showWarningMessage(installInterstates(cli.name, settings.flavor));
		return;
	}
	const args = cliArguments({ command, file: uri.fsPath, platform: process.platform, ...settings });
	// A fresh terminal each time: the last program may still be waiting at a WRITE IN, and would read
	// the next command line as its input.
	terminal?.dispose();
	terminal = vscode.window.createTerminal({ name: 'INTERCAL', cwd: dirname(uri.fsPath) });
	terminal.show();
	terminal.sendText(shellLine(vscode.env.shell, cli.command, args));
};

export const registerCommands = (server: ServerController): vscode.Disposable =>
	vscode.Disposable.from(
		vscode.commands.registerCommand('intercal.toggleComment', () => toggleComment(server)),
		vscode.commands.registerCommand('intercal.run', (uri?: vscode.Uri) => runCli(server, 'run', uri)),
		vscode.commands.registerCommand('intercal.build', (uri?: vscode.Uri) => runCli(server, 'build', uri))
	);
