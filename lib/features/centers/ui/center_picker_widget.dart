import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/center_models.dart';
import '../data/center_repository.dart';

/// A required field: money and item donations are rejected server-side
/// without a `CenterId`, so this always asks for one rather than offering a
/// direct-to-charity alternative.
class CenterPickerTile extends FormField<String> {
  CenterPickerTile({
    super.key,
    required CenterRepository repository,
    String? selectedCenterId,
    ValueChanged<CenterResponse?>? onCenterChanged,
    String? cityId,
    String? countryId,
    super.autovalidateMode,
  }) : super(
         initialValue: selectedCenterId,
         validator: (value) => value == null || value.trim().isEmpty
             ? 'يلزم اختيار مركز GiveChain لاستلام التبرع'
             : null,
         builder: (field) => _CenterPickerField(
           repository: repository,
           selectedCenterId: field.value,
           cityId: cityId,
           countryId: countryId,
           errorText: field.errorText,
           onCenterChanged: (center) {
             field.didChange(center?.id);
             onCenterChanged?.call(center);
           },
         ),
       );
}

class _CenterPickerField extends StatefulWidget {
  const _CenterPickerField({
    required this.repository,
    required this.onCenterChanged,
    this.selectedCenterId,
    this.cityId,
    this.countryId,
    this.errorText,
  });

  final CenterRepository repository;
  final String? selectedCenterId;
  final ValueChanged<CenterResponse?> onCenterChanged;
  final String? cityId;
  final String? countryId;
  final String? errorText;

  @override
  State<_CenterPickerField> createState() => _CenterPickerFieldState();
}

class _CenterPickerFieldState extends State<_CenterPickerField> {
  late Future<List<CenterResponse>> _future;
  CenterResponse? _selectedCenter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CenterPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCenterId != oldWidget.selectedCenterId &&
        widget.selectedCenterId != _selectedCenter?.id) {
      _applySelectedCenterId(widget.selectedCenterId);
    }
  }

  void _load() {
    _future = widget.repository.getCenters(
      cityId: widget.cityId,
      countryId: widget.countryId,
    )..then((centers) {
      if (!mounted) return;
      _applySelectedCenterId(widget.selectedCenterId);
      // A single available center is picked automatically — there is
      // nothing to choose between, and the field is required anyway.
      if (widget.selectedCenterId == null && centers.length == 1) {
        setState(() => _selectedCenter = centers.first);
        widget.onCenterChanged(centers.first);
      }
    });
  }

  void _applySelectedCenterId(String? centerId) {
    if (centerId == null) return;
    _future.then((centers) {
      if (!mounted) return;
      final match = centers.where((item) => item.id == centerId);
      if (match.isNotEmpty) setState(() => _selectedCenter = match.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final hasError = widget.errorText != null;

    return FutureBuilder<List<CenterResponse>>(
      future: _future,
      builder: (context, snapshot) {
        final centers = snapshot.data ?? const [];
        final loading = snapshot.connectionState != ConnectionState.done;

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'تعذر جلب مراكز GiveChain، أعد المحاولة قبل المتابعة.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(_load),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: loading ? null : () => _showCenterSheet(context, centers),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasError
                        ? scheme.error
                        : _selectedCenter != null
                        ? AppTheme.primary
                        : scheme.outline.withValues(alpha: 0.2),
                    width: hasError || _selectedCenter != null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      color: _selectedCenter != null
                          ? AppTheme.primary
                          : scheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'مركز GiveChain لاستلام التبرع',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            loading
                                ? 'جارٍ تحميل المراكز...'
                                : _selectedCenter == null
                                ? 'اختر مركزًا لاستلام التبرع'
                                : '${_selectedCenter!.name} — ${_selectedCenter!.cityName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _selectedCenter != null
                                  ? AppTheme.primary
                                  : scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            if (hasError) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  widget.errorText!,
                  style: TextStyle(fontSize: 12, color: scheme.error),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showCenterSheet(BuildContext context, List<CenterResponse> centers) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'اختر مركز GiveChain للتسليم',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (centers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('لا تتوفر مراكز تسليم نشطة في هذه المنطقة حالياً.'),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: centers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = centers[index];
                    final isSelected = _selectedCenter?.id == item.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppTheme.primary
                            : AppTheme.softOf(context),
                        child: Icon(
                          Icons.storefront,
                          color: isSelected ? Colors.white : AppTheme.primary,
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (item.isCurrentlyOpen != null) ...[
                            const SizedBox(width: 8),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              avatar: Icon(
                                Icons.circle,
                                size: 10,
                                color: item.isCurrentlyOpen!
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              label: Text(
                                item.isCurrentlyOpen! ? 'مفتوح الآن' : 'مغلق الآن',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text('${item.cityName} ${item.addressDetails}'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppTheme.primary)
                          : null,
                      onTap: () {
                        setState(() => _selectedCenter = item);
                        widget.onCenterChanged(item);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
