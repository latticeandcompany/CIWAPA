import 'library.g.dart';

/// One of EXTRACAL's library blocks (R10): a range of labels and the INTERCAL source that defines
/// them, included when a program NEXTs into the range and defines no label in it.
class LibraryBlock {
  const LibraryBlock(this.name, this.first, this.last);

  final String name;
  final int first;
  final int last;

  String get source => extracalSources[name]!;
}

/// The blocks, in the order they are appended after a program.
const libraryBlocks = [
  LibraryBlock('io', 2000, 2999),
  LibraryBlock('strings', 3000, 3999),
  LibraryBlock('system', 8000, 8999),
];

/// The host services PETITION asks for (R10, L29), and the variables each reads and writes, in
/// the order the runtimes take them. `packages/ciwapa_core/lib/extracal/README.md` documents
/// them.
const petitionServices = <int, ({List<String> scalars, List<String> arrays})>{
  8000: (scalars: ['.1'], arrays: []),
  8010: (scalars: ['.1', '.2'], arrays: [',1']),
  8020: (scalars: ['.1'], arrays: [',1', ',2']),
  8030: (scalars: ['.1'], arrays: []),
  8040: (scalars: ['::1'], arrays: []),
  8050: (scalars: ['::1'], arrays: []),
  8060: (scalars: ['::1'], arrays: []),
  2000: (scalars: ['.1', '.2', '.3'], arrays: []),
  2010: (scalars: ['.1', '.2', '.3'], arrays: []),
  2020: (scalars: ['.1', '.2', '.3'], arrays: [',1']),
  2030: (scalars: ['.1', '.3'], arrays: []),
  3000: (scalars: [':1'], arrays: [',1']),
  3001: (scalars: [], arrays: [',1']),
  3002: (scalars: [':2'], arrays: [',2']),
  807: (scalars: [], arrays: []),
  808: (scalars: [], arrays: []),
};
