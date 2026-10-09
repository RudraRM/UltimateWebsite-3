"use client";

import { createContext, useContext, useState, type Dispatch, type SetStateAction, type ReactNode } from "react";
import { useTier } from "@/context/TierContext";
import { useLocalState } from "@/lib/useLocalState";
import { DEFAULTS, isInputs, isScenarios, type Inputs, type Scenario } from "@/lib/engine";

function isName(value: unknown): value is string {
  return typeof value === "string" && value.length <= 60;
}

type ProjectState = {
  inputs: Inputs;
  setInputs: Dispatch<SetStateAction<Inputs>>;
  scenarios: Scenario[];
  setScenarios: Dispatch<SetStateAction<Scenario[]>>;
  name: string;
  setName: Dispatch<SetStateAction<string>>;
  notice: string;
  setNotice: Dispatch<SetStateAction<string>>;
  active: boolean;
  storageOK: boolean;
};

const ProjectContext = createContext<ProjectState | undefined>(undefined);

export function ProjectProvider({ children }: { children: ReactNode }) {
  const { ready, storageOK: tierStorageOK } = useTier();
  const [inputs, setInputs, inputsReady, inputsOK] = useLocalState<Inputs>("marginpilot:inputs:v1", DEFAULTS, isInputs);
  const [scenarios, setScenarios, scenariosReady, scenariosOK] = useLocalState<Scenario[]>("marginpilot:scenarios:v1", [], isScenarios);
  const [name, setName, nameReady, nameOK] = useLocalState<string>("marginpilot:name:v1", "My next project", isName);
  const [notice, setNotice] = useState("");

  return <ProjectContext.Provider value={{
    inputs, setInputs, scenarios, setScenarios, name, setName, notice, setNotice,
    active: ready && inputsReady && scenariosReady && nameReady,
    storageOK: tierStorageOK && inputsOK && scenariosOK && nameOK,
  }}>{children}</ProjectContext.Provider>;
}

export function useProject() {
  const value = useContext(ProjectContext);
  if (!value) throw new Error("ProjectProvider is required");
  return value;
}
