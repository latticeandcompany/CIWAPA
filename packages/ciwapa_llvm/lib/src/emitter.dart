import 'dart:convert';

import 'package:ciwapa_core/ciwapa_core.dart';

/// Generates textual LLVM IR for an [IrProgram].
///
/// The IR sticks to a conservative subset that both Apple clang and the bundled LLVM accept:
/// opaque `ptr`, no newer syntax. Statement N's entry block is `s<N>` and its "after" block, where
/// any COME FROM trap fires and where a RESUME returns to a NEXT, is `a<N>`.
class LlvmEmitter {
  LlvmEmitter(this.program, this.options, this.triple);

  final IrProgram program;
  final EmitOptions options;
  final String triple;
  late final _natives = options.optimize
      ? findNativeCalls(program)
      : const <int, NativeCall>{};

  final _globals = StringBuffer();
  var _body = StringBuffer();

  /// The control engine's callbacks, for a program it runs (R3).
  final _engineFunctions = StringBuffer();
  final _strings = <String, String>{};
  var _temp = 0;
  var _maxSubscripts = 1;
  var _blockCount = 0;

  /// Every RESUME's popped return point and the block it comes from, for the one shared `resume`
  /// block that dispatches them all.
  final _resumes = <(String, String)>[];

  static const _declarations = '''
declare void @ick_init(i32, ptr, ptr)
declare void @ick_fatal(i32, i32) noreturn
declare void @ick_undecodable(ptr, i32, i32) noreturn
declare void @ick_give_up() noreturn
declare i32 @ick_next_free()
declare i64 @ick_syslib(i32, i32, i32)
declare i32 @ick_roll(i32)
declare void @ick_stash_scalar(i32, i32)
declare void @ick_retrieve_scalar(i32, i32)
declare void @ick_stash_array(i32, i32)
declare void @ick_retrieve_array(i32, i32)
declare i32 @ick_mingle(i32, i32, i32)
declare i32 @ick_select(i32, i32)
declare i32 @ick_logical(i32, i32, i32)
declare i32 @ick_minus(i32, i32)
declare i32 @ick_plus(i32, i32)
declare i32 @ick_write_in(i32)
declare void @ick_read_out(i32)
declare void @ick_turing_in(i32, i32)
declare void @ick_turing_out(i32, i32)
declare void @ick_dimension(i32, i32, ptr, i32)
declare ptr @ick_element(i32, i32, ptr, i32)
declare i32 @ick_array_ignored(i32)
declare void @ick_array_set_ignored(i32, i32)
declare i32 @llvm.cttz.i32(i32, i1)

@ick_next_stack = external dso_local global [79 x i32]
@ick_next_depth = external dso_local global i32

define internal void @next_push(i32 %id, i32 %target) alwaysinline {
entry:
  %depth = load i32, ptr @ick_next_depth
  %full = icmp eq i32 %depth, 79
  br i1 %full, label %overflow, label %push
overflow:
  call void @ick_fatal(i32 123, i32 %target)
  unreachable
push:
  %slot = getelementptr [79 x i32], ptr @ick_next_stack, i32 0, i32 %depth
  store i32 %id, ptr %slot
  %grown = add i32 %depth, 1
  store i32 %grown, ptr @ick_next_depth
  ret void
}

define internal void @forget(i32 %count) alwaysinline {
entry:
  %depth = load i32, ptr @ick_next_depth
  %all = icmp uge i32 %count, %depth
  %left = sub i32 %depth, %count
  %kept = select i1 %all, i32 0, i32 %left
  store i32 %kept, ptr @ick_next_depth
  ret void
}

define internal i32 @resume(i32 %count, i32 %next) alwaysinline {
entry:
  %none = icmp eq i32 %count, 0
  br i1 %none, label %zero, label %some
zero:
  call void @ick_fatal(i32 621, i32 %next)
  unreachable
some:
  %depth = load i32, ptr @ick_next_depth
  %over = icmp ugt i32 %count, %depth
  br i1 %over, label %underflow, label %pop
underflow:
  call void @ick_fatal(i32 632, i32 %next)
  unreachable
pop:
  %left = sub i32 %depth, %count
  store i32 %left, ptr @ick_next_depth
  %slot = getelementptr [79 x i32], ptr @ick_next_stack, i32 0, i32 %left
  %id = load i32, ptr %slot
  ret i32 %id
}

define internal i32 @select2(i32 %value, i32 %mask) {
entry:
  %negated = sub i32 0, %mask
  %low = and i32 %mask, %negated
  %end = add i32 %mask, %low
  %gaps = and i32 %end, %mask
  %contiguous = icmp eq i32 %gaps, 0
  br i1 %contiguous, label %run, label %loop
run:
  %kept = and i32 %value, %mask
  %padded = or i32 %mask, -2147483648
  %shift = call i32 @llvm.cttz.i32(i32 %padded, i1 true)
  %shifted = lshr i32 %kept, %shift
  ret i32 %shifted
loop:
  %rest = phi i32 [ %mask, %entry ], [ %rest.next, %loop ]
  %bit = phi i32 [ 1, %entry ], [ %bit.next, %loop ]
  %result = phi i32 [ 0, %entry ], [ %result.next, %loop ]
  %rest.negated = sub i32 0, %rest
  %lowest = and i32 %rest, %rest.negated
  %hit = and i32 %value, %lowest
  %set = icmp ne i32 %hit, 0
  %with = or i32 %result, %bit
  %result.next = select i1 %set, i32 %with, i32 %result
  %bit.next = shl i32 %bit, 1
  %rest.less = sub i32 %rest, 1
  %rest.next = and i32 %rest, %rest.less
  %more = icmp ne i32 %rest.next, 0
  br i1 %more, label %loop, label %done
done:
  ret i32 %result.next
}
''';

