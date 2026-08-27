---
name: upgrade-paos-framework
description: Smart-upgrade an installed Personal Agentic OS workspace to the latest template. Probes what the workspace actually has (version file, feature probes, local edits), pulls the file layer via sync-with-upstream, then applies the version ledger's post-merge steps for every version between installed and latest, preserving everything the owner wrote. This is the HOSTED canonical; the copy inside any workspace is a thin pointer that fetches this URL, so even an old workspace upgrades with current logic.
---

# PAOS Upgrade Ledger

> **This file is the canonical upgrade ledger, and it lives here so it can take pull requests.**
> It was previously hosted only on a wiki, in a private repo, which meant the people actually
> running upgrades — the only ones who can find these bugs — had no way to fix them. Filed by
> @wilsfong after a v1.0.0 → v1.8.1 migration surfaced four defects he could not PR.
>
> `https://supersuit.wiki/skills/upgrade-paos-framework/SKILL.md` redirects here, so every
> workspace with that URL baked in keeps working. Older workspaces are exactly the population
> that needs it to.
>
> **A change here takes up to 5 minutes to reach an upgrading agent.**
> `raw.githubusercontent.com` serves this with `cache-control: max-age=300`. The commit is
> live immediately; the CDN is not. If you just pushed a fix and the URL still shows the old
> ledger, wait rather than pushing again.
>
> **Add new versions by APPENDING to the bottom of the ledger, never by prepending.** Step 3
> applies entries in order, so an out-of-order ledger upgrades in the wrong sequence — and it
> fails only for whoever is furthest behind, who is the least likely to be watched.


This file is hosted at https://supersuit.wiki/skills/upgrade-paos-framework/SKILL.md and is the single source of truth for upgrading a workspace built from [SupersuitUp/personal-agentic-os-workspace-template](https://github.com/SupersuitUp/personal-agentic-os-workspace-template).

**Why it lives at a URL:** the copy of any upgrade skill inside a workspace only knows the upgrades that existed the day that workspace was created. This URL always knows the newest versions and their post-merge steps. The in-workspace `upgrade-paos-framework` skill fetches this file and follows it; a workspace too old to have that skill can still be upgraded by fetching this URL directly.

## Step 1 — Probe the installed framework

Determine the installed template version. In order:

1. **Read `TEMPLATE-VERSION`** at the workspace root (ships since v1.2.0). If present, that is the installed version.
2. **Feature-probe** if the file is absent:
   - `grep -q saveMyProgress .paos.json.example` → v1.11.0
   - `grep -q 'SAME conversation' .agents/skills/process-transcript/SKILL.md` → v1.10.0
   - `grep -q 'recovered via PCM' .agents/skills/set-up-capture/SETUP.md` → v1.9.1
   - `.agents/lib/paos-workspace.mjs` present → v1.9.0
   - `grep -c 'created_at).toISOString' .agents/skills/sync-granola/scripts/sync.mjs` returns 0 → v1.8.0
   - `~/.claude/skills/my-skills/` present AND the marketplace is GitHub-sourced → v1.7.1
   - `.agents/skills/create-or-update-google-doc/` present → v1.6.0
   - `.agents/skills/message-contact/scripts/message_contact.py` present → v1.5.0
   - `.claude-plugin/plugin.json` and `projects/README.md` present → v1.1.0
   - `scripts/bootstrap.sh` present (but no plugin manifests) → v1.0.0
   - none of the above → pre-v1.0.0

**Probe for BEHAVIOR, never for a name.** A directory or an identifier tells you who wrote
something, not whether it works. Two ways this goes wrong, both seen in the field: an owner's
independently-written skill that happens to share a name reads as a template version they never
had, so every entry below it is skipped and the upgrade reports success on a workspace missing
those layers; and an owner who fixed a bug themselves under a different function name reads as
unfixed, so the ledger tells them something is wrong when it is not. Probe for a file the
template UNIQUELY ships, or for the ABSENCE OF THE DEFECT. When a probe disagrees with
`TEMPLATE-VERSION` or with the owner, believe the owner and ask.

Then probe local reality, because the upgrade must respect it:

- `git status` — a dirty tree pauses the upgrade until the owner commits or stashes.
- Which starter skills the owner has **edited** (`git diff upstream/main -- .agents/skills/` after fetching upstream) and which skills are **owner-added** (exist locally, not upstream).
- Whether the `upstream` remote is wired; if not, wire it with a disabled push URL: `git remote add upstream https://github.com/SupersuitUp/personal-agentic-os-workspace-template.git && git remote set-url --push upstream DISABLED`.

