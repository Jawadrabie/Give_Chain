import 'package:equatable/equatable.dart';

import '../../../core/constants/api_enums.dart';
import '../../../core/network/json_helpers.dart';

class CatalogItem extends Equatable {
  const CatalogItem({
    required this.id,
    required this.title,
    this.description = '',
    this.imageUrl = '',
    this.mediaUrls = const [],
    this.goalAmount = 0,
    this.collectedAmount = 0,
    this.targetQuantity,
    this.achievedQuantity,
    this.goalUnit = '',
    this.goalType = '',
    this.charityId = '',
    this.charityName = '',
    this.status = '',
    this.statusCode,
    this.isTrusted = false,
    this.startDate,
    this.endDate,
    this.typeId = '',
    this.typeName = '',
    this.location = '',
    this.beneficiaryName = '',
    this.createdByUserName = '',
    this.currency = '',
    this.ownerType,
    this.isCase = false,
    this.priority,
    this.publishedAt,
    this.closedAt,
    this.closedNotes = '',
    this.referenceNumber = '',
    this.typeIconUrl = '',
    this.trustImageUrl = '',
    this.isStatusLocked = false,
    this.statusLockNote = '',
    this.caseNeeds = const [],
    this.caseUpdates = const [],
    this.raw = const {},
  });

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final List<String> mediaUrls;
  final double goalAmount;
  final double collectedAmount;
  final double? targetQuantity;
  final double? achievedQuantity;
  final String goalUnit;
  final String goalType;
  final String charityId;
  final String charityName;
  final String status;
  final int? statusCode;
  final bool isTrusted;
  final DateTime? startDate;
  final DateTime? endDate;
  final String typeId;
  final String typeName;
  final String location;
  final String beneficiaryName;
  final String createdByUserName;
  final String currency;
  final int? ownerType;
  final bool isCase;
  final int? priority;
  final DateTime? publishedAt;
  final DateTime? closedAt;
  final String closedNotes;

  /// `caseNumber` / `campaignNumber` — a human-readable reference the charity
  /// can be quoted. Empty throughout production today, so the UI only shows
  /// it once the backend starts filling it in.
  final String referenceNumber;

  /// Icon for the case category / campaign type, when the lookup supplies one.
  final String typeIconUrl;

  /// Badge image backing [isTrusted], when the backend supplies one.
  final String trustImageUrl;

  /// A locked status cannot change until the charity unlocks it;
  /// [statusLockNote] explains why.
  final bool isStatusLocked;
  final String statusLockNote;

  /// Donatable needs. Only the case *detail* endpoint populates these; list
  /// endpoints deliberately return an empty array to keep list pages light.
  final List<CaseNeed> caseNeeds;

  /// Progress posts published by the charity, likewise detail-only.
  final List<CaseUpdate> caseUpdates;
  final Map<String, dynamic> raw;

  /// Money target, preferring the item's own figure and otherwise summing the
  /// case's needs.
  ///
  /// The API leaves `targetAmount`/`achievedAmount` null on every case — the
  /// real money lives on `caseNeeds` — so reading only the top-level fields
  /// renders an empty 0% bar over a case that is genuinely part-funded.
  double get effectiveGoalAmount {
    if (goalAmount > 0) return goalAmount;
    return caseNeeds.fold<double>(0, (sum, need) => sum + (need.amount ?? 0));
  }

  double get effectiveCollectedAmount {
    if (goalAmount > 0) return collectedAmount;
    return caseNeeds.fold<double>(
      0,
      (sum, need) => sum + (need.fulfilledAmount ?? 0),
    );
  }

  /// True when there is a real monetary target to show a bar against.
  bool get hasMonetaryGoal => effectiveGoalAmount > 0;

  double get progress => effectiveGoalAmount <= 0
      ? 0
      : (effectiveCollectedAmount / effectiveGoalAmount)
            .clamp(0, 1)
            .toDouble();

