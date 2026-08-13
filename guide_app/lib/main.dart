import 'package:flutter/material.dart';

import 'bootstrap/app_bootstrap.dart';
import 'guide_app/guide_app.dart';

Future<void> main() async {
  AppBootstrap.appVariant = 'guide';
  await AppBootstrap.initialize();
  runApp(const GuideApp());
}
