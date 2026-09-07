import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_back_app_bar.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/dynamic_answer_field.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../data/benefit_models.dart';
import '../data/benefit_repository.dart';

/// The single "apply for a benefit" flow, used from both entry points.
///
/// Step 1 picks a benefit type, step 2 answers that type's questions. When
/// [initialCharityId] is supplied (opened from a charity's Benefits tab) the
/// picker is scoped to that charity; without it (opened from the profile) the
/// picker spans every charity and doubles as the charity chooser, since a
/// benefit type belongs to exactly one charity.
///
/// [initialBenefitType] skips step 1 entirely when the caller already holds
/// the chosen type.
class BenefitApplyScreen extends StatefulWidget {
  const BenefitApplyScreen({
    super.key,
    this.initialCharityId = '',
    this.charityName = '',
    this.initialBenefitType,
  });

  final String initialCharityId;
  final String charityName;
  final BenefitType? initialBenefitType;

  @override
  State<BenefitApplyScreen> createState() => _BenefitApplyScreenState();
}

class _BenefitApplyScreenState extends State<BenefitApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _searchController = TextEditingController();

  List<BenefitType> _types = const [];
  BenefitType? _selected;
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.initialBenefitType;
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // A caller-supplied type already carries its questions, so the picker's
    // list is never needed and the (possibly 404ing) lookup is skipped.
    if (widget.initialBenefitType != null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final types = await context.read<BenefitRepository>().benefitTypes(
        charityId: widget.initialCharityId,
      );
      if (!mounted) return;
      setState(() {
        _types = types;
        _loading = false;
        // A charity offering exactly one benefit type has nothing to choose,
        // so step 1 is skipped and the form opens directly.
        if (types.length == 1 && widget.initialCharityId.isNotEmpty) {
          _selected = types.first;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  void _choose(BenefitType type) {
    // Answers belong to the questions of one type; switching type must not
    // carry stale answers across.
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    setState(() => _selected = type);
  }

  void _back() {
    // Only offer a way back to the picker when there is a choice to remake.
    if (widget.initialBenefitType != null || _types.length <= 1) {
      context.pop();
      return;
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    setState(() => _selected = null);
  }

  Future<void> _submit() async {
    final type = _selected;
    if (type == null || _formKey.currentState?.validate() != true) return;

    setState(() => _submitting = true);
    try {
      // Required questions always travel; optional ones only when answered, so
      // the backend can tell "skipped" from "answered with an empty string".
      final answers = <BenefitAnswer>[
        for (final question in type.questions)
          if (question.isRequired ||
              (_controllers[question.id]?.text.trim().isNotEmpty ?? false))
            BenefitAnswer(
              questionId: question.id,
              questionText: question.text,
              answer: _controllers[question.id]?.text.trim() ?? '',
            ),
      ];

      await context.read<BenefitRepository>().submit(
        benefitTypeId: type.id,
        answers: answers,
        // Cached locally so "طلباتي" can label the request; the list
        // endpoint does not echo any of this back yet.
        benefitTypeName: type.name,
        charityId: type.charityId.isEmpty
            ? widget.initialCharityId
            : type.charityId,
        charityName: type.charityName,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب المنفعة بنجاح، وهو الآن قيد المراجعة.'),
        ),
      );
      // `pop(true)` lets the charity tab refresh in place; when this screen was
      // opened as a root destination there is nothing to pop back to, so fall
      // through to the applications list instead.
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/benefits/my');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBackAppBar(
        title: Text(
          selected == null
              ? 'اختر نوع المنفعة'
              : 'طلب ${selected.name}',
        ),
      ),
      body: _loading
          ? const SkeletonList(count: 4)
          : _loadError != null && selected == null
          ? ErrorRetry(message: _loadError!, onRetry: _load)
          : selected == null
          ? _picker()
          : _form(selected),
    );
  }

  // ── Step 1: choose a benefit type ────────────────────────────────────────

  Widget _picker() {
    final query = _search.trim().toLowerCase();
    final visible = query.isEmpty
        ? _types
        : _types
              .where(
                (type) =>
                    type.name.toLowerCase().contains(query) ||
                    type.charityName.toLowerCase().contains(query),
              )
              .toList();

    if (_types.isEmpty) {
      return EmptyView(
        message: widget.initialCharityId.isEmpty
            ? 'لا توجد أنواع منافع متاحة حاليًا.'
            : 'لا تقدم هذه الجمعية أي منافع فعالة حاليًا.',
        icon: Icons.redeem_outlined,
        actionLabel: 'إعادة المحاولة',
        onAction: _load,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: 'ابحث عن منفعة...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const EmptyView(
                  message: 'لا توجد نتائج مطابقة لبحثك.',
                  icon: Icons.search_off,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final type = visible[index];
                    final questionCount = type.questions.length;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: const Icon(
                            Icons.redeem_outlined,
                            color: AppTheme.primary,
                          ),
                        ),
                        title: Text(
                          type.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          [
                            if (type.charityName.isNotEmpty) type.charityName,
                            if (type.description.isNotEmpty) type.description,
                            if (questionCount > 0)
                              '$questionCount ${questionCount == 1 ? 'سؤال' : 'أسئلة'}',
                          ].join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                        ),
                        onTap: () => _choose(type),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Step 2: answer the type's questions ──────────────────────────────────

  Widget _form(BenefitType type) {
    final questions = type.questions;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _header(type),
          const SizedBox(height: 20),
          if (questions.isEmpty)
            const _InfoBanner(
              icon: Icons.check_circle_outline,
              message:
                  'لا تتطلب هذه المنفعة أي بيانات إضافية. اضغط إرسال لتقديم طلبك.',
            )
          else ...[
            // The wire format for multi-select and attachment answers is not
            // pinned down by the backend contract yet, so the form still
            // accepts them (blocking the whole request would be worse) but
            // warns that the charity may follow up for those two.
            if (questions.any(_needsBackendConfirmation)) ...[
              const _InfoBanner(
                icon: Icons.info_outline,
                message:
                    'يحتوي هذا النموذج على حقول قد تحتاج تأكيداً إضافياً من '
                    'الجمعية بعد الإرسال (اختيارات متعددة أو مرفقات).',
              ),
              const SizedBox(height: 14),
            ],
            for (final question in questions) ...[
              DynamicAnswerField(
                label: question.text,
                fieldType: question.fieldType,
                isRequired: question.isRequired,
                options: question.options,
                enabled: !_submitting,
                controller: _controllers.putIfAbsent(
                  question.id,
                  TextEditingController.new,
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              _submitting ? 'جارٍ الإرسال...' : 'إرسال الطلب',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (widget.initialBenefitType == null && _types.length > 1) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _submitting ? null : _back,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('اختيار نوع منفعة آخر'),
            ),
          ],
        ],
      ),
    );
  }

  /// Whether a question uses one of the two field types whose submission
  /// format the backend has not confirmed: MultiOption (6) — no agreed
  /// delimiter for joining the selected values — and Attachment (4), which has
  /// no upload endpoint feeding this JSON-only submit.
  static bool _needsBackendConfirmation(BenefitQuestion question) =>
      question.fieldType == 4 || question.fieldType == 6;

  Widget _header(BenefitType type) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        type.name,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
      if (type.charityName.isNotEmpty || widget.charityName.isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.apartment_outlined, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                type.charityName.isNotEmpty
                    ? type.charityName
                    : widget.charityName,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ],
      if (type.description.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(type.description, style: const TextStyle(height: 1.6)),
      ],
    ],
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(height: 1.5, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
