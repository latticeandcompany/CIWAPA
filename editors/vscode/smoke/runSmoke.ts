import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { runTests } from '@vscode/test-electron';

const vscodeVersion = '1.144.0';

const root = resolve(__dirname, '..');
const serverPath = resolve(process.env['INTERCAL_SERVER'] ?? join(root, '../../.cache/build/ciwapa-llvm'));
const userData = join(root, '.vscode-test', 'smoke-user-data');

const main = async (): Promise<void> => {
	rmSync(userData, { recursive: true, force: true });
	mkdirSync(join(userData, 'User'), { recursive: true });
	writeFileSync(
		join(userData, 'User', 'settings.json'),
		JSON.stringify({ 'intercal.serverPath': serverPath, 'extensions.autoCheckUpdates': false, 'telemetry.telemetryLevel': 'off', 'chat.disableAIFeatures': true }, null, '\t')
	);
	console.log(`Smoke test: VS Code ${vscodeVersion}, server ${serverPath}`);
	await runTests({
		version: vscodeVersion,
		extensionDevelopmentPath: root,
		extensionTestsPath: join(root, 'out', 'smokeSuite.js'),
		launchArgs: [join(root, 'smoke', 'workspace'), `--user-data-dir=${userData}`, '--disable-extensions', '--disable-gpu']
	});
};

main().catch((error: unknown) => {
	console.error(error instanceof Error ? error.message : error);
	process.exit(1);
});
