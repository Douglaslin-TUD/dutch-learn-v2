import 'package:flutter_test/flutter_test.dart';
import 'package:dutch_learn_app/core/extensions/duration_extension.dart';

void main() {
  group('DurationExtension', () {
    group('formatted', () {
      test('returns MM:SS for typical duration', () {
        expect(
          const Duration(minutes: 2, seconds: 35).formatted,
          '02:35',
        );
      });

      test('pads single-digit seconds with zero', () {
        expect(const Duration(seconds: 5).formatted, '00:05');
      });

      test('pads single-digit minutes with zero', () {
        expect(const Duration(minutes: 3).formatted, '03:00');
      });

      test('handles double-digit minutes', () {
        expect(const Duration(minutes: 10).formatted, '10:00');
      });

      test('wraps minutes at 60 (shows remainder)', () {
        // 65 minutes = 1 hour 5 minutes, remainder is 05
        expect(const Duration(minutes: 65, seconds: 12).formatted, '05:12');
      });

      test('returns 00:00 for zero duration', () {
        expect(Duration.zero.formatted, '00:00');
      });
    });

    group('formattedWithHours', () {
      test('includes hours when duration has hours', () {
        expect(
          const Duration(hours: 1, minutes: 5, seconds: 30).formattedWithHours,
          '1:05:30',
        );
      });

      test('falls back to MM:SS when no hours', () {
        expect(
          const Duration(minutes: 5, seconds: 30).formattedWithHours,
          '05:30',
        );
      });

      test('handles multi-digit hours', () {
        expect(
          const Duration(hours: 12, minutes: 0, seconds: 5).formattedWithHours,
          '12:00:05',
        );
      });

      test('returns 00:00 for zero duration', () {
        expect(Duration.zero.formattedWithHours, '00:00');
      });
    });

    group('compact', () {
      test('returns Xm Ys for durations with minutes', () {
        expect(const Duration(minutes: 2, seconds: 35).compact, '2m 35s');
      });

      test('returns Xs for durations under a minute', () {
        expect(const Duration(seconds: 45).compact, '45s');
      });

      test('returns Xh Ym for durations with hours', () {
        expect(const Duration(hours: 1, minutes: 30).compact, '1h 30m');
      });

      test('returns 0s for zero duration', () {
        expect(Duration.zero.compact, '0s');
      });

      test('shows 0s remainder in minutes format', () {
        expect(const Duration(minutes: 5).compact, '5m 0s');
      });

      test('shows 0m remainder in hours format', () {
        expect(const Duration(hours: 2).compact, '2h 0m');
      });
    });

    group('asSecondsString', () {
      test('returns seconds with one decimal place', () {
        expect(
          const Duration(seconds: 5, milliseconds: 500).asSecondsString,
          '5.5',
        );
      });

      test('returns whole seconds with .0', () {
        expect(const Duration(seconds: 10).asSecondsString, '10.0');
      });

      test('returns 0.0 for zero duration', () {
        expect(Duration.zero.asSecondsString, '0.0');
      });

      test('rounds to one decimal place', () {
        expect(
          const Duration(milliseconds: 1234).asSecondsString,
          '1.2',
        );
      });
    });

    group('asSeconds', () {
      test('returns seconds as double', () {
        expect(
          const Duration(seconds: 5, milliseconds: 500).asSeconds,
          5.5,
        );
      });

      test('returns 0.0 for zero duration', () {
        expect(Duration.zero.asSeconds, 0.0);
      });

      test('handles sub-second durations', () {
        expect(const Duration(milliseconds: 250).asSeconds, 0.25);
      });
    });

    group('fromSeconds', () {
      test('creates Duration from double seconds', () {
        final d = DurationExtension.fromSeconds(2.5);
        expect(d.inMilliseconds, 2500);
      });

      test('creates Duration from whole seconds', () {
        final d = DurationExtension.fromSeconds(3.0);
        expect(d.inMilliseconds, 3000);
      });

      test('creates zero Duration from 0', () {
        final d = DurationExtension.fromSeconds(0);
        expect(d, Duration.zero);
      });

      test('rounds fractional milliseconds', () {
        // 1.2345 seconds = 1234.5 ms, rounds to 1235
        final d = DurationExtension.fromSeconds(1.2345);
        expect(d.inMilliseconds, 1235);
      });
    });

    group('isWithin', () {
      test('returns true when duration is within range', () {
        const d = Duration(seconds: 5);
        expect(
          d.isWithin(const Duration(seconds: 3), const Duration(seconds: 7)),
          isTrue,
        );
      });

      test('returns false when duration is before range', () {
        const d = Duration(seconds: 2);
        expect(
          d.isWithin(const Duration(seconds: 3), const Duration(seconds: 7)),
          isFalse,
        );
      });

      test('returns false when duration is after range', () {
        const d = Duration(seconds: 5);
        expect(
          d.isWithin(const Duration(seconds: 6), const Duration(seconds: 8)),
          isFalse,
        );
      });

      test('returns true when duration equals start boundary', () {
        const d = Duration(seconds: 3);
        expect(
          d.isWithin(const Duration(seconds: 3), const Duration(seconds: 7)),
          isTrue,
        );
      });

      test('returns true when duration equals end boundary', () {
        const d = Duration(seconds: 7);
        expect(
          d.isWithin(const Duration(seconds: 3), const Duration(seconds: 7)),
          isTrue,
        );
      });
    });

    group('clamp', () {
      test('returns max when duration exceeds max', () {
        const d = Duration(seconds: 10);
        expect(
          d.clamp(const Duration(seconds: 0), const Duration(seconds: 5)),
          const Duration(seconds: 5),
        );
      });

      test('returns min when duration is below min', () {
        const d = Duration(seconds: 1);
        expect(
          d.clamp(const Duration(seconds: 3), const Duration(seconds: 10)),
          const Duration(seconds: 3),
        );
      });

      test('returns duration when within range', () {
        const d = Duration(seconds: 10);
        expect(
          d.clamp(const Duration(seconds: 0), const Duration(seconds: 15)),
          const Duration(seconds: 10),
        );
      });

      test('returns duration when equal to min', () {
        const d = Duration(seconds: 5);
        expect(
          d.clamp(const Duration(seconds: 5), const Duration(seconds: 10)),
          const Duration(seconds: 5),
        );
      });

      test('returns duration when equal to max', () {
        const d = Duration(seconds: 10);
        expect(
          d.clamp(const Duration(seconds: 5), const Duration(seconds: 10)),
          const Duration(seconds: 10),
        );
      });
    });

    group('addPercent', () {
      test('adds percentage of duration', () {
        const d = Duration(seconds: 10);
        // 50% of 10s = 5s, total = 15s
        expect(d.addPercent(50).inSeconds, 15);
      });

      test('adds 100% to double the duration', () {
        const d = Duration(seconds: 10);
        expect(d.addPercent(100).inSeconds, 20);
      });

      test('adds 0% leaving duration unchanged', () {
        const d = Duration(seconds: 10);
        expect(d.addPercent(0), const Duration(seconds: 10));
      });
    });

    group('percentOf', () {
      test('calculates percentage relative to total', () {
        const part = Duration(seconds: 30);
        const total = Duration(seconds: 120);
        // 30/120 * 100 = 25.0
        expect(part.percentOf(total), closeTo(25.0, 0.001));
      });

      test('returns 100 when equal to total', () {
        const d = Duration(seconds: 60);
        expect(d.percentOf(const Duration(seconds: 60)), closeTo(100.0, 0.001));
      });

      test('returns 0 when total is zero', () {
        const d = Duration(seconds: 30);
        expect(d.percentOf(Duration.zero), 0);
      });

      test('returns 50 for half duration', () {
        const d = Duration(seconds: 5);
        expect(d.percentOf(const Duration(seconds: 10)), closeTo(50.0, 0.001));
      });
    });

    group('multiply', () {
      test('scales duration by factor', () {
        const d = Duration(seconds: 10);
        expect(d.multiply(1.5).inMilliseconds, 15000);
      });

      test('doubles duration with factor 2', () {
        const d = Duration(seconds: 5);
        expect(d.multiply(2.0), const Duration(seconds: 10));
      });

      test('returns zero when factor is 0', () {
        const d = Duration(seconds: 10);
        expect(d.multiply(0), Duration.zero);
      });

      test('halves duration with factor 0.5', () {
        const d = Duration(seconds: 10);
        expect(d.multiply(0.5).inMilliseconds, 5000);
      });
    });

    group('divide', () {
      test('divides duration by factor', () {
        const d = Duration(seconds: 10);
        expect(d.divide(2.0).inMilliseconds, 5000);
      });

      test('returns zero when factor is 0', () {
        const d = Duration(seconds: 10);
        expect(d.divide(0), Duration.zero);
      });

      test('returns same duration when factor is 1', () {
        const d = Duration(seconds: 10);
        expect(d.divide(1.0), const Duration(seconds: 10));
      });

      test('handles fractional divisor', () {
        const d = Duration(seconds: 10);
        // 10 / 0.5 = 20 seconds
        expect(d.divide(0.5).inMilliseconds, 20000);
      });
    });
  });

  group('DoubleToDuration', () {
    test('seconds converts double to Duration', () {
      expect(2.5.seconds.inMilliseconds, 2500);
    });

    test('seconds handles whole numbers', () {
      expect(3.0.seconds, const Duration(seconds: 3));
    });

    test('milliseconds converts double to Duration', () {
      expect(1500.0.milliseconds, const Duration(milliseconds: 1500));
    });

    test('minutes converts double to Duration (rounds)', () {
      // 1.5 rounds to 2, so Duration(minutes: 2)
      expect(1.5.minutes, const Duration(minutes: 2));
    });

    test('minutes converts whole number to Duration', () {
      expect(3.0.minutes, const Duration(minutes: 3));
    });

    test('hours converts double to Duration (rounds)', () {
      // 1.5 rounds to 2, so Duration(hours: 2)
      expect(1.5.hours, const Duration(hours: 2));
    });

    test('hours converts whole number to Duration', () {
      expect(2.0.hours, const Duration(hours: 2));
    });
  });

  group('IntToDuration', () {
    test('seconds converts int to Duration', () {
      expect(5.seconds, const Duration(seconds: 5));
    });

    test('milliseconds converts int to Duration', () {
      expect(500.milliseconds, const Duration(milliseconds: 500));
    });

    test('minutes converts int to Duration', () {
      expect(2.minutes, const Duration(minutes: 2));
    });

    test('hours converts int to Duration', () {
      expect(3.hours, const Duration(hours: 3));
    });

    test('zero seconds returns zero Duration', () {
      expect(0.seconds, Duration.zero);
    });
  });
}
