#!/bin/bash
set -Eeuo pipefail
trap 'echo "Setup failed at line $LINENO; no success is being claimed." >&2' ERR

# Requires Node.js >=20.9, npm, git, and GitHub push access.
# Replaces the repository application; preserves Git history. Never force-pushes.
for tool in node npm npx git; do command -v "$tool" >/dev/null || { echo "Missing: $tool" >&2; exit 1; }; done
node -e 'const [a,b]=process.versions.node.split(".").map(Number); if(a<20||(a===20&&b<9)) process.exit(1)'

# 1. Clean and initialize target repository workspace
rm -rf -- monetized-app
git clone https://github.com/RudraRM/UltimateWebsite-3.git monetized-app
cd monetized-app
git var GIT_AUTHOR_IDENT >/dev/null
git var GIT_COMMITTER_IDENT >/dev/null
# create-next-app refuses an occupied directory. Retain only repository metadata.
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf -- {} +

# 2. Force bootstrap a clean Next.js application structure
npx create-next-app@latest . --ts --tailwind --eslint --app --no-src-dir --use-npm --import-alias="@/*" --skip-install --yes --disable-git

# 3. Inject missing modern front-end dependencies
npm install framer-motion lucide-react
mkdir -p context components lib tests

cat <<'EOF' > lib/engine.ts
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
EOF

# 4. Generate Core Global State (Tier Management)
cat <<'EOF' > context/TierContext.tsx
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
EOF

cat <<'EOF' > lib/useLocalState.ts
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
EOF

# 5. Build Comprehensive Shared Component Library
cat <<'EOF' > components/Primitives.tsx
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
EOF

