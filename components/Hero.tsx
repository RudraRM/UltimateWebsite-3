"use client";
import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowUpRight, ArrowRight, ShieldCheck } from "lucide-react";
import { Reveal } from "./Primitives";
const MotionLink = motion.create(Link);
export default function Hero() {
  return <Reveal className="container hero">
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ staggerChildren: 0.12 }}>
      <div className="eyebrow"><span className="status-dot" /> INDEPENDENT WORK. INTELLIGENT PRICING.</div>
      <motion.h1 initial={{ opacity: 0, y: 18 }} animate={{ opacity: 1, y: 0 }}>Good work.<br /><span className="muted">Better margins.</span></motion.h1>
      <motion.p className="hero-copy" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.15 }}>Turn your next project into a profitable decision. Model the quote, stress-test the scope, and see what your time is really worth.</motion.p>
      <div className="row wrap hero-actions"><MotionLink href="/quote" className="btn primary" whileHover={{ scale: 1.025 }} whileTap={{ scale: 0.98 }}>Calculate my quote <ArrowUpRight size={17} /></MotionLink><Link href="/pricing" className="text-link">Explore plans <ArrowRight size={15} /></Link></div>
      <p className="small muted row"><ShieldCheck size={15} /> No account. No uploads. Your numbers stay in this browser.</p>
    </motion.div>
    <motion.div className="terminal" initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} whileHover={{ y: -3 }}>
      <div className="terminal-bar"><div className="row dots"><i /><i /><i /></div><span className="mono small">quote.engine / example</span><span className="badge">LOCAL</span></div>
      <div className="terminal-body mono"><p className="muted">$ marginpilot model --project website</p><p><span className="muted">01 /</span> Labor + expenses + overhead <b>$3,100</b></p><p><span className="muted">02 /</span> Target profit margin <b>35%</b></p><div className="terminal-result"><span className="small muted">RECOMMENDED QUOTE</span><strong>$4,769</strong><span className="accent small">$1,669 modeled profit · Free calculation</span></div><div className="row small muted"><span className="status-dot" /> Ready to calculate your project<span className="cursor">▍</span></div></div>
    </motion.div>

  </Reveal>;
}
