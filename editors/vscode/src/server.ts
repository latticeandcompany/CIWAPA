import * as vscode from 'vscode';
import {
	CloseAction,
	DidChangeConfigurationNotification,
	ErrorAction,
	LanguageClient,
	type LanguageClientOptions,
	type ServerOptions
} from 'vscode-languageclient/node';
import { createCrashCounter } from './crashes';
import type { Discovery } from './discovery';
import { installInterstates, serverCrashed, serverDidNotStart, serverMissing, wrongVersion } from './messages';
import { noticeOnce } from './notices';
import type { Politeness, PolitenessDisplay } from './politeness';
import { discover, readSettings, type Settings } from './settings';
import { isInterstates } from './claiming';
import { versionMatches } from './version';

export interface ServerController {
	ready: () => Promise<LanguageClient | undefined>;
	stop: () => Promise<void>;
	discovery: () => Discovery;
	settings: () => Settings;
}

const maxRestarts = 4;
const restartWindowMs = 3 * 60 * 1000;

const isIntercal = (document: vscode.TextDocument): boolean => document.languageId === 'intercal';

export const createServerController = (extensionVersion: string, politeness: PolitenessDisplay): ServerController => {
	let settings = readSettings();
	let found = discover(settings);
	let client: LanguageClient | undefined;
	let starting: Promise<void> | undefined;
	let stopping = false;
	const ioiNotices = vscode.languages.createDiagnosticCollection('intercal-server');

	const refreshIoiNotices = (): void => {
		ioiNotices.clear();
		const server = found.server;
		if (server === undefined || server.speaksInterstates) {
			return;
		}
		for (const document of vscode.workspace.textDocuments) {
			if (isIntercal(document) && document.uri.scheme === 'file' && isInterstates(document.uri.path)) {
				const firstLine = document.lineAt(0).range;
				const diagnostic = new vscode.Diagnostic(firstLine, installInterstates(server.name, settings.flavor), vscode.DiagnosticSeverity.Warning);
				diagnostic.source = 'INTERCAL';
				ioiNotices.set(document.uri, [diagnostic]);
			}
		}
	};

	const createClient = (command: string, name: string): LanguageClient => {
		const crashes = createCrashCounter(maxRestarts, restartWindowMs);
		const serverOptions: ServerOptions = { command, args: ['lsp'] };
		const clientOptions: LanguageClientOptions = {
			documentSelector: [
				{ scheme: 'file', language: 'intercal' },
				{ scheme: 'file', language: 'html' }
			],
			initializationOptions: {
				traditional: settings.traditional,
				clockface: settings.clockface,
				politenessInStatusBar: true
			},
			errorHandler: {
				error: (_error, _message, count) => ({
					action: (count ?? 0) <= 3 ? ErrorAction.Continue : ErrorAction.Shutdown,
					handled: true
				}),
				closed: () => {
					if (stopping || crashes.shouldRestart()) {
						return { action: stopping ? CloseAction.DoNotRestart : CloseAction.Restart, handled: true };
					}
					void noticeOnce('crashed', 'error', serverCrashed(name));
					return { action: CloseAction.DoNotRestart, handled: true };
				}
			}
		};
		const languageClient = new LanguageClient('intercal', 'INTERCAL', serverOptions, clientOptions);
		languageClient.onNotification('intercal/politeness', (params: Politeness) => politeness.update(params));
		return languageClient;
	};

	const start = async (): Promise<void> => {
		const server = found.server;
		if (server === undefined) {
			void noticeOnce('missing', 'error', serverMissing(found.looked, settings.serverPath !== ''));
			return;
		}
		const languageClient = createClient(server.command, server.name);
		client = languageClient;
		try {
			await languageClient.start();
		} catch (error) {
			client = undefined;
			void noticeOnce('missing', 'error', serverDidNotStart(server.name, error instanceof Error ? error.message : String(error)));
			return;
		}
		const serverVersion = languageClient.initializeResult?.serverInfo?.version;
		if (!versionMatches(serverVersion, extensionVersion)) {
			void noticeOnce('version', 'warning', wrongVersion(server.name, serverVersion, extensionVersion));
		}
	};

	const ensureStarted = (): void => {
		if (client === undefined && starting === undefined && vscode.workspace.textDocuments.some(isIntercal)) {
			starting = start().finally(() => {
				starting = undefined;
			});
		}
	};

	const stop = async (): Promise<void> => {
		await starting;
		const running = client;
		client = undefined;
		politeness.clear();
		if (running !== undefined) {
			stopping = true;
			try {
				await running.stop();
			} catch {
				// A server that already died has nothing left to stop.
			} finally {
				stopping = false;
			}
		}
	};

	const restart = async (): Promise<void> => {
		await stop();
		found = discover(settings);
		refreshIoiNotices();
		ensureStarted();
	};

	const subscriptions: vscode.Disposable[] = [
		ioiNotices,
		vscode.workspace.onDidOpenTextDocument(() => {
			refreshIoiNotices();
			ensureStarted();
		}),
		vscode.workspace.onDidCloseTextDocument((document) => ioiNotices.delete(document.uri)),
		vscode.workspace.onDidChangeConfiguration((event) => {
			if (!event.affectsConfiguration('intercal')) {
				return;
			}
			const previous = settings;
			settings = readSettings();
			if (previous.serverPath !== settings.serverPath || previous.flavor !== settings.flavor) {
				void restart();
				return;
			}
			void client?.sendNotification(DidChangeConfigurationNotification.type, {
				settings: { intercal: { traditional: settings.traditional, clockface: settings.clockface } }
			});
		})
	];

	refreshIoiNotices();
	ensureStarted();

	return {
		ready: async () => {
			await starting;
			return client;
		},
		discovery: () => found,
		settings: () => settings,
		stop: async () => {
			subscriptions.forEach((subscription) => subscription.dispose());
			await stop();
		}
	};
};
