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
      <AnimatePresence initial={false}>{scenarios.map((scenario, index) => <motion.div layout initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} key={scenario.id} className="scenario"><Button className="scenario-load" aria-label={`Load scenario ${scenario.name}`} disabled={index >= LIMITS[tier]} onClick={() => { setInputs({ ...scenario.inputs }); setName(scenario.name); setNotice(`Loaded ${scenario.name}. All tool pages now use this project at the ${tier} tier.`); }}><span>{scenario.name}</span><span className="mono small muted">{index >= LIMITS[tier] ? "Tier locked" : money(calculate(scenario.inputs, tier).quote)}</span></Button><Button className="icon-btn" aria-label={`Delete ${scenario.name}`} onClick={() => { setScenarios(current => current.filter(item => item.id !== scenario.id)); setNotice(`Deleted ${scenario.name}.`); }}><Trash2 size={14} /></Button></motion.div>)}</AnimatePresence>
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
