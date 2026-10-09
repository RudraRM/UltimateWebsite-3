"use client";
import { useEffect, useState, type Dispatch, type SetStateAction } from "react";
export function useLocalState<T>(key: string, initial: T, validate: (value: unknown) => value is T): [T, Dispatch<SetStateAction<T>>, boolean, boolean] {
  const [value, setValue] = useState<T>(initial);
  const [ready, setReady] = useState(false);
  const [storageOK, setStorageOK] = useState(true);
  useEffect(() => {
    try { const raw = localStorage.getItem(key); if (raw) { const parsed: unknown = JSON.parse(raw); if (validate(parsed)) setValue(parsed); else setStorageOK(false); } }
    catch { setStorageOK(false); }
    setReady(true);
  }, [key, validate]);
  useEffect(() => {
    if (!ready) return;
    try { localStorage.setItem(key, JSON.stringify(value)); } catch { setStorageOK(false); }
  }, [key, value, ready]);
  return [value, setValue, ready, storageOK];
}
