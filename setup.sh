#!/bin/bash
set -Eeuo pipefail
trap 'echo "Setup failed at line $LINENO; no success is being claimed." >&2' ERR
# Requires Node.js >=20.9, npm, git, and GitHub push access.
# Replaces the repository application, preserves Git history, and never force-pushes.
for tool in node npm npx git; do command -v "$tool" >/dev/null || { echo "Missing: $tool" >&2; exit 1; }; done
node -e 'const [a,b]=process.versions.node.split(".").map(Number); if(a<20||(a===20&&b<9)) process.exit(1)'

# 1. Clean and initialize target repository workspace
rm -rf -- monetized-app
git clone https://github.com/RudraRM/UltimateWebsite-3.git monetized-app
cd monetized-app
git var GIT_AUTHOR_IDENT >/dev/null
git var GIT_COMMITTER_IDENT >/dev/null
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf -- {} +

# 2. Force bootstrap a clean Next.js application structure
npx create-next-app@latest . --ts --tailwind --eslint --app --no-src-dir --use-npm --import-alias="@/*" --skip-install --yes --disable-git

# 3. Generate the complete routed application and shared local state
mkdir -p .github/workflows app app/capacity app/pricing app/quote app/reports app/scenarios app/scope components context lib tests tests/browser

cat <<'MARGINPILOT_SOURCE' > .github/workflows/ci.yml
name: Verify MarginPilot
on:
  push:
    branches: [main]
  pull_request:
permissions:
  contents: read
jobs:
  verify:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: npm install --no-audit --no-fund
      - run: npm test
      - run: npm run lint
      - run: npm run typecheck
      - run: npm run build
        env:
          NEXT_TELEMETRY_DISABLED: 1
      - run: npx playwright install --with-deps chromium
      - run: npm run test:browser
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > .gitignore
/node_modules
/.next/
/out/
/.engine-check/
*.tsbuildinfo
.env*
!.env.example
.DS_Store
npm-debug.log*

/playwright-report/
/test-results/
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > README.md
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

GitHub Actions runs the calculation tests, lint, TypeScript checks, and static production build on pushes to main. A dependency lockfile was not generated because the creation environment could not reach the package registry.

## Pages and navigation

The landing page contains the product introduction and links to the app and plans.
Each tool has its own route: `/quote`, `/scope`, `/capacity`, `/scenarios`, and `/reports`.
Plan selection lives at `/pricing`. Header, footer, tool navigation, and a mobile menu link between pages.
The root project provider keeps inputs, project name, scenarios, and demo tier consistent during navigation and reloads.
Existing browser input and scenario storage keys are preserved.

## Browser verification

