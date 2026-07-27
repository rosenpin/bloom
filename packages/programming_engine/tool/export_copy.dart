// Exports all exercise copy from catalog_v1 as markdown for instructor review.
// Run: dart run tool/export_copy.dart > /tmp/exercise-copy.md
import 'package:programming_engine/programming_engine.dart';

void main() {
  final catalog = catalogV1;
  final buf = StringBuffer(
    '# Exercise copy review — draft from catalog_v1\n\n'
    'Review like an instructor. For each: setup steps right? cues real? '
    'anything unsafe or awkward? Mark changes inline.\n',
  );
  for (final e in catalog.exercises) {
    buf
      ..writeln('\n## ${e.name}  (`${e.id}`)')
      ..writeln(
        '- Block: ${e.blockRole.name} · ${e.movementClass.name} · '
        '${e.resistanceEquipment.name} · bw ${e.bwContribution}',
      )
      ..writeln('- Should feel: ${e.shouldFeel}')
      ..writeln('- Stop if: ${e.stopIf}')
      ..writeln('- Find it: ${e.findIt}');
    buf.writeln('- Setup:');
    for (var i = 0; i < e.setupSteps.length; i++) {
      buf.writeln('  ${i + 1}. ${e.setupSteps[i]}');
    }
    if (e.dos.isNotEmpty) buf.writeln("- Do's: ${e.dos.join(' | ')}");
    if (e.donts.isNotEmpty) {
      buf.writeln("- Don'ts: ${e.donts.join(' | ')}");
    }
  }
  // ignore: avoid_print
  print(buf);
}
