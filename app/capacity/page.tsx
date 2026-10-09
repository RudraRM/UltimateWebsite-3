import type { Metadata } from "next";
import SaaSAppWorkspace from "@/components/SaaSAppWorkspace";
export const metadata: Metadata = { title: "Capacity Planning — MarginPilot", description: "Model team capacity, project duration, and annual profit with local calculations." };
export default function CapacityPage() { return <SaaSAppWorkspace view="capacity" />; }
