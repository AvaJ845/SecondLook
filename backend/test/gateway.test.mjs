import { test } from "node:test";
import assert from "node:assert/strict";
import { breakerOpen, breakerTrip, _breakerReset, stripReasoning } from "../src/worker.js";

test("circuit breaker opens after a trip, then closes after the cooldown", () => {
  _breakerReset();
  const model = "nvidia:example/hangs";
  const now = 1_000_000;
  assert.equal(breakerOpen(model, now), false);
  breakerTrip(model, now);
  assert.equal(breakerOpen(model, now + 1_000), true);          // still cooling down
  assert.equal(breakerOpen(model, now + 5 * 60_000), false);    // cooled off
  _breakerReset();
});

test("stripReasoning removes <think> blocks", () => {
  assert.equal(
    stripReasoning("<think>let me consider…</think>\nHere is the answer."),
    "Here is the answer.",
  );
});

test("stripReasoning drops a preamble before the first label for structured tasks", () => {
  const raw =
    "Here's a thinking process:\n1. Analyze the message.\n2. Decide.\n\n" +
    "READ: a few things worth checking\nCONCERNS:\n- asks for a fee";
  const out = stripReasoning(raw, "deepCheck");
  assert.ok(out.startsWith("READ:"), out);
  assert.ok(!out.toLowerCase().includes("thinking process"), out);
});

test("stripReasoning leaves a clean structured answer untouched", () => {
  const raw = "READ: looks consistent with a real process\nCONCERNS:\n- none found";
  assert.equal(stripReasoning(raw, "deepCheck"), raw);
});

test("stripReasoning leaves plain summaries alone", () => {
  const raw = "Be cautious — legitimate employers rarely ask for payment before an interview.";
  assert.equal(stripReasoning(raw, "plainSummary"), raw);
});
