import '../../../core/config/api_paths.dart';
import '../../../core/constants/api_enums.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_helpers.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.userName,
    required this.gender,
    this.nationalNumber = '',
    this.phoneNumber = '',
    this.countryId = '',
    this.countryName = '',
    this.cityId = '',
    this.cityName = '',
    this.imageUrl = '',
    this.birthDate,
    this.userStatus,
    this.userType,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String userName;
  final int gender;
  final String nationalNumber;

  /// Optional on the API; empty for accounts created before it existed.
  final String phoneNumber;
  final String countryId;
  final String countryName;
  final String cityId;
  final String cityName;
  final String imageUrl;
  final DateTime? birthDate;
  final int? userStatus;
  final int? userType;

  String get name {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? (userName.isEmpty ? 'المستخدم' : userName) : value;
  }

  String get genderName => ApiEnums.gender[gender] ?? 'غير محدد';
  String get statusName => userStatus == null
      ? 'غير محدد'
      : ApiEnums.userStatus[userStatus!] ?? 'غير معروف';
  String get userTypeName => userType == null
      ? 'غير محدد'
      : ApiEnums.userType[userType!] ?? 'غير معروف';

  factory UserProfile.fromJson(Map<String, dynamic> source) {
    final userRaw = source['user'];
    final user = userRaw is Map
        ? Map<String, dynamic>.from(userRaw)
        : <String, dynamic>{};
    final countryRaw = source['country'];
    final country = countryRaw is Map
        ? Map<String, dynamic>.from(countryRaw)
        : <String, dynamic>{};
    final cityRaw = source['city'];
    final city = cityRaw is Map
        ? Map<String, dynamic>.from(cityRaw)
        : <String, dynamic>{};
    return UserProfile(
      id: JsonHelpers.text(source, const ['id']),
      firstName: JsonHelpers.text(source, const ['firstName']),
      lastName: JsonHelpers.text(source, const ['lastName']),
      email: JsonHelpers.text(user, const ['email']),
      userName: JsonHelpers.text(user, const ['userName', 'username']),
      gender: _int(source['gender']) ?? 0,
      nationalNumber: JsonHelpers.text(source, const ['nationalNumber']),
      // The API puts it on the person; some payloads nest it on the user.
      phoneNumber: JsonHelpers.text(
        source,
        const ['phoneNumber', 'phone'],
        fallback: JsonHelpers.text(user, const ['phoneNumber', 'phone']),
      ),
      countryId: JsonHelpers.text(country, const ['id']),
      countryName: JsonHelpers.text(country, const ['countryName', 'name']),
      cityId: JsonHelpers.text(city, const ['id']),
      cityName: JsonHelpers.text(city, const ['cityName', 'name']),
      imageUrl: JsonHelpers.text(source, const ['imagePath']),
      birthDate: _date(source['birthOfDate']),
      userStatus: _int(user['status'] ?? user['userStatus']),
      userType: _int(source['userType'] ?? user['userType']),
    );
  }
}

class UpdateProfileRequest {
  const UpdateProfileRequest({
    this.firstName,
    this.lastName,
    this.nationalNumber,
    this.phoneNumber,
    this.birthDate,
    this.gender,
    this.countryId,
    this.cityId,
  });

  final String? firstName;
  final String? lastName;
  final String? nationalNumber;
  final String? phoneNumber;
  final DateTime? birthDate;
  final int? gender;
  final String? countryId;
  final String? cityId;

  Map<String, dynamic> toJson() => {
    if (firstName != null) 'firstName': firstName!.trim(),
    if (lastName != null) 'lastName': lastName!.trim(),
    if (nationalNumber != null) 'nationalNumber': nationalNumber!.trim(),
    // Sent even when blank so the user can clear a number they saved before.
    if (phoneNumber != null)
      'phoneNumber': phoneNumber!.trim().isEmpty ? null : phoneNumber!.trim(),
    if (birthDate != null)
      'birthOfDate': birthDate!.toIso8601String().split('T').first,
    if (gender != null) 'gender': gender,
    'countryId': countryId?.trim().isEmpty == true ? null : countryId?.trim(),
    'cityId': cityId?.trim().isEmpty == true ? null : cityId?.trim(),
  };
}

class ChangePasswordRequest {
  const ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });
  final String currentPassword;
  final String newPassword;
  Map<String, dynamic> toJson() => {
    'currentPassword': currentPassword,
    'newPassword': newPassword,
  };
}

class PersonInfoAnswer {
  const PersonInfoAnswer({
    required this.id,
    required this.personId,
    required this.fieldId,
    required this.fieldName,
    required this.answer,
    this.attachments = const [],
  });
  final String id;
  final String personId;
  final String fieldId;
  final String fieldName;
  final String answer;
  final List<String> attachments;

  factory PersonInfoAnswer.fromJson(Map<String, dynamic> json) =>
      PersonInfoAnswer(
        id: JsonHelpers.text(json, const ['id']),
        personId: JsonHelpers.text(json, const ['personId']),
        fieldId: JsonHelpers.text(json, const ['fieldId']),
        fieldName: JsonHelpers.text(json, const ['fieldName']),
        answer: JsonHelpers.text(json, const ['answer']),
        // The API documents `attachments` as a plain string[] of URLs, but
        // tolerate media objects too so either shape parses.
        attachments: (json['attachments'] as List? ?? const [])
            .map(
              (item) => item is Map
                  ? JsonHelpers.text(
                      Map<String, dynamic>.from(item),
                      const ['url', 'fileUrl', 'path'],
                    )
                  : item.toString().trim(),
            )
            .where((url) => url.isNotEmpty && url != 'null')
            .toList(),
      );
}

class ProfileOperationResult {
  const ProfileOperationResult(this.message);
  final String message;
  factory ProfileOperationResult.fromJson(dynamic raw) {
    final root = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return ProfileOperationResult(
      JsonHelpers.text(root, const [
        'message',
      ], fallback: 'تم حفظ التغييرات بنجاح'),
    );
  }
}

class ProfileRepository {
  const ProfileRepository(this._client);
  final ApiClient _client;

  Future<UserProfile> getProfile() async {
    final raw = JsonHelpers.unwrap(await _client.get(ApiPaths.profile));
    if (raw is! Map) throw const ApiFailure('تعذر قراءة الملف الشخصي.');
    return UserProfile.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<ProfileOperationResult> updateProfile(
    UpdateProfileRequest request,
  ) async {
    final raw = await _client.put(ApiPaths.profile, body: request.toJson());
    return ProfileOperationResult.fromJson(raw);
  }

  Future<ProfileOperationResult> changePassword(
    ChangePasswordRequest request,
  ) async {
    final raw = await _client.put(
      ApiPaths.profilePassword,
      body: request.toJson(),
    );
    return ProfileOperationResult.fromJson(raw);
  }

  Future<List<PersonInfoAnswer>> infoAnswers() async {
    final raw = await _client.get(ApiPaths.profileInfoAnswers);
    return JsonHelpers.objectList(raw).map(PersonInfoAnswer.fromJson).toList();
  }

  Future<ProfileOperationResult> upsertInfoAnswer({
    required String fieldId,
    required String answer,
  }) async {
    final raw = await _client.put(
      ApiPaths.profileInfoAnswers,
      body: {'fieldId': fieldId.trim(), 'answer': answer.trim()},
    );
    return ProfileOperationResult.fromJson(raw);
  }
}

int? _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
DateTime? _date(dynamic value) => DateTime.tryParse(value?.toString() ?? '');
