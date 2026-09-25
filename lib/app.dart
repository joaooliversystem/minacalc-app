import 'package:flutter/material.dart';

import 'controllers/app_controller.dart';
import 'ui/screens/entry_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

class MinaCalcApp extends StatelessWidget {
  final AppController controller;
  const MinaCalcApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        title: 'MinaCalc Pro',
        debugShowCheckedModeBanner: false,
        theme: MinaTheme.dark(),
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: !controller.initialized
              ? const _Splash(key: ValueKey('splash'))
              : controller.hasSession
                  ? HomeScreen(key: const ValueKey('home'), controller: controller)
                  : EntryScreen(key: const ValueKey('entry'), controller: controller),
        ),
      ),
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash({super.key});
  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  @override
  void dispose() { c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.28), radius: 1.05, colors: [Color(0xFF17212A), MinaTheme.bg]))),
          Center(
            child: FadeTransition(
              opacity: Tween<double>(begin: .55, end: 1).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/logo.png', width: 280),
                const SizedBox(height: 22),
                RotationTransition(turns: c, child: const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3, color: MinaTheme.yellow))),
                const SizedBox(height: 14),
                const Text('Preparando MinaCalc Pro...', style: TextStyle(color: MinaTheme.muted)),
              ]),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: Image.asset('assets/hazard.png', height: 52, width: double.infinity, fit: BoxFit.cover)),
        ],
      ),
    );
  }
}
