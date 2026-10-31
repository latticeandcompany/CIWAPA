import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, test } from '@jest/globals';
import { claimOf } from '../src/claiming';

const manifest = JSON.parse(readFileSync(join(__dirname, '..', 'package.json'), 'utf8'));

describe('package.json', () => {
	test('is latticeandcompany.intercal, called INTERCAL, and mentions CIWAPA', () => {
		expect(`${manifest.publisher}.${manifest.name}`).toBe('latticeandcompany.intercal');
		expect(manifest.displayName).toBe('INTERCAL');
		expect(manifest.description).toContain('CIWAPA');
	});

	test('claims exactly the unambiguous extensions outright; .i and .xc wait for a look', () => {
		const [language] = manifest.contributes.languages;
		expect(language.id).toBe('intercal');
		for (const extension of language.extensions) {
			expect(claimOf(`program${extension}`)).toBe('always');
		}
		expect(language.extensions).toHaveLength(14);
		expect(language.extensions).not.toContain('.i');
		expect(language.extensions).not.toContain('.xc');
	});

	test('contributes no task type, since nothing provides one', () => {
		expect(manifest.contributes.taskDefinitions).toBeUndefined();
	});

	test('binds the usual comment shortcut to the server-side toggle in INTERCAL files', () => {
		expect(manifest.contributes.keybindings).toContainEqual({
			command: 'intercal.toggleComment',
			key: 'ctrl+/',
			mac: 'cmd+/',
			when: 'editorTextFocus && editorLangId == intercal && !editorReadonly'
		});
	});

	test('has the settings every extension has', () => {
		expect(Object.keys(manifest.contributes.configuration.properties).toSorted()).toEqual([
			'intercal.clockface',
			'intercal.flavor',
			'intercal.serverPath',
			'intercal.traditional'
		]);
		expect(manifest.contributes.configuration.properties['intercal.flavor'].enum).toEqual(['llvm', 'dart']);
	});

	test('every dependency is pinned to an exact version', () => {
		for (const version of Object.values<string>({ ...manifest.dependencies, ...manifest.devDependencies })) {
			expect(version).toMatch(/^\d+\.\d+\.\d+$/);
		}
	});
});
