export type Claim = 'always' | 'check' | 'never';

export type ClaimAction = 'claim' | 'leave' | 'ask';

const alwaysIntercal = /\.(?:[2-7]i|[2-7]xc|2?ioi)$/;
const sometimesIntercal = /\.(?:i|xc)$/;
const statement = /^\s*(\(\d+\)\s*)?(PLEASE|DO)\b/;
const linesChecked = 50;

export const claimOf = (path: string): Claim => {
	if (alwaysIntercal.test(path)) {
		return 'always';
	}
	return sometimesIntercal.test(path) ? 'check' : 'never';
};

export const extensionOf = (path: string): string => {
	const dot = path.lastIndexOf('.');
	return dot < 0 ? '' : path.slice(dot);
};

export const looksLikeIntercal = (text: string): boolean =>
	text.split(/\r\n|\r|\n/, linesChecked).some((line) => statement.test(line));

export const decideClaim = (path: string, text: string, remembered: boolean | undefined): ClaimAction => {
	switch (claimOf(path)) {
		case 'always':
			return 'claim';
		case 'never':
			return 'leave';
		case 'check':
			if (looksLikeIntercal(text) || remembered === true) {
				return 'claim';
			}
			return remembered === false ? 'leave' : 'ask';
	}
};

export const isInterstates = (path: string): boolean => /\.2?ioi$/.test(path);
