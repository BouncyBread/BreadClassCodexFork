local _, ns = ...

if not C_ClassTalents or not C_Traits then return end

local ICON_SIZE = 48
local CONTAINER_ICON_SIZE = 40 -- selector height stays at the original pre-icon-bump size
local SOURCE_DROPDOWN_WIDTH = 240
local BUILD_DROPDOWN_WIDTH = 262
local BADGE_SIZE = 20
local ICON_GAP = 6
local CONTAINER_PADDING_X = 8
local CONTAINER_PADDING_Y = 6
local REVEAL_DURATION = 0.18
local REVEAL_SLIDE_DX = 22

local GLOW_INSET = 3
local GLOW_ALPHA = 0.45
local GLOW_ATLAS = "bags-glow-orange"
local GLOW_COLOR_ADD = { 0.20, 1.00, 0.35 }
local GLOW_COLOR_REMOVE = { 1.00, 0.30, 0.30 }
local GLOW_COLOR_CHANGE = { 1.00, 0.75, 0.20 }

local container
local iconBtn
local iconBright
local banner
local buildCard
local revealClip
local RefreshBanner
local RefreshBuildCard
local RefreshAll
local PersistPanelState
local stateReady = false
local panelExpanded = false

local previewedBuild
local previewEntry
local buildMapCache = {}
local activeMapCache
local touchedGlowButtons = {}
local setupDone = false

local selectedSource
local selectedContent
local selectedDifficulty = "mythic"
local lastSpecKey
local selectedUggHero
local selectedBuildKey

local HERO_ALL = "All"

local INSPECT_CONFIG_ID = (Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID) or -1

local inspectOverride = nil

-- WoW 12.1.0 removed the global GetInspectSpecialization, moving it onto
-- C_SpecializationInfo. Resolved per call rather than cached at load, so the
-- same file works either side of the change. Returns 0 (the "unknown spec"
-- sentinel the callers already expect) when neither exists.
local function GetInspectSpecID(unit)
    local fn = (C_SpecializationInfo and C_SpecializationInfo.GetInspectSpecialization)
        or _G.GetInspectSpecialization
    return (fn and fn(unit)) or 0
end

local function ResolveInspectOverride()
    if not PlayerSpellsFrame or not PlayerSpellsFrame.IsInspecting then return nil end
    local ok, isInspecting = pcall(PlayerSpellsFrame.IsInspecting, PlayerSpellsFrame)
    if not ok or not isInspecting then return nil end

    local infoFn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID)
        or _G.GetSpecializationInfoByID
    if not infoFn then return nil end

    local unit = PlayerSpellsFrame.GetInspectUnit and PlayerSpellsFrame:GetInspectUnit() or nil
    if unit and UnitExists and UnitExists(unit) then
        local _, classFile = UnitClass(unit)
        local specID = GetInspectSpecID(unit)
        if classFile and specID and specID ~= 0 then
            local _, specDisplayName = infoFn(specID)
            if specDisplayName and specDisplayName ~= "" then
                return {
                    classFile = classFile,
                    specName = specDisplayName:lower():gsub("%s+", "-"),
                    specID = specID,
                    level = (UnitLevel and UnitLevel(unit)) or 80,
                }
            end
        end
    end

    if PlayerSpellsFrame.GetInspectString then
        local _, classID, specID = PlayerSpellsFrame:GetInspectString()
        if classID and specID then
            local classInfo = C_CreatureInfo and C_CreatureInfo.GetClassInfo(classID)
            local classFile = classInfo and classInfo.classFile
            if classFile then
                local _, specDisplayName = infoFn(specID)
                if specDisplayName and specDisplayName ~= "" then
                    return {
                        classFile = classFile,
                        specName = specDisplayName:lower():gsub("%s+", "-"),
                        specID = specID,
                        level = 80,
                    }
                end
            end
        end
    end

    return nil
end

local function RefreshInspectOverride()
    local resolved = ResolveInspectOverride()
    if not resolved and inspectOverride then
        local stillInspecting = PlayerSpellsFrame
            and PlayerSpellsFrame.IsInspecting
            and PlayerSpellsFrame:IsInspecting()
        if stillInspecting then return end
    end
    inspectOverride = resolved
    ns._talentPaneInspect = inspectOverride
end

local function ClearGlow()
    for i = 1, #touchedGlowButtons do
        local btn = touchedGlowButtons[i]
        if btn and btn._ccGlow then btn._ccGlow:Hide() end
        touchedGlowButtons[i] = nil
    end
end

local function InvalidateActiveMap()
    activeMapCache = nil

    if buildMapCache then wipe(buildMapCache) end
end

local function GetActiveConfigID()
    if inspectOverride then
        local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
        if tf and tf.GetConfigID then
            local ok, id = pcall(tf.GetConfigID, tf)
            if ok and id then return id end
        end
        return INSPECT_CONFIG_ID
    end
    return C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
end

local function GetActiveMap()
    if activeMapCache then return activeMapCache end
    local configID = GetActiveConfigID()
    if not configID then return nil end
    local info = C_Traits.GetConfigInfo(configID)
    if not info or not info.treeIDs or not info.treeIDs[1] then return nil end
    local treeNodes = C_Traits.GetTreeNodes(info.treeIDs[1])
    if not treeNodes then return nil end
    local map = {}
    for _, nodeID in ipairs(treeNodes) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo and nodeInfo.ranksPurchased and nodeInfo.ranksPurchased > 0 then
            local entryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID or nil
            map[nodeID] = {
                ranksPurchased = nodeInfo.ranksPurchased,
                selectionEntryID = entryID,
            }
        end
    end
    activeMapCache = map
    return map
end

local function GetBuildMap(exportString)
    local cached = buildMapCache[exportString]
    if cached ~= nil then return cached or nil end
    local map = ns.ParseLoadoutNodes and ns.ParseLoadoutNodes(exportString) or nil

    if map and next(map) then
        buildMapCache[exportString] = map
    else
        buildMapCache[exportString] = false
    end
    return (map and next(map)) and map or nil
end

