import type { Metadata } from "next";
import PricingMatrix from "@/components/PricingMatrix";
export const metadata: Metadata = { title: "Plans and Pricing — MarginPilot", description: "Compare Free, Plus, and Pro demo plans for local project pricing and analysis." };
export default function PricingPage() { return <PricingMatrix />; }
