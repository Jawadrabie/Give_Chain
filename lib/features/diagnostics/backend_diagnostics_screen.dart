import 'package:flutter/material.dart';

import '../../core/config/api_paths.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_failure.dart';
import '../../core/network/json_helpers.dart';
import '../../core/widgets/app_back_app_bar.dart';

class BackendDiagnosticsScreen extends StatefulWidget {
  const BackendDiagnosticsScreen({super.key});

  @override
  State<BackendDiagnosticsScreen> createState() =>
      _BackendDiagnosticsScreenState();
}

class _BackendDiagnosticsScreenState extends State<BackendDiagnosticsScreen> {
  late Future<List<_DiagnosticResult>> _future;

  @override
  void initState() {
    super.initState();
    _future = _run();
  }

  Future<List<_DiagnosticResult>> _run() async {
    final client = ApiClient.instance;
    final checks = <_Check>[
      const _Check('الصفحة الرئيسية', 'GET', ApiPaths.home, public: true),
      const _Check(
        'الحملات',
        'GET',
        ApiPaths.campaigns,
        public: true,
        paged: true,
      ),
      const _Check('الحالات', 'GET', ApiPaths.cases, public: true, paged: true),
      const _Check(
        'الجمعيات',
        'GET',
        ApiPaths.charities,
        public: true,
        paged: true,
      ),
      const _Check('الدول', 'GET', ApiPaths.countries, public: true),
      const _Check('المدن', 'GET', ApiPaths.citiesPath, public: true),
      const _Check(
        'حقول التسجيل الإضافية',
        'GET',
        ApiPaths.infoFields,
        public: true,
      ),
      const _Check('الملف الشخصي', 'GET', ApiPaths.profile),
      const _Check('تبرعاتي', 'GET', ApiPaths.donations, paged: true),
      const _Check('تتبع جميع التبرعات', 'GET', ApiPaths.donationTraceAll),
      const _Check('طلبات المنافع', 'GET', ApiPaths.benefits, paged: true),
      const _Check('شكاواي', 'GET', ApiPaths.complaints, paged: true),
      const _Check('الإشعارات', 'GET', ApiPaths.notifications, paged: true),
      const _Check(
        'عدد الإشعارات غير المقروءة',
        'GET',
        ApiPaths.notificationUnreadCount,
      ),
      const _Check(
        'إجابات معلوماتي الإضافية',
        'GET',
        ApiPaths.profileInfoAnswers,
      ),
    ];
    final results = <_DiagnosticResult>[];
    for (final check in checks) {
      try {
        final raw = await client.request(
          check.method,
          check.path,
          query: check.paged ? const {'page': 1, 'pageSize': 1} : null,
          requiresAuth: !check.public,
        );
        final count = check.paged ? JsonHelpers.objectList(raw).length : null;
        results.add(
          _DiagnosticResult(
            check: check,
            success: true,
            message: count == null
                ? 'تم تنفيذ طلب قراءة بنجاح.'
                : 'تم تنفيذ الطلب وقراءة $count عنصر من صفحة الاختبار.',
          ),
        );
      } on ApiFailure catch (failure) {
        results.add(
          _DiagnosticResult(
            check: check,
            success: false,
            message: failure.statusCode == null
                ? failure.message
                : '${failure.message} (HTTP ${failure.statusCode})',
          ),
        );
      }
    }
    return results;
  }

  void _reload() => setState(() => _future = _run());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(
      title: const Text('تشخيص ربط الـAPI'),
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: 'إعادة الفحص',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<_DiagnosticResult>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final items = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'يعتمد هذا الفحص على دليل Mobile API الرسمي. ينفذ طلبات GET فقط ولا ينشئ تبرعات أو شكاوى ولا يغيّر بيانات الحساب.',
                  style: TextStyle(height: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final item in items)
              Card(
                child: ListTile(
                  leading: Icon(
                    item.success ? Icons.check_circle : Icons.error_outline,
                    color: item.success ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    item.check.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${item.check.method} ${item.check.path}\n${item.message}',
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _Check {
  const _Check(
    this.title,
    this.method,
    this.path, {
    this.public = false,
    this.paged = false,
  });
  final String title;
  final String method;
  final String path;
  final bool public;
  final bool paged;
}

class _DiagnosticResult {
  const _DiagnosticResult({
    required this.check,
    required this.success,
    required this.message,
  });
  final _Check check;
  final bool success;
  final String message;
}
