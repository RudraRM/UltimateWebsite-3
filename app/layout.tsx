import type { Metadata } from "next";
import { TierProvider } from "@/context/TierContext";
import { ProjectProvider } from "@/context/ProjectContext";
import { MotionShell } from "@/components/Primitives";
import Header from "@/components/Header";
import Footer from "@/components/Footer";
import "./globals.css";
export const metadata: Metadata = {
  title: "MarginPilot — Good work. Better margins.",
  description: "A private, browser-based pricing planner for freelancers and agencies. Calculate profitable quotes, stress-test scope, and plan capacity without external APIs.",
};
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en" data-theme="dark"><body><a className="skip-link" href="#main-content">Skip to content</a><TierProvider><ProjectProvider><MotionShell><Header /><main id="main-content" tabIndex={-1}>{children}</main><Footer /></MotionShell></ProjectProvider></TierProvider></body></html>;
}
