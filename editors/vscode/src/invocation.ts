import { posix, win32 } from 'node:path';

export type CliCommand = 'run' | 'build';

export interface InvocationInput {
	command: CliCommand;
	file: string;
	platform: NodeJS.Platform;
	traditional: boolean;
	clockface: boolean;
}

export const cliArguments = ({ command, file, platform, traditional, clockface }: InvocationInput): string[] => {
	const path = platform === 'win32' ? win32 : posix;
	const parsed = path.parse(file);
	const output = command === 'build' ? ['-o', path.join(parsed.dir, parsed.name)] : [];
	const flags = [...(traditional ? ['--traditional'] : []), ...(clockface ? ['--clockface'] : [])];
	return [command, file, ...output, ...flags];
};