  static const _wideDeclarations = '''
declare void @ick_init_wide(ptr, ptr, i32, i32)
declare i32 @ick_check_narrow(i64, i32, i32)
declare i64 @ick_select64(i64, i64)
declare void @ick_stash_scalar64(i32, i32)
declare void @ick_retrieve_scalar64(i32, i32)
declare void @ick_dimension_x(i32, i32, i32, ptr, i32)
declare ptr @ick_element64(i32, i32, ptr, i32)
declare i32 @ick_array_ignored64(i32)
declare void @ick_array_set_ignored64(i32, i32)
declare void @ick_stash_array64(i32, i32)
declare void @ick_retrieve_array64(i32, i32)
declare i64 @ick_write_in64(i32)
declare void @ick_read_out64(i64)
declare void @ick_turing_in64(i32, i32)
declare void @ick_turing_out64(i32, i32)
declare void @ick_xmingle(ptr, i32, i64, i64, i32, i64, i64, i32)
declare void @ick_xselect(ptr, i32, i64, i64, i32, i64, i64)
declare void @ick_xunary(ptr, i32, i32, i64, i64, i32)
declare i64 @ick_write_in_signed(i32, i32)
declare void @ick_x_run(ptr, i32, ptr, ptr, ptr, i32, ptr, ptr, ptr)
declare i32 @ick_x_clear(i32)
declare void @ick_init_overloading(i32, i32, ptr, ptr)
declare i64 @ick_ov_get(i32, i64, i32, i32)
declare i32 @ick_ov_set(i32, i64, i32)
declare i64 @ick_ov_slat(i32, i32, i64)
declare void @ick_ov_stash(i32)
declare void @ick_ov_retrieve(i32)
declare i64 @ick_reverse_unary(i32, i64, i32, i32)
declare void @ick_read_out_signed(i64, i32)
''';

  String emit() {
    if (program.engine) return _emitEngine();
    for (final s in program.statements) {
      _statement(s);
    }
    _block('fell');
    _line('call void @ick_fatal(i32 633, i32 ${program.userStatements + 1})');
    _line('unreachable');
    if (program.statements.length > program.userStatements) {
      _block('fell.library');
      _line(
        'call void @ick_fatal(i32 633, i32 ${program.statements.length + 1})',
      );
      _line('unreachable');
    }
    _block('unreachable');
    _line('unreachable');
    if (_resumes.isNotEmpty) {
      _block('resume');
      _line(
        '%return.id = phi i32 ${_resumes.map((r) => '[ ${r.$1}, %${r.$2} ]').join(', ')}',
      );
      final returns = [
        for (final t in program.statements)
          if (t.op is IrNext && t.faults.isEmpty)
            'i32 ${t.ordinal}, label %a${t.ordinal}',
      ];
      _line('switch i32 %return.id, label %unreachable [${returns.join(' ')}]');
    }

    final statements = program.statements.length;
    final out = _module()
      ..writeln('define i32 @main(i32 %argc, ptr %argv) {')
      ..writeln('entry:')
      ..writeln('  %subs = alloca [$_maxSubscripts x i32]')
      ..write(
        program.extracal
            ? '  %dims64 = alloca [$_maxSubscripts x i64]\n'
                  '  %xout = alloca [3 x i64]\n'
            : '',
      )
      ..writeln('  call void @ick_init(i32 %argc, ptr %argv, ptr @program)')
      ..write(
        program.extracal
            ? '  call void @ick_init_wide(ptr @v64, ptr @igw, i32 ${program.wideScalars.length}, '
                  'i32 ${program.wideArrays.length})\n'
            : '',
      )
      ..writeln('  br label %${statements == 0 ? 'fell' : 's1'}')
      ..write(_body)
      ..writeln('}');
    return out.toString();
  }

  /// The program on EXTRACAL's control engine (R3): the engine runs the control flow from a table,
  /// and calls back into compiled functions for the bodies of the other statements, FORGET and
  /// RESUME counts, and native library routines.
  String _emitEngine() {
    final table = EngineTable(program);
    final count = program.statements.length;

    _engineFunction('void @x_body(i32 %ordinal)', 'ret void', () {
      final cases = <String>[];
      for (final s in program.statements) {
        if (!_plainBody(s.op)) continue;
        cases.add('i32 ${s.ordinal}, label %b${s.ordinal}');
      }
      _line('switch i32 %ordinal, label %done [${cases.join(' ')}]');
      for (final s in program.statements) {
        if (!_plainBody(s.op)) continue;
        _block('b${s.ordinal}');
        _statementBody(s);
        _line('br label %done');
      }
    });
    _engineFunction('i64 @x_expr(i32 %ordinal)', 'ret i64 0', () {
      final counts = [
        for (final s in program.statements)
          if (s.op
              case IrForget(:final count) ||
                  IrResume(:final count) ||
                  IrComputedComeFrom(label: final count) ||
                  IrAbstain(count: final count?))
            (s, count),
      ];
      _line(
        'switch i32 %ordinal, label %done [${counts.map((c) => 'i32 ${c.$1.ordinal}, label %e${c.$1.ordinal}').join(' ')}]',
      );
      for (final (s, count) in counts) {
        _block('e${s.ordinal}');
        _line('ret i64 ${_as64(count, s.next)}');
      }
    });
    _engineFunction('i32 @x_native(i32 %ordinal)', 'ret i32 0', () {
      final calls = [
        for (final s in program.statements)
          if (s.op case IrNext(:final target) when _natives.containsKey(target))
            (s, _natives[target]!),
      ];
      _line(
        'switch i32 %ordinal, label %done [${calls.map((c) => 'i32 ${c.$1.ordinal}, label %n${c.$1.ordinal}').join(' ')}]',
      );
      for (final (s, call) in calls) {
        _block('n${s.ordinal}');
        final free = _fresh(), room = _fresh(), native = _newBlock('native');
        _line('$free = call i32 @ick_next_free()');
        _line('$room = icmp uge i32 $free, ${call.depth}');
        _line('br i1 $room, label %$native, label %done');
        _block(native);
        final clear = [
          for (final w in call.watched)
            () {
              final flag = _fresh(), ok = _fresh();
              _line('$flag = load i8, ptr ${_ignoredFlag(w)}');
              _line('$ok = icmp eq i8 $flag, 0');
              return ok;
            }(),
          for (final o in call.abstainable)
            () {
              final flag = _fresh(), ok = _fresh();
              _line('$flag = call i32 @ick_x_clear(i32 $o)');
              _line('$ok = icmp ne i32 $flag, 0');
              return ok;
            }(),
        ];
        for (final ok in clear) {
          final next = _newBlock('native');
          _line('br i1 $ok, label %$next, label %done');
          _block(next);
        }
        final args = [
          for (final a in call.args) _expr(IrScalar(a), s.next),
          if (call.args.length == 1) '0',
        ];
        final r = _fresh(), ran = _fresh(), store = _newBlock('native');
        _line(
          '$r = call i64 @ick_syslib(i32 ${call.label}, ${args.map((a) => 'i32 $a').join(', ')})',
        );
        _line('$ran = icmp sge i64 $r, 0');
        _line('br i1 $ran, label %$store, label %done');
        _block(store);
        final result = _fresh();
        _line('$result = trunc i64 $r to i32');
        _line('store i32 $result, ptr ${_scalarPointer(call.result)}');
        if (call.flag case final flag?) {
          final high = _fresh(), overflowed = _fresh(), value = _fresh();
          _line('$high = lshr i64 $r, 32');
          _line('$overflowed = icmp ne i64 $high, 0');
          _line('$value = select i1 $overflowed, i32 2, i32 1');
          _line('store i32 $value, ptr ${_scalarPointer(flag)}');
        }
        _line('ret i32 1');
      }
    });

    if (program.overloading) {
      _engineFunction('i64 @ov_get(i32 %id, i32 %next)', 'ret i64 0', () {
        final ids = [for (var i = 1; i <= program.overloads.length; i++) i];
        _line(
          'switch i32 %id, label %done [${ids.map((i) => 'i32 $i, label %g$i').join(' ')}]',
        );
        for (final id in ids) {
          _block('g$id');
          _line('ret i64 ${_as64(program.overloads[id - 1], '%next')}');
        }
      });
      _engineFunction('void @ov_set(i32 %id, i64 %value, i32 %next)', 'ret void', () {
        final ids = [for (var i = 1; i <= program.overloads.length; i++) i];
        _line(
          'switch i32 %id, label %done [${ids.map((i) => 'i32 $i, label %s$i').join(' ')}]',
        );
        for (final id in ids) {
          _block('s$id');
          _reverse(program.overloads[id - 1], '%value');
          _line('br label %done');
        }
      });
    }
    final texts = [
      for (var o = 0; o <= count; o++)
        table.texts[o] == null
            ? 'ptr null'
            : 'ptr ${_stringGlobal(table.texts[o]!)}',
    ];
    final lengths = [
      for (var o = 0; o <= count; o++)
        'i32 ${table.texts[o] == null ? 0 : utf8.encode(table.texts[o]!).length}',
    ];
    final lists = table.lists.isEmpty ? [0] : table.lists;
    _globals
      ..writeln(
        '@x_table = internal constant [${table.rows.length} x i32] [${table.rows.map((v) => 'i32 $v').join(', ')}]',
      )
      ..writeln(
        '@x_lists = internal constant [${lists.length} x i32] [${lists.map((v) => 'i32 $v').join(', ')}]',
      )
      ..writeln(
        '@x_texts = internal constant [${count + 1} x ptr] [${texts.join(', ')}]',
      )
      ..writeln(
        '@x_text_lengths = internal constant [${count + 1} x i32] [${lengths.join(', ')}]',
      );
    final out = _module()
      ..write(_engineFunctions)
      ..writeln('define i32 @main(i32 %argc, ptr %argv) {')
      ..writeln('entry:')
      ..writeln('  call void @ick_init(i32 %argc, ptr %argv, ptr @program)')
      ..writeln(
        '  call void @ick_init_wide(ptr @v64, ptr @igw, i32 ${program.wideScalars.length}, '
        'i32 ${program.wideArrays.length})',
      )
      ..write(
        program.overloading
            ? '  call void @ick_init_overloading(i32 ${program.scalars.length + program.wideScalars.length}, '
                  'i32 ${program.overloads.length}, ptr @ov_get, ptr @ov_set)\n'
            : '',
      )
      ..writeln(
        '  call void @ick_x_run(ptr @x_table, i32 $count, ptr @x_lists, ptr @x_texts, '
        'ptr @x_text_lengths, i32 ${program.userStatements}, ptr @x_body, ptr @x_expr, ptr @x_native)',
      )
      ..writeln('  unreachable')
      ..writeln('}');
    return out.toString();
  }

