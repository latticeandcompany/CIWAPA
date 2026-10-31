import * as vscode from 'vscode';
import { notRunning } from './messages';
import type { ServerController } from './server';

export const libraryScheme = 'ciwapa-lib';

interface LibrarySource {
	text: string;
}

export const registerLibraryDocuments = (server: ServerController): vscode.Disposable =>
	vscode.workspace.registerTextDocumentContentProvider(libraryScheme, {
		provideTextDocumentContent: async (uri) => {
			const client = await server.ready();
			if (client === undefined) {
				throw new Error(notRunning);
			}
			const source = await client.sendRequest<LibrarySource>('intercal/librarySource', { uri: uri.toString() });
			return source.text;
		}
	});
