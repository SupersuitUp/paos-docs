---
name: upgrade-paos-framework
description: Locate and fetch the current PAOS upgrade ledger. The full ledger is served to PAOS clients from the client repo; this public file carries the version list so that every installed workspace can tell whether it is behind without needing credentials.
---

# PAOS Upgrade Ledger — version index

**Latest version: v1.36.0**

This file is public on purpose, and it is deliberately thin.

Every installed PAOS workspace polls this URL **unauthenticated** at session start to decide
whether to tell its owner they are behind. That check has to keep working for someone whose
access has lapsed, or whose install is years old — those are precisely the people who most need
to be told a newer version exists. So the version list lives here, in the open, forever.

The upgrade INSTRUCTIONS are not here. They are served to PAOS clients, who have read access to
the client repo because that access is how PAOS is installed in the first place.

## Getting the full ledger

```bash
gh api repos/SupersuitUp/paos/contents/UPGRADE-LEDGER.md \
  -H "Accept: application/vnd.github.raw"
```

If that returns 404, the GitHub account you are authenticated as is not a PAOS client. That is
the wall, and it is the only one — nothing here is obfuscated, and the skills themselves are
plain markdown on your own disk once installed.

Not a client yet: https://github.com/SupersuitUp/paos

## Versions

Newest last. An upgrade applies every entry between the installed version and the latest, in
order.

### → v1.1.0 (plugin + projects layer)
### → v1.2.0 (self-upgrading framework)
### → v1.3.0 (capture stack in the bootstrap)
### → v1.4.0 (save-my-progress learns from the run)
### → v1.5.0 (capture + message sending in the plugin)
### → v1.6.0 (Google Docs + Calendar)
### → v1.7.1 (the plugin actually receives releases)
### → v1.8.0 (date fix + merged lessons)
### → v1.8.2 (message-contact refuses to guess)
### → v1.9.0 (declarable paths; stop writing into the plugin cache)
### → v1.9.1 (truncated transcripts are recovered, not retried)
### → v1.10.0 (don't file one conversation twice)
### → v1.11.0 (save-my-progress takes configuration)
### → v1.11.1 (a default Drive folder is a setting too)
### → v1.12.0 (transcript files keep the transcript)
### → v1.12.1 (voice memos get the same protection as meetings)
### → v1.13.0 (source back-links, and a test suite)
### → v1.14.0 (the ledger and installers moved; access is checked up front)
### → v1.15.0 (Granola heartbeat)
### → v1.16.0 (Google Docs auth works on current gog)
### → v1.17.0 (a way to report PAOS bugs)
### → v1.18.0 (you will be told when you are behind)
### → v1.19.0 (a local usage log)
### → v1.20.0 (message-contact works on stock macOS Python again)
### → v1.21.0 (the "you are behind" notice now reaches plugin installs)
### → v1.22.0 (PAOS now ships from a client repo)
### → v1.23.0 (WhatsApp path fix, accounts, and usage analytics)
### → v1.24.0 (paos login, and a portal of your own)
### → v1.25.0 (saying plainly what the analytics record)
### → v1.26.0 (your Granola sync stops forgetting itself)
### → v1.27.0 (CiCi, and a log of what you actually got done)
### → v1.28.0 (CiCi offers a save, and texts you the breadcrumb)
### → v1.29.0 (she is called CiCi)
### → v1.30.0 (iMessage and WhatsApp sync)
### → v1.31.0 (golden work sessions)
### → v1.32.0 (CiCi knows where you left off; keeping a session folds into saving)
### → v1.33.0 (CiCi greets you with what you were doing)
### → v1.34.0 (CiCi was silent for two reasons, both fixed)
### → v1.35.0 (harvest-and-compound: the step that makes the next session cheaper)
### → v1.36.0 (process-my-convos: one front door for every conversation)
