import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/field_validators.dart';
import '../../../core/state/async_state.dart';
import '../../auth/data/registration_lookup_models.dart';
import '../../auth/data/registration_lookup_repository.dart';
import '../data/profile_repository.dart';
import '../logic/profile_cubits.dart';
import '../../../core/widgets/app_back_app_bar.dart';
import '../../../core/widgets/app_dropdown_form_field.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key, this.profile});
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final value = profile;
    if (value != null) return _provider(context, value);
    return _EditProfileLoader(
      loader: context.read<ProfileRepository>().getProfile,
    );
  }

  Widget _provider(BuildContext context, UserProfile value) => BlocProvider(
    create: (_) => UpdateProfileCubit(context.read<ProfileRepository>()),
    child: _EditProfileView(profile: value),
  );
}

class _EditProfileLoader extends StatefulWidget {
  const _EditProfileLoader({required this.loader});
  final Future<UserProfile> Function() loader;

  @override
  State<_EditProfileLoader> createState() => _EditProfileLoaderState();
}

class _EditProfileLoaderState extends State<_EditProfileLoader> {
  late Future<UserProfile> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _reload() => setState(() => _future = widget.loader());

  @override
  Widget build(BuildContext context) => FutureBuilder<UserProfile>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          appBar: AppBackAppBar(),
          body: Center(child: CircularProgressIndicator()),
        );
      }
      final value = snapshot.data;
      if (snapshot.hasError || value == null) {
        return Scaffold(
          appBar: const AppBackAppBar(title: Text('تعديل الملف الشخصي')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error?.toString() ?? 'تعذر تحميل الملف الشخصي.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return BlocProvider(
        create: (_) => UpdateProfileCubit(context.read<ProfileRepository>()),
        child: _EditProfileView(profile: value),
      );
    },
  );
}

class _EditProfileView extends StatefulWidget {
  const _EditProfileView({required this.profile});
  final UserProfile? profile;

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _nationalNumber;
  late final TextEditingController _phoneNumber;
  DateTime? _birthDate;
  int _gender = 0;
  String? _countryId;
  String? _cityId;
  List<ReferenceOption> _countries = const [];
  List<ReferenceOption> _allCities = const [];
  bool _loadingLookups = true;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _firstName = TextEditingController(text: profile?.firstName ?? '');
    _lastName = TextEditingController(text: profile?.lastName ?? '');
    _nationalNumber = TextEditingController(
      text: profile?.nationalNumber ?? '',
    );
    _phoneNumber = TextEditingController(text: profile?.phoneNumber ?? '');
    _birthDate = profile?.birthDate;
    _gender = profile?.gender ?? 0;
    _countryId = profile?.countryId.isEmpty == true ? null : profile?.countryId;
    _cityId = profile?.cityId.isEmpty == true ? null : profile?.cityId;
    _loadLookups();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _nationalNumber.dispose();
    _phoneNumber.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final repository = context.read<RegistrationLookupRepository>();
      final countriesFuture = repository.countries();
      final citiesFuture = repository.cities();
      final countries = await countriesFuture;
      final cities = await citiesFuture;
      if (mounted) {
        setState(() {
          _countries = countries;
          _allCities = cities;
          _loadingLookups = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLookups = false);
    }
  }

  List<ReferenceOption> get _cities => _countryId == null
      ? const []
      : _allCities.where((item) => item.parentId == _countryId).toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(title: const Text('تعديل الملف الشخصي')),
    body: BlocConsumer<UpdateProfileCubit, AsyncState<ProfileOperationResult>>(
      listener: (context, state) {
        if (state.status == AsyncStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.data?.message ?? 'تم الحفظ')),
          );
          context.pop(true);
        } else if (state.status == AsyncStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message ?? 'تعذر الحفظ')),
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
              _field(_firstName, 'الاسم الأول'),
              const SizedBox(height: 14),
              _field(_lastName, 'اسم العائلة'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nationalNumber,
                decoration: const InputDecoration(
                  labelText: 'الرقم الوطني',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
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
              const SizedBox(height: 14),
              InkWell(
                onTap: loading ? null : _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الميلاد',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    _birthDate == null
                        ? 'غير محدد'
                        : DateFormat('yyyy-MM-dd').format(_birthDate!),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_loadingLookups)
                const LinearProgressIndicator()
              else ...[
                AppDropdownFormField<String?>(
                  initialValue: _countryId,
                  decoration: const InputDecoration(
                    labelText: 'الدولة',
                    prefixIcon: Icon(Icons.public_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('غير محدد'),
                    ),
                    ..._countries.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: loading
                      ? null
                      : (value) => setState(() {
                          _countryId = value;
                          _cityId = null;
                        }),
                ),
                const SizedBox(height: 14),
                AppDropdownFormField<String?>(
                  initialValue: _cities.any((item) => item.id == _cityId)
                      ? _cityId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'المدينة',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('غير محدد'),
                    ),
                    ..._cities.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: loading
                      ? null
                      : (value) => setState(() => _cityId = value),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: loading ? null : _submit,
                icon: const Icon(Icons.save_outlined),
                label: Text(loading ? 'جارٍ الحفظ...' : 'حفظ التغييرات'),
              ),
              const SizedBox(height: 12),
              const Text(
                'البريد واسم المستخدم والصورة للعرض فقط؛ عقد الخادم الحالي لا يسمح بتعديلها من هذا المسار.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _field(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.person_outline),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
      );

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _birthDate = selected);
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    context.read<UpdateProfileCubit>().submit(
      UpdateProfileRequest(
        firstName: _firstName.text,
        lastName: _lastName.text,
        nationalNumber: _nationalNumber.text,
        phoneNumber: _phoneNumber.text,
        birthDate: _birthDate,
        gender: _gender,
        countryId: _countryId,
        cityId: _cityId,
      ),
    );
  }
}
