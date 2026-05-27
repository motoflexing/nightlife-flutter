# Nightlife Platform

Flutter and Firebase workspace for the Nightlife mobile app, public website,
and isolated Super Admin dashboard.

## Applications

- `apps/mobile` - mobile app for users, promoters, and venue admins.
- `apps/website` - public responsive website with event listings, details, and RSVP sign-in flow.
- `apps/admin` - separate web dashboard for Super Admin operations.
- `packages/nightlife_shared` - shared Firebase models, services, theme, and reusable backend access.

All apps use the same Firebase project and existing Firestore/Storage schemas.

## Common Commands

```bash
cd apps/mobile
flutter pub get
flutter run
```

```bash
cd apps/website
flutter pub get
flutter run -d chrome
```

```bash
cd apps/admin
flutter pub get
flutter run -d chrome
```

## Firebase Rules

Firestore and Storage rules stay at the workspace root:

- `firestore.rules`
- `storage.rules`

Active event documents and event poster images are publicly readable for the
website. User data, RSVP writes, venue management, promoter data, and admin
operations remain role protected.
