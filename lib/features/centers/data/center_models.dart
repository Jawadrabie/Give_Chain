import '../../../core/network/json_helpers.dart';

class CenterResponse {
  const CenterResponse({
    required this.id,
    required this.name,
    this.countryId,
    this.countryName = '',
    this.cityId,
    this.cityName = '',
    this.addressDetails = '',
    this.workingHours = '',
    this.opensAt,
    this.closesAt,
    this.status,
    this.isCurrentlyOpen,
  });

  final String id;
  final String name;
  final String? countryId;
  final String countryName;
  final String? cityId;
  final String cityName;
  final String addressDetails;
  final String workingHours;
  final DateTime? opensAt;
  final DateTime? closesAt;

  /// `CenterStatus`: Active = 0, Inactive = 1.
  final int? status;

  /// Server-computed "is this Center open right now" flag.
  final bool? isCurrentlyOpen;

  factory CenterResponse.fromJson(dynamic raw) {
    final data = JsonHelpers.unwrap(raw);
    final json = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    return CenterResponse(
      id: JsonHelpers.text(json, const ['id', 'centerId']),
      name: JsonHelpers.text(json, const ['name', 'title']),
      countryId: _nullable(json['countryId']),
      countryName: JsonHelpers.text(json, const ['countryName']),
      cityId: _nullable(json['cityId']),
      cityName: JsonHelpers.text(json, const ['cityName']),
      addressDetails: JsonHelpers.text(json, const ['addressDetails', 'address']),
      workingHours: JsonHelpers.text(json, const ['workingHours']),
      opensAt: DateTime.tryParse(json['opensAt']?.toString() ?? ''),
      closesAt: DateTime.tryParse(json['closesAt']?.toString() ?? ''),
      status: json['status'] is num
          ? (json['status'] as num).toInt()
          : int.tryParse(json['status']?.toString() ?? ''),
      isCurrentlyOpen: json['isCurrentlyOpen'] is bool
          ? json['isCurrentlyOpen'] as bool
          : null,
    );
  }
}

String? _nullable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? null : text;
}
