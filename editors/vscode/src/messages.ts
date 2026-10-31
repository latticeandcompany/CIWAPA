export const openSetting = 'Open the serverPath setting';

export const askToClaim = (extension: string): string =>
	`This ${extension} doesn't look like INTERCAL. Open it as INTERCAL anyway?`;

export const claimAnswers = { yes: 'Open as INTERCAL', no: 'Leave it alone' };

export const serverMissing = (looked: string, isSetting: boolean): string =>
	isSetting
		? `intercal.serverPath says the compiler is at ${looked}, but there's nothing there that runs. INTERCAL will have to be read the old-fashioned way.`
		: `Couldn't find ${looked} on your PATH, so there's no INTERCAL language server. Install a CIWAPA release, or point intercal.serverPath at one.`;

export const serverDidNotStart = (name: string, reason: string): string =>
	`${name} lsp didn't start: ${reason}. The compiler is usually more forthcoming than this.`;

export const serverCrashed = (name: string): string =>
	`${name} lsp keeps crashing, so it won't be restarted. Considering what it reads all day, this is understandable.`;

export const wrongVersion = (name: string, serverVersion: string | undefined, extensionVersion: string): string =>
	`${name} is version ${serverVersion ?? 'unknown'}, but this extension is ${extensionVersion}. They ship together and expect to match exactly, so some things may not work. Install matching versions, or point intercal.serverPath at the right one.`;

export const installInterstates = (server: string, flavor: string): string =>
	`${server} doesn't read INTERCAL on Interstates. Install ioi-${flavor} (the ioi-${flavor} release archive) to get help with .ioi files.`;

export const notRunning = 'The INTERCAL language server isn\'t running, so it can\'t help with that.';

export const politenessTooltip = 'How polite this file is. The compiler wants at least a fifth of its statements to say PLEASE, and at most a third.';
