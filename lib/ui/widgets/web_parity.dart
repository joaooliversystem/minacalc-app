import 'package:flutter/material.dart';

import '../theme.dart';

class MCPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const MCPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF121A22), Color(0xFF0E151B)]),
          border: Border.all(color: MinaTheme.border),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: child,
      );
}

class MCPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  const MCPageHeader({super.key, required this.title, required this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: MinaTheme.muted, fontSize: 13)),
          ])),
          if (action != null) ...[const SizedBox(width: 10), action!],
        ]),
      );
}

class MCKpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool warning;
  const MCKpi({super.key, required this.icon, required this.label, required this.value, this.warning = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF141D25), Color(0xFF0E151C)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MinaTheme.border),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: const Color(0xFF131B22), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFF34404A))),
            child: Icon(icon, color: warning ? MinaTheme.red : MinaTheme.yellow, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFAEB5BC), fontSize: 11)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ])),
        ]),
      );
}

class MCStatus extends StatelessWidget {
  final String text;
  const MCStatus(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = text.toLowerCase();
    Color c;
    if (RegExp(r'conclu|ativo|emitido|aprovado|disponível|conforme').hasMatch(s)) {
      c = MinaTheme.green;
    } else if (RegExp(r'andamento|revis|pendente|atenção|aguard').hasMatch(s)) {
      c = MinaTheme.yellow2;
    } else if (RegExp(r'planejad').hasMatch(s)) {
      c = MinaTheme.blue;
    } else if (RegExp(r'paus|arquiv|inativo').hasMatch(s)) {
      c = MinaTheme.muted;
    } else {
      c = MinaTheme.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withValues(alpha: .55))),
      child: Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class MCEmpty extends StatelessWidget {
  final String title;
  final String text;
  const MCEmpty({super.key, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => MCPanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Column(children: [
            const Icon(Icons.inventory_2_outlined, size: 42, color: MinaTheme.muted),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: MinaTheme.muted)),
          ]),
        ),
      );
}

class MCPendingDot extends StatelessWidget {
  final bool pending;
  const MCPendingDot({super.key, required this.pending});
  @override
  Widget build(BuildContext context) => pending
      ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: .14), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.orangeAccent.withValues(alpha: .45))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cloud_upload_outlined, size: 13, color: Colors.orangeAccent), SizedBox(width: 4), Text('Pendente', style: TextStyle(fontSize: 10, color: Colors.orangeAccent, fontWeight: FontWeight.w800))]),
        )
      : const SizedBox.shrink();
}

class MCFadeIn extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const MCFadeIn({super.key, required this.child, this.delayMs = 0});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 320 + delayMs),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0, end: 1),
        builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child)),
        child: child,
      );
}

Future<bool> mcConfirm(BuildContext context, {required String title, required String text, String confirm = 'Confirmar'}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirm)),
          ],
        ),
      ) ??
      false;
}

void mcToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? const Color(0xFF6E2427) : const Color(0xFF17251B),
    behavior: SnackBarBehavior.floating,
  ));
}
