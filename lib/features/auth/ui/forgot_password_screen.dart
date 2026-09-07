import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/async_state.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import '../logic/auth_cubits.dart';
import '../../../core/widgets/app_back_app_bar.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
    this.initialToken = '',
  });

  final String initialEmail;
  final String initialToken;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AuthRepository>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ForgotPasswordCubit(repository)),
        BlocProvider(create: (_) => ResetPasswordCubit(repository)),
      ],
      child: _ForgotPasswordView(
        initialEmail: initialEmail,
        initialToken: initialToken,
      ),
    );
  }
}

class _ForgotPasswordView extends StatefulWidget {
  const _ForgotPasswordView({
    required this.initialEmail,
    required this.initialToken,
  });

  final String initialEmail;
  final String initialToken;

  @override
  State<_ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<_ForgotPasswordView> {
  final _requestKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _token;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showResetForm = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
    _token = TextEditingController(text: widget.initialToken);
    _showResetForm = widget.initialToken.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBackAppBar(
        fallbackRoute: '/welcome',
        title: const Text('استعادة كلمة المرور'),
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<
            ForgotPasswordCubit,
            AsyncState<PasswordResetRequestResult>
          >(
            listener: (context, state) {
              if (state.status == AsyncStatus.success) {
                setState(() => _showResetForm = true);
                _showMessage(
                  state.data?.message ?? 'تم إرسال تعليمات الاستعادة.',
                );
              } else if (state.status == AsyncStatus.failure) {
                _showMessage(state.message ?? 'تعذر إرسال الطلب.');
              }
            },
          ),
          BlocListener<
            ResetPasswordCubit,
            AsyncState<PasswordResetRequestResult>
          >(
            listener: (context, state) {
              if (state.status == AsyncStatus.success) {
                _showMessage(
                  state.data?.message ?? 'تم تغيير كلمة المرور بنجاح.',
                );
                context.go('/login');
              } else if (state.status == AsyncStatus.failure) {
                _showMessage(state.message ?? 'تعذر تغيير كلمة المرور.');
              }
            },
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.lock_reset, size: 72),
            const SizedBox(height: 14),
            const Text(
              'أدخل بريد الحساب لإرسال رابط أو رمز الاستعادة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, height: 1.6),
            ),
            const SizedBox(height: 24),
            Form(
              key: _requestKey,
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _emailValidator,
              ),
            ),
            const SizedBox(height: 14),
            BlocBuilder<
              ForgotPasswordCubit,
              AsyncState<PasswordResetRequestResult>
            >(
              builder: (context, state) => SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: state.status == AsyncStatus.loading
                      ? null
                      : _requestReset,
                  icon: state.status == AsyncStatus.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('إرسال تعليمات الاستعادة'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _showResetForm = !_showResetForm),
              child: Text(
                _showResetForm
                    ? 'إخفاء نموذج إدخال الرمز'
                    : 'لدي رمز لإعادة التعيين',
              ),
            ),
            if (_showResetForm) ...[
              const Divider(height: 32),
              Form(
                key: _resetKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _token,
                      decoration: const InputDecoration(
                        labelText: 'رمز الاستعادة',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'أدخل رمز الاستعادة'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _passwordField(_password, 'كلمة المرور الجديدة'),
                    const SizedBox(height: 14),
                    _passwordField(_confirm, 'تأكيد كلمة المرور'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              BlocBuilder<
                ResetPasswordCubit,
                AsyncState<PasswordResetRequestResult>
              >(
                builder: (context, state) => SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: state.status == AsyncStatus.loading
                        ? null
                        : _reset,
                    icon: const Icon(Icons.password_outlined),
                    label: Text(
                      state.status == AsyncStatus.loading
                          ? 'جارٍ التغيير...'
                          : 'تعيين كلمة مرور جديدة',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _passwordField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: (value) => value == null || value.length < 8
          ? 'يجب ألا تقل كلمة المرور عن 8 أحرف'
          : null,
    );
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || !text.contains('@') || !text.contains('.')) {
      return 'أدخل بريدًا إلكترونيًا صحيحًا';
    }
    return null;
  }

  void _requestReset() {
    if (_requestKey.currentState?.validate() != true) return;
    context.read<ForgotPasswordCubit>().request(_email.text);
  }

  void _reset() {
    if (_requestKey.currentState?.validate() != true ||
        _resetKey.currentState?.validate() != true) {
      return;
    }
    if (_password.text != _confirm.text) {
      _showMessage('كلمتا المرور غير متطابقتين.');
      return;
    }
    context.read<ResetPasswordCubit>().reset(
      ResetPasswordRequest(
        email: _email.text,
        code: _token.text,
        newPassword: _password.text,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
