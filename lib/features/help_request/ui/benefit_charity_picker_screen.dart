import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_back_app_bar.dart';
import '../../benefits/data/benefit_models.dart';

/// Step 2 of the need-first flow: which charity should receive the request.
///
/// Each charity configures its own questions for the same benefit, so the
/// choice made here determines the form that follows — the selected
/// [BenefitType] is passed straight to the apply screen.
class BenefitCharityPickerScreen extends StatelessWidget {
  const BenefitCharityPickerScreen({super.key, required this.offering});

  final BenefitOffering offering;

  Future<void> _pick(BuildContext context, BenefitType type) async {
    final submitted = await context.push<bool>(
      '/benefits/apply',
      extra: type,
    );
    // Carry the result back so the whole flow unwinds to the applications
    // list in one step rather than stranding the user on this picker.
    if (submitted == true && context.mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBackAppBar(title: Text(offering.name)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: offering.types.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'اختر الجمعية التي ترغب بتقديم طلب «${offering.name}» لديها.',
                style: TextStyle(
                  height: 1.5,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            );
          }

          final type = offering.types[index - 1];
          final questionCount = type.questions.length;

          return Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _pick(context, type),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.apartment_outlined,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.charityName.isEmpty
                                ? 'جمعية'
                                : type.charityName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            questionCount == 0
                                ? 'بدون أسئلة إضافية'
                                : '$questionCount ${questionCount == 1 ? 'سؤال' : 'أسئلة'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                          if (type.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              type.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
