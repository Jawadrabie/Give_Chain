import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/url_resolver.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/dynamic_answer_field.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../../../core/widgets/app_back_app_bar.dart';

class InfoAnswersScreen extends StatefulWidget {
  const InfoAnswersScreen({super.key});

  @override
  State<InfoAnswersScreen> createState() => _InfoAnswersScreenState();
}

class _InfoAnswersScreenState extends State<InfoAnswersScreen> {
  late Future<_InfoAnswersData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_InfoAnswersData> _load() async {
    final fieldsFuture = context.read<AuthRepository>().infoFields();
    final answersFuture = context.read<ProfileRepository>().infoAnswers();
    final fields = await fieldsFuture;
    final answers = await answersFuture;
    return _InfoAnswersData(fields: fields, answers: answers);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(title: const Text('معلوماتي الإضافية')),
    body: FutureBuilder<_InfoAnswersData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorRetry(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final data = snapshot.data;
        if (data == null || (data.fields.isEmpty && data.answers.isEmpty)) {
          return const EmptyView(
            message: 'لا توجد حقول معلومات إضافية مطلوبة.',
          );
        }
        final answerByField = {
          for (final answer in data.answers) answer.fieldId: answer,
        };
        final entries = <_InfoEntry>[
          for (final field in data.fields)
            _InfoEntry(field: field, answer: answerByField[field.id]),
          for (final answer in data.answers)
            if (!data.fields.any((field) => field.id == answer.fieldId))
              _InfoEntry(
                field: PersonInfoField(
                  id: answer.fieldId,
                  fieldName: answer.fieldName,
                  fieldType: 0,
                  isRequired: false,
                ),
                answer: answer,
              ),
        ];
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final value = entry.answer?.answer.trim() ?? '';
              final attachments = entry.answer?.attachments ?? const <String>[];
              final answered = value.isNotEmpty || attachments.isNotEmpty;
              return Card(
                child: ListTile(
                  leading: Icon(
                    answered
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.field.fieldName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (entry.field.isRequired)
                        const Chip(label: Text('مطلوب')),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value.isNotEmpty
                            ? value
                            : attachments.isEmpty
                                ? 'لم تتم الإجابة بعد'
                                : 'تمت الإجابة بمرفقات',
                      ),
                      if (attachments.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final url in attachments)
                              ActionChip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.attach_file, size: 14),
                                label: Text(
                                  _attachmentLabel(url),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () => _openAttachment(url),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  isThreeLine: attachments.isNotEmpty,
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _edit(entry),
                ),
              );
            },
          ),
        );
      },
    ),
  );

  /// Last path segment of an attachment URL, for a compact chip label.
  static String _attachmentLabel(String url) {
    final path = Uri.tryParse(url)?.pathSegments;
    final name = (path == null || path.isEmpty) ? '' : path.last;
    final label = name.isEmpty ? url : name;
    return label.length <= 24 ? label : '${label.substring(0, 21)}…';
  }

  Future<void> _openAttachment(String url) async {
    final uri = UrlResolver.external(UrlResolver.resolve(url));
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _edit(_InfoEntry entry) async {
    final controller = TextEditingController(text: entry.answer?.answer ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.field.fieldName),
        content: SingleChildScrollView(
          child: DynamicAnswerField(
            label: entry.field.fieldName,
            fieldType: entry.field.fieldType,
            isRequired: entry.field.isRequired,
            controller: controller,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (entry.field.isRequired && text.isEmpty) return;
              Navigator.pop(context, text);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    try {
      await context.read<ProfileRepository>().upsertInfoAnswer(
        fieldId: entry.field.id,
        answer: value,
      );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _InfoAnswersData {
  const _InfoAnswersData({required this.fields, required this.answers});
  final List<PersonInfoField> fields;
  final List<PersonInfoAnswer> answers;
}

class _InfoEntry {
  const _InfoEntry({required this.field, this.answer});
  final PersonInfoField field;
  final PersonInfoAnswer? answer;
}
