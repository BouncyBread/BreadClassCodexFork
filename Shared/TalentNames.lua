local _, ns = ...

-- Canonical loadout name for a talent build: Save-as-loadout defaults and the
-- apply rename both go through this so every surface names a build the same
-- way. Row fields: provider, hero, label, difficulty (nil except raid boss
-- rows, where it distinguishes mythic from heroic).
function ns.BuildLoadoutName(row)
    local source = row.provider
    if source == "u.gg" and ns.SOURCES and ns.SOURCES.ugg then source = ns.SOURCES.ugg.name end

    local hero = row.hero
    local body = row.label or "Build"
    if row.difficulty and row.difficulty ~= "" then body = body .. " " .. row.difficulty:gsub("^%l", string.upper) end
    local name = (hero and hero ~= "" and hero ~= "All") and (hero .. " " .. body) or body

    if source and source ~= "" then return source .. " - " .. name end
    return name
end
