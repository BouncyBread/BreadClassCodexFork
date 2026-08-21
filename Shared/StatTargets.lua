local _, ns = ...

ns.STAT_KEYS = { "crit", "haste", "mastery", "versatility" }

ns.STAT_LABELS = {
    crit = "Critical Strike",
    haste = "Haste",
    mastery = "Mastery",
    versatility = "Versatility",
}

ns.STAT_KEY_FROM_LABEL = {}
for key, label in pairs(ns.STAT_LABELS) do
    ns.STAT_KEY_FROM_LABEL[label] = key
end

ns.UNIVERSAL_DR = {
    crit = 1380,
    haste = 1320,
    mastery = 1380,
    versatility = 1620,
}

ns.DR_BRACKETS = {
    { pct = 30, mult = 1.00 },
    { pct = 39, mult = 0.90 },
    { pct = 47, mult = 0.80 },
    { pct = 54, mult = 0.70 },
    { pct = 66, mult = 0.60 },
    { pct = math.huge, mult = 0.50 },
}

function ns.GetMarginalDR(currentPct)
    if not currentPct or currentPct <= 0 then return 1 end
    for _, b in ipairs(ns.DR_BRACKETS) do
        if currentPct < b.pct then return b.mult end
    end
    return 0.5
end

local function NormalizeContext(ctx)
    if not ctx then return nil end
    local lc = ctx:lower()
    if lc:find("pvp") then return "PvP" end
    if lc:find("raid") then return "Raid" end
    if lc:find("mythic+") or lc:find("m+") or lc:find("dungeon") then return "Mythic+" end
    return nil
end

local function ActiveHeroSlug()
    local display = ns.GetActiveHeroTalentName and ns.GetActiveHeroTalentName()
    return ns.HeroSlugFromDisplay and ns.HeroSlugFromDisplay(display) or nil
end

function ns.HeroSlugFromDisplay(display)
    if not display or display == "" or display == "All" then return "all" end
    local hn = ClassCodexSource
        and ClassCodexSource.ugg
        and ClassCodexSource.ugg.reference
        and ClassCodexSource.ugg.reference.heroNames
    if hn then
        for slug, name in pairs(hn) do
            if name == display then return slug end
        end
    end
    return display:lower():gsub(" ", "-")
end

function ns.GetStatTargets(classToken, specKey, context, source, heroSlug)
    if not classToken or not specKey then return nil end
    local normalized = NormalizeContext(context)
    if not normalized then return nil end

    local ctx = (normalized == "Mythic+") and "mplus" or (normalized == "PvP") and "pvp" or "raid"
    -- An explicit slug (the pane/compendium hero selection) wins; otherwise the
    -- in-game active hero for the player's own spec, else the aggregate.
    local hero = heroSlug
    if not hero then
        hero = "all"
        local pc, ps
        if ns.GetClassAndSpec then
            pc, ps = ns.GetClassAndSpec()
        end
        if pc == classToken and ps == specKey then hero = ActiveHeroSlug() or "all" end
    end

    source = source or (ns.ActiveSource and ns.ActiveSource())
    local targets = ns.SourceValue and ns.SourceValue(source, classToken, specKey, "statTargets", hero, ctx)
    if not targets and source ~= "ugg" then
        targets = ns.SourceValue and ns.SourceValue("ugg", classToken, specKey, "statTargets", hero, ctx)
    end
    if not targets then return nil end
    return { targets = targets }
end

local STAT_PRIORITY_DISPLAY =
    { crit = "Critical Strike", haste = "Haste", mastery = "Mastery", versatility = "Versatility" }

local function resolveStatPriority(classToken, specKey, context, source, heroSlug)
    if not classToken or not specKey then return nil end
    local hero = heroSlug
    if not hero then
        hero = "all"
        local pc, ps
        if ns.GetClassAndSpec then
            pc, ps = ns.GetClassAndSpec()
        end
        if pc == classToken and ps == specKey then hero = ActiveHeroSlug() or "all" end
    end
    source = source or (ns.ActiveSource and ns.ActiveSource())
    local sp = ns.SourceValue and ns.SourceValue(source, classToken, specKey, "statPriority", hero, context or "all")
    if
        not (sp and sp.secondary)
        and context == "pvp"
        and ns.HasPvpGuide
        and not ns.HasPvpGuide(source, classToken, specKey)
    then
        return nil
    end
    if not (sp and sp.secondary) and context and context ~= "all" then
        sp = ns.SourceValue and ns.SourceValue(source, classToken, specKey, "statPriority", hero, "all")
    end
    if not (sp and sp.secondary) then return nil end
    return sp
end

