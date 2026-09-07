import 'package:flutter_test/flutter_test.dart';
import 'package:give_chain_app/features/profile/data/profile_repository.dart';

void main() {
  test('UserProfile parses documented PersonResponse', () {
    final profile = UserProfile.fromJson({
      'id': 'person-1',
      'firstName': 'سارة',
      'lastName': 'علي',
      'nationalNumber': 'N-1',
      'birthOfDate': '2000-01-01T00:00:00Z',
      'gender': 1,
      'country': {'id': 'country-1', 'countryName': 'سوريا'},
      'city': {'id': 'city-1', 'cityName': 'دمشق'},
      'imagePath': 'https://example.test/me.png',
      'user': {'userName': 'sara', 'email': 'sara@example.com', 'status': 0},
    });

    expect(profile.name, 'سارة علي');
    expect(profile.email, 'sara@example.com');
    expect(profile.countryName, 'سوريا');
    expect(profile.cityName, 'دمشق');
    expect(profile.genderName, 'أنثى');
  });

  test('UpdateProfileRequest emits only documented editable fields', () {
    final json = UpdateProfileRequest(
      firstName: 'Ali',
      lastName: 'Ahmad',
      nationalNumber: 'N-1',
      birthDate: DateTime.utc(2000, 1, 2),
      gender: 0,
      countryId: 'country-id',
      cityId: 'city-id',
    ).toJson();

    expect(json['firstName'], 'Ali');
    expect(json['birthOfDate'], '2000-01-02');
    expect(json['gender'], 0);
    expect(json.containsKey('email'), isFalse);
    expect(json.containsKey('imagePath'), isFalse);
  });

  test('ChangePasswordRequest uses the documented body', () {
    final json = const ChangePasswordRequest(
      currentPassword: 'old-password',
      newPassword: 'new-password',
    ).toJson();

    expect(json, {
      'currentPassword': 'old-password',
      'newPassword': 'new-password',
    });
  });

  test('PersonInfoAnswer reads attachments as documented string URLs', () {
    // The contract documents a plain string[]; a Map-only parse silently
    // yielded an empty list and hid every attachment.
    final answer = PersonInfoAnswer.fromJson({
      'id': 'answer-1',
      'personId': 'person-1',
      'fieldId': 'field-1',
      'fieldName': 'إثبات السكن',
      'answer': '',
      'attachments': [
        'https://cdn.example.test/a.pdf',
        'https://cdn.example.test/b.png',
      ],
    });

    expect(answer.attachments, [
      'https://cdn.example.test/a.pdf',
      'https://cdn.example.test/b.png',
    ]);
  });

  test('PersonInfoAnswer also tolerates media-object attachments', () {
    final answer = PersonInfoAnswer.fromJson({
      'id': 'answer-2',
      'personId': 'person-1',
      'fieldId': 'field-2',
      'fieldName': 'مرفق',
      'answer': '',
      'attachments': [
        {'id': 'm1', 'url': 'https://cdn.example.test/c.jpg'},
      ],
    });

    expect(answer.attachments, ['https://cdn.example.test/c.jpg']);
  });
}
