import 'library.g.dart';

/// One of EXTRACAL's library blocks (R10): a range of labels and the INTERCAL source that defines
/// them, included when a program NEXTs into the range and defines no label in it.
class LibraryBlock {
  const LibraryBlock(this.name, this.first, this.last, [this._source]);

  /// The file name the block's statements come from, such as `io.xc`.
  final String name;
  final int first;
  final int last;
  final String? _source;

  String get source => _source ?? extracalSources[name.split('.').first]!;
}

/// The blocks, in the order they are appended after a program.
const libraryBlocks = [
  LibraryBlock('io.xc', 2000, 2999),
  LibraryBlock('strings.xc', 3000, 3999),
  LibraryBlock('math.xc', 4000, 4999),
  LibraryBlock('arrays.xc', 6000, 6999),
  LibraryBlock('floats.xc', 7000, 7999),
  LibraryBlock('system.xc', 8000, 8999),
  LibraryBlock('network.xc', 9000, 9999),
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
  6000: (scalars: [':1'], arrays: [',1']),
  6003: (scalars: [], arrays: [',2']),
  6010: (scalars: [':1'], arrays: [',1']),
  6100: (scalars: [':1'], arrays: [';1']),
  6103: (scalars: [], arrays: [';2']),
  6110: (scalars: [':1'], arrays: [';1']),
  9000: (scalars: ['.1', '.2', '.3'], arrays: [',1']),
  9010: (scalars: ['.1', '.2', '.3'], arrays: []),
  9020: (scalars: ['.1', '.2', '.3'], arrays: []),
  9030: (scalars: ['.1', '.2'], arrays: []),
  9203: (scalars: [], arrays: [',3']),
  817: (scalars: [], arrays: []),
  807: (scalars: [], arrays: []),
  808: (scalars: [], arrays: []),
  809: (scalars: [], arrays: []),
  813: (scalars: [], arrays: []),
  814: (scalars: [], arrays: []),
  815: (scalars: [], arrays: []),
  816: (scalars: [], arrays: []),
};
