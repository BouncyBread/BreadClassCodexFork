local _, ns = ...

local PREFIX = "|cff00ccffClass Codex|r "
local function green(s)
    return "|cff40ff40" .. s .. "|r"
end
local function red(s)
    return "|cffff5555" .. s .. "|r"
end

local function count(t)
    if type(t) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

local function line(label, ok, detail)
    print("  " .. (ok and green("OK  ") or red("--  ")) .. label .. (detail and (" — " .. detail) or ""))
end

local function specCount(root)
    if type(root) ~= "table" then return 0 end
    local n = 0
    for _, specs in pairs(root) do
        n = n + count(specs)
    end
    return n
end

function ns.RunSelfTest()
    local class, spec
    if ns.GetClassAndSpec then
        class, spec = ns.GetClassAndSpec()
    end
    if not class or not spec then
        print(PREFIX .. red("could not resolve your class/spec — open the panel once, then retry."))
        return
    end
    print(PREFIX .. "self-test for " .. green(class .. " / " .. spec) .. ":")

    local gear = ns.GetBisGearData and ns.GetBisGearData("ugg", class, spec)
    local bisTabs = gear and gear.bisGear
    line("Gear (U.GG)", bisTabs and #bisTabs > 0, bisTabs and (#bisTabs .. " tabs") or nil)

    local gd = ns.GetSpecGearData and ns.GetSpecGearData(class, spec)
    local enchants = gd and gd.enchants
    line("Enchants", enchants and #enchants > 0, enchants and (#enchants .. " slots") or nil)
    local gems = gd and gd.gems
    line(
        "Gems (U.GG)",
        gems and (gems.primary or (gems.secondary and #gems.secondary > 0)),
        gems and gems.primary and "primary + " .. count(gems.secondary) .. " secondary" or nil
    )
    line(
        "Trinkets (U.GG)",
        gd and gd.trinkets and #gd.trinkets > 0,
        gd and gd.trinkets and (#gd.trinkets .. " ranked") or nil
    )

    local data = _G.IcyVeinsData and _G.IcyVeinsData[class] and _G.IcyVeinsData[class][spec]
    line("Stat priority (Icy Veins)", data and data.priorities and #data.priorities > 0)
    line(
        "Rotation (Icy Veins)",
        data and data.rotation and #data.rotation > 0,
        data and data.rotation and (#data.rotation .. " builds") or nil
    )

    local uggBuilds = _G.UGGData and _G.UGGData[class] and _G.UGGData[class][spec]
    line("Talents (U.GG)", uggBuilds and uggBuilds.contexts and next(uggBuilds.contexts) ~= nil)
    local ivT = ns.GetIcyVeinsTalentSpecData and ns:GetIcyVeinsTalentSpecData(class, spec)
    line("Talents (Icy Veins)", ivT and ivT.talents and #ivT.talents > 0)

    line(
        "Crafting (U.GG + Icy Veins)",
        (
            ns.SourceHas
            and (ns.SourceHas("ugg", class, spec, "crafting") or ns.SourceHas("icyveins", class, spec, "crafting"))
        ) or false
    )
    line("PvP (U.GG)", (ns.HasPvPData and ns.HasPvPData(class, spec)) or false)

    local emb = ClassCodexGameData and ClassCodexGameData.embellishments and ClassCodexGameData.embellishments.effects
    line("Embellishment effect map", emb and count(emb) > 0, emb and (count(emb) .. " items") or nil)

    local cov = {}
    for _, src in ipairs(ns.Sources and ns.Sources() or {}) do
        cov[#cov + 1] = src .. " " .. specCount(ClassCodexSource[src] and ClassCodexSource[src].data)
    end
    print(PREFIX .. "coverage across all specs: " .. table.concat(cov, ", "))
end
