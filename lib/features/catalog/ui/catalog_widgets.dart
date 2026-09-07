import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/api_enums.dart';
import '../../../core/network/url_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section.dart';
import '../data/catalog_models.dart';

/// ألوان بطاقات الاستكشاف وفق GiveChain UI.txt.
abstract final class CatalogLook {
  static const mint = AppTheme.soft;
  static const brandGreen = AppTheme.primary;
  static const donateBrown = AppTheme.donate;
  static const searchFill = AppTheme.border;
  static const softButton = AppTheme.soft;
  /// Kept in step with [AppSection.radius] so a card in a list and a section
  /// on a detail screen read as the same family.
  static const cardRadius = AppSection.radius;
  static const imageHeight = 124.0;

  /// Detail-screen header heights. Without a photo the header would otherwise
  /// reserve [detailHeaderHeight] for a bare placeholder, pushing the case's
  /// needs and updates off the first screen.
  static const detailHeaderHeight = 260.0;
  static const detailHeaderHeightNoImage = 150.0;

  static const carouselWidth = 252.0;
  static const carouselHeight = 292.0;
  static const listCardHeight = 292.0;
}

class NetworkOrPlaceholder extends StatelessWidget {
  const NetworkOrPlaceholder({
    super.key,
    required this.url,
    this.height = 170,
    this.icon = Icons.volunteer_activism,
  });

  final String url;
  final double height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return _placeholder(context);
    return CachedNetworkImage(
      imageUrl: UrlResolver.resolve(url),
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, _) => _placeholder(context, loading: true),
      errorWidget: (_, _, _) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context, {bool loading = false}) =>
      Container(
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Icon(
                icon,
                size: height < 120 ? 32 : 44,
                color: CatalogLook.brandGreen,
              ),
      );
}

/// بطاقة موحّدة للحملات والحالات (الرئيسية + الاستكشاف).
class CatalogCard extends StatelessWidget {
  const CatalogCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onDonate,
    this.width,
    this.height,
    this.donateLabel = 'تبرع الأن',
  });

  final CatalogItem item;
  final VoidCallback onTap;
  final VoidCallback? onDonate;
  final double? width;
  final double? height;
  final String donateLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final cardColor = isDark ? scheme.surface : Colors.white;
    // Uses the effective figures so a case whose money lives on its
    // `caseNeeds` shows the same progress here as on its detail screen.
    final hasMoneyGoal = item.hasMonetaryGoal;
    final progress = hasMoneyGoal ? item.progress : item.quantityProgress;
    final meta = [
      if (item.typeName.isNotEmpty) item.typeName,
      if (item.charityName.isNotEmpty) item.charityName,
      if (item.isCase && item.priorityLabel.isNotEmpty) item.priorityLabel,
    ].join(' • ');
    final cardHeight = height ??
        (width != null
            ? CatalogLook.carouselHeight
            : CatalogLook.listCardHeight);

    return Semantics(
      label: item.title,
      child: Container(
      width: width,
      height: cardHeight,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(CatalogLook.cardRadius),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppTheme.primary.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CatalogLook.cardRadius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: CatalogLook.imageHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NetworkOrPlaceholder(
                        url: item.imageUrl,
                        height: CatalogLook.imageHeight,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0x66000000),
                              Color(0xCC000000),
                            ],
                            stops: [0.25, 0.62, 1],
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: 8,
                        start: 8,
                        end: 8,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (item.isTrusted)
                              const Tooltip(
                                message: 'حملة موثوقة',
                                child: _Badge(
                                  label: 'موثوقة',
                                  verified: true,
                                ),
                              ),
                            if (item.displayStatus.isNotEmpty)
                              _Badge(
                                icon: Icons.circle,
                                label: item.displayStatus,
                                compact: true,
                              ),
                            if (item.isCase && item.priorityLabel.isNotEmpty)
                              _Badge(
                                icon: Icons.priority_high,
                                label: item.priorityLabel,
                                tint: ApiEnums.statusColor(
                                  item.priority!,
                                  family: 'casePriority',
                                ),
                              ),
                          ],
                        ),
                      ),
                      PositionedDirectional(
                        start: 10,
                        end: 10,
                        bottom: 8,
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 16,
                          child: Text(
                            meta.isEmpty ? ' ' : meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                              color: scheme.onSurface.withValues(alpha: 0.52),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 46,
                          child: progress != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            hasMoneyGoal
                                                ? _amount(
                                                    item
                                                        .effectiveCollectedAmount,
                                                    item.currency,
                                                  )
                                                : '${item.effectiveAchievedQuantity.toStringAsFixed(0)}'
                                                      ' / ${item.effectiveTargetQuantity.toStringAsFixed(0)}'
                                                      '${item.goalUnit.isEmpty ? '' : ' ${item.goalUnit}'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${(progress * 100).toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.65),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 7,
                                        backgroundColor: AppTheme.primary
                                            .withValues(alpha: 0.12),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                          AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  item.description.isEmpty
                                      ? 'ساهم الآن لدعم هذه المبادرة'
                                      : item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.62),
                                  ),
                                ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppTheme.primaryForeground,
                              minimumSize: const Size.fromHeight(40),
                              padding: EdgeInsets.zero,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: onDonate ?? onTap,
                            child: Text(
                              donateLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  String _amount(double value, String currency) {
    final amount = NumberFormat('#,##0.##').format(value);
    if (currency.isEmpty) return '$amount ل.س';
    return '$amount $currency';
  }
}

class CharityCard extends StatelessWidget {
  const CharityCard({super.key, required this.charity, required this.onTap});

  final Charity charity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final cardColor = isDark ? scheme.surface : Colors.white;
    final categories = charity.categoryNames.isNotEmpty
        ? charity.categoryNames
        : [
            if (charity.categoryName.isNotEmpty) charity.categoryName,
          ];
    final location = [
      charity.cityName,
      charity.countryName,
    ].where((v) => v.isNotEmpty).join(', ');
    final subtitle = [
      if (location.isNotEmpty) location,
      ...categories.take(1),
    ].join(' • ');

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(CatalogLook.cardRadius),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppTheme.primary.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CatalogLook.cardRadius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.softOf(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: charity.logoUrl.trim().isEmpty
                          ? Icon(
                              Icons.apartment,
                              color: scheme.primary,
                              size: 28,
                            )
                          : NetworkOrPlaceholder(
                              url: charity.logoUrl,
                              height: 56,
                              icon: Icons.apartment,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                charity.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            if (charity.isTrusted)
                              const Padding(
                                padding: EdgeInsetsDirectional.only(start: 4),
                                child: Icon(
                                  Icons.verified,
                                  color: AppTheme.primary,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.58),
                            ),
                          ),
                        ],
                        if (charity.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            charity.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.62),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: scheme.onSurface.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    this.icon,
    required this.label,
    this.tint,
    this.compact = false,
    this.verified = false,
  }) : assert(verified || icon != null);

  final IconData? icon;
  final String label;
  final Color? tint;
  final bool compact;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppTheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (verified)
            Container(
              width: compact ? 11 : 14,
              height: compact ? 11 : 14,
              decoration: const BoxDecoration(
                color: Color(0xFF1877F2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                size: compact ? 8 : 10,
                color: Colors.white,
              ),
            )
          else
            Icon(
              icon,
              size: compact ? 9 : 12,
              color: color == AppTheme.primary
                  ? Colors.white.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.9),
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
