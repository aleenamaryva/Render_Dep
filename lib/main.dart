import 'package:flutter/material.dart';

import 'app.dart';
import 'services/app_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSession.outboxService.init();
  AppSession.meshService.initialize();
  runApp(const LifeTraceApp());
}

