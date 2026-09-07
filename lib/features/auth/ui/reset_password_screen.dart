import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/async_state.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import '../logic/auth_cubits.dart';
import '../../../core/widgets/app_back_app_bar.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({
    super.key,
    this.initialEmail = '',
    this.initialCode = '',
  });

  final String initialEmail;
  final String initialCode;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ResetPasswordCubit(context.read<AuthRepository>()),
    child: _ResetPasswordView(
      initialEmail: initialEmail,
      initialCode: initialCode,
    ),
  );
}

class _ResetPasswordView extends StatefulWidget {
  const _ResetPasswordView({
    required this.initialEmail,
    required this.initialCode,
  });
  final String initialEmail;
  final String initialCode;

  @override
  State<_ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<_ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _code;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
    _code = TextEditingController(text: widget.initialCode);
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمتا المرور غير متطابقتين.')),
      );
      return;
    }
    context.read<ResetPasswordCubit>().reset(
      ResetPasswordRequest(
        email: _email.text,
        code: _code.text,
        newPassword: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(
      fallbackRoute: '/welcome',
      title: const Text('تعيين كلمة مرور جديدة'),
    ),
    body:
        BlocConsumer<
          ResetPasswordCubit,
          AsyncState<PasswordResetRequestResult>
        >(
          listener: (context, state) {
            if (state.status == AsyncStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.data?.message ?? 'تم تغيير كلمة المرور بنجاح.',
                  ),
                ),
              );
              context.go('/login');
            } else if (state.status == AsyncStatus.failure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'تعذر تغيير كلمة المرور'),
                ),
              );
            }
          },
          builder: (context, state) {
            final loading = state.status == AsyncStatus.loading;
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(Icons.lock_reset, size: 70),
                  const SizedBox(height: 12),
                  const Text(
                    'أدخل البريد والرمز الذي وصلك ثم اختر كلمة مرور قوية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    enabled: !loading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      return !text.contains('@') ? 'أدخل بريدًا صحيحًا' : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _code,
                    enabled: !loading,
                    decoration: const InputDecoration(
                      labelText: 'رمز الاستعادة',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'أدخل رمز الاستعادة'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _passwordField(_password, 'كلمة المرور الجديدة', loading),
                  const SizedBox(height: 14),
                  _passwordField(_confirm, 'تأكيد كلمة المرور', loading),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: loading ? null : _submit,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        loading ? 'جارٍ التغيير...' : 'حفظ كلمة المرور',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
  );

  Widget _passwordField(
    TextEditingController controller,
    String label,
    bool loading,
  ) => TextFormField(
    controller: controller,
    enabled: !loading,
    obscureText: _obscure,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
    validator: (value) => value == null || value.length < 8
        ? 'يجب ألا تقل كلمة المرور عن 8 أحرف'
        : null,
  );
}
