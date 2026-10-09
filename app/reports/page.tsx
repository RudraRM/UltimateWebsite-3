import type { Metadata } from "next";
import SaaSAppWorkspace from "@/components/SaaSAppWorkspace";
export const metadata: Metadata = { title: "Project Reports — MarginPilot", description: "Preview project economics and export CSV or printable reports with the Pro demo tier." };
export default function ReportsPage() { return <SaaSAppWorkspace view="reports" />; }
