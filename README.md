# Bread Class CodexFork

A fork of **[Class Codex](https://addons.wago.io/addons/classcodex)** by jfstn (MIT) that
adds **Wowhead** and **archon.gg** as data sources alongside the original's Icy Veins and
u.gg, and keeps it working on current retail.

Not affiliated with or endorsed by jfstn. **Please don't report issues with this fork
upstream.**

## What's different

- **Wowhead** — editorial BiS, talent builds and written rotations.
- **archon.gg** — log-derived popularity split by **Mythic+ and Raid**, with each item's
  adoption share, max key and DPS. Covers the evoker talents and marksmanship hunter gear
  that Wowhead has gaps on.
- Both appear in the existing source dropdowns on the gear, talent, enhancement and
  trinket surfaces. Nothing from upstream was removed.
- The item tooltip's "BiS for these specs" badge covers all four sources (Wowhead and
  Archon are off by default — four sources on one tooltip is a lot of text).
- Compatible with WoW **12.1.0**; upstream's `GetInspectSpecialization` call was removed
  by that patch.

Data refreshes automatically once a week, so BiS tracks the current season.

## Install

**Do not run this alongside the original Class Codex.** It is a replacement, not an
add-on to it — both loaded at once will collide on frame names and saved variables.
Uninstall Class Codex first. Your existing settings carry over, because this fork keeps
the same saved-variable names.

### With an addon manager (recommended — you get auto-updates)

In [WowUp](https://wowup.io) or CurseBreaker, add this repository as a GitHub source:

```
https://github.com/BouncyBread/BreadClassCodexFork
```

### Manually

Download the `BreadClassCodexFork-*.zip` from
[Releases](https://github.com/BouncyBread/BreadClassCodexFork/releases), extract it into
`World of Warcraft/_retail_/Interface/AddOns/`, and `/reload`.

## Credits

- **jfstn** — Class Codex, everything this is built on.
- **Wowhead** and **archon.gg** — every gear, talent and consumable recommendation in
  `Data/db_wowhead.lua` and `Data/db_archon.lua` is their work; this only restructures it
  for in-game display. Each section links back to the page it came from.

See [NOTICE](NOTICE) for full attribution and licensing.
