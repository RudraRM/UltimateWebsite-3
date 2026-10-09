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
