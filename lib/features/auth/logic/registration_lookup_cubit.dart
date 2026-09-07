import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/registration_lookup_models.dart';
import '../data/registration_lookup_repository.dart';

class RegistrationLookupCubit extends Cubit<RegistrationLookupState> {
  RegistrationLookupCubit(this._repository)
    : super(const RegistrationLookupState());

  final RegistrationLookupRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearWarning: true));
    try {
      final countriesFuture = _repository.countries();
      final citiesFuture = _repository.cities();
      final countries = await countriesFuture;
      final cities = await citiesFuture;
      emit(
        state.copyWith(
          countries: countries,
          allCities: cities,
          cities: const [],
          isLoading: false,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          warning:
              'تعذر تحميل الدول والمدن. يمكنك متابعة التسجيل دون تحديدهما: $error',
        ),
      );
    }
  }

  void selectCountry(String? countryId) {
    final id = countryId?.trim() ?? '';
    emit(
      state.copyWith(
        cities: id.isEmpty
            ? const []
            : state.allCities.where((city) => city.parentId == id).toList(),
      ),
    );
  }
}
