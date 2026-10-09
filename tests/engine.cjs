const { test } = require("node:test");
const assert = require("node:assert/strict");
const { calculate, sensitivity, DEFAULTS, isInputs, isScenarios } = require("../.engine-check/engine.js");
test("recommended quote achieves the selected margin after reserved costs", () => {
  for (const tier of ["Free", "Plus", "Pro"]) {
    const r = calculate(DEFAULTS, tier);
    assert.ok(Math.abs(r.profit / r.quote - DEFAULTS.margin / 100) < 1e-10);
    assert.ok(Math.abs(r.quote - r.totalCost - r.profit) < 1e-10);
  }
});
test("Free results ignore locked paid inputs", () => {
  const a = calculate(DEFAULTS, "Free");
  const b = calculate({ ...DEFAULTS, contingency: 50, team: 50, weekly: 80 }, "Free");
  assert.deepEqual(a, b);
});
test("effort overruns reduce profit at a fixed quote", () => {
  const rows = sensitivity(DEFAULTS, "Plus");
  for (let i = 1; i < rows.length; i++) assert.ok(rows[i].profit < rows[i - 1].profit);
  assert.ok(Math.abs(rows.find(r => r.delta === 0).margin - DEFAULTS.margin) < 1e-10);
});
test("capacity changes duration without inflating the project quote", () => {
  const a = calculate(DEFAULTS, "Pro");
  const b = calculate({ ...DEFAULTS, team: 2 }, "Pro");
  assert.equal(a.quote, b.quote); assert.equal(a.weeks / 2, b.weeks);
});
test("unsafe stored inputs and malformed scenarios are rejected", () => {
  assert.equal(isInputs({ ...DEFAULTS, margin: 100 }), false);
  assert.equal(isInputs({ ...DEFAULTS, hours: Infinity }), false);
  assert.equal(isInputs({ ...DEFAULTS, team: 1.5 }), false);
  assert.equal(isScenarios([{ id: "a", name: "Demo", inputs: DEFAULTS, savedAt: "invalid" }]), false);
});
