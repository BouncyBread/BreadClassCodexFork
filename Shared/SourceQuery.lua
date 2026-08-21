local _, ns = ...

local WILDCARD = "all"

function ns.QuerySources(category, class, spec)
    if not class then
        class, spec = ns.GetClassAndSpec()
    end
    local out = {}
    if not (class and spec) then return out end
    for _, source in ipairs(ns.Sources()) do
        if ns.SourceHas(source, class, spec, category) then out[#out + 1] = source end
    end
    return out
end

local VARIANT_LABEL = { mplus = "Mythic+", raid = "Raid", all = "Overall" }
function ns.GearVariants(class, spec, source, contentType)
    if not class then
        class, spec = ns.GetClassAndSpec()
    end
    contentType = contentType or (ns.Context and ns.Context.contentType())
    local sd = ns.SourceSpec(source, class, spec)
    local gear = sd and sd.gear and sd.gear["all"]
    local out = {}
    if not (gear and contentType) then return out end
    if contentType == "pvp" or contentType:sub(1, 4) == "pvp:" then
        local ctx = contentType
        if ctx == "pvp" and not gear.pvp then
            ctx = nil
            for c in pairs(gear) do
                if c:sub(1, 4) == "pvp:" and (not ctx or c < ctx) then ctx = c end
            end
        end
        if ctx and gear[ctx] then out[#out + 1] = { context = ctx, label = "PvP" } end
        return out
    end
    if gear[contentType] then
        out[#out + 1] = { context = contentType, label = VARIANT_LABEL[contentType] or contentType }
    end
    if gear["all"] then out[#out + 1] = { context = "all", label = VARIANT_LABEL.all } end
    return out
end

local CONTENT_ORDER = { "all", "mplus", "raid", "pvp:2v2", "pvp:3v3", "pvp:shuffle", "pvp:blitz", "pvp:rbg" }

function ns.QueryContentTypes(category, class, spec, source)
    if not class then
        class, spec = ns.GetClassAndSpec()
    end
    local seen = {}
    if class and spec then
        local sources = source and { source } or ns.Sources()
        for _, s in ipairs(sources) do
            local sd = ns.SourceSpec(s, class, spec)
            local cat = sd and sd[category]
            if cat then
                for _, byContext in pairs(cat) do
                    for context in pairs(byContext) do
                        seen[context] = true
                    end
                end
            end
        end
    end
    local out = {}
    for _, c in ipairs(CONTENT_ORDER) do
        if seen[c] then
            out[#out + 1] = c
            seen[c] = nil
        end
    end
    for c in pairs(seen) do
        out[#out + 1] = c
    end

    if #out > 1 then
        for i, c in ipairs(out) do
            if c == WILDCARD then
                table.remove(out, i)
                break
            end
        end
    end
    return out
end
