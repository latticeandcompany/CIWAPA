import * as vscode from 'vscode';
import { createClaimer } from './claimer';
import { registerCommands } from './commands';
import { registerLibraryDocuments } from './library';
import { createPolitenessDisplay } from './politeness';
import { createServerController, type ServerController } from './server';

let server: ServerController | undefined;

export const activate = (context: vscode.ExtensionContext): void => {
	const politeness = createPolitenessDisplay();
	server = createServerController(String(context.extension.packageJSON.version), politeness);
	context.subscriptions.push(
		politeness,
		createClaimer(context.workspaceState),
		registerLibraryDocuments(server),
		registerCommands(server)
	);
};

export const deactivate = async (): Promise<void> => {
	await server?.stop();
	server = undefined;
};
