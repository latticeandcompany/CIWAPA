import { describe, expect, test } from '@jest/globals';
import { claimOf, decideClaim, extensionOf, isInterstates, looksLikeIntercal } from '../src/claiming';

const swig = '%module example\n%{\n#include "example.h"\n%}\nint fact(int n);\n';
const xmos = '#include <xs1.h>\nint main() {\n  par {\n  }\n}\n';

describe('claimOf', () => {
	test.each(['.2i', '.3i', '.4i', '.5i', '.6i', '.7i', '.2xc', '.3xc', '.4xc', '.5xc', '.6xc', '.7xc', '.ioi', '.2ioi'])(
		'%s is always INTERCAL',
		(extension) => expect(claimOf(`/src/program${extension}`)).toBe('always')
	);

	test.each(['.i', '.xc'])('%s needs a look first', (extension) => expect(claimOf(`/src/program${extension}`)).toBe('check'));

	test.each(['.8i', '.1i', '.3ioi', '.7ioi', '.html', '.c', '.txt', ''])('%s is never claimed', (extension) =>
		expect(claimOf(`/src/program${extension}`)).toBe('never')
	);
});

describe('looksLikeIntercal', () => {
	test.each([
		'DO GIVE UP',
		'PLEASE DO ,1 <- #2',
		'\tPLEASE GIVE UP',
		'(1) DO .1 <- #1',
		'(1000)\tPLEASE RESUME #1',
		'   (12)DO NOTE this is a comment'
	])('a statement line: %s', (line) => expect(looksLikeIntercal(`prose first\n${line}\nmore prose`)).toBe(true));

	test.each(['DONE', 'PLEASED TO MEET YOU', 'do give up', '(x) DO GIVE UP', 'NOTE: DO GIVE UP', '1 DO GIVE UP'])(
		'not a statement line: %s',
		(line) => expect(looksLikeIntercal(line)).toBe(false)
	);

	test('SWIG and XMOS XC are not INTERCAL', () => {
		expect(looksLikeIntercal(swig)).toBe(false);
		expect(looksLikeIntercal(xmos)).toBe(false);
	});

	test('only the first 50 lines count', () => {
		expect(looksLikeIntercal(`${'prose\n'.repeat(49)}DO GIVE UP\n`)).toBe(true);
		expect(looksLikeIntercal(`${'prose\n'.repeat(50)}DO GIVE UP\n`)).toBe(false);
	});

	test('CRLF and CR line endings count lines too', () => {
		expect(looksLikeIntercal(`${'prose\r\n'.repeat(49)}DO GIVE UP`)).toBe(true);
		expect(looksLikeIntercal(`${'prose\r'.repeat(50)}DO GIVE UP`)).toBe(false);
	});

	test('an empty file is not INTERCAL', () => expect(looksLikeIntercal('')).toBe(false));
});

describe('decideClaim', () => {
	test('unambiguous extensions are claimed whatever they hold', () => {
		expect(decideClaim('/a.ioi', swig, undefined)).toBe('claim');
		expect(decideClaim('/a.3i', '', false)).toBe('claim');
	});

	test('a .i or .xc with a statement is claimed without asking', () => {
		expect(decideClaim('/a.i', 'DO GIVE UP', undefined)).toBe('claim');
		expect(decideClaim('/a.xc', 'PLEASE GIVE UP', false)).toBe('claim');
	});

	test('a .i or .xc without one asks, unless the answer is remembered', () => {
		expect(decideClaim('/a.i', swig, undefined)).toBe('ask');
		expect(decideClaim('/a.xc', xmos, undefined)).toBe('ask');
		expect(decideClaim('/a.i', swig, true)).toBe('claim');
		expect(decideClaim('/a.xc', xmos, false)).toBe('leave');
	});

	test('other files are left alone', () => expect(decideClaim('/a.c', 'DO GIVE UP', true)).toBe('leave'));
});

describe('helpers', () => {
	test('extensionOf names the extension for the prompt', () => {
		expect(extensionOf('/src/example.i')).toBe('.i');
		expect(extensionOf('/src/board.xc')).toBe('.xc');
		expect(extensionOf('/src/Makefile')).toBe('');
	});

	test('isInterstates spots .ioi and .2ioi', () => {
		expect(isInterstates('/blog.ioi')).toBe(true);
		expect(isInterstates('/blog.2ioi')).toBe(true);
		expect(isInterstates('/blog.i')).toBe(false);
		expect(isInterstates('/blog.xc')).toBe(false);
	});
});
