import 'package:flutter/widgets.dart';

import 'app/config/environments/dev_config.dart';
import 'main.dart';

/// Entry point for dev environment.
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await runApplication(DevConfig());
}
