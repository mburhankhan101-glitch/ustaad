// lib/models/explanation.dart
//
// Explanations are stored as one string with four labelled parts:
//
//   "Concept: … Solution: 1. … 2. … 3. … Trick: … Mistake: …"
//
// The screen used to render that string as-is, so a student who had just got a
// question wrong was handed the labels and the step numbers as literal grey
// text in a single paragraph. Every one of the 1,819 explanations in the bank
// carries all four labels, and 99% write the solution as numbered steps, so
// there is real structure here to render — it was only ever being thrown away.
//
// This file is deliberately free of Flutter imports so it can be unit tested
// without a widget tester.

/// The four labels, in the order they are written.
const List<String> kExplanationLabels = [
  'Concept',
  'Solution',
  'Trick',
  'Mistake',
];

class ExplanationPart {
  /// One of [kExplanationLabels], or null for text before any label.
  final String? label;

  /// The prose, with the label stripped.
  final String body;

  /// Set only when [body] is a run of numbered steps. Empty otherwise.
  final List<String> steps;

  const ExplanationPart({
    required this.label,
    required this.body,
    this.steps = const [],
  });

  bool get hasSteps => steps.isNotEmpty;
}

class Explanation {
  final List<ExplanationPart> parts;

  const Explanation(this.parts);

  bool get isEmpty => parts.isEmpty;

  ExplanationPart? partFor(String label) {
    for (final p in parts) {
      if (p.label == label) return p;
    }
    return null;
  }

  /// Parts that make up the answer itself, always shown.
  List<ExplanationPart> get core =>
      parts.where((p) => p.label != 'Trick' && p.label != 'Mistake').toList();

  static final RegExp _labelPattern = RegExp(
    '(^|\\s)(${kExplanationLabels.join('|')}):\\s*',
  );

  /// Splits a stored explanation into its parts.
  ///
  /// Text with no labels at all comes back as a single unlabelled part rather
  /// than as nothing, so an explanation written in some other shape still
  /// renders instead of vanishing.
  static Explanation parse(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return const Explanation([]);

    final matches = _labelPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Explanation([ExplanationPart(label: null, body: text)]);
    }

    final out = <ExplanationPart>[];
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final start = m.end;
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      final body = text.substring(start, end).trim();
      if (body.isEmpty) continue;

      final label = m.group(2);
      out.add(
        ExplanationPart(
          label: label,
          body: body,
          steps: label == 'Solution' ? splitSteps(body) : const [],
        ),
      );
    }

    if (out.isEmpty) {
      return Explanation([ExplanationPart(label: null, body: text)]);
    }
    return Explanation(out);
  }

  /// Breaks "1. … 2. … 3. …" into its steps, or returns empty if it is prose.
  ///
  /// Splitting on every "<digits>. " tears sentences apart at their own
  /// numbers, and the bank is full of those: "…such that their sum is 0. 2.
  /// Multiply…" has two candidates and only one is a step marker. Two rules
  /// together settle it — a marker continues the sequence, and a marker opens
  /// a sentence, so it follows a full stop or starts the text.
  static List<String> splitSteps(String body) {
    final marks = <_Mark>[];
    var expected = 1;

    for (final m in RegExp(r'(\d+)\.\s+').allMatches(body)) {
      if (int.tryParse(m.group(1)!) != expected) continue;

      // Must start a word: rules out the "4" in "1.4. something".
      if (m.start > 0) {
        final before = body[m.start - 1];
        if (before != ' ' && before != '\n' && before != '\t') continue;
      }

      // Must open a sentence. "…denominator by 4. 4. The two cancel…" offers
      // two candidates for step 4 and only the second follows a full stop.
      final preceding = body.substring(0, m.start).trimRight();
      if (preceding.isNotEmpty &&
          !RegExp(r'[.?!:;]$').hasMatch(preceding)) {
        continue;
      }

      marks.add(_Mark(m.start, m.end));
      expected++;
    }

    if (marks.length < 2) return const [];

    final steps = <String>[];
    for (var i = 0; i < marks.length; i++) {
      // Cut at the next marker's start, not by trimming a trailing number off
      // the text, so a step that legitimately ends in one keeps it:
      // "Result: -2 - root 3." must not lose its 3.
      final end = i + 1 < marks.length ? marks[i + 1].start : body.length;
      final step = body.substring(marks[i].bodyStart, end).trim();
      if (step.isNotEmpty) steps.add(step);
    }
    return steps;
  }
}

class _Mark {
  final int start;
  final int bodyStart;
  const _Mark(this.start, this.bodyStart);
}

/// Arabic script, used by Urdu.
final RegExp _arabicScript = RegExp(r'[؀-ۿ]');
final RegExp _latinLetters = RegExp(r'[A-Za-z]');

/// Whether a string should be laid out right to left.
///
/// The screen used to decide this from the language toggle, but 1,599 of the
/// 1,819 Urdu explanations in the bank are roman Urdu written in the Latin
/// alphabet. Those were being right-aligned and line-spaced as though they
/// were Arabic script. The string itself is the only thing that knows.
bool isRtlText(String? text) {
  final s = text ?? '';
  if (s.isEmpty) return false;

  final arabic = _arabicScript.allMatches(s).length;
  if (arabic == 0) return false;

  final latin = _latinLetters.allMatches(s).length;
  return arabic >= latin;
}
