import '../../../core/network/json_helpers.dart';

class LoginRequest {
  const LoginRequest({
    required this.userName,
    required this.email,
    required this.password,
  });

  final String userName;
  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
    'userName': userName.trim(),
    'email': email.trim(),
    'password': password,
  };
}

class SignUpRequest {
  const SignUpRequest({
    required this.firstName,
    required this.lastName,
    required this.userName,
    required this.email,
    required this.password,
    required this.gender,
    this.birthOfDate,
    this.nationalNumber = '',
    this.phoneNumber = '',
    this.countryId = '',
    this.cityId = '',
    this.profileImagePath,
    this.infoAnswers = const {},
  });

  final String firstName;
  final String lastName;
  final String userName;
  final String email;
  final String password;
  final DateTime? birthOfDate;
  final String nationalNumber;

  /// Optional on the API; omitted from the request when blank.
  final String phoneNumber;
  final String countryId;
  final String cityId;
  final int gender;
  final String? profileImagePath;
  final Map<String, String> infoAnswers;

  Map<String, dynamic> toMultipartFields() => {
    'FirstName': firstName.trim(),
    'LastName': lastName.trim(),
    'Username': userName.trim(),
    'Email': email.trim(),
    'Password': password,
    'Gender': gender,
    if (birthOfDate != null) 'BirthOfDate': birthOfDate!.toIso8601String(),
    if (nationalNumber.trim().isNotEmpty)
      'NationalNumber': nationalNumber.trim(),
    if (phoneNumber.trim().isNotEmpty) 'PhoneNumber': phoneNumber.trim(),
    if (countryId.trim().isNotEmpty) 'CountryId': countryId.trim(),
    if (cityId.trim().isNotEmpty) 'CityId': cityId.trim(),
  };
}

class AuthResponse {
  const AuthResponse({
    required this.message,
    this.userId = '',
    this.token,
    this.email = '',
    this.fullName = '',
    this.userName = '',
    this.phoneNumber = '',
    this.userType,
    this.userStatus,
    this.isAdmin = false,
    this.roleId,
    this.role,
    this.permissions = const [],
  });

  final String message;
  final String userId;
  final String? token;
  final String email;
  final String fullName;
  final String userName;

  /// Empty for accounts created before the field existed, until the user
  /// fills it in from the profile screen.
  final String phoneNumber;
  final int? userType;
  final int? userStatus;
  final bool isAdmin;
  final String? roleId;
  final String? role;
  final List<String> permissions;

  factory AuthResponse.fromJson(dynamic raw) {
    final data = JsonHelpers.unwrap(raw);
    final json = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    final root = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final permissionsRaw = json['permissions'];
    return AuthResponse(
      message: JsonHelpers.text(root, const [
        'message',
      ], fallback: 'تمت العملية بنجاح'),
      userId: JsonHelpers.text(json, const ['userId', 'id']),
      token: _nullable(json['token']),
      email: JsonHelpers.text(json, const ['email']),
      fullName: JsonHelpers.text(json, const ['fullName']),
      userName: JsonHelpers.text(json, const ['userName']),
      phoneNumber: JsonHelpers.text(json, const ['phoneNumber', 'phone']),
      userType: _int(json['userType']),
      userStatus: _int(json['userStatus']),
      isAdmin: JsonHelpers.boolean(json, const ['isAdmin']),
      roleId: _nullable(json['roleId']),
      role: _nullable(json['role']),
      permissions: permissionsRaw is List
          ? permissionsRaw.map((value) => value.toString()).toList()
          : const [],
    );
  }
}

class PersonInfoField {
  const PersonInfoField({
    required this.id,
    required this.fieldName,
    required this.fieldType,
    required this.isRequired,
  });

  final String id;
  final String fieldName;
  final int fieldType;
  final bool isRequired;

  factory PersonInfoField.fromJson(Map<String, dynamic> json) =>
      PersonInfoField(
        id: JsonHelpers.text(json, const ['id']),
        fieldName: JsonHelpers.text(json, const [
          'fieldName',
          'name',
        ], fallback: 'معلومة إضافية'),
        fieldType: _int(json['fieldType']) ?? 0,
        isRequired: JsonHelpers.boolean(json, const ['isRequired']),
      );
}

class PasswordResetRequestResult {
  const PasswordResetRequestResult({required this.message});
  final String message;

  factory PasswordResetRequestResult.fromJson(dynamic raw) {
    final root = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return PasswordResetRequestResult(
      message: JsonHelpers.text(root, const [
        'message',
      ], fallback: 'تمت العملية بنجاح.'),
    );
  }
}

class ResetPasswordRequest {
  const ResetPasswordRequest({
    required this.email,
    required this.code,
    required this.newPassword,
  });

  final String email;
  final String code;
  final String newPassword;

  // The contract is ambiguous: API_MOBILE.md documents `Token`, while the
  // older mobile guide documents `code` (and lists the two as an open
  // question). Sending both keeps the reset flow working under either DTO —
  // ASP.NET model binding ignores a property it does not declare. Drop the
  // redundant key once the backend confirms (BACKEND_QUESTIONS_R2.md #9).
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'token': code.trim(),
    'code': code.trim(),
    'newPassword': newPassword,
  };
}

String? _nullable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? null : text;
}

int? _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