After `npm run build`, run `npx playwright install chromium` and `npm run test:browser`.
The tests use the actual static export on desktop and mobile to verify navigation, persisted projects, scenario loading, tier gates, CSV downloads, and print rendering.
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > app/capacity/page.tsx
import type { Metadata } from "next";
import SaaSAppWorkspace from "@/components/SaaSAppWorkspace";
export const metadata: Metadata = { title: "Capacity Planning — MarginPilot", description: "Model team capacity, project duration, and annual profit with local calculations." };
export default function CapacityPage() { return <SaaSAppWorkspace view="capacity" />; }
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > app/globals.css
@import "tailwindcss";
@theme inline { --color-background: var(--bg); --color-foreground: var(--fg); --font-sans: Arial, Helvetica, sans-serif; --font-mono: "SFMono-Regular", Consolas, monospace; }
:root { color-scheme: dark; --bg:#0a0a0b; --fg:#eeeef0; --muted:#a2a2aa; --panel:#111113; --surface:#19191c; --line:#2b2b30; --accent:#b8ef92; --accent-ink:#1a2811; --danger:#ff9e9e; --chart-0:#555b61; --chart-1:#727980; --chart-2:#9299a0; --chart-3:#899f74; --chart-4:#b8ef92; }
:root[data-theme="light"] { color-scheme:light; --bg:#fafaf9; --fg:#18181b; --muted:#626269; --panel:#fff; --surface:#f0f0ef; --line:#d8d8da; --accent:#39651d; --accent-ink:#fff; --danger:#b42323; --chart-4:#39651d; }
* { box-sizing:border-box; } html { scroll-behavior:smooth; scroll-padding-top:96px; } body { margin:0; background:var(--bg); color:var(--fg); font-family:Arial,Helvetica,sans-serif; -webkit-font-smoothing:antialiased; padding-bottom:76px; } ::selection { background:var(--accent); color:var(--accent-ink); } a { color:inherit; text-decoration:none; } button,input,select { font:inherit; } button,a,input,select { -webkit-tap-highlight-color:transparent; } button { cursor:pointer; } button:disabled { cursor:not-allowed; opacity:.48; } :focus-visible { outline:2px solid var(--accent); outline-offset:4px; } h1,h2,h3,h4,p { margin-top:0; } h1,h2 { letter-spacing:-.065em; line-height:1.05; font-weight:600; } h1 { font-size:clamp(3.4rem,7.2vw,6.3rem); margin-bottom:24px; } h2 { font-size:clamp(2.3rem,4.6vw,3.9rem); margin-bottom:0; } h3 { font-size:1.2rem; letter-spacing:-.035em; font-weight:600; } h4 { font-size:.95rem; font-weight:600; } p { line-height:1.65; } .container { width:min(1120px,calc(100% - 48px)); margin-inline:auto; } .row { display:flex; align-items:center; gap:12px; } .wrap { flex-wrap:wrap; } .between { display:flex; align-items:center; justify-content:space-between; gap:16px; } .muted { color:var(--muted); } .accent { color:var(--accent); } .danger { color:var(--danger); } .small { font-size:.78rem; } .mono { font-family:"SFMono-Regular",Consolas,monospace; } .eyebrow { font-family:"SFMono-Regular",Consolas,monospace; font-size:.66rem; letter-spacing:.09em; color:var(--muted); margin-bottom:22px; display:flex; align-items:center; gap:9px; line-height:1.6; } .badge { display:inline-flex; align-items:center; border:1px solid var(--line); background:var(--surface); border-radius:5px; padding:5px 8px; font-family:Consolas,monospace; font-size:.63rem; white-space:nowrap; } .btn { display:inline-flex; align-items:center; justify-content:center; gap:9px; padding:11px 16px; min-height:42px; border:1px solid var(--line); border-radius:7px; background:var(--surface); color:var(--fg); font-weight:500; font-size:.83rem; line-height:1.25; } .btn:hover { border-color:var(--muted); } .btn.primary { background:var(--accent); color:var(--accent-ink); border-color:var(--accent); } .btn.small { font-size:.74rem; padding:9px 12px; } .btn.full { width:100%; } .icon-btn { width:40px; height:40px; padding:0; } .text-link { display:inline-flex; align-items:center; gap:9px; font-size:.83rem; } .text-link:hover { color:var(--accent); } .status-dot { width:6px; height:6px; border-radius:50%; background:var(--accent); flex-shrink:0; } .topbar { position:sticky; top:0; z-index:30; border-bottom:1px solid var(--line); background:var(--bg); } .nav { min-height:76px; display:flex; align-items:center; justify-content:space-between; gap:20px; } .brand { display:flex; align-items:center; gap:10px; font-size:1rem; font-weight:600; letter-spacing:-.035em; } .navlinks { display:flex; gap:26px; color:var(--muted); font-size:.8rem; } .navlinks a:hover { color:var(--fg); } .hero { padding-top:100px; display:grid; grid-template-columns:1.1fr 1fr; gap:48px; align-items:center; } .hero-copy { max-width:450px; font-size:1rem; color:var(--muted); } .hero-actions { margin:28px 0 18px; gap:24px; } .terminal { border:1px solid var(--line); border-radius:10px; background:var(--panel); overflow:hidden; box-shadow:0 20px 80px #00000012; } .terminal-bar { padding:13px 16px; border-bottom:1px solid var(--line); display:flex; align-items:center; justify-content:space-between; gap:8px; color:var(--muted); } .dots { gap:5px; } .dots i { width:7px; height:7px; border-radius:50%; background:var(--line); } .terminal-body { padding:26px; font-size:.75rem; } .terminal-body p { display:flex; gap:12px; align-items:center; margin-bottom:18px; } .terminal-body b { margin-left:auto; white-space:nowrap; font-weight:400; } .terminal-result { padding:25px 0; margin:24px 0; border-top:1px dashed var(--line); border-bottom:1px dashed var(--line); display:flex; flex-direction:column; gap:12px; } .terminal-result strong { font-family:Arial,sans-serif; font-size:3.1rem; font-weight:500; letter-spacing:-.07em; } .cursor { margin-left:auto; color:var(--accent); }    .section { padding-top:104px; } .section-heading { display:flex; justify-content:space-between; align-items:flex-end; gap:28px; margin-bottom:36px; } .section-heading>p { font-size:.84rem; margin:0; } .panel { border:1px solid var(--line); background:var(--panel); border-radius:10px; }          .pricing-grid { display:grid; grid-template-columns:repeat(3,1fr); gap:14px; margin-bottom:18px; } .pricing-card { padding:28px; } .pricing-card.selected { border-color:var(--accent); } .pricing-card h2 { font-size:1.2rem; letter-spacing:-.035em; margin:0; } .pricing-card>.small { margin:16px 0; } .price { font-size:3rem; font-weight:500; letter-spacing:-.06em; margin:26px 0; } .price span { letter-spacing:0; } .pricing-card ul { list-style:none; padding:0; margin:28px 0 0; display:flex; flex-direction:column; gap:15px; } .pricing-card li { display:flex; align-items:flex-start; gap:10px; font-size:.77rem; color:var(--muted); } .pricing-card li svg { flex-shrink:0; } .workspace { overflow:hidden; } .workspace-toolbar { padding:16px 24px; border-bottom:1px solid var(--line); background:var(--surface); } .workspace-grid { display:grid; grid-template-columns:340px minmax(0,1fr); border:0; padding:0; margin:0; min-width:0; } .input-panel { border-right:1px solid var(--line); padding:28px; min-width:0; } .input-panel h3 { margin:0; } .input-panel>.between { margin-bottom:22px; } .name-input,select { width:100%; padding:11px 12px; border:1px solid var(--line); border-radius:6px; background:var(--bg); color:var(--fg); font-size:.82rem; margin-top:8px; } .presets { margin:14px 0 28px; gap:7px; } .presets .btn { font-size:.68rem; min-height:34px; padding:8px 10px; } .field { margin-bottom:22px; } .field label { font-size:.77rem; } .input-shell { display:flex; align-items:center; border:1px solid var(--line); border-radius:6px; margin:9px 0 8px; padding-right:11px; background:var(--bg); } .input-shell:focus-within { border-color:var(--accent); } .input-shell input { width:100%; min-width:0; padding:11px; border:0; background:transparent; color:var(--fg); font-size:.87rem; outline:none; } .input-shell span { white-space:nowrap; } input[type="range"] { width:100%; height:3px; display:block; accent-color:var(--accent); cursor:pointer; } .locked-field { color:var(--muted); } .locked-field input { cursor:not-allowed; } .helper { margin-top:-14px; margin-bottom:24px; font-size:.68rem; } .two-col { display:grid; grid-template-columns:1fr 1fr; gap:12px; } .result-panel { padding:28px; min-width:0; }    .quote-block { padding:32px 0 26px; } .quote-block .eyebrow { margin-bottom:14px; } .quote-number { font-size:clamp(2.8rem,5vw,4.6rem); letter-spacing:-.07em; line-height:1.1; font-weight:500; overflow-wrap:anywhere; } .quote-block p:last-child { font-size:.78rem; margin:12px 0 0; } .metric-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:12px; } .mini-card { padding:18px; border:1px solid var(--line); border-radius:7px; background:var(--surface); } .mini-card p { margin-bottom:8px; } .mini-card strong { font-size:1.35rem; font-weight:500; letter-spacing:-.04em; overflow-wrap:anywhere; } .breakdown { margin-top:32px; } .ledger-row { padding:10px 0; border-bottom:1px solid var(--line); font-size:.79rem; } .stacked-bar { display:flex; height:7px; border-radius:5px; overflow:hidden; margin:20px 0 14px; } .upgrade { display:flex; align-items:center; gap:14px; padding:20px; border:1px dashed var(--line); border-radius:8px; background:var(--surface); margin:24px 0; } .upgrade>svg { flex-shrink:0; color:var(--accent); } .upgrade b { font-size:.8rem; } .upgrade p { margin:5px 0 0; font-size:.73rem; } .upgrade .btn { margin-left:auto; white-space:nowrap; font-size:.74rem; padding:10px; } .analysis { padding-top:28px; } .analysis h3 { font-size:1.5rem; } .risk-chart { display:flex; gap:10px; margin:30px 0; } .risk-column { flex:1; text-align:center; min-width:0; } .bar-track { height:100px; display:flex; align-items:flex-end; margin:9px 0; background:var(--surface); border-radius:4px; overflow:hidden; } .risk-bar { width:100%; background:var(--accent); border-radius:4px; } .risk-bar.negative { background:var(--danger); } table { width:100%; border-collapse:collapse; font-size:.76rem; } th,td { padding:12px 4px; text-align:left; border-bottom:1px solid var(--line); } th { color:var(--muted); font-weight:400; } th:not(:first-child),td:not(:first-child) { text-align:right; } .capacity-metrics { margin:24px 0; } .saved { margin-top:32px; border-top:1px solid var(--line); padding-top:24px; } .saved h4 { margin:0; } .saved>.small { margin-top:18px; } .scenario { display:flex; align-items:center; gap:8px; margin-top:10px; } .scenario-load { flex:1; min-width:0; display:flex; justify-content:space-between; text-align:left; font-size:.76rem; padding:12px; } .scenario-load span:first-child { overflow:hidden; text-overflow:ellipsis; white-space:nowrap; } .scenario-load span:last-child { flex-shrink:0; } .comparison { margin-top:22px; } .comparison p { margin:12px 0 0; } .export-row { margin-top:26px; gap:10px; } .export-row .btn { font-size:.73rem; } .notice { color:var(--muted); min-height:38px; margin:18px 0 0; } .storage-warning { padding:14px 24px; color:var(--danger); border-bottom:1px solid var(--line); font-size:.8rem; margin:0; } .print-report { display:none; } .footer { padding-block:70px 32px; } .footer-details { margin-top:28px; max-width:750px; } .footer-details p { font-size:.7rem; margin-bottom:10px; } .plan-dock { position:fixed; bottom:0; left:0; right:0; background:var(--bg); border-top:1px solid var(--line); z-index:40; padding:12px 0; } .skip-link { position:fixed; top:10px; left:10px; z-index:100; padding:12px; background:var(--accent); color:var(--accent-ink); transform:translateY(-150%); } .skip-link:focus { transform:translateY(0); }
@media (max-width:950px) { .hero { gap:28px; padding-top:64px; } .navlinks { gap:16px; } .navcta { display:none; } .terminal-body { padding:18px; font-size:.68rem; } .workspace-grid { grid-template-columns:300px minmax(0,1fr); } .input-panel,.result-panel { padding:22px; } .upgrade { flex-wrap:wrap; } .upgrade .btn { margin-left:32px; } .pricing-card { padding:22px; } .pricing-card .badge { font-size:.5rem; } }
@media (max-width:720px) { .container { width:calc(100% - 32px); } .nav { min-height:66px; gap:10px; } .navlinks { display:none; } .brand { font-size:.92rem; } .nav>.row { gap:7px; } .hero { grid-template-columns:1fr; padding-top:55px; gap:32px; } .hero-copy { max-width:100%; } .terminal-body { font-size:.75rem; padding:24px; }  .section { padding-top:72px; } .section-heading { align-items:flex-start; flex-direction:column; gap:20px; margin-bottom:26px; }    .pricing-grid { grid-template-columns:1fr; } .pricing-card { padding:26px; } .pricing-card .badge { font-size:.63rem; } .price { margin:22px 0; } .workspace-toolbar { padding:14px; gap:8px; } .workspace-toolbar .mono { font-size:.62rem; } .workspace-toolbar .btn { font-size:.65rem; padding:8px; } .workspace-grid { grid-template-columns:1fr; } .input-panel { border-right:0; border-bottom:1px solid var(--line); padding:24px; } .result-panel { padding:24px; } .quote-number { font-size:3.5rem; } .plan-dock .dock-label { display:none; } .plan-dock .row { gap:12px; } .footer { padding-top:48px; } .metric-grid { gap:10px; } .mini-card { padding:14px; } .mini-card strong { font-size:1.15rem; } .risk-chart { gap:7px; } .risk-column .small { font-size:.65rem; } }
@media (prefers-reduced-motion:reduce) { html { scroll-behavior:auto; } *,*::before,*::after { animation-duration:.01ms!important; transition-duration:.01ms!important; } }
@media print { :root { color-scheme:light; --bg:#fff; --fg:#111; --muted:#444; --line:#ddd; } body { background:#fff; color:#111; padding:0; } header,.hero,#pricing,.workspace,.workspace-section>.section-heading,footer,.plan-dock,.skip-link { display:none!important; } .workspace-section { padding:0; width:100%; opacity:1!important; transform:none!important; } .print-report { display:block; padding:24px; } .print-report h1 { font-size:2rem; } .print-report h2 { font-size:1.5rem; margin-bottom:20px; } .print-report p { font-size:.85rem; } }

/* Dedicated tool pages share the same responsive shell and local project. */
.page-title { font-size:clamp(2.5rem,5vw,4.2rem); margin:0; }
.page-description { max-width:610px; margin:18px 0 0; font-size:.9rem; }
.tool-navigation { display:flex; flex-wrap:wrap; gap:8px; margin:0 0 24px; }
.tool-link { position:relative; padding:13px 16px; border:1px solid var(--line); border-radius:7px; font-size:.8rem; color:var(--muted); }
.tool-link:hover,.tool-link.current { color:var(--fg); background:var(--surface); }
.tool-link.current { border-color:var(--accent); }
.tool-link-indicator { position:absolute; left:16px; right:16px; bottom:5px; height:2px; background:var(--accent); border-radius:2px; }
.workspace-single { border:0; padding:0; margin:0; min-width:0; }
.workspace-single .result-panel { max-width:850px; margin-inline:auto; padding:36px; }
.subheading { font-size:.95rem; font-weight:600; letter-spacing:-.02em; line-height:1.4; margin:0 0 20px; }
.analysis-title { font-size:1.5rem; line-height:1.2; letter-spacing:-.035em; margin-bottom:18px; }
.project-name { font-size:1.5rem; line-height:1.3; letter-spacing:-.035em; overflow-wrap:anywhere; }
.project-summary>.between { margin-bottom:22px; }
.project-summary .eyebrow { margin-bottom:8px; }
.saved-link { margin-top:16px; }
.saved>.between .subheading { margin:0; }
.empty-state { padding:28px 0 8px; font-size:.85rem; }
.report-facts { margin:28px 0; }
.report-facts dd { margin:0; }
.report-assumptions { margin:24px 0 0; }
.mobile-menu-toggle,.mobile-navigation { display:none; }
.hero { padding-bottom:40px; }
#main-content:focus { outline:none; }
@media (max-width:720px) {
  .mobile-menu-toggle { display:inline-flex; }
  .mobile-navigation { display:grid; grid-template-columns:1fr 1fr; gap:8px; padding-block:12px 18px; border-top:1px solid var(--line); }
  .mobile-navigation a { display:flex; align-items:center; justify-content:space-between; gap:8px; padding:12px; background:var(--surface); border-radius:6px; font-size:.8rem; }
  .mobile-navigation a[aria-current="page"] { color:var(--accent); }
  .nav>.row { gap:6px; }
  .nav .brand { font-size:.85rem; gap:7px; }
  .nav .icon-btn { width:34px; height:38px; min-height:38px; }
  .nav .badge { font-size:.56rem; padding:5px; }
  .tool-link { padding:12px; font-size:.74rem; }
  .workspace-single .result-panel { padding:24px; }
  .report-facts .ledger-row { align-items:flex-start; }
  .report-facts dd { text-align:right; }
}
@media print {
  .tool-navigation,.mobile-navigation { display:none!important; }
  .page-transition { opacity:1!important; transform:none!important; }
  .print-report .metric-grid { display:block; }
  .print-report .mini-card { border:0; padding:0; margin:16px 0; }
  .print-report h2 { margin:0 0 16px; }
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > app/layout.tsx
import type { Metadata } from "next";
import { TierProvider } from "@/context/TierContext";
import { ProjectProvider } from "@/context/ProjectContext";
import { MotionShell } from "@/components/Primitives";
import Header from "@/components/Header";
import Footer from "@/components/Footer";
import "./globals.css";
export const metadata: Metadata = {
  title: "MarginPilot — Good work. Better margins.",
  description: "A private, browser-based pricing planner for freelancers and agencies. Calculate profitable quotes, stress-test scope, and plan capacity without external APIs.",
};
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en" data-theme="dark"><body><a className="skip-link" href="#main-content">Skip to content</a><TierProvider><ProjectProvider><MotionShell><Header /><main id="main-content" tabIndex={-1}>{children}</main><Footer /></MotionShell></ProjectProvider></TierProvider></body></html>;
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > app/page.tsx
import Hero from "@/components/Hero";
export default function Home() {
  return <Hero />;
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > app/pricing/page.tsx
import type { Metadata } from "next";
import PricingMatrix from "@/components/PricingMatrix";
export const metadata: Metadata = { title: "Plans and Pricing — MarginPilot", description: "Compare Free, Plus, and Pro demo plans for local project pricing and analysis." };
export default function PricingPage() { return <PricingMatrix />; }
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > app/quote/page.tsx
import type { Metadata } from "next";
import SaaSAppWorkspace from "@/components/SaaSAppWorkspace";
export const metadata: Metadata = { title: "Quote Calculator — MarginPilot", description: "Calculate a profitable project quote from your labor costs, expenses, overhead, and target margin." };
export default function QuotePage() { return <SaaSAppWorkspace view="quote" />; }
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > app/reports/page.tsx
import type { Metadata } from "next";
import SaaSAppWorkspace from "@/components/SaaSAppWorkspace";
export const metadata: Metadata = { title: "Project Reports — MarginPilot", description: "Preview project economics and export CSV or printable reports with the Pro demo tier." };
export default function ReportsPage() { return <SaaSAppWorkspace view="reports" />; }
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > app/scenarios/page.tsx
import type { Metadata } from "next";
import SaaSAppWorkspace from "@/components/SaaSAppWorkspace";
export const metadata: Metadata = { title: "Saved Scenarios — MarginPilot", description: "Save, load, and compare project scenarios privately in your browser." };
export default function ScenariosPage() { return <SaaSAppWorkspace view="scenarios" />; }
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > app/scope/page.tsx
import type { Metadata } from "next";
import SaaSAppWorkspace from "@/components/SaaSAppWorkspace";
export const metadata: Metadata = { title: "Scope Risk — MarginPilot", description: "Stress-test project effort and understand its effect on profit at a fixed quote." };
export default function ScopePage() { return <SaaSAppWorkspace view="risk" />; }
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > app/template.tsx
"use client";
import { motion } from "framer-motion";
export default function Template({ children }: { children: React.ReactNode }) {
  return <motion.div className="page-transition" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.2 }}>{children}</motion.div>;
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > components/Footer.tsx
"use client";
import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowUpRight, Command } from "lucide-react";
import { useTier } from "@/context/TierContext";
import { Button } from "./Primitives";
export default function Footer() {
  const { tier, selectTier, ready } = useTier();
  return <><motion.footer initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }} className="container footer"><div className="between wrap"><Link href="/" className="brand"><Command size={20} />MarginPilot</Link><span className="small muted">Built for better business decisions.</span></div><div className="footer-details small muted"><p>Privacy: inputs and scenarios are stored only in this browser. Clearing site storage removes them. No analytics, cloud storage, or external APIs are used.</p><p>Terms: this is an illustrative planning tool. Results depend on your assumptions. Demo tiers do not process payments or provide secure entitlements.</p></div></motion.footer><motion.div className="plan-dock" initial={{ opacity: 0 }} animate={{ opacity: 1 }}><div className="container between"><span className="small"><b>{tier}</b> demo <span className="muted dock-label">/ your private pricing workspace</span></span><div className="row"><Link href="/pricing" className="small muted">All plans</Link>{tier !== "Pro" && <Button disabled={!ready} className="primary small" onClick={() => selectTier(tier === "Free" ? "Plus" : "Pro")}>Try {tier === "Free" ? "Plus" : "Pro"}<ArrowUpRight size={14} /></Button>}{tier === "Pro" && <Link className="btn small" href="/quote">Open workspace<ArrowUpRight size={14} /></Link>}</div></div></motion.div></>;
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > components/Header.tsx
"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { Command, Sun, Moon, ArrowUpRight, Menu, X } from "lucide-react";
import { useTier } from "@/context/TierContext";
import { TOOL_ROUTES } from "@/lib/routes";
import { Button } from "./Primitives";

export default function Header() {
  const { tier, theme, toggleTheme } = useTier();
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);
  const links = [...TOOL_ROUTES, { href: "/pricing", label: "Pricing" }];

  return <motion.header initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="topbar">
    <div className="container nav">
      <Link href="/" className="brand" aria-label="MarginPilot home" onClick={() => setMenuOpen(false)}><Command size={23} aria-hidden="true" />MarginPilot</Link>
      <nav aria-label="Main navigation" className="navlinks">
        <Link href="/quote" aria-current={pathname === "/quote" ? "page" : undefined}>Tools</Link>
        <Link href="/pricing" aria-current={pathname === "/pricing" ? "page" : undefined}>Pricing</Link>
      </nav>
      <div className="row">
        <span className="badge"><AnimatePresence mode="wait"><motion.span key={tier} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>{tier} demo</motion.span></AnimatePresence></span>
        <Button className="icon-btn" onClick={toggleTheme} aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} theme`}>{theme === "dark" ? <Sun size={17} /> : <Moon size={17} />}</Button>
        <Link className="btn navcta" href="/quote">Open app<ArrowUpRight size={15} /></Link>
        <Button className="icon-btn mobile-menu-toggle" aria-label={menuOpen ? "Close navigation" : "Open navigation"} aria-expanded={menuOpen} aria-controls="mobile-navigation" onClick={() => setMenuOpen(open => !open)}>{menuOpen ? <X size={18} /> : <Menu size={18} />}</Button>
      </div>
    </div>
    <AnimatePresence>{menuOpen && <motion.nav id="mobile-navigation" aria-label="Mobile navigation" className="container mobile-navigation" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onKeyDown={event => { if (event.key === "Escape") { setMenuOpen(false); document.querySelector<HTMLButtonElement>(".mobile-menu-toggle")?.focus(); } }}>
      {links.map(link => <Link key={link.href} href={link.href} aria-current={pathname === link.href ? "page" : undefined} onClick={() => setMenuOpen(false)}>{link.label}<ArrowUpRight size={14} /></Link>)}
    </motion.nav>}</AnimatePresence>
  </motion.header>;
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > components/Hero.tsx
"use client";
import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowUpRight, ArrowRight, ShieldCheck } from "lucide-react";
import { Reveal } from "./Primitives";
const MotionLink = motion.create(Link);
export default function Hero() {
  return <Reveal className="container hero">
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ staggerChildren: 0.12 }}>
      <div className="eyebrow"><span className="status-dot" /> INDEPENDENT WORK. INTELLIGENT PRICING.</div>
      <motion.h1 initial={{ opacity: 0, y: 18 }} animate={{ opacity: 1, y: 0 }}>Good work.<br /><span className="muted">Better margins.</span></motion.h1>
      <motion.p className="hero-copy" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.15 }}>Turn your next project into a profitable decision. Model the quote, stress-test the scope, and see what your time is really worth.</motion.p>
      <div className="row wrap hero-actions"><MotionLink href="/quote" className="btn primary" whileHover={{ scale: 1.025 }} whileTap={{ scale: 0.98 }}>Calculate my quote <ArrowUpRight size={17} /></MotionLink><Link href="/pricing" className="text-link">Explore plans <ArrowRight size={15} /></Link></div>
      <p className="small muted row"><ShieldCheck size={15} /> No account. No uploads. Your numbers stay in this browser.</p>
    </motion.div>
    <motion.div className="terminal" initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} whileHover={{ y: -3 }}>
      <div className="terminal-bar"><div className="row dots"><i /><i /><i /></div><span className="mono small">quote.engine / example</span><span className="badge">LOCAL</span></div>
      <div className="terminal-body mono"><p className="muted">$ marginpilot model --project website</p><p><span className="muted">01 /</span> Labor + expenses + overhead <b>$3,100</b></p><p><span className="muted">02 /</span> Target profit margin <b>35%</b></p><div className="terminal-result"><span className="small muted">RECOMMENDED QUOTE</span><strong>$4,769</strong><span className="accent small">$1,669 modeled profit · Free calculation</span></div><div className="row small muted"><span className="status-dot" /> Ready to calculate your project<span className="cursor">▍</span></div></div>
    </motion.div>

  </Reveal>;
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > components/PricingMatrix.tsx
"use client";
import Link from "next/link";
import { motion } from "framer-motion";
import { Check, ArrowUpRight } from "lucide-react";
import { useTier } from "@/context/TierContext";
import type { Tier } from "@/lib/engine";
import { Button, Reveal } from "./Primitives";
const plans: { name: Tier; price: number; description: string; features: string[] }[] = [
  { name: "Free", price: 0, description: "Make your next quote make sense.", features: ["Full quote and margin calculator", "1 saved scenario", "Project presets", "Private browser storage"] },
  { name: "Plus", price: 19, description: "Protect your margin as scope changes.", features: ["Everything in Free", "Adjustable contingency reserve", "Scope sensitivity analysis", "5 saved scenarios + comparison"] },
  { name: "Pro", price: 49, description: "Plan the business behind the work.", features: ["Everything in Plus", "Team and weekly capacity controls", "Annual profit planning", "20 scenarios + CSV / print reports"] },
];
export default function PricingMatrix() {
  const { tier, selectTier, ready } = useTier();
  return <Reveal id="pricing" className="container section pricing-page"><div className="section-heading"><div><p className="eyebrow">A PLAN FOR YOUR NEXT STAGE</p><h1 className="page-title">Find your margin.<br /><span className="muted">Then protect it.</span></h1></div><p className="small muted">Illustrative monthly pricing in USD.<br />Try every tier. No payment is collected.</p></div><div className="pricing-grid">{plans.map(plan => <motion.article layout className={`panel pricing-card ${plan.name === tier ? "selected" : ""}`} key={plan.name} whileHover={{ y: -4 }}><div className="between"><h2>{plan.name}</h2>{plan.name === "Plus" && <span className="badge accent">SCOPE CONTROL</span>}</div><p className="muted small">{plan.description}</p><div className="price">${plan.price}<span className="muted small"> / month</span></div><Button disabled={!ready} aria-pressed={plan.name === tier} className={plan.name === tier ? "primary full" : "full"} onClick={() => selectTier(plan.name)}>{plan.name === tier ? "Active demo tier" : `Try ${plan.name} demo`}<ArrowUpRight size={16} /></Button><ul>{plan.features.map(item => <li key={item}><Check size={15} className="accent" />{item}</li>)}</ul></motion.article>)}</div><p className="small"><Link className="text-link" href="/quote">Continue to your quote <ArrowUpRight size={15} /></Link></p><p className="small muted">Demo access is stored locally and can be changed at any time. Saved scenarios are kept when you switch tiers; access follows your current plan.</p></Reveal>;
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > components/Primitives.tsx
"use client";
import { motion, MotionConfig, type HTMLMotionProps } from "framer-motion";
import type { ReactNode } from "react";
export function MotionShell({ children }: { children: ReactNode }) {
  return <MotionConfig reducedMotion="user" transition={{ type: "spring", stiffness: 280, damping: 28 }}>{children}</MotionConfig>;
}
export function Reveal({ children, className = "", id }: { children: ReactNode; className?: string; id?: string }) {
  return <motion.section id={id} className={className} initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true, amount: 0.08 }} transition={{ duration: 0.4 }}>{children}</motion.section>;
}
export function Button({ children, className = "", ...props }: HTMLMotionProps<"button">) {
  return <motion.button type="button" className={`btn ${className}`} whileHover={props.disabled ? undefined : { scale: 1.025 }} whileTap={props.disabled ? undefined : { scale: 0.98 }} {...props}>{children}</motion.button>;
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > components/SaaSAppWorkspace.tsx
"use client";

import { useId, useState } from "react";
import Link from "next/link";
import { AnimatePresence, motion } from "framer-motion";
import { ArrowUpRight, Download, LockKeyhole, Save, Trash2, Printer, RotateCcw } from "lucide-react";
import { useTier } from "@/context/TierContext";
import { useProject } from "@/context/ProjectContext";
import { BOUNDS, DEFAULTS, LIMITS, calculate, sensitivity, money, downloadCSV, type Inputs } from "@/lib/engine";
import { TOOL_ROUTES, type ToolView } from "@/lib/routes";
import ToolNavigation from "./ToolNavigation";
import { Button, Reveal } from "./Primitives";

const presets: { name: string; inputs: Inputs }[] = [
  { name: "Website", inputs: DEFAULTS },
  { name: "Brand sprint", inputs: { ...DEFAULTS, hours: 24, rate: 90, expenses: 100, overhead: 200, margin: 40 } },
  { name: "Retainer", inputs: { ...DEFAULTS, hours: 60, rate: 75, expenses: 150, overhead: 500, margin: 30 } },
];

function Field({ label, value, field, suffix = "", locked = false, onChange }: { label: string; value: number; field: keyof Inputs; suffix?: string; locked?: boolean; onChange: (key: keyof Inputs, value: number) => void }) {
  const id = useId();
  const [min, max, step] = BOUNDS[field];
  return <div className={`field ${locked ? "locked-field" : ""}`}>
    <div className="between"><label htmlFor={id}>{label}</label>{locked && <LockKeyhole size={13} aria-label="Requires a higher tier" />}</div>
    <div className="input-shell"><input id={id} type="number" min={min} max={max} step={step} disabled={locked} value={value} onChange={event => {
      const n = event.target.valueAsNumber;
      if (Number.isFinite(n)) onChange(field, Math.min(max, Math.max(min, field === "team" ? Math.round(n) : n)));
    }} /><span className="mono muted small">{suffix}</span></div>
    <input type="range" aria-label={`${label} slider`} min={min} max={max} step={step} disabled={locked} value={value} onChange={event => onChange(field, Number(event.target.value))} />
  </div>;
}

function Upgrade({ plan, children }: { plan: "Plus" | "Pro"; children: React.ReactNode }) {
  const { selectTier, ready } = useTier();
  return <motion.div className="upgrade" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
    <LockKeyhole size={18} /><div><b>{plan} decision tools</b><p className="small muted">{children}</p><Link href="/pricing" className="small text-link">Compare plans<ArrowUpRight size={12} /></Link></div>
    <Button disabled={!ready} onClick={() => selectTier(plan)}>Try {plan}<ArrowUpRight size={14} /></Button>
  </motion.div>;
}

function ProjectSummary() {
  const { tier } = useTier();
  const { name, inputs } = useProject();
  const result = calculate(inputs, tier);
  return <div className="project-summary"><div className="between wrap"><div><p className="eyebrow">CURRENT PROJECT</p><h2 className="project-name">{name.trim() || "Untitled project"}</h2></div><Link href="/quote" className="btn small">Edit quote<ArrowUpRight size={14} /></Link></div>
    <div className="metric-grid"><div className="mini-card"><p className="small muted">Recommended quote</p><strong>{money(result.quote)}</strong></div><div className="mini-card"><p className="small muted">Modeled profit</p><strong className="accent">{money(result.profit)}</strong></div></div>
  </div>;
}

function QuoteResult() {
  const { tier } = useTier();
  const { inputs } = useProject();
  const result = calculate(inputs, tier);
  return <>
    <div className="quote-block"><p className="eyebrow">YOUR RECOMMENDED PROJECT QUOTE</p><motion.div layout className="quote-number">{money(result.quote)}</motion.div><p className="muted">Built around a {inputs.margin}% target margin{tier !== "Free" ? ` and ${inputs.contingency}% contingency` : ""}.</p></div>
    <div className="metric-grid"><motion.div layout className="mini-card"><p className="small muted">Modeled profit</p><strong className="accent">{money(result.profit)}</strong></motion.div><motion.div layout className="mini-card"><p className="small muted">Effective billing rate</p><strong>{money(result.hourly)}<span className="small muted"> / hr</span></strong></motion.div></div>
    <div className="breakdown"><h2 className="subheading">Every dollar, accounted for.</h2>{[["Labor", inputs.hours * inputs.rate], ["Direct expenses", inputs.expenses], ["Project overhead", inputs.overhead], ["Contingency reserve", result.reserve], ["Target profit", result.profit]].map(([label, value]) => <div className="between ledger-row" key={label}><span className="muted">{label}</span><span className="mono">{money(Number(value))}</span></div>)}
      <div className="stacked-bar" aria-label="Quote composition">{[inputs.hours * inputs.rate, inputs.expenses, inputs.overhead, result.reserve, result.profit].map((n, i) => <motion.span key={i} animate={{ width: `${n / result.quote * 100}%` }} style={{ background: `var(--chart-${i})` }} />)}</div>
      <p className="small muted">Quote = (labor + expenses + overhead + reserve) ÷ (1 − margin). Profit is after the reserve; taxes and unmodeled costs are excluded.</p>
    </div>
    <Link className="text-link small" href="/scope">Stress-test this quote<ArrowUpRight size={14} /></Link>
    {tier === "Free" && <Upgrade plan="Plus">Build in a contingency buffer and check what happens when the scope grows.</Upgrade>}
  </>;
}

function ScopeTable() {
  const { tier } = useTier();
  const { inputs } = useProject();
  return <table><caption className="sr-only">Scope sensitivity results</caption><thead><tr><th>Effort change</th><th>Profit</th><th>Margin</th></tr></thead><tbody>{sensitivity(inputs, tier).map(row => <tr key={row.delta}><td>{row.delta > 0 ? "+" : ""}{row.delta}%</td><td className={row.profit < 0 ? "danger" : ""}>{money(row.profit)}</td><td>{row.margin.toFixed(1)}%</td></tr>)}</tbody></table>;
}

function ScopeResult() {
  const { tier } = useTier();
  const { inputs } = useProject();
  if (tier === "Free") return <Upgrade plan="Plus">Unlock a seven-point scope stress test. See exactly where overruns erode your margin.</Upgrade>;
  const result = calculate(inputs, tier);
  return <div className="analysis"><p className="eyebrow">FIXED QUOTE / CHANGING EFFORT</p><h2 className="analysis-title">What if the work expands?</h2><p className="muted small">The quote stays at {money(result.quote)}. Labor and its contingency reserve change with effort; other costs stay fixed.</p>
    <div className="risk-chart" role="img" aria-label="Profit margin by effort change; exact values are listed below">{sensitivity(inputs, tier).map(row => <div className="risk-column" key={row.delta}><span className={row.margin < 0 ? "danger small" : "small"}>{row.margin.toFixed(0)}%</span><div className="bar-track"><motion.div className={row.margin < 0 ? "risk-bar negative" : "risk-bar"} initial={{ height: 0 }} animate={{ height: `${Math.min(100, Math.max(3, Math.abs(row.margin)))}%` }} /></div><span className="small muted">{row.delta > 0 ? "+" : ""}{row.delta}%</span></div>)}</div>
    <ScopeTable />
  </div>;
}

function CapacityResult() {
  const { tier } = useTier();
  const { inputs } = useProject();
  if (tier !== "Pro") return <Upgrade plan="Pro">Adjust productive hours and team size to model delivery time and annual profit.</Upgrade>;
  const result = calculate(inputs, tier);
  return <div className="analysis"><p className="eyebrow">CAPACITY / 48-WEEK PLANNING MODEL</p><h2 className="analysis-title">Turn a project into a plan.</h2><div className="metric-grid capacity-metrics">{[["Project duration", `${result.weeks.toFixed(1)} weeks`], ["Team capacity", `${inputs.weekly * inputs.team} hrs/week`], ["Equivalent projects / year", result.annualProjects.toFixed(1)], ["Modeled annual profit", money(result.annualProfit)]].map(([label, value]) => <motion.div layout key={label} className="mini-card"><p className="small muted">{label}</p><strong>{value}</strong></motion.div>)}</div><p className="small muted">Assumes 48 working weeks, full utilization, parallelizable work, and repeated projects with the same cost and scope. This is a planning model, not a revenue forecast. Adjust productive hours to account for selling, admin, and time off.</p></div>;
}

function ScenariosResult({ onSave }: { onSave: () => void }) {
  const { tier } = useTier();
  const { inputs, setInputs, scenarios, setScenarios, setName, setNotice } = useProject();
  const [compareId, setCompareId] = useState("");
  const accessible = scenarios.slice(0, LIMITS[tier]);
  const compare = tier !== "Free" ? accessible.find(scenario => scenario.id === compareId) : undefined;
  const compared = compare ? calculate(compare.inputs, tier) : undefined;
  const result = calculate(inputs, tier);
  return <>
    <ProjectSummary />
    <div className="saved"><div className="between wrap"><h2 className="subheading">Saved scenarios ({scenarios.length}/{LIMITS[tier]})</h2><Button onClick={onSave}><Save size={15} />Save current project</Button></div>
      {scenarios.length === 0 && <div className="empty-state"><p className="muted">No saved scenarios yet. Start with your current project, or refine its inputs on the quote page.</p><Link className="text-link" href="/quote">Open quote calculator<ArrowUpRight size={15} /></Link></div>}
      <AnimatePresence initial={false}>{scenarios.map((scenario, index) => <motion.div layout initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} key={scenario.id} className="scenario"><Button className="scenario-load" disabled={index >= LIMITS[tier]} onClick={() => { setInputs({ ...scenario.inputs }); setName(scenario.name); setNotice(`Loaded ${scenario.name}. All tool pages now use this project at the ${tier} tier.`); }}><span>{scenario.name}</span><span className="mono small muted">{index >= LIMITS[tier] ? "Tier locked" : money(calculate(scenario.inputs, tier).quote)}</span></Button><Button className="icon-btn" aria-label={`Delete ${scenario.name}`} onClick={() => { setScenarios(current => current.filter(item => item.id !== scenario.id)); setNotice(`Deleted ${scenario.name}.`); }}><Trash2 size={14} /></Button></motion.div>)}</AnimatePresence>
      {scenarios.length > LIMITS[tier] && <p className="small muted">Scenarios above your current plan limit are retained. Switch plans to access them.</p>}
      {tier !== "Free" && accessible.length > 0 && <div className="comparison"><label htmlFor="compare" className="small muted">Compare current quote with a saved scenario</label><select id="compare" value={compare?.id || ""} onChange={event => setCompareId(event.target.value)}><option value="">Choose a scenario</option>{accessible.map(scenario => <option key={scenario.id} value={scenario.id}>{scenario.name}</option>)}</select>{compared && <p className="small">Quote difference: <b>{money(result.quote - compared.quote)}</b> · Profit difference: <b>{money(result.profit - compared.profit)}</b><span className="muted"> (current minus saved, at {tier} settings)</span></p>}</div>}
      {tier === "Free" && <Upgrade plan="Plus">Keep five scenarios and compare their quote and profit differences.</Upgrade>}
    </div>
  </>;
}

function ProjectReport({ print = false }: { print?: boolean }) {
  const { tier } = useTier();
  const { inputs, name } = useProject();
  const result = calculate(inputs, tier);
  return <article className={print ? "print-report" : "report-preview"}>
    <h2 className="analysis-title">{name.trim() || "Untitled project"}</h2><p className="small muted">MarginPilot project report · USD · {tier} demo tier</p>
    <div className="metric-grid"><div className="mini-card"><p className="small muted">Recommended quote</p><strong>{money(result.quote)}</strong></div><div className="mini-card"><p className="small muted">Modeled profit</p><strong>{money(result.profit)}</strong></div></div>
    <dl className="report-facts">{[["Estimated effort", `${inputs.hours} hours`], ["Internal hourly cost", `${money(inputs.rate)}/hour`], ["Direct expenses", money(inputs.expenses)], ["Allocated overhead", money(inputs.overhead)], ["Target margin", `${inputs.margin}%`], ["Contingency reserve", money(result.reserve)], ["Team capacity", `${inputs.weekly * inputs.team} hours/week`], ["Project duration", `${result.weeks.toFixed(1)} weeks`], ["Modeled annual profit", money(result.annualProfit)]].map(([label, value]) => <div className="between ledger-row" key={label}><dt className="muted">{label}</dt><dd className="mono">{value}</dd></div>)}</dl>
    <h3>Scope sensitivity</h3><ScopeTable />
    <p className="small muted report-assumptions">Annual figures assume 48 working weeks, full utilization, parallelizable work, and identical repeated projects. Profit is after contingency reserves. Taxes and unmodeled costs are excluded.</p>
  </article>;
}

export default function SaaSAppWorkspace({ view }: { view: ToolView }) {
  const { tier } = useTier();
  const { inputs, setInputs, scenarios, setScenarios, name, setName, notice, setNotice, active, storageOK } = useProject();
  const plus = tier !== "Free";
  const pro = tier === "Pro";
  const details = TOOL_ROUTES.find(route => route.view === view)!;
  const editable = view === "quote" || view === "risk" || view === "capacity";
  const result = calculate(inputs, tier);

  function change(key: keyof Inputs, value: number) { setInputs(current => ({ ...current, [key]: value })); }
  function save() {
    if (!active) return;
    if (scenarios.length >= LIMITS[tier]) { setNotice(`Your ${tier} plan allows ${LIMITS[tier]} saved scenarios. Delete a scenario or try a higher tier.`); return; }
    setScenarios(current => [...current, { id: crypto.randomUUID(), name: name.trim() || "Untitled project", inputs: { ...inputs }, savedAt: new Date().toISOString() }]);
    setNotice("Scenario saved in this browser. Open Scenarios to revisit or compare it.");
  }
  function exportReport() {
    if (!pro || !active) return;
    downloadCSV([
      ["MarginPilot project report", name.trim() || "Untitled project"], ["Currency", "USD"], ["Demo tier", tier],
      ["Effort hours", inputs.hours], ["Internal hourly cost", inputs.rate], ["Direct expenses", inputs.expenses], ["Allocated overhead", inputs.overhead],
      ["Target margin percent", inputs.margin], ["Contingency percent", inputs.contingency], ["Base cost", result.cost], ["Reserve", result.reserve],
      ["Recommended quote", Number(result.quote.toFixed(2))], ["Modeled profit", Number(result.profit.toFixed(2))],
      ["Weekly productive hours per person", inputs.weekly], ["Team size", inputs.team], ["Estimated project weeks", Number(result.weeks.toFixed(2))],
      ["Annual modeled profit", Number(result.annualProfit.toFixed(2))], ["Assumption", "48 working weeks, full utilization, identical repeated projects; excludes tax and unmodeled costs"],
      [], ["Effort change percent", "Profit at fixed quote", "Margin percent"], ...sensitivity(inputs, tier).map(row => [row.delta, Number(row.profit.toFixed(2)), Number(row.margin.toFixed(2))]),
    ], "marginpilot-report.csv");
    setNotice("CSV report downloaded.");
  }

  return <Reveal id="workspace" className="container section workspace-section">
    <div className="section-heading"><div><p className="eyebrow">YOUR PRIVATE WORKSPACE / {details.label.toUpperCase()}</p><h1 className="page-title">{details.title}</h1><p className="muted page-description">{details.description}</p></div><span className="badge">{tier.toUpperCase()} DEMO · USD</span></div>
    <ToolNavigation />
    <div className="panel workspace"><div className="workspace-toolbar between"><div className="row"><span className="status-dot" /><span className="mono small">marginpilot / {details.label.toLowerCase()}</span></div>{editable && <Button onClick={() => { setInputs({ ...DEFAULTS }); setNotice("Inputs reset. Saved scenarios are retained."); }} disabled={!active} className="small"><RotateCcw size={14} />Reset inputs</Button>}</div>
      {!storageOK && <p className="storage-warning" role="status">Browser storage is unavailable or contained invalid data. Calculations still work; changes may only last for this session.</p>}
      <fieldset className={editable ? "workspace-grid" : "workspace-single"} disabled={!active} aria-busy={!active}><legend className="sr-only">{details.label} workspace</legend>
        {editable && <motion.aside layout className="input-panel"><h2 className="subheading">Project inputs</h2><label className="small muted" htmlFor="project-name">Project name</label><input id="project-name" className="name-input" maxLength={60} value={name} onChange={event => setName(event.target.value)} />
          <div className="row wrap presets">{presets.map(preset => <Button className="small" key={preset.name} onClick={() => { setInputs({ ...preset.inputs }); setName(preset.name); setNotice(`${preset.name} preset loaded.`); }}>{preset.name}</Button>)}</div>
          <Field label="Estimated effort" value={inputs.hours} field="hours" suffix="hrs" onChange={change} /><Field label="Internal hourly cost" value={inputs.rate} field="rate" suffix="USD/hr" onChange={change} /><p className="small muted helper">Use your cost of labor, not your client billing rate.</p><Field label="Direct expenses" value={inputs.expenses} field="expenses" suffix="USD" onChange={change} /><Field label="Allocated project overhead" value={inputs.overhead} field="overhead" suffix="USD" onChange={change} /><Field label="Target profit margin" value={inputs.margin} field="margin" suffix="%" onChange={change} /><Field label="Contingency reserve" value={plus ? inputs.contingency : 0} field="contingency" suffix={plus ? "%" : "Plus"} locked={!plus} onChange={change} />
          {view === "capacity" && <div className="two-col"><Field label="Hours / week" value={pro ? inputs.weekly : 30} field="weekly" suffix={pro ? "hrs" : "Pro"} locked={!pro} onChange={change} /><Field label="Team size" value={pro ? inputs.team : 1} field="team" suffix={pro ? "people" : "Pro"} locked={!pro} onChange={change} /></div>}
          <Button className="primary full" onClick={save}><Save size={16} />Save scenario ({scenarios.length}/{LIMITS[tier]})</Button><Link href="/scenarios" className="text-link small saved-link">View saved scenarios<ArrowUpRight size={14} /></Link>
        </motion.aside>}
        <div className="result-panel">
          {view === "quote" && <QuoteResult />}
          {view === "risk" && <ScopeResult />}
          {view === "capacity" && <CapacityResult />}
          {view === "scenarios" && <ScenariosResult onSave={save} />}
          {view === "reports" && (pro ? <><ProjectReport /><div className="export-row row wrap"><Button onClick={exportReport}><Download size={15} />Export CSV</Button><Button onClick={() => { if (pro && active) window.print(); }}><Printer size={15} />Print report</Button><Link href="/quote" className="text-link small">Edit project<ArrowUpRight size={14} /></Link></div></> : <><ProjectSummary /><Upgrade plan="Pro">Preview your complete project report, download its CSV, and print a shareable summary.</Upgrade></>)}
          <p className="notice small" role="status" aria-live="polite">{!active ? "Restoring browser workspace…" : notice || "All tool pages share this project. Your numbers stay in this browser."}</p>
        </div>
      </fieldset>
    </div>
    {view === "reports" && pro && <ProjectReport print />}
  </Reveal>;
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > components/ToolNavigation.tsx
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { motion } from "framer-motion";
import { TOOL_ROUTES } from "@/lib/routes";

export default function ToolNavigation() {
  const pathname = usePathname();
  return <motion.nav className="tool-navigation" aria-label="Workspace tools" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
    {TOOL_ROUTES.map(route => <Link key={route.href} href={route.href} aria-current={pathname === route.href ? "page" : undefined} className={pathname === route.href ? "tool-link current" : "tool-link"}>
      {route.label}
      {pathname === route.href && <motion.span className="tool-link-indicator" layoutId="active-tool" />}
    </Link>)}
  </motion.nav>;
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > context/ProjectContext.tsx
"use client";

import { createContext, useContext, useState, type Dispatch, type SetStateAction, type ReactNode } from "react";
import { useTier } from "@/context/TierContext";
import { useLocalState } from "@/lib/useLocalState";
import { DEFAULTS, isInputs, isScenarios, type Inputs, type Scenario } from "@/lib/engine";

function isName(value: unknown): value is string {
  return typeof value === "string" && value.length <= 60;
}

type ProjectState = {
  inputs: Inputs;
  setInputs: Dispatch<SetStateAction<Inputs>>;
  scenarios: Scenario[];
  setScenarios: Dispatch<SetStateAction<Scenario[]>>;
  name: string;
  setName: Dispatch<SetStateAction<string>>;
  notice: string;
  setNotice: Dispatch<SetStateAction<string>>;
  active: boolean;
  storageOK: boolean;
};

const ProjectContext = createContext<ProjectState | undefined>(undefined);

export function ProjectProvider({ children }: { children: ReactNode }) {
  const { ready, storageOK: tierStorageOK } = useTier();
  const [inputs, setInputs, inputsReady, inputsOK] = useLocalState<Inputs>("marginpilot:inputs:v1", DEFAULTS, isInputs);
  const [scenarios, setScenarios, scenariosReady, scenariosOK] = useLocalState<Scenario[]>("marginpilot:scenarios:v1", [], isScenarios);
  const [name, setName, nameReady, nameOK] = useLocalState<string>("marginpilot:name:v1", "My next project", isName);
  const [notice, setNotice] = useState("");

  return <ProjectContext.Provider value={{
    inputs, setInputs, scenarios, setScenarios, name, setName, notice, setNotice,
    active: ready && inputsReady && scenariosReady && nameReady,
    storageOK: tierStorageOK && inputsOK && scenariosOK && nameOK,
  }}>{children}</ProjectContext.Provider>;
}

export function useProject() {
  const value = useContext(ProjectContext);
  if (!value) throw new Error("ProjectProvider is required");
  return value;
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > context/TierContext.tsx
"use client";
import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { isTier, type Tier } from "@/lib/engine";
type State = { tier: Tier; selectTier: (tier: Tier) => void; theme: "dark" | "light"; toggleTheme: () => void; ready: boolean; storageOK: boolean };
const Context = createContext<State | undefined>(undefined);
export function TierProvider({ children }: { children: ReactNode }) {
  const [tier, setTier] = useState<Tier>("Free");
  const [theme, setTheme] = useState<"dark" | "light">("dark");
  const [ready, setReady] = useState(false);
  const [storageOK, setStorageOK] = useState(true);
  useEffect(() => {
    try {
      const stored = localStorage.getItem("marginpilot:tier:v1");
      if (isTier(stored)) setTier(stored);
      const savedTheme = localStorage.getItem("marginpilot:theme:v1");
      if (savedTheme === "light" || savedTheme === "dark") setTheme(savedTheme);
      else if (window.matchMedia("(prefers-color-scheme: light)").matches) setTheme("light");
    } catch { setStorageOK(false); }
    setReady(true);
    const sync = (event: StorageEvent) => {
      if (event.key === "marginpilot:tier:v1") setTier(isTier(event.newValue) ? event.newValue : "Free");
      if (event.key === "marginpilot:theme:v1") setTheme(event.newValue === "light" ? "light" : "dark");
    };
    window.addEventListener("storage", sync);
    return () => window.removeEventListener("storage", sync);
  }, []);
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    if (!ready) return;
    try { localStorage.setItem("marginpilot:tier:v1", tier); localStorage.setItem("marginpilot:theme:v1", theme); }
    catch { setStorageOK(false); }
  }, [tier, theme, ready]);
  return <Context.Provider value={{ tier, selectTier: setTier, theme, toggleTheme: () => setTheme(t => t === "dark" ? "light" : "dark"), ready, storageOK }}>{children}</Context.Provider>;
}
export function useTier() { const value = useContext(Context); if (!value) throw new Error("TierProvider is required"); return value; }
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > eslint.config.mjs
import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTypescript from "eslint-config-next/typescript";
export default defineConfig([
  ...nextVitals,
  ...nextTypescript,
  {
    files: ["context/TierContext.tsx", "lib/useLocalState.ts"],
    // Browser storage is intentionally restored after SSR hydration.
    rules: { "react-hooks/set-state-in-effect": "off" },
  },
  { files: ["tests/*.cjs"], rules: { "@typescript-eslint/no-require-imports": "off" } },
  globalIgnores([".next/**", "out/**", ".engine-check/**", "next-env.d.ts"]),
]);
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > lib/engine.ts
export type Tier = "Free" | "Plus" | "Pro";
export const TIERS: Tier[] = ["Free", "Plus", "Pro"];
export const LIMITS: Record<Tier, number> = { Free: 1, Plus: 5, Pro: 20 };
export type Inputs = { hours: number; rate: number; expenses: number; overhead: number; margin: number; contingency: number; weekly: number; team: number };
export const DEFAULTS: Inputs = { hours: 40, rate: 65, expenses: 200, overhead: 300, margin: 35, contingency: 10, weekly: 30, team: 1 };
export const BOUNDS: Record<keyof Inputs, [number, number, number]> = {
  hours: [1, 2000, 1], rate: [1, 1000, 1], expenses: [0, 100000, 50], overhead: [0, 100000, 50],
  margin: [0, 85, 1], contingency: [0, 50, 1], weekly: [1, 80, 1], team: [1, 50, 1],
};
export function isTier(value: unknown): value is Tier { return TIERS.includes(value as Tier); }
export function isInputs(value: unknown): value is Inputs {
  if (!value || typeof value !== "object") return false;
  return (Object.keys(BOUNDS) as (keyof Inputs)[]).every(key => {
    const n = (value as Inputs)[key]; const [min, max] = BOUNDS[key];
    return typeof n === "number" && Number.isFinite(n) && n >= min && n <= max && (key !== "team" || Number.isInteger(n));
  });
}
export function calculate(input: Inputs, tier: Tier) {
  const contingency = tier === "Free" ? 0 : input.contingency;
  const weekly = tier === "Pro" ? input.weekly : 30;
  const team = tier === "Pro" ? input.team : 1;
  const cost = input.hours * input.rate + input.expenses + input.overhead;
  const reserve = cost * contingency / 100;
  const totalCost = cost + reserve;
  const quote = totalCost / (1 - input.margin / 100);
  const profit = quote - totalCost;
  const weeks = input.hours / (weekly * team);
  const annualProjects = 48 / weeks;
  return { cost, reserve, totalCost, quote, profit, weeks, annualProjects, annualProfit: profit * annualProjects, hourly: quote / input.hours };
}
export function sensitivity(input: Inputs, tier: Tier) {
  const base = calculate(input, tier);
  return [-20, -10, 0, 10, 20, 30, 40].map(delta => {
    const hours = input.hours * (1 + delta / 100);
    const cost = (hours * input.rate + input.expenses + input.overhead) * (1 + (tier === "Free" ? 0 : input.contingency) / 100);
    return { delta, profit: base.quote - cost, margin: (base.quote - cost) / base.quote * 100 };
  });
}
export type Scenario = { id: string; name: string; inputs: Inputs; savedAt: string };
export function isScenarios(value: unknown): value is Scenario[] {
  if (!Array.isArray(value) || value.length > 20) return false;
  const ids = new Set<string>();
  return value.every(item => {
    if (!item || typeof item.id !== "string" || item.id.length > 100 || ids.has(item.id) || typeof item.name !== "string" || item.name.length > 60 || !isInputs(item.inputs) || typeof item.savedAt !== "string" || !Number.isFinite(Date.parse(item.savedAt))) return false;
    ids.add(item.id); return true;
  });
}
export const money = (value: number) => new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 }).format(value);
export function downloadCSV(rows: (string | number)[][], filename: string) {
  const cell = (value: string | number) => {
    const raw = typeof value === "string" && /^[\s]*[=+@-]/.test(value) ? "'" + value : String(value);
    return '"' + raw.replace(/"/g, '""') + '"';
  };
  const blob = new Blob(["\uFEFF" + rows.map(row => row.map(cell).join(",")).join("\r\n")], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob); const a = document.createElement("a");
  a.href = url; a.download = filename; document.body.appendChild(a); a.click(); a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > lib/routes.ts
export const TOOL_ROUTES = [
  { href: "/quote", view: "quote", label: "Quote", title: "Price the project.", description: "Turn labor, expenses, and overhead into a quote that meets your target margin." },
  { href: "/scope", view: "risk", label: "Scope risk", title: "Protect your margin.", description: "Hold the quote fixed and see how changing effort affects your profit." },
  { href: "/capacity", view: "capacity", label: "Capacity", title: "Plan your capacity.", description: "Model delivery time and annual profit using your team's productive hours." },
  { href: "/scenarios", view: "scenarios", label: "Scenarios", title: "Compare your decisions.", description: "Save, revisit, and compare projects stored privately in this browser." },
  { href: "/reports", view: "reports", label: "Reports", title: "Share the numbers.", description: "Preview your current project and export a CSV or printable report." },
] as const;

export type ToolView = typeof TOOL_ROUTES[number]["view"];
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > lib/useLocalState.ts
"use client";
import { useEffect, useState, type Dispatch, type SetStateAction } from "react";
export function useLocalState<T>(key: string, initial: T, validate: (value: unknown) => value is T): [T, Dispatch<SetStateAction<T>>, boolean, boolean] {
  const [value, setValue] = useState<T>(initial);
  const [ready, setReady] = useState(false);
  const [storageOK, setStorageOK] = useState(true);
  useEffect(() => {
    try { const raw = localStorage.getItem(key); if (raw) { const parsed: unknown = JSON.parse(raw); if (validate(parsed)) setValue(parsed); else setStorageOK(false); } }
    catch { setStorageOK(false); }
    setReady(true);
  }, [key, validate]);
  useEffect(() => {
    if (!ready) return;
    try { localStorage.setItem(key, JSON.stringify(value)); } catch { setStorageOK(false); }
  }, [key, value, ready]);
  return [value, setValue, ready, storageOK];
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > next-env.d.ts
/// <reference types="next" />
/// <reference types="next/image-types/global" />
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > next.config.ts
import type { NextConfig } from "next";
const nextConfig: NextConfig = { output: "export", images: { unoptimized: true }, poweredByHeader: false };
export default nextConfig;
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > package.json
{
  "name": "marginpilot",
  "version": "1.0.0",
  "private": true,
  "engines": {
    "node": ">=20.9.0"
  },
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit",
    "test": "tsc lib/engine.ts --target ES2020 --module commonjs --skipLibCheck --outDir .engine-check && node --test tests/engine.cjs",
    "test:browser": "playwright test"
  },
  "dependencies": {
    "next": "^16.0.0",
    "react": "^19.2.0",
    "react-dom": "^19.2.0",
    "framer-motion": "^12.23.24",
    "lucide-react": "^0.468.0"
  },
  "devDependencies": {
    "typescript": "^5.9.0",
    "@types/node": "^22.0.0",
    "@types/react": "^19.2.0",
    "@types/react-dom": "^19.2.0",
    "tailwindcss": "^4.1.0",
    "@tailwindcss/postcss": "^4.1.0",
    "eslint": "^9.0.0",
    "eslint-config-next": "^16.0.0",
    "@playwright/test": "^1.56.0"
  }
}
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > playwright.config.ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/browser",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: "list",
  use: { baseURL: "http://127.0.0.1:4173", trace: "retain-on-failure" },
  projects: [
    { name: "desktop", use: { ...devices["Desktop Chrome"] } },
    { name: "mobile", use: { ...devices["Pixel 7"] } },
  ],
  webServer: {
    command: "node tests/serve-static.cjs",
    url: "http://127.0.0.1:4173",
    reuseExistingServer: !process.env.CI,
  },
});
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > postcss.config.mjs
export default { plugins: { "@tailwindcss/postcss": {} } };
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > tests/browser/navigation.spec.ts
import { readFile } from "node:fs/promises";
import { test, expect } from "@playwright/test";

test("landing stays focused and projects survive navigation and reload", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toContainText("Good work.");
  await expect(page.locator(".workspace, .bento, .pricing-grid")).toHaveCount(0);
  await expect(page.getByRole("spinbutton")).toHaveCount(0);
  await page.getByRole("link", { name: "Calculate my quote" }).click();
  await expect(page).toHaveURL(/\/quote$/);
  await expect(page.getByLabel("Estimated effort", { exact: true })).toBeEnabled();
  await page.getByLabel("Project name", { exact: true }).fill("Client Alpha");
  await page.getByLabel("Estimated effort", { exact: true }).fill("80");
  await expect(page.locator(".quote-number")).toHaveText("$8,769");
  await page.getByRole("button", { name: "Save scenario" }).click();
  await page.getByRole("link", { name: "View saved scenarios" }).click();
  await expect(page).toHaveURL(/\/scenarios$/);
  await expect(page.getByRole("heading", { name: "Client Alpha" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Client Alpha" })).toBeEnabled();
  await page.getByRole("link", { name: "Edit quote", exact: true }).click();
  await page.getByLabel("Project name", { exact: true }).fill("Client Beta");
  await page.getByLabel("Estimated effort", { exact: true }).fill("20");
  await page.getByRole("navigation", { name: "Workspace tools" }).getByRole("link", { name: "Scenarios", exact: true }).click();
  await page.getByRole("button", { name: "Client Alpha" }).click();
  await page.getByRole("link", { name: "Edit quote", exact: true }).click();
  await expect(page.getByLabel("Project name", { exact: true })).toHaveValue("Client Alpha");
  await expect(page.getByLabel("Estimated effort", { exact: true })).toHaveValue("80");
  await page.reload();
  await expect(page.getByLabel("Estimated effort", { exact: true })).toBeEnabled();
  await expect(page.getByLabel("Project name", { exact: true })).toHaveValue("Client Alpha");
  await expect(page.locator(".quote-number")).toHaveText("$8,769");
});

test("direct tool routes honor plan gates and Pro produces reports", async ({ page }) => {
  await page.goto("/quote");
  await expect(page.getByLabel("Estimated effort", { exact: true })).toBeEnabled();
  await expect(page.getByLabel("Contingency reserve", { exact: true })).toBeDisabled();
  await page.goto("/scope");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Protect your margin.");
  await expect(page.locator("table")).toHaveCount(0);
  await page.goto("/capacity");
  await expect(page.getByLabel("Hours / week", { exact: true })).toBeDisabled();
  await page.goto("/reports");
  await expect(page.getByRole("button", { name: "Export CSV" })).toHaveCount(0);
  await page.goto("/pricing");
  const plus = page.locator(".pricing-card").filter({ has: page.getByRole("heading", { name: "Plus", exact: true }) });
  await plus.getByRole("button", { name: "Try Plus demo" }).click();
  await expect(plus.getByRole("button", { name: "Active demo tier" })).toBeVisible();
  await page.goto("/scope");
  await expect(page.locator("tbody tr")).toHaveCount(7);
  await page.goto("/capacity");
  await expect(page.getByLabel("Team size", { exact: true })).toBeDisabled();
  await page.goto("/pricing");
  const pro = page.locator(".pricing-card").filter({ has: page.getByRole("heading", { name: "Pro", exact: true }) });
  await pro.getByRole("button", { name: "Try Pro demo" }).click();
  await expect(pro.getByRole("button", { name: "Active demo tier" })).toBeVisible();
  await page.goto("/capacity");
  await expect(page.getByLabel("Hours / week", { exact: true })).toBeEnabled();
  await page.getByLabel("Hours / week", { exact: true }).fill("20");
  await page.getByLabel("Team size", { exact: true }).fill("2");
  await page.getByRole("navigation", { name: "Workspace tools" }).getByRole("link", { name: "Reports", exact: true }).click();
  await expect(page.locator(".report-preview")).toContainText("40 hours/week");
  const download = page.waitForEvent("download");
  await page.getByRole("button", { name: "Export CSV" }).click();
  const report = await download;
  expect(report.suggestedFilename()).toBe("marginpilot-report.csv");
  const csv = await readFile((await report.path())!, "utf8");
  expect(csv).toContain('"Weekly productive hours per person","20"');
  expect(csv).toContain('"Team size","2"');
  await page.emulateMedia({ media: "print" });
  await expect(page.locator(".print-report")).toBeVisible();
  await expect(page.getByRole("navigation", { name: "Workspace tools" })).toBeHidden();
  await expect(page.locator(".report-preview")).toBeHidden();
});

test("navigation is accessible on mobile and desktop", async ({ page, isMobile }) => {
  await page.goto("/");
  if (isMobile) {
    const toggle = page.getByRole("button", { name: "Open navigation" });
    await toggle.click();
    await expect(page.getByRole("button", { name: "Close navigation" })).toHaveAttribute("aria-expanded", "true");
    await page.getByRole("navigation", { name: "Mobile navigation" }).getByRole("link", { name: "Reports", exact: true }).click();
    await expect(page.getByRole("navigation", { name: "Mobile navigation" })).toHaveCount(0);
  } else {
    await page.getByRole("navigation", { name: "Main navigation" }).getByRole("link", { name: "Tools", exact: true }).click();
    await page.getByRole("navigation", { name: "Workspace tools" }).getByRole("link", { name: "Reports", exact: true }).click();
  }
  await expect(page).toHaveURL(/\/reports$/);
  await expect(page.getByRole("navigation", { name: "Workspace tools" }).getByRole("link", { name: "Reports", exact: true })).toHaveAttribute("aria-current", "page");
  const horizontalOverflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
  expect(horizontalOverflow).toBe(false);
});
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > tests/engine.cjs
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { calculate, sensitivity, DEFAULTS, isInputs, isScenarios } = require("../.engine-check/engine.js");
test("recommended quote achieves the selected margin after reserved costs", () => {
  for (const tier of ["Free", "Plus", "Pro"]) {
    const r = calculate(DEFAULTS, tier);
    assert.ok(Math.abs(r.profit / r.quote - DEFAULTS.margin / 100) < 1e-10);
    assert.ok(Math.abs(r.quote - r.totalCost - r.profit) < 1e-10);
  }
});
test("Free results ignore locked paid inputs", () => {
  const a = calculate(DEFAULTS, "Free");
  const b = calculate({ ...DEFAULTS, contingency: 50, team: 50, weekly: 80 }, "Free");
  assert.deepEqual(a, b);
});
test("effort overruns reduce profit at a fixed quote", () => {
  const rows = sensitivity(DEFAULTS, "Plus");
  for (let i = 1; i < rows.length; i++) assert.ok(rows[i].profit < rows[i - 1].profit);
  assert.ok(Math.abs(rows.find(r => r.delta === 0).margin - DEFAULTS.margin) < 1e-10);
});
test("capacity changes duration without inflating the project quote", () => {
  const a = calculate(DEFAULTS, "Pro");
  const b = calculate({ ...DEFAULTS, team: 2 }, "Pro");
  assert.equal(a.quote, b.quote); assert.equal(a.weeks / 2, b.weeks);
});
test("unsafe stored inputs and malformed scenarios are rejected", () => {
  assert.equal(isInputs({ ...DEFAULTS, margin: 100 }), false);
  assert.equal(isInputs({ ...DEFAULTS, hours: Infinity }), false);
  assert.equal(isInputs({ ...DEFAULTS, team: 1.5 }), false);
  assert.equal(isScenarios([{ id: "a", name: "Demo", inputs: DEFAULTS, savedAt: "invalid" }]), false);
});
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > tests/serve-static.cjs
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "../out");
const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".json": "application/json", ".txt": "text/plain", ".svg": "image/svg+xml", ".ico": "image/x-icon" };
http.createServer((request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
    const filename = path.resolve(root, "." + pathname);
    if (filename !== root && !filename.startsWith(root + path.sep)) { response.writeHead(403).end(); return; }
    const candidates = [filename, filename + ".html", path.join(filename, "index.html")];
    const file = candidates.find(candidate => fs.existsSync(candidate) && fs.statSync(candidate).isFile());
    if (!file) { response.writeHead(404).end("Not found"); return; }
    response.writeHead(200, { "Content-Type": types[path.extname(file)] || "application/octet-stream" });
    fs.createReadStream(file).pipe(response);
  } catch { response.writeHead(400).end("Bad request"); }
}).listen(4173, "127.0.0.1");
MARGINPILOT_SOURCE

cat <<'MARGINPILOT_SOURCE' > tsconfig.json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": [
      "dom",
      "dom.iterable",
      "esnext"
    ],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "react-jsx",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "paths": {
      "@/*": [
        "./*"
      ]
    }
  },
  "include": [
    "next-env.d.ts",
    "**/*.ts",
    "**/*.tsx",
    ".next/types/**/*.ts",
    ".next/dev/types/**/*.ts"
  ],
  "exclude": [
    "node_modules",
    ".engine-check"
  ]
}
MARGINPILOT_SOURCE

# 4. Install dependencies and verify the application before publishing
npm install
npm test
npm run lint
npm run typecheck
npm run build
npx playwright install --with-deps chromium
npm run test:browser
rm -rf .engine-check

# 5. Commit and push without rewriting repository history
git add .
git commit -m "feat: add MarginPilot dedicated tool pages and shared local workspace"
git branch -M main
git push origin main
echo "System setup successful! Project verified and uploaded to https://github.com/RudraRM/UltimateWebsite-3"
