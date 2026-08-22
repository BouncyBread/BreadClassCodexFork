local _, ns = ...

local WILDCARD = "all"

local function rawSpec(source, class, spec)
    local src = ClassCodexSource and ClassCodexSource[source]
    local byClass = src and src.data and src.data[class]
    return byClass and byClass[spec] or nil
end
ns.RawSourceSpec = rawSpec

-- Bread Codex substitution model
-- ------------------------------
-- Upstream's shipped data (Icy Veins / u.gg) is the BASE. The locally scraped
-- sources FILL gaps in it — they never overwrite a value upstream already has.
-- Substitution happens here, at the spec-table level, because the sections read
-- whole spec tables via ns.SourceSpec rather than going leaf-by-leaf through
-- ns.SourceValue; merging here means every section inherits the behaviour
-- without touching its own lookup code.
--
-- Merge is per-leaf at category -> hero -> context depth. A category upstream
-- lacks entirely is adopted wholesale; a category it has gains only the
-- hero/context combinations it is missing. Nothing is mutated in place: the
-- merged view is built into fresh tables so ClassCodexSource stays pristine.
local BASE_SOURCES = { icyveins = true, ugg = true }
local FILL_SOURCES = { "wowhead", "archongg" }

-- Substitution applies to DATA, never to a source's own bookkeeping. `links`
-- is per-source attribution (adopting Archon's would make a u.gg page cite
-- archon.gg), and `archonContexts` is Archon's private encounter index that
-- only its own UI knows how to read.
local NON_SUBSTITUTABLE = { links = true, archonContexts = true }
ns.BASE_SOURCES, ns.FILL_SOURCES = BASE_SOURCES, FILL_SOURCES

-- Provenance lives OUTSIDE the merged data, never as an extra key inside it:
-- the sections iterate these tables with pairs(), so a bookkeeping key would
-- show up as a bogus hero or context.
local mergedCache, provenance = {}, {}

local function cacheKey(source, class, spec)
    return source .. "\0" .. class .. "\0" .. spec
end

local function mergeSpec(source, class, spec)
    local base = rawSpec(source, class, spec)
    local prov = {}
    local out, dirty = nil, false

    for _, fill in ipairs(FILL_SOURCES) do
        local fsd = fill ~= source and rawSpec(fill, class, spec) or nil
        if fsd then
            for category, fByHero in pairs(fsd) do
                if type(fByHero) == "table" and not NON_SUBSTITUTABLE[category] then
                    local bByHero = base and base[category]
                    if bByHero == nil then
                        -- Upstream has no such category at all: adopt it whole.
                        out = out or {}
                        out[category] = fByHero
                        prov[category] = prov[category] or {}
                        prov[category]["*"] = fill
                        dirty = true
                    elseif type(bByHero) == "table" then
                        for hero, fByCtx in pairs(fByHero) do
                            if type(fByCtx) == "table" then
                                local bByCtx = bByHero[hero]
                                for ctx, val in pairs(fByCtx) do
                                    if bByCtx == nil or bByCtx[ctx] == nil then
                                        out = out or {}
                                        local oByHero = out[category]
                                        if oByHero == nil then
                                            oByHero = {}
                                            for h, v in pairs(bByHero) do oByHero[h] = v end
                                            out[category] = oByHero
                                        end
                                        local oByCtx = oByHero[hero]
                                        -- Copy-on-write: the base's own context
                                        -- table must not gain foreign entries.
                                        if oByCtx == nil or oByCtx == bByCtx then
                                            local copy = {}
                                            if bByCtx then
                                                for c, v in pairs(bByCtx) do copy[c] = v end
                                            end
                                            oByCtx = copy
                                            oByHero[hero] = copy
                                        end
                                        oByCtx[ctx] = val
                                        prov[category] = prov[category] or {}
                                        prov[category][hero .. "\0" .. ctx] = fill
                                        dirty = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if not dirty then return base, nil end

    -- Carry across every base category the fill pass did not touch.
    local merged = {}
    if base then
        for k, v in pairs(base) do merged[k] = v end
    end
    for k, v in pairs(out) do merged[k] = v end
    return merged, prov
end

function ns.SourceSpec(source, class, spec)
    if not (source and class and spec) then return nil end
    if not BASE_SOURCES[source] then return rawSpec(source, class, spec) end
    local key = cacheKey(source, class, spec)
    local hit = mergedCache[key]
    if hit ~= nil then
        if hit == false then return nil end
        return hit
    end
    local merged, prov = mergeSpec(source, class, spec)
    mergedCache[key] = merged == nil and false or merged
    provenance[key] = prov
    return merged
end

--- Which source actually supplied a category/hero/context under a base source,
--- or nil when it came from the base itself. Lets the UI badge substituted data.
function ns.FilledFrom(source, class, spec, category, hero, context)
    if not (source and class and spec and category) then return nil end
    local prov = provenance[cacheKey(source, class, spec)]
    local byCat = prov and prov[category]
    if not byCat then return nil end
    if byCat["*"] then return byCat["*"] end
    if hero and context then return byCat[hero .. "\0" .. context] end
    return nil