  /// Quantity target, again falling back to the sum across the case's needs
  /// so an in-kind case ("100 سلة غذائية") shows real progress.
  double get effectiveTargetQuantity {
    final target = targetQuantity;
    if (target != null && target > 0) return target;
    return caseNeeds.fold<double>(0, (sum, need) => sum + (need.quantity ?? 0));
  }

  double get effectiveAchievedQuantity {
    final target = targetQuantity;
    if (target != null && target > 0) return achievedQuantity ?? 0;
    return caseNeeds.fold<double>(
      0,
      (sum, need) => sum + (need.fulfilledQuantity ?? 0),
    );
  }

  double? get quantityProgress {
    final target = effectiveTargetQuantity;
    if (target <= 0) return null;
    return (effectiveAchievedQuantity / target).clamp(0, 1).toDouble();
  }

  double get remainingAmount => (effectiveGoalAmount - effectiveCollectedAmount)
      .clamp(0, double.infinity)
      .toDouble();

  String get displayStatus {
    if (status.trim().isNotEmpty && int.tryParse(status) == null) return status;
    return isCase
        ? (ApiEnums.caseStatus[statusCode] ?? status)
        : (ApiEnums.campaignStatus[statusCode] ?? status);
  }

  String get goalTypeLabel {
    final value = int.tryParse(goalType);
    return value == null ? goalType : ApiEnums.goalType[value] ?? goalType;
  }

  String get priorityLabel => priority == null
      ? ''
      : ApiEnums.casePriority[priority!] ?? priority.toString();

  bool get canDonate => isCase
      ? statusCode == null || statusCode == 0 || statusCode == 1
      : statusCode == null || statusCode == 1;

  bool matches(CatalogQuery query) {
    final normalized = query.search.trim().toLowerCase();
    if (normalized.isNotEmpty) {
      final searchable = [
        title,
        description,
        charityName,
        typeName,
        location,
        beneficiaryName,
      ].join(' ').toLowerCase();
      if (!searchable.contains(normalized)) return false;
    }
    if (query.status.trim().isNotEmpty) {
      final wanted = query.status.trim().toLowerCase();
      if (displayStatus.toLowerCase() != wanted &&
          status.toLowerCase() != wanted &&
          statusCode?.toString() != wanted) {
        return false;
      }
    }
    if (query.typeId.trim().isNotEmpty && typeId != query.typeId.trim()) {
      return false;
    }
    if (query.priority.trim().isNotEmpty &&
        priority?.toString() != query.priority.trim()) {
      return false;
    }
    if (query.onlyTrusted && !isTrusted) return false;
    return true;
  }

  CatalogItem copyWith({String? typeName, String? charityName}) => CatalogItem(
    id: id,
    title: title,
    description: description,
    imageUrl: imageUrl,
    mediaUrls: mediaUrls,
    goalAmount: goalAmount,
    collectedAmount: collectedAmount,
    targetQuantity: targetQuantity,
    achievedQuantity: achievedQuantity,
    goalUnit: goalUnit,
    goalType: goalType,
    charityId: charityId,
    charityName: charityName ?? this.charityName,
    status: status,
    statusCode: statusCode,
    isTrusted: isTrusted,
    startDate: startDate,
    endDate: endDate,
    typeId: typeId,
    typeName: typeName ?? this.typeName,
    location: location,
    beneficiaryName: beneficiaryName,
    createdByUserName: createdByUserName,
    currency: currency,
    ownerType: ownerType,
    isCase: isCase,
    priority: priority,
    publishedAt: publishedAt,
    closedAt: closedAt,
    closedNotes: closedNotes,
    referenceNumber: referenceNumber,
    typeIconUrl: typeIconUrl,
    trustImageUrl: trustImageUrl,
    isStatusLocked: isStatusLocked,
    statusLockNote: statusLockNote,
    caseNeeds: caseNeeds,
    caseUpdates: caseUpdates,
    raw: raw,
  );

  @override
  List<Object?> get props => [id, title, charityId];

