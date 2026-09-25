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
        home: !controller.initialized
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : controller.hasSession
                ? HomeScreen(controller: controller)
                : EntryScreen(controller: controller),
      ),
    );
  }
}
