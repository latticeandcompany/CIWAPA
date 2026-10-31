import { describe, expect, test } from '@jest/globals';
import { createCrashCounter } from '../src/crashes';

describe('createCrashCounter', () => {
	test('restarts up to the limit within the window, then gives up', () => {
		let now = 0;
		const counter = createCrashCounter(2, 1000, () => now);
		expect(counter.shouldRestart()).toBe(true);
		now = 100;
		expect(counter.shouldRestart()).toBe(true);
		now = 200;
		expect(counter.shouldRestart()).toBe(false);
	});

	test('old crashes stop counting once they leave the window', () => {
		let now = 0;
		const counter = createCrashCounter(2, 1000, () => now);
		counter.shouldRestart();
		counter.shouldRestart();
		now = 5000;
		expect(counter.shouldRestart()).toBe(true);
	});
});
