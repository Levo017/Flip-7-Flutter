import 'package:flutter/material.dart';

import 'game_controller.dart';
import 'ui/game_screen.dart';
import 'ui/setup_screen.dart';
import 'ui/theme.dart';

void main() => runApp(const Flip7App());

class Flip7App extends StatefulWidget {
  const Flip7App({super.key});

  @override
  State<Flip7App> createState() => _Flip7AppState();
}

class _Flip7AppState extends State<Flip7App> {
  final _controller = GameController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flip 7: With a Vengeance',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _controller.game == null
            ? SetupScreen(
                onStart: (players, brutal) =>
                    _controller.start(players, brutal: brutal),
              )
            : GameScreen(controller: _controller),
      ),
    );
  }
}
