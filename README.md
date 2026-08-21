# Bread Class Codex

A fork of **Class Codex** by jfstn that adds **Wowhead** and **archon.gg** data alongside
the original's Icy Veins and u.gg, and keeps it working on current retail.

> **Licensing:** this release is based on Class Codex **1.0.3**, which ships only inside the
> Icy Veins desktop app and carries **no license file**. Redistribution terms are unresolved —
> see [NOTICE](NOTICE). The MIT text in `LICENSE` covers the older 0.40.14-based lineage only.

Not affiliated with or endorsed by jfstn. **Please don't report issues with this fork
upstream.**

## What's different

Built on Class Codex **1.0.3**. Upstream's Icy Veins / u.gg data is the base and is never
overwritten — **Wowhead** and **archon.gg** fill the gaps in it.

- Where upstream has no value for a category, hero talent or content context, the locally
  scraped data supplies one. Across all 40 specs that means a **`rotation` section for the
  34 u.gg specs that have none**, consumables for 40 specs, and roughly 1,500 extra talent
  build contexts plus ~160 each of gems, enchants and trinkets.
- Wowhead and Archon are **not** separate entries in the source dropdown. They fill
  upstream's gaps rather than sitting beside it as alternative views.
- Compatible with WoW **12.1.0** — 1.0.3 still calls `GetInspectSpecialization`, removed by
  that patch, unguarded in one place; this fork routes it through `C_SpecializationInfo`.
- **Not yet ported from the 0.40.14 lineage:** the "BiS for these specs" tooltip badge and
  the Archon per-encounter talent menu.

Data refreshes automatically once a week, so BiS tracks the current season.

## Install

**Do not run this alongside the original Class Codex.** It is a replacement, not an
add-on to it — both loaded at once will collide on frame names and saved variables.
Uninstall Class Codex first. Your existing settings carry over, because this fork keeps
the same saved-variable names.

### Manually

Download `BreadClassCodex-*.zip` from
[Releases](https://github.com/BouncyBread/BreadClassCodexFork/releases), extract it into
`World of Warcraft/_retail_/Interface/AddOns/`, and `/reload`. The zip already contains a
single `BreadClassCodex/` folder, so extract it as-is.

### With an addon manager

Add this repository as a GitHub source:

```
https://github.com/BouncyBread/BreadClassCodexFork
```

Installing this way works. **Updating in WowUp 2.23.0 does not** — remove the addon and
add it again to move to a newer version, or use the manual route above.

The two paths use different URLs. A fresh install downloads from the release's normal
download URL and succeeds. An update instead fetches
`api.github.com/repos/.../releases/assets/{id}` without sending
`Accept: application/octet-stream`, so GitHub returns JSON metadata rather than the zip
and it fails with *"End of central directory record signature not found."* A GitHub token
makes no difference — the header is the only thing that matters. This affects WowUp's
GitHub provider generally, not just this addon; 2.23.0 is the current release.

## Credits

- **jfstn** — Class Codex, everything this is built on.
- **Wowhead** and **archon.gg** — every gear, talent and consumable recommendation in
  `Data/db_wowhead.lua` and `Data/db_archon.lua` is their work; this only restructures it
  for in-game display. Each section links back to the page it came from.

See [NOTICE](NOTICE) for full attribution and licensing.