## Step 2 — Pull the file layer

Run the workspace's `sync-with-upstream` skill if it exists (it carries the merge protections). Otherwise: `git fetch upstream && git merge upstream/main`, resolving conflicts by the rule in Step 4.

**First check that the two repos share history at all:**

```bash
git merge-base HEAD upstream/main    # empty output means NO shared history
```

A workspace built from a PREDECESSOR template (e.g. `Applied-AI-Society/minimum-viable-jarvis`)
shares no history, and the merge refuses outright. Many workshop graduates are in exactly this
position. `--allow-unrelated-histories` does work, but it turns every shared path into an add/add
conflict — twenty files rather than the handful this flow normally expects — so get the owner's
agreement to that scale of review BEFORE starting, rather than halfway through it.

**Resolve `.gitignore` first, and resolve it as a UNION.** It is usually the only thing keeping
a private file out of a hosted repo, and taking upstream's version can silently un-ignore one.
On a workspace with an autopush job, the next commit then publishes it with nobody watching.
Prove the protections survived before committing anything:

```bash
git check-ignore -q "<each sensitive path>" && echo protected || echo EXPOSED
```

This is the one mistake in this workflow a revert cannot undo, because a pushed commit is public
the moment it lands.

## Step 3 — Apply the version ledger

Post-merge steps are what a git merge cannot do. Apply every entry strictly in order, from the installed version to the latest. Each entry is idempotent; re-running is safe.

### → v1.1.0 (plugin + projects layer)

1. The merge brought `.claude-plugin/` (the workspace doubles as a Claude Code plugin marketplace), `projects/README.md`, and the skills `start-project`, `resume-project`, `save-my-progress`. Confirm all are present.
2. Install the plugin globally so skills work in any directory as `/paos:<skill>`:
   ```bash
   claude plugin marketplace add <workspace-dir>
   claude plugin install paos@paos-workspace --yes
   ```
   Skip each command if `claude plugin marketplace list` / `claude plugin list` shows it already done. If `claude` is not on PATH, report it as a remaining manual step rather than failing the upgrade.

### → v1.2.0 (self-upgrading framework)

1. The merge brought `TEMPLATE-VERSION` and the thin `upgrade-paos-framework` skill (the pointer to this URL). Confirm both are present.
2. If the plugin was already installed before this upgrade, refresh the global snapshot: `claude plugin update paos`.


### → v1.3.0 (capture stack in the bootstrap)

1. The merge brought a bootstrap that installs Granola and Wispr Flow as Homebrew casks. A merge cannot install an app, so install whatever is missing:
   ```bash
   [ -d "/Applications/Granola.app" ]    || brew install --cask granola
   [ -d "/Applications/Wispr Flow.app" ] || brew install --cask wispr-flow
   ```
   Re-running `bash scripts/bootstrap.sh` does the same thing idempotently and re-prints the report card. On Windows or Linux, report both as manual installs rather than failing the upgrade.
2. Tell the owner the two sign-ins are theirs: Wispr Flow (free trial, then ~$10/mo) and Granola (free tier is enough). Neither app does anything until its account is connected.
3. Granola is what the `sync-granola` skill talks to. If the owner declines it, say plainly that `sync-granola` will not work without it.

### → v1.4.0 (save-my-progress learns from the run)

1. **Nothing to install.** This version changes one skill file, so the merge IS the upgrade. Confirm it landed:
   ```bash
   grep -c "hand-rolled" .agents/skills/save-my-progress/SKILL.md   # expect 1 or more
   ```
2. **Tell the owner what actually changed**, because it changes what a save DOES rather than adding a command:
   - A save now looks for the previous save's checkpoint first, so repeated saves are incremental instead of re-reading the whole history each time.
   - Lessons are now ROUTED by when they need to fire, into the narrowest home that fires then, rather than piling into the top-level instructions file that loads on every turn.
   - A save now sweeps for what the session HAND-ROLLED (throwaway scripts, retry loops, anything done three times by hand) and builds the fix, instead of writing a note about it.
   - Skill edits are now held to a test: does the skill behave better because of this line? Descriptive session history fails it and belongs in the log instead.
3. If the owner has customised their own `save-my-progress`, the merge may conflict. Their edits win; graft the four items above in rather than overwriting their file.


### → v1.5.0 (capture + message sending in the plugin)

