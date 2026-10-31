import * as vscode from 'vscode';
import { openServerPathSetting } from './settings';
import { openSetting } from './messages';

const shown = new Set<string>();

export const noticeOnce = async (kind: string, severity: 'error' | 'warning', message: string): Promise<void> => {
	if (shown.has(kind)) {
		return;
	}
	shown.add(kind);
	const show = severity === 'error' ? vscode.window.showErrorMessage : vscode.window.showWarningMessage;
	if ((await show(message, openSetting)) === openSetting) {
		await openServerPathSetting();
	}
};