  factory CatalogItem.fromJson(Map<String, dynamic> source) {
    final json = _catalogMap(source);
    final mediaUrls = _mediaUrls(json);
    final campaignType = _nestedMap(json, const [
      'campaignType',
      'category',
      'type',
    ]);
    final charity = _nestedMap(json, const ['charity', 'organization']);
    final creator = _nestedMap(json, const ['creator', 'createdByUser']);
    final isCase =
        json.containsKey('priority') ||
        json.containsKey('publishedAt') ||
        json.containsKey('categoryId');
    final statusValue = json['status'];
    final statusCode = statusValue is num
        ? statusValue.toInt()
        : int.tryParse(statusValue?.toString() ?? '');

    final image = JsonHelpers.text(json, const [
      'imageUrl',
      'image',
      'coverImageUrl',
      'photoUrl',
    ], fallback: mediaUrls.isEmpty ? '' : mediaUrls.first);

    return CatalogItem(
      id: JsonHelpers.text(json, const ['id', 'campaignId', 'caseId', 'uuid']),
      title: JsonHelpers.text(json, const [
        'campaignName',
        'caseName',
        'caseTitle',
        'campaignTitle',
        'title',
        'name',
      ], fallback: 'بدون عنوان'),
      description: JsonHelpers.text(json, const [
        'campaignDescription',
        'caseDescription',
        'description',
        'details',
        'summary',
        'content',
      ]),
      imageUrl: image,
      mediaUrls: mediaUrls,
      goalAmount: JsonHelpers.number(json, const [
        'targetAmount',
        'goalAmount',
        'requiredAmount',
        'goal',
      ]),
      collectedAmount: JsonHelpers.number(json, const [
        'achievedAmount',
        'collectedAmount',
        'raisedAmount',
        'currentAmount',
        'donatedAmount',
      ]),
      targetQuantity: _nullableNumber(json['targetQuantity']),
      achievedQuantity: _nullableNumber(json['achievedQuantity']),
      goalUnit: JsonHelpers.text(json, const ['goalUnit', 'unit']),
      goalType: json['goalType']?.toString() ?? '',
      charityId: JsonHelpers.text(json, const [
        'charityId',
        'organizationId',
      ], fallback: JsonHelpers.text(charity, const ['id'])),
      charityName: JsonHelpers.text(
        json,
        const ['charityName', 'organizationName'],
        fallback: JsonHelpers.text(charity, const [
          'name',
          'charityName',
          'title',
        ]),
      ),
      status:
          statusValue?.toString() ??
          JsonHelpers.text(json, const ['statusName']),
      statusCode: statusCode,
      isTrusted: JsonHelpers.boolean(json, const [
        'isTrusted',
        'trusted',
        'isVerified',
        'verified',
      ]),
      startDate: _date(json, const ['startDate', 'createdAt', 'createdDate']),
      endDate: _date(json, const ['endDate', 'expiryDate', 'deadline']),
      typeId: JsonHelpers.text(json, const [
        'campaignTypeId',
        'caseTypeId',
        'typeId',
        'categoryId',
      ], fallback: JsonHelpers.text(campaignType, const ['id'])),
      typeName: JsonHelpers.text(
        json,
        const ['campaignTypeName', 'caseTypeName', 'typeName', 'categoryName'],
        fallback: JsonHelpers.text(campaignType, const [
          'name',
          'title',
          'description',
        ]),
      ),
      location: JsonHelpers.text(json, const [
        'locationDetails',
        'location',
        'address',
        'cityName',
        'regionName',
      ]),
      beneficiaryName: JsonHelpers.text(json, const [
        'beneficiaryName',
        'patientName',
        'recipientName',
      ]),
      createdByUserName: JsonHelpers.text(
        json,
        const ['createdByUserName', 'creatorName'],
        fallback: JsonHelpers.text(creator, const [
          'userName',
          'name',
          'displayName',
        ]),
      ),
      currency: JsonHelpers.text(json, const ['currency', 'currencyCode']),
      ownerType: json['ownerType'] is num
          ? (json['ownerType'] as num).toInt()
          : int.tryParse(json['ownerType']?.toString() ?? ''),
      isCase: isCase,
      priority: json['priority'] is num
          ? (json['priority'] as num).toInt()
          : int.tryParse(json['priority']?.toString() ?? ''),
      publishedAt: _date(json, const ['publishedAt']),
      closedAt: _date(json, const ['closedAt']),
      closedNotes: JsonHelpers.text(json, const ['closedNotes']),
      referenceNumber: JsonHelpers.text(json, const [
        'caseNumber',
        'campaignNumber',
      ]),
      typeIconUrl: JsonHelpers.text(campaignType, const ['iconUrl']),
      trustImageUrl: JsonHelpers.text(json, const ['trustImageUrl']),
      isStatusLocked: JsonHelpers.boolean(json, const ['isStatusLocked']),
      statusLockNote: JsonHelpers.text(json, const ['statusLockNote']),
      caseNeeds: _caseNeeds(json),
      caseUpdates: _caseUpdates(json),
      raw: json,
    );
  }

