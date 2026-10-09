"use client";
import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowUpRight, Command } from "lucide-react";
import { useTier } from "@/context/TierContext";
import { Button } from "./Primitives";
export default function Footer() {
  const { tier, selectTier, ready } = useTier();
  return <><motion.footer initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }} className="container footer"><div className="between wrap"><Link href="/" className="brand"><Command size={20} />MarginPilot</Link><span className="small muted">Built for better business decisions.</span></div><div className="footer-details small muted"><p>Privacy: inputs and scenarios are stored only in this browser. Clearing site storage removes them. No analytics, cloud storage, or external APIs are used.</p><p>Terms: this is an illustrative planning tool. Results depend on your assumptions. Demo tiers do not process payments or provide secure entitlements.</p></div></motion.footer><motion.div className="plan-dock" initial={{ opacity: 0 }} animate={{ opacity: 1 }}><div className="container between"><span className="small"><b>{tier}</b> demo <span className="muted dock-label">/ your private pricing workspace</span></span><div className="row"><Link href="/pricing" className="small muted">All plans</Link>{tier !== "Pro" && <Button disabled={!ready} className="primary small" onClick={() => selectTier(tier === "Free" ? "Plus" : "Pro")}>Try {tier === "Free" ? "Plus" : "Pro"}<ArrowUpRight size={14} /></Button>}{tier === "Pro" && <Link className="btn small" href="/quote">Open workspace<ArrowUpRight size={14} /></Link>}</div></div></motion.div></>;
}
