import 'package:flutter_test/flutter_test.dart';
import 'package:murassikh_app/features/settings/models/user_settings.dart';

void main() {
  group('UserSettings Model Tests', () {
    test('Should correctly create a model with age and gender', () {
      final settings = UserSettings(
        name: "test",
        email: "test@test.com",
        age: 25,
        gender: 'male',
        preferredLanguage: 'ar',
      );

      expect(settings.age, 25);
      expect(settings.gender, 'male');
      expect(settings.preferredLanguage, 'ar');
    });

    test('Should correctly parse from JSON and to JSON', () {
      final jsonMap = {
        'age': 30,
        'gender': 'female',
        'preferredLanguage': 'en',
      };

      final settings = UserSettings.fromJson(jsonMap);
      expect(settings.age, 30);
      expect(settings.gender, 'female');

      final serialized = settings.toJson();
      expect(serialized['age'], 30);
      expect(serialized['gender'], 'female');
    });

    test('copyWith should update fields correctly', () {
      final settings = UserSettings(
        name: "test",
        email: "test@test.com",
        age: 20,
      );
      final updated = settings.copyWith(age: 21, gender: 'male');

      expect(updated.age, 21);
      expect(updated.gender, 'male');
      expect(updated.preferredLanguage, 'ar'); // defaults
    });

    test('preserves the 30-second auto-lock value', () {
      final settings = UserSettings(
        name: 'test',
        email: 'test@test.com',
        autoLockTimeoutMinutes: 0.5,
      );

      final restored = UserSettings.fromJson(settings.toJson());

      expect(restored.autoLockTimeoutMinutes, 0.5);
    });
  });
}
