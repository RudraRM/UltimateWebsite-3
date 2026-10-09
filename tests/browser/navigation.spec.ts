import { readFile } from "node:fs/promises";
import { test, expect } from "@playwright/test";

test("landing stays focused and projects survive navigation and reload", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toContainText("Good work.");
  await expect(page.locator(".workspace, .bento, .pricing-grid")).toHaveCount(0);
  await expect(page.getByRole("spinbutton")).toHaveCount(0);
  await page.getByRole("link", { name: "Calculate my quote" }).click();
  await expect(page).toHaveURL(/\/quote$/);
  await expect(page.getByLabel("Estimated effort", { exact: true })).toBeEnabled();
  await page.getByLabel("Project name", { exact: true }).fill("Client Alpha");
  await page.getByLabel("Estimated effort", { exact: true }).fill("80");
  await expect(page.locator(".quote-number")).toHaveText("$8,769");
  await page.getByRole("button", { name: "Save scenario" }).click();
  await page.getByRole("link", { name: "View saved scenarios" }).click();
  await expect(page).toHaveURL(/\/scenarios$/);
  await expect(page.getByRole("heading", { name: "Client Alpha" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Load scenario Client Alpha", exact: true })).toBeEnabled();
  await page.getByRole("link", { name: "Edit quote", exact: true }).click();
  await page.getByLabel("Project name", { exact: true }).fill("Client Beta");
  await page.getByLabel("Estimated effort", { exact: true }).fill("20");
  await page.getByRole("navigation", { name: "Workspace tools" }).getByRole("link", { name: "Scenarios", exact: true }).click();
  await page.getByRole("button", { name: "Load scenario Client Alpha", exact: true }).click();
  await page.getByRole("link", { name: "Edit quote", exact: true }).click();
  await expect(page.getByLabel("Project name", { exact: true })).toHaveValue("Client Alpha");
  await expect(page.getByLabel("Estimated effort", { exact: true })).toHaveValue("80");
  await page.reload();
  await expect(page.getByLabel("Estimated effort", { exact: true })).toBeEnabled();
  await expect(page.getByLabel("Project name", { exact: true })).toHaveValue("Client Alpha");
  await expect(page.locator(".quote-number")).toHaveText("$8,769");
});

test("direct tool routes honor plan gates and Pro produces reports", async ({ page }) => {
  await page.goto("/quote");
  await expect(page.getByLabel("Estimated effort", { exact: true })).toBeEnabled();
  await expect(page.getByLabel("Contingency reserve", { exact: true })).toBeDisabled();
  await page.goto("/scope");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Protect your margin.");
  await expect(page.locator("table")).toHaveCount(0);
  await page.goto("/capacity");
  await expect(page.getByLabel("Hours / week", { exact: true })).toBeDisabled();
  await page.goto("/reports");
  await expect(page.getByRole("button", { name: "Export CSV" })).toHaveCount(0);
  await page.goto("/pricing");
  const plus = page.locator(".pricing-card").filter({ has: page.getByRole("heading", { name: "Plus", exact: true }) });
  await plus.getByRole("button", { name: "Try Plus demo" }).click();
  await expect(plus.getByRole("button", { name: "Active demo tier" })).toBeVisible();
  await page.goto("/scope");
  await expect(page.locator("tbody tr")).toHaveCount(7);
  await page.goto("/capacity");
  await expect(page.getByLabel("Team size", { exact: true })).toBeDisabled();
  await page.goto("/pricing");
  const pro = page.locator(".pricing-card").filter({ has: page.getByRole("heading", { name: "Pro", exact: true }) });
  await pro.getByRole("button", { name: "Try Pro demo" }).click();
  await expect(pro.getByRole("button", { name: "Active demo tier" })).toBeVisible();
  await page.goto("/capacity");
  await expect(page.getByLabel("Hours / week", { exact: true })).toBeEnabled();
  await page.getByLabel("Hours / week", { exact: true }).fill("20");
  await page.getByLabel("Team size", { exact: true }).fill("2");
  await page.getByRole("navigation", { name: "Workspace tools" }).getByRole("link", { name: "Reports", exact: true }).click();
  await expect(page.locator(".report-preview")).toContainText("40 hours/week");
  const download = page.waitForEvent("download");
  await page.getByRole("button", { name: "Export CSV" }).click();
  const report = await download;
  expect(report.suggestedFilename()).toBe("marginpilot-report.csv");
  const csv = await readFile((await report.path())!, "utf8");
  expect(csv).toContain('"Weekly productive hours per person","20"');
  expect(csv).toContain('"Team size","2"');
  await page.emulateMedia({ media: "print" });
  await expect(page.locator(".print-report")).toBeVisible();
  await expect(page.getByRole("navigation", { name: "Workspace tools" })).toBeHidden();
  await expect(page.locator(".report-preview")).toBeHidden();
});

test("navigation is accessible on mobile and desktop", async ({ page, isMobile }) => {
  await page.goto("/");
  if (isMobile) {
    const toggle = page.getByRole("button", { name: "Open navigation" });
    await toggle.click();
    await expect(page.getByRole("button", { name: "Close navigation" })).toHaveAttribute("aria-expanded", "true");
    await page.getByRole("navigation", { name: "Mobile navigation" }).getByRole("link", { name: "Reports", exact: true }).click();
    await expect(page.getByRole("navigation", { name: "Mobile navigation" })).toHaveCount(0);
  } else {
    await page.getByRole("navigation", { name: "Main navigation" }).getByRole("link", { name: "Tools", exact: true }).click();
    await page.getByRole("navigation", { name: "Workspace tools" }).getByRole("link", { name: "Reports", exact: true }).click();
  }
  await expect(page).toHaveURL(/\/reports$/);
  await expect(page.getByRole("navigation", { name: "Workspace tools" }).getByRole("link", { name: "Reports", exact: true })).toHaveAttribute("aria-current", "page");
  const horizontalOverflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
  expect(horizontalOverflow).toBe(false);
});