  /// `caseNeeds` is the field the backend ships; `needs` is the name the
  /// original bug report proposed and is still accepted so the app parses
  /// either shape.
  static List<CaseNeed> _caseNeeds(Map<String, dynamic> json) {
    final raw = json['caseNeeds'] ?? json['needs'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => CaseNeed.fromJson(Map<String, dynamic>.from(item)))
        .where((need) => need.id.isNotEmpty)
        .toList();
  }

  static List<CaseUpdate> _caseUpdates(Map<String, dynamic> json) {
    final raw = json['caseUpdates'] ?? json['updates'];
    if (raw is! List) return const [];
    final updates = raw
        .whereType<Map>()
        .map((item) => CaseUpdate.fromJson(Map<String, dynamic>.from(item)))
        .where((update) => update.content.isNotEmpty)
        .toList();
    // Newest first; undated posts sink to the bottom rather than the top.
    updates.sort((a, b) {
      final left = a.postedAt;
      final right = b.postedAt;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return updates;
  }

  static Map<String, dynamic> _catalogMap(Map<String, dynamic> source) {
    for (final key in const ['campaign', 'case', 'item']) {
      if (source[key] is Map) {
        return Map<String, dynamic>.from(source[key] as Map);
      }
    }
    return source;
  }

  static List<String> _mediaUrls(Map<String, dynamic> json) {
    final raw = json['medias'] ?? json['media'] ?? json['images'];
    if (raw is! List) return const [];
    final primary = <String>[];
    final other = <String>[];
    for (final item in raw) {
      if (item is String && item.trim().isNotEmpty) {
        other.add(item.trim());
      } else if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final url = JsonHelpers.text(map, const [
          'url',
          'imageUrl',
          'fileUrl',
          'path',
        ]);
        if (url.isEmpty) continue;
        if (map['isPrimary'] == true) {
          primary.add(url);
        } else {
          other.add(url);
        }
      }
    }
    return <String>{...primary, ...other}.toList();
  }

  static Map<String, dynamic> _nestedMap(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  static DateTime? _date(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null || value.toString().trim().isEmpty) continue;
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  static double? _nullableNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class CharityCategory extends Equatable {
  const CharityCategory({
    required this.id,
    required this.name,
    this.description = '',
  });

  final String id;
  final String name;
  final String description;

  @override
  List<Object?> get props => [id, name];

  factory CharityCategory.fromJson(Map<String, dynamic> json) =>
      CharityCategory(
        id: JsonHelpers.text(json, const ['id']),
        name: JsonHelpers.text(json, const ['name']),
        description: JsonHelpers.text(json, const ['description']),
      );
}

class Charity extends Equatable {
  const Charity({
    required this.id,
    required this.name,
    this.description = '',
    this.logoUrl = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.licenseNumber = '',
    this.cityName = '',
    this.countryName = '',
    this.countryId,
    this.cityId,
    this.categoryName = '',
    this.categoryNames = const [],
    this.categories = const [],
    this.status,
    this.statusCode,
    this.suspendedReason = '',
    this.suspendedAt,
    this.ownerUserId,
    this.ownerUserName = '',
    this.ownerEmail = '',
    this.subDomain = '',
    this.date,
    this.isTrusted = false,
    this.campaignsCount,
    this.casesCount,
    this.raw = const {},
  });

  final String id;
  final String name;
  final String description;
  final String logoUrl;
  final String address;
  final String phone;
  final String email;
  final String website;
  final String licenseNumber;
  final String cityName;
  final String countryName;
  final String? countryId;
  final String? cityId;
  final String categoryName;
  final List<String> categoryNames;

  /// Full category objects (id/name/description), in addition to the
  /// flattened [categoryNames] used by existing display code.
  final List<CharityCategory> categories;

  /// `CharityStatus`: Active = 0, Suspended = 1, Deleted = 2.
  final int? status;

  /// Shortcut flag from the backend: 1 = active, 0 = blocked.
  final int? statusCode;
  final String suspendedReason;
  final DateTime? suspendedAt;
  final String? ownerUserId;
  final String ownerUserName;
  final String ownerEmail;
  final String subDomain;
  final DateTime? date;
  final bool isTrusted;
  final int? campaignsCount;
  final int? casesCount;
  final Map<String, dynamic> raw;

  bool matches(String search) {
    final query = search.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      name,
      description,
      address,
      cityName,
      countryName,
      categoryName,
      ...categoryNames,
    ].join(' ').toLowerCase().contains(query);
  }

  @override
  List<Object?> get props => [id, name];

  factory Charity.fromJson(Map<String, dynamic> source) {
    final json = source['charity'] is Map
        ? Map<String, dynamic>.from(source['charity'] as Map)
        : source;
    final city = json['city'] is Map
        ? Map<String, dynamic>.from(json['city'] as Map)
        : <String, dynamic>{};
    final country = json['country'] is Map
        ? Map<String, dynamic>.from(json['country'] as Map)
        : <String, dynamic>{};
    final category = json['category'] is Map
        ? Map<String, dynamic>.from(json['category'] as Map)
        : <String, dynamic>{};
    final categories = (json['categories'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CharityCategory.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.id.isNotEmpty || item.name.isNotEmpty)
        .toList();
    final categoryNames = categories
        .map((item) => item.name)
        .where((name) => name.isNotEmpty)
        .toList();
    final owner = json['owner'] is Map
        ? Map<String, dynamic>.from(json['owner'] as Map)
        : <String, dynamic>{};
    return Charity(
      id: JsonHelpers.text(json, const ['id', 'charityId', 'uuid']),
      name: JsonHelpers.text(json, const [
        'name',
        'title',
        'charityName',
      ], fallback: 'جمعية'),
      description: JsonHelpers.text(json, const [
        'description',
        'about',
        'summary',
      ]),
      logoUrl: JsonHelpers.text(json, const [
        'logoUrl',
        'imageUrl',
        'logo',
        'image',
      ]),
      address: JsonHelpers.text(json, const ['address', 'location']),
      phone: JsonHelpers.text(json, const ['phone', 'phoneNumber', 'mobile']),
      email: JsonHelpers.text(json, const ['email', 'emailAddress']),
      website: JsonHelpers.text(json, const [
        'website',
        'websiteUrl',
        'webSite',
      ]),
      licenseNumber: JsonHelpers.text(json, const [
        'licenseNumber',
        'registrationNumber',
        'charityNumber',
      ]),
      cityName: JsonHelpers.text(json, const [
        'cityName',
        'city',
      ], fallback: JsonHelpers.text(city, const ['cityName', 'name', 'title'])),
      countryName: JsonHelpers.text(
        json,
        const ['countryName', 'country'],
        fallback: JsonHelpers.text(country, const [
          'countryName',
          'name',
          'title',
        ]),
      ),
      countryId: _nullable(
        json['countryId'] ?? JsonHelpers.text(country, const ['id']),
      ),
      cityId: _nullable(json['cityId'] ?? JsonHelpers.text(city, const ['id'])),
      categoryName: categoryNames.isNotEmpty
          ? categoryNames.first
          : JsonHelpers.text(json, const [
              'categoryName',
            ], fallback: JsonHelpers.text(category, const ['name', 'title'])),
      categoryNames: categoryNames,
      categories: categories,
      status: _int(json, const ['status']),
      statusCode: _int(json, const ['statusCode']),
      suspendedReason: JsonHelpers.text(json, const ['suspendedReason']),
      suspendedAt: DateTime.tryParse(json['suspendedAt']?.toString() ?? ''),
      ownerUserId: _nullable(json['ownerUserId']),
      ownerUserName: JsonHelpers.text(
        owner,
        const ['userName', 'name'],
      ),
      ownerEmail: JsonHelpers.text(owner, const ['email']),
      subDomain: JsonHelpers.text(json, const ['subDomain']),
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      isTrusted: JsonHelpers.boolean(json, const [
        'isTrusted',
        'trusted',
        'isVerified',
        'verified',
      ]),
      campaignsCount: _int(json, const ['campaignsCount', 'campaignCount']),
      casesCount: _int(json, const ['casesCount', 'caseCount']),
      raw: json,
    );
  }

  static int? _int(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String? _nullable(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }
}

class CatalogQuery extends Equatable {
  const CatalogQuery({
    this.search = '',
    this.status = '',
    this.typeId = '',
    this.priority = '',
    this.onlyTrusted = false,
  });

  final String search;
  final String status;
  final String typeId;
  final String priority;
  final bool onlyTrusted;

  bool get isEmpty =>
      search.trim().isEmpty &&
      status.trim().isEmpty &&
      typeId.trim().isEmpty &&
      priority.trim().isEmpty &&
      !onlyTrusted;

  CatalogQuery copyWith({
    String? search,
    String? status,
    String? typeId,
    String? priority,
    bool? onlyTrusted,
  }) {
    return CatalogQuery(
      search: search ?? this.search,
      status: status ?? this.status,
      typeId: typeId ?? this.typeId,
      priority: priority ?? this.priority,
      onlyTrusted: onlyTrusted ?? this.onlyTrusted,
    );
  }

  Map<String, dynamic> toServerQuery() => const {};

  @override
  List<Object?> get props => [search, status, typeId, priority, onlyTrusted];
}

class PageResult<T> {
  const PageResult({required this.items, required this.hasMore});
  final List<T> items;
  final bool hasMore;
}

/// One donatable need attached to a case.
///
/// A case donation is rejected server-side without a `caseNeedId` and the
/// backend never infers one, so [id] is the value the donation form must
/// submit. The backend delivers these on the case *detail* payload only
/// (`GET /api/mobile/cases/{id}`); list endpoints return an empty array.
class CaseNeed extends Equatable {
  const CaseNeed({
    required this.id,
    required this.name,
    this.caseId = '',
    this.caseNeedType = 0,
    this.quantity,
    this.unit,
    this.amount,
    this.description = '',
    this.fulfilledQuantity,
    this.fulfilledAmount,
  });

  final String id;
  final String caseId;
  final String name;

  /// `CaseNeedType` (0-3). This is *not* `DonationType` (1-3): the two enums
  /// have different ranges and the backend has not published the member
  /// names, so the value must never be copied into a donation's type. Use
  /// [amount] vs [quantity] to tell a money need from an in-kind one.
  final int caseNeedType;
  final double? quantity;

  /// `Unit` enum, used to label an in-kind need's quantity.
  final int? unit;
  final double? amount;
  final String description;
  final double? fulfilledQuantity;
  final double? fulfilledAmount;

  String get unitLabel => unit == null ? '' : ApiEnums.unit[unit!] ?? '';

  /// How the need is measured, derived from the payload rather than from
  /// [caseNeedType] — whose member names the backend has not published.
  String get typeLabel {
    if ((amount ?? 0) > 0) return 'مالي';
    if ((quantity ?? 0) > 0) return 'عيني';
    return '';
  }

  /// Progress toward this need, using whichever measure the need is
  /// expressed in (money or quantity). Null when nothing is targeted.
  double? get progress {
    final targetAmount = amount ?? 0;
    if (targetAmount > 0) {
      return ((fulfilledAmount ?? 0) / targetAmount).clamp(0, 1).toDouble();
    }
    final targetQuantity = quantity ?? 0;
    if (targetQuantity > 0) {
      return ((fulfilledQuantity ?? 0) / targetQuantity).clamp(0, 1).toDouble();
    }
    return null;
  }

  /// A fully-covered need is still selectable server-side, but offering it
  /// first is a poor default, so the UI de-emphasises it.
  bool get isFulfilled => (progress ?? 0) >= 1;

  /// The only `DonationType` (1-3) the server accepts for this need: a
  /// money need only takes money, an in-kind one only takes goods. The
  /// server rejects any mismatch (e.g. a money donation against an item
  /// need), so the donation form must restrict its type picker to this
  /// value rather than merely suggest it. Null when the need's shape gives
  /// no signal (both amount and quantity are unset), in which case any
  /// donation type is left open.
  int? get allowedDonationType {
    if ((amount ?? 0) > 0) return 1;
    if ((quantity ?? 0) > 0) return 2;
    return null;
  }

  @override
  List<Object?> get props => [id, name, caseNeedType];

  factory CaseNeed.fromJson(Map<String, dynamic> json) => CaseNeed(
    id: JsonHelpers.text(json, const ['id', 'caseNeedId']),
    caseId: JsonHelpers.text(json, const ['caseId']),
    name: JsonHelpers.text(json, const [
      'name',
      'title',
      'needName',
    ], fallback: 'احتياج'),
    // `caseNeedType` is the documented name; `type` is accepted because the
    // original bug report proposed it and either may reach us.
    caseNeedType: _intOf(json, const ['caseNeedType', 'type', 'needType']) ?? 0,
    quantity: _numberOf(json, const ['quantity', 'targetQuantity']),
    unit: _intOf(json, const ['unit']),
    amount: _numberOf(json, const ['amount', 'targetAmount']),
    description: JsonHelpers.text(json, const ['description']),
    fulfilledQuantity: _numberOf(json, const [
      'fulfilledQuantity',
      'achievedQuantity',
    ]),
    fulfilledAmount: _numberOf(json, const [
      'fulfilledAmount',
      'achievedAmount',
    ]),
  );
}

/// A progress post published on a case by the owning charity.
class CaseUpdate extends Equatable {
  const CaseUpdate({
    required this.id,
    required this.content,
    this.caseId = '',
    this.postedById = '',
    this.postedAt,
    this.mediaUrls = const [],
  });

  final String id;
  final String caseId;
  final String postedById;
  final String content;
  final DateTime? postedAt;
  final List<String> mediaUrls;

  @override
  List<Object?> get props => [id, content, postedAt];

  factory CaseUpdate.fromJson(Map<String, dynamic> json) => CaseUpdate(
    id: JsonHelpers.text(json, const ['id']),
    caseId: JsonHelpers.text(json, const ['caseId']),
    postedById: JsonHelpers.text(json, const ['postedById']),
    content: JsonHelpers.text(json, const ['content', 'text', 'body']),
    postedAt: DateTime.tryParse(json['postedAt']?.toString() ?? ''),
    mediaUrls: (json['medias'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => JsonHelpers.text(Map<String, dynamic>.from(item), const [
            'url',
            'imageUrl',
            'fileUrl',
            'path',
          ]),
        )
        .where((url) => url.isNotEmpty)
        .toList(),
  );
}

int? _intOf(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

double? _numberOf(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}
