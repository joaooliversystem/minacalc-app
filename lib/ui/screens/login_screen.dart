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
  void dispose() { user.dispose(); password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(widget.controller.language);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/quarry.png', fit: BoxFit.cover),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xE6071017), Color(0xFA080C10)]))),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              children: [
                Row(children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                  const Spacer(),
                  SegmentedButton<String>(
                    segments: const [ButtonSegment(value: 'pt-BR', label: Text('PT')), ButtonSegment(value: 'en', label: Text('EN')), ButtonSegment(value: 'es', label: Text('ES'))],
                    selected: {widget.controller.language},
                    onSelectionChanged: (set) => widget.controller.setLanguage(set.first),
                  ),
                ]),
                const SizedBox(height: 16),
                Center(child: Image.asset('assets/logo.png', width: 245)),
                const SizedBox(height: 20),
                Text(_tr('Gestão integrada de operações', 'Integrated operations management', 'Gestión integrada de operaciones'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(_tr('Planejamento, campo, segurança e relatórios', 'Planning, field, safety and reports', 'Planificación, campo, seguridad e informes'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB8BEC5))),
                const SizedBox(height: 16),
                Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(color: const Color(0xFF0F1C16), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFF285138))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.circle, size: 10, color: MinaTheme.green), const SizedBox(width: 8), Text('${_tr('Termo aceito', 'Notice accepted', 'Término aceptado')} · v${widget.controller.termsVersion}', style: const TextStyle(color: Color(0xFF70D681), fontSize: 12, fontWeight: FontWeight.w700))]))),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xEE151B20), Color(0xEE0D1217)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: MinaTheme.border2), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 40, offset: Offset(0, 18))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_tr('Acesse sua conta', 'Access your account', 'Acceda a su cuenta'), style: const TextStyle(color: MinaTheme.yellow, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 18),
                    TextField(controller: user, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: s.t('user'))),
                    const SizedBox(height: 14),
                    TextField(controller: password, obscureText: true, onSubmitted: (_) => _submit(), decoration: InputDecoration(labelText: s.t('password'))),
                    if (widget.controller.authError != null) ...[const SizedBox(height: 12), Text(widget.controller.authError!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)],
                    const SizedBox(height: 18),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: busy ? null : _submit, icon: busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward), label: Text(s.t('login').toUpperCase()))),
                    Center(child: TextButton(onPressed: busy ? null : _forgotPassword, child: Text(s.t('forgotPassword')))),
                  ]),
                ),
                const SizedBox(height: 18),
                const Text('MinaCalc Pro · Operação segura e rastreável', textAlign: TextAlign.center, style: TextStyle(color: MinaTheme.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tr(String pt, String en, String es) => switch (widget.controller.language) { 'en' => en, 'es' => es, _ => pt };

  Future<void> _forgotPassword() async {
    final s = AppStrings(widget.controller.language);
    final email = TextEditingController();
    final submitted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(s.t('forgotPassword')), content: TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: s.t('email'))), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('back'))), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('resetSend')))]));
    if (submitted != true || email.text.trim().isEmpty) { email.dispose(); return; }
    try { await widget.controller.api.requestPasswordReset(email.text.trim()); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('resetSent')))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { email.dispose(); }
  }

  Future<void> _submit() async {
    if (user.text.trim().isEmpty || password.text.isEmpty) return;
    setState(() => busy = true);
    final ok = await widget.controller.login(user.text.trim(), password.text);
    if (mounted) setState(() => busy = false);
    if (ok && mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
