import { accessSync, constants, statSync } from 'node:fs';
import * as vscode from 'vscode';
import { type Discovery, discoverServer, type Flavor } from './discovery';

export interface Settings {
	serverPath: string;
	flavor: Flavor;
	traditional: boolean;
	clockface: boolean;
}

export const readSettings = (): Settings => {
	const config = vscode.workspace.getConfiguration('intercal');
	return {
		serverPath: config.get<string>('serverPath', '').trim(),
		flavor: config.get<string>('flavor') === 'dart' ? 'dart' : 'llvm',
		traditional: config.get<boolean>('traditional', false),
		clockface: config.get<boolean>('clockface', false)
	};
};

const isExecutable = (path: string): boolean => {
	try {
		accessSync(path, constants.X_OK);
		return statSync(path).isFile();
	} catch {
		return false;
	}
};

export const discover = (settings: Settings): Discovery =>
	discoverServer({
		serverPath: settings.serverPath,
		flavor: settings.flavor,
		platform: process.platform,
		pathVariable: process.env['PATH'],
		isExecutable
	});

export const openServerPathSetting = async (): Promise<void> => {
	await vscode.commands.executeCommand('workbench.action.openSettings', 'intercal.serverPath');
};
