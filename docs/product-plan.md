# Errandeer: Product Plan (v1)

_Draft, updated 12 Oct 2026._

## What it is

Errandeer is a smart errand planner for busy people on the go. You tell it, out loud, what you need to do today. It works out **the best time and order** to do everything, taking into account traffic, how busy each place is likely to be, opening hours, how long each errand takes, and the fixed commitments in your day. It learns your routines and favourite places as you use it, so planning gets faster and smarter over time.

**Platform:** Apple only. iPhone first, with an Apple Watch companion and widgets close behind.
**Launch region:** United States.

## Who it's for

- Working parents juggling school runs, groceries, pharmacy and dry cleaning.
- Professionals squeezing errands into lunch breaks and commutes.
- Anyone with a weekly routine who wants it handled with less thinking.

## How it should feel: an example

You say:

> "Today I need to go grocery shopping, stop at CVS to pick up my medication, and pick my kids up from school."

Errandeer replies with a plan:

> **Leave at 12:40.** CVS (pickup, ~10 min, quiet right now) → Kroger on Main St (~35 min, less busy before 2) → home to drop groceries → **leave at 2:45** for school pickup at **3:00**.
> _Heading out after 4 would add about 20 minutes of traffic and the store gets busy._

Behind that answer, Errandeer:

- Understood three errands and recognised "pick up my kids" as a **fixed appointment** (3:00) that everything else works around.
- Resolved "the store" and "CVS" to **the specific places you normally use**.
- Checked **traffic** for different departure times, **busyness forecasts**, **opening hours**, and **how long each errand usually takes you**.
- Ordered stops sensibly (groceries last and close to home so cold food isn't in the car for long).

The plan then **adapts during the day**. If you're running late, it reshuffles and tells you what to drop or move to protect the 3:00 pickup.

## v1 core features

1. **Talk to plan, with Siri.** Say "Hey Siri, plan my day in Errandeer" (or tap the mic, the Action Button or a Lock Screen control) and dictate your errands in plain language. Errandeer turns them into errands with places, durations and constraints, and asks a quick follow-up only when it really needs one ("Which school?"). Siri can also add a single errand on the fly: "Hey Siri, add pick up dry cleaning to Errandeer".
2. **Add without the microphone.** Everything voice can do also works by hand:
   - **Type** an errand in a text field (the same smart understanding applies, so "CVS pick up meds" works).
   - **Search for a place** by name, address or category ("pharmacy near me") with a map and nearby results, then add it as a stop.
   - **Pick from My places** (saved and frequently used places) with one tap.
   - Set details by hand: time window, fixed time, expected duration, notes or checklist.
3. **Smart day plan.** Recommends *when to leave* and *what order to go in*, balancing:
   - **Traffic:** travel time predicted for each possible departure time.
   - **Busyness:** how crowded each place is forecast to be at that hour.
   - **Opening and closing times:** never routes you to a closed store; warns when a window is tight.
   - **Errand duration:** how long each stop takes, starting from sensible defaults and learning your real times.
   - **Fixed commitments:** things like school pickup are locked in and everything else fits around them.
4. **Reorder by hand (drag and drop).** The suggested order is a starting point. Press and drag any stop in the Today list to move it. Errandeer instantly recalculates leave-by times and travel times for the new order and flags any problems ("This order makes you 10 min late for the 3:00 pickup" or "Kroger closes before you'd arrive"). You can lock a stop in place, or tap "Re-optimise the rest" to let Errandeer re-plan around your changes.
5. **Start the route in Google Maps or Apple Maps.** When you confirm the plan, a dialog asks which app to navigate with:
   - **Google Maps (recommended)**: "Matches Errandeer' timing, since your plan was built with Google's traffic data." Opens the whole route with every stop in your chosen order.
   - **Apple Maps**: opens the route in Apple Maps.
   - A **"Don't ask again"** checkbox remembers the choice. It can be changed any time in Settings.
   If Google Maps isn't installed, the Google option opens it in the browser and offers to install the app.
6. **Live re-planning.** If you fall behind, or something new is added mid-day, the plan updates and nudges you ("Leave now to make the 3:00 pickup").
7. **Learns your routines.** Notices repeating commitments ("kids pickup, weekdays at 3:00") and offers to make them permanent so you never have to say them again. Learns your typical errand durations from your visits.
8. **Remembers your places.** Saves places you use often and their nicknames, so "the store" means *your* grocery store and "the pharmacy" means *your* CVS.
9. **Location nudges.** Reminds you when you're near a place where an open errand can be done.
10. **Sync.** iCloud sync across iPhone, iPad and Watch, with no account to create.

### Out of scope for v1 (later)

- Shared lists and plans with family or partners.
- Calendar-aware planning (fitting errands around meetings). A strong v1.1 candidate, since it fits the "fixed commitments" model.
- Store integrations (pickup orders, inventory).
- Full in-app turn-by-turn navigation.
- Android or web.

## Key screens

1. **Onboarding.** Value in three short screens, then location, microphone and notification permissions with clear reasons. Optionally set Home, Work and the kids' school.
2. **Today.** The home screen: "Plan my day" and "+ Add" buttons, the recommended plan as a timeline with **leave-by times**, a map strip of stops, and a short note on why ("less busy before 2"). Stops can be **dragged to reorder**, locked, or swiped to complete. A **"Start route"** button opens the navigation choice dialog (Google Maps or Apple Maps).
3. **Add errand.** Text field with smart understanding, a mic button, place search with map and nearby results, and quick picks from My places.
4. **Talk / Review.** Live transcript while you speak (or the result of a Siri request), then the errands it understood as editable cards before the plan is built.
5. **Errand detail.** Place, hours, busyness forecast, expected duration, notes or checklist (e.g. grocery list), and a "Navigate" button.
6. **My places.** Saved and learned places with nicknames ("the store" → Kroger, Main St).
7. **Routines.** Fixed commitments and recurring errands, learned or added by hand.
8. **Settings and Pro.** Nudge preferences, travel mode, default navigation app (Google Maps or Apple Maps), and the upgrade to remove ads.

Plus **widgets** (next stop and leave-by time) and a **Watch app** as fast follow-ons.

## Pricing

- **Free:** the full app, supported by ads.
- **Errandeer Pro:** **$3.99/month**, removes all ads.

### Built to change

The pricing model is expected to evolve, so the app is set up to change it without a rewrite:

- **Entitlements layer.** All features check "is this unlocked?" against one place in the code rather than checking "is Pro?" directly. Moving a feature between Free and Pro later is a config change.
- **Remote config.** Ad frequency, which features are Pro-only, paywall wording and trial offers are controlled remotely, so they can change without an App Store update.
- **StoreKit 2.** The subscription price is set in App Store Connect and can be changed there. Yearly plans, trials or a lifetime option can be added later as new products.

### Ads: guardrails

- Ads appear only in calm moments (e.g. the bottom of the Today list), **never while you're driving or being nudged to leave**.
- Errands can include sensitive information (like picking up medication), so **ads are never targeted using errand content**. Ads use the standard App Tracking Transparency prompt, with non-personalised ads for anyone who declines.
- Suggested network: Google AdMob (good US fill rates and solid iOS support).

## Suggested tech approach

| Area | Choice | Why |
|---|---|---|
| UI | **SwiftUI** | One codebase across iPhone, iPad, Watch and widgets. |
| Minimum OS | **iOS 26** | Needed for Apple's on-device language model and the newest speech APIs. |
| Speech to text | **SpeechAnalyzer** (on device) | Fast, private, works offline. |
| Understanding requests | **Apple Foundation Models** (on device), with a **cloud language model fallback** | Turns "pick up my meds at CVS" into structured errands. On-device first for privacy and zero cost; the cloud fallback covers iPhones without Apple Intelligence. |
| Data | **SwiftData** with **CloudKit** sync | Local-first, offline, free sync, no login. |
| Travel times and stop order | **Google Routes API** (traffic-aware, with `optimizeWaypointOrder`) | Most accurate future drive times, built-in best stop order, and matches the Google Maps handoff. No time estimates to maintain ourselves. |
| Opening hours | **Google Places API (New)**, Place Details | Regular and holiday hours. Fetched only when needed and refreshed within Google's caching rules. |
| In-app map | **Google Maps SDK for iOS** | Google's terms require Google route data to be shown on a Google map. |
| Busyness forecasts | **Third-party foot-traffic API** (e.g. BestTime), with category-based fallback curves | Apple and Google don't offer "popular times" through their official APIs. |
| Planning engine | On-device scheduler | Tries each departure time and stop order and scores it on total time, waiting, crowding and hard deadlines. With fewer than ~10 stops a day this can be checked exhaustively in milliseconds. |
| Learning | On-device visit detection (Core Location visits) and usage history | Learns durations, favourite places and routines without sending your movements anywhere. |
| Backend | Serverless functions on **Google Cloud / Firebase** | All Google Maps, busyness and language model calls go through it, so API keys never ship in the app. Also serves remote config. Scales automatically. |
| Ads and subscription | **AdMob**, **StoreKit 2**, **App Tracking Transparency** | Standard and well supported. |
| Siri and voice entry points | **App Intents / App Shortcuts** | "Hey Siri, plan my day in Errandeer" and "add … to Errandeer" work without any setup by the user, plus the Action Button and Lock Screen controls. |
| Manual place search | **Google Places Autocomplete** (via the backend) | Search by name, address or category with live suggestions; returns Google place IDs used everywhere else. |
| Drag-to-reorder | SwiftUI list reordering, with the scheduler re-scoring the user's order | Users stay in control; the app explains the impact of each move. |
| Navigation handoff | **Google Maps URLs** (`google.com/maps/dir/?api=1` with `waypoints` and place IDs) and **Apple Maps** links | Opens the chosen app with the route. Free, with no API key needed. |
| Testing / CI | Swift Testing, Xcode Cloud or GitHub Actions on macOS | Standard Apple tooling. |

**What changed from the first draft:** maps data now comes from **Google**, and we need a **backend** to keep paid API keys off the phone, control costs and serve remote config.

## Who pays for what

- **Google Maps Platform, the busyness API and the cloud language model are billed to the app owner** (the business behind Errandeer), never to users. Users never see or need a Google API key.
- **Users pay the app owner** through the $3.99/month Pro subscription; free users are paid for by ads.
- So the business model has to cover those API costs. Rough estimate: about 9 cents per plan past Google's free monthly allowance, or $2–3 a month for someone who plans every day.
- **Cost controls built in from day one:** a monthly budget with alerts and hard quota caps in Google Cloud, per-user daily limits on re-planning (lower for free users), caching of results, and as few route checks per plan as possible.

## Security and scalability

Built to a professional standard from the start, so the app can grow to a large consumer audience on the App Store and pass due diligence by a potential acquirer.

**Security**
- **No secrets in the app.** All paid APIs are called from the backend; keys are restricted to that backend and stored in a secrets manager.
- **Only the real app can call the backend.** Firebase App Check with Apple App Attest blocks scripts and copies of the app.
- **Per-user rate limiting** on the backend to stop abuse and runaway bills.
- **Privacy by design.** Errands, places and location history stay on the device and in the user's own iCloud. The backend handles each request and keeps no personal data. Location is never sold or used for ad targeting.
- **Encryption** in transit (TLS) and at rest (iOS Data Protection, iCloud).
- **Sign in with Apple** if and when accounts are needed (e.g. for family sharing).
- Privacy policy, App Store privacy labels and a data-deletion option from launch.

**Scalability**
- Serverless backend scales automatically from zero to millions of requests with no servers to manage.
- Smart caching of places and routes cuts both cost and response time as usage grows.
- Monitoring and crash reporting (Firebase Crashlytics, Cloud Monitoring) with alerts.
- Google quotas can be raised on request as the user base grows.

**Ready to sell**
- Clean, documented, tested code with CI, kept in a private repository you own.
- All accounts (Apple Developer, Google Cloud, AdMob, domain) registered to a business entity you control, so they can be transferred in a sale.
- Product analytics (retention, plans per user, conversion to Pro) that buyers will ask for.
- Building on Google's own maps platform is a plus if Google is a target buyer.

## Risks and things to verify early

- **"Hey errands" as a wake word isn't possible.** iOS doesn't let third-party apps listen for their own wake word. The closest options are "Hey Siri, plan my day in Errandeer", the Action Button, a Lock Screen control, or the in-app mic. All of these can start straight into listening mode.
- **Busyness data costs money and coverage varies.** A third-party foot-traffic API charges per lookup. We'll cache forecasts per place (they change weekly, not hourly) and fall back to typical patterns by category when data is missing.
- **Google API costs.** Paid per request past the free monthly allowance (see "Who pays for what"). Budgets, caps and caching keep this predictable.
- **Running costs vs ad revenue.** Busyness lookups and cloud language model calls cost money for every free user. Caching, the on-device model and per-user daily limits keep this in check.
- **Google Maps stop limit.** A route sent to Google Maps can hold a start, an end and **up to 9 stops in between**. That covers a normal day; for longer plans Errandeer sends the first 10 stops and offers "Send the rest" when you're nearly done.
- **Google Maps picks the roads.** Google Maps keeps your stops and their order but chooses its own roads between them, using live traffic. That's what we want, but its timings may differ slightly from Errandeer' estimates.
- **Battery.** Learning from visits and nudges must use iOS's low-power location features, not constant GPS.

## Milestones

1. **Foundation:** Xcode project, data model, entitlements layer, typed errand entry, place search, Today list with drag-to-reorder.
2. **Talk to plan:** Siri (App Intents), speech capture, on-device understanding, review cards, saved places and nicknames.
3. **Smart planning and handoff:** traffic-aware ETAs, opening hours, fixed commitments, scheduling engine, leave-by times, impact warnings when reordering, navigation choice dialog (Google Maps or Apple Maps).
4. **Busyness and backend:** serverless backend, busyness forecasts, remote config, cloud language model fallback.
5. **Learning and live re-planning:** learned durations, routines and places; mid-day re-planning; location nudges.
6. **Monetisation and polish:** AdMob with guardrails, Pro subscription, onboarding, Action Button and Lock Screen controls, TestFlight beta (US).
7. **Fast follow:** widgets, Watch app, calendar-aware planning, shared plans.

## Decisions log

- **12 Oct 2026:** US launch first. Family sharing later. "Airends" was a working title; the code uses a neutral internal name so a rename is cheap.
- **12 Oct 2026:** Pricing changed to **free with ads plus Pro at $3.99/month (ad-free)**, built so the model is easy to change later. This replaces the earlier freemium-with-limits draft.
- **12 Oct 2026:** The core of the app is a **voice-driven smart planner** that picks the best time and order based on traffic, busyness, hours, durations and fixed commitments, and learns routines and frequent places.

- **12 Oct 2026:** Siri dictation plus full manual entry (typing and place search) are both first-class. Stops can be reordered by drag and drop. Completed routes can be sent to **Google Maps** with all stops in order.
- **12 Oct 2026:** Planning data (travel times, stop order, opening hours, place search) comes from **Google**. Users choose Google Maps or Apple Maps when starting a route, with Google recommended and a "Don't ask again" option. Built to a professional security and scalability standard. Sold to **consumers on the App Store** (not licensed to businesses), with a possible acquisition as the long-term goal.

- **12 Oct 2026:** The app is named **Errandeer** (no App Store app with that name was found). "Apple Errands" was ruled out because Apple doesn't allow "Apple" in app names.

## Still open

- **Reserve the name.** Reserve "Errandeer" in App Store Connect and check the US trademark register and a domain.
- **Brand look.** Colours and icon style.

## What building it needs

- A Mac with Xcode to build and run the app (the code can be written here, but compiling and running iOS apps requires macOS).
- An iPhone that supports Apple Intelligence (iPhone 15 Pro or newer) to test the on-device language features.
- An Apple Developer account ($99/year) for TestFlight and the App Store.
- A registered business entity to own the accounts, plus a Google Cloud account with billing (Maps Platform and Firebase), AdMob, and a busyness data provider.
- A GitHub repository to hold the code.
