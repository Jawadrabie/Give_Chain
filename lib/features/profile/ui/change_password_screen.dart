import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/async_state.dart';
import '../data/profile_repository.dart';
import '../logic/profile_cubits.dart';
import '../../../core/widgets/app_back_app_bar.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChangePasswordCubit(context.read<ProfileRepository>()),
      child: const _ChangePasswordView(),
    );
  }
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView();

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBackAppBar(title: const Text('تغيير كلمة المرور')),
      body:
          BlocConsumer<ChangePasswordCubit, AsyncState<ProfileOperationResult>>(
            listener: (context, state) {
              if (state.status == AsyncStatus.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.data?.message ?? 'تم التغيير')),
                );
                context.pop(true);
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
                    _passwordField(_current, 'كلمة المرور الحالية'),
                    const SizedBox(height: 14),
                    _passwordField(_next, 'كلمة المرور الجديدة'),
                    const SizedBox(height: 14),
                    _passwordField(_confirm, 'تأكيد كلمة المرور الجديدة'),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: loading ? null : _submit,
                        icon: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_reset),
                        label: Text(
                          loading ? 'جارٍ التغيير...' : 'تغيير كلمة المرور',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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
      validator: (value) {
        final text = value ?? '';
        if (text.length < 8) return 'يجب ألا تقل كلمة المرور عن 8 أحرف';
        return null;
      },
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    if (_next.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمتا المرور الجديدتان غير متطابقتين')),
      );
      return;
    }
    if (_current.text == _next.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر كلمة مرور جديدة مختلفة')),
      );
      return;
    }
    context.read<ChangePasswordCubit>().submit(
      ChangePasswordRequest(
        currentPassword: _current.text,
        newPassword: _next.text,
      ),
    );
  }
}
