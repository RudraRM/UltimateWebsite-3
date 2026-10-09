"use client";
import { motion } from "framer-motion";
import { ArrowUpRight, ChartNoAxesCombined, Layers, LockKeyhole, SlidersHorizontal } from "lucide-react";
import { Reveal } from "./Primitives";
const features = [
  { icon: SlidersHorizontal, label: "01 / QUOTE INTELLIGENCE", title: "Stop pricing on instinct.", copy: "Account for labor, direct expenses, and project overhead. Set a real profit margin, rather than confusing margin with markup.", tag: "Every plan", wide: true },
  { icon: ChartNoAxesCombined, label: "02 / SCOPE SENSITIVITY", title: "See the cost of ‘one more thing.’", copy: "Hold your quote fixed and model effort overruns from −20% to +40%. Know when a good project becomes a bad deal.", tag: "Plus + Pro", wide: false },
  { icon: Layers, label: "03 / CAPACITY PLANNING", title: "A business, beyond one quote.", copy: "Model team capacity and project duration. Estimate annual profit under an explicit 48-week, fully utilized planning assumption.", tag: "Pro", wide: false },
  { icon: LockKeyhole, label: "04 / PRIVATE BY DESIGN", title: "Your client numbers stay yours.", copy: "Save scenarios locally, compare decisions, and export a client-ready cost summary. No accounts, trackers, cloud sync, or remote computation.", tag: "Local-first", wide: true },
];
export default function BentoFeatures() {
  return <Reveal id="features" className="container section"><div className="section-heading"><div><p className="eyebrow">BUILT FOR PEOPLE WHO SELL THEIR EXPERTISE</p><h2>Less guesswork.<br /><span className="muted">More room to grow.</span></h2></div><p className="muted">One focused workspace.<br />The numbers behind your next yes.</p></div><div className="bento">{features.map((feature, index) => <motion.a href="#workspace" key={feature.title} className={`panel feature ${feature.wide ? "wide" : ""}`} initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }} transition={{ delay: index * 0.06 }} whileHover={{ y: -4 }}><div className="between"><feature.icon size={24} aria-hidden="true" /><ArrowUpRight className="muted" size={18} /></div><p className="mono small muted">{feature.label}</p><h3>{feature.title}</h3><p className="muted">{feature.copy}</p><span className="badge">{feature.tag}</span></motion.a>)}</div></Reveal>;
}
