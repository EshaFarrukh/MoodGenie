# MoodGenie 🧞‍♂️✨

Your AI-powered mental wellness companion. EshaFarrukh/MoodGenie is a Flutter application designed to help users track their moods, gain insights through analytics, chat with a supportive AI, and connect with professional therapists.

## Features

🌟 **Daily Mood Tracking**
Log your emotional state in under 10 seconds. Select from a variety of moods, set the intensity, and add optional journal notes.

📊 **Smart Analytics**
Visualize your emotional journey with interactive charts. Track your 7-day trends, maintain a daily logging streak, and understand your mood patterns over time.

💬 **AI Companion Chat**
Need someone to talk to? The built-in AI chat provides a safe space to express your feelings and receive gentle, supportive wellness guidance.

🧑‍⚕️ **Therapist Connect**
Browse a curated list of licensed therapists, view their specialties (Anxiety, PTSD, Family Therapy, etc.), and book appointments directly through the app.

✨ **Premium Design**
A beautifully crafted user interface featuring glassmorphism, smooth animations, and a calming purple color palette tailored for mental wellness.

## Tech Stack

*   **Frontend:** Flutter & Dart
*   **Backend:** Firebase (Authentication, Cloud Firestore)
*   **State Management:** Provider
*   **Key Packages:** `fl_chart`, `shared_preferences`, `google_fonts`

## Getting Started

### Prerequisites

*   Flutter SDK (v3.10.0 or higher)
*   Dart SDK
*   An active Firebase project configured for iOS/Android

### Installation

1.  **Clone the repository**
    ```bash
    git clone https://github.com/EshaFarrukh/MoodGenie.git
    cd MoodGenie
    ```

2.  **Install dependencies**
    ```bash
    flutter pub get
    ```

3.  **Run the app**
    ```bash
    flutter run
    ```

## Project Structure

```text
lib/
├── screens/
│   ├── auth/         # Login & Signup flows
│   ├── chat/         # AI Companion interface
│   ├── home/         # Dashboard, Navigation, and Profile
│   ├── mood/         # Tracking, History, and Analytics
│   ├── splash/       # App initialization
│   └── therapist/    # Directory and Booking
├── src/
│   ├── auth/         # Authentication services & models
│   ├── services/     # Core application services (MoodRepository)
│   ├── theme/        # Design system (AppColors, AppRadius)
│   └── therapist/    # Clean Architecture domain layer for therapists
└── main.dart         # Entry point & routing
```

## Privacy & Security

MoodGenie respects your privacy. All mood logs, journal entries, and chat conversations are securely stored in Firebase under your personal account and are never shared with third parties.

---

*Made with 💜 for mental wellness.*
