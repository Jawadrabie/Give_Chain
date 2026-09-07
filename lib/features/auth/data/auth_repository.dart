import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_helpers.dart';
import '../../../core/storage/token_storage.dart';
import 'auth_models.dart';

class AuthRepository {
  const AuthRepository(this._client);
  final ApiClient _client;

  Future<AuthResponse> login(LoginRequest request) async {
    final raw = await _client.post(
      ApiPaths.login,
      body: request.toJson(),
      requiresAuth: false,
    );
    final response = AuthResponse.fromJson(raw);
    final token = response.token?.trim() ?? '';
    if (token.isEmpty) {
      throw const ApiFailure('لم يرجع الخادم رمز جلسة صالحًا.');
    }
    await TokenStorage.saveToken(token);
    return response;
  }

  Future<AuthResponse> signUp(SignUpRequest request) async {
    final raw = await _client.multipart(
      'POST',
      ApiPaths.signup,
      fields: request.toMultipartFields(),
      filePath: request.profileImagePath,
      fileField: 'ProfileImage',
      requiresAuth: false,
    );
    final response = AuthResponse.fromJson(raw);
    final token = response.token?.trim() ?? '';
    if (token.isEmpty) {
      throw const ApiFailure(
        'تم إنشاء الحساب لكن الخادم لم يرجع رمز جلسة صالحًا.',
      );
    }
    await TokenStorage.saveToken(token);
    await TokenStorage.setRememberSession(true);
    for (final entry in request.infoAnswers.entries) {
      if (entry.value.trim().isEmpty) continue;
      try {
        await _client.put(
          ApiPaths.profileInfoAnswers,
          body: {'fieldId': entry.key, 'answer': entry.value.trim()},
        );
      } catch (_) {
        // Registration itself succeeded. The user can complete this answer
        // later from Profile > My information answers.
      }
    }
    return response;
  }

  Future<List<PersonInfoField>> infoFields() async {
    final raw = await _client.get(
      ApiPaths.infoFields,
      requiresAuth: false,
      cacheTtl: const Duration(hours: 6),
    );
    return JsonHelpers.objectList(raw).map(PersonInfoField.fromJson).toList();
  }

  Future<PasswordResetRequestResult> requestPasswordReset(String email) async {
    final raw = await _client.post(
      ApiPaths.forgotPassword,
      body: {'email': email.trim()},
      requiresAuth: false,
    );
    return PasswordResetRequestResult.fromJson(raw);
  }

  Future<PasswordResetRequestResult> resetPassword(
    ResetPasswordRequest request,
  ) async {
    final raw = await _client.post(
      ApiPaths.resetPassword,
      body: request.toJson(),
      requiresAuth: false,
    );
    return PasswordResetRequestResult.fromJson(raw);
  }
}
