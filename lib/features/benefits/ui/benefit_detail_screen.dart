import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_back_app_bar.dart';
import '../data/benefit_models.dart';

class BenefitDetailScreen extends StatelessWidget {
  const BenefitDetailScreen({
    super.key,
    required this.charityId,
    required this.benefitType,
  });

  final String charityId;
  final BenefitType benefitType;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: const AppBackAppBar(title: Text('تفاصيل المنفعة')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
            children: [
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volunteer_activism,
                    color: AppTheme.primary,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                benefitType.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              if (benefitType.description.isNotEmpty) ...[
                const Text(
                  'الوصف',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    benefitType.description,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: scheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
              
              const Text(
                'ملاحظات هامة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: scheme.error, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'يرجى العلم بأنه قد يُطلب منك إرفاق مستندات أو تعبئة استبيان قصير لتقييم مدى أهليتك لهذه المنفعة قبل إتمام الطلب.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: SafeArea(
                child: FilledButton(
                  onPressed: () {
                    // The route's charity id wins, but the benefit type now
                    // carries its own, so a caller that has none still
                    // builds a valid path.
                    final owner = charityId.trim().isNotEmpty
                        ? charityId
                        : benefitType.charityId;
                    context.push(
                      '/charities/$owner/benefits/${benefitType.id}/apply',
                      extra: benefitType,
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'متابعة لتقديم الطلب',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
