// Summarises coverage/lcov.info per file and fails if the total line coverage
// is below the minimum.
//
//   flutter test --coverage
//   dart run tool/coverage.dart [minimum percent, default 90]
import 'dart:io';

void main(List<String> args) {
  final minimum = args.isEmpty ? 90.0 : double.parse(args.first);
  final report = File('coverage/lcov.info');
  if (!report.existsSync()) {
    stderr.writeln('coverage/lcov.info not found. Run: flutter test --coverage');
    exit(2);
  }

  // file -> (lines hit, lines found, uncovered line numbers)
  final files = <String, (int, int, List<int>)>{};
  var name = '';
  var hit = 0;
  var found = 0;
  var missed = <int>[];
  for (final line in report.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      name = line.substring(3).replaceAll(r'\', '/');
      hit = 0;
      found = 0;
      missed = [];
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      found++;
      if (int.parse(parts[1]) > 0) {
        hit++;
      } else {
        missed.add(int.parse(parts[0]));
      }
    } else if (line == 'end_of_record') {
      files[name] = (hit, found, missed);
    }
  }

  String percent(int hit, int found) =>
      found == 0 ? '  n/a' : '${(100 * hit / found).toStringAsFixed(1).padLeft(5)}%';

  final width = files.keys.fold(0, (w, f) => f.length > w ? f.length : w);
  var totalHit = 0;
  var totalFound = 0;
  for (final name in files.keys.toList()..sort()) {
    final (hit, found, missed) = files[name]!;
    totalHit += hit;
    totalFound += found;
    final gaps = missed.isEmpty ? '' : '  uncovered lines: ${missed.join(', ')}';
    stdout.writeln(
      '${name.padRight(width)}  ${percent(hit, found)}  $hit/$found$gaps',
    );
  }
  stdout.writeln(
    '${'TOTAL'.padRight(width)}  ${percent(totalHit, totalFound)}  $totalHit/$totalFound',
  );

  final total = totalFound == 0 ? 0.0 : 100 * totalHit / totalFound;
  if (total < minimum) {
    stderr.writeln(
      'Coverage ${total.toStringAsFixed(1)}% is below the minimum of $minimum%.',
    );
    exit(1);
  }
}
