import type { Metadata } from "next";
import SaaSAppWorkspace from "@/components/SaaSAppWorkspace";
export const metadata: Metadata = { title: "Scope Risk — MarginPilot", description: "Stress-test project effort and understand its effect on profit at a fixed quote." };
export default function ScopePage() { return <SaaSAppWorkspace view="risk" />; }
