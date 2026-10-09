import type { Metadata } from "next";
import SaaSAppWorkspace from "@/components/SaaSAppWorkspace";
export const metadata: Metadata = { title: "Quote Calculator — MarginPilot", description: "Calculate a profitable project quote from your labor costs, expenses, overhead, and target margin." };
export default function QuotePage() { return <SaaSAppWorkspace view="quote" />; }