  /// Assigns i64 [target] to [e] backwards, as `ick` does for an overloaded variable: a mingle's
  /// operands get the target's odd and even bits, a select's left operand gets the target and its
  /// right operand all ones, a unary operator is undone, and a constant is E277. "All ones" is
  /// [width] bits: `ick` starts at 16 and takes each unary operator's width on the way down. Runs
  /// inside @ov_set, whose `%next` it uses.
  void _reverse(IrExpr e, String target, [int width = 16]) {
    const next = '%next';
    switch (e) {
      case IrScalar(:final slot):
        final handled = _fresh(), went = _fresh();
        _line(
          '$handled = call i32 @ick_ov_set(i32 ${_key(slot)}, i64 $target, i32 $next)',
        );
        _line('$went = icmp ne i32 $handled, 0');
        final store = _newBlock('store'), done = _newBlock('stored');
        _line('br i1 $went, label %$done, label %$store');
        _block(store);
        _storeFitting(slot, target, next);
        _line('br label %$done');
        _block(done);
      case IrSlat(:final slot, :final id):
        _storeFitting(slot, target, next);
        _line('call i64 @ick_ov_slat(i32 ${_key(slot)}, i32 $id, i64 0)');
      case IrElement(:final array, :final subscripts):
        final pointer = _elementPointer(array, subscripts, next);
        final v = _fitting(target, array.width, next);
        final flag = _fresh(), ignored = _fresh();
        _line(
          '$flag = call i32 @ick_array_ignored${_suffix(array)}(i32 ${array.index})',
        );
        _line('$ignored = icmp ne i32 $flag, 0');
        _storeUnlessIgnored(pointer, v, ignored, array.wide ? 'i64' : 'i32');
      case IrMingle(:final left, :final right) when program.base == 2:
        final odd = _fresh(), even = _fresh();
        _line(
          '$odd = call i64 @ick_select64(i64 $target, i64 -6148914691236517206)',
        );
        _line(
          '$even = call i64 @ick_select64(i64 $target, i64 6148914691236517205)',
        );
        _reverse(left, odd, width);
        _reverse(right, even, width);
      case IrSelect(:final left, :final right) when program.base == 2:
        _reverse(left, target, width);
        _reverse(right, width == 64 ? '-1' : '${(1 << width) - 1}', width);
      case IrUnary(:final op, :final operand) when program.base == 2:
        final undone = _fresh();
        _line(
          '$undone = call i64 @ick_reverse_unary(i32 ${UnaryOp.values.indexOf(op)}, i64 $target, '
          'i32 ${operand.valueWidth}, i32 $next)',
        );
        _reverse(operand, undone, operand.valueWidth);
      default:
        // Constants can't change, and the other bases' operators can't be undone.
        _line('call void @ick_fatal(i32 277, i32 $next)');
        _line('unreachable');
        _block(_newBlock('dead'));
    }
  }

