import 'package:flutter/material.dart';

import 'app/app.dart';
import 'bootstrap/app_bootstrap.dart';

Future<void> main() async {
  await AppBootstrap.initialize();
  runApp(const BanyixiaApp());
}
