import * as vscode from 'vscode';

const pollMs = 250;

const waitFor = async <T>(what: string, timeoutMs: number, probe: () => T | undefined | Promise<T | undefined>): Promise<T> => {
	const deadline = Date.now() + timeoutMs;
	while (Date.now() < deadline) {
		const value = await probe();
		if (value !== undefined) {
			return value;
		}
		await new Promise((resolve) => setTimeout(resolve, pollMs));
	}
	throw new Error(`Timed out after ${timeoutMs / 1000}s waiting for ${what}.`);
};

const targetOf = (location: vscode.Location | vscode.LocationLink): vscode.Location =>
	'targetUri' in location
		? new vscode.Location(location.targetUri, location.targetSelectionRange ?? location.targetRange)
		: location;

export const run = async (): Promise<void> => {
	const folder = vscode.workspace.workspaceFolders?.[0];
	if (folder === undefined) {
		throw new Error('The smoke workspace did not open.');
	}
	const uri = vscode.Uri.joinPath(folder.uri, 'sample.i');
	await vscode.window.showTextDocument(await vscode.workspace.openTextDocument(uri));
	console.log('ok: opened sample.i');

	const document = await waitFor('sample.i to be claimed as INTERCAL', 15_000, () =>
		vscode.workspace.textDocuments.find((open) => open.uri.toString() === uri.toString() && open.languageId === 'intercal')
	);
	console.log('ok: sample.i is INTERCAL');

	const errors = await waitFor('an error diagnostic from the server', 30_000, () => {
		const found = vscode.languages.getDiagnostics(uri).filter((diagnostic) => diagnostic.severity === vscode.DiagnosticSeverity.Error);
		return found.length > 0 ? found : undefined;
	});
	for (const error of errors) {
		console.log(`ok: diagnostic on line ${error.range.start.line + 1}: ${error.message.split('\n')[0]}`);
	}

	const firstLine = document.lineAt(0).text;
	const use = new vscode.Position(0, firstLine.indexOf('(1)') + 1);
	const definition = await waitFor('go to definition from (1) NEXT to the statement labelled (1)', 20_000, async () => {
		const locations = await vscode.commands.executeCommand<(vscode.Location | vscode.LocationLink)[] | undefined>(
			'vscode.executeDefinitionProvider',
			uri,
			use
		);
		return (locations ?? []).map(targetOf).find((location) => location.uri.toString() === uri.toString() && location.range.start.line === 2);
	});
	console.log(`ok: (1) NEXT goes to line ${definition.range.start.line + 1}: ${document.lineAt(definition.range.start.line).text.trim()}`);
};
