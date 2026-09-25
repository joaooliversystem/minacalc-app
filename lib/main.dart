import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  await controller.initialize();
  runApp(MinaCalcApp(controller: controller));
}
