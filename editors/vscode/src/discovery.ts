import { posix, win32 } from 'node:path';

export type Flavor = 'llvm' | 'dart';

export interface Server {
	command: string;
	name: string;
	speaksInterstates: boolean;
}

export interface DiscoveryInput {
	serverPath: string;
	flavor: Flavor;
	platform: NodeJS.Platform;
	pathVariable: string | undefined;
	isExecutable: (path: string) => boolean;
}

export interface Discovery {
	server?: Server;
	looked: string;
}

const nameOf = (command: string, platform: NodeJS.Platform): string => {
	const base = (platform === 'win32' ? win32 : posix).basename(command);
	return platform === 'win32' ? base.replace(/\.exe$/i, '') : base;
};

const serverAt = (command: string, platform: NodeJS.Platform): Server => {
	const name = nameOf(command, platform);
	return { command, name, speaksInterstates: !name.startsWith('ciwapa-') };
};

export const candidateNames = (flavor: Flavor): string[] => [`ioi-${flavor}`, `ciwapa-${flavor}`];

export const discoverServer = ({ serverPath, flavor, platform, pathVariable, isExecutable }: DiscoveryInput): Discovery => {
	if (serverPath !== '') {
		return isExecutable(serverPath)
			? { server: serverAt(serverPath, platform), looked: serverPath }
			: { looked: serverPath };
	}
	const path = platform === 'win32' ? win32 : posix;
	const directories = (pathVariable ?? '').split(path.delimiter).filter((directory) => directory !== '');
	const executable = platform === 'win32' ? '.exe' : '';
	const names = candidateNames(flavor);
	for (const name of names) {
		for (const directory of directories) {
			const command = path.join(directory, name + executable);
			if (isExecutable(command)) {
				return { server: serverAt(command, platform), looked: names.join(' and ') };
			}
		}
	}
	return { looked: names.join(' and ') };
};
