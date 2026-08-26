import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "fs";
import { resolve, dirname, join } from "path";
import { fileURLToPath } from "url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const ledger = readFileSync(join(ROOT, "UPGRADE-LEDGER.md"), "utf8");
const entries = [...ledger.matchAll(/^### → v(\d+)\.(\d+)\.(\d+)/gm)].map((m) => m.slice(1, 4).map(Number));

test("the ledger is in ASCENDING version order", () => {
  // Step 3 applies entries in order. A prepended entry silently upgrades in the wrong
  // sequence, and it fails only for whoever is furthest behind — the person least
  // likely to be watched. This shipped for real once; hence the test.
  assert.ok(entries.length >= 2, "expected several entries");
  for (let i = 1; i < entries.length; i++) {
    const [a, b] = [entries[i - 1], entries[i]];
    assert.ok((a[0] - b[0] || a[1] - b[1] || a[2] - b[2]) < 0,
      `out of order: v${a.join(".")} appears before v${b.join(".")}`);
  }
});

test("no version appears twice", () => {
  const seen = entries.map((e) => e.join("."));
  assert.equal(new Set(seen).size, seen.length, "a duplicated entry gets applied twice");
});

test("every entry is numbered and actionable", () => {
  const blocks = ledger.split(/^### → v/m).slice(1);
  for (const b of blocks) {
    const name = b.split("\n")[0];
    assert.match(b, /^\s*1\./m, `v${name} has no numbered steps — an agent cannot follow it`);
  }
});

test("the append rule is stated where an editor will see it", () => {
  assert.match(ledger, /APPEND/i);
  assert.match(ledger, /never by prepending|never prepend/i);
});

test("the installers referenced by the ledger exist in this repo", () => {
  for (const s of ["scripts/bootstrap.sh", "scripts/preflight.sh"])
    assert.ok(existsSync(join(ROOT, s)), `${s} missing — the install commands point here`);
});
