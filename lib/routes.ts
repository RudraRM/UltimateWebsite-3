export const TOOL_ROUTES = [
  { href: "/quote", view: "quote", label: "Quote", title: "Price the project.", description: "Turn labor, expenses, and overhead into a quote that meets your target margin." },
  { href: "/scope", view: "risk", label: "Scope risk", title: "Protect your margin.", description: "Hold the quote fixed and see how changing effort affects your profit." },
  { href: "/capacity", view: "capacity", label: "Capacity", title: "Plan your capacity.", description: "Model delivery time and annual profit using your team's productive hours." },
  { href: "/scenarios", view: "scenarios", label: "Scenarios", title: "Compare your decisions.", description: "Save, revisit, and compare projects stored privately in this browser." },
  { href: "/reports", view: "reports", label: "Reports", title: "Share the numbers.", description: "Preview your current project and export a CSV or printable report." },
] as const;

export type ToolView = typeof TOOL_ROUTES[number]["view"];
