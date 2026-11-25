# ClipNear

A barber marketplace for web and Android. Customers discover nearby barbers by haircut and price and reserve appointments free. The commercial model is a provider subscription.

## Current milestone

Implemented: responsive Expo customer interface, haircut and budget filters, device location with area fallback, distance ordering, service details, slot selection, booking history and cancellation. A Node API supports an explicit in-memory demo and an authenticated Supabase mode. The initial migration adds PostGIS discovery, schedules, time off, price snapshots, RLS and overlapping appointment exclusion.

This is an early development build. Sample profiles and reviews are fictional and labelled as preview data. No provider receives a real notification in demo mode. It is not a production service or an Android store release.

Not implemented yet: self-service provider onboarding, portfolio uploads, provider dashboard, subscription checkout/webhooks, reminders, reviews submission, negotiated offers, home visits and a production administration interface. The SQL currently supports one public barber profile per provider record; multi-staff shop management is a subsequent migration. The API is modular Express with JavaScript ES modules; the client uses TypeScript and Expo Router. NestJS can be introduced when provider workflows justify the extra structure.

## Local development

Requires Node 22 or later and npm. From the repository root:

```sh
npm install
cp apps/api/.env.example apps/api/.env
cp apps/client/.env.example apps/client/.env
npm run dev:api
# A second terminal
npm run dev:web
```

PowerShell users can use `Copy-Item` instead of `cp`. Open the web URL Expo prints, normally http://localhost:8081. API health is http://localhost:4000/health.

Demo mode is for local development only. It uses one shared demo customer and resets bookings on restart. Do not expose it as a real multi-user service.

## Android

From `apps/client`, run `npx expo start` and open with a matching Expo Go version, or run `npm run android` with Android Studio configured. For a physical phone set `EXPO_PUBLIC_API_URL` to your computer's LAN IP on port 4000. Restart Expo after changing environment values. Location access requires permission; the preset areas work without it.

`eas.json` includes an APK preview profile. After configuring an Expo account and EAS project, run `npx eas-cli build --platform android --profile preview`. A signed APK has not been generated in this milestone.

## Supabase setup

1. Create a Supabase project and apply `supabase/migrations/202611250001_initial.sql` using the SQL editor or migration tooling. PostGIS and btree_gist must be available in the `extensions` schema.
2. Enable email/password authentication and configure confirmed-email redirect URLs for your deployment.
3. Set API `DATA_MODE=supabase`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` and exact web origin. Set the matching client public Supabase URL/key. Never put a service-role key in the client.
4. Create a provider Auth user and use `supabase/provider-example.sql` to insert its approved profile, services and hours from an administrator context. Replace the owner UUID. Approval and subscription dates are manually administered until billing is built; no payments are collected by this code.
5. Restart both processes. Create a customer account and confirm email before booking. Slots are generated for the next 60 days, in Africa/Harare time. This milestone supports USD only.

The API verifies customer tokens with Supabase `getUser`. Its database requests use that customer's JWT, never a service-role bypass. Public RPCs expose only discovery fields; direct provider tables are not granted to anonymous users. Critical booking RPCs check auth, availability and schedule under a barber row lock. A GiST exclusion constraint prevents overlapping active bookings. Unrelated provider integrations must respect the same lock when mutating schedules.

## Verification

```sh
npm test
npm run typecheck
npm run build:web
```

Tests cover combined search filters, duration overlap, competing booking writes, history and cancellation. `supabase/tests/access_and_booking.sql` gives a database verification checklist to run on a fresh staging project. Live Supabase and real Android device testing require configured services and are not implied by the local demo tests.

## Repository structure

```text
apps/client    Expo web and Android client
apps/api       Node API, demo domain and integration tests
supabase       Database migration, provider setup and verification checklist
docs           Architecture decisions and next milestones
```

## Deployment

Serve `apps/client/dist` as static web assets after exporting with a production HTTPS API URL. Deploy `apps/api` as a Node service with `npm start` from that workspace. Configure exact CORS origin, secret/environment management and HTTPS. Use Supabase mode, provision real approved providers, and complete billing, operations and live database checks before accepting actual customers. Never commit `.env` files.
