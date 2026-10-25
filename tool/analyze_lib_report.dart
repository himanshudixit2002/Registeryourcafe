// Analyzer report: JSON + CSV under tool/analyzer_reports/ (gitignored).
//
// From repo root (package-wide — same as `dart analyze` with no paths):
//   dart run tool/analyze_lib_report.dart
//   dart run tool/analyze_lib_report.dart --raw
//
// Scoped directories/files (after `--`):
//   dart run tool/analyze_lib_report.dart -- lib tool test
//   dart run tool/analyze_lib_report.dart --raw -- lib
//
// Flags: --raw  also writes analyzer_raw.json

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final parsed = _parseArgs(args);
  final root = _findRepoRoot();
  final outDir = Directory('${root.path}/tool/analyzer_reports');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final analyzeArgs = <String>[
    'analyze',
    '--format',
    'json',
    ...parsed.paths,
  ];

  final result = await Process.run(
    'dart',
    analyzeArgs,
    workingDirectory: root.path,
    environment: {...Platform.environment},
  );

  final stdoutText = result.stdout as String;
  if (stdoutText.trim().isEmpty) {
    stderr.writeln(
      'dart analyze produced empty stdout (exit ${result.exitCode})',
    );
    if ((result.stderr as String).isNotEmpty) {
      stderr.writeln(result.stderr);
    }
    exit(1);
  }

  late final Map<String, dynamic> decoded;
  try {
    decoded = jsonDecode(stdoutText) as Map<String, dynamic>;
  } catch (e) {
    stderr.writeln('Failed to parse analyzer JSON: $e');
    exit(1);
  }

  final diagnostics = (decoded['diagnostics'] as List<dynamic>?) ?? [];

  if (parsed.includeRaw) {
    File(
      '${outDir.path}/analyzer_raw.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(decoded));
  }

  final rootPrefix = root.path.endsWith(Platform.pathSeparator)
      ? root.path
      : '${root.path}${Platform.pathSeparator}';

  String relPath(String absolute) {
    if (absolute.startsWith(rootPrefix)) {
      return absolute.substring(rootPrefix.length).replaceAll('\\', '/');
    }
    return absolute.replaceAll('\\', '/');
  }

  final byFile = <String, _Agg>{};
  final globalCodes = <String, int>{};

  for (final d in diagnostics) {
    final m = d as Map<String, dynamic>;
    final loc = m['location'] as Map<String, dynamic>?;
    final file = loc?['file'] as String? ?? '(unknown)';
    final rel = relPath(file);
    final severity = (m['severity'] as String?)?.toUpperCase() ?? 'INFO';
    final code = m['code'] as String? ?? 'unknown';

    globalCodes[code] = (globalCodes[code] ?? 0) + 1;
    final agg = byFile.putIfAbsent(rel, _Agg.new);
    switch (severity) {
      case 'ERROR':
        agg.errors++;
      case 'WARNING':
        agg.warnings++;
      default:
        agg.infos++;
    }
    agg.codes[code] = (agg.codes[code] ?? 0) + 1;
  }

  final sortedFiles = byFile.keys.toList()..sort();

  final filesJson = <String, dynamic>{
    for (final f in sortedFiles)
      f: {
        'errors': byFile[f]!.errors,
        'warnings': byFile[f]!.warnings,
        'infos': byFile[f]!.infos,
        'codes': Map.fromEntries(
          (byFile[f]!.codes.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .map((e) => MapEntry(e.key, e.value)),
        ),
      },
  };

  final summary = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'repoRoot': root.path,
    'analyzeCommand': 'dart ${analyzeArgs.join(' ')}',
    'analyzeTargets':
        parsed.paths.isEmpty ? <String>['(package root — all contexts)'] : parsed.paths,
    'dartAnalyzeExitCode': result.exitCode,
    'totalDiagnostics': diagnostics.length,
    'filesWithIssues': byFile.length,
    'bySeverity': {
      'ERROR': byFile.values.fold<int>(0, (s, a) => s + a.errors),
      'WARNING': byFile.values.fold<int>(0, (s, a) => s + a.warnings),
      'INFO': byFile.values.fold<int>(0, (s, a) => s + a.infos),
    },
    'topRules': {
      for (final e in _topN(globalCodes, 15)) e.key: e.value,
    },
  };

  final perFileOut = {'summary': summary, 'files': filesJson};
  File(
    '${outDir.path}/per_file_summary.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(perFileOut));

  // Wide CSV: one row per file + compact rule breakdown
  final csvWide = StringBuffer()
    ..writeln('file,errors,warnings,infos,total,rule_breakdown');
  for (final f in sortedFiles) {
    final a = byFile[f]!;
    final total = a.errors + a.warnings + a.infos;
    final breakdownEntries = a.codes.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));
    final breakdown = breakdownEntries
        .map((e) => '${e.key}:${e.value}')
        .join('; ');
    _csvRow(csvWide, [
      f,
      '${a.errors}',
      '${a.warnings}',
      '${a.infos}',
      '$total',
      breakdown,
    ]);
  }
  File(
    '${outDir.path}/per_file_summary.csv',
  ).writeAsStringSync(csvWide.toString());

  // Long CSV for pivoting: file, code, count
  final csvLong = StringBuffer()..writeln('file,code,count');
  for (final f in sortedFiles) {
    final codes = byFile[f]!.codes.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        if (c != 0) return c;
        return a.key.compareTo(b.key);
      });
    for (final e in codes) {
      _csvRow(csvLong, [f, e.key, '${e.value}']);
    }
  }
  File(
    '${outDir.path}/per_file_rules.csv',
  ).writeAsStringSync(csvLong.toString());

  stdout.writeln('Wrote under ${outDir.path}/');
  stdout.writeln('  per_file_summary.json');
  stdout.writeln('  per_file_summary.csv');
  stdout.writeln('  per_file_rules.csv');
  if (parsed.includeRaw) stdout.writeln('  analyzer_raw.json');
  stdout.writeln('');
  stdout.writeln(
    'summary: ${summary['totalDiagnostics']} diagnostics in '
    '${summary['filesWithIssues']} files (dart exit ${result.exitCode})',
  );
  stdout.writeln('top rules: ${summary['topRules']}');
}