  /// Emits one of the engine's callbacks: [emit] writes its body, which ends at `done` unless it
  /// returns.
  void _engineFunction(String signature, String done, void Function() emit) {
    _body = StringBuffer();
    _maxSubscripts = 1;
    emit();
    _block('done');
    _line(done);
    _engineFunctions
      ..writeln('define internal $signature {')
      ..writeln('entry:')
      ..writeln('  %subs = alloca [$_maxSubscripts x i32]')
      ..writeln('  %dims64 = alloca [$_maxSubscripts x i64]')
      ..writeln('  %xout = alloca [3 x i64]')
      ..writeln('  br label %body')
      ..writeln('body:')
      ..write(_body)
      ..writeln('}')
      ..writeln();
  }

  /// The statements whose bodies are compiled for the control engine; it runs the rest itself.
  static bool _plainBody(IrOp op) => switch (op) {
    IrAssign() ||
    IrDimension() ||
    IrVarList() ||
    IrWriteIn() ||
    IrReadOut() => true,
    _ => false,
  };

  /// Everything before main: globals, declarations and helpers.
  StringBuffer _module() {
    final scalars = program.scalars.length;
    final statements = program.statements.length;
    final abstained = [
      'i8 0',
      for (final s in program.statements) 'i8 ${s.initiallyAbstained ? 1 : 0}',
    ];
    final messages = [
      for (final m in IclError.all)
        '%ick_message { i32 ${m.code}, ptr ${_stringGlobal(m.text)}, ptr ${_stringGlobal(m.joke)} }',
    ];
    return StringBuffer()
      ..writeln(
        '; Generated by ciwapa-llvm from ${options.sourceName}. Do not edit.',
      )
      ..writeln('target triple = "$triple"')
      ..writeln()
      ..writeln('%ick_message = type { i32, ptr, ptr }')
      ..writeln(
        '%ick_program = type { i32, i32, i32, i32, ptr, ptr, ptr, i32 }',
      )
      ..writeln()
      ..writeln('@v = internal global [$scalars x i32] zeroinitializer')
      ..writeln('@ig = internal global [$scalars x i8] zeroinitializer')
      ..write(
        program.extracal
            ? '@v64 = internal global [${program.wideScalars.length} x i64] zeroinitializer\n'
                  '@igw = internal global [${program.wideScalars.length} x i8] zeroinitializer\n'
            : '',
      )
      ..writeln(
        '@ab = internal global [${statements + 1} x i8] [${abstained.join(', ')}]',
      )
      ..writeln(
        '@messages = internal constant [${messages.length} x %ick_message] [${messages.join(', ')}]',
      )
      ..writeln(
        '@program = internal constant %ick_program { i32 ${program.base}, i32 ${options.clockface ? 1 : 0}, '
        'i32 $scalars, i32 ${program.arrays.length}, ptr @v, ptr @ig, ptr @messages, i32 ${messages.length} }',
      )
      ..write(_globals)
      ..writeln()
      ..write(_declarations)
      ..write(program.extracal ? _wideDeclarations : '')
      ..writeln()
      ..writeln(
        'define internal i32 @check_small(i32 %value, i32 %next) alwaysinline {',
      )
      ..writeln('entry:')
      ..writeln('  %big = icmp ugt i32 %value, ${program.smallLimit}')
      ..writeln('  br i1 %big, label %overflow, label %fits')
      ..writeln('overflow:')
      ..writeln('  call void @ick_fatal(i32 275, i32 %next)')
      ..writeln('  unreachable')
      ..writeln('fits:')
      ..writeln('  ret i32 %value')
      ..writeln('}')
      ..writeln();
  }

  void _block(String name) => _body.writeln('$name:');

  void _line(String code) => _body.writeln('  $code');

  String _fresh() => '%t${_temp++}';

  String _newBlock(String prefix) => '$prefix.${_blockCount++}';

  String _stringGlobal(String text) => _strings.putIfAbsent(text, () {
    final name = '@.str.${_strings.length}';
    final bytes = [...utf8.encode(text), 0];
    final escaped = bytes
        .map(
          (b) => b >= 0x20 && b < 0x7F && b != 0x22 && b != 0x5C
              ? String.fromCharCode(b)
              : '\\${b.toRadixString(16).padLeft(2, '0').toUpperCase()}',
        )
        .join();
    _globals.writeln(
      '$name = private unnamed_addr constant [${bytes.length} x i8] c"$escaped"',
    );
    return name;
  });

  /// Running off the user's program is E633 at the user's last ordinal + 1 (decision T37);
  /// running off the library, at its own.
  String _fallthrough(IrStatement s) {
    if (s.ordinal == program.userStatements) return 'fell';
    if (s.ordinal == program.statements.length) return 'fell.library';
    return 's${s.ordinal + 1}';
  }

  void _statement(IrStatement s) {
    final n = s.ordinal;
    _block('s$n');
    if (s.bug) {
      _line('call void @ick_fatal(i32 774, i32 ${s.next})');
      _line('unreachable');
    } else {
      if (s.op is! IrComeFrom) {
        final percent = s.percent;
        if (percent != null && percent < 100) _guard('ickRoll', percent, 'a$n');
        if (s.abstainable) _guard('abstained', n, 'a$n');
      }
      if (s.faults.isNotEmpty && s.op is! IrComeFrom) {
        _line(
          'call void @ick_fatal(i32 ${s.faults.first.code}, i32 ${s.next})',
        );
        _line('unreachable');
      } else {
        _statementBody(s);
        _line('br label %a$n');
      }
    }

    _block('a$n');
    _trap(s, _fallthrough(s));
  }

  /// The COME FROM trap after [s]: jumps to the COME FROM aimed at it when that COME FROM's own
  /// guard passes, and to [otherwise] when it doesn't (or when nothing is aimed at [s]). A COME
  /// FROM's own faults fire in place of its jump (decision L2).
  void _trap(IrStatement s, String otherwise) {
    final comeFrom = s.comeFrom;
    if (comeFrom == null) {
      _line('br label %$otherwise');
      return;
    }
    final c = program.at(comeFrom);
    if (c.percent != null && c.percent! < 100) {
      _guard('ickRoll', c.percent!, otherwise);
    }
    if (c.abstainable) _guard('abstained', c.ordinal, otherwise);
    // A bug planted on the COME FROM fires at its entry, ahead of its faults (decision T23).
    if (c.faults.isEmpty || c.bug) {
      _line('br label %s$comeFrom');
    } else {
      _line('call void @ick_fatal(i32 ${c.faults.first.code}, i32 ${c.next})');
      _line('unreachable');
    }
  }

