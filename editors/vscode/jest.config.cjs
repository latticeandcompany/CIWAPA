module.exports = {
	testEnvironment: 'node',
	testMatch: ['<rootDir>/tests/**/*.test.ts'],
	transform: {
		'^.+\\.ts$': [
			'@swc/jest',
			{
				jsc: {
					parser: { syntax: 'typescript' },
					target: 'es2023'
				},
				module: { type: 'commonjs' }
			}
		]
	},
	moduleFileExtensions: ['ts', 'js', 'json']
};
