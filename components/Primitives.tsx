"use client";
import { motion, MotionConfig, type HTMLMotionProps } from "framer-motion";
import type { ReactNode } from "react";
export function MotionShell({ children }: { children: ReactNode }) {
  return <MotionConfig reducedMotion="user" transition={{ type: "spring", stiffness: 280, damping: 28 }}>{children}</MotionConfig>;
}
export function Reveal({ children, className = "", id }: { children: ReactNode; className?: string; id?: string }) {
  return <motion.section id={id} className={className} initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true, amount: 0.08 }} transition={{ duration: 0.4 }}>{children}</motion.section>;
}
export function Button({ children, className = "", ...props }: HTMLMotionProps<"button">) {
  return <motion.button type="button" className={`btn ${className}`} whileHover={props.disabled ? undefined : { scale: 1.025 }} whileTap={props.disabled ? undefined : { scale: 0.98 }} {...props}>{children}</motion.button>;
}
