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

test("the version index is exactly that, and nothing more", () => {
  // This file stopped being the canonical ledger in v1.22.0. It is now a PUBLIC
  // version index: numbers only, no upgrade instructions, because those moved
  // behind the client grant. Its job is to keep working unauthenticated forever.
  //
  // The test it replaced asserted "every entry has numbered steps" with
  // /^\s*1\./ and passed on a file containing no steps at all — every version
  // string starts with "1.", so the check matched the version number. It would
  // have passed on anything. The real check now lives in the development repo,
  // against the real ledger.
  assert.ok(entries.length >= 2, "expected several versions");
  assert.doesNotMatch(ledger, /^\s*\d+\.\s+\*\*/m,
    "instructions belong in the client repo, not in the public index");
  assert.match(ledger, /Latest version: v\d+\.\d+\.\d+/,
    "the index must state the latest version in a form a human can read");
});

test("the latest heading agrees with the stated latest version", () => {
  const stated = ledger.match(/Latest version: (v\d+\.\d+\.\d+)/)?.[1];
  const newest = `v${entries.at(-1).join(".")}`;
  assert.equal(stated, newest,
    "the banner and the list disagree, so one of them is lying to every installed hook");
});

test("the old session-start hook's exact grep still finds a version", () => {
  // Every already-installed workspace polls this file with a fixed pattern. If a
  // rewrite ever drops the "### → vX.Y.Z" shape, every existing install goes
  // silent — including the ones furthest behind, who need it most.
  const found = ledger.match(/^### → v[0-9]+\.[0-9]+\.[0-9]+/gm);
  assert.ok(found && found.length > 0, "the index carries no parseable version headings");
});

test("the installers referenced by the ledger exist in this repo", () => {
  for (const s of ["scripts/bootstrap.sh", "scripts/preflight.sh"])
    assert.ok(existsSync(join(ROOT, s)), `${s} missing — the install commands point here`);
});
