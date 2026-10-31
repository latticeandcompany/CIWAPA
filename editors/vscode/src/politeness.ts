import * as vscode from 'vscode';
import { politenessTooltip } from './messages';

export interface Politeness {
	uri: string;
	polite: number;
	total: number;
	text: string;
}

export interface PolitenessDisplay extends vscode.Disposable {
	update: (politeness: Politeness) => void;
	clear: () => void;
}

export const createPolitenessDisplay = (): PolitenessDisplay => {
	const item = vscode.window.createStatusBarItem('intercal.politeness', vscode.StatusBarAlignment.Right, 100);
	item.name = 'INTERCAL politeness';
	item.tooltip = politenessTooltip;
	const texts = new Map<string, string>();

	const refresh = (): void => {
		const document = vscode.window.activeTextEditor?.document;
		const text = document?.languageId === 'intercal' ? texts.get(document.uri.toString()) : undefined;
		if (!text) {
			item.hide();
			return;
		}
		item.text = text;
		item.show();
	};

	const subscriptions = [
		item,
		vscode.window.onDidChangeActiveTextEditor(refresh),
		vscode.workspace.onDidCloseTextDocument((document) => {
			texts.delete(document.uri.toString());
			refresh();
		})
	];

	return {
		update: (politeness) => {
			texts.set(vscode.Uri.parse(politeness.uri).toString(), politeness.text);
			refresh();
		},
		clear: () => {
			texts.clear();
			refresh();
		},
		dispose: () => subscriptions.forEach((subscription) => subscription.dispose())
	};
};
