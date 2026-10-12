# Airends (working title)

A smart errand planner for iPhone. Tell it what you need to do today and it works out when to leave and the best order to go in, then hands the route to Google Maps or Apple Maps.

The full product plan is in [docs/product-plan.md](docs/product-plan.md).

## Getting started

You need a Mac with **Xcode 26** and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen            # generates ErrandPlanner.xcodeproj from project.yml
open ErrandPlanner.xcodeproj
```

Pick an iPhone simulator and press Run. To run on your own iPhone, set `DEVELOPMENT_TEAM` in `Config/Shared.xcconfig`.

Run the core logic tests:

```sh
cd Packages/ErrandKit && swift test
```

## Project layout

| Path | What's there |
|---|---|
| `App/` | The SwiftUI app: screens, SwiftData models and services. |
| `Packages/ErrandKit/` | Platform-independent logic with tests: plan timing and stop ordering, entitlements (free vs Pro), and Google Maps / Apple Maps links. |
| `Config/Shared.xcconfig` | App display name and bundle ID, so renaming is a one-line change. |
| `backend/` | Firebase Cloud Function that calls Google Maps Platform for the app. Holds the only copy of the API key. |
| `project.yml` | XcodeGen spec. The `.xcodeproj` is generated and not committed. |
| `.github/workflows/ci.yml` | Runs the tests and builds the app on every push and pull request. |

## Naming

"Airends" is a working title. Code and modules use the neutral name **ErrandPlanner**; the name users see comes from `APP_DISPLAY_NAME` in `Config/Shared.xcconfig`.

## What's built so far (milestone 1: foundation)

- Today screen with the day's errands as a timed route: leave-by time, drive time and time at each stop.
- Add errands by typing and searching for places, with frequently used places saved automatically.
- Drag and drop to reorder stops (long-press a stop), with instant warnings if the new order makes you late for a fixed-time stop or reach a place after it closes.
- Lock a stop in place and tap **Optimise** to re-order the rest.
- **Start route** asks Google Maps (recommended) or Apple Maps, with "Don't ask again"; changeable in Settings.
- Entitlements layer for free vs Pro, ready for remote config, with an ad placeholder for free users.

## Milestone 2: Siri and voice

- **Plan my day by voice:** tap **Plan my day**, say your errands, and review them as editable cards before they're added and the route is optimised.
- **Siri:** "Hey Siri, plan my day in Airends" or "Hey Siri, add an errand in Airends". Siri asks what you need to do, then the app opens with the errands ready to review. These phrases also appear in Shortcuts, Spotlight and the Action Button settings.
- **Understanding:** Apple's on-device language model (Foundation Models) turns speech into errands. iPhones without Apple Intelligence use a built-in rule-based parser instead (`HeuristicErrandParser`).
- **Your places:** "the store" or "CVS" is matched to places you already use. Once "the store" is resolved, it's remembered as a nickname. Nicknames can be edited in **Settings → My places**.
- **Typing still works:** everything is also available without the microphone via **+**.

Siri note: Apple only allows fixed phrases (plus the app name) to launch a shortcut directly, so "Hey Siri, add pick up dry cleaning to Airends" in one breath isn't possible. Siri asks a quick follow-up question instead.

## Google proof of concept (milestone 3)

When `BACKEND_HOST` is set in `Config/Shared.xcconfig`, the app uses Google through the backend:

- **Place search** comes from Google Places, so every stop carries a Google place ID.
- **Drive times** are traffic-aware, from the Google Routes API, fetched once for all of today's places (up to 9 stops plus your location). The list footer says whether times are live or estimated.
- **Opening hours** come from Google Places for today, so the plan waits for a store to open and warns if it closes first.

With `BACKEND_HOST` empty, or if the backend can't be reached, the app falls back to MapKit search and estimated times.

### Deploying the backend (from a Mac)

One-time setup:

1. Install Node 22 from nodejs.org, then `npm install -g firebase-tools` and `firebase login`.
2. In Google Cloud (same project as Firebase), create an API key restricted to **Routes API** and **Places API (New)**.
3. From `backend/`: `firebase use --add` and pick the Firebase project.
4. `firebase functions:secrets:set MAPS_API_KEY` and paste the key when asked. It is stored in Google Secret Manager, never in the repo or the app.

Each deploy:

```sh
cd backend
firebase deploy --only functions
```

The deploy prints the function URL. Put it in `Config/Shared.xcconfig` without `https://`, for example `BACKEND_HOST = us-central1-airends.cloudfunctions.net/api`, then rebuild the app.

Backend tests: `cd backend/functions && npm install && npm test`.

### Temporary stand-ins

- **Speech** uses Apple's established speech recogniser (on device where supported). It can move to the newer SpeechAnalyzer API later.
- **App Check** isn't enforced yet, so anyone with the URL could call the backend (rate limited to 60 requests a minute per address). Turn on `ENFORCE_APP_CHECK` once the app ships with App Attest.
- **Ads and Pro** are placeholders. AdMob and StoreKit 2 come in milestone 6.

## Security

No API keys or secrets are ever committed or shipped in the app. Paid APIs (Google Maps Platform, busyness data, language model) are called only from the backend. See the "Security and scalability" section of the product plan.
