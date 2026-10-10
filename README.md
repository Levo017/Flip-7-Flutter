# Flip 7: With a Vengeance (Flutter)

A Flutter version of the press-your-luck card game, for web and Android. It is a
port of the React app in `../flip7-vengeance` and follows the same rules and
visual design.

## Run

```bash
flutter run -d chrome
```

```bash
flutter run -d <android-device-id>
```

```bash
flutter test
```

## Layout

- `lib/game/` — the rules, with no Flutter imports: `cards.dart` (the 108-card
  deck), `game.dart` (the `Game` state machine) and `bot.dart` (CPU players).
- `lib/game_controller.dart` — a `ChangeNotifier` that owns the running game and
  paces dealing and CPU turns with timers.
- `lib/ui/` — the screens and widgets.
- `test/engine_test.dart` — rule checks plus 150 simulated all-CPU games.

Fonts (DM Mono, Space Grotesk) are fetched at runtime by `google_fonts`, so the
first launch needs a network connection.
