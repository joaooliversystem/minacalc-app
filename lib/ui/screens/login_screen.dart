import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../core/i18n.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  final AppController controller;
  const LoginScreen({super.key, required this.controller});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final user = TextEditingController();
  final password = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    user.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(widget.controller.language);
    return Scaffold(
      appBar: AppBar(title: const Text('MinaCalc Pro')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(children: [
              const Icon(Icons.engineering, color: MinaTheme.yellow, size: 72),
              const SizedBox(height: 12),
              const Text('MinaCalc Pro', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(s.t('loginOnline'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 24),
              TextField(controller: user, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: s.t('user'), prefixIcon: const Icon(Icons.person_outline))),
              const SizedBox(height: 14),
              TextField(controller: password, obscureText: true, onSubmitted: (_) => _submit(), decoration: InputDecoration(labelText: s.t('password'), prefixIcon: const Icon(Icons.key_outlined))),
              if (widget.controller.authError != null) ...[
                const SizedBox(height: 14),
                Text(widget.controller.authError!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(onPressed: busy ? null : _submit, icon: busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: Text(s.t('login').toUpperCase())),
              const SizedBox(height: 8),
              TextButton(onPressed: busy ? null : _forgotPassword, child: Text(s.t('forgotPassword'))),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final s = AppStrings(widget.controller.language);
    final email = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('forgotPassword')),
        content: TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: s.t('email'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('back'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('resetSend'))),
        ],
      ),
    );
    if (submitted != true || email.text.trim().isEmpty) {
      email.dispose();
      return;
    }
    try {
      await widget.controller.api.requestPasswordReset(email.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('resetSent'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      email.dispose();
    }
  }

  Future<void> _submit() async {
    if (user.text.trim().isEmpty || password.text.isEmpty) return;
    setState(() => busy = true);
    final ok = await widget.controller.login(user.text.trim(), password.text);
    if (mounted) setState(() => busy = false);
    if (ok && mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
