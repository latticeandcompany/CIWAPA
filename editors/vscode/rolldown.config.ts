import { defineConfig } from 'rolldown';

export default defineConfig([
	{
		input: 'src/extension.ts',
		external: ['vscode'],
		platform: 'node',
		output: {
			file: 'dist/extension.js',
			format: 'cjs',
			sourcemap: true,
			minify: true
		}
	},
	{
		input: {
			runSmoke: 'smoke/runSmoke.ts',
			smokeSuite: 'smoke/smokeSuite.ts'
		},
		external: ['vscode', '@vscode/test-electron'],
		platform: 'node',
		output: {
			dir: 'out',
			format: 'cjs'
		}
	}
]);