end

--- Drop the merged views. Call if ClassCodexSource is ever rebuilt at runtime.
function ns.ResetSourceMerge()
    mergedCache, provenance = {}, {}
end

--- True when the source carries ANY PvP-context data for the spec — i.e. the
--- spec "has a PvP guide" there. Guide-less specs show the PvP empty screen
--- instead of borrowed or PvE data.
function ns.HasPvpGuide(source, class, spec)
    local sd = ns.SourceSpec(source, class, spec)
    if not sd then return false end
    for _, cat in ipairs({ "gear", "enchants", "gems", "trinkets", "statPriority", "rotation", "talents", "crafting" }) do
        local byHero = sd[cat]
        if type(byHero) == "table" then
            for _, byCtx in pairs(byHero) do
                if type(byCtx) == "table" then
                    for ctx in pairs(byCtx) do
                        if ctx == "pvp" or ctx:sub(1, 4) == "pvp:" then return true end
                    end
                end
            end
        end
    end
    return false
end

function ns.LastUpdated()
    local best
    if ClassCodexSource then
        for _, src in pairs(ClassCodexSource) do
            local g = type(src) == "table" and src.meta and src.meta.generatedAt
            if type(g) == "string" and (not best or g > best) then best = g end
        end
    end
    return best and best:sub(1, 10) or nil
end

-- Sources disagree on context spelling for the same content. Wowhead splits
-- raid into "raid-st" / "raid-cleave" and pluralises delves; upstream emits
-- bare "raid" and singular "delve". These aliases let a value from one source
-- satisfy a lookup phrased in another's vocabulary, which is what makes the
-- cross-source substitution below actually hit rather than silently miss.
local CONTEXT_ALIAS = {
    delves = "delve",
    delve = "delves",
}

local function contextChain(context)
    local chain = { context }
    local sep = context:find(":", 1, true)
    if sep then chain[#chain + 1] = context:sub(1, sep - 1) end
    -- "raid-st" / "raid-cleave" -> "raid". Hyphen splits are a Wowhead-ism, so
    -- they are tried after the colon split and before the wildcard.
    local dash = context:find("-", 1, true)
    if dash then chain[#chain + 1] = context:sub(1, dash - 1) end
    local alias = CONTEXT_ALIAS[context]
    if alias then chain[#chain + 1] = alias end
    -- Generic pvp falls back to the shuffle bracket, so data emitted with
    -- bracket-specific contexts (multi-bracket fetch) still resolves.
    if context == "pvp" then chain[#chain + 1] = "pvp:shuffle" end
    local isPvp = context == "pvp" or context:sub(1, 4) == "pvp:"
    if context ~= WILDCARD and not isPvp then chain[#chain + 1] = WILDCARD end
    return chain
end
ns.ContextChain = contextChain

function ns.ResolveCategory(category, hero, context)
    if not category then return nil end
    local heroes = hero == WILDCARD and { WILDCARD } or { hero, WILDCARD }
    for _, ctx in ipairs(contextChain(context)) do
        for _, h in ipairs(heroes) do
            local byContext = category[h]
            if byContext and byContext[ctx] ~= nil then return byContext[ctx], h, ctx end
        end
    end
    return nil
end

function ns.SourceValue(source, class, spec, category, hero, context)
    local sd = ns.SourceSpec(source, class, spec)
    return sd and ns.ResolveCategory(sd[category], hero or WILDCARD, context or WILDCARD) or nil
end

function ns.ActiveSource()
    local s = ns.Context and ns.Context.source()
    if s and ClassCodexSource and ClassCodexSource[s] then return s end
    return (ns.Sources())[1] or "icyveins"
end

function ns.SourceHas(source, class, spec, category)
    local sd = ns.SourceSpec(source, class, spec)
    return sd ~= nil and sd[category] ~= nil
end

local DEFAULT_PRIORITY = { "icyveins", "ugg", "wowhead", "archongg" }

--- The user-selectable sources, in picker order.
---
--- Wowhead and Archon are BOTH pickable sources here AND fill sources for the
--- bases above — the two roles are independent. Picking them shows their own
--- data (see wowheadTalentBuilds / archonTalentBuilds in SourceReader.lua);
--- leaving them unpicked still lets ns.SourceSpec fill gaps in Icy Veins/u.gg.
---
--- They may only be listed while SourceReader has a builder for each: ns.
--- GetTalentBuilds falls through to the u.gg builder for any source it does not
--- recognise, so an unbuilt source renders u.gg's builds under its own name.
function ns.Sources()
    local order, seen = {}, {}
    if not ClassCodexSource then return order end
    for _, s in ipairs(DEFAULT_PRIORITY) do
        if ClassCodexSource[s] then
            order[#order + 1] = s
            seen[s] = true
        end
    end
    for s in pairs(ClassCodexSource) do
        if not seen[s] then order[#order + 1] = s end
    end
    return order
end
