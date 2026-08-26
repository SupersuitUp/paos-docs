# PAOS — public docs

The **upgrade ledger** and the **installers** for the Personal Agentic OS, kept public and
unauthenticated on purpose.

The PAOS template itself is private and granted per account. These two things cannot live
there with it:

- **`UPGRADE-LEDGER.md`** — every workspace's upgrade path fetches this, unauthenticated. If it
  sat behind access control, a private repo would 404 for the very people entitled to upgrade,
  because the fetch carries no credentials. It holds instructions only, never capability.
- **`scripts/`** — `preflight.sh` and `bootstrap.sh`. Install begins here so that someone
  without access fails at the ACCESS boundary with a message that tells them what to do, rather
  than on a 404 that tells them nothing.

PRs welcome on the ledger. It is the file that upgrades everyone's workspace, and the people
who find its bugs are the ones actually running upgrades — which is why it is here rather than
somewhere only the author can edit.