1. The merge brought two skills. Confirm both are present:
   ```bash
   ls .agents/skills/set-up-capture/SETUP.md .agents/skills/message-contact/scripts/message_contact.py
   ```
2. **`message-contact` needs no config on a PAOS workspace.** It reads the `people/`
   folder automatically. Prove it resolves before telling the owner it works:
   ```bash
   python3 .agents/skills/message-contact/scripts/message_contact.py "<someone in people/>" "test" --dry-run
   ```
   Exit 2 means it could not resolve them; it prints the directories it searched. If the
   owner keeps people somewhere other than `people/`, write that path into
   `.agents/skills/message-contact/config.json` as `relationships_dirs`.
3. **`set-up-capture` is a one-time scaffold, not a merge.** The merge only delivered the
   instructions. Tell the owner it is available and what it does — Granola and Apple Voice
   Memos become markdown transcripts, iMessage and WhatsApp become READ-ONLY sources an
   agent can pull a thread from — and run it only if they want it now. It asks for two API
   keys and, in its second half, Full Disk Access.
4. If the plugin is installed globally, refresh the snapshot so the two new skills appear:
   `claude plugin update paos`. Verify with `claude plugin details paos`.

### → v1.6.0 (Google Docs + Calendar)

1. The merge brought two skills. Confirm:
   ```bash
   ls .agents/skills/create-or-update-google-doc/scripts/create.mjs .agents/skills/create-google-calendar-event/SKILL.md
   ```
2. **Install the `gog` CLI** — a merge cannot install a binary. Both skills are inert without it:
   ```bash
   command -v gog || brew install openclaw/tap/gogcli
   ```
   Re-running `bash scripts/bootstrap.sh` does the same idempotently. On Windows or Linux,
   report it as a manual install rather than failing the upgrade.
3. **The OAuth grant is the owner's, and nothing works until they do it.** Walk them through it:
   ```bash
   gog auth add <their-email> --services docs,calendar
   ```
   Then prove it before saying it works: `gog calendar events --max 1`.
4. Optional: docs land in Drive root by default. If the owner wants them in a specific
   folder, set `GOOGLE_DOC_FOLDER_ID` in their shell profile, or pass `--folder <id>`.
5. If the plugin is installed globally, refresh it: `claude plugin update paos`.

### → v1.7.1 (the plugin actually receives releases)

**This is a migration, and it is the reason an operator may have been stuck.** Until now
`bootstrap.sh` registered the marketplace from the local clone. The manifest says
`"source": "./"`, which resolves to the repo root on GitHub or to the local folder depending
only on how it was ADDED — so `claude plugin update paos` re-read the operator's own folder,
reported success, and delivered nothing, forever. Check first:

```bash
claude plugin marketplace list | grep -A1 paos-workspace
```

1. **If that says `Directory`, re-point it at GitHub.** This is the whole fix:
   ```bash
   claude plugin marketplace remove paos-workspace
   claude plugin marketplace add SupersuitUp/personal-agentic-os-workspace-template
   claude plugin install paos@paos-workspace --yes    # skip if already installed
   claude plugin update paos
   ```
   Then verify it took: `claude plugin list` should show `paos@paos-workspace` at 1.7.1 or
   later, and `marketplace list` should say `GitHub`. If it still says `Directory`, stop and
   report it — every future release depends on this one line.

2. **Give the operator their own skills plugin**, because a GitHub-sourced `paos` is replaced
   wholesale on every release and anything they wrote inside it would be lost:
   ```bash
   claude plugin init my-skills --description "Your own skills, global as /my-skills:<name> in any directory."
   rm -f ~/.claude/skills/my-skills/SKILL.md
   mkdir -p ~/.claude/skills/my-skills/skills
   ```
   Then set `"skills": ["./skills/"]` in `~/.claude/skills/my-skills/.claude-plugin/plugin.json`.
   `plugin init` scaffolds a single-skill plugin, so without this a skill added under
   `skills/<name>/` is never loaded and the placeholder's TODO text loads into every session.
   Prove it: `claude plugin details my-skills`.

3. **Leave skills in `.agents/skills/` alone.** They live in the operator's OWN repo, which a
   plugin release never touches, and `AGENTS.md` routes to them by that path — moving them breaks
   the routing to solve a problem the operator does not have. The `my-skills` plugin is for NEW
   skills from here on, and for anything the operator put INSIDE the plugin directory itself.
   Only that second case is ever at risk on a release.

