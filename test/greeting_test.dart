import 'package:flutter_test/flutter_test.dart';
import 'package:ustaad/providers/progress_provider.dart';

/// The greeting line on the home screen.
///
/// getGreeting() picks at random from a time-of-day pool and substitutes the
/// student's name. Two things have already gone wrong here in practice:
///
///   1. A pool entry missing its [Name] placeholder, or a name failing to
///      substitute, shows the raw template to the student.
///   2. Because it randomises on every call, any caller that invokes it during
///      build re-randomises the greeting on every frame. That shipped: for a
///      user with no displayName the home screen header changed text
///      constantly and the layout visibly shook.
///
/// The caching that prevents (2) lives in the widget, so what is pinned here
/// is the contract the widget relies on: same call, valid output, name always
/// substituted, whatever the hour.
void main() {
  group('the name placeholder is always resolved', () {
    // Not every line uses the name — plenty are complete sentences on their
    // own ("Raat ka silence, padhai ka best time. Use it."). So the invariant
    // is not "the name always appears", it is "a raw [Name] never does".
    test('no raw [Name] placeholder ever reaches the screen', () {
      for (var i = 0; i < 300; i++) {
        final greeting = getGreeting('Burhan');
        expect(greeting.contains('[Name]'), isFalse,
            reason: 'a pool entry leaked its raw placeholder: "$greeting"');
      }
    });

    test('lines that do use the name substitute it', () {
      // Sampled rather than asserted per call, because which line comes back
      // is random. Across 300 draws at least one name-bearing line will show
      // up in every pool, so a substitution that silently stopped working
      // would fail here.
      final withName = List.generate(300, (_) => getGreeting('Burhan'))
          .where((g) => g.contains('Burhan'))
          .length;
      expect(withName, greaterThan(0),
          reason: 'no line substituted the name in 300 draws — [Name] '
              'substitution is broken');
    });

    test('unusual names do not break substitution', () {
      for (final name in ['A', 'Muhammad Burhan', 'Ali-Raza', "O'Brien", 'Ûsmân']) {
        final drawn = List.generate(200, (_) => getGreeting(name));
        expect(drawn.every((g) => !g.contains('[Name]')), isTrue,
            reason: '"$name" left a placeholder unresolved');
        expect(drawn.any((g) => g.contains(name)), isTrue,
            reason: '"$name" never substituted in 200 draws');
      }
    });
  });

  group('output is always displayable', () {
    test('never empty, never just whitespace', () {
      for (var i = 0; i < 200; i++) {
        final greeting = getGreeting('Student');
        expect(greeting.trim(), isNotEmpty);
      }
    });

    test('stays short enough for a one line header', () {
      // The header is a single line on a 360dp phone. An overlong entry wraps
      // and pushes the layout around, which is what the shaking looked like.
      for (var i = 0; i < 200; i++) {
        final greeting = getGreeting('Burhan');
        expect(greeting.length, lessThan(80),
            reason: 'too long for the home header: "$greeting"');
      }
    });
  });

  group('it really is random, which is why callers must cache it', () {
    test('repeated calls do not always return the same line', () {
      // Documents the behaviour rather than guarding it: this is exactly why
      // _greetingLine caches per name instead of calling through on every
      // build. If this ever starts failing because the pools shrank to one
      // entry each, the caching requirement goes away with it.
      final seen = <String>{};
      for (var i = 0; i < 100; i++) {
        seen.add(getGreeting('Burhan'));
      }
      expect(seen.length, greaterThan(1),
          reason: 'getGreeting is expected to vary; callers cache it because '
              'of that');
    });
  });
}
