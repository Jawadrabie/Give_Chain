import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/async_view.dart';
import '../data/system_repository.dart';
import '../../../core/widgets/app_back_app_bar.dart';

class CharitySubdomainScreen extends StatefulWidget {
  const CharitySubdomainScreen({super.key, required this.subdomain});
  final String subdomain;

  @override
  State<CharitySubdomainScreen> createState() => _CharitySubdomainScreenState();
}

class _CharitySubdomainScreenState extends State<CharitySubdomainScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    setState(() => _error = null);
    try {
      final id = await context.read<SystemRepository>().charityIdBySubdomain(
        widget.subdomain,
      );
      if (mounted) context.go('/charities/$id');
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(title: const Text('فتح الجمعية')),
    body: _error == null
        ? const Center(child: CircularProgressIndicator())
        : ErrorRetry(message: _error.toString(), onRetry: _resolve),
  );
}
