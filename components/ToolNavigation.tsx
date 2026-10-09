"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { motion } from "framer-motion";
import { TOOL_ROUTES } from "@/lib/routes";

export default function ToolNavigation() {
  const pathname = usePathname();
  return <motion.nav className="tool-navigation" aria-label="Workspace tools" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
    {TOOL_ROUTES.map(route => <Link key={route.href} href={route.href} aria-current={pathname === route.href ? "page" : undefined} className={pathname === route.href ? "tool-link current" : "tool-link"}>
      {route.label}
      {pathname === route.href && <motion.span className="tool-link-indicator" layoutId="active-tool" />}
    </Link>)}
  </motion.nav>;
}
