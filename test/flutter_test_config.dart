import 'dart:async';

import 'package:flip7_flutter/ui/theme.dart';

/// Runs before every test file: widgets must not try to download fonts.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  downloadFonts = false;
  await testMain();
}
