import 'package:flutter/widgets.dart';

import 'app/config/environments/local_config.dart';
import 'main.dart';

/// Entry point for local environment.
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await runApplication(LocalConfig());
}
