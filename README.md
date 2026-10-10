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

## Test

Unit and widget tests, with a coverage report in `coverage/lcov.info`:

```bash
flutter test --coverage
```

Per-file coverage summary; exits non-zero below the minimum (default 90%):

```bash
dart run tool/coverage.dart
```

End-to-end UI test that plays a round in the real app on a device or emulator:

```bash
flutter test integration_test -d <device-id>
```

| Tests | What they cover |
| --- | --- |
| `test/game/cards_test.dart` | `GameCard` and the 108-card deck |
| `test/game/game_test.dart` | `Player`, scoring and every rule in `Game` |
| `test/game/bot_test.dart` | each decision the CPU players make |
| `test/game/simulation_test.dart` | 150 complete all-CPU games |
| `test/game_controller_test.dart` | `GameController` timing, focus and card selection |
| `test/ui/*_test.dart` | every widget and screen, at desktop, tablet and phone sizes |
| `test/main_test.dart` | the app shell: setup → game → setup |
| `integration_test/app_test.dart` | a full round on a device |

## Layout

- `lib/game/` — the rules, with no Flutter imports: `cards.dart` (the 108-card
  deck), `game.dart` (the `Game` state machine) and `bot.dart` (CPU players).
- `lib/game_controller.dart` — a `ChangeNotifier` that owns the running game and
  paces dealing and CPU turns with timers.
- `lib/ui/` — the screens and widgets.

Fonts (DM Mono, Space Grotesk) are fetched at runtime by `google_fonts`, so the
first launch needs a network connection.
