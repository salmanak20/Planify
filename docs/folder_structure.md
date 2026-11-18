# Planify Folder Structure

This workspace is now Firebase-first: the Flutter app uses Firebase Auth and
Cloud Firestore directly for backend data. The old FastAPI backend is kept only
as legacy/local reference code and no longer has cloud deployment
configuration.

```text
Planify/
|-- planify_app/
|   |-- lib/
|   |   |-- core/           # Theme, routing, Firebase services, shared helpers
|   |   |-- data/           # Firestore repositories, local cache, models
|   |   |-- presentation/   # Screens and reusable widgets
|   |   `-- providers/      # Riverpod state + application services
|   |-- android/
|   |-- ios/
|   `-- pubspec.yaml
|-- backend/                # Legacy FastAPI/SQLAlchemy backend reference
|   |-- app/
|   |-- alembic/
|   |-- requirements.txt
|   |-- schema.sql
|   `-- seed_data.py
`-- stitch/                 # Design explorations and source visuals
```

Architecture notes:

- Authentication: Firebase Auth
- Data backend: Cloud Firestore via Flutter repositories
- Local resilience: shared preferences/Hive-backed cache helpers
- Notifications and focus timer: local device services with optional Firestore logs
- Smart Insights: Flutter calls the existing FastAPI service at
  `POST /insights/smart`; the service verifies a Firebase ID token and calls
  Gemini with a server-only `GEMINI_API_KEY`. No Gemini key belongs in the app.

## Smart Insights setup and contract

The Flutter card uses `PLANIFY_API_BASE_URL` only as a nonsecret endpoint
location (for example, `https://api.example.com`). If it is unset or the
service is unavailable, the card displays a safe unavailable message. Configure
it at build time with `--dart-define=PLANIFY_API_BASE_URL=https://...`; never
pass a Gemini credential to Flutter or a `dart-define`.

The existing `backend/` FastAPI service hosts the protected endpoint:

- `POST /insights/smart`
- `Authorization: Bearer <Firebase ID token>`; the service verifies the token
  with Firebase Admin and uses the verified UID for rate limiting.
- JSON body: `{"tasks":["..."],"notes":["..."]}`. Each list accepts at most
  five titles, each no longer than 200 characters; extra fields are rejected.
- Successful response: `{"insight":"..."}`.
- Errors: `401` for missing/invalid authentication, `413` for oversized body,
  `415` for non-JSON, `422` for malformed/invalid payload, `429` after ten
  requests per authenticated user per minute, and `502`/`503` for provider
  failure or missing server configuration.

For local backend use, configure `FIREBASE_PROJECT_ID` and Firebase Admin
credentials as described in `backend/.env.example`, then set `GEMINI_API_KEY`
and optionally `GEMINI_MODEL` in the backend environment. In production, use
the hosting provider's secret manager for both credentials. The current rate
limiter is process-local; deployments with multiple workers/instances should
replace it with a shared rate-limit store before relying on a global quota.

The Gemini key previously committed in the Flutter source must be revoked and
rotated by the project owner. This code change does not rotate it.
