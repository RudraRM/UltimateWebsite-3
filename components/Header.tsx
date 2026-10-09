"use client";
import { motion, AnimatePresence } from "framer-motion";
import { Command, Sun, Moon, ArrowUpRight } from "lucide-react";
import { useTier } from "@/context/TierContext";
import { Button } from "./Primitives";
export default function Header() {
  const { tier, theme, toggleTheme } = useTier();
  return <motion.header initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="topbar">
    <div className="container nav">
      <a href="#" className="brand" aria-label="MarginPilot home"><Command size={23} aria-hidden="true" /> MarginPilot<span className="mono muted">/</span></a>
      <nav aria-label="Main navigation" className="navlinks"><a href="#features">Features</a><a href="#pricing">Pricing</a><a href="#workspace">Workspace</a></nav>
      <div className="row"><span className="badge"><AnimatePresence mode="wait"><motion.span key={tier} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>{tier} demo</motion.span></AnimatePresence></span><Button className="icon-btn" onClick={toggleTheme} aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} theme`}>{theme === "dark" ? <Sun size={17} /> : <Moon size={17} />}</Button><a className="btn navcta" href="#workspace">Open app <ArrowUpRight size={15} /></a></div>
    </div>
  </motion.header>;
}
