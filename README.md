<p align="center">
  <img src="assets/logo/moodgenie_logo.svg" alt="MoodGenie Logo" width="120" />
</p>

<h1 align="center">MoodGenie</h1>

<p align="center">
  <strong>AI-Powered Mental Wellness Platform</strong><br/>
  Mood tracking · AI emotional support · Therapist discovery & booking
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/Next.js-15-000000?logo=nextdotjs&logoColor=white" alt="Next.js" />
  <img src="https://img.shields.io/badge/Node.js-Express-339933?logo=nodedotjs&logoColor=white" alt="Node.js" />
</p>

---

## 📖 Description

MoodGenie is a production-oriented wellness platform built as a monorepo with three operating surfaces:

- **Flutter Mobile App** — Mood tracking, AI-powered emotional support chat, therapist discovery, booking, in-app calling, and push notifications.
- **Express Backend** — Privileged API layer for secure mutations, AI gateway proxying (Ollama), data-rights operations, and release-health telemetry.
- **Next.js Admin Dashboard** — Therapist approvals, support operations, privacy jobs, AI incident handling, feature governance, and launch readiness tooling.

---

## ✨ Features

### For Users
- 🎭 **Mood Logging & Analytics** — Track daily moods with visual charts and historical insights
- 🤖 **AI Emotional Support Chat** — Conversational AI powered by a fine-tuned local LLM with graceful fallback states
- 🔍 **Therapist Discovery** — Browse, search, and filter verified mental health professionals
- 📅 **Appointment Booking** — Book sessions with real-time availability
- 💬 **Therapist Chat & Calling** — In-app messaging and WebRTC-based video/audio calls
- 🔔 **Smart Notifications** — Push + in-app notifications for appointments, mood reminders, and wellness insights
- 📊 **Profile & Progress** — Track your wellness journey over time
- 🌍 **Localization Ready** — i18n scaffolding for multi-language support

### For Therapists
- 📋 **Onboarding & Verification** — Structured signup with credential review
- 📆 **Scheduling Management** — Manage availability and appointments
- 💬 **Patient Communication** — Chat and call patients directly through the app

### For Admins
- ✅ **Therapist Review Queue** — Approve or reject therapist applications with audit trails
- 🛡️ **Privacy & Data Rights** — GDPR-style data export/deletion job management
- 🤖 **AI Ops** — Monitor AI incidents, review flagged conversations
- 🚦 **Feature Flags** — Toggle features without redeployment
- 📈 **System Health & Release Readiness** — Real-time operational dashboards
- 📊 **Reports & Analytics** — User engagement, mood trends, appointment metrics

---

## 🛠️ Technology Stack

| Layer | Technology |
|-------|-----------|
| **Mobile App** | Flutter 3.10+, Dart, Provider |
| **Backend** | Node.js, Express, Firebase Admin SDK |
| **Admin Dashboard** | Next.js 15 (App Router), TypeScript, React |
| **Database** | Cloud Firestore |
| **Authentication** | Firebase Auth, Google Sign-In |
| **Storage** | Firebase Cloud Storage |
| **AI / LLM** | Ollama (local LLM), Gemini API |
| **Push Notifications** | Firebase Cloud Messaging (FCM) |
| **Real-time Calling** | Flutter WebRTC |
| **Email Delivery** | Postmark (transactional emails) |
| **CI/CD** | GitHub Actions |
| **Charts** | fl_chart |
| **PDF Generation** | pdf, printing |

---

## 📁 Project Structure

```text
MoodGenie/
├── lib/                    # Flutter mobile application
│   ├── controllers/        #   State management controllers
│   ├── models/             #   Data models
│   ├── screens/            #   UI screens (auth, chat, home, etc.)
│   ├── services/           #   API & service layer
│   ├── src/                #   Core modules (auth, notifications, etc.)
│   ├── utils/              #   Helpers and utilities
│   └── main.dart           #   App entry point
├── assets/                 # Images, icons, logos
├── android/                # Android platform project
├── ios/                    # iOS platform project
├── macos/                  # macOS platform project
├── web/                    # Web platform shell
├── test/                   # Flutter test suite
├── apps/
│   └── admin/              # Next.js admin dashboard
│       ├── app/            #   Pages & API routes
│       ├── components/     #   React components
│       ├── lib/            #   Shared utilities
│       └── tests/          #   Admin tests
├── backend/                # Express API server
│   ├── server.js           #   Main server
│   ├── notifications.js    #   Notification engine
│   ├── mood_forecast.js    #   Mood forecasting
│   └── tests/              #   Backend tests
├── firebase_tests/         # Firestore rules test suite
├── scripts/                # Automation & DevOps scripts
├── docs/release/           # Release runbooks & checklists
├── firestore.rules         # Firestore security rules
├── firestore.indexes.json  # Firestore indexes
├── storage.rules           # Cloud Storage rules
├── firebase.json           # Firebase project config
└── pubspec.yaml            # Flutter dependencies
```

