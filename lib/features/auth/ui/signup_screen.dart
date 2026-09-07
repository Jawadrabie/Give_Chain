import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/field_validators.dart';
import '../../../core/state/async_state.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import '../data/registration_lookup_models.dart';
import '../data/registration_lookup_repository.dart';
import '../logic/auth_cubits.dart';
import '../logic/registration_lookup_cubit.dart';
import '../../../core/widgets/app_back_app_bar.dart';
import '../../../core/widgets/app_dropdown_form_field.dart';
import '../../../core/widgets/dynamic_answer_field.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => SignUpCubit(context.read<AuthRepository>()),
        ),
        BlocProvider(
          create: (_) => RegistrationLookupCubit(
            context.read<RegistrationLookupRepository>(),
          )..load(),
        ),
      ],
      child: const _SignUpView(),
    );
  }
}

class _SignUpView extends StatefulWidget {
  const _SignUpView();

  @override
  State<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<_SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _userName = TextEditingController();
  final _email = TextEditingController();
  final _nationalNumber = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _infoControllers = <String, TextEditingController>{};

  late Future<List<PersonInfoField>> _infoFieldsFuture;
  DateTime? _birthDate;
  int _gender = 0;
  String? _countryId;
  String? _cityId;
  String? _profileImagePath;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _infoFieldsFuture = context.read<AuthRepository>().infoFields();
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _userName,
      _email,
      _nationalNumber,
      _phoneNumber,
      _password,
      _confirmPassword,
      ..._infoControllers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBackAppBar(
        fallbackRoute: '/welcome',
        title: const Text('إنشاء حساب جديد'),
      ),
      body: BlocConsumer<SignUpCubit, AsyncState<AuthResponse>>(
        listener: (context, state) {
          if (state.status == AsyncStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إنشاء الحساب وتسجيل الدخول بنجاح'),
              ),
            );
            context.go('/home');
          } else if (state.status == AsyncStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message ?? 'تعذر إنشاء الحساب')),
            );
          }
        },
        builder: (context, state) {
          final loading = state.status == AsyncStatus.loading;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
              children: [
                const Text(
                  'بيانات الحساب',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'الحقول الأساسية مطلوبة، ويمكنك إكمال البيانات الشخصية الاختيارية الآن.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _requiredField(_firstName, 'الاسم الأول')),
                    const SizedBox(width: 10),
                    Expanded(child: _requiredField(_lastName, 'اسم العائلة')),
                  ],
                ),
                const SizedBox(height: 12),
                _requiredField(
                  _userName,
                  'اسم المستخدم',
                  icon: Icons.alternate_email,
                ),
                const SizedBox(height: 12),
                _requiredField(
                  _email,
                  'البريد الإلكتروني',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'البريد الإلكتروني مطلوب';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                      return 'أدخل بريدًا إلكترونيًا صحيحًا';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _passwordField(_password, 'كلمة المرور'),
                const SizedBox(height: 12),
                _passwordField(_confirmPassword, 'تأكيد كلمة المرور'),
                const SizedBox(height: 18),
                _sectionTitle('البيانات الشخصية'),
                const SizedBox(height: 12),
                AppDropdownFormField<int>(
                  initialValue: _gender,
                  decoration: const InputDecoration(
                    labelText: 'الجنس',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('ذكر')),
                    DropdownMenuItem(value: 1, child: Text('أنثى')),
                  ],
                  onChanged: loading
                      ? null
                      : (value) => setState(() => _gender = value ?? 0),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nationalNumber,
                  enabled: !loading,
                  decoration: const InputDecoration(
                    labelText: 'الرقم الوطني (اختياري)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneNumber,
                  enabled: !loading,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (اختياري)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: FieldValidators.phoneNumber,
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: loading ? null : _pickBirthDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'تاريخ الميلاد (اختياري)',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _birthDate == null
                                ? 'اختر التاريخ'
                                : DateFormat('yyyy-MM-dd').format(_birthDate!),
                          ),
                        ),
                        if (_birthDate != null)
                          IconButton(
                            onPressed: () => setState(() => _birthDate = null),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                BlocBuilder<RegistrationLookupCubit, RegistrationLookupState>(
                  builder: (context, lookups) {
                    if (lookups.isLoading) {
                      return const LinearProgressIndicator();
                    }
                    return Column(
                      children: [
                        if (lookups.warning != null) ...[
                          _warning(lookups.warning!),
                          const SizedBox(height: 12),
                        ],
                        AppDropdownFormField<String?>(
                          initialValue: _countryId,
                          decoration: const InputDecoration(
                            labelText: 'الدولة (اختياري)',
                            prefixIcon: Icon(Icons.public_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('بدون تحديد'),
                            ),
                            ...lookups.countries.map(
                              (item) => DropdownMenuItem<String?>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            ),
                          ],
                          onChanged: loading
                              ? null
                              : (value) {
                                  setState(() {
                                    _countryId = value;
                                    _cityId = null;
                                  });
                                  context
                                      .read<RegistrationLookupCubit>()
                                      .selectCountry(value);
                                },
                        ),
                        const SizedBox(height: 12),
                        AppDropdownFormField<String?>(
                          initialValue: _cityId,
                          decoration: const InputDecoration(
                            labelText: 'المدينة (اختياري)',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('بدون تحديد'),
                            ),
                            ...lookups.cities.map(
                              (item) => DropdownMenuItem<String?>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            ),
                          ],
                          onChanged: loading || _countryId == null
                              ? null
                              : (value) => setState(() => _cityId = value),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _imagePicker(loading),
                const SizedBox(height: 18),
                FutureBuilder<List<PersonInfoField>>(
                  future: _infoFieldsFuture,
                  builder: (context, snapshot) {
                    final fields = snapshot.data ?? const <PersonInfoField>[];
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LinearProgressIndicator();
                    }
                    if (fields.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionTitle('معلومات إضافية'),
                        const SizedBox(height: 6),
                        Text(
                          'يطلبها النظام لاستكمال ملف المستخدم.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 12),
                        for (final field in fields) ...[
                          DynamicAnswerField(
                            label: field.fieldName,
                            fieldType: field.fieldType,
                            isRequired: field.isRequired,
                            enabled: !loading,
                            controller: _infoControllers.putIfAbsent(
                              field.id,
                              TextEditingController.new,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'إنشاء الحساب',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => AppNavigation.back(
                          context,
                          fallbackRoute: '/login',
                        ),
                  child: const Text('لديك حساب؟ تسجيل الدخول'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _requiredField(
    TextEditingController controller,
    String label, {
    IconData icon = Icons.person_outline,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    validator:
        validator ??
        (value) =>
            value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
  );

  Widget _passwordField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        validator: (value) {
          final text = value ?? '';
          if (text.length < 8) {
            return 'كلمة المرور يجب أن تكون 8 محارف على الأقل';
          }
          if (controller == _confirmPassword && text != _password.text) {
            return 'كلمتا المرور غير متطابقتين';
          }
          return null;
        },
      );

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
  );

  Widget _warning(String message) => Builder(
    builder: (context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningSurfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
    ),
  );

  Widget _imagePicker(bool loading) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.softOf(context),
              backgroundImage: _profileImagePath == null
                  ? null
                  : FileImage(File(_profileImagePath!)),
              child: _profileImagePath == null
                  ? const Icon(Icons.person, color: AppTheme.primary)
                  : null,
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الصورة الشخصية',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('اختيارية، وتُرفع مع طلب التسجيل'),
                ],
              ),
            ),
            TextButton(
              onPressed: loading ? null : _pickImage,
              child: Text(_profileImagePath == null ? 'اختيار' : 'تغيير'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (selected != null) setState(() => _birthDate = selected);
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image != null) setState(() => _profileImagePath = image.path);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<SignUpCubit>().signUp(
      SignUpRequest(
        firstName: _firstName.text,
        lastName: _lastName.text,
        userName: _userName.text,
        email: _email.text,
        password: _password.text,
        birthOfDate: _birthDate,
        nationalNumber: _nationalNumber.text,
        phoneNumber: _phoneNumber.text,
        countryId: _countryId ?? '',
        cityId: _cityId ?? '',
        gender: _gender,
        profileImagePath: _profileImagePath,
        infoAnswers: {
          for (final entry in _infoControllers.entries)
            entry.key: entry.value.text,
        },
      ),
    );
  }
}
