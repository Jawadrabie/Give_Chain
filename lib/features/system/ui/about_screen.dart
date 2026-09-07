import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_back_app_bar.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(title: const Text('حول GiveChain')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryLight],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Column(
            children: [
              AppLogo(size: 80),
              SizedBox(height: 14),
              Text(
                'GiveChain',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'منصة للتبرع والعمل الخيري تركّز على الثقة والشفافية وتتبع أثر العطاء.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.phone_android_outlined),
                title: Text('نسخة التطبيق'),
                subtitle: Text('3.0.0'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.language_outlined),
                title: Text('الموقع الرسمي'),
                subtitle: SelectableText('give-chain-production.vercel.app'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.email_outlined),
                title: Text('تواصل عبر الإيميل'),
                subtitle: SelectableText('support@give-chain.com'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مبادئ التجربة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 12),
                _ValueRow(
                  icon: Icons.verified_user_outlined,
                  title: 'الثقة',
                  text: 'حالات واضحة وشارات حالة موحّدة.',
                ),
                _ValueRow(
                  icon: Icons.account_tree_outlined,
                  title: 'الشفافية',
                  text: 'تتبّع مسار التبرع من المتبرع إلى المستفيد.',
                ),
                _ValueRow(
                  icon: Icons.accessibility_new_outlined,
                  title: 'سهولة الوصول',
                  text: 'واجهة عربية RTL وحالات تحميل وخطأ وفراغ متناسقة.',
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: AppTheme.softOf(context),
          child: Icon(icon, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(text, style: const TextStyle(height: 1.45)),
            ],
          ),
        ),
      ],
    ),
  );
}
