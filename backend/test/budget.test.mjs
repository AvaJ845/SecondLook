import { test } from "node:test";
import assert from "node:assert/strict";
import { planAttempt } from "../src/worker.js";

// The bug this guards against: the app waits ~60s for a deepCheck, the worker
// tried a chain of models at 20s each and blew past that, so the app timed out
// with -1001 while the worker kept grinding. planAttempt keeps every attempt
// inside the budget.

test("first attempt gets the full per-model timeout", () => {
  const p = planAttempt(50_000, 0, 18_000);
  assert.equal(p.go, true);
  assert.equal(p.timeoutMs, 18_000);
});

test("a later attempt is shortened to what's left of the budget", () => {
  const p = planAttempt(50_000, 40_000, 18_000);
  assert.equal(p.go, true);
  assert.ok(p.timeoutMs <= 10_000, `expected <=10s, got ${p.timeoutMs}`);
});

test("no attempt is started once the budget is nearly gone", () => {
  const p = planAttempt(50_000, 46_000, 18_000, 7_000);
  assert.equal(p.go, false);
});

test("a shortened attempt never drops below the minimum useful time", () => {
  const p = planAttempt(50_000, 42_000, 18_000, 7_000);
  if (p.go) assert.ok(p.timeoutMs >= 7_000, `got ${p.timeoutMs}`);
});

test("two 18s attempts fit inside the 50s deepCheck budget", () => {
  let elapsed = 0;
  const a = planAttempt(50_000, elapsed);
  assert.equal(a.go, true);
  elapsed += a.timeoutMs;
  const b = planAttempt(50_000, elapsed);
  assert.equal(b.go, true);
  elapsed += b.timeoutMs;
  assert.ok(elapsed < 50_000, `chain ran ${elapsed}ms, over budget`);
});