  /// Continues in a fresh block when the guard passes, and jumps to [otherwise] when it doesn't.
  void _guard(String kind, int value, String otherwise) {
    final pass = _fresh();
    if (kind == 'ickRoll') {
      final roll = _fresh();
      _line('$roll = call i32 @ick_roll(i32 $value)');
      _line('$pass = icmp ne i32 $roll, 0');
    } else {
      final flag = _fresh();
      _line(
        '$flag = load i8, ptr getelementptr inbounds ([${program.statements.length + 1} x i8], ptr @ab, i64 0, i64 $value)',
      );
      _line('$pass = icmp eq i8 $flag, 0');
    }
    final next = _newBlock('g');
    _line('br i1 $pass, label %$next, label %$otherwise');
    _block(next);
  }

  void _statementBody(IrStatement s) {
    final next = s.next;
    switch (s.op) {
      case IrAssign(:final target, :final value):
        _assign(target, value, next);
      case IrDimension(:final array, :final dimensions) when program.extracal:
        // EXTRACAL dimensions are 64-bit values, checked against 32 bits by the runtime (R4).
        final values = [for (final d in dimensions) _as64(d, next)];
        if (values.length > _maxSubscripts) _maxSubscripts = values.length;
        for (final (i, value) in values.indexed) {
          final slot = _fresh();
          _line('$slot = getelementptr inbounds i64, ptr %dims64, i64 $i');
          _line('store i64 $value, ptr $slot');
        }
        _line(
          'call void @ick_dimension_x(i32 ${array.index}, i32 ${array.wide ? 1 : 0}, '
          'i32 ${values.length}, ptr %dims64, i32 $next)',
        );
      case IrDimension(:final array, :final dimensions):
        final values = [for (final d in dimensions) _expr(d, next)];
        _storeSubscripts(values);
        _line(
          'call void @ick_dimension(i32 ${array.index}, i32 ${values.length}, ptr %subs, i32 $next)',
        );
      case IrNext(:final target):
        if (_natives[target] case final call?) _native(s, call);
        _line('call void @next_push(i32 ${s.ordinal}, i32 $target)');
        _line('br label %s$target');
        _block(_newBlock('dead'));
      case IrForget(:final count):
        _line('call void @forget(i32 ${_count(count, next)})');
      case IrResume(:final count):
        final id = _fresh();
        _line('$id = call i32 @resume(i32 ${_count(count, next)}, i32 $next)');
        // An executed RESUME still springs a COME FROM aimed at it; only an executed NEXT waits
        // for its RESUME (§4.4.14.2).
        final dispatch = _newBlock('return');
        _trap(s, dispatch);
        _block(dispatch);
        _resumes.add((id, dispatch));
        _line('br label %resume');
        _block(_newBlock('dead'));
      case IrGiveUp():
        _line('call void @ick_give_up()');
        _line('unreachable');
        _block(_newBlock('dead'));
      case IrVarList(:final op, :final scalars, :final arrays)
          when op == ListOp.stash || op == ListOp.retrieve:
        final verb = op == ListOp.stash ? 'stash' : 'retrieve';
        for (final v in scalars) {
          _line(
            'call void @ick_${verb}_scalar${_suffix(v)}(i32 ${v.index}, i32 $next)',
          );
          if (program.overloading) {
            _line(
              'call void @ick_ov_${op == ListOp.stash ? 'stash' : 'retrieve'}(i32 ${_key(v)})',
            );
          }
        }
        for (final a in arrays) {
          _line(
            'call void @ick_${verb}_array${_suffix(a)}(i32 ${a.index}, i32 $next)',
          );
        }
      case IrVarList(:final op, :final scalars, :final arrays)
          when op == ListOp.ignore || op == ListOp.remember:
        final ignored = op == ListOp.ignore ? 1 : 0;
        for (final v in scalars) {
          _line('store i8 $ignored, ptr ${_ignoredFlag(v)}');
        }
        for (final a in arrays) {
          _line(
            'call void @ick_array_set_ignored${_suffix(a)}(i32 ${a.index}, i32 $ignored)',
          );
        }
      case IrAbstain(:final abstain, :final targets):
        for (final t in targets) {
          final p = _fresh();
          _line(
            '$p = getelementptr inbounds [${program.statements.length + 1} x i8], ptr @ab, i64 0, i64 $t',
          );
          _line('store i8 ${abstain ? 1 : 0}, ptr $p');
        }
      case IrWriteIn(:final items, :final signed):
        for (final item in items) {
          if (item is IrArrayItem) {
            _line(
              'call void @ick_turing_in${_suffix(item.array)}(i32 ${item.array.index}, i32 $next)',
            );
            continue;
          }
          // Element subscripts are checked first, then the number is read, then E275 (even when
          // the target is IGNOREd, decision T24), then the store.
          _assign(
            item,
            signed
                ? IrInput(width: item.width, signed: true)
                : IrInput(width: item.width == 64 ? 64 : 32),
            next,
          );
        }
      case IrReadOut(:final items, :final signed):
        for (final item in items) {
          if (item is IrArrayItem) {
            _line(
              'call void @ick_turing_out${_suffix(item.array)}(i32 ${item.array.index}, i32 $next)',
            );
          } else if (signed) {
            _line(
              'call void @ick_read_out_signed(i64 ${_as64(item, next)}, i32 ${item.width})',
            );
          } else if (item.width == 64) {
            _line('call void @ick_read_out64(i64 ${_expr(item, next)})');
          } else {
            _line('call void @ick_read_out(i32 ${_expr(item, next)})');
          }
        }
      case IrComeFrom():
        break;
      case IrUndecodable(:final text):
        final length = utf8.encode(text).length;
        _line(
          'call void @ick_undecodable(ptr ${_stringGlobal(text)}, i32 $length, i32 $next)',
        );
        _line('unreachable');
        _block(_newBlock('dead'));
      case final op:
        throw ToolchainException('${op.runtimeType} is not implemented yet');
    }
  }

  void _storeSubscripts(List<String> values) {
    if (values.length > _maxSubscripts) _maxSubscripts = values.length;
    for (final (i, value) in values.indexed) {
      final slot = _fresh();
      _line('$slot = getelementptr inbounds i32, ptr %subs, i64 $i');
      _line('store i32 $value, ptr $slot');
    }
  }

  /// Stores [value] at [pointer] unless [ignored] (an i1) is set.
  void _storeUnlessIgnored(
    String pointer,
    String value,
    String ignored, [
    String type = 'i32',
  ]) {
    final old = _fresh(), chosen = _fresh();
    _line('$old = load $type, ptr $pointer');
    _line('$chosen = select i1 $ignored, $type $old, $type $value');
    _line('store $type $chosen, ptr $pointer');
  }

