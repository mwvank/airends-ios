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

### Temporary stand-ins

These are deliberately simple until the backend exists, and are swapped out in later milestones:

- **Speech** uses Apple's established speech recogniser (on device where supported). It can move to the newer SpeechAnalyzer API later.
- **Place search** uses Apple's MapKit search. It will move to Google Places through the backend.
- **Travel times** are estimated from straight-line distance. They will come from the Google Routes API with live traffic.
- **Opening hours** aren't fetched yet. They will come from Google Places.
- **Ads and Pro** are placeholders. AdMob and StoreKit 2 come in milestone 6.

## Security

No API keys or secrets are ever committed or shipped in the app. Paid APIs (Google Maps Platform, busyness data, language model) are called only from the backend. See the "Security and scalability" section of the product plan.
