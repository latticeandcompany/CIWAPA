import { describe, expect, test } from '@jest/globals';
import { shellLine } from '../src/shellLine';

describe('shellLine', () => {
	test('POSIX shells leave plain words alone', () => {
		expect(shellLine('/bin/bash', '/usr/bin/ioi-llvm', ['run', '/home/me/hello.ioi'])).toBe('/usr/bin/ioi-llvm run /home/me/hello.ioi');
	});

	test('POSIX shells single-quote the rest, quotes included', () => {
		expect(shellLine('/usr/bin/zsh', '/opt/my tools/ciwapa-llvm', ['run', "/home/me/it's here.i"])).toBe(
			"'/opt/my tools/ciwapa-llvm' run '/home/me/it'\\''s here.i'"
		);
	});

	test('PowerShell calls the command with & and doubles single quotes', () => {
		expect(shellLine('C:\\Program Files\\PowerShell\\7\\pwsh.exe', 'C:\\ciwapa\\ciwapa-llvm.exe', ['build', "C:\\src\\o'clock.i"])).toBe(
			"& 'C:\\ciwapa\\ciwapa-llvm.exe' 'build' 'C:\\src\\o''clock.i'"
		);
		expect(shellLine('powershell.exe', 'a', ['b'])).toBe("& 'a' 'b'");
	});

	test('cmd double-quotes words with spaces', () => {
		expect(shellLine('C:\\Windows\\System32\\cmd.exe', 'C:\\ciwapa\\ciwapa-llvm.exe', ['run', 'C:\\My Programs\\a.i'])).toBe(
			'C:\\ciwapa\\ciwapa-llvm.exe run "C:\\My Programs\\a.i"'
		);
	});
});
