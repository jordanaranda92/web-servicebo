import 'package:flutter/widgets.dart';

import 'app/config/environments/pro_config.dart';
import 'main.dart';

/// Entry point for pro environment.
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await runApplication(ProConfig());
}
