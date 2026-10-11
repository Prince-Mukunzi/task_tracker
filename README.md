# Pulse

A task tracker for small teams that keeps deadlines honest. Every task carries
a deadline, and Pulse tells you at a glance whether it is on track, at risk, or
already overdue.

Built with Flutter. Everything is stored on the device, so there is no backend
to set up and no account to create anywhere else.

## What it does

- **Dashboard** with a daily briefing, tasks grouped by urgency, and charts
  for SLA health and status breakdown.
- **Tasks** with search and filters for status, assignee, priority, and
  deadline.
- **Task details** with status updates, tags, multiple assignees, and a
  comment thread.
- **Team** list of the people tasks can be assigned to.
- **Notifications** for new, updated, completed, at-risk, and overdue tasks.
- **Sign in** with email and password, or with biometrics on supported
  devices.

### How SLA status works

| Status    | Meaning                          |
| --------- | -------------------------------- |
| On track  | More than 24 hours until the deadline |
| At risk   | Less than 24 hours left          |
| Overdue   | The deadline has passed          |
| Completed | The task is done                 |

## Getting started

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(Dart 3.13 or newer).

```bash
git clone git@github.com:Prince-Mukunzi/task_tracker.git
cd task_tracker
flutter pub get
flutter run
```

If you change a Hive model in `lib/models`, regenerate the adapters:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Tech stack

| Concern          | Package                              |
| ---------------- | ------------------------------------ |
| State management | `flutter_riverpod`                   |
| Tasks, team, comments | `hive` / `hive_flutter`         |
| Notifications    | `sqflite`                            |
| Credentials      | `shared_preferences`                 |
| Biometrics       | `local_auth`                         |
| Charts           | `fl_chart`                           |
| UI               | `google_fonts`, `lucide_icons_flutter`, `sprung`, `confetti` |

## Project structure

```
lib/
  main.dart      Hive setup and app entry point
  app.dart       Root widget and the auth gate
  core/          Theme, shared components, animations, formatters
  models/        Task, TeamMember, AppNotification, enums
  data/          Repositories over Hive and SQLite
  providers/     Riverpod providers
  screens/       One folder per screen
```

## Good to know

- Data never leaves the device. Uninstalling the app, or using
  *Clear All Tasks* in settings, deletes it for good.
- Authentication is local only. It keeps the app private on a shared phone,
  but it is not a substitute for a real auth server.
- The team list is seeded with sample members on first launch.