local function ComputeDiff(buildMap, activeMap)
    local adds, removes, changes = {}, {}, {}
    if not buildMap or not activeMap then return adds, removes, changes end
    for nodeID, buildEntry in pairs(buildMap) do
        local activeEntry = activeMap[nodeID]
        if not activeEntry then
            adds[#adds + 1] = nodeID
        elseif
            buildEntry.selectionEntryID ~= activeEntry.selectionEntryID
            or buildEntry.ranksPurchased ~= activeEntry.ranksPurchased
        then
            changes[#changes + 1] = nodeID
        end
    end
    for nodeID in pairs(activeMap) do
        if not buildMap[nodeID] then removes[#removes + 1] = nodeID end
    end
    return adds, removes, changes
end

local function ApplyGlowToButton(nodeID, color)
    local talentsFrame = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not talentsFrame or not talentsFrame.GetTalentButtonByNodeID then return end
    local btn = talentsFrame:GetTalentButtonByNodeID(nodeID)
    if not btn then return end
    if not btn._ccGlow then
        local glow = btn:CreateTexture(nil, "OVERLAY", nil, 7)
        glow:SetAtlas(GLOW_ATLAS)
        glow:SetBlendMode("BLEND")
        local size = math.max(btn:GetWidth() or 0, btn:GetHeight() or 0)
        if size <= 0 then size = 38 end
        size = size + GLOW_INSET * 2
        glow:SetSize(size, size)
        glow:SetPoint("CENTER", btn, "CENTER")
        btn._ccGlow = glow
    end
    btn._ccGlow:SetVertexColor(color[1], color[2], color[3], GLOW_ALPHA)
    btn._ccGlow:Show()
    touchedGlowButtons[#touchedGlowButtons + 1] = btn
end

local function GetIdleWidth()
    return CONTAINER_PADDING_X * 2 + ICON_SIZE
end

local function GetExpandedWidth()
    return CONTAINER_PADDING_X * 2 + ICON_SIZE + ICON_GAP + SOURCE_DROPDOWN_WIDTH + ICON_GAP + BUILD_DROPDOWN_WIDTH
end

local function GetTargetWidth()
    if not panelExpanded then return GetIdleWidth() end
    return GetExpandedWidth()
end

local function AnchorRevealed(slideOffset)
    if banner and revealClip then
        banner:ClearAllPoints()
        banner:SetPoint("LEFT", revealClip, "LEFT", ICON_GAP + slideOffset, 0)
    end
end

local function SetDropdownAlpha(a)
    if banner then banner:SetAlpha(a) end
    if buildCard then buildCard:SetAlpha(a) end
end

local function ShowDropdown()
    if banner then banner:Show() end
    if buildCard and buildCard._hasBuild then buildCard:Show() end
end

local function HideDropdown()
    if banner then banner:Hide() end
    if buildCard then buildCard:Hide() end
end

local function CloseBuildMenu()
    if MenuUtil and MenuUtil.HideCurrentMenu then pcall(MenuUtil.HideCurrentMenu) end
end

local function UpdateRevealAnimation()
    if not container then return end

    local targetWidth = GetTargetWidth()
    local dropdownTarget = panelExpanded and 1 or 0

    if dropdownTarget > 0 then ShowDropdown() end

    local startWidth = container:GetWidth()
    local startAlpha = banner and banner:GetAlpha() or 0

    local atTarget = math.abs(startWidth - targetWidth) < 0.5 and math.abs(startAlpha - dropdownTarget) < 0.01

    if atTarget then
        container:SetWidth(targetWidth)
        SetDropdownAlpha(dropdownTarget)
        AnchorRevealed(0)
        if dropdownTarget == 0 then HideDropdown() end
        container:SetScript("OnUpdate", nil)
        return
    end

    local elapsed = 0
    container:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / REVEAL_DURATION, 1.0)
        local eased = 1 - (1 - t) * (1 - t)
        self:SetWidth(startWidth + (targetWidth - startWidth) * eased)

        local alpha = startAlpha + (dropdownTarget - startAlpha) * eased
        SetDropdownAlpha(alpha)
        AnchorRevealed(-REVEAL_SLIDE_DX * (1 - eased) * (panelExpanded and 1 or -1))

        if t >= 1 then
            self:SetScript("OnUpdate", nil)
            AnchorRevealed(0)
            if dropdownTarget == 0 then HideDropdown() end
        end
    end)
end

local function ApplyGlowForBuild(build)
    if not build then return end
    local buildMap = GetBuildMap(build.exportString)
    local activeMap = GetActiveMap()
    if buildMap and activeMap then
        local adds, removes, changes = ComputeDiff(buildMap, activeMap)
        for _, n in ipairs(adds) do
            ApplyGlowToButton(n, GLOW_COLOR_ADD)
        end
        for _, n in ipairs(removes) do
            ApplyGlowToButton(n, GLOW_COLOR_REMOVE)
        end
        for _, n in ipairs(changes) do
            ApplyGlowToButton(n, GLOW_COLOR_CHANGE)
        end
    end
end

local function BuildMatchesActive(build)
    if not build or not build.exportString then return false end
    local buildMap = GetBuildMap(build.exportString)
    local activeMap = GetActiveMap()
    if not buildMap or not activeMap then return false end

    if next(buildMap) == nil or next(activeMap) == nil then return false end
    local adds, removes, changes = ComputeDiff(buildMap, activeMap)
    return #adds == 0 and #removes == 0 and #changes == 0
end

ns.BuildMatchesActive = BuildMatchesActive

local function IsActiveBuild(build)
    return BuildMatchesActive(build)
end

local function CurrentClassSpec()
    if inspectOverride then return inspectOverride.classFile, inspectOverride.specName end
    if not ns.GetSpecData then return nil, nil end
    local _, classToken, specKey = ns.GetSpecData()
    return classToken, specKey
end

local function GetEffectiveSpecData()
    if inspectOverride then
        local DATA = _G.IcyVeinsData
        if not DATA then return nil end
        local cls = DATA[inspectOverride.classFile]
        if not cls then return nil end
        return cls[inspectOverride.specName]
    end
    return ns.GetSpecData and ns.GetSpecData() or nil
end

local function FindActiveBuild()
    if not GetActiveMap() then return nil end

    local specData = GetEffectiveSpecData()
    if specData and specData.talents then
        for _, build in ipairs(specData.talents) do
            if BuildMatchesActive(build) then return build end
        end
    end

    local classFile, specName = CurrentClassSpec()
    if classFile and specName and ns.GetUggSpecData then
        local ugg = ns.GetUggSpecData(classFile, specName)
        if ugg and ugg.contexts then
            for _, ctx in pairs(ugg.contexts) do
                if ctx.builds then
                    for _, build in ipairs(ctx.builds) do
                        if BuildMatchesActive(build) then return build end
                    end
                end
            end
        end
    end
    return nil
end

local function SetPreview(build)
    if previewedBuild == build then return end
    previewedBuild = build
    ClearGlow()

    if build and panelExpanded then ApplyGlowForBuild(build) end
    if RefreshBanner then RefreshBanner() end
    if RefreshBuildCard then RefreshBuildCard() end
    if ns.SetRecommendedHonorTalents then ns.SetRecommendedHonorTalents(build and build._pvpHonorTalents) end
    UpdateRevealAnimation()
end

local function ShowCopyPopup(exportString)
    if ns.ShowCopyPopup then ns.ShowCopyPopup(exportString) end
end

local function BuildLoadoutLabel(build)
    local source
    if build._ivSource then
        source = "Icy Veins"
    elseif build._uggSource then
        source = "U.GG"
    elseif build._pvpSource then
        source = "PvP"
    elseif build._genericSource then
        source = build._genericSource
    end

    local hero = build.heroTalent or "All"
    local ctx = build.context or "Build"
    local bl = build.buildLabel
    local body
    if build._ivSource then
        body = (bl and bl ~= "" and bl ~= source) and bl or ctx
    else
        body = ctx
        if bl and bl ~= "" and bl ~= ctx and bl ~= source then body = body .. " " .. bl end
    end
    local name = (hero ~= "All") and (hero .. " " .. body) or body

    if source and source ~= "" then return source .. " - " .. name end
    return name
end

local function OnApplyClicked()
    if not previewedBuild then return end

    if inspectOverride then return end

    if IsActiveBuild(previewedBuild) then return end

    ClearGlow()
    local build = previewedBuild
    local ok, err = ns.ApplyTalentExportString(build.exportString, BuildLoadoutLabel(build))
    if not ok then
        print("|cff00ccffBread Codex:|r " .. (err or ns.L["talent_apply.failed_generic"]))
        return
    end

    if build._pvpHonorTalents and ns.ApplyPvpHonorTalents then ns.ApplyPvpHonorTalents(build._pvpHonorTalents) end
end

local function OnSaveAsNewClicked()
    if not previewedBuild then return end

    if inspectOverride then return end

    if ns.PromptAndSaveTalentBuild then
        ns.PromptAndSaveTalentBuild(previewedBuild.exportString, BuildLoadoutLabel(previewedBuild))
    end
end

local function UggBuildRecord(ctx, build)
    local hero = build.heroTalent or "All"
    local context = (ns.GetUggEncounterLabel and ns.GetUggEncounterLabel(ctx)) or ctx.encounterLabel or "Build"
    local difficultyLabel = ctx.difficultyLabel
    local buildLabel = nil
    if difficultyLabel and difficultyLabel ~= "" and ctx.zoneType == "raid" then buildLabel = difficultyLabel end
    return {
        heroTalent = hero,
        context = context,
        buildLabel = buildLabel,
        exportString = build.exportString,
        recommended = false,
        _uggSource = true,
        _uggContextKey = nil,
        _pvpHonorTalents = build.honor,
    }
end

local function UggHeroOptions(specData)
    local seen, out = {}, {}
    if specData and specData.contexts then
        for _, ctx in pairs(specData.contexts) do
            if ctx.builds then
                for _, b in ipairs(ctx.builds) do
                    local h = b.heroTalent
                    if h and h ~= "" and h ~= HERO_ALL and not seen[h] then
                        seen[h] = true
                        out[#out + 1] = h
                    end
                end
            end
        end
    end
    table.sort(out)
    return out
end

local function SelectBuildForHero(ctx, hero)
    if not ctx or not ctx.builds or not ctx.builds[1] then return nil end
    if hero and hero ~= HERO_ALL then
        for _, b in ipairs(ctx.builds) do
            if b.heroTalent == hero then return b end
        end
        return nil
    end
    return ctx.builds[1]
end

local function IcyVeinsBuildRecord(build)
    return {
        heroTalent = "All",
        context = build.context or "Build",
        buildLabel = build.buildLabel,
        exportString = build.exportString,
        recommended = false,
        _ivSource = true,
    }
end

local function CurrentSpecIcon()
    if inspectOverride then return nil end
    local idx = GetSpecialization and GetSpecialization()
    if idx and GetSpecializationInfo then
        local _, _, _, icon = GetSpecializationInfo(idx)
        return icon
    end
    return nil
end

local function UggGroupsForState()
    local classFile, specName = CurrentClassSpec()
    if not classFile or not specName or not ns.GetUggSpecData then return nil end
    local specData = ns.GetUggSpecData(classFile, specName)
    if not specData or not specData.contexts then return nil end
    return ns.GroupUggContexts(specData), specData
end

local APPLIED_MARK = "  |TInterface\\COMMON\\Indicator-Green:12:12:0:0|t"

local function IcyVeinsTalents()
    local classFile, specName = CurrentClassSpec()
    local ivData = (classFile and specName and ns.GetIcyVeinsTalentSpecData)
            and ns:GetIcyVeinsTalentSpecData(classFile, specName)
        or nil
    return ivData and ivData.talents or nil
end

local RECOMMENDED_ATLAS = "PetJournal-FavoritesIcon"
local RECOMMENDED_ICON = "|A:" .. RECOMMENDED_ATLAS .. ":14:14|a"
local IV_CTX_TO_CONTENT = { ["Mythic+"] = "mplus", Raid = "raid", Delves = "mplus", General = "mplus", PvP = "pvp" }

local function ContentIconKey(content)
    if content == "mplus" or content == "raid" or content == "pvp" then return content end
    return nil
end

local function HeroDisplayLabel(h)
    if h == HERO_ALL then
        return RECOMMENDED_ICON .. "  " .. ((ns.L and ns.L["talent_pane.recommended"]) or "Recommended")
    end
    local atlas = ns.HERO_TALENT_ATLAS and ns.HERO_TALENT_ATLAS[h]
    return atlas and ("|A:" .. atlas .. ":14:14|a  " .. h) or h
end

local function ContentOptionsForSource()
    return (ns.GetGenericContentOptions and ns.GetGenericContentOptions()) or {}
end

local function ScopeFromState()
    if selectedContent == "raid" then
        return (selectedDifficulty == "heroic") and "raidHeroic" or "raidMythic"
    elseif selectedContent == "pvp" then
        return "pvp"
    end
    return "mplus"
end

local function EnrichUggLabel(ctx, b)
    local label = (ns.GetUggEncounterLabel and ns.GetUggEncounterLabel(ctx)) or ctx.encounterLabel or "Build"
    local hatlas = b.heroTalent and ns.HERO_TALENT_ATLAS and ns.HERO_TALENT_ATLAS[b.heroTalent]
    if hatlas then label = "|A:" .. hatlas .. ":14:14|a " .. label end
    if BuildMatchesActive(b) then label = label .. APPLIED_MARK end
    return label
end

local function UggBuildEntries()
    local groups = UggGroupsForState()
    if not groups then return {} end
    local scope = ScopeFromState()
    local list = {}
    local function add(entry, isOverview)
        if not (entry and entry.ctx) then return end
        local b = SelectBuildForHero(entry.ctx, selectedUggHero)
        if not b then return end
        list[#list + 1] = {
            key = entry.contextKey,
            ctx = entry.ctx,
            build = b,
            label = EnrichUggLabel(entry.ctx, b),
            isOverview = isOverview or entry.isOverview or nil,
            separatorBefore = entry.separatorBefore or nil,
        }
    end
    if scope == "mplus" then
        add(groups.mplusOverview)
        for _, e in ipairs(groups.mplusDungeons) do
            add(e)
        end
    elseif scope == "raidHeroic" then
        add(groups.raidOverviewHeroic)
        for _, e in ipairs(groups.raidHeroicBosses) do
            add(e)
        end
    elseif scope == "raidMythic" then
        add(groups.raidOverviewMythic)
        for _, e in ipairs(groups.raidMythicBosses) do
            add(e)
        end
    elseif scope == "pvp" then
        for _, e in ipairs(groups.pvpArena) do
            add(e)
        end
        for _, e in ipairs(groups.pvpBattleground) do
            add(e)
        end
    end
    return list
end

local function IcyVeinsBuildEntries()
    local talents = IcyVeinsTalents()
    if not talents then return {} end
    local list = {}
    local recommendedMode = (selectedUggHero == HERO_ALL)
    for i, b in ipairs(talents) do
        local heroMatch
        if recommendedMode then
            heroMatch = b.recommended
        else
            heroMatch = (b.heroTalent or HERO_ALL) == selectedUggHero
        end
        local contentMatch = not selectedContent
            or (IV_CTX_TO_CONTENT[b.context] == selectedContent)
            or (b.leveling and selectedContent ~= "pvp")
        if heroMatch and contentMatch then
            local label = b.buildLabel or b.context or "Build"
            local hatlas = b.heroTalent and ns.HERO_TALENT_ATLAS and ns.HERO_TALENT_ATLAS[b.heroTalent]
            if hatlas then label = "|A:" .. hatlas .. ":14:14|a " .. label end
            if BuildMatchesActive({ exportString = b.exportString }) then label = label .. APPLIED_MARK end
            list[#list + 1] = { key = tostring(i), build = b, label = label }
        end
    end
    return list
end

-- Icy Veins and u.gg have bespoke paths through this pane, reaching into their
-- own record shapes (ns.GetUggSpecData / ns.GroupUggContexts for one,
-- ns:GetIcyVeinsTalentSpecData for the other). Every OTHER source goes through
-- the generic path below, which reads ns.GetTalentBuilds — the same accessor
-- the main panel's Talents tab uses — and adapts its entries to the shape this
-- pane consumes.
--
-- Before this existed, BuildEntries was `icyveins or else u.gg`, so any other
-- selected source silently rendered U.GG's builds under its name and saved a
-- loadout labelled "U.GG - ...".
local BESPOKE_SOURCE = { icyveins = true, ugg = true }

-- Map the pane's scope state onto the zoneKind vocabulary ns.GetTalentBuilds
-- emits. Raid difficulty is not applied here: Wowhead carries no difficulty at
-- all and Archon's raid data is Heroic-only, so filtering on it would empty the
-- list rather than narrow it.
local function ZoneKindFromState()
    local scope = ScopeFromState()
    if scope == "mplus" then return "mplus" end
    if scope == "pvp" then return "pvp" end
    return "raid"
end

local function GenericBuilds()
    local class, spec = CurrentClassSpec()
    if not (class and spec and ns.GetTalentBuilds) then return {} end
    return ns.GetTalentBuilds(class, spec, selectedSource) or {}
end

local function GenericBuildEntries()
    local wantZone = ZoneKindFromState()
    local list, seen = {}, {}
    for i, b in ipairs(GenericBuilds()) do
        -- nil zoneKind means "unclassified", which shows under every PvE
        -- scope rather than being hidden from the one it belongs to -- but
        -- never under PvP, which must be positively claimed. Same rule as
        -- Sections/Talents.lua.
        local zoneOk = (not b.zoneKind and wantZone ~= "pvp") or b.zoneKind == wantZone
        local heroOk = selectedUggHero == HERO_ALL or not b.hero or b.hero == selectedUggHero
        if zoneOk and heroOk and b.exportString and b.exportString ~= "" then
            local key = tostring(b.contextId or b.label or i) .. "\0" .. tostring(b.hero or "")
            if not seen[key] then
                seen[key] = true
                list[#list + 1] = {
                    key = key,
                    -- A synthetic context standing in for u.gg's record. The
                    -- _generic flag keeps BuildCardParts away from
                    -- ns.GetUggEncounterLabel, which expects a real u.gg ctx.
                    ctx = {
                        _generic = true,
                        zoneType = b.zoneKind or wantZone,
                        encounterLabel = b.encounterLabel,
                        difficultyLabel = b.difficulty,
                    },
                    build = {
                        heroTalent = b.hero or HERO_ALL,
                        exportString = b.exportString,
                        honor = b.honor,
                    },
                    label = b.label or b.encounterLabel or "Build",
                }
            end
        end
    end
    return list
end

local function GenericBuildRecord(entry)
    local src = ns.SOURCES and ns.SOURCES[selectedSource]
    return {
        heroTalent = entry.build.heroTalent or "All",
        context = entry.label or "Build",
        buildLabel = entry.ctx and entry.ctx.difficultyLabel or nil,
        exportString = entry.build.exportString,
        recommended = false,
        _genericSource = src and src.name or selectedSource,
        _pvpHonorTalents = entry.build.honor,
    }
end

local function BuildEntries()
    if selectedSource == "icyveins" then return IcyVeinsBuildEntries() end
    if not BESPOKE_SOURCE[selectedSource] then return GenericBuildEntries() end
    return UggBuildEntries()
end

local function HeroOptionsForSelector()
    local opts = { HERO_ALL }
    local seen = {}
    if selectedSource == "icyveins" then
        for _, b in ipairs(IcyVeinsTalents() or {}) do
            local h = b.heroTalent
            if h and h ~= HERO_ALL and not seen[h] then
                seen[h] = true
                opts[#opts + 1] = h
            end
        end
        -- Same predictable alphabetical order as the u.gg list.
        table.sort(opts, function(a, b)
            if a == HERO_ALL then return true end
            if b == HERO_ALL then return false end
            return a < b
        end)
    elseif not BESPOKE_SOURCE[selectedSource] then
        for _, b in ipairs(GenericBuilds()) do
            local h = b.hero
            if h and h ~= HERO_ALL and not seen[h] then
                seen[h] = true
                opts[#opts + 1] = h
            end
        end
    else
        local _, specData = UggGroupsForState()
        for _, h in ipairs(UggHeroOptions(specData)) do
            opts[#opts + 1] = h
        end
    end
    return opts
end

local function ResolvePreviewFromState()
    local entries = BuildEntries()
    if #entries == 0 then
        selectedBuildKey = nil
        previewEntry = nil
        SetPreview(nil)
        return
    end
    local chosen
    for _, e in ipairs(entries) do
        if e.key == selectedBuildKey then
            chosen = e
            break
        end
    end
    if not chosen and selectedUggHero == HERO_ALL and BESPOKE_SOURCE[selectedSource]
        and selectedSource ~= "icyveins" then
        local autoKey = ns.GetActiveUggContext and ns.GetActiveUggContext()
        if autoKey then
            for _, e in ipairs(entries) do
                if e.key == autoKey then
                    chosen = e
                    break
                end
            end
        end
    end
    chosen = chosen or entries[1]
    selectedBuildKey = chosen.key
    previewEntry = chosen
    local build
    if selectedSource == "icyveins" then
        build = IcyVeinsBuildRecord(chosen.build)
    elseif not BESPOKE_SOURCE[selectedSource] then
        build = GenericBuildRecord(chosen)
    else
        build = UggBuildRecord(chosen.ctx, chosen.build)
        build._uggContextKey = chosen.key
    end
    SetPreview(build)
end

local function BuildCardParts(entry)
    if not entry then return nil end
    local heroTalent = entry.build and entry.build.heroTalent
    local heroAtlas = heroTalent
        and heroTalent ~= HERO_ALL
        and ns.HERO_TALENT_ATLAS
        and ns.HERO_TALENT_ATLAS[heroTalent]
    local title, portrait, icon, tintKind, tintKey, portraitPending
    if selectedSource == "icyveins" then
        title = entry.build.buildLabel or entry.build.context or "Build"
        tintKey = title
    else
        local ctx = entry.ctx
        local generic = ctx and ctx._generic
        title = generic and (entry.label or "Build")
            or (ns.GetUggEncounterLabel and ns.GetUggEncounterLabel(ctx)) or ctx.encounterLabel or "Build"
        local label = generic and ctx.encounterLabel
            or (ns.GetUggEncounterLabel and ns.GetUggEncounterLabel(ctx)) or ctx.encounterLabel
        if ctx.zoneType == "raid" then
            tintKind = (ns.GetUggRaidGroupKind and ns.GetUggRaidGroupKind(ctx)) or nil
            if label and ns.GetBossArtByName then
                local ba = ns.GetBossArtByName(label)
                if ba then
                    portrait = ba.displayID
                elseif ns.IsBossMapReady and not ns.IsBossMapReady() then
                    portraitPending = true
                end
            end
        elseif ctx.zoneType == "mplus" then
            tintKey = label or "mythic-plus"
            if label and ns.GetDungeonIconByName then icon = ns.GetDungeonIconByName(label) end
        else
            tintKey = title
        end
        -- No specific art (overview contexts, unknown boss, PvP): generic
        -- content-type icon before the tome fallback.
        if not portrait and not portraitPending and not icon then
            icon = ns.GetContentFallbackAtlas and ns.GetContentFallbackAtlas(ctx.zoneType)
        end
    end
    return {
        title = title,
        heroAtlas = heroAtlas,
        heroName = heroTalent,
        portrait = portrait,
        portraitPending = portraitPending,
        icon = icon,
        tintKind = tintKind,
        tintKey = tintKey,
        recommended = (selectedUggHero == HERO_ALL),
    }
end

local NEUTRAL_BORDER = { 1, 1, 1 }
local GENERIC_BUILD_ICON = "Interface\\Icons\\INV_Inscription_TalentTome01"

RefreshBuildCard = function()
    if not buildCard then return end
    local parts = BuildCardParts(previewEntry)
    if not parts then
        buildCard._hasBuild = false
        buildCard:Hide()
        return
    end
    buildCard._hasBuild = true
    buildCard:SetTitle(parts.title)
    buildCard:SetHeroIcon(nil)
    buildCard:SetRecommended(parts.recommended)

    local iconSet = false
    if parts.portrait then iconSet = buildCard:SetPortrait(parts.portrait) end
    if not iconSet and parts.portraitPending then
        buildCard:SetPortraitPlaceholder()
        iconSet = true
    end
    if not iconSet and parts.icon then
        buildCard:SetIcon(parts.icon)
        iconSet = true
    end
    if not iconSet then buildCard:SetIcon(GENERIC_BUILD_ICON) end

    if parts.tintKind and ns.GetRaidGroupTint then
        buildCard:SetBackgroundColor(ns.GetRaidGroupTint(parts.tintKind))
    elseif parts.tintKey and ns.TintFromKey then
        buildCard:SetBackgroundColor(ns.TintFromKey(parts.tintKey))
    else
        buildCard:SetBackgroundColor(nil)
    end

    local applied = previewedBuild and IsActiveBuild(previewedBuild) or false
    buildCard:SetApplied(applied)
    buildCard:SetAccent(NEUTRAL_BORDER[1], NEUTRAL_BORDER[2], NEUTRAL_BORDER[3], 0.9)
    if panelExpanded then buildCard:Show() end
end

-- The boss-portrait map loads asynchronously (DungeonArt defers the
-- Encounter Journal scan off the render frame); the selector card keeps its
-- placeholder unless it is re-rendered once the map lands.
function ns.RefreshTalentPaneDropdown()
    if panelExpanded and RefreshBuildCard then RefreshBuildCard() end
end

local function BuildPickerMenu(_, root)
    root:CreateTitle((ns.L and ns.L["loadout_dock.pick_a_build"]) or "Pick a build")
    local lastWasOverview = false
    for _, e in ipairs(BuildEntries()) do
        if (lastWasOverview and not e.isOverview) or e.separatorBefore then root:CreateDivider() end
        lastWasOverview = e.isOverview or false
        root:CreateRadio(e.label, function()
            return e.key == selectedBuildKey
        end, function()
            selectedBuildKey = e.key
            ResolvePreviewFromState()
            if RefreshAll then RefreshAll() end
            return MenuResponse.Refresh
        end)
    end
end

local function OnSourcePicked(v)
    if selectedSource == v then return end
    selectedSource = v
    selectedBuildKey = nil
    if ClassCodexDB and ClassCodexDB.pinTalentSource and ns.SetPersistedTalentSource then
        ns.SetPersistedTalentSource(v)
    end
    if RefreshAll then RefreshAll() end
end

local function OnContentPicked(v)
    if selectedContent == v then return end
    selectedContent = v
    selectedBuildKey = nil
    if RefreshAll then RefreshAll() end
end

local function OnHeroPicked(v)
    if selectedUggHero == v then return end
    selectedUggHero = v
    selectedBuildKey = nil
    if RefreshAll then RefreshAll() end
end

local function DifficultySectionVisible()
    return selectedContent == "raid" and selectedSource ~= "icyveins"
end

local function ContextMenuBuilder(owner, root)
    root:CreateTitle("Source")
    -- Was a hardcoded { "icyveins", "ugg" }. Registering a source in
    -- ns.SOURCES and ns.Sources() is not enough on its own — this menu built
    -- its own list and ignored both, so Wowhead/Archon never appeared here.
    -- Filter to sources that actually carry talents for the current spec, so a
    -- source with no data for it does not offer an empty pick.
    local srcClass, srcSpec = CurrentClassSpec()
    local sourceKeys = {}
    for _, k in ipairs((ns.Sources and ns.Sources()) or { "icyveins", "ugg" }) do
        if not (srcClass and srcSpec) or not ns.SourceHas
            or ns.SourceHas(k, srcClass, srcSpec, "talents") then
            sourceKeys[#sourceKeys + 1] = k
        end
    end
    if #sourceKeys == 0 then sourceKeys = { "icyveins", "ugg" } end
    for _, key in ipairs(sourceKeys) do
        root:CreateRadio(ns.SourceLabelText(key), function()
            return selectedSource == key
        end, function()
            local difficultyWasVisible = DifficultySectionVisible()
            OnSourcePicked(key)
            if DifficultySectionVisible() ~= difficultyWasVisible and owner and owner.ReopenGrowDown then
                -- Keep the menu open (no blink); the deferred reopen replaces
                -- it in place with the Difficulty section added/removed.
                owner:ReopenGrowDown()
                return MenuResponse.Refresh
            end
            return MenuResponse.Refresh
        end)
    end
    local contentOpts = ContentOptionsForSource()
    if #contentOpts > 0 then
        root:CreateDivider()
        root:CreateTitle("Content")
        for _, o in ipairs(contentOpts) do
            local tex = ns.ContentTypeIcon and ns.ContentTypeIcon(o.value)
            local label = tex and ("|T" .. tex .. ":16:16|t  " .. o.label) or o.label
            root:CreateRadio(label, function()
                return selectedContent == o.value
            end, function()
                local difficultyWasVisible = DifficultySectionVisible()
                OnContentPicked(o.value)
                -- MenuResponse.Refresh only re-evaluates radio states; it does
                -- not rebuild the menu, so a content pick that toggles the
                -- raid Difficulty section must reopen the menu to show it.
                -- The menu stays open until the reopen replaces it, so the
                -- swap doesn't blink.
                if DifficultySectionVisible() ~= difficultyWasVisible and owner and owner.ReopenGrowDown then
                    owner:ReopenGrowDown()
                end
                return MenuResponse.Refresh
            end)
        end
    end
    root:CreateDivider()
    root:CreateTitle("Hero Talent")
    for _, h in ipairs(HeroOptionsForSelector()) do
        root:CreateRadio(HeroDisplayLabel(h), function()
            return selectedUggHero == h
        end, function()
            OnHeroPicked(h)
            return MenuResponse.Refresh
        end)
    end
    if DifficultySectionVisible() then
        root:CreateDivider()
        root:CreateTitle((ns.L and ns.L["talent_pane.difficulty"]) or "Difficulty")
        root:CreateRadio(PLAYER_DIFFICULTY2 or "Heroic", function()
            return selectedDifficulty == "heroic"
        end, function()
            selectedDifficulty = "heroic"
            RefreshAll()
            return MenuResponse.Refresh
        end)
        root:CreateRadio(PLAYER_DIFFICULTY6 or "Mythic", function()
            return selectedDifficulty == "mythic"
        end, function()
            selectedDifficulty = "mythic"
            RefreshAll()
            return MenuResponse.Refresh
        end)
    end
end

RefreshBanner = function()
    if not banner then return end
    local contentOpts = ContentOptionsForSource()
    local ok = false
    for _, o in ipairs(contentOpts) do
        if o.value == selectedContent then
            ok = true
            break
        end
    end
    if not ok then selectedContent = contentOpts[1] and contentOpts[1].value or nil end
    local iconContent = ContentIconKey(selectedContent)
    banner:SetContext({
        sourceCurrent = selectedSource,
        contentCurrent = iconContent,
        heroCurrent = (selectedUggHero ~= HERO_ALL) and selectedUggHero or nil,
        heroBadgeAtlas = (selectedUggHero == HERO_ALL) and RECOMMENDED_ATLAS or nil,
        specIcon = CurrentSpecIcon(),
        menuBuilder = ContextMenuBuilder,
    })
end

RefreshAll = function()
    ResolvePreviewFromState()
    RefreshBanner()
    RefreshBuildCard()
    if container then container:SetWidth(GetTargetWidth()) end
    if stateReady and PersistPanelState then PersistPanelState() end
end

local function TalentStateKey()
    return (ns.GetSpecKey and ns.GetSpecKey()) or "default"
end

PersistPanelState = function()
    if not ClassCodexCharDB or inspectOverride then return end
    ClassCodexCharDB.talentPaneOpen = panelExpanded or nil
    ClassCodexCharDB.talentPaneBuild = (previewedBuild and previewedBuild.exportString) or nil
    ClassCodexCharDB.talentPaneState = ClassCodexCharDB.talentPaneState or {}
    ClassCodexCharDB.talentPaneState[TalentStateKey()] = {
        source = selectedSource,
        content = selectedContent,
        hero = selectedUggHero,
        difficulty = selectedDifficulty,
        buildKey = selectedBuildKey,
    }
end

local function OnIconClicked()
    panelExpanded = not panelExpanded
    if iconBtn and iconBtn._setActive then iconBtn._setActive(panelExpanded) end
    if not panelExpanded then
        CloseBuildMenu()
        ClearGlow()
    else
        if RefreshAll then RefreshAll() end
        if previewedBuild then ApplyGlowForBuild(previewedBuild) end
    end
    PersistPanelState()
    UpdateRevealAnimation()
end

local function EnsureContainer()
    if iconBtn then return end
    local talentsFrame = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not talentsFrame then return end

    container = CreateFrame("Frame", "ClassCodexTalentIconContainer", talentsFrame)
    container:SetHeight(CONTAINER_ICON_SIZE + CONTAINER_PADDING_Y * 2)
    container:SetWidth(CONTAINER_PADDING_X * 2 + ICON_SIZE)
    container:SetFrameStrata("HIGH")

    local containerHeight = CONTAINER_ICON_SIZE + CONTAINER_PADDING_Y * 2
    local liftAbove = math.floor(containerHeight * 0.75 + 0.5)
    local extraLift = math.floor(CONTAINER_ICON_SIZE / 3 + 0.5)
    container:SetPoint("BOTTOMLEFT", talentsFrame, "BOTTOMLEFT", 4, 40 + liftAbove + extraLift + 0)

    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetAtlas("Toast-Background", true)

    iconBtn = CreateFrame("Button", "ClassCodexTalentIcon", container)
    iconBtn:SetSize(ICON_SIZE, ICON_SIZE)
    iconBtn:SetPoint("LEFT", container, "LEFT", CONTAINER_PADDING_X + 2, 0)
    iconBtn:RegisterForClicks("LeftButtonUp")

    local ICON_TEX = "Interface\\AddOns\\BreadClassCodex\\Media\\icon"
    local icon = iconBtn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(ICON_TEX)
    icon:SetVertexColor(0.82, 0.82, 0.82)
    iconBtn.icon = icon

    iconBright = iconBtn:CreateTexture(nil, "OVERLAY")
    iconBright:SetAllPoints(icon)
    iconBright:SetTexture(ICON_TEX)
    iconBright:SetVertexColor(1, 1, 1)
    iconBright:SetAlpha(0)

    local iconHighlight = iconBtn:CreateTexture(nil, "HIGHLIGHT")
    iconHighlight:SetAllPoints(icon)
    iconHighlight:SetTexture(ICON_TEX)
    iconHighlight:SetVertexColor(1, 1, 1)
    iconHighlight:SetAlpha(0.35)
    iconHighlight:SetBlendMode("ADD")

    local fx = CreateFrame("Frame", nil, iconBtn)
    fx:SetAllPoints(iconBtn)
    fx:SetFrameLevel(math.max(0, iconBtn:GetFrameLevel() - 1))
    fx:Hide()
    local fxGlow = fx:CreateTexture(nil, "BACKGROUND")
    fxGlow:SetSize(ICON_SIZE + 12, ICON_SIZE + 12)
    fxGlow:SetPoint("CENTER")
    fxGlow:SetAtlas("bags-glow-flash")
    fxGlow:SetVertexColor(1.0, 0.85, 0.3)
    fxGlow:SetBlendMode("ADD")
    local starFrame = CreateFrame("Frame", nil, fx)
    starFrame:SetAllPoints()
    local fxStar = starFrame:CreateTexture(nil, "BACKGROUND")
    fxStar:SetSize(ICON_SIZE + 16, ICON_SIZE + 16)
    fxStar:SetPoint("CENTER")
    fxStar:SetTexture("Interface\\Cooldown\\star4")
    fxStar:SetVertexColor(1.0, 0.9, 0.45, 0.5)
    fxStar:SetBlendMode("ADD")
    local pulse = fx:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local pulseAlpha = pulse:CreateAnimation("Alpha")
    pulseAlpha:SetFromAlpha(0.25)
    pulseAlpha:SetToAlpha(0.7)
    pulseAlpha:SetDuration(1.1)
    pulseAlpha:SetSmoothing("IN_OUT")
    local spin = starFrame:CreateAnimationGroup()
    spin:SetLooping("REPEAT")
    local spinRot = spin:CreateAnimation("Rotation")
    spinRot:SetDegrees(360)
    spinRot:SetDuration(9)
    local function PlayFx()
        fx:Show()
        pulse:Play()
        spin:Play()
    end
    local function StopFx()
        pulse:Stop()
        spin:Stop()
        fx:Hide()
    end

    local trailFx = CreateFrame("Frame", nil, UIParent)
    trailFx:SetFrameStrata("TOOLTIP")
    trailFx:SetSize(24, 24)
    trailFx:Hide()
    local trailTex = trailFx:CreateTexture(nil, "OVERLAY")
    trailTex:SetAllPoints()
    trailTex:SetTexture("Interface\\Cooldown\\star4")
    trailTex:SetVertexColor(1.0, 0.9, 0.5)
    trailTex:SetBlendMode("ADD")
    local trailT = 0
    trailFx:SetScript("OnUpdate", function(self, elapsed)
        trailT = trailT - elapsed
        if trailT <= 0 then
            self:Hide()
            return
        end
        local scale = UIParent:GetEffectiveScale()
        if not scale or scale == 0 then return end
        local cx, cy = GetCursorPosition()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
        self:SetAlpha(math.min(1, trailT * 1.6))
        trailTex:SetRotation((1 - trailT) * 5)
    end)
    local function StartTrail()
        trailT = 1.0
        trailFx:Show()
    end

    local brightTarget = 0
    iconBtn:SetScript("OnUpdate", function(_, dt)
        local cur = iconBright:GetAlpha()
        if math.abs(cur - brightTarget) < 0.01 then
            if cur ~= brightTarget then iconBright:SetAlpha(brightTarget) end
            return
        end
        local step = dt / 0.12
        if cur < brightTarget then
            iconBright:SetAlpha(math.min(brightTarget, cur + step))
        else
            iconBright:SetAlpha(math.max(brightTarget, cur - step))
        end
    end)

    local function SetTalentActive(active)
        if active then
            StopFx()
            brightTarget = 1
        else
            PlayFx()
            brightTarget = 0
        end
    end
    iconBtn._setActive = SetTalentActive
    SetTalentActive(panelExpanded)

    iconBtn:SetScript("OnEnter", function(self)
        brightTarget = 1
        StartTrail()
        ns.Tooltip
            .Open(self, "ANCHOR_RIGHT")
            .Head("Bread Codex Talent Highlight", "title")
            .Line(ns.L["talent_pane.compare_hint"], "body")
            .Show()
    end)
    iconBtn:SetScript("OnLeave", function()
        brightTarget = panelExpanded and 1 or 0
        ns.Tooltip.Hide()
    end)
    iconBtn:SetScript("OnClick", OnIconClicked)

    selectedSource = (ns.GetEffectiveTalentSource and ns.GetEffectiveTalentSource()) or "ugg"

    revealClip = CreateFrame("Frame", nil, container)
    revealClip:SetPoint("LEFT", iconBtn, "RIGHT", 0, 0)
    revealClip:SetPoint("TOP", container, "TOP", 0, 0)
    revealClip:SetPoint("BOTTOM", container, "BOTTOM", 0, 0)
    revealClip:SetPoint("RIGHT", container, "RIGHT", -CONTAINER_PADDING_X, 0)
    revealClip:SetClipsChildren(true)
    iconBtn:SetFrameLevel(revealClip:GetFrameLevel() + 4)

    banner = ns.CreateSourceButton and ns.CreateSourceButton("ClassCodexTalentBanner", revealClip, BADGE_SIZE) or nil
    if banner then
        banner:SetHeight(CONTAINER_ICON_SIZE)
        banner:SetWidth(SOURCE_DROPDOWN_WIDTH)
        banner:SetPoint("LEFT", revealClip, "LEFT", ICON_GAP, 0)
        banner:Hide()
        banner:SetAlpha(0)
    end

    buildCard = ns.CreateCard
            and ns.CreateCard(revealClip, {
                height = CONTAINER_ICON_SIZE,
                staticBorder = true,
                actions = {
                    { icon = "Interface\\AddOns\\BreadClassCodex\\Media\\action-copy", tooltip = "Export build string" },
                    {
                        icon = "Interface\\AddOns\\BreadClassCodex\\Media\\action-save",
                        tooltip = (ns.L and ns.L["talent_pane.save_as.tooltip"]) or "Save as new loadout",
                    },
                    {
                        icon = "Interface\\AddOns\\BreadClassCodex\\Media\\action-apply",
                        tooltip = "Apply previewed build",
                        role = "apply",
                    },
                },
                onClick = function(self)
                    if MenuUtil and MenuUtil.CreateContextMenu then
                        MenuUtil.CreateContextMenu(self, BuildPickerMenu)
                    end
                end,
            })
        or nil
    if buildCard then
        if buildCard.title then
            local f, s, flags = buildCard.title:GetFont()
            if f and s then buildCard.title:SetFont(f, s + 2, flags) end
        end
        buildCard:SetWidth(BUILD_DROPDOWN_WIDTH)
        buildCard:SetPoint("LEFT", banner or iconBtn, "RIGHT", ICON_GAP, 0)
        if banner then
            buildCard:SetPoint("TOP", banner, "TOP", 0, 0)
            buildCard:SetPoint("BOTTOM", banner, "BOTTOM", 0, 0)
        end
        buildCard:Hide()
        buildCard:SetAlpha(0)
        local function bindAction(idx, fn)
            local b = buildCard.actions and buildCard.actions[idx]
            if b then b:SetScript("OnClick", fn) end
        end
        bindAction(1, function()
            if previewedBuild then ShowCopyPopup(previewedBuild.exportString) end
        end)
        bindAction(2, OnSaveAsNewClicked)
        bindAction(3, OnApplyClicked)
    end

    RefreshAll()
end

local function IsTalentsTabActive()
    if not PlayerSpellsFrame or not PlayerSpellsFrame.IsFrameTabActive then return false end
    local util = _G.PlayerSpellsUtil
    if not util or not util.FrameTabs or not util.FrameTabs.ClassTalents then return false end
    local ok, active = pcall(PlayerSpellsFrame.IsFrameTabActive, PlayerSpellsFrame, util.FrameTabs.ClassTalents)
    return ok and active
end

local function FindBuildByExportString(exportString)
    if not exportString then return nil end
    local specData = GetEffectiveSpecData()
    if specData and specData.talents then
        for _, build in ipairs(specData.talents) do
            if build.exportString == exportString then return build end
        end
    end
    local classFile, specName = CurrentClassSpec()
    if classFile and specName and ns.FindUggBuildByExportString then
        local b = ns.FindUggBuildByExportString(classFile, specName, exportString)
        if b then return b end
    end
    return nil
end

local function RestorePanelState()
    if not ClassCodexCharDB then return end
    stateReady = true
    if not inspectOverride then
        local st = ClassCodexCharDB.talentPaneState and ClassCodexCharDB.talentPaneState[TalentStateKey()]
        if st then
            if st.source then selectedSource = st.source end
            selectedContent = st.content
            selectedUggHero = st.hero or HERO_ALL
            if st.difficulty then selectedDifficulty = st.difficulty end
            selectedBuildKey = st.buildKey
        end
    end
    if ClassCodexCharDB.talentPaneOpen then
        panelExpanded = true
        if not previewedBuild and ClassCodexCharDB.talentPaneBuild then
            previewedBuild = FindBuildByExportString(ClassCodexCharDB.talentPaneBuild)
        end
        if not previewedBuild then previewedBuild = FindActiveBuild() end
        if previewedBuild then ApplyGlowForBuild(previewedBuild) end
    end
end

local function IsTalentPaneEnabled()
    if ClassCodexDB == nil then return true end
    if ClassCodexDB.talentPaneEnabled == nil then return true end
    return ClassCodexDB.talentPaneEnabled and true or false
end

local function UpdateVisibility()
    if not container then return end
    if PlayerSpellsFrame and PlayerSpellsFrame:IsShown() and IsTalentsTabActive() and IsTalentPaneEnabled() then
        if ns.InstallPvpTalentHighlight then ns.InstallPvpTalentHighlight() end
        local prev = inspectOverride
        RefreshInspectOverride()
        if prev ~= inspectOverride then
            previewedBuild = nil
            ClearGlow()
            InvalidateActiveMap()
            wipe(buildMapCache)

            selectedSource = (ns.GetEffectiveTalentSource and ns.GetEffectiveTalentSource()) or "ugg"
            selectedUggHero = nil
            RefreshAll()
        end
        container:Show()

        RestorePanelState()

        RefreshAll()
        if iconBtn and iconBtn._setActive then iconBtn._setActive(panelExpanded) end
        UpdateRevealAnimation()
    else
        CloseBuildMenu()
        container:Hide()
        ClearGlow()
        previewedBuild = nil
        panelExpanded = false
        -- A stale inspect override leaks INSPECT_TRAIT_CONFIG_ID (-1) into
        -- every ns.GetActiveTalentSignature / ParseLoadoutNodes caller after
        -- the pane closes, and C_Traits calls with the sentinel config
        -- hard-crash the client.
        if inspectOverride then
            inspectOverride = nil
            ns._talentPaneInspect = nil
        end
        if buildCard then
            buildCard:Hide()
            buildCard:SetAlpha(0)
        end
        if ns.HideSaveAsLoadoutPopup then ns.HideSaveAsLoadoutPopup() end
        if banner then
            banner:Hide()
            banner:SetAlpha(0)
        end
        container:SetWidth(GetIdleWidth())
    end
end

local function Setup()
    if setupDone then return end
    if not IsTalentPaneEnabled() then return end
    if not PlayerSpellsFrame or not PlayerSpellsFrame.TalentsFrame then return end
    setupDone = true

    EnsureContainer()
    if not container then
        setupDone = false
        return
    end

    lastSpecKey = ns.GetSpecKey and ns.GetSpecKey()

    PlayerSpellsFrame:HookScript("OnShow", UpdateVisibility)
    PlayerSpellsFrame:HookScript("OnHide", UpdateVisibility)

    if PlayerSpellsFrame.SetInspecting then
        local pending = false
        local function deferredUpdate()
            pending = false
            UpdateVisibility()
        end
        pcall(hooksecurefunc, PlayerSpellsFrame, "SetInspecting", function()
            if pending then return end
            pending = true
            if C_Timer and C_Timer.After then
                C_Timer.After(0, deferredUpdate)
            else
                deferredUpdate()
            end
        end)
    end

    if _G.EventRegistry and EventRegistry.RegisterCallback then
        pcall(EventRegistry.RegisterCallback, EventRegistry, "PlayerSpellsFrame.TabSet", UpdateVisibility, container)
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    eventFrame:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("INSPECT_READY")

    ns._refreshTalentDiff = function()
        InvalidateActiveMap()
        local current = previewedBuild
        previewedBuild = nil
        SetPreview(current)
    end

    local refreshGen = 0
    local function ScheduleTraitRefresh()
        refreshGen = refreshGen + 1
        local thisGen = refreshGen
        C_Timer.After(0.15, function()
            if thisGen ~= refreshGen then return end
            local current = previewedBuild
            previewedBuild = nil
            SetPreview(current)
        end)
    end

    eventFrame:SetScript("OnEvent", function(_, event)
        -- Always drop the active-map cache, even mid-apply: TRAIT_CONFIG_UPDATED
        -- fires once per commit, and bailing before invalidating leaves the pane
        -- diffing against pre-apply talents, which lets an "already applied"
        -- build pass the IsActiveBuild guard and be applied a second time.
        if event ~= "INSPECT_READY" and event ~= "PLAYER_SPECIALIZATION_CHANGED" then InvalidateActiveMap() end

        if ns._talentApplyInProgress then return end

        if event == "INSPECT_READY" then
            InvalidateActiveMap()
            UpdateVisibility()
            return
        end
        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            InvalidateActiveMap()
            local key = ns.GetSpecKey and ns.GetSpecKey()
            if key == lastSpecKey then
                if panelExpanded then ScheduleTraitRefresh() end
                return
            end
            lastSpecKey = key
            selectedUggHero = nil
            selectedSource = (ns.GetEffectiveTalentSource and ns.GetEffectiveTalentSource()) or "ugg"
            SetPreview(nil)
            RefreshAll()
            return
        end

        InvalidateActiveMap()
        if not panelExpanded then return end
        ScheduleTraitRefresh()
    end)

    local function OnUggContext()
        if selectedUggHero == HERO_ALL and panelExpanded then RefreshAll() end
    end
    if ns.RegisterUggContextCallback then ns.RegisterUggContextCallback(OnUggContext) end

    ns.OnPinTalentSourceToggled = function()
        if ClassCodexDB and ClassCodexDB.pinTalentSource and selectedSource and ns.SetPersistedTalentSource then
            ns.SetPersistedTalentSource(selectedSource)
        end
        OnUggContext(ns.GetActiveUggContext and ns.GetActiveUggContext() or nil)
    end

    -- Deliberately NOT tinting the CC loadout names in Blizzard's pane
    -- dropdown, in any form: the share/export menu entries are built by the
    -- SAME menu generator that produces loadout names, so any interception
    -- (mutating configIDToName OR wrapping nameTranslation) taints the share
    -- closures, and the protected clipboard/chat action then raises the
    -- "disable your addons" warning. Taint cannot be undone, so the only clean
    -- option is leaving this path untouched — the loadout dock's own menu
    -- keeps the cyan CC entries (read-only, our frames).

    UpdateVisibility()
end

local function IsPlayerSpellsLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells")
    elseif _G.IsAddOnLoaded then
        return IsAddOnLoaded("Blizzard_PlayerSpells")
    end
    return false
end

function ns.DumpInspectState()
    local function p(...)
        print("|cff00ccffCC inspect:|r", ...)
    end
    p("--- start ---")
    p("inspectOverride:", inspectOverride and (inspectOverride.classFile .. "/" .. inspectOverride.specName) or "nil")
    p("ns._talentPaneInspect:", ns._talentPaneInspect and "set" or "nil")

    if PlayerSpellsFrame then
        local isInspecting = PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting() or false
        p("PlayerSpellsFrame:IsInspecting:", tostring(isInspecting))
        local unit = PlayerSpellsFrame.GetInspectUnit and PlayerSpellsFrame:GetInspectUnit() or nil
        p("GetInspectUnit:", tostring(unit), unit and ("exists=" .. tostring(UnitExists(unit))) or "")
        if unit and UnitExists(unit) then
            p("  UnitClass:", select(2, UnitClass(unit)))
            p("  GetInspectSpecialization:", tostring(GetInspectSpecID(unit)))
        end
    end

    local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if tf and tf.GetConfigID then
        local ok, id = pcall(tf.GetConfigID, tf)
        p("TalentsFrame:GetConfigID:", ok and tostring(id) or "ERR")
    else
        p("TalentsFrame:GetConfigID: method missing")
    end
    p("INSPECT_CONFIG_ID constant:", tostring(INSPECT_CONFIG_ID))
    p(
        "VIEW_TRAIT_CONFIG_ID:",
        tostring(Constants and Constants.TraitConsts and Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID)
    )

    local cid = GetActiveConfigID()
    p("GetActiveConfigID returns:", tostring(cid))
    if cid then
        local info = C_Traits.GetConfigInfo(cid)
        p("  GetConfigInfo:", info and "ok" or "nil")
        if info then
            p("  treeIDs:", info.treeIDs and table.concat(info.treeIDs, ",") or "nil")
            if info.treeIDs and info.treeIDs[1] then
                local nodes = C_Traits.GetTreeNodes(info.treeIDs[1])
                p("  GetTreeNodes count:", nodes and #nodes or 0)
                local purchased = 0
                if nodes then
                    for _, n in ipairs(nodes) do
                        local ni = C_Traits.GetNodeInfo(cid, n)
                        if ni and ni.ranksPurchased and ni.ranksPurchased > 0 then purchased = purchased + 1 end
                    end
                end
                p("  nodes with ranksPurchased>0:", purchased)
            end
        end
    end

    p("panelExpanded:", tostring(panelExpanded))
    p(
        "previewedBuild:",
        previewedBuild and ((previewedBuild._uggContextKey or "") .. " " .. (previewedBuild.heroTalent or "")) or "nil"
    )
    if previewedBuild then
        local bm = GetBuildMap(previewedBuild.exportString)
        p("  buildMap:", bm and "ok" or "nil")
        if bm then
            local count = 0
            for _ in pairs(bm) do
                count = count + 1
            end
            p("  buildMap node count:", count)
        end
    end

    local am = GetActiveMap()
    p("activeMap:", am and "ok" or "nil")
    if am then
        local count = 0
        for _ in pairs(am) do
            count = count + 1
        end
        p("  activeMap node count:", count)
    end

    if previewedBuild and tf and tf.GetTalentButtonByNodeID then
        local bm = GetBuildMap(previewedBuild.exportString)
        if bm and am then
            local adds, removes, changes = ComputeDiff(bm, am)
            p("diff: adds=" .. #adds, "removes=" .. #removes, "changes=" .. #changes)
            local sample = adds[1] or changes[1] or removes[1]
            if sample then
                local btn = tf:GetTalentButtonByNodeID(sample)
                p("  GetTalentButtonByNodeID(" .. sample .. "):", btn and "got button" or "nil")
            end
        end
    end
    p("--- end ---")
end

function ns.SetTalentPaneEnabled(enabled)
    if enabled then
        if not setupDone and IsPlayerSpellsLoaded() then Setup() end
    else
        if container then
            CloseBuildMenu()
            ClearGlow()
            previewedBuild = nil
            panelExpanded = false
            if iconBtn then iconBtn:Hide() end
            if banner then
                banner:Hide()
                banner:SetAlpha(0)
            end
            if buildCard then
                buildCard:Hide()
                buildCard:SetAlpha(0)
            end
            if ns.HideSaveAsLoadoutPopup then ns.HideSaveAsLoadoutPopup() end
            container:Hide()
        end
    end

    if container then UpdateVisibility() end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_PlayerSpells" then
            Setup()
            if setupDone then self:UnregisterEvent("ADDON_LOADED") end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if IsPlayerSpellsLoaded() then Setup() end
        if setupDone then self:UnregisterEvent("PLAYER_ENTERING_WORLD") end
    end
end)
