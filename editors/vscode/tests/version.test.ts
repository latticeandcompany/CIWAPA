import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, test } from '@jest/globals';
import { versionMatches } from '../src/version';

const root = join(__dirname, '..');
const manifest = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));

describe('versions', () => {
	test("the extension's version is the compilers' version", () => {
		const pubspec = readFileSync(join(root, '../../packages/ciwapa_llvm/pubspec.yaml'), 'utf8');
		const compilers = /^version:\s*(\S+)\s*$/m.exec(pubspec)?.[1];
		expect(compilers).toBeDefined();
		expect(manifest.version).toBe(compilers);
	});

	test('only the exact same version matches', () => {
		expect(versionMatches('0.0.0', '0.0.0')).toBe(true);
		expect(versionMatches('0.0.1', '0.0.0')).toBe(false);
		expect(versionMatches('0.0.0-dev', '0.0.0')).toBe(false);
		expect(versionMatches(undefined, '0.0.0')).toBe(false);
	});
});