class _ParsedArgs {
  _ParsedArgs({required this.includeRaw, required this.paths});

  final bool includeRaw;
  final List<String> paths;
}

_ParsedArgs _parseArgs(List<String> args) {
  var includeRaw = false;
  final dd = args.indexOf('--');
  final flagSlice = dd == -1 ? args : args.sublist(0, dd);
  final pathSlice = dd == -1 ? <String>[] : args.sublist(dd + 1);

  for (final a in flagSlice) {
    if (a == '--raw') {
      includeRaw = true;
    } else if (a.startsWith('-')) {
      stderr.writeln('Unknown flag: $a (only --raw is supported)');
      exit(64);
    } else {
      stderr.writeln(
        'Unexpected argument before --: $a\n'
        'Use: dart run tool/analyze_lib_report.dart [--raw] [-- path1 path2 ...]',
      );
      exit(64);
    }
  }

  return _ParsedArgs(includeRaw: includeRaw, paths: pathSlice);
}

class _Agg {
  int errors = 0;
  int warnings = 0;
  int infos = 0;
  final Map<String, int> codes = {};
}

List<MapEntry<String, int>> _topN(Map<String, int> codes, int n) {
  final list = codes.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return list.take(n).toList();
}

void _csvRow(StringBuffer buf, List<String> fields) {
  buf.writeln(fields.map(_csvEscape).join(','));
}

String _csvEscape(String s) {
  if (s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

Directory _findRepoRoot() {
  // Prefer cwd when it already contains pubspec (typical: `dart run` from root).
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync()) {
    return cwd;
  }
  // Fall back: walk up from this script location.
  final scriptFile = Platform.script;
  if (scriptFile.isScheme('dart-mapped')) {
    // `dart run` can use virtual script URIs; cwd is the reliable anchor.
    throw StateError(
      'Run from project root (directory containing pubspec.yaml). '
      'Current: ${cwd.path}',
    );
  }
  var dir = Directory.fromUri(scriptFile).parent;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('pubspec.yaml not found above ${dir.path}');
    }
    dir = parent;
  }
}