  /// `64` for EXTRACAL's 64-bit storage, whose runtime functions end in it.
  static String _suffix(Slot slot) => slot.wide ? '64' : '';

  /// A scalar's key in the runtime's overloading table: 64-bit scalars come after the others.
  int _key(Slot slot) =>
      slot.wide ? program.scalars.length + slot.index : slot.index;

  /// [value], an i64, as a value [width] bits wide can hold: E275 or E276 when it doesn't fit.
  String _fitting(String value, int width, Object next) {
    if (width == 64) return value;
    final narrow = _fresh();
    _line(
      '$narrow = call i32 @ick_check_narrow(i64 $value, i32 $width, i32 $next)',
    );
    return narrow;
  }

  /// Stores i64 [value] in [slot] past its overloading, unless the slot is IGNOREd.
  void _storeFitting(Slot slot, String value, Object next) {
    final type = slot.wide ? 'i64' : 'i32';
    final v = _fitting(value, slot.width, next);
    final pointer = _scalarPointer(slot);
    final flag = _fresh(), ignored = _fresh();
    _line('$flag = load i8, ptr ${_ignoredFlag(slot)}');
    _line('$ignored = icmp ne i8 $flag, 0');
    _storeUnlessIgnored(pointer, v, ignored, type);
  }

  /// A scalar's true value, without its overloading, as an i64.
  String _trueValue(Slot slot) {
    final p = _scalarPointer(slot), t = _fresh();
    _line('$t = load ${slot.wide ? 'i64' : 'i32'}, ptr $p');
    if (slot.wide) return t;
    final wide = _fresh();
    _line('$wide = zext i32 $t to i64');
    return wide;
  }

  /// An i64 [value] narrowed back to [slot]'s type.
  String _asSlotType(Slot slot, String value) {
    if (slot.wide) return value;
    final narrow = _fresh();
    _line('$narrow = trunc i64 $value to i32');
    return narrow;
  }

  /// A pointer to [slot]'s IGNORE flag.
  String _ignoredFlag(Slot slot) {
    final p = _fresh();
    final (flags, count) = slot.wide
        ? ('@igw', program.wideScalars.length)
        : ('@ig', program.scalars.length);
    _line(
      '$p = getelementptr inbounds [$count x i8], ptr $flags, i64 0, i64 ${slot.index}',
    );
    return p;
  }

  /// [e] as an i64, widening a 16- or 32-bit value.
  String _as64(IrExpr e, Object next) {
    final v = _expr(e, next);
    if (e.valueWidth == 64) return v;
    final wide = _fresh();
    _line('$wide = zext i32 $v to i64');
    return wide;
  }

  /// An i64 [value] clamped to 32 bits: past them it becomes [past].
  String _clamp32(String value, int past) {
    final big = _fresh(), low = _fresh(), clamped = _fresh();
    _line('$big = icmp ugt i64 $value, 4294967295');
    _line('$low = trunc i64 $value to i32');
    _line('$clamped = select i1 $big, i32 $past, i32 $low');
    return clamped;
  }

  /// A FORGET or RESUME count: a 64-bit one past 32 bits acts like the largest 32-bit count.
  String _count(IrExpr count, Object next) {
    final v = _expr(count, next);
    return count.valueWidth == 64 ? _clamp32(v, -1) : v;
  }

  void _assign(IrExpr target, IrExpr value, Object next) {
    // A value can only exceed a narrower target; narrower ones were checked when they were stored.
    // 32 bits into 16 is Mode 1's E275, and anything wider is EXTRACAL's (R4).
    String checked(String v) {
      if (target.width == 64) {
        if (value.valueWidth == 64) return v;
        final wide = _fresh();
        _line('$wide = zext i32 $v to i64');
        return wide;
      }
      if (value.valueWidth <= target.width) return v;
      if (value is IrConst && value.value >= 0) {
        final max = target.width == 16 ? program.smallLimit : 0xFFFFFFFF;
        if (value.value <= max) return value.width == 64 ? '${value.value}' : v;
      }
      final c = _fresh();
      if (value.valueWidth == 64) {
        _line(
          '$c = call i32 @ick_check_narrow(i64 $v, i32 ${target.width}, i32 $next)',
        );
      } else {
        _line('$c = call i32 @check_small(i32 $v, i32 $next)');
      }
      return c;
    }

    final type = target.width == 64 ? 'i64' : 'i32';
    switch (target) {
      // An overloaded variable's assignment goes into its expression instead. WRITE IN stores
      // into the variable itself, as in `ick`.
      case IrScalar(:final slot) when program.overloading && value is! IrInput:
        final v = _as64(value, next), handled = _fresh(), went = _fresh();
        _line(
          '$handled = call i32 @ick_ov_set(i32 ${_key(slot)}, i64 $v, i32 $next)',
        );
        _line('$went = icmp ne i32 $handled, 0');
        final store = _newBlock('store'), done = _newBlock('stored');
        _line('br i1 $went, label %$done, label %$store');
        _block(store);
        _storeFitting(slot, v, next);
        _line('br label %$done');
        _block(done);
      case IrScalar(:final slot):
        final v = checked(_expr(value, next));
        final pointer = _scalarPointer(slot);
        if (!program.ignorable.contains(slot)) {
          _line('store $type $v, ptr $pointer');
          return;
        }
        final flag = _fresh(), ignored = _fresh();
        _line('$flag = load i8, ptr ${_ignoredFlag(slot)}');
        _line('$ignored = icmp ne i8 $flag, 0');
        _storeUnlessIgnored(pointer, v, ignored, type);
      case IrElement(:final array, :final subscripts):
        final pointer = _elementPointer(array, subscripts, next);
        final v = checked(_expr(value, next));
        if (!program.ignorable.contains(array)) {
          _line('store $type $v, ptr $pointer');
          return;
        }
        final flag = _fresh(), ignored = _fresh();
        _line(
          '$flag = call i32 @ick_array_ignored${_suffix(array)}(i32 ${array.index})',
        );
        _line('$ignored = icmp ne i32 $flag, 0');
        _storeUnlessIgnored(pointer, v, ignored, type);
      default:
        throw StateError('cannot assign to $target');
    }
  }

