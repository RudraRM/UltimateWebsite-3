import type { Metadata } from "next";
import SaaSAppWorkspace from "@/components/SaaSAppWorkspace";
export const metadata: Metadata = { title: "Saved Scenarios — MarginPilot", description: "Save, load, and compare project scenarios privately in your browser." };
export default function ScenariosPage() { return <SaaSAppWorkspace view="scenarios" />; }
