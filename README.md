# MarginPilot

A Next.js App Router, TypeScript, Tailwind CSS, and Framer Motion pricing planner.
All computations, scenario storage, CSV generation, and demo tier state run locally.
No runtime API, payment processor, remote font, analytics, or database is required.

## Development

Use Node.js 20.9 or newer. Run `npm install`, then `npm run dev`.
Run `npm test`, `npm run typecheck`, and `npm run build` to verify changes.
The build produces `out/`; deploy that directory to a static host.
For local production preview use `npx serve out` (the Next.js server is not used for a static export).

## Pricing model

Quote = (labor + direct expenses + allocated overhead) × (1 + contingency/100) / (1 − margin/100).
Free ignores contingency and uses 30 productive weekly hours and one person.
Plus unlocks contingency, scope sensitivity, comparison, and five saved scenarios.
Pro unlocks capacity controls, twenty saved scenarios, CSV exports, and print reports.
Scenario inputs remain saved on downgrade; access is limited to the current tier quota.
USD is the display currency. Annual figures assume 48 fully utilized working weeks and identical projects; they exclude taxes and unmodeled costs.

## Local data and simulated monetization

Browser localStorage persists tier, theme, inputs, project name, and scenarios. Data does not sync across devices.
Clearing browser storage deletes it. No payment is collected; prices are illustrative.
Client-side gates are editable by users and are not secure paid entitlements.
Commercial billing and enforceable paid access require a separate trusted billing/licensing design.
The default static output can be distributed as a paid digital product using a separate sales channel.

## Verification

GitHub Actions runs the calculation tests, lint, TypeScript checks, and static production build on pushes to main and pull requests. A dependency lockfile was not generated because the creation environment could not reach the package registry.

## Pages and navigation

The landing page contains the product introduction and links to the app and plans.
Each tool has its own route: `/quote`, `/scope`, `/capacity`, `/scenarios`, and `/reports`.
Plan selection lives at `/pricing`. Header, footer, tool navigation, and a mobile menu link between pages.
The root project provider keeps inputs, project name, scenarios, and demo tier consistent during navigation and reloads.
Existing browser input and scenario storage keys are preserved.

## Browser verification

After `npm run build`, run `npx playwright install chromium` and `npm run test:browser`.
The tests use the actual static export on desktop and mobile to verify navigation, persisted projects, scenario loading, tier gates, CSV downloads, and print rendering.
