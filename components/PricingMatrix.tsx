"use client";
import Link from "next/link";
import { motion } from "framer-motion";
import { Check, ArrowUpRight } from "lucide-react";
import { useTier } from "@/context/TierContext";
import type { Tier } from "@/lib/engine";
import { Button, Reveal } from "./Primitives";
const plans: { name: Tier; price: number; description: string; features: string[] }[] = [
  { name: "Free", price: 0, description: "Make your next quote make sense.", features: ["Full quote and margin calculator", "1 saved scenario", "Project presets", "Private browser storage"] },
  { name: "Plus", price: 19, description: "Protect your margin as scope changes.", features: ["Everything in Free", "Adjustable contingency reserve", "Scope sensitivity analysis", "5 saved scenarios + comparison"] },
  { name: "Pro", price: 49, description: "Plan the business behind the work.", features: ["Everything in Plus", "Team and weekly capacity controls", "Annual profit planning", "20 scenarios + CSV / print reports"] },
];
export default function PricingMatrix() {
  const { tier, selectTier, ready } = useTier();
  return <Reveal id="pricing" className="container section pricing-page"><div className="section-heading"><div><p className="eyebrow">A PLAN FOR YOUR NEXT STAGE</p><h1 className="page-title">Find your margin.<br /><span className="muted">Then protect it.</span></h1></div><p className="small muted">Illustrative monthly pricing in USD.<br />Try every tier. No payment is collected.</p></div><div className="pricing-grid">{plans.map(plan => <motion.article layout className={`panel pricing-card ${plan.name === tier ? "selected" : ""}`} key={plan.name} whileHover={{ y: -4 }}><div className="between"><h2>{plan.name}</h2>{plan.name === "Plus" && <span className="badge accent">SCOPE CONTROL</span>}</div><p className="muted small">{plan.description}</p><div className="price">${plan.price}<span className="muted small"> / month</span></div><Button disabled={!ready} aria-pressed={plan.name === tier} className={plan.name === tier ? "primary full" : "full"} onClick={() => selectTier(plan.name)}>{plan.name === tier ? "Active demo tier" : `Try ${plan.name} demo`}<ArrowUpRight size={16} /></Button><ul>{plan.features.map(item => <li key={item}><Check size={15} className="accent" />{item}</li>)}</ul></motion.article>)}</div><p className="small"><Link className="text-link" href="/quote">Continue to your quote <ArrowUpRight size={15} /></Link></p><p className="small muted">Demo access is stored locally and can be changed at any time. Saved scenarios are kept when you switch tiers; access follows your current plan.</p></Reveal>;
}
