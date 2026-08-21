local _, ns = ...

function ns.GroupBuildsByHero(talents)
    local heroOrder, heroBuilds = {}, {}
    if not talents then return heroOrder, heroBuilds end
    for _, t in ipairs(talents) do
        local hero = t.heroTalent
        if not heroBuilds[hero] then
            heroBuilds[hero] = {}
            heroOrder[#heroOrder + 1] = hero
        end
        heroBuilds[hero][#heroBuilds[hero] + 1] = t
    end
    return heroOrder, heroBuilds
end

local TIER_COLORS = {
    S = "ffff6a00",
    A = "ffffd200",
    B = "ff4fd14f",
    C = "ffb0b0b0",
    D = "ff909090",
    F = "ff808080",
}

local function FormatTierBadge(tier, pop)
    if not tier or tier == "" then return "" end
    local color = TIER_COLORS[tier:sub(1, 1):upper()] or "ffb0b0b0"
    local badge = "  |c" .. color .. tier .. "|r"
    if pop then badge = badge .. " |cff808080" .. pop .. "%|r" end
    return badge
end

function ns.FormatHeroHeaderText(hero, tier, pop)
    local L = ns.L
    local displayHero = (hero == "All" and L and L["settings.header.general"]) or (hero == "All" and "General") or hero
    local atlas = ns.HERO_TALENT_ATLAS and ns.HERO_TALENT_ATLAS[hero]
    local badge = FormatTierBadge(tier, pop)
    if atlas then return "|A:" .. atlas .. ":14:14|a " .. displayHero .. badge end
    return displayHero .. badge
end

function ns.FormatBuildLabel(build)
    local context = build.context
    local buildLabel = build.buildLabel
    local label
    if buildLabel and buildLabel ~= "" then
        if not context or context == "" or buildLabel:lower():find(context:lower(), 1, true) then
            label = buildLabel
        else
            label = context .. " — " .. buildLabel
        end
    else
        label = context or "Build"
    end
    if build.recommended then label = label .. "  |cff1abc3cRecommended|r" end
    return label
end

function ns.BuildStatSuffix(build)
    local suffix = ""
    if build.pickrate and build.pickrate > 0 then suffix = suffix .. " |cff808080" .. build.pickrate .. "%|r" end
    if build.topDps then suffix = suffix .. " |cffffd200★ top dps|r" end
    return suffix
end

function ns.ExtractTalentBits(exportString)
    if not exportString or not ExportUtil or not ExportUtil.MakeImportDataStream then return nil end
    local ok, stream = pcall(ExportUtil.MakeImportDataStream, exportString)
    if not ok or not stream then return nil end

    for _ = 1, 19 do
        pcall(stream.ExtractValue, stream, 8)
    end
    -- Read the entire content bitstream: capping at 500 bits truncated the
    -- tail of the string (hero-tree selections serialize last), which made
    -- different builds compare as equal.
    local bits = {}
    for _ = 1, 4096 do
        local bok, val = pcall(stream.ExtractValue, stream, 1)
        if not bok then break end
        bits[#bits + 1] = val
    end
    return table.concat(bits)
end

-- forcePlayerConfig: the apply pipeline and other non-pane consumers must
-- never read through the inspect override. A stale inspect flag made them
-- call C_Traits.GenerateImportString with the inspect sentinel config (-1),
-- which hard-crashes the client (pcall cannot catch a native fault).
function ns.GetActiveTalentSignature(forcePlayerConfig)
    if not C_Traits or not C_Traits.GenerateImportString then return nil end
    local configID
    if ns._talentPaneInspect and not forcePlayerConfig then
        -- Only read the inspect config while an inspect is actually open;
        -- otherwise fall through to the player's config.
        local inspecting = PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting()
        if inspecting then
            local tf = PlayerSpellsFrame.TalentsFrame
            if tf and tf.GetConfigID then
                local ok, id = pcall(tf.GetConfigID, tf)
                if ok then configID = id end
            end
            if not configID then
                configID = (Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID)
            end
        end
    end
    if not configID then
        if not C_ClassTalents or not C_ClassTalents.GetActiveConfigID then return nil end
        configID = C_ClassTalents.GetActiveConfigID()
    end
    if not configID then return nil end
    local ok, str = pcall(C_Traits.GenerateImportString, configID)
    if not ok or not str then return nil end
    return ns.ExtractTalentBits(str)
end
