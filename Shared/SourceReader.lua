local _, ns = ...

IcyVeinsData = IcyVeinsData or {}
UGGData = UGGData or {}

local WILDCARD = "all"
local STAT_DISPLAY = { crit = "Critical Strike", haste = "Haste", mastery = "Mastery", versatility = "Versatility" }
local ROTATION_CTX = {
    ["single-target"] = "Single-Target",
    aoe = "AoE",
    cleave = "Cleave",
    opener = "Opener",
    ["single-target-opener"] = "Opener (Single-Target)",
    ["aoe-opener"] = "Opener (AoE)",
    ["cleave-opener"] = "Opener (Cleave)",
    pvp = "PvP",
    [WILDCARD] = "Rotation",
}

-- Target-count AoE splits ("aoe-2", "aoe-3", "aoe-4plus", …). The 2-target
-- list is deltas on top of the single-target rotation, per the source guide.
local function rotationContextLabel(key)
    local label = ROTATION_CTX[key]
    if label then return label end
    local n = key:match("^aoe%-(%d+)plus$") or key:match("^aoe%-(%d+)$")
    if n then
        if n == "2" then return "AoE · 2 Targets (ST + changes)" end
        if key:sub(-#"plus") == "plus" then return ("AoE · %s+ Targets"):format(n) end
        return ("AoE · %s Targets"):format(n)
    end
    return key
end

-- Dropdown order: single-target first, then AoE (plain, then by target count),
-- generic Rotation, then openers — mirroring the source guide's presentation.
local ROTATION_CTX_ORDER = {
    ["single-target"] = 1,
    aoe = 2,
    cleave = 2,
    ["all"] = 4,
    opener = 5,
    ["single-target-opener"] = 6,
    ["aoe-opener"] = 7,
    ["cleave-opener"] = 8,
    pvp = 9,
}
-- Returns (rank, tiebreak) — target-count splits order by their number.
local function rotationContextRank(key)
    local base = ROTATION_CTX_ORDER[key]
    if base then return base, 0 end
    local n = key:match("^aoe%-(%d+)")
    if n then return 3, tonumber(n) or 0 end
    return 10, 0
end
ns.RotationContextRank = rotationContextRank
local TALENT_CTX =
    { raid = "Raid", mplus = "Mythic+", delve = "Delves", leveling = "Leveling", pvp = "PvP", [WILDCARD] = "General" }

local function resolve(category, hero, context)
    if not category then return nil end
    return ns.ResolveCategory and ns.ResolveCategory(category, hero, context) or nil
end

-- The feed can repeat a step verbatim under differently-worded sub-headings
-- that map to one context (e.g. "AoE Opener" / "Multi-Target Opener"); a
-- priority list never carries the same exact step twice meaningfully.
local function dedupeSteps(steps)
    local seen, out = {}, {}
    for _, s in ipairs(steps) do
        if not seen[s] then
            seen[s] = true
            out[#out + 1] = s
        end
    end
    return out
end

local function buildClassCodexData(iv)
    IcyVeinsData = IcyVeinsData or {}
    for class, specs in pairs(iv.data) do
        IcyVeinsData[class] = IcyVeinsData[class] or {}
        for spec, sd in pairs(specs) do
            local entry = {}

            local sp = resolve(sd.statPriority, WILDCARD, WILDCARD)
            if sp and sp.secondary then
                local tiers = {}
                for _, tier in ipairs(sp.secondary) do
                    local names = {}
                    for _, k in ipairs(tier) do
                        -- Qualified entries ({stat="haste",note="to 22%"}) carry an
                        -- upstream breakpoint ("Haste to 22%"); plain strings are bare keys.
                        local base, note = k, nil
                        if type(k) == "table" then
                            base, note = k.stat, k.note
                        end
                        local name = STAT_DISPLAY[base] or base
                        if note and note ~= "" then name = name .. " " .. note end
                        names[#names + 1] = name
                    end
                    if #names > 0 then tiers[#tiers + 1] = names end
                end
                if #tiers > 0 then entry.priorities = { { heroTalent = "All", context = "General", stats = tiers } } end
            end

            local rot = sd.rotation
            if rot then
                local out = {}
                for heroKey, byPlaystyle in pairs(rot) do
                    local heroDisplay = (heroKey == WILDCARD) and "All"
                        or (iv.reference and iv.reference.heroNames and iv.reference.heroNames[heroKey])
                        or heroKey
                    for playstyle, r in pairs(byPlaystyle) do
                        out[#out + 1] = {
                            heroTalent = heroDisplay,
                            context = rotationContextLabel(playstyle),
                            key = playstyle,
                            steps = dedupeSteps(r.steps),
                        }
                    end
                end
                if #out > 0 then entry.rotation = out end
            end

            local tal = sd.talents
            if tal then
                local out = {}
                for heroKey, byContext in pairs(tal) do
                    local heroDisplay = (heroKey == WILDCARD) and "All"
                        or (iv.reference and iv.reference.heroNames and iv.reference.heroNames[heroKey])
                        or heroKey
                    for context, builds in pairs(byContext) do
                        for _, b in ipairs(builds) do
                            out[#out + 1] = {
                                heroTalent = heroDisplay,
                                context = TALENT_CTX[context] or context,
                                buildLabel = b.label,
                                exportString = b.export,
                                recommended = b.recommended,
                            }
                        end
                    end
                end
                if #out > 0 then entry.talents = out end
            end

            IcyVeinsData[class][spec] = entry
        end
    end
end

local PVP_BRACKET_LABEL = { ["2v2"] = "2v2", ["3v3"] = "3v3", rbg = "Rated BG", shuffle = "Solo Shuffle" }
local function describeUggContext(ctxKey, ref)
    if ctxKey == "mplus" then
        return "mythic-plus:high-keys:all-dungeons", "mplus", nil, "all-dungeons", "All Dungeons", true
    end
    if ctxKey == "raid" then return "raid:mythic:all-bosses", "raid", "mythic", "all-bosses", "All Bosses", true end
    if ctxKey == "raidh" then return "raid:heroic:all-bosses", "raid", "heroic", "all-bosses", "All Bosses", true end
    if ctxKey == "pvp" then return "pvp:all-brackets", "pvp", nil, "all-brackets", "PvP", true end
    local bucket, id = ctxKey:match("^(%a+):(.+)$")
    local enc = ref and ref.encounters
    if bucket == "mplus" then
        local label = (enc and enc.dungeons and enc.dungeons[tonumber(id)]) or ("Dungeon " .. id)
        return "mythic-plus:high-keys:ugg-" .. id, "mplus", nil, "ugg-" .. id, label, false
    elseif bucket == "raid" then
        local label = (enc and enc.bosses and enc.bosses[tonumber(id)]) or ("Boss " .. id)
        return "raid:mythic:ugg-" .. id, "raid", "mythic", "ugg-" .. id, label, false
    elseif bucket == "raidh" then
        local label = (enc and enc.bosses and enc.bosses[tonumber(id)]) or ("Boss " .. id)
        return "raid:heroic:ugg-" .. id, "raid", "heroic", "ugg-" .. id, label, false
    elseif bucket == "pvp" then
        return "pvp:" .. id, "pvp", nil, id, PVP_BRACKET_LABEL[id] or id, false
    end
    return nil
end

local function resolveExport(export, canEncode)
    if not export then return nil end
    if not export:find("#", 1, true) then return export end
    if canEncode and ns.EncodeUggTalents then
        local ok, s = pcall(ns.EncodeUggTalents, export)
        if ok and s and s ~= "" then return s end
    end
    return nil
end

local function buildUggBuilds(ugg, ref)
    UGGData = UGGData or {}
    local activeClass, activeSpec
    if ns.GetClassAndSpec then
        activeClass, activeSpec = ns.GetClassAndSpec()
    end
    for class, specs in pairs(ugg.data) do
        UGGData[class] = UGGData[class] or {}
        for spec, sd in pairs(specs) do
            if sd.talents then
                local canEncode = (class == activeClass and spec == activeSpec)
                local contexts, overview, encounters = {}, {}, {}
                for heroSlug, byContext in pairs(sd.talents) do
                    local heroDisplay = (ref and ref.heroNames and ref.heroNames[heroSlug]) or heroSlug
                    local tr = sd.tierRank and sd.tierRank[heroSlug]
                    local raidPerf = tr and tr.raid or nil
                    local mplusPerf = tr and tr.mplus or nil
                    for ctxKey, builds in pairs(byContext) do
                        local uggKey, zoneType, difficulty, encounter, label, isOverview =
                            describeUggContext(ctxKey, ref)
                        if uggKey then
                            local perf = (zoneType == "mplus" and mplusPerf)
                                or (zoneType == "raid" and raidPerf)
                                or raidPerf
                                or mplusPerf
                            local heroTier = perf and perf.tier or nil
                            local heroPop = perf and perf.pop or nil
                            local heroWeight = (perf and (perf.pop or perf.count)) or 1
                            local ctx = contexts[uggKey]
                            if not ctx then
                                ctx = {
                                    zoneType = zoneType,
                                    difficulty = difficulty,
                                    encounter = encounter,
                                    encounterLabel = label,
                                    builds = {},
                                }
                                contexts[uggKey] = ctx
                                if isOverview then
                                    overview[#overview + 1] = uggKey
                                else
                                    encounters[#encounters + 1] = uggKey
                                end
                            end
                            for _, b in ipairs(builds) do
                                local export = resolveExport(b.export, canEncode)
                                if export then
                                    ctx.builds[#ctx.builds + 1] = {
                                        exportString = export,
                                        heroTalent = heroDisplay,
                                        pickrate = b.pickrate,
                                        topDps = b.topDps,
                                        heroTier = heroTier,
                                        heroPop = heroPop,
                                        popScore = (b.pickrate or 0) * heroWeight,
                                        honor = b.honor,
                                    }
                                end
                            end
                        end
                    end
                end
                for k, ctx in pairs(contexts) do
                    if #ctx.builds == 0 then
                        contexts[k] = nil
                    else
                        -- Builds are appended hero-by-hero in pairs() order, so
                        -- sort by popularity here: pickrate is a share WITHIN a
                        -- hero, so weight it by how many players run that hero
                        -- (heroPop) to compare builds across heroes. Consumers
                        -- (talent pane, loadout dock, talents section) all treat
                        -- builds[1] as the recommended build.
                        table.sort(ctx.builds, function(a, b)
                            local sa, sb = a.popScore or 0, b.popScore or 0
                            if sa ~= sb then return sa > sb end
                            if (a.pickrate or 0) ~= (b.pickrate or 0) then
                                return (a.pickrate or 0) > (b.pickrate or 0)
                            end
                            return (a.heroTalent or "") < (b.heroTalent or "")
                        end)
                    end
                end
                local order = {}
                for _, k in ipairs(overview) do
                    if contexts[k] then order[#order + 1] = k end
                end
                for _, k in ipairs(encounters) do
                    if contexts[k] then order[#order + 1] = k end
                end
                UGGData[class][spec] = next(contexts) and { contexts = contexts, contextOrder = order } or nil
            end
        end
    end
    if ns.RebuildUggLookups then ns.RebuildUggLookups() end
end

local function icyVeinsTalentBuilds(class, spec)
    local out = {}
    local ivt = ns.GetIcyVeinsTalentSpecData and ns:GetIcyVeinsTalentSpecData(class, spec)
    local builds = ivt and ivt.talents
    if not builds then return out end
    local seen = {}
    -- Content-context filter for the pane: every IV build carries the zone kind
    -- its page context maps to, so PvE builds never leak into a PvP selection
    -- (and vice versa). Leveling builds stay zone-agnostic but are excluded
    -- from PvP by the section's content check.
    local IV_ZONE_KIND = { PvP = "pvp", Raid = "raid", ["Mythic+"] = "mplus", Delves = "mplus", General = "mplus" }
    -- Finer than zoneKind: Delves ride under the M+ content view but get their
    -- own card icon.
    local IV_ART_KIND = { PvP = "pvp", Raid = "raid", ["Mythic+"] = "mplus", Delves = "delve" }
    for _, b in ipairs(builds) do
        local k = (b.heroTalent or "all") .. "\0" .. (b.exportString or "")
        if b.exportString and b.exportString ~= "" and not seen[k] then
            seen[k] = true
            local label = b.buildLabel or b.context or "Build"
            out[#out + 1] = {
                label = label,
                hero = b.heroTalent,
                exportString = b.exportString,
                recommended = b.recommended or false,
                leveling = b.leveling or false,
                tags = b.tags,
                contextId = label .. "\0" .. (b.heroTalent or ""),
                provider = "Icy Veins",
                zoneKind = (not b.leveling) and (IV_ZONE_KIND[b.context] or "mplus") or nil,
                artKind = (not b.leveling) and IV_ART_KIND[b.context] or nil,
                honor = b.honor,
                isPvp = b.context == "PvP",
            }
        end
    end
    return out
end

local function uggTalentBuilds(class, spec)
    local out = {}
    local ugg = ns.GetUggSpecData and ns.GetUggSpecData(class, spec)
    if not ugg or not ugg.contexts then return out end
    local groups = ns.GroupUggContexts(ugg)
    local function push(entry, zoneKind, difficulty, isOverview)
        if not entry then return end
        local ctx = entry.ctx
        if not (ctx.builds and #ctx.builds > 0) then return end
        local label = (ns.GetUggEncounterLabel and ns.GetUggEncounterLabel(ctx)) or "Build"
        local contextId = entry.contextKey or label
        local ranked = {}
        for _, b in ipairs(ctx.builds) do
            if b.exportString and b.exportString ~= "" then ranked[#ranked + 1] = b end
        end
        for idx, b in ipairs(ranked) do
            out[#out + 1] = {
                label = label,
                hero = b.heroTalent,
                exportString = b.exportString,
                recommended = idx == 1,
                pickrate = b.pickrate,
                tier = b.heroTier,
                topDps = b.topDps,
                zoneKind = zoneKind,
                difficulty = difficulty,
                encounterLabel = (not isOverview) and label or nil,
                contextId = contextId,
                provider = "u.gg",
            }
        end
    end
    push(groups.mplusOverview, "mplus", nil, true)
    for _, e in ipairs(groups.mplusDungeons) do
        push(e, "mplus", nil, false)
    end
    push(groups.raidOverviewMythic, "raid", "mythic", true)
    for _, e in ipairs(groups.raidMythicBosses) do
        push(e, "raid", "mythic", false)
    end
    push(groups.raidOverviewHeroic, "raid", "heroic", true)
    for _, e in ipairs(groups.raidHeroicBosses) do
        push(e, "raid", "heroic", false)
    end
    for _, e in ipairs(groups.pvpArena or {}) do
        push(e, "pvp", nil, false)
    end
    for _, e in ipairs(groups.pvpBattleground or {}) do
        push(e, "pvp", nil, false)
    end
    return out
end


-------------------------------------------------------------------------------
-- Bread Codex: talent builds from the locally scraped sources.
--
-- ns.GetTalentBuilds falls through to the u.gg builder for any source it does
-- not recognise, so without these a "Wowhead" pick renders u.gg's builds under
-- a Wowhead label. Both emit the same entry shape uggTalentBuilds does.
-------------------------------------------------------------------------------

-- Wowhead has NO per-encounter data — unlike Archon, none of its contexts name
-- a dungeon or boss. They are slugified BUILD NAMES: "Raid Cleave" -> cleave,
-- "Raid (Standard)" -> standard-raid, "Raid Multitarget" -> mt-raid.
--
-- So classify from the human label AND the slug, because neither alone is
-- reliable: `cleave` and `council` are raid builds whose slug says nothing, and
-- `st-raid`'s label is just "Single Target". A slug-prefix table got 6 of the
-- 21 real contexts wrong, filing raid builds under Mythic+.
--
-- Genuinely ambiguous rows ("Single Target", "Single Target/Cleave") return nil,
-- which Sections/Talents.lua treats as "show under every content filter" —
-- better than guessing and hiding a build from the tab it belongs to.
local function wowheadZone(ctx, label)
    local hay = ((label or "") .. " " .. (ctx or "")):lower()
    if hay:find("pvp", 1, true) then return "pvp" end
    if hay:find("raid", 1, true) then return "raid" end
    if hay:find("delve", 1, true) then return "mplus", "delve" end
    if hay:find("m+", 1, true) or hay:find("mythic", 1, true)
        or hay:find("mplus", 1, true) then return "mplus" end
    if hay:find("open world", 1, true) or hay:find("open-world", 1, true) then return "mplus" end
    return nil
end
ns.WowheadZoneFor = wowheadZone

local function wowheadTalentBuilds(class, spec)
    local out = {}
    -- Raw, not merged: this source IS the fill source, so a merged view would
    -- fold the base's builds back in and double them up.
    local sd = ns.RawSourceSpec and ns.RawSourceSpec("wowhead", class, spec)
    if not (sd and sd.talents) then return out end
    for hero, byCtx in pairs(sd.talents) do
        if type(byCtx) == "table" then
            for ctx, list in pairs(byCtx) do
                if type(list) == "table" then
                    for _, b in ipairs(list) do
                        if type(b) == "table" and b.export and b.export ~= "" then
                            -- Keep the page's verbatim Build Name (Holy Paladin
                            -- ships "Raid - Virtue" / "Raid - Faith"); collapsing
                            -- to the context would merge distinct rows.
                            local label = b.label or ctx
                            local zone, art = wowheadZone(ctx, b.label)
                            local best = type(b.recommended) == "string" and b.recommended or nil
                            out[#out + 1] = {
                                label = best and (label .. " (" .. best .. ")") or label,
                                hero = hero ~= "all" and hero or nil,
                                exportString = b.export,
                                recommended = b.recommended ~= nil and b.recommended ~= false,
                                zoneKind = zone,
                                artKind = art,
                                contextId = ctx .. "\0" .. hero,
                                provider = "Wowhead",
                            }
                        end
                    end
                end
            end
        end
    end
    return out
end

local function titleCase(slug)
    local words = {}
    for w in tostring(slug):gmatch("[^-]+") do
        words[#words + 1] = w:sub(1, 1):upper() .. w:sub(2)
    end
    return table.concat(words, " ")
end

local function archonTalentBuilds(class, spec)
    local out = {}
    local sd = ns.RawSourceSpec and ns.RawSourceSpec("archongg", class, spec)
    if not (sd and sd.talents) then return out end
    for hero, byCtx in pairs(sd.talents) do
        if type(byCtx) == "table" then
            for ctx, list in pairs(byCtx) do
                if type(list) == "table" then
                    -- "mplus", "mplus:altar-of-fangs", "raid:heroic:the-twin-fangs"
                    local zone, seg2, seg3 = ctx:match("^([^:]+):?([^:]*):?(.*)$")
                    local zoneKind = (zone == "raid") and "raid" or (zone == "pvp" and "pvp" or "mplus")
                    local diffLabel, encounter
                    if zone == "raid" then
                        if seg3 ~= "" then diffLabel, encounter = seg2, seg3 else encounter = seg2 end
                    else
                        encounter = seg2
                    end
                    if encounter == "" then encounter = nil end
                    local encLabel = encounter and titleCase(encounter) or nil
                    for _, b in ipairs(list) do
                        if type(b) == "table" and b.export and b.export ~= "" then
                            -- popularity ships as a string ("52.4%"); the build
                            -- list does `pickrate > 0`, so hand it a number or
                            -- it errors comparing string with number.
                            local pick = tonumber(tostring(b.popularity or ""):match("([%d%.]+)") or "")
                            local label = b.label or encLabel or "Build"
                            if diffLabel and diffLabel ~= "" then
                                label = label .. " (" .. titleCase(diffLabel) .. ")"
                            end
                            out[#out + 1] = {
                                label = label,
                                hero = hero ~= "all" and hero or nil,
                                exportString = b.export,
                                -- Archon's own "Recommended Class Tree" is often
                                -- not the most-played build, so flag its pick
                                -- explicitly rather than assuming rank 1.
                                recommended = type(b.label) == "string"
                                    and b.label:find("Recommended", 1, true) ~= nil,
                                pickrate = pick,
                                zoneKind = zoneKind,
                                -- difficulty deliberately left nil: Archon raid
                                -- data is Heroic, and the pane defaults to
                                -- Mythic, which would filter every row away.
                                encounterLabel = encLabel,
                                contextId = ctx .. "\0" .. hero,
                                provider = "Archon",
                            }
                        end
                    end
                end
            end
        end
    end
    return out
end

function ns.GetTalentBuilds(class, spec, source)
    if source == "icyveins" then
        local builds = icyVeinsTalentBuilds(class, spec)
        local hasPvp = false
        for _, b in ipairs(builds) do
            if b.isPvp then
                hasPvp = true
                break
            end
        end
        -- Specs without an Icy Veins PvP guide (the tanks) borrow u.gg's PvP
        -- builds so the list isn't empty; those cards carry a u.gg badge.
        if not hasPvp then
            for _, b in ipairs(uggTalentBuilds(class, spec)) do
                if b.zoneKind == "pvp" then builds[#builds + 1] = b end
            end
        end
        return builds
    end
    if source == "wowhead" then return wowheadTalentBuilds(class, spec) end
    if source == "archongg" then return archonTalentBuilds(class, spec) end
    return uggTalentBuilds(class, spec)
end

local function rebuild()
    local src = ClassCodexSource
    if not src then return end
    if src.icyveins then buildClassCodexData(src.icyveins) end
    if src.ugg then buildUggBuilds(src.ugg, src.ugg.reference) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:SetScript("OnEvent", rebuild)
