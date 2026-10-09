"use client";
import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { isTier, type Tier } from "@/lib/engine";
type State = { tier: Tier; selectTier: (tier: Tier) => void; theme: "dark" | "light"; toggleTheme: () => void; ready: boolean; storageOK: boolean };
const Context = createContext<State | undefined>(undefined);
export function TierProvider({ children }: { children: ReactNode }) {
  const [tier, setTier] = useState<Tier>("Free");
  const [theme, setTheme] = useState<"dark" | "light">("dark");
  const [ready, setReady] = useState(false);
  const [storageOK, setStorageOK] = useState(true);
  useEffect(() => {
    try {
      const stored = localStorage.getItem("marginpilot:tier:v1");
      if (isTier(stored)) setTier(stored);
      const savedTheme = localStorage.getItem("marginpilot:theme:v1");
      if (savedTheme === "light" || savedTheme === "dark") setTheme(savedTheme);
      else if (window.matchMedia("(prefers-color-scheme: light)").matches) setTheme("light");
    } catch { setStorageOK(false); }
    setReady(true);
    const sync = (event: StorageEvent) => {
      if (event.key === "marginpilot:tier:v1") setTier(isTier(event.newValue) ? event.newValue : "Free");
      if (event.key === "marginpilot:theme:v1") setTheme(event.newValue === "light" ? "light" : "dark");
    };
    window.addEventListener("storage", sync);
    return () => window.removeEventListener("storage", sync);
  }, []);
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    if (!ready) return;
    try { localStorage.setItem("marginpilot:tier:v1", tier); localStorage.setItem("marginpilot:theme:v1", theme); }
    catch { setStorageOK(false); }
  }, [tier, theme, ready]);
  return <Context.Provider value={{ tier, selectTier: setTier, theme, toggleTheme: () => setTheme(t => t === "dark" ? "light" : "dark"), ready, storageOK }}>{children}</Context.Provider>;
}
export function useTier() { const value = useContext(Context); if (!value) throw new Error("TierProvider is required"); return value; }
