# ElectronScout

A mobile scouting app for [FIRST Robotics Competition (FRC)](https://www.firstinspires.org/robotics/frc) teams. Scouts watch matches at a competition, tap in what each robot does, and the app turns that into team stats, picklists, and (for fun) a virtual betting game.

It is **offline-first**: competition venues often have bad Wi-Fi, so everything is saved on the phone first and uploaded whenever a connection is available.

---

## What the app does

| Feature | What it means |
|---|---|
| **Match scouting** | During a match, a scout follows one robot and records actions (pieces scored, climbs, etc.) with counters, toggles, and timers. After the match they fill in a short survey (driving, defense, notes). |
| **Offline storage + sync** | Each submission is saved to a database on the phone. When the phone is online, unsent data uploads to the team's cloud database in the background. |
| **QR transfer** | If a phone can't get online at all, it can show its data as QR codes, and another phone scans them to import it. |
| **Analytics** | Per-team averages, consistency, and score breakdowns, combining your own scouting data with public data from The Blue Alliance and Statbotics. |
| **Picklists** | Rank teams for alliance selection. |
| **Scouter schedules** | Admins assign scouts to matches/robots so coverage is even. |
| **Betting (e-bucks)** | Scouts bet virtual currency on match outcomes, with odds computed from team stats. Keeps people engaged during long events. No real money. |
| **Teams & roles** | Each FRC team registers and gets a **team code** that scouts use to log in. An **admin code** unlocks admin screens (schedules, deleting bad data, etc.). Each team only sees its own data. |

---

## How it works (big picture)

```
 ┌──────────────── Phone (React Native app) ────────────────┐
 │                                                           │
 │  Scout taps buttons ──► SQLite (on-device DB)             │
 │                           │  rows marked synced = 0       │
 │                           ▼                               │
 │                  Sync service (when online) ──────────────┼──► Supabase Edge Functions
 │                                                           │         │
 │  Screens ◄── React Query cache ◄──────────────────────────┼──── Supabase Postgres (cloud DB)
 │     ▲                                                     │
 │     └──── The Blue Alliance / Statbotics APIs (schedules, │
 │           team info, EPA ratings)                         │
 └───────────────────────────────────────────────────────────┘
                   crashes/errors ──► Sentry
```

1. **Write locally first.** Saving a match writes to SQLite on the phone (`services/database.ts`). This works with no internet.
2. **Sync in the background.** `services/supabase.sync.ts` finds rows not yet uploaded, reshapes them (`services/syncTransformer.ts`), and sends them in batches to a Supabase Edge Function, which writes them to Postgres.
3. **Read from the cloud.** Stats, bets, schedules, and picklists are fetched from Supabase and external APIs and cached on the phone with React Query, so screens still show recent data offline.
4. **Game rules live in one file.** Every FRC season has a new game. `config/gameConfig.ts` describes the current game's phases, what can be scored, and point values. The scouting screen, scoring, and analytics are all generated from it.

---

## Tech stack (and what each piece is)

If you're new to mobile development, here's what every piece does and where to learn it.

### App

| Tool | What it is | Why we use it | Docs |
|---|---|---|---|
| **React Native** | A framework for building iOS and Android apps with JavaScript/TypeScript and React components. | One codebase for both platforms. | [reactnative.dev](https://reactnative.dev/docs/getting-started) |
| **Expo** | A toolkit on top of React Native that handles native setup, builds, and device APIs (camera, SQLite, etc.) so you rarely touch Xcode/Android Studio. | Much simpler setup; lets you run the app on your phone with the **Expo Go** app. | [docs.expo.dev](https://docs.expo.dev/) |
| **Expo Router** | File-based navigation: each file in `app/` is a screen. | Adding a screen = adding a file. | [Expo Router docs](https://docs.expo.dev/router/introduction/) |
| **TypeScript** | JavaScript with types. | Catches mistakes before running. | [typescriptlang.org](https://www.typescriptlang.org/docs/) |
| **expo-sqlite** | A SQL database stored on the phone. | Offline storage of scouting data. | [expo-sqlite](https://docs.expo.dev/versions/latest/sdk/sqlite/) |
| **Zustand** | Small library for app-wide state (logged-in team, e-bucks balance…). | Simpler than Redux. | [zustand docs](https://zustand.docs.pmnd.rs/) |
| **TanStack React Query** | Fetches and caches server data, refetches when stale. | Handles loading/error/cache logic for every API call. | [tanstack.com/query](https://tanstack.com/query/latest/docs/framework/react/overview) |
| **Axios** | HTTP client. | Calls to The Blue Alliance and Statbotics. | [axios-http.com](https://axios-http.com/docs/intro) |

### Backend

| Tool | What it is | Why we use it | Docs |
|---|---|---|---|
| **Supabase** | A hosted backend: a Postgres database, an auto-generated REST API, and serverless functions. | No server to run ourselves. | [supabase.com/docs](https://supabase.com/docs) |
| **PostgreSQL** | The database Supabase runs. Tables: `matches`, `teams`, `bets`, `picklists`, etc. | Reliable relational DB. | [postgresql.org/docs](https://www.postgresql.org/docs/) |
| **Row Level Security (RLS)** | Postgres rules that decide which rows a user can see/change. | Keeps each FRC team's data private from other teams. | [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) |
| **Edge Functions** | Small TypeScript functions (running on Deno) hosted by Supabase. Code is in `supabase/functions/`. | Login, uploading matches, team/picklist operations: anything that needs the privileged service key or extra validation. | [Edge Functions](https://supabase.com/docs/guides/functions) |
| **Supabase CLI** | Command-line tool to run Supabase locally and deploy functions. | Local dev + deploys. | [CLI docs](https://supabase.com/docs/guides/local-development/cli/getting-started) |

### External data

| Service | What it gives us | Docs |
|---|---|---|
| **The Blue Alliance (TBA)** | Official FRC events, match schedules, results, team names. Needs a free API key. | [TBA API](https://www.thebluealliance.com/apidocs) |
| **Statbotics** | EPA, a statistical rating of each robot's expected contribution. No key needed. | [Statbotics API](https://www.statbotics.io/docs/rest) |

### Builds, updates & monitoring

| Tool | What it is | Docs |
|---|---|---|
| **EAS Build** | Expo's cloud service that builds the real `.ipa` / `.apk` files for the App Store / Play Store. | [EAS Build](https://docs.expo.dev/build/introduction/) |
| **EAS Update (OTA)** | Pushes JavaScript-only changes straight to installed apps without an app store review. | [EAS Update](https://docs.expo.dev/eas-update/introduction/) |
| **Sentry** | Crash and error reporting. When the app (or an Edge Function) crashes, Sentry records the stack trace, device, and what the user did. | [Sentry React Native](https://docs.sentry.io/platforms/react-native/) |

---

## Project structure

```
app/                  Screens (Expo Router — file path = route)
  (tabs)/             Main tabs: scouting (index), analytics, picklists, betting, admin
  (admin)/            Admin-only screens
  _layout.tsx         Root layout: providers, Sentry init, auth gate
components/           Reusable UI (counters, survey modal, betting/admin widgets)
config/
  gameConfig.ts       ⭐ This season's game definition — edit yearly
  queryClient.ts      React Query setup
  queryKeys.ts        Cache keys
services/             Business logic (database, sync, betting odds, stats, picklists, QR)
stores/               Zustand global state
hooks/                React Query hooks used by screens
api/                  TBA and Statbotics clients + types
lib/                  Supabase client, Edge Function callers, auth token storage
migrations/           SQL files that build the database schema, numbered in order
supabase/functions/   Edge Function source code
```

`@/` is an import shortcut for the project root, e.g. `import { db } from '@/services/database'`.

---

## Getting started

### 1. Prerequisites

- [Node.js](https://nodejs.org/) 20+ and npm
- The **Expo Go** app on your phone ([iOS](https://apps.apple.com/app/expo-go/id982107779) / [Android](https://play.google.com/store/apps/details?id=host.exp.exponent)), or an iOS Simulator / Android Emulator
- A free [Supabase](https://supabase.com/) account (for your own backend)
- A free [TBA API key](https://www.thebluealliance.com/account)

### 2. Install

```bash
git clone https://github.com/lexnaadi/ElectronScout.git
cd ElectronScout
npm install
```

### 3. Environment variables

Create a `.env` file in the project root (it's git-ignored, so never commit it):

```bash
EXPO_PUBLIC_SUPABASE_URL=https://<your-project>.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=<your anon/publishable key>
EXPO_PUBLIC_TBA_API_KEY=<your TBA key>
SENTRY_AUTH_TOKEN=<optional, only needed for production builds>
```

> ⚠️ Anything prefixed `EXPO_PUBLIC_` can be compiled into the app and is readable by anyone who downloads it. **Never** put the Supabase service role key or other secrets under an `EXPO_PUBLIC_` name. Secrets belong only in Edge Functions (see below).

### 4. Run

```bash
npx expo start          # scan the QR code with Expo Go
npx expo start --ios    # or open iOS simulator
npx expo start --android
```

There are no lint or test commands configured yet.

---

## Forking for your own team

The app expects **its own** Supabase backend. To run your own copy:

1. **Create a Supabase project** and copy its URL and anon key into `.env`.
2. **Build the database.** Run the SQL files in `migrations/` in numeric order (Supabase dashboard → SQL Editor). Some numbers are skipped or repeated; just go in filename order. If something fails, open an issue. The files may not perfectly match the live schema.
3. **Deploy the Edge Functions:**
   ```bash
   npx supabase login
   npx supabase link --project-ref <your-project-ref>
   npx supabase secrets set JWT_SECRET=<Project Settings → API → JWT secret>
   npx supabase functions deploy
   ```
   `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided to functions automatically.
4. **Replace our project identifiers** so builds and crash reports go to *your* accounts:
   - `app.config.js`: `owner`, `extra.eas.projectId`, `ios.bundleIdentifier` / Android `package`
   - `app.json`: Sentry `organization` and `project`
   - Sentry DSN in `app/_layout.tsx` and `supabase/functions/_shared/sentry.ts` (or remove Sentry entirely)
5. **Update the game** in `config/gameConfig.ts` (see below).
6. **Build for devices** with `eas build --platform ios|android` (requires a free [Expo account](https://expo.dev/)).

### Updating for a new FRC season

Edit only `config/gameConfig.ts`:

- Define a new `GameConfig` with the season's `phases` (auto, teleop, endgame) and their `metrics`.
- Metric types: `counter`, `boolean`, `select` (with `pointsMap`), `timer`, `rapidCounter` (hold-to-count for fast scoring).
- Set point values so `calculated_points` matches real scoring.
- Edit the post-match `survey` questions.
- Point `ACTIVE_GAME_CONFIG` at the new config.

The previous season's config is left commented out in the file as an example.

### Adding a database table

Copy `migrations/_template_new_table.sql`. Since Oct 30, 2026, Supabase no longer auto-grants API access to new tables, so every `CREATE TABLE` must be followed by explicit `GRANT`s, plus RLS policies, or the API returns `permission denied (42501)`.

---

## Contributing

**Issues**: please include:
- What you did, what you expected, what happened
- Device + OS version and app version (Settings screen)
- Screenshots or screen recordings if it's a UI problem

**Pull requests:**
1. Fork, then create a branch from `main`.
2. Keep PRs focused on one change.
3. Test on a real device or simulator, ideally both iOS and Android, and try it **offline** (airplane mode) if you touched data or sync code.
4. If you change the database, add a new numbered file in `migrations/`. Don't edit old ones.
5. If you change an Edge Function, say so in the PR. It must be redeployed separately from the app.
6. Describe *why* in the PR description, not just what.

**Good to know:**
- Production builds strip `console.log` / `info` / `debug` (`babel.config.js`); use `console.warn` / `console.error` for things that must show up in production.
- `expo-sqlite` doesn't run on web, so the web build mocks it out (`metro.config.js`). Web is for quick UI checks only.
- JS-only changes ship via OTA update; changes to native dependencies or `app.config.js` need a new EAS build.

---

## License

[MIT](LICENSE): fork it, change it, use it for your team.
