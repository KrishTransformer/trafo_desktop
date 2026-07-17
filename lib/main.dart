import 'package:flutter/widgets.dart';

import 'src/app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await bootstrap();
  runApp(app);
}