---

## 🚀 Installation

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.10)
- [Node.js](https://nodejs.org/) (≥ 18)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [Ollama](https://ollama.ai/) (for local AI chat)
- Xcode (for iOS/macOS builds)
- Android Studio (for Android builds)

### 1. Clone the Repository

```bash
git clone https://github.com/EshaFarrukh/MoodGenie.git
cd MoodGenie
```

### 2. Flutter Mobile App

```bash
# Install dependencies
flutter pub get

# Run on a connected device or simulator
flutter run
```

### 3. Backend Server

```bash
cd backend

# Install dependencies
npm install

# Create your environment file
cp .env.example .env
# Edit .env with your Firebase credentials

# Start the server
npm start
```

### 4. Admin Dashboard

```bash
cd apps/admin

# Install dependencies
npm install

# Create your environment file
cp .env.example .env.local
# Edit .env.local with your Firebase Admin credentials

# Start the dev server
npm run dev
```

The admin dashboard runs at `http://127.0.0.1:3001`.

### 5. Firebase Rules Tests

```bash
cd firebase_tests
npm install
npm test
```

---

## 💻 Usage

### One-Command Local Stack

Boot the entire stack (Ollama, backend, admin dashboard, iOS Simulator, Flutter app) with a single command:

```bash
./scripts/local_stack.sh start
```

**Manage the stack:**

```bash
./scripts/local_stack.sh status   # Check what's running
./scripts/local_stack.sh stop     # Stop everything
```

### Quality Gates

```bash
# Run Flutter tests
flutter test

# Dart analysis
flutter analyze --no-fatal-infos

# Firebase rules tests
cd firebase_tests && npm test

# Admin dashboard build check
cd apps/admin && npm run build

# Backend validation
cd backend && npm run check

# Full release smoke test
./scripts/release_smoke.sh
```

### Notification Jobs (Local Testing)

```bash
INTERNAL_JOB_SECRET=your-secret ./scripts/notification_jobs_local.sh all
```

---

## 🔧 Environment Configuration

### Root `.env`

| Variable | Description |
|----------|-------------|
| `GEMINI_API_KEY` | Google Gemini API key for AI features |
| `BACKEND_URL` | URL of the backend server |

### `backend/.env`

| Variable | Description |
|----------|-------------|
| `OLLAMA_URL` | Ollama server URL (default: `http://127.0.0.1:11434`) |
| `OLLAMA_MODEL` | Ollama model name |
| `PORT` | Server port (default: `3000`) |
| `FIREBASE_PROJECT_ID` | Firebase project identifier |
| `POSTMARK_SERVER_TOKEN` | Postmark email delivery token |
| `INTERNAL_JOB_SECRET` | Secret for internal scheduled jobs |

### `apps/admin/.env.local`

| Variable | Description |
|----------|-------------|
| `NEXT_PUBLIC_FIREBASE_*` | Public Firebase web config |
| `FIREBASE_CLIENT_EMAIL` | Firebase Admin service account email |
| `FIREBASE_PRIVATE_KEY` | Firebase Admin private key |
| `ADMIN_BOOTSTRAP_UIDS` | UIDs for initial admin access |

> ⚠️ **Never commit `.env` files.** Use the provided `.env.example` files as templates.

---

## 📸 Screenshots

<!-- Add your screenshots here -->

| Home Screen | Mood Tracking | AI Chat |
|:-----------:|:-------------:|:-------:|
| _Coming soon_ | _Coming soon_ | _Coming soon_ |

| Therapist Discovery | Booking | Admin Dashboard |
|:-------------------:|:-------:|:---------------:|
| _Coming soon_ | _Coming soon_ | _Coming soon_ |

---

## 📚 Documentation

- [Release Candidate Checklist](docs/release/release_candidate_checklist.md)
- [UAT Matrix](docs/release/uat_matrix.md)
- [Incident Playbooks](docs/release/incident_playbooks.md)
- [Launch Cutover Plan](docs/release/launch_cutover_plan.md)
- [Production Identity & Signing](docs/release/production_identity_and_signing.md)

---

## 👥 Contributors

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/EshaFarrukh">
        <img src="https://github.com/EshaFarrukh.png" width="80" style="border-radius:50%" alt="Esha Farrukh"/>
        <br />
        <sub><b>Esha Farrukh</b></sub>
      </a>
    </td>
  </tr>
</table>

---

## 📄 License

This project is developed as a Final Year Project (FYP). All rights reserved.

---

<p align="center">
  Made with ❤️ for mental wellness
</p>