  /// Runs [call] in place of the NEXT [s] when the INTERCAL routine would behave the same, and
  /// continues to the NEXT otherwise.
  void _native(IrStatement s, NativeCall call) {
    final native = _newBlock('native'), fallback = _newBlock('fallback');
    final free = _fresh(), room = _fresh();
    _line('$free = call i32 @ick_next_free()');
    _line('$room = icmp uge i32 $free, ${call.depth}');
    _line('br i1 $room, label %$native, label %$fallback');
    _block(native);
    for (final w in call.watched) {
      final flagPointer = _fresh(), flag = _fresh(), clear = _fresh();
      _line(
        '$flagPointer = getelementptr inbounds [${program.scalars.length} x i8], ptr @ig, i64 0, i64 ${w.index}',
      );
      _line('$flag = load i8, ptr $flagPointer');
      _line('$clear = icmp eq i8 $flag, 0');
      final next = _newBlock('native');
      _line('br i1 $clear, label %$next, label %$fallback');
      _block(next);
    }
    for (final o in call.abstainable) {
      final flag = _fresh(), clear = _fresh();
      _line(
        '$flag = load i8, ptr getelementptr inbounds ([${program.statements.length + 1} x i8], ptr @ab, i64 0, i64 $o)',
      );
      _line('$clear = icmp eq i8 $flag, 0');
      final next = _newBlock('native');
      _line('br i1 $clear, label %$next, label %$fallback');
      _block(next);
    }
    final args = [
      for (final a in call.args) _expr(IrScalar(a), s.next),
      if (call.args.length == 1) '0',
    ];
    final r = _fresh(), ran = _fresh(), store = _newBlock('native');
    _line(
      '$r = call i64 @ick_syslib(i32 ${call.label}, ${args.map((a) => 'i32 $a').join(', ')})',
    );
    _line('$ran = icmp sge i64 $r, 0');
    _line('br i1 $ran, label %$store, label %$fallback');
    _block(store);
    final result = _fresh();
    _line('$result = trunc i64 $r to i32');
    _line('store i32 $result, ptr ${_scalarPointer(call.result)}');
    if (call.flag case final flag?) {
      final high = _fresh(), overflowed = _fresh(), value = _fresh();
      _line('$high = lshr i64 $r, 32');
      _line('$overflowed = icmp ne i64 $high, 0');
      _line('$value = select i1 $overflowed, i32 2, i32 1');
      _line('store i32 $value, ptr ${_scalarPointer(flag)}');
    }
    _line('br label %a${s.ordinal}');
    _block(fallback);
  }

  String _op(String op, String a, String b) {
    final t = _fresh();
    _line('$t = $op i32 $a, $b');
    return t;
  }

  String _op64(String op, String a, String b) {
    final t = _fresh();
    _line('$t = $op i64 $a, $b');
    return t;
  }

  /// The LLVM type [e] evaluates to.
  static String _type(IrExpr e) => e.valueWidth == 64 ? 'i64' : 'i32';

  /// [e] as (width, high, low): an i32 and two i64s, for the operations whose result width
  /// depends on their operands' values: EXTRACAL's mingle and what is built on it (R5).
  (String, String, String) _wide(IrExpr e, Object next) => switch (e) {
    _ when e.width != IrExpr.runtimeWidth => (
      '${e.width}',
      '0',
      _as64(e, next),
    ),
    IrMingle(:final left, :final right) => _xcall('ick_xmingle', [
      ..._wideArgs(_wide(left, next)),
      ..._wideArgs(_wide(right, next)),
      'i32 $next',
    ]),
    IrSelect(:final left, :final right) => _xcall('ick_xselect', [
      ..._wideArgs(_wide(left, next)),
      ..._wideArgs(_wide(right, next)),
    ]),
    IrUnary(:final op, :final operand) => _xcall('ick_xunary', [
      'i32 ${UnaryOp.values.indexOf(op)}',
      ..._wideArgs(_wide(operand, next)),
      'i32 $next',
    ]),
    _ => throw StateError('$e has no run-time width'),
  };

  static List<String> _wideArgs((String, String, String) value) => [
    'i32 ${value.$1}',
    'i64 ${value.$2}',
    'i64 ${value.$3}',
  ];

  /// Calls a runtime routine that leaves a (width, high, low) result in %xout, and loads it.
  (String, String, String) _xcall(String function, List<String> args) {
    _line('call void @$function(ptr %xout, ${args.join(', ')})');
    final parts = <String>[];
    for (var i = 0; i < 3; i++) {
      final p = _fresh(), t = _fresh();
      _line('$p = getelementptr inbounds [3 x i64], ptr %xout, i64 0, i64 $i');
      _line('$t = load i64, ptr $p');
      parts.add(t);
    }
    final width = _fresh();
    _line('$width = trunc i64 ${parts[0]} to i32');
    return (width, parts[1], parts[2]);
  }

  /// Whether [e] can't be above 65535: a small value, or a constant that fits.
  static bool _fitsSmall(IrExpr e) =>
      !e.large || (e is IrConst && e.value >= 0 && e.value <= 65535);

  /// Spreads the 16 bits of [v] to the even bit positions, for mingle (§3.4.1).
  String _spread(String v) {
    for (final (shift, mask) in const [
      (8, 0x00FF00FF),
      (4, 0x0F0F0F0F),
      (2, 0x33333333),
      (1, 0x55555555),
    ]) {
      v = _op('and', _op('or', v, _op('shl', v, '$shift')), '$mask');
    }
    return v;
  }

  String _scalarPointer(Slot slot) {
    final p = _fresh();
    _line(
      slot.wide
          ? '$p = getelementptr inbounds [${program.wideScalars.length} x i64], ptr @v64, i64 0, i64 ${slot.index}'
          : '$p = getelementptr inbounds [${program.scalars.length} x i32], ptr @v, i64 0, i64 ${slot.index}',
    );
    return p;
  }

  /// A subscript past 32 bits is past the end of any array, so it becomes 0, which is E241 too.
  String _elementPointer(Slot array, List<IrExpr> subscripts, Object next) {
    final values = [
      for (final s in subscripts)
        s.valueWidth == 64 ? _clamp32(_expr(s, next), 0) : _expr(s, next),
    ];
    _storeSubscripts(values);
    final p = _fresh();
    _line(
      '$p = call ptr @ick_element${_suffix(array)}(i32 ${array.index}, i32 ${values.length}, ptr %subs, i32 $next)',
    );
    return p;
  }

  String _call(String function, List<String> args) {
    final t = _fresh();
    _line('$t = call i32 @$function(${args.map((a) => 'i32 $a').join(', ')})');
    return t;
  }

