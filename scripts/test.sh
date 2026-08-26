#!/usr/bin/env bash
# Guards on the ledger. No dependencies. Note the glob: `node --test tests/`
# resolves the directory as a module on Node 20+ and fails misleadingly.
set -euo pipefail
cd "$(dirname "$0")/.."
exec node --test tests/*.test.mjs
