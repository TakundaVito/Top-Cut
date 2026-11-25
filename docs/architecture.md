# Architecture and next milestones

## Data flow

Web and Android share React Native screens. The client authenticates with Supabase Auth and sends a bearer token to the Node API for private actions. The API verifies the token and runs database requests with the user's own identity. Public search and availability are read-only SQL RPCs. Booking RPCs own scheduling and price decisions; the client never supplies a price.

Demo mode uses the same HTTP contracts with fictional Harare providers and an ephemeral store. Its shared demo identity is intentionally unsuitable for deployment.

## Decisions

- A single Node API and managed Postgres keep the first release simple. Express provides the initial HTTP boundary; move to NestJS when the domain grows rather than introducing unused modules.
- A single Expo application serves Android and web. Expo Router provides explore, account and appointment routes. Platform location code is loaded only when requested. Dedicated barber and booking deep links are a later milestone.
- Monetary values use PostgreSQL numeric plus explicit currency; price and duration are captured in a booking snapshot. USD and Africa/Harare are explicit pilot constraints.
- Database exclusion constraints protect appointments under concurrency. RPCs use restricted grants and fixed search paths. A barber row lock serialises booking availability checks. Future calendar mutation RPCs must acquire the same lock.
- No automated billing is simulated. Subscription eligibility is an administrator-managed date until a supported payment gateway is selected and verified.

## Next milestones

1. Run migrations against staging Supabase and automate customer isolation, concurrency and timezone SQL tests.
2. Add shop membership roles, provider onboarding approval and calendar editing with shared locking rules.
3. Add storage policies, portfolio uploads and moderation.
4. Select a Zimbabwe-compatible billing gateway; implement signed, idempotent webhooks, renewal and grace period rules.
5. Add durable notification jobs, reminders, verified completion and customer reviews.
6. Add device-level Android testing, release signing and production observability.

Pricing negotiation follows demonstrated provider response rates. Home visits require separate address privacy, travel scheduling and operating procedures.
