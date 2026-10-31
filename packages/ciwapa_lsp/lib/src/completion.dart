import 'package:ciwapa_core/ciwapa_core.dart';

import 'document.dart';
import 'text.dart';
import 'words.dart';

const _keywords = [
  'NEXT',
  'FORGET',
  'RESUME',
  'STASH',
  'RETRIEVE',
  'IGNORE',
  'REMEMBER',
  'ABSTAIN FROM',
  'REINSTATE',
  'READ OUT',
  'WRITE IN',
  'COME FROM',
  'GIVE UP',
  'NOTE',
];

const _extracalKeywords = [
  'NEXT FROM',
  'TRY AGAIN',
  'CREATE',
  'GO BACK',
  'GO AHEAD',
  'PETITION',
  'READ OUT BAUDOT',
  'WRITE IN BAUDOT',
  'WRITE IN SIGNED',
];

const _gerunds = {
  Gerund.calculating: 'CALCULATING',
  Gerund.nexting: 'NEXTING',
  Gerund.forgetting: 'FORGETTING',
  Gerund.resuming: 'RESUMING',
  Gerund.stashing: 'STASHING',
  Gerund.retrieving: 'RETRIEVING',
  Gerund.ignoring: 'IGNORING',
  Gerund.remembering: 'REMEMBERING',
  Gerund.abstaining: 'ABSTAINING',
  Gerund.reinstating: 'REINSTATING',
  Gerund.readingOut: 'READING OUT',
  Gerund.writingIn: 'WRITING IN',
  Gerund.comingFrom: 'COMING FROM',
};

const _extracalGerunds = {
  Gerund.nextingFrom: 'NEXTING FROM',
  Gerund.tryingAgain: 'TRYING AGAIN',
  Gerund.creating: 'CREATING',
  Gerund.commenting: 'COMMENTING',
  Gerund.goingBack: 'GOING BACK',
  Gerund.goingAhead: 'GOING AHEAD',
  Gerund.whiling: 'WHILING',
  Gerund.petitioning: 'PETITIONING',
};

/// How far back completion looks for its context: far enough for a statement's head.
const _lookBehind = 200;

final _inLabel = RegExp(r'\(\s*\d*$');
final _afterGerundTaker = RegExp(
  r"(ABSTAIN\s+FROM|REINSTATE)\s+([A-Z]+(\s+[A-Z]+)*\s*\+\s*)*[A-Z]*$",
);
final _afterIdentifier = RegExp(
  r"(^|[\s)])(DO|PLEASE(\s+DO)?|MAYBE(\s+PLEASE)?(\s+DO)?)(\s*(NOT|N'T))?(\s*%\s*\d+)?\s+[A-Z]*$",
);

/// `textDocument/completion` (R8, Q172): labels inside `( )`, gerunds after ABSTAIN FROM and
/// REINSTATE, and statement keywords after an identifier.
List<Map<String, Object?>> completion(Document document, Position position) {
  final offset = document.text.offset(position);
  final runes = document.text.source.runes;
  final before = String.fromCharCodes(
    runes,
    (offset - _lookBehind).clamp(0, offset),
    offset,
  );
  final program = document.analysis.program;
  if (_inLabel.hasMatch(before)) return _labels(document);
  if (_afterGerundTaker.hasMatch(before)) {
    return [
      for (final MapEntry(key: gerund, value: word) in {
        ..._gerunds,
        if (program.extracal) ..._extracalGerunds,
      }.entries)
        {
          'label': word,
          'kind': 14,
          'documentation': _markdown(gerundHelp(gerund)),
        },
    ];
  }
  if (_afterIdentifier.hasMatch(before)) {
    return [
      for (final word in [
        ..._keywords,
        if (program.extracal) ..._extracalKeywords,
        ...document.server.extension.keywordsFor(document.path),
      ])
        {'label': word, 'kind': 14},
    ];
  }
  return const [];
}

List<Map<String, Object?>> _labels(Document document) {
  final own = document.definedLabels.toList()..sort();
  final routines = document.libraryRoutines.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return [
    for (final label in own)
      {'label': '$label', 'kind': 18, 'detail': 'a label in this file'},
    for (final MapEntry(key: label, value: routine) in routines)
      {
        'label': '$label',
        'kind': 3,
        'detail': routine.library,
        'documentation': _markdown(routine.toMarkdown()),
      },
  ];
}

Map<String, Object?> _markdown(String value) => {
  'kind': 'markdown',
  'value': value,
};
