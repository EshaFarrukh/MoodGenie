# MoodGenie Production Identity And Signing

## Android
- The repo is standardized on the production application ID `com.moodgenie.app`.
- Generate or import the real Play upload keystore.
- Copy `android/key.properties.example` to `android/key.properties` and fill the real values.
- Re-register or update the Android Firebase app for `com.moodgenie.app`, then replace `android/app/google-services.json` with the real downloaded file.
- Release builds must not fall back to debug signing. The preflight now checks for a real keystore path and placeholder-free values.

## iOS
- The repo is standardized on the production bundle identifier `com.moodgenie.app`.
- Copy `ios/Flutter/Signing.xcconfig.example` to `ios/Flutter/Signing.xcconfig` and set the real Apple `DEVELOPMENT_TEAM`.
- Re-register or update the iOS Firebase app for `com.moodgenie.app`, then replace `ios/Runner/GoogleService-Info.plist` with the real downloaded file.
- Revalidate the Google Sign-In URL scheme after the new iOS Firebase plist is in place.

## Privacy and store metadata
- Complete `ios/Runner/PrivacyInfo.xcprivacy` with the final required-reason API declarations if Apple requires them for the shipped dependency set.
- Confirm Play Data Safety and App Store privacy answers against the current export, delete, AI chat, therapist chat, and calling flows.
- Replace placeholder branding values like `Moodgenie` casing where store metadata requires final polish.

## Verification
- Run `./scripts/production_preflight.sh com.moodgenie.app`.
- Run `./scripts/release_smoke.sh`.
- Upload the signed Android artifact to Play internal testing.
- Build an iOS archive with final signing and validate it in Xcode/App Store Connect.