4. From here on, `claude plugin update paos` is all they need for new skills.
   `/sync-with-upstream` still carries workspace files (scripts, docs, AGENTS.md).

### → v1.8.0 (date fix + merged lessons)

1. **Nothing to install** — the merge IS the upgrade. Confirm the date fix landed:
   ```bash
   grep -c "created_at).toISOString" .agents/skills/sync-granola/scripts/sync.mjs   # expect 0
   ```
2. **Tell the owner their PAST Granola syncs may be misdated, because this fix does not
   repair files already on disk.** Granola returns `created_at` in UTC; the old code
   derived the date from it directly, so anyone west of UTC had evening meetings filed one
   day forward. A meeting recorded at 9pm local was stored under tomorrow's date, and that
   date also fed the dedup keys.
   To find suspects, look in the meeting-transcripts folder for files whose frontmatter time
   is late-evening and whose filename date is one day AFTER the date in the body. Offer to
   rename them; do not rename anything without showing the list first, because these are the
   owner's records.
3. Other merged fixes need no action: `save-my-progress` no longer prints Step 0 twice, and
   the Google Docs and Calendar skills gained a when-to-use, a `--title` gotcha, and a
   write-the-correction-back-in-the-same-turn rule.

### → v1.8.2 (message-contact refuses to guess)

1. **Nothing to install.** Confirm the merge landed:
   ```bash
   grep -c "Refusing to guess" .agents/skills/message-contact/scripts/message_contact.py   # expect 1
   ```
2. **Tell the owner the behavior changed**, because it can now stop where it used to proceed:
   an identifier matching more than one person prints the candidates and exits 2 instead of
   sending to whichever file sorted first. Re-run with the exact slug (the filename without
   `.md`). Never pick one on the owner's behalf.
3. `sync-with-upstream` also gained a `.gitignore` union rule, an unrelated-histories branch,
   and ownership-by-diff. Those arrive with the merge; nothing to do.

### → v1.9.0 (declarable paths; stop writing into the plugin cache)

1. **RECOVER ANYTHING STRANDED FIRST — do this before `claude plugin update paos`, which
   deletes the directory it is in.** Until this version, `sync-granola` run from the plugin
   resolved the workspace relative to its own file, which under a plugin install is a
   complete copy of the template. Synced meetings were written there:
   ```bash
   find ~/.claude/plugins/cache/paos-workspace -path "*meeting-transcripts/*" -name "*.md"
   ```
   If that returns anything, those are the owner's meeting notes and they exist nowhere else.
   Move them into the real workspace's transcripts folder before updating the plugin. Show
   the owner the list; never delete any of it.
2. **Confirm the fix landed:**
   ```bash
   ls .agents/lib/paos-workspace.mjs
   ```
   Resolution now starts from the working directory and REFUSES a workspace inside the
   plugin cache. A script that cannot find a workspace now exits 2 with an explanation
   rather than writing somewhere that gets erased.
3. **If the owner's folders are not named like the template's**, they no longer have to
   reorganize. Copy `.paos.json.example` to `.paos.json` and declare the real paths:
   ```json
   { "paths": { "people": "docs/relationships", "transcripts": "docs/transcripts" } }
   ```
   Anything omitted keeps the default, so a template-shaped workspace needs no file at all.
   Ask the owner where things actually live rather than guessing, then prove it:
   ```bash
   python3 .agents/skills/message-contact/scripts/message_contact.py "<someone>" x --dry-run
   ```
   The `source:` line must point into their real folder.
4. Skills that name folders in PROSE are resolved through the same map — see the
   "Workspace paths" section that this version adds to `AGENTS.md`.

### → v1.9.1 (truncated transcripts are recovered, not retried)

1. **Nothing to install** if the owner has never run `set-up-capture`. Confirm the merge:
   ```bash
   grep -c "recovered via PCM" .agents/skills/set-up-capture/SETUP.md   # expect 1
   ```
2. **If they DID scaffold capture, their generated `.capture/vm-transcribe.mjs` is a COPY and
   does not update itself.** Re-scaffold that one file from the current `SETUP.md`, or apply
   the change by hand. Until then their pipeline still detects truncation and still gives up.
3. **Install ffmpeg if missing** — it is no longer optional:
   ```bash
   command -v ffprobe >/dev/null || brew install ffmpeg
   ```
   `ffprobe` is the only way the pipeline can tell a silently truncated transcript from a
   quiet recording; `ffmpeg` performs the transcode that recovers one.
