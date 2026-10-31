import * as vscode from 'vscode';
import { claimAnswers, askToClaim } from './messages';
import { claimOf, decideClaim, extensionOf } from './claiming';

const stateKey = (uri: vscode.Uri): string => `intercal.claim:${uri.toString()}`;

// Changing a document's language closes it and opens it again, so an INTERCAL document that
// reopens straight away as something else is the user switching it back by hand.
const switchWindowMs = 1000;

export const createClaimer = (state: vscode.Memento): vscode.Disposable => {
	const askedThisSession = new Set<string>();
	const closedAsIntercal = new Map<string, number>();

	const switchedByHand = (uri: vscode.Uri): boolean => {
		const closed = closedAsIntercal.get(uri.toString());
		closedAsIntercal.delete(uri.toString());
		return closed !== undefined && Date.now() - closed < switchWindowMs;
	};

	const claim = async (document: vscode.TextDocument): Promise<void> => {
		if (document.languageId === 'intercal') {
			return;
		}
		if (document.uri.scheme === 'ciwapa-lib') {
			await vscode.languages.setTextDocumentLanguage(document, 'intercal');
			return;
		}
		const path = document.uri.path;
		if (document.uri.scheme !== 'file' || claimOf(path) !== 'check' || switchedByHand(document.uri)) {
			return;
		}
		const key = stateKey(document.uri);
		const action = decideClaim(path, document.getText(), state.get<boolean>(key));
		if (action === 'claim') {
			await vscode.languages.setTextDocumentLanguage(document, 'intercal');
			return;
		}
		if (action === 'leave' || askedThisSession.has(key)) {
			return;
		}
		askedThisSession.add(key);
		const answer = await vscode.window.showInformationMessage(askToClaim(extensionOf(path)), claimAnswers.yes, claimAnswers.no);
		if (answer === undefined) {
			return;
		}
		await state.update(key, answer === claimAnswers.yes);
		if (answer === claimAnswers.yes) {
			const reopened = vscode.workspace.textDocuments.find((open) => open.uri.toString() === document.uri.toString());
			if (reopened !== undefined) {
				await vscode.languages.setTextDocumentLanguage(reopened, 'intercal');
			}
		}
	};

	vscode.workspace.textDocuments.forEach((document) => void claim(document));
	const subscriptions = [
		vscode.workspace.onDidOpenTextDocument((document) => void claim(document)),
		vscode.workspace.onDidCloseTextDocument((document) => {
			if (document.languageId === 'intercal') {
				closedAsIntercal.set(document.uri.toString(), Date.now());
			}
		})
	];
	return vscode.Disposable.from(...subscriptions);
};
