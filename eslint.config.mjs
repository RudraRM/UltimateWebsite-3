import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTypescript from "eslint-config-next/typescript";
export default defineConfig([
  ...nextVitals,
  ...nextTypescript,
  {
    files: ["context/TierContext.tsx", "lib/useLocalState.ts"],
    // Browser storage is intentionally restored after SSR hydration.
    rules: { "react-hooks/set-state-in-effect": "off" },
  },
  { files: ["tests/*.cjs"], rules: { "@typescript-eslint/no-require-imports": "off" } },
  globalIgnores([".next/**", "out/**", ".engine-check/**", "next-env.d.ts"]),
]);