4. **Offer to re-run any voice memo that was skipped as truncated.** Those files were never
   marked processed, so they are still pending — but before this version they would have
   failed identically on every run. They are recoverable now, and each one is a conversation
   the owner believed they had captured.

### → v1.10.0 (don't file one conversation twice)

1. **Nothing to install.** Confirm the merge:
   ```bash
   grep -c "SAME conversation" .agents/skills/process-transcript/SKILL.md   # expect 1
   ```
2. **Tell the owner what changed, because it changes what a capture run produces.** PAOS ships
   both Granola and Voice Memo capture, and until now had no deduplication between them. An
   owner recording a conversation on their laptop AND their phone got two meeting entries, two
   sets of action items, and two updates to the same person's file. `process-transcript` now
   checks for that first, and dedupes on transcript CONTENT rather than on clock math.
3. **If the owner already has duplicate entries from past runs**, offer to find them: same-day
   transcripts whose distinctive nouns appear in both at similar counts. Show the list and let
   them decide — these are their records, and merging is not automatic.
4. `capture.mjs` now takes a lock, so two concurrent runs cannot transcribe the same memos twice
   and race each other's state file. A lock older than 15 minutes is treated as stale.
5. `sync-granola` now refuses an unparseable or future `--since` instead of reporting a
   confident "0 new meetings", which is indistinguishable from actually having none. If the
   owner has a script passing `--since`, a previously-silent bad value now exits 2.

### → v1.11.0 (save-my-progress takes configuration)

1. **Nothing to install.** Confirm the merge:
   ```bash
   grep -c saveMyProgress .paos.json.example   # expect 1
   ```
2. **Defaults are unchanged**, so an owner who does nothing sees exactly the previous
   behavior: the checklist gate, and no messages sent.
3. **Tell the owner the two knobs exist**, because they turn a fork into a setting. Anyone
   who edited their own copy of this skill to make it autonomous, or to have it text them a
   recap, can delete that edit and set config instead — and then they receive future
   upgrades to the skill rather than being stranded on their fork:
   ```json
   { "saveMyProgress": { "mode": "autonomous", "textToSelf": true } }
   ```
   `textToSelf` resolves the recipient through `message-contact`, so it needs a contact file
   for the owner. If there is none, say so rather than leaving it silently doing nothing.
4. An explicit argument still beats the config: `/save-my-progress ask` forces the checklist
   even when the config says autonomous.

### → v1.11.1 (a default Drive folder is a setting too)

1. **Nothing to install.** `create-or-update-google-doc` now reads `googleDoc.folderId` and
   `googleDoc.author` from `.paos.json`, ahead of `$GOOGLE_DOC_FOLDER_ID` and behind an
   explicit `--folder`.
2. **This is the same fix as v1.11.0, applied to a second skill.** Anyone keeping a private
   copy of this skill purely to hardcode their own Drive folder or byline can delete that
   copy and set config — and start receiving upgrades again.

### → v1.12.0 (transcript files keep the transcript)

1. **Nothing to install.** Confirm:
   ```bash
   grep -c "ENRICH the file, never replace it" .agents/skills/process-transcript/SKILL.md
   ```
2. **This changes what a processed transcript file contains, and it is worth telling the
   owner plainly.** The old template produced a summary — Summary, Key Topics, Decisions,
   Action Items, Notes — and nothing else. Run against a file `sync-granola` had already
   written, an agent following it literally would replace the real transcript with a summary
   of it. The source was discarded and the file still looked complete.
3. **Offer to check for records that already lost their source:**
   ```bash
   grep -L "^## Transcript" <transcripts dir>/*.md
   ```
   Any file listed has no verbatim text. If it came from Granola, the original may still be
   recoverable — `sync-granola --id <granola_id> --force` re-pulls it. Show the owner the list
   first; some will legitimately have no transcript (handwritten notes, a meeting recalled
   from memory), and those should be marked rather than re-pulled.
4. From here on, `process-transcript` ENRICHES: distilled sections go above the existing
   `## Transcript`, and frontmatter flips `status: "raw"` to `"processed"`.

### → v1.12.1 (voice memos get the same protection as meetings)

1. **Nothing to install.** v1.12.0 protected the transcript inside files that carried
   `status: "raw"` — but only Granola's `sync-granola` wrote that marker. The capture stack's
   own `granola-pull.mjs` and `vm-transcribe.mjs` did not, so a voice-memo transcript did not
   match the description and could still be rewritten as a summary. Both now emit it.
