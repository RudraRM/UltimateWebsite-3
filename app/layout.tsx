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
