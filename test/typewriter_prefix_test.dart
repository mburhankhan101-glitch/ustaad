// The UTF-16 crash, pinned down.
//
// Crashlytics: _NativeParagraphBuilder.addText — "Invalid argument(s):
// string is not well-formed UTF-16", live from 1.3.1 to 1.3.4. Every Ustu
// line carries emoji, an emoji is a surrogate pair, and the typewriters cut
// those lines one UTF-16 code unit at a time. On the tick that landed
// between the halves the widget tried to lay out half a character.
//
// It was intermittent because the loop runs faster than the display: the
// bad frame has to actually get painted. That is exactly the kind of bug
// that survives manual testing, so it gets a test instead.

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/core/utils/ustu_overlays.dart';

/// True if [s] contains half of a surrogate pair. This is the condition
/// Flutter's text layout rejects.
bool hasLoneSurrogate(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c >= 0xD800 && c <= 0xDBFF) {
      if (i + 1 >= s.length) return true;
      final n = s.codeUnitAt(i + 1);
      if (n < 0xDC00 || n > 0xDFFF) return true;
      i++;
    } else if (c >= 0xDC00 && c <= 0xDFFF) {
      return true;
    }
  }
  return false;
}

void main() {
  // Real lines from the app, plus the nastier sequences a student's own
  // name could contain.
  const lines = [
    '🔥 2 din ho gaye. Shabaash! 🤩',
    'Lagta hai Abba jee ne internet ke paise nahi jama krwaye iss mahiney 😬',
    'Ustu bhi offline ho gaya... aur wo toh owl hai! 🦉',
    'Ek aur din, ek aur qadam. Keep it up! 🚀',
    'Reels ke liye internet full taiz chalta hai tumhara! 📱',
    '👨‍👩‍👧 family',   // ZWJ sequence
    'café ☕',         // combining accent
    'plain ascii only',
    '',
  ];

  test('no cut of any line is ever malformed UTF-16', () {
    for (final line in lines) {
      // One past the end on purpose: the loops run i <= length.
      for (var i = -1; i <= line.characters.length + 1; i++) {
        final cut = typewriterPrefix(line, i);
        expect(
          hasLoneSurrogate(cut),
          isFalse,
          reason: 'cutting "$line" at $i gave a lone surrogate: "$cut"',
        );
      }
    }
  });

  test('the old code-unit cut really was broken', () {
    // Guards the premise. If this ever stops failing, the test above is
    // no longer proving anything.
    const line = '🔥 2 din ho gaye. Shabaash! 🤩';
    final broken = [
      for (var i = 0; i <= line.length; i++) line.substring(0, i),
    ];
    expect(
      broken.any(hasLoneSurrogate),
      isTrue,
      reason: 'substring by code unit should split an emoji',
    );
  });

  test('it still types the whole line out, in order', () {
    const line = 'Ustu bhi offline ho gaya 🦉';
    final steps = [
      for (var i = 0; i <= line.characters.length; i++)
        typewriterPrefix(line, i),
    ];

    expect(steps.first, '');
    expect(steps.last, line);

    // Monotonic: each step is the previous one plus exactly one glyph.
    for (var i = 1; i < steps.length; i++) {
      expect(steps[i].startsWith(steps[i - 1]), isTrue);
      expect(steps[i].characters.length, steps[i - 1].characters.length + 1);
    }
  });

  test('a count past the end returns the line unchanged', () {
    const line = 'short 🚀';
    expect(typewriterPrefix(line, 999), line);
    expect(typewriterPrefix(line, -5), '');
  });
}