  String _expr(IrExpr e, Object next) {
    switch (e) {
      case _ when e.width == IrExpr.runtimeWidth:
        final (width, _, low) = _wide(e, next);
        final ephemeral = _fresh(),
            fine = _newBlock('x'),
            fault = _newBlock('e534');
        _line('$ephemeral = icmp eq i32 $width, 128');
        _line('br i1 $ephemeral, label %$fault, label %$fine');
        _block(fault);
        _line('call void @ick_fatal(i32 534, i32 $next)');
        _line('unreachable');
        _block(fine);
        return low;
      case IrSelect(:final left, :final right)
          when left.width == IrExpr.runtimeWidth:
        final (_, _, low) = _xcall('ick_xselect', [
          ..._wideArgs(_wide(left, next)),
          ..._wideArgs(_wide(right, next)),
        ]);
        if (e.width == 64) return low;
        final narrow = _fresh();
        _line('$narrow = trunc i64 $low to i32');
        return narrow;
      case IrConst(:final value):
        return '$value';
      case IrScalar(:final slot) when program.overloading:
        final read = _fresh();
        _line(
          '$read = call i64 @ick_ov_get(i32 ${_key(slot)}, i64 ${_trueValue(slot)}, i32 ${slot.width}, i32 $next)',
        );
        return _asSlotType(slot, read);
      case IrSlat(:final slot, :final id):
        final value = _fresh();
        _line(
          '$value = call i64 @ick_ov_slat(i32 ${_key(slot)}, i32 $id, i64 ${_trueValue(slot)})',
        );
        return _asSlotType(slot, value);
      case IrScalar(:final slot):
        final p = _scalarPointer(slot), t = _fresh();
        _line('$t = load ${_type(e)}, ptr $p');
        return t;
      case IrElement(:final array, :final subscripts):
        final p = _elementPointer(array, subscripts, next), t = _fresh();
        _line('$t = load ${_type(e)}, ptr $p');
        return t;
      case IrMingle(:final left, :final right) when program.base == 2:
        final l = _expr(left, next), r = _expr(right, next);
        for (final (operand, value) in [(left, l), (right, r)]) {
          if (_fitsSmall(operand)) continue;
          final tooBig = _fresh(), fine = _newBlock('mingle');
          final fault = _newBlock('e533');
          _line('$tooBig = icmp ugt i32 $value, 65535');
          _line('br i1 $tooBig, label %$fault, label %$fine');
          _block(fault);
          _line('call void @ick_fatal(i32 533, i32 $next)');
          _line('unreachable');
          _block(fine);
        }
        return _op('or', _op('shl', _spread(l), '1'), _spread(r));
      case IrMingle(:final left, :final right):
        final l = _expr(left, next), r = _expr(right, next);
        return _call('ick_mingle', [l, r, '$next']);
      case IrSelect(:final left, :final right)
          when left.width == 64 || right.width == 64:
        final l = _as64(left, next);
        String result;
        if (right case IrConst(value: final mask)
            when selectRuns(mask, bits: 64).length <= 8) {
          result = '0';
          for (final run in selectRuns(mask, bits: 64)) {
            var part = run.from == 0 ? l : _op64('lshr', l, '${run.from}');
            if (run.from + run.width < 64) {
              part = _op64('and', part, '${(1 << run.width) - 1}');
            }
            if (run.to > 0) part = _op64('shl', part, '${run.to}');
            result = result == '0' ? part : _op64('or', result, part);
          }
        } else {
          result = _fresh();
          _line(
            '$result = call i64 @ick_select64(i64 $l, i64 ${_as64(right, next)})',
          );
        }
        if (e.width == 64) return result;
        final narrow = _fresh();
        _line('$narrow = trunc i64 $result to i32');
        return narrow;
      case IrSelect(:final left, right: IrConst(value: final mask))
          when program.base == 2 &&
              compressSteps(mask).length < selectRuns(mask).length:
        var x = _op('and', _expr(left, next), '$mask');
        for (final step in compressSteps(mask)) {
          final moving = _op('and', x, '${step.moving}');
          x = _op(
            'or',
            _op('xor', x, moving),
            _op('lshr', moving, '${step.shift}'),
          );
        }
        return x;
      case IrSelect(:final left, right: IrConst(value: final mask))
          when program.base == 2:
        final l = _expr(left, next);
        var result = '0';
        for (final run in selectRuns(mask)) {
          var part = run.from == 0 ? l : _op('lshr', l, '${run.from}');
          if (run.from + run.width < 32) {
            part = _op('and', part, '${(1 << run.width) - 1}');
          }
          if (run.to > 0) part = _op('shl', part, '${run.to}');
          result = result == '0' ? part : _op('or', result, part);
        }
        return result;
      case IrSelect(:final left, :final right):
        final l = _expr(left, next), r = _expr(right, next);
        return _call(program.base == 2 ? 'select2' : 'ick_select', [l, r]);
      case IrUnary(:final op, :final operand) when operand.width == 64:
        final value = _expr(operand, next);
        final rotated = _op64(
          'or',
          _op64('lshr', value, '1'),
          _op64('shl', value, '63'),
        );
        return _op64(
          switch (op) {
            UnaryOp.and => 'and',
            UnaryOp.or => 'or',
            _ => 'xor',
          },
          value,
          rotated,
        );
      case IrUnary(:final op, :final operand):
        final value = _expr(operand, next);
        final large = operand.large ? 1 : 0;
        if (program.base == 2) {
          // Each bit with its neighbor, the last wrapping around to the first (§3.4.2).
          final name = switch (op) {
            UnaryOp.and => 'and',
            UnaryOp.or => 'or',
            UnaryOp.xor => 'xor',
            _ => throw StateError('$op in binary is E997 at compile time'),
          };
          final width = operand.large ? 32 : 16;
          var rotated = _op(
            'or',
            _op('lshr', value, '1'),
            _op('shl', value, '${width - 1}'),
          );
          if (width == 16) rotated = _op('and', rotated, '65535');
          return _op(name, value, rotated);
        }
        return switch (op) {
          UnaryOp.xor => _call('ick_minus', ['$large', value]),
          UnaryOp.sharkfin => _call('ick_plus', ['$large', value]),
          _ => _call('ick_logical', [
            '$large',
            '${preferredDigit(op, program.base)}',
            value,
          ]),
        };
      case IrInput(signed: true, :final width):
        final t = _fresh();
        _line('$t = call i64 @ick_write_in_signed(i32 $width, i32 $next)');
        if (width == 64) return t;
        final narrow = _fresh();
        _line('$narrow = trunc i64 $t to i32');
        return narrow;
      case IrInput(width: 64):
        final t = _fresh();
        _line('$t = call i64 @ick_write_in64(i32 $next)');
        return t;
      case IrInput():
        return _call('ick_write_in', ['$next']);
      case IrArrayItem():
        throw StateError('a whole array is not a value');
    }
  }
}
