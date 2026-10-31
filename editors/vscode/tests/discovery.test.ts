import { describe, expect, test } from '@jest/globals';
import { discoverServer, type DiscoveryInput } from '../src/discovery';

const onDisk = (...paths: string[]) => (path: string) => paths.includes(path);

const input = (overrides: Partial<DiscoveryInput>): DiscoveryInput => ({
	serverPath: '',
	flavor: 'llvm',
	platform: 'linux',
	pathVariable: '/usr/local/bin:/opt/ciwapa/bin:/usr/bin',
	isExecutable: onDisk(),
	...overrides
});

describe('discoverServer', () => {
	test('serverPath wins over everything on PATH', () => {
		const found = discoverServer(input({ serverPath: '/home/me/ciwapa-dart', isExecutable: onDisk('/home/me/ciwapa-dart', '/usr/bin/ioi-llvm') }));
		expect(found.server).toEqual({ command: '/home/me/ciwapa-dart', name: 'ciwapa-dart', speaksInterstates: false });
	});

	test('a serverPath that is not there finds nothing, rather than quietly using PATH', () => {
		const found = discoverServer(input({ serverPath: '/nowhere/ioi-llvm', isExecutable: onDisk('/usr/bin/ioi-llvm') }));
		expect(found).toEqual({ looked: '/nowhere/ioi-llvm' });
	});

	test('a serverPath with an unfamiliar name is trusted with .ioi files', () => {
		const found = discoverServer(input({ serverPath: '/opt/my-server', isExecutable: onDisk('/opt/my-server') }));
		expect(found.server?.speaksInterstates).toBe(true);
	});

	test('ioi-<flavor> beats ciwapa-<flavor>, even later on PATH', () => {
		const found = discoverServer(input({ isExecutable: onDisk('/usr/local/bin/ciwapa-llvm', '/usr/bin/ioi-llvm') }));
		expect(found.server).toEqual({ command: '/usr/bin/ioi-llvm', name: 'ioi-llvm', speaksInterstates: true });
	});

	test('ciwapa-<flavor> when it is all there is', () => {
		const found = discoverServer(input({ isExecutable: onDisk('/opt/ciwapa/bin/ciwapa-llvm') }));
		expect(found.server).toEqual({ command: '/opt/ciwapa/bin/ciwapa-llvm', name: 'ciwapa-llvm', speaksInterstates: false });
	});

	test('the first match on PATH wins', () => {
		const found = discoverServer(input({ isExecutable: onDisk('/opt/ciwapa/bin/ioi-llvm', '/usr/bin/ioi-llvm') }));
		expect(found.server?.command).toBe('/opt/ciwapa/bin/ioi-llvm');
	});

	test('the flavor picks which compilers to look for', () => {
		const disk = onDisk('/usr/bin/ioi-llvm', '/usr/bin/ciwapa-dart');
		expect(discoverServer(input({ flavor: 'dart', isExecutable: disk })).server?.name).toBe('ciwapa-dart');
		expect(discoverServer(input({ flavor: 'llvm', isExecutable: disk })).server?.name).toBe('ioi-llvm');
	});

	test('nothing found says what it looked for', () => {
		expect(discoverServer(input({}))).toEqual({ looked: 'ioi-llvm and ciwapa-llvm' });
		expect(discoverServer(input({ pathVariable: undefined }))).toEqual({ looked: 'ioi-llvm and ciwapa-llvm' });
	});

	test('Windows: .exe, semicolons and backslashes', () => {
		const found = discoverServer(
			input({
				platform: 'win32',
				pathVariable: 'C:\\Windows;C:\\Tools\\ciwapa\\bin',
				isExecutable: onDisk('C:\\Tools\\ciwapa\\bin\\ciwapa-llvm.exe')
			})
		);
		expect(found.server).toEqual({ command: 'C:\\Tools\\ciwapa\\bin\\ciwapa-llvm.exe', name: 'ciwapa-llvm', speaksInterstates: false });
	});

	test('Windows: a serverPath to ioi-dart.exe speaks Interstates', () => {
		const found = discoverServer(input({ platform: 'win32', serverPath: 'D:\\ioi\\bin\\ioi-dart.exe', isExecutable: onDisk('D:\\ioi\\bin\\ioi-dart.exe') }));
		expect(found.server).toEqual({ command: 'D:\\ioi\\bin\\ioi-dart.exe', name: 'ioi-dart', speaksInterstates: true });
	});
});
