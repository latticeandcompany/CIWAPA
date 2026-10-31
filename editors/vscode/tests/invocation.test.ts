import { describe, expect, test } from '@jest/globals';
import { cliArguments } from '../src/invocation';

const plain = { platform: 'linux' as const, traditional: false, clockface: false };

describe('cliArguments', () => {
	test('run runs the file', () => {
		expect(cliArguments({ ...plain, command: 'run', file: '/src/hello.i' })).toEqual(['run', '/src/hello.i']);
	});

	test('build writes the executable next to the source', () => {
		expect(cliArguments({ ...plain, command: 'build', file: '/src/blog.ioi' })).toEqual(['build', '/src/blog.ioi', '-o', '/src/blog']);
		expect(cliArguments({ ...plain, platform: 'win32', command: 'build', file: 'C:\\src\\nine.2i' })).toEqual([
			'build',
			'C:\\src\\nine.2i',
			'-o',
			'C:\\src\\nine'
		]);
	});

	test('the traditional and clockface settings become flags', () => {
		expect(cliArguments({ ...plain, command: 'run', file: '/a.i', traditional: true, clockface: true })).toEqual([
			'run',
			'/a.i',
			'--traditional',
			'--clockface'
		]);
	});
});