function ns.GetStatPriority(classToken, specKey, context, source, heroSlug)
    local sp = resolveStatPriority(classToken, specKey, context, source, heroSlug)
    if not sp then return nil end
    local tiers = {}
    for _, tier in ipairs(sp.secondary) do
        local names = {}
        for _, k in ipairs(tier) do
            -- Qualified entries ({stat="haste",note="to 22%"}) carry an upstream
            -- breakpoint ("Haste to 22%"); plain strings are bare keys.
            local base, note = k, nil
            if type(k) == "table" then
                base, note = k.stat, k.note
            end
            local name = STAT_PRIORITY_DISPLAY[base] or base
            if note and note ~= "" then name = name .. " " .. note end
            names[#names + 1] = name
        end
        if #names > 0 then tiers[#tiers + 1] = names end
    end
    return #tiers > 0 and tiers or nil
end

--- Qualified breakpoint entries in a spec's priority ("Haste to 22%",
--- "Haste (until 1800 rating)"), keyed by display name:
--- { statKey, tier, kind = "pct"|"rating", value }. While the player is below
--- the threshold the stat ranks at the qualified tier; from the threshold up,
--- its bare tier (if any) applies. Notes without a readable threshold are
--- ignored — there is no value to compare against.
function ns.GetStatBreakpoints(classToken, specKey, context, source, heroSlug)
    local sp = resolveStatPriority(classToken, specKey, context, source, heroSlug)
    if not sp then return nil end
    local out
    for i, tier in ipairs(sp.secondary) do
        for _, k in ipairs(tier) do
            if type(k) == "table" and k.stat then
                local note = k.note or ""
                -- Percent thresholds ("to 22%") compare against the player's
                -- stat percent; explicit ratings ("until 1800 rating") and bare
                -- "to N" numbers ("to 700+", "to 200") against the rating.
                local kind, value
                local pct = note:match("(%d+%.?%d*)%s*%%")
                local rating = note:match("(%d+)%s*rating") or note:match("to%s+(%d+)")
                if pct then
                    kind, value = "pct", tonumber(pct)
                elseif rating then
                    kind, value = "rating", tonumber(rating)
                end
                if kind then
                    out = out or {}
                    out[STAT_PRIORITY_DISPLAY[k.stat] or k.stat] =
                        { statKey = k.stat, tier = i, kind = kind, value = value }
                end
            end
        end
    end
    return out
end

local function safeNum(v)
    if type(v) == "number" then return v end
    return 0
end

-- Player stat readings are refreshed out of combat and served from cache while
-- in combat, so panels/tooltips render consistently mid-fight instead of
-- fluctuating with procs (or blanking out behind a combat warning).
local PLAYER_STAT_READERS = {
    crit = function()
        return safeNum(GetCombatRating(CR_CRIT_MELEE)), safeNum(GetCritChance())
    end,
    haste = function()
        return safeNum(GetCombatRating(CR_HASTE_MELEE)), safeNum(GetHaste())
    end,
    mastery = function()
        return safeNum(GetCombatRating(CR_MASTERY)), safeNum(GetMasteryEffect())
    end,
    versatility = function()
        return safeNum(GetCombatRating(CR_VERSATILITY_DAMAGE_DONE)),
            safeNum(GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE))
    end,
}

local playerStatCache = {}

local function readPlayerStat(statKey)
    local read = PLAYER_STAT_READERS[statKey]
    if not read then return 0, 0 end
    if not InCombatLockdown() then
        local rating, pct = read()
        playerStatCache[statKey] = { rating = rating, pct = pct }
        return rating, pct
    end
    local cached = playerStatCache[statKey]
    if cached then return cached.rating, cached.pct end
    -- No pre-combat snapshot yet (e.g. reload during a pull) — a live read is
    -- still better than zeros.
    return read()
end

function ns.GetPlayerStatRating(statKey)
    return (readPlayerStat(statKey))
end

function ns.GetPlayerStatPercent(statKey)
    local _, pct = readPlayerStat(statKey)
    return pct
end

function ns.ClassifyStatDelta(currentRating, targetRating)
    if not targetRating or targetRating <= 0 then return nil, 0 end
    local diff = currentRating - targetRating
    local pct = (diff / targetRating) * 100
    if math.abs(pct) < 5 then
        return "at", pct
    elseif pct > 0 then
        return "above", pct
    else
        return "below", pct
    end
end

local STATE_COLORS = {
    above = { 0.40, 0.70, 1.00 },
    at = { 0.40, 1.00, 0.45 },
    below = { 1.00, 0.40, 0.40 },
}

function ns.AppendStatExtrasToTooltip(tooltip, statKey, snapshot, opts)
    if not tooltip or not statKey then return end
    opts = opts or {}
    local label = ns.STAT_LABELS[statKey] or statKey
    local current = ns.GetPlayerStatRating(statKey) or 0
    local livePct = ns.GetPlayerStatPercent(statKey) or 0
    local target = snapshot and snapshot.targets and snapshot.targets[statKey]

    local COLORS = ns.Tooltip.COLORS

    if opts.includeTitle then
        local ct = COLORS.title
        tooltip:AddLine(label, ct[1], ct[2], ct[3])
        local cl, cr = COLORS.intro, COLORS.muted
        tooltip:AddDoubleLine(
            string.format("%.1f%%", livePct),
            string.format("%d rating", current),
            cl[1],
            cl[2],
            cl[3],
            cr[1],
            cr[2],
            cr[3]
        )
    end

    if not opts.omitTarget and target and target > 0 then
        if opts.includeTitle then tooltip:AddLine(" ") end
        local cl, cr = COLORS.muted, COLORS.intro
        tooltip:AddDoubleLine("Target", string.format("%d", target), cl[1], cl[2], cl[3], cr[1], cr[2], cr[3])
        local kind = ns.ClassifyStatDelta(current, target) or "below"
        local diff = current - target
        local sign = (diff >= 0) and "+" or "−"
        local stateLabels = {
            above = "Above target",
            at = "At target",
            below = "Below target",
        }
        local c = STATE_COLORS[kind]
        tooltip:AddDoubleLine(
            stateLabels[kind],
            string.format("%s%d", sign, math.abs(diff)),
            c[1],
            c[2],
            c[3],
            c[1],
            c[2],
            c[3]
        )
    end
end
