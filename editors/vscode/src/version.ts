export const versionMatches = (serverVersion: string | undefined, extensionVersion: string): boolean =>
	serverVersion === extensionVersion;
