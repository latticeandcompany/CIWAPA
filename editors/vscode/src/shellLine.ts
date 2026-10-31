type ShellFamily = 'posix' | 'powershell' | 'cmd';

const familyOf = (shell: string): ShellFamily => {
	const name = shell.split(/[\\/]/).pop()?.toLowerCase().replace(/\.exe$/, '') ?? '';
	if (name === 'pwsh' || name === 'powershell') {
		return 'powershell';
	}
	return name === 'cmd' ? 'cmd' : 'posix';
};

const plain = /^[\w@%+=:,./-]+$/;

const quotePosix = (word: string): string => (plain.test(word) ? word : `'${word.replaceAll("'", "'\\''")}'`);

const quotePowershell = (word: string): string => `'${word.replaceAll("'", "''")}'`;

const plainForCmd = /^[\w@%+=:,./\\-]+$/;

const quoteCmd = (word: string): string => (plainForCmd.test(word) ? word : `"${word}"`);

export const shellLine = (shell: string, command: string, args: string[]): string => {
	switch (familyOf(shell)) {
		case 'powershell':
			return ['&', ...[command, ...args].map(quotePowershell)].join(' ');
		case 'cmd':
			return [command, ...args].map(quoteCmd).join(' ');
		case 'posix':
			return [command, ...args].map(quotePosix).join(' ');
	}
};
