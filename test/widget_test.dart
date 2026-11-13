
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/profile/orbit_profile.dart';

void main() {
  group('ORBIT Zodiac Service', () {
    test('Should return Cancer for July 16', () {
      final result = ZodiacService.fromBirthday(7, 16);

      expect(result, 'Cancer');
    });

    test('Should return Aries for March 21', () {
      final result = ZodiacService.fromBirthday(3, 21);

      expect(result, 'Aries');
    });

    test('Should reject invalid birthdays', () {
      expect(
            () => ZodiacService.fromBirthday(2, 30),
        throwsArgumentError,
      );
    });
  });
}