2. **A voice memo is the case most easily got wrong**, and worth naming to the owner: its
   transcript is diarized but the speakers are NUMBERED (`**Speaker 0**`), so it reads like
   scratch output that wants cleaning up. It is not. The numbers can be resolved to names
   later; the words cannot be recovered. And unlike a meeting, there is often no service
   holding a second copy — the memo's audio may be the only other source, and it may be gone.
3. **If the owner already scaffolded capture, their generated `.capture/*.mjs` are COPIES** and
   do not update themselves. Re-scaffold `granola-pull.mjs` and `vm-transcribe.mjs` from the
   current `SETUP.md`, or add the `status: "raw"` line by hand.

### → v1.13.0 (source back-links, and a test suite)

1. **Nothing to install.** Confirm:
   ```bash
   bash scripts/test.sh        # 40 tests, no dependencies
   ```
2. **Capture files now link back to their source.** A Granola note records its
   `granola_url`; a voice memo records `audio` and `audio_filename`. A transcript is
   evidence, and evidence you cannot trace to its origin is worth much less — this is how
   a reader re-listens, checks a disputed line, or recovers the text if the file is damaged.
   Existing files are NOT rewritten; only new captures carry it.
3. **If the owner scaffolded capture before this, their `.capture/*.mjs` are COPIES** and do
   not update themselves. Re-scaffold `granola-pull.mjs` and `vm-transcribe.mjs` from the
   current `SETUP.md` to pick up both the back-links and the `status: "raw"` marker.
4. The suite covers the workspace resolver, both capture scripts, message-contact resolution,
   the Granola date guards, and repo invariants including ledger ordering. Run it before
   proposing any change to this template.

### → v1.14.0 (the ledger and installers moved; access is checked up front)

1. **Nothing changes for the owner.** `supersuit.wiki/skills/upgrade-paos-framework/SKILL.md`
   still resolves — it now redirects to this file's public home rather than serving a copy.
   Any workspace with that URL baked in keeps working.
2. **`bootstrap.sh` now checks repo access before creating anything** and exits 3 with an
   explanation if the account cannot see the template. Previously a missing grant surfaced as
   `Could not resolve to a Repository` three steps into a half-built workspace.
3. **If the owner has a pinned install command saved anywhere**, the installers moved:
   ```
   https://raw.githubusercontent.com/SupersuitUp/paos-docs/main/scripts/bootstrap.sh
   ```
   They now track `main` in a repo whose only job is holding them, so an install always gets
   the current bootstrap instead of whatever tag the docs last mentioned.
4. Nothing to run. This entry exists so a workspace upgrading THROUGH this version knows why
   the URLs it may have recorded have changed.

### → v1.15.0 (Granola heartbeat)

1. **Nothing to install.** `sync-granola` gained `check.mjs`, which answers "are there new
   meetings I have not synced?" without doing the sync:
   ```bash
   node .agents/skills/sync-granola/scripts/check.mjs --verbose
   ```
2. **Worth telling the owner it exists**, because the value is in what it lets them skip. Run
   it before a sync, and before anything that depends on a sync having happened. A routine
   that assumes a sync ran misses meetings; one that re-syncs every time to be safe burns an
   API call per run and buries any real signal in noise.

*(New versions APPEND here, below the last entry — never prepend. Step 3 says to apply
every entry in order, so a ledger written out of order silently upgrades in the wrong
sequence, and the workspaces that traverse the most versions are the ones it hits. A
workspace jumping several versions applies every entry between, in order.)*

## Step 4 — Integration rules (what is never clobbered)

- **Owner content is untouchable:** `user/`, `people/`, `artifacts/`, `meeting-transcripts/`, the contents of `projects/`, and every owner-added skill.
- **An edited starter skill keeps the owner's version.** Report the upstream diff and offer to fold the upstream improvements into their version; never overwrite silently.
- **Conflicts resolve toward the owner's content and the template's structure.** New template files land; files the owner shaped stay theirs.
- Nothing is force-pushed, and nothing is deleted that the owner created.

## Step 5 — Verify and report

- `bash scripts/test-setup-scripts.sh` if present; it must pass.
- `claude plugin details paos` should list the skill inventory (v1.1.0+).
- Update `TEMPLATE-VERSION` to the version just reached if the merge did not already.
- Report: version before and after, ledger entries applied, owner-edited files preserved (with the diffs offered), and any manual steps remaining.
