export interface CrashCounter {
	shouldRestart: () => boolean;
}

export const createCrashCounter = (maxRestarts: number, windowMs: number, now: () => number = Date.now): CrashCounter => {
	const crashes: number[] = [];
	return {
		shouldRestart: () => {
			const time = now();
			crashes.push(time);
			while (crashes.length > 0 && time - (crashes[0] ?? time) > windowMs) {
				crashes.shift();
			}
			return crashes.length <= maxRestarts;
		}
	};
};
