"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { Command, Sun, Moon, ArrowUpRight, Menu, X } from "lucide-react";
import { useTier } from "@/context/TierContext";
import { TOOL_ROUTES } from "@/lib/routes";
import { Button } from "./Primitives";

export default function Header() {
  const { tier, theme, toggleTheme } = useTier();
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);
  const links = [...TOOL_ROUTES, { href: "/pricing", label: "Pricing" }];

  return <motion.header initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="topbar">
    <div className="container nav">
      <Link href="/" className="brand" aria-label="MarginPilot home" onClick={() => setMenuOpen(false)}><Command size={23} aria-hidden="true" />MarginPilot</Link>
      <nav aria-label="Main navigation" className="navlinks">
        <Link href="/quote" aria-current={pathname === "/quote" ? "page" : undefined}>Tools</Link>
        <Link href="/pricing" aria-current={pathname === "/pricing" ? "page" : undefined}>Pricing</Link>
      </nav>
      <div className="row">
        <span className="badge"><AnimatePresence mode="wait"><motion.span key={tier} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>{tier} demo</motion.span></AnimatePresence></span>
        <Button className="icon-btn" onClick={toggleTheme} aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} theme`}>{theme === "dark" ? <Sun size={17} /> : <Moon size={17} />}</Button>
        <Link className="btn navcta" href="/quote">Open app<ArrowUpRight size={15} /></Link>
        <Button className="icon-btn mobile-menu-toggle" aria-label={menuOpen ? "Close navigation" : "Open navigation"} aria-expanded={menuOpen} aria-controls="mobile-navigation" onClick={() => setMenuOpen(open => !open)}>{menuOpen ? <X size={18} /> : <Menu size={18} />}</Button>
      </div>
    </div>
    <AnimatePresence>{menuOpen && <motion.nav id="mobile-navigation" aria-label="Mobile navigation" className="container mobile-navigation" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onKeyDown={event => { if (event.key === "Escape") { setMenuOpen(false); document.querySelector<HTMLButtonElement>(".mobile-menu-toggle")?.focus(); } }}>
      {links.map(link => <Link key={link.href} href={link.href} aria-current={pathname === link.href ? "page" : undefined} onClick={() => setMenuOpen(false)}>{link.label}<ArrowUpRight size={14} /></Link>)}
    </motion.nav>}</AnimatePresence>
  </motion.header>;
}
