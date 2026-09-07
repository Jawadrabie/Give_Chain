import 'package:equatable/equatable.dart';

import '../../../core/network/json_helpers.dart';

class ReferenceOption extends Equatable {
  const ReferenceOption({
    required this.id,
    required this.name,
    this.parentId = '',
  });

  final String id;
  final String name;
  final String parentId;

  factory ReferenceOption.fromJson(Map<String, dynamic> json) =>
      ReferenceOption(
        id: JsonHelpers.text(json, const ['id']),
        name: JsonHelpers.text(json, const [
          'countryName',
          'cityName',
          'name',
        ], fallback: JsonHelpers.text(json, const ['id'])),
        parentId: JsonHelpers.text(json, const ['countryId']),
      );

  @override
  List<Object?> get props => [id, name, parentId];
}

class RegistrationLookupState extends Equatable {
  const RegistrationLookupState({
    this.countries = const [],
    this.allCities = const [],
    this.cities = const [],
    this.infoFields = const [],
    this.isLoading = false,
    this.warning,
  });

  final List<ReferenceOption> countries;
  final List<ReferenceOption> allCities;
  final List<ReferenceOption> cities;
  final List<dynamic> infoFields;
  final bool isLoading;
  final String? warning;

  RegistrationLookupState copyWith({
    List<ReferenceOption>? countries,
    List<ReferenceOption>? allCities,
    List<ReferenceOption>? cities,
    List<dynamic>? infoFields,
    bool? isLoading,
    String? warning,
    bool clearWarning = false,
  }) => RegistrationLookupState(
    countries: countries ?? this.countries,
    allCities: allCities ?? this.allCities,
    cities: cities ?? this.cities,
    infoFields: infoFields ?? this.infoFields,
    isLoading: isLoading ?? this.isLoading,
    warning: clearWarning ? null : warning ?? this.warning,
  );

  @override
  List<Object?> get props => [
    countries,
    allCities,
    cities,
    infoFields,
    isLoading,
    warning,
  ];
}