cat <<'EOF' > components/Header.tsx
"use client";
import { motion, AnimatePresence } from "framer-motion";
import { Command, Sun, Moon, ArrowUpRight } from "lucide-react";
import { useTier } from "@/context/TierContext";
import { Button } from "./Primitives";
export default function Header() {
  const { tier, theme, toggleTheme } = useTier();
  return <motion.header initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="topbar">
    <div className="container nav">
      <a href="#" className="brand" aria-label="MarginPilot home"><Command size={23} aria-hidden="true" /> MarginPilot<span className="mono muted">/</span></a>
      <nav aria-label="Main navigation" className="navlinks"><a href="#features">Features</a><a href="#pricing">Pricing</a><a href="#workspace">Workspace</a></nav>
      <div className="row"><span className="badge"><AnimatePresence mode="wait"><motion.span key={tier} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>{tier} demo</motion.span></AnimatePresence></span><Button className="icon-btn" onClick={toggleTheme} aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} theme`}>{theme === "dark" ? <Sun size={17} /> : <Moon size={17} />}</Button><a className="btn navcta" href="#workspace">Open app <ArrowUpRight size={15} /></a></div>
    </div>
  </motion.header>;
}
EOF

cat <<'EOF' > components/Hero.tsx
"use client";
import { motion } from "framer-motion";
import { ArrowUpRight, ArrowRight, ShieldCheck } from "lucide-react";
import { Reveal } from "./Primitives";
export default function Hero() {
  return <Reveal className="container hero">
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ staggerChildren: 0.12 }}>
      <div className="eyebrow"><span className="status-dot" /> INDEPENDENT WORK. INTELLIGENT PRICING.</div>
      <motion.h1 initial={{ opacity: 0, y: 18 }} animate={{ opacity: 1, y: 0 }}>Good work.<br /><span className="muted">Better margins.</span></motion.h1>
      <motion.p className="hero-copy" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.15 }}>Turn your next project into a profitable decision. Model the quote, stress-test the scope, and see what your time is really worth.</motion.p>
      <div className="row wrap hero-actions"><motion.a href="#workspace" className="btn primary" whileHover={{ scale: 1.025 }} whileTap={{ scale: 0.98 }}>Calculate my quote <ArrowUpRight size={17} /></motion.a><a href="#pricing" className="text-link">Explore plans <ArrowRight size={15} /></a></div>
      <p className="small muted row"><ShieldCheck size={15} /> No account. No uploads. Your numbers stay in this browser.</p>
    </motion.div>
    <motion.div className="terminal" initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} whileHover={{ y: -3 }}>
      <div className="terminal-bar"><div className="row dots"><i /><i /><i /></div><span className="mono small">quote.engine / example</span><span className="badge">LOCAL</span></div>
      <div className="terminal-body mono"><p className="muted">$ marginpilot model --project website</p><p><span className="muted">01 /</span> Labor + expenses + overhead <b>$3,100</b></p><p><span className="muted">02 /</span> Target profit margin <b>35%</b></p><div className="terminal-result"><span className="small muted">RECOMMENDED QUOTE</span><strong>$4,769</strong><span className="accent small">$1,669 modeled profit · Free calculation</span></div><div className="row small muted"><span className="status-dot" /> Ready to calculate your project<span className="cursor">▍</span></div></div>
    </motion.div>
    <div className="hero-stats"><div><b>100%</b><span>Browser-side calculations</span></div><div><b>0</b><span>External API calls</span></div><div><b>3</b><span>Levels of decision support</span></div><div><b>Your data</b><span>Stored on your device</span></div></div>
  </Reveal>;
}
EOF

cat <<'EOF' > components/BentoFeatures.tsx
"use client";
import { motion } from "framer-motion";
import { ArrowUpRight, ChartNoAxesCombined, Layers, LockKeyhole, SlidersHorizontal } from "lucide-react";
import { Reveal } from "./Primitives";
const features = [
  { icon: SlidersHorizontal, label: "01 / QUOTE INTELLIGENCE", title: "Stop pricing on instinct.", copy: "Account for labor, direct expenses, and project overhead. Set a real profit margin, rather than confusing margin with markup.", tag: "Every plan", wide: true },
  { icon: ChartNoAxesCombined, label: "02 / SCOPE SENSITIVITY", title: "See the cost of ‘one more thing.’", copy: "Hold your quote fixed and model effort overruns from −20% to +40%. Know when a good project becomes a bad deal.", tag: "Plus + Pro", wide: false },
  { icon: Layers, label: "03 / CAPACITY PLANNING", title: "A business, beyond one quote.", copy: "Model team capacity and project duration. Estimate annual profit under an explicit 48-week, fully utilized planning assumption.", tag: "Pro", wide: false },
  { icon: LockKeyhole, label: "04 / PRIVATE BY DESIGN", title: "Your client numbers stay yours.", copy: "Save scenarios locally, compare decisions, and export a client-ready cost summary. No accounts, trackers, cloud sync, or remote computation.", tag: "Local-first", wide: true },
];
export default function BentoFeatures() {
  return <Reveal id="features" className="container section"><div className="section-heading"><div><p className="eyebrow">BUILT FOR PEOPLE WHO SELL THEIR EXPERTISE</p><h2>Less guesswork.<br /><span className="muted">More room to grow.</span></h2></div><p className="muted">One focused workspace.<br />The numbers behind your next yes.</p></div><div className="bento">{features.map((feature, index) => <motion.a href="#workspace" key={feature.title} className={`panel feature ${feature.wide ? "wide" : ""}`} initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }} transition={{ delay: index * 0.06 }} whileHover={{ y: -4 }}><div className="between"><feature.icon size={24} aria-hidden="true" /><ArrowUpRight className="muted" size={18} /></div><p className="mono small muted">{feature.label}</p><h3>{feature.title}</h3><p className="muted">{feature.copy}</p><span className="badge">{feature.tag}</span></motion.a>)}</div></Reveal>;
}
EOF

cat <<'EOF' > components/PricingMatrix.tsx
"use client";
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
  return <Reveal id="pricing" className="container section"><div className="section-heading"><div><p className="eyebrow">A PLAN FOR YOUR NEXT STAGE</p><h2>Find your margin.<br /><span className="muted">Then protect it.</span></h2></div><p className="small muted">Illustrative monthly pricing in USD.<br />Try every tier. No payment is collected.</p></div><div className="pricing-grid">{plans.map(plan => <motion.article layout className={`panel pricing-card ${plan.name === tier ? "selected" : ""}`} key={plan.name} whileHover={{ y: -4 }}><div className="between"><h3>{plan.name}</h3>{plan.name === "Plus" && <span className="badge accent">SCOPE CONTROL</span>}</div><p className="muted small">{plan.description}</p><div className="price">${plan.price}<span className="muted small"> / month</span></div><Button disabled={!ready} aria-pressed={plan.name === tier} className={plan.name === tier ? "primary full" : "full"} onClick={() => selectTier(plan.name)}>{plan.name === tier ? "Active demo tier" : `Try ${plan.name} demo`}<ArrowUpRight size={16} /></Button><ul>{plan.features.map(item => <li key={item}><Check size={15} className="accent" />{item}</li>)}</ul></motion.article>)}</div><p className="small muted">Demo access is stored locally and can be changed at any time. Saved scenarios are kept when you switch tiers; access follows your current plan.</p></Reveal>;
}
EOF

cat <<'EOF' > components/SaaSAppWorkspace.tsx
"use client";
import { useId, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { ArrowUpRight, Download, LockKeyhole, Save, Trash2, Printer, RotateCcw } from "lucide-react";
import { useTier } from "@/context/TierContext";
import { useLocalState } from "@/lib/useLocalState";
import { BOUNDS, DEFAULTS, LIMITS, calculate, sensitivity, money, isInputs, isScenarios, downloadCSV, type Inputs, type Scenario } from "@/lib/engine";
import { Button, Reveal } from "./Primitives";
const presets: { name: string; inputs: Inputs }[] = [
  { name: "Website", inputs: DEFAULTS },
  { name: "Brand sprint", inputs: { ...DEFAULTS, hours: 24, rate: 90, expenses: 100, overhead: 200, margin: 40 } },
  { name: "Retainer", inputs: { ...DEFAULTS, hours: 60, rate: 75, expenses: 150, overhead: 500, margin: 30 } },
];
function Field({ label, value, field, suffix = "", locked = false, onChange }: { label: string; value: number; field: keyof Inputs; suffix?: string; locked?: boolean; onChange: (key: keyof Inputs, value: number) => void }) {
  const id = useId(); const [min, max, step] = BOUNDS[field];
  return <div className={`field ${locked ? "locked-field" : ""}`}><div className="between"><label htmlFor={id}>{label}</label>{locked && <LockKeyhole size={13} aria-label="Requires a higher tier" />}</div><div className="input-shell"><input id={id} type="number" min={min} max={max} step={step} disabled={locked} value={value} onChange={event => { const n = event.target.valueAsNumber; if (Number.isFinite(n)) onChange(field, Math.min(max, Math.max(min, field === "team" ? Math.round(n) : n))); }} /><span className="mono muted small">{suffix}</span></div><input type="range" aria-label={`${label} slider`} min={min} max={max} step={step} disabled={locked} value={value} onChange={event => onChange(field, Number(event.target.value))} /></div>;
}
function Upgrade({ plan, children }: { plan: "Plus" | "Pro"; children: React.ReactNode }) {
  const { selectTier } = useTier();
  return <motion.div className="upgrade" initial={{ opacity: 0 }} animate={{ opacity: 1 }}><LockKeyhole size={18} /><div><b>{plan} decision tools</b><p className="small muted">{children}</p></div><Button onClick={() => selectTier(plan)}>Try {plan}<ArrowUpRight size={14} /></Button></motion.div>;
}
export default function SaaSAppWorkspace() {
  const { tier, ready, storageOK } = useTier();
  const [inputs, setInputs, inputsReady, inputsOK] = useLocalState<Inputs>("marginpilot:inputs:v1", DEFAULTS, isInputs);
  const [scenarios, setScenarios, scenariosReady, scenariosOK] = useLocalState<Scenario[]>("marginpilot:scenarios:v1", [], isScenarios);
  const [name, setName] = useState("My next project");
  const [tab, setTab] = useState<"quote" | "risk" | "capacity">("quote");
  const [notice, setNotice] = useState("");
  const [compareId, setCompareId] = useState("");
  const plus = tier !== "Free"; const pro = tier === "Pro";
  const active = ready && inputsReady && scenariosReady;
  const result = calculate(inputs, tier); const rows = sensitivity(inputs, tier);
  const accessible = scenarios.slice(0, LIMITS[tier]);
  const compare = plus ? accessible.find(s => s.id === compareId) : undefined;
  const compared = compare ? calculate(compare.inputs, tier) : undefined;
  function change(key: keyof Inputs, value: number) { setInputs(current => ({ ...current, [key]: value })); }
  function save() {
    if (!active) return;
    if (scenarios.length >= LIMITS[tier]) { setNotice(`Your ${tier} plan allows ${LIMITS[tier]} saved scenarios. Delete a scenario or try a higher tier.`); return; }
    setScenarios(current => [...current, { id: crypto.randomUUID(), name: name.trim() || "Untitled project", inputs: { ...inputs }, savedAt: new Date().toISOString() }]);
    setNotice("Scenario saved in this browser. It includes your current inputs.");
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
      [], ["Effort change percent", "Profit at fixed quote", "Margin percent"], ...rows.map(r => [r.delta, Number(r.profit.toFixed(2)), Number(r.margin.toFixed(2))]),
    ], "marginpilot-report.csv");
    setNotice("CSV report downloaded.");
  }
  return <Reveal id="workspace" className="container section workspace-section"><div className="section-heading"><div><p className="eyebrow">THE WORKSPACE / NO SIGN-UP REQUIRED</p><h2>Make the numbers<br /><span className="muted">work for you.</span></h2></div><span className="badge">{tier.toUpperCase()} DEMO · USD</span></div>
    <div className="panel workspace"><div className="workspace-toolbar between"><div className="row"><span className="status-dot" /><span className="mono small">marginpilot / local workspace</span></div><Button onClick={() => { setInputs({ ...DEFAULTS }); setNotice("Inputs reset. Saved scenarios are retained."); }} disabled={!active} className="small"><RotateCcw size={14} />Reset inputs</Button></div>
      {(!storageOK || !inputsOK || !scenariosOK) && <p className="storage-warning" role="status">Browser storage is unavailable or contained invalid data. Calculations still work; changes may only last for this session.</p>}
      <fieldset className="workspace-grid" disabled={!active} aria-busy={!active}><legend className="sr-only">Project pricing workspace</legend><motion.aside layout className="input-panel"><div className="between"><h3>Project inputs</h3><span className="small muted">01—08</span></div><label className="small muted" htmlFor="project-name">Project name</label><input id="project-name" className="name-input" maxLength={60} value={name} onChange={e => setName(e.target.value)} /><div className="row wrap presets">{presets.map(p => <Button className="small" key={p.name} onClick={() => { setInputs({ ...p.inputs }); setName(p.name); setNotice(`${p.name} preset loaded.`); }}>{p.name}</Button>)}</div>
        <Field label="Estimated effort" value={inputs.hours} field="hours" suffix="hrs" onChange={change} /><Field label="Internal hourly cost" value={inputs.rate} field="rate" suffix="USD/hr" onChange={change} /><p className="small muted helper">Use your cost of labor, not your client billing rate.</p><Field label="Direct expenses" value={inputs.expenses} field="expenses" suffix="USD" onChange={change} /><Field label="Allocated project overhead" value={inputs.overhead} field="overhead" suffix="USD" onChange={change} /><Field label="Target profit margin" value={inputs.margin} field="margin" suffix="%" onChange={change} /><Field label="Contingency reserve" value={plus ? inputs.contingency : 0} field="contingency" suffix={plus ? "%" : "Plus"} locked={!plus} onChange={change} /><div className="two-col"><Field label="Hours / week" value={pro ? inputs.weekly : 30} field="weekly" suffix={pro ? "hrs" : "Pro"} locked={!pro} onChange={change} /><Field label="Team size" value={pro ? inputs.team : 1} field="team" suffix={pro ? "people" : "Pro"} locked={!pro} onChange={change} /></div><Button className="primary full" onClick={save}><Save size={16} />Save scenario ({scenarios.length}/{LIMITS[tier]})</Button>
      </motion.aside><div className="result-panel"><div className="tabs" role="tablist" aria-label="Analysis view">{(["quote", "risk", "capacity"] as const).map(t => <Button key={t} role="tab" id={`tab-${t}`} aria-selected={tab === t} aria-controls={`panel-${t}`} tabIndex={tab === t ? 0 : -1} onKeyDown={event => { const tabs = ["quote", "risk", "capacity"] as const; const index = tabs.indexOf(t); let next = index; if (event.key === "ArrowRight") next = (index + 1) % 3; else if (event.key === "ArrowLeft") next = (index + 2) % 3; else if (event.key === "Home") next = 0; else if (event.key === "End") next = 2; else return; event.preventDefault(); setTab(tabs[next]); document.getElementById(`tab-${tabs[next]}`)?.focus(); }} className={tab === t ? "tab active" : "tab"} onClick={() => setTab(t)}>{t === "quote" ? "Quote" : t === "risk" ? "Scope risk" : "Capacity"}{((t === "risk" && !plus) || (t === "capacity" && !pro)) && <LockKeyhole size={12} />}</Button>)}</div>
        <AnimatePresence mode="wait"><motion.div key={tab} role="tabpanel" id={`panel-${tab}`} aria-labelledby={`tab-${tab}`} tabIndex={0} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.15 }}>
          {tab === "quote" && <><div className="quote-block"><p className="eyebrow">YOUR RECOMMENDED PROJECT QUOTE</p><motion.div layout className="quote-number">{money(result.quote)}</motion.div><p className="muted">Built around a {inputs.margin}% target margin{plus ? ` and ${inputs.contingency}% contingency` : ""}.</p></div><div className="metric-grid"><motion.div layout className="mini-card"><p className="small muted">Modeled profit</p><strong className="accent">{money(result.profit)}</strong></motion.div><motion.div layout className="mini-card"><p className="small muted">Effective billing rate</p><strong>{money(result.hourly)}<span className="small muted"> / hr</span></strong></motion.div></div><div className="breakdown"><h4>Every dollar, accounted for.</h4>{[["Labor", inputs.hours * inputs.rate], ["Direct expenses", inputs.expenses], ["Project overhead", inputs.overhead], ["Contingency reserve", result.reserve], ["Target profit", result.profit]].map(([label, value]) => <div className="between ledger-row" key={label}><span className="muted">{label}</span><span className="mono">{money(Number(value))}</span></div>)}<div className="stacked-bar" aria-label="Quote composition">{[inputs.hours * inputs.rate, inputs.expenses, inputs.overhead, result.reserve, result.profit].map((n, i) => <motion.span key={i} animate={{ width: `${n / result.quote * 100}%` }} style={{ background: `var(--chart-${i})` }} />)}</div><p className="small muted">Quote = (labor + expenses + overhead + reserve) ÷ (1 − margin). Profit is after the reserve; taxes and unmodeled costs are excluded.</p></div>{!plus && <Upgrade plan="Plus">Build in a contingency buffer and check what happens when the scope grows.</Upgrade>}</>}
          {tab === "risk" && (plus ? <div className="analysis"><p className="eyebrow">FIXED QUOTE / CHANGING EFFORT</p><h3>What if the work expands?</h3><p className="muted small">The quote stays at {money(result.quote)}. Labor and its contingency reserve change with effort; other costs stay fixed.</p><div className="risk-chart" role="img" aria-label="Profit margin by effort change; exact values are listed below">{rows.map(r => <div className="risk-column" key={r.delta}><span className={r.margin < 0 ? "danger small" : "small"}>{r.margin.toFixed(0)}%</span><div className="bar-track"><motion.div className={r.margin < 0 ? "risk-bar negative" : "risk-bar"} initial={{ height: 0 }} animate={{ height: `${Math.min(100, Math.max(3, Math.abs(r.margin)))}%` }} /></div><span className="small muted">{r.delta > 0 ? "+" : ""}{r.delta}%</span></div>)}</div><table><caption className="sr-only">Scope sensitivity results</caption><thead><tr><th>Effort change</th><th>Profit</th><th>Margin</th></tr></thead><tbody>{rows.map(r => <tr key={r.delta}><td>{r.delta > 0 ? "+" : ""}{r.delta}%</td><td className={r.profit < 0 ? "danger" : ""}>{money(r.profit)}</td><td>{r.margin.toFixed(1)}%</td></tr>)}</tbody></table></div> : <Upgrade plan="Plus">Unlock a seven-point scope stress test. See exactly where overruns erode your margin.</Upgrade>)}
          {tab === "capacity" && (pro ? <div className="analysis"><p className="eyebrow">CAPACITY / 48-WEEK PLANNING MODEL</p><h3>Turn a project into a plan.</h3><div className="metric-grid capacity-metrics">{[["Project duration", `${result.weeks.toFixed(1)} weeks`], ["Team capacity", `${inputs.weekly * inputs.team} hrs/week`], ["Equivalent projects / year", result.annualProjects.toFixed(1)], ["Modeled annual profit", money(result.annualProfit)]].map(([label, value]) => <motion.div layout key={label} className="mini-card"><p className="small muted">{label}</p><strong>{value}</strong></motion.div>)}</div><p className="small muted">Assumes 48 working weeks, full utilization, parallelizable work, and repeated projects with the same cost and scope. This is a planning model, not a revenue forecast. Adjust productive hours to account for selling, admin, and time off.</p></div> : <Upgrade plan="Pro">Adjust productive hours and team size to model delivery time and annual profit.</Upgrade>)}
        </motion.div></AnimatePresence>
        <div className="saved"><div className="between"><h4>Saved scenarios</h4><span className="small muted">{scenarios.length}/{LIMITS[tier]}</span></div>{scenarios.length === 0 && <p className="small muted">Save your first project to revisit the decision.</p>}<AnimatePresence initial={false}>{scenarios.map((s, index) => <motion.div layout initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} key={s.id} className="scenario"><Button className="scenario-load" disabled={index >= LIMITS[tier]} onClick={() => { setInputs({ ...s.inputs }); setName(s.name); setNotice(`Loaded ${s.name}. Results use the current ${tier} tier.`); }}><span>{s.name}</span><span className="mono small muted">{index >= LIMITS[tier] ? "Tier locked" : money(calculate(s.inputs, tier).quote)}</span></Button><Button className="icon-btn" aria-label={`Delete ${s.name}`} onClick={() => { setScenarios(current => current.filter(item => item.id !== s.id)); setNotice(`Deleted ${s.name}.`); }}><Trash2 size={14} /></Button></motion.div>)}</AnimatePresence>{plus && accessible.length > 0 && <div className="comparison"><label htmlFor="compare" className="small muted">Compare current quote with a saved scenario</label><select id="compare" value={compare?.id || ""} onChange={e => setCompareId(e.target.value)}><option value="">Choose a scenario</option>{accessible.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}</select>{compared && <p className="small">Quote difference: <b>{money(result.quote - compared.quote)}</b> · Profit difference: <b>{money(result.profit - compared.profit)}</b><span className="muted"> (current minus saved, at {tier} settings)</span></p>}</div>}</div>
        <div className="export-row row wrap"><Button disabled={!pro} onClick={exportReport}><Download size={15} />Export CSV {!pro && <LockKeyhole size={12} />}</Button><Button disabled={!pro} onClick={() => { if (pro) window.print(); }}><Printer size={15} />Print report {!pro && <LockKeyhole size={12} />}</Button>{!pro && <span className="small muted">Reports are included in Pro.</span>}</div>
        <p className="notice small" role="status" aria-live="polite">{!active ? "Restoring browser workspace…" : notice || "All calculations run locally. No data leaves this workspace."}</p>
      </div></fieldset>
    </div>
    <article className="print-report"><h1>MarginPilot project report</h1><h2>{name}</h2><p>USD · {tier} demo tier</p><p>Recommended quote: {money(result.quote)} · Modeled profit: {money(result.profit)}</p><p>Effort: {inputs.hours} hours · Labor cost: {money(inputs.rate)}/hour · Expenses: {money(inputs.expenses)} · Overhead: {money(inputs.overhead)}</p><p>Target margin: {inputs.margin}% · Reserve: {money(result.reserve)} · Project duration: {result.weeks.toFixed(1)} weeks</p><p>Annual modeled profit: {money(result.annualProfit)}. Assumes 48 working weeks, full utilization, and identical repeated projects. Excludes taxes and unmodeled costs.</p><table><thead><tr><th>Effort change</th><th>Profit</th><th>Margin</th></tr></thead><tbody>{rows.map(r => <tr key={r.delta}><td>{r.delta}%</td><td>{money(r.profit)}</td><td>{r.margin.toFixed(1)}%</td></tr>)}</tbody></table></article>
  </Reveal>;
}
EOF

cat <<'EOF' > components/Footer.tsx
"use client";
import { motion } from "framer-motion";
import { ArrowUpRight, Command } from "lucide-react";
import { useTier } from "@/context/TierContext";
import { Button } from "./Primitives";
export default function Footer() {
  const { tier, selectTier, ready } = useTier();
  return <><motion.footer initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }} className="container footer"><div className="between wrap"><a href="#" className="brand"><Command size={20} />MarginPilot</a><span className="small muted">Built for better business decisions.</span></div><div className="footer-details small muted"><p>Privacy: inputs and scenarios are stored only in this browser. Clearing site storage removes them. No analytics, cloud storage, or external APIs are used.</p><p>Terms: this is an illustrative planning tool. Results depend on your assumptions. Demo tiers do not process payments or provide secure entitlements.</p></div></motion.footer><motion.div className="plan-dock" initial={{ opacity: 0 }} animate={{ opacity: 1 }}><div className="container between"><span className="small"><b>{tier}</b> demo <span className="muted dock-label">/ your private pricing workspace</span></span><div className="row"><a href="#pricing" className="small muted">All plans</a>{tier !== "Pro" && <Button disabled={!ready} className="primary small" onClick={() => selectTier(tier === "Free" ? "Plus" : "Pro")}>Try {tier === "Free" ? "Plus" : "Pro"}<ArrowUpRight size={14} /></Button>}{tier === "Pro" && <a className="btn small" href="#workspace">Open workspace<ArrowUpRight size={14} /></a>}</div></div></motion.div></>;
}
EOF

# 6. Tie App Router Pages Together
cat <<'EOF' > app/layout.tsx
import type { Metadata } from "next";
import { TierProvider } from "@/context/TierContext";
import { MotionShell } from "@/components/Primitives";
import "./globals.css";
export const metadata: Metadata = {
  title: "MarginPilot — Good work. Better margins.",
  description: "A private, browser-based pricing planner for freelancers and agencies. Calculate profitable quotes, stress-test scope, and plan capacity without external APIs.",
};
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en" data-theme="dark"><body><a className="skip-link" href="#workspace">Skip to workspace</a><TierProvider><MotionShell>{children}</MotionShell></TierProvider></body></html>;
}
EOF

cat <<'EOF' > app/page.tsx
import Header from "@/components/Header";
import Hero from "@/components/Hero";
import BentoFeatures from "@/components/BentoFeatures";
import PricingMatrix from "@/components/PricingMatrix";
import SaaSAppWorkspace from "@/components/SaaSAppWorkspace";
import Footer from "@/components/Footer";
export default function Home() {
  return <><Header /><main><Hero /><BentoFeatures /><PricingMatrix /><SaaSAppWorkspace /></main><Footer /></>;
}
EOF

cat <<'EOF' > app/globals.css
@import "tailwindcss";
@theme inline { --color-background: var(--bg); --color-foreground: var(--fg); --font-sans: Arial, Helvetica, sans-serif; --font-mono: "SFMono-Regular", Consolas, monospace; }
:root { color-scheme: dark; --bg:#0a0a0b; --fg:#eeeef0; --muted:#a2a2aa; --panel:#111113; --surface:#19191c; --line:#2b2b30; --accent:#b8ef92; --accent-ink:#1a2811; --danger:#ff9e9e; --chart-0:#555b61; --chart-1:#727980; --chart-2:#9299a0; --chart-3:#899f74; --chart-4:#b8ef92; }
:root[data-theme="light"] { color-scheme:light; --bg:#fafaf9; --fg:#18181b; --muted:#626269; --panel:#fff; --surface:#f0f0ef; --line:#d8d8da; --accent:#39651d; --accent-ink:#fff; --danger:#b42323; --chart-4:#39651d; }
* { box-sizing:border-box; } html { scroll-behavior:smooth; scroll-padding-top:96px; } body { margin:0; background:var(--bg); color:var(--fg); font-family:Arial,Helvetica,sans-serif; -webkit-font-smoothing:antialiased; padding-bottom:76px; } ::selection { background:var(--accent); color:var(--accent-ink); } a { color:inherit; text-decoration:none; } button,input,select { font:inherit; } button,a,input,select { -webkit-tap-highlight-color:transparent; } button { cursor:pointer; } button:disabled { cursor:not-allowed; opacity:.48; } :focus-visible { outline:2px solid var(--accent); outline-offset:4px; } h1,h2,h3,h4,p { margin-top:0; } h1,h2 { letter-spacing:-.065em; line-height:1.05; font-weight:600; } h1 { font-size:clamp(3.4rem,7.2vw,6.3rem); margin-bottom:24px; } h2 { font-size:clamp(2.3rem,4.6vw,3.9rem); margin-bottom:0; } h3 { font-size:1.2rem; letter-spacing:-.035em; font-weight:600; } h4 { font-size:.95rem; font-weight:600; } p { line-height:1.65; } .container { width:min(1120px,calc(100% - 48px)); margin-inline:auto; } .row { display:flex; align-items:center; gap:12px; } .wrap { flex-wrap:wrap; } .between { display:flex; align-items:center; justify-content:space-between; gap:16px; } .muted { color:var(--muted); } .accent { color:var(--accent); } .danger { color:var(--danger); } .small { font-size:.78rem; } .mono { font-family:"SFMono-Regular",Consolas,monospace; } .eyebrow { font-family:"SFMono-Regular",Consolas,monospace; font-size:.66rem; letter-spacing:.09em; color:var(--muted); margin-bottom:22px; display:flex; align-items:center; gap:9px; line-height:1.6; } .badge { display:inline-flex; align-items:center; border:1px solid var(--line); background:var(--surface); border-radius:5px; padding:5px 8px; font-family:Consolas,monospace; font-size:.63rem; white-space:nowrap; } .btn { display:inline-flex; align-items:center; justify-content:center; gap:9px; padding:11px 16px; min-height:42px; border:1px solid var(--line); border-radius:7px; background:var(--surface); color:var(--fg); font-weight:500; font-size:.83rem; line-height:1.25; } .btn:hover { border-color:var(--muted); } .btn.primary { background:var(--accent); color:var(--accent-ink); border-color:var(--accent); } .btn.small { font-size:.74rem; padding:9px 12px; } .btn.full { width:100%; } .icon-btn { width:40px; height:40px; padding:0; } .text-link { display:inline-flex; align-items:center; gap:9px; font-size:.83rem; } .text-link:hover { color:var(--accent); } .status-dot { width:6px; height:6px; border-radius:50%; background:var(--accent); flex-shrink:0; } .topbar { position:sticky; top:0; z-index:30; border-bottom:1px solid var(--line); background:var(--bg); } .nav { min-height:76px; display:flex; align-items:center; justify-content:space-between; gap:20px; } .brand { display:flex; align-items:center; gap:10px; font-size:1rem; font-weight:600; letter-spacing:-.035em; } .navlinks { display:flex; gap:26px; color:var(--muted); font-size:.8rem; } .navlinks a:hover { color:var(--fg); } .hero { padding-top:100px; display:grid; grid-template-columns:1.1fr 1fr; gap:48px; align-items:center; } .hero-copy { max-width:450px; font-size:1rem; color:var(--muted); } .hero-actions { margin:28px 0 18px; gap:24px; } .terminal { border:1px solid var(--line); border-radius:10px; background:var(--panel); overflow:hidden; box-shadow:0 20px 80px #00000012; } .terminal-bar { padding:13px 16px; border-bottom:1px solid var(--line); display:flex; align-items:center; justify-content:space-between; gap:8px; color:var(--muted); } .dots { gap:5px; } .dots i { width:7px; height:7px; border-radius:50%; background:var(--line); } .terminal-body { padding:26px; font-size:.75rem; } .terminal-body p { display:flex; gap:12px; align-items:center; margin-bottom:18px; } .terminal-body b { margin-left:auto; white-space:nowrap; font-weight:400; } .terminal-result { padding:25px 0; margin:24px 0; border-top:1px dashed var(--line); border-bottom:1px dashed var(--line); display:flex; flex-direction:column; gap:12px; } .terminal-result strong { font-family:Arial,sans-serif; font-size:3.1rem; font-weight:500; letter-spacing:-.07em; } .cursor { margin-left:auto; color:var(--accent); } .hero-stats { grid-column:1/-1; display:grid; grid-template-columns:repeat(4,1fr); gap:24px; border-top:1px solid var(--line); border-bottom:1px solid var(--line); padding:30px 0; margin-top:28px; } .hero-stats b { display:block; font-size:1.25rem; letter-spacing:-.04em; font-weight:500; margin-bottom:6px; } .hero-stats span { color:var(--muted); font-size:.73rem; } .section { padding-top:104px; } .section-heading { display:flex; justify-content:space-between; align-items:flex-end; gap:28px; margin-bottom:36px; } .section-heading>p { font-size:.84rem; margin:0; } .panel { border:1px solid var(--line); background:var(--panel); border-radius:10px; } .bento { display:grid; grid-template-columns:repeat(3,1fr); gap:14px; } .feature { padding:30px; min-height:250px; display:flex; flex-direction:column; gap:12px; } .feature.wide { grid-column:span 2; } .feature:hover { border-color:var(--muted); background:var(--surface); } .feature>.between { margin-bottom:16px; } .feature p,.feature h3 { margin-bottom:0; } .feature .badge { align-self:flex-start; margin-top:auto; } .feature p:not(.mono) { font-size:.86rem; max-width:460px; } .feature h3 { font-size:1.4rem; } .pricing-grid { display:grid; grid-template-columns:repeat(3,1fr); gap:14px; margin-bottom:18px; } .pricing-card { padding:28px; } .pricing-card.selected { border-color:var(--accent); } .pricing-card h3 { margin:0; } .pricing-card>.small { margin:16px 0; } .price { font-size:3rem; font-weight:500; letter-spacing:-.06em; margin:26px 0; } .price span { letter-spacing:0; } .pricing-card ul { list-style:none; padding:0; margin:28px 0 0; display:flex; flex-direction:column; gap:15px; } .pricing-card li { display:flex; align-items:flex-start; gap:10px; font-size:.77rem; color:var(--muted); } .pricing-card li svg { flex-shrink:0; } .workspace { overflow:hidden; } .workspace-toolbar { padding:16px 24px; border-bottom:1px solid var(--line); background:var(--surface); } .workspace-grid { display:grid; grid-template-columns:340px minmax(0,1fr); border:0; padding:0; margin:0; min-width:0; } .input-panel { border-right:1px solid var(--line); padding:28px; min-width:0; } .input-panel h3 { margin:0; } .input-panel>.between { margin-bottom:22px; } .name-input,select { width:100%; padding:11px 12px; border:1px solid var(--line); border-radius:6px; background:var(--bg); color:var(--fg); font-size:.82rem; margin-top:8px; } .presets { margin:14px 0 28px; gap:7px; } .presets .btn { font-size:.68rem; min-height:34px; padding:8px 10px; } .field { margin-bottom:22px; } .field label { font-size:.77rem; } .input-shell { display:flex; align-items:center; border:1px solid var(--line); border-radius:6px; margin:9px 0 8px; padding-right:11px; background:var(--bg); } .input-shell:focus-within { border-color:var(--accent); } .input-shell input { width:100%; min-width:0; padding:11px; border:0; background:transparent; color:var(--fg); font-size:.87rem; outline:none; } .input-shell span { white-space:nowrap; } input[type="range"] { width:100%; height:3px; display:block; accent-color:var(--accent); cursor:pointer; } .locked-field { color:var(--muted); } .locked-field input { cursor:not-allowed; } .helper { margin-top:-14px; margin-bottom:24px; font-size:.68rem; } .two-col { display:grid; grid-template-columns:1fr 1fr; gap:12px; } .result-panel { padding:28px; min-width:0; } .tabs { display:flex; gap:8px; padding-bottom:24px; border-bottom:1px solid var(--line); } .btn.tab { background:transparent; border-color:transparent; padding:9px 12px; font-size:.76rem; color:var(--muted); } .btn.tab.active { background:var(--surface); border-color:var(--line); color:var(--fg); } .quote-block { padding:32px 0 26px; } .quote-block .eyebrow { margin-bottom:14px; } .quote-number { font-size:clamp(2.8rem,5vw,4.6rem); letter-spacing:-.07em; line-height:1.1; font-weight:500; overflow-wrap:anywhere; } .quote-block p:last-child { font-size:.78rem; margin:12px 0 0; } .metric-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:12px; } .mini-card { padding:18px; border:1px solid var(--line); border-radius:7px; background:var(--surface); } .mini-card p { margin-bottom:8px; } .mini-card strong { font-size:1.35rem; font-weight:500; letter-spacing:-.04em; overflow-wrap:anywhere; } .breakdown { margin-top:32px; } .ledger-row { padding:10px 0; border-bottom:1px solid var(--line); font-size:.79rem; } .stacked-bar { display:flex; height:7px; border-radius:5px; overflow:hidden; margin:20px 0 14px; } .upgrade { display:flex; align-items:center; gap:14px; padding:20px; border:1px dashed var(--line); border-radius:8px; background:var(--surface); margin:24px 0; } .upgrade>svg { flex-shrink:0; color:var(--accent); } .upgrade b { font-size:.8rem; } .upgrade p { margin:5px 0 0; font-size:.73rem; } .upgrade .btn { margin-left:auto; white-space:nowrap; font-size:.74rem; padding:10px; } .analysis { padding-top:28px; } .analysis h3 { font-size:1.5rem; } .risk-chart { display:flex; gap:10px; margin:30px 0; } .risk-column { flex:1; text-align:center; min-width:0; } .bar-track { height:100px; display:flex; align-items:flex-end; margin:9px 0; background:var(--surface); border-radius:4px; overflow:hidden; } .risk-bar { width:100%; background:var(--accent); border-radius:4px; } .risk-bar.negative { background:var(--danger); } table { width:100%; border-collapse:collapse; font-size:.76rem; } th,td { padding:12px 4px; text-align:left; border-bottom:1px solid var(--line); } th { color:var(--muted); font-weight:400; } th:not(:first-child),td:not(:first-child) { text-align:right; } .capacity-metrics { margin:24px 0; } .saved { margin-top:32px; border-top:1px solid var(--line); padding-top:24px; } .saved h4 { margin:0; } .saved>.small { margin-top:18px; } .scenario { display:flex; align-items:center; gap:8px; margin-top:10px; } .scenario-load { flex:1; min-width:0; display:flex; justify-content:space-between; text-align:left; font-size:.76rem; padding:12px; } .scenario-load span:first-child { overflow:hidden; text-overflow:ellipsis; white-space:nowrap; } .scenario-load span:last-child { flex-shrink:0; } .comparison { margin-top:22px; } .comparison p { margin:12px 0 0; } .export-row { margin-top:26px; gap:10px; } .export-row .btn { font-size:.73rem; } .notice { color:var(--muted); min-height:38px; margin:18px 0 0; } .storage-warning { padding:14px 24px; color:var(--danger); border-bottom:1px solid var(--line); font-size:.8rem; margin:0; } .print-report { display:none; } .footer { padding-block:70px 32px; } .footer-details { margin-top:28px; max-width:750px; } .footer-details p { font-size:.7rem; margin-bottom:10px; } .plan-dock { position:fixed; bottom:0; left:0; right:0; background:var(--bg); border-top:1px solid var(--line); z-index:40; padding:12px 0; } .skip-link { position:fixed; top:10px; left:10px; z-index:100; padding:12px; background:var(--accent); color:var(--accent-ink); transform:translateY(-150%); } .skip-link:focus { transform:translateY(0); }
@media (max-width:950px) { .hero { gap:28px; padding-top:64px; } .navlinks { gap:16px; } .navcta { display:none; } .terminal-body { padding:18px; font-size:.68rem; } .workspace-grid { grid-template-columns:300px minmax(0,1fr); } .input-panel,.result-panel { padding:22px; } .upgrade { flex-wrap:wrap; } .upgrade .btn { margin-left:32px; } .pricing-card { padding:22px; } .pricing-card .badge { font-size:.5rem; } }
@media (max-width:720px) { .container { width:calc(100% - 32px); } .nav { min-height:66px; gap:10px; } .navlinks { display:none; } .brand { font-size:.92rem; } .nav>.row { gap:7px; } .hero { grid-template-columns:1fr; padding-top:55px; gap:32px; } .hero-copy { max-width:100%; } .terminal-body { font-size:.75rem; padding:24px; } .hero-stats { grid-template-columns:1fr 1fr; margin-top:4px; gap:28px; } .section { padding-top:72px; } .section-heading { align-items:flex-start; flex-direction:column; gap:20px; margin-bottom:26px; } .bento { grid-template-columns:1fr; } .feature.wide { grid-column:auto; } .feature { min-height:235px; padding:24px; } .pricing-grid { grid-template-columns:1fr; } .pricing-card { padding:26px; } .pricing-card .badge { font-size:.63rem; } .price { margin:22px 0; } .workspace-toolbar { padding:14px; gap:8px; } .workspace-toolbar .mono { font-size:.62rem; } .workspace-toolbar .btn { font-size:.65rem; padding:8px; } .workspace-grid { grid-template-columns:1fr; } .input-panel { border-right:0; border-bottom:1px solid var(--line); padding:24px; } .result-panel { padding:24px; } .quote-number { font-size:3.5rem; } .plan-dock .dock-label { display:none; } .plan-dock .row { gap:12px; } .footer { padding-top:48px; } .metric-grid { gap:10px; } .mini-card { padding:14px; } .mini-card strong { font-size:1.15rem; } .risk-chart { gap:7px; } .risk-column .small { font-size:.65rem; } }
@media (prefers-reduced-motion:reduce) { html { scroll-behavior:auto; } *,*::before,*::after { animation-duration:.01ms!important; transition-duration:.01ms!important; } }
@media print { :root { color-scheme:light; --bg:#fff; --fg:#111; --muted:#444; --line:#ddd; } body { background:#fff; color:#111; padding:0; } header,.hero,#features,#pricing,.workspace,.workspace-section>.section-heading,footer,.plan-dock,.skip-link { display:none!important; } .workspace-section { padding:0; width:100%; opacity:1!important; transform:none!important; } .print-report { display:block; padding:24px; } .print-report h1 { font-size:2rem; } .print-report h2 { font-size:1.5rem; margin-bottom:20px; } .print-report p { font-size:.85rem; } }
EOF

cat <<'EOF' > next.config.ts
import type { NextConfig } from "next";
const nextConfig: NextConfig = { output: "export", images: { unoptimized: true }, poweredByHeader: false };
export default nextConfig;
EOF

cat <<'EOF' > tests/engine.cjs
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
EOF

node <<'EOF'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.scripts = { ...pkg.scripts, dev: 'next dev', build: 'next build', lint: 'eslint .', typecheck: 'tsc --noEmit', test: 'tsc lib/engine.ts --target ES2020 --module commonjs --skipLibCheck --outDir .engine-check && node --test tests/engine.cjs' };
delete pkg.scripts.start;
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
fs.appendFileSync('.gitignore', '\n.engine-check/\n');
EOF

cat <<'EOF' > README.md
# MarginPilot

A Next.js App Router, TypeScript, Tailwind CSS, and Framer Motion pricing planner.
All computations, scenario storage, CSV generation, and demo tier state run locally.
No runtime API, payment processor, remote font, analytics, or database is required.

## Development

Use Node.js 20.9 or newer. Run `npm ci`, then `npm run dev`.
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

Browser localStorage persists tier, theme, inputs, and scenarios. Data does not sync across devices.
Clearing browser storage deletes it. No payment is collected; prices are illustrative.
Client-side gates are editable by users and are not secure paid entitlements.
Commercial billing and enforceable paid access require a separate trusted billing/licensing design.
The default static output can be distributed as a paid digital product using a separate sales channel.
EOF

# Verify before committing or pushing. No success message on failed checks.
npm test
npm run typecheck
npm run build
rm -rf .engine-check

# 7. Automate Assembly staging, commit, and push back up to GitHub
git add .
git commit -m "feat: autogenerated ultra-premium API-free high-revenue SaaS platform built with Next.js and Framer Motion"
git branch -M main
git push origin main

echo "System setup successful! Project fully compiled and uploaded to https://github.com/RudraRM/UltimateWebsite-3"
