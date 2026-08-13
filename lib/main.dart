import 'package:flutter/material.dart';

import 'app/app.dart';
import 'bootstrap/app_bootstrap.dart';

Future<void> main() async {
  AppBootstrap.appVariant = 'customer';
  await AppBootstrap.initialize();
  runApp(const BanyixiaApp());
}
