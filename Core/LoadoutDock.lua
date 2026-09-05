local _, ns = ...

local DOCK_DEFAULT_WIDTH = 200
local DOCK_MIN_WIDTH = 120
local DOCK_MAX_WIDTH = 400
local DOCK_HEIGHT = 30
local ICON_SIZE = 16
local PAD = 8
local ICON_GAP = 5
local LABEL_GAP = 6

local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local GOLD = { 1, 0.82, 0 }
local BORDER_CARD = { 0.32, 0.32, 0.38, 1.0 }

local dock = nil

local lastLoadedConfigBySpec = {}

local function L()
    return ns.L or setmetatable({}, {
        __index = function(_, k)
            return k
        end,
    })
end

local function configName(id)
    if not id or not C_Traits or not C_Traits.GetConfigInfo then return nil end
    local info = C_Traits.GetConfigInfo(id)
    if info and info.name and info.name ~= "" then return info.name end
    return nil
end

local function GetCurrentSpecID()
    return PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
end

local function IsLiveSavedConfig(specID, id)
    if not id or not specID or not C_ClassTalents.GetConfigIDsBySpecID then return true end
    local ids = C_ClassTalents.GetConfigIDsBySpecID(specID)
    if not ids then return true end
    for _, cid in ipairs(ids) do
        if cid == id then return true end
    end
    return false
end

local function GetActiveLoadoutName()
    if not C_ClassTalents then return nil end
    local specID = GetCurrentSpecID()

    if specID then
        local cached = lastLoadedConfigBySpec[specID]
        if cached and not IsLiveSavedConfig(specID, cached) then
            lastLoadedConfigBySpec[specID] = nil
            cached = nil
        end
        local name = configName(cached)
        if name then return name end
    end

    if specID and C_ClassTalents.GetLastSelectedSavedConfigID then
        local savedID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
        if savedID then
            lastLoadedConfigBySpec[specID] = savedID
            local name = configName(savedID)
            if name then return name end
        end
    end

    local active = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    return configName(active)
end

local function GetCurrentLoadoutBits()
    if not (C_Traits and C_Traits.GenerateImportString and ns.ExtractTalentBits) then
        return ns.GetActiveTalentSignature and ns.GetActiveTalentSignature() or nil
    end
    local specID = GetCurrentSpecID()
    local id = specID and lastLoadedConfigBySpec[specID]
    if id and not IsLiveSavedConfig(specID, id) then id = nil end
    if not id and specID and C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID then
        id = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    end
    if id then
        local ok, str = pcall(C_Traits.GenerateImportString, id)
        if ok and str then
            local bits = ns.ExtractTalentBits(str)
            if bits then return bits end
        end
    end
    return ns.GetActiveTalentSignature and ns.GetActiveTalentSignature() or nil
end

local function CurrentTalentSignatures()
    local sigs = {}
    local scratch = ns.GetActiveTalentSignature and ns.GetActiveTalentSignature()
    if scratch then sigs[scratch] = true end
    local loadout = GetCurrentLoadoutBits()
    if loadout then sigs[loadout] = true end
    return sigs
end

local function BuildBitsMatch(exportString, sigs)
    if not exportString or not ns.ExtractTalentBits then return false end
    local b = ns.ExtractTalentBits(exportString)
    return b ~= nil and sigs[b] == true
end

local function MatchCodexBuild(specData)
    if not specData or not specData.talents then return nil end
    local sigs = CurrentTalentSignatures()
    if not next(sigs) then return nil end
    for _, build in ipairs(specData.talents) do
        if BuildBitsMatch(build.exportString, sigs) then return build end
    end
    return nil
end

local function MatchUggBuild(classToken, specKey)
    if not classToken or not specKey then return nil end
    if not ns.GetUggSpecData or not ns.ExtractTalentBits then return nil end
    local sd = ns.GetUggSpecData(classToken, specKey)
    if not sd or not sd.contexts then return nil end
    local sigs = CurrentTalentSignatures()
    if not next(sigs) then return nil end
    for _, ctx in pairs(sd.contexts) do
        if ctx.builds then
            for _, build in ipairs(ctx.builds) do
                if BuildBitsMatch(build.exportString, sigs) then return build, ctx end
            end
        end
    end
    return nil
end

local function BuildApplyContext()
    local ctx = {}

    ctx.sigs = CurrentTalentSignatures()
    local activeID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID() or nil
    -- pcall'd like every other GenerateImportString call site: a config in a
    -- bad state (purchased choice node without a valid active entry) makes the
    -- generator throw, which must not break opening the dock menu.
    if activeID and C_Traits and C_Traits.GenerateImportString then
        local ok, str = pcall(C_Traits.GenerateImportString, activeID)
        if ok and str then ctx.activeExport = str end
    end

    local perSpec = (ns.GetPerSpecState and ns.GetPerSpecState()) or nil
    ctx.lastAppliedExport = perSpec and perSpec.lastAppliedBuildExport or nil
    ctx.lastAppliedBits = perSpec and perSpec.lastAppliedBuildBits or nil
    if ctx.lastAppliedExport and ctx.lastAppliedBits and next(ctx.sigs) and not ctx.sigs[ctx.lastAppliedBits] then
        if perSpec then
            perSpec.lastAppliedBuildExport = nil
            perSpec.lastAppliedBuildBits = nil
        end
        ctx.lastAppliedExport = nil
        ctx.lastAppliedBits = nil
    end

    function ctx.matches(exportString)
        if not exportString then return false end
        if
            ctx.lastAppliedExport
            and ctx.lastAppliedBits
            and ctx.lastAppliedExport == exportString
            and ctx.sigs[ctx.lastAppliedBits]
        then
            return true
        end
        if ctx.activeExport and ctx.activeExport == exportString then return true end
        return BuildBitsMatch(exportString, ctx.sigs)
    end

    return ctx
end

local function GuardCombat()
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(L()["loadout_dock.cannot_switch_combat"], 1, 0.3, 0.3)
        return true
    end
    return false
end

local function ApplySavedConfig(configID, specID)
    local result = C_ClassTalents.LoadConfig(configID, true)
    if result == Enum.LoadConfigResult.Error then
        UIErrorsFrame:AddMessage(L()["loadout_dock.switch_failed"], 1, 0.3, 0.3)
        return false
    end
    if specID and C_ClassTalents.UpdateLastSelectedSavedConfigID then
        C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, configID)
    end
    return true
end

local function ApplyExportString(exportString, label)
    local p = ns.GetPerSpecState and ns.GetPerSpecState()
    if p and exportString then p.pendingApplyBuildExport = exportString end
    if ns.ApplyTalentExportString then ns.ApplyTalentExportString(exportString, label) end
end

local function GetActiveSpecIcon()
    local specIndex = GetSpecialization and GetSpecialization()
    if specIndex then
        local _, _, _, iconTex = GetSpecializationInfo(specIndex)
        return iconTex
    end
    return nil
end

local function GetDockBackgroundColor()
    if ClassCodexDB and ClassCodexDB.dockLoadoutBackground == "custom" then
        local c = ClassCodexDB.dockLoadoutBackgroundColor
        if c and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then return c.r, c.g, c.b end
    end
    local _, classToken = UnitClass("player")
    if classToken then
        if C_ClassColor and C_ClassColor.GetClassColor then
            local ok, cc = pcall(C_ClassColor.GetClassColor, classToken)
            if ok and cc then return cc.r, cc.g, cc.b end
        end
        local rc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
        if rc then return rc.r, rc.g, rc.b end
    end
    return 0.08, 0.08, 0.09
end

local function GetDockTheme()
    local t = ClassCodexDB and ClassCodexDB.dockLoadoutTheme
    if t == "compact" or t == "minimalist" then return t end
    return "codex"
end

local function ThemeShowsIcons()
    return GetDockTheme() ~= "minimalist"
end

local function GetBuildFilter()
    local f = ClassCodexDB and ClassCodexDB.dockLoadoutBuildFilter
    if f == "all" or f == "recommended" then return f end
    return "hero"
end

local function GetShowPvp()
    return (ClassCodexDB and ClassCodexDB.dockLoadoutShowPvp) ~= false
end

local function GetMaxWidth()
    local w = ClassCodexDB and ClassCodexDB.dockLoadoutMaxWidth
    if type(w) == "number" then return math.max(DOCK_MIN_WIDTH, math.min(600, w)) end
    return DOCK_MAX_WIDTH
end

local function GetHeroFilter()
    return (ClassCodexDB and ClassCodexDB.dockLoadoutHeroFilter) or "auto"
end

local function GetEffectiveHero()
    local saved = GetHeroFilter()
    if saved ~= "auto" then return saved end
    return ns.GetActiveHeroTalentName and ns.GetActiveHeroTalentName()
end

local function ringedTexture(owner, size)
    local tex = owner:CreateTexture(nil, "ARTWORK")
    tex:SetSize(size, size)
    tex:SetTexCoord(0, 1, 0, 1)
    local mask = owner:CreateMaskTexture()
    mask:SetAllPoints(tex)
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    tex:AddMaskTexture(mask)
    local ring = owner:CreateTexture(nil, "OVERLAY")
    ring:SetAtlas("Artifacts-PerkRing-Final")
    ring:SetPoint("CENTER", tex, "CENTER")
    ring:SetSize(size * 1.42, size * 1.42)
    return tex
end

local function UpdateDockTint(f)
    f = f or dock
    if not (f and f.tint) then return end
    if GetDockTheme() ~= "codex" then
        f.tint:Hide()
        return
    end
    f.tint:Show()
    local r, g, b = 0.35, 0.35, 0.42
    if f.tint.SetGradient and CreateColor then
        f.tint:SetColorTexture(1, 1, 1, 1)
        f.tint:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.32 * 0.35), CreateColor(r, g, b, 0.32))
    else
        f.tint:SetColorTexture(r, g, b, 0.32)
    end
end

local function LayoutDockContent()
    if not dock then return end
    local alignment = (ClassCodexDB and ClassCodexDB.dockLoadoutAlignment) or "LEFT"
    local frameW = dock:GetWidth() or DOCK_DEFAULT_WIDTH
    local rightPad = PAD

    local showIcons = ThemeShowsIcons()
    local hasSpec = showIcons and dock.specIcon:IsShown()
    local hasHero = showIcons and dock.heroIcon:IsShown()
    local iconCount = (hasSpec and 1 or 0) + (hasHero and 1 or 0)
    local iconsW = iconCount * ICON_SIZE + math.max(0, iconCount - 1) * ICON_GAP
    local labelW = dock.label:GetStringWidth() or 0
    local groupW = iconsW + (iconCount > 0 and labelW > 0 and LABEL_GAP or 0) + labelW

    local iconOffset
    if alignment == "CENTER" then
        iconOffset = math.max(PAD, math.floor((frameW - groupW - rightPad) / 2))
    elseif alignment == "RIGHT" then
        iconOffset = math.max(PAD, frameW - groupW - rightPad)
    else
        iconOffset = PAD
    end

    dock.specIcon:ClearAllPoints()
    dock.heroIcon:ClearAllPoints()
    dock.label:ClearAllPoints()
    dock.label:Show()

    local cursor = iconOffset
    if hasSpec then
        dock.specIcon:SetPoint("LEFT", cursor, 0)
        cursor = cursor + ICON_SIZE + (hasHero and ICON_GAP or 0)
    end
    if hasHero then
        dock.heroIcon:SetPoint("LEFT", cursor, 0)
        cursor = cursor + ICON_SIZE
    end

    local labelLeft = (iconCount > 0) and (cursor + LABEL_GAP) or PAD
    dock.label:SetPoint("LEFT", labelLeft, 0)
    dock.label:SetPoint("RIGHT", -rightPad, 0)

    if alignment == "CENTER" then
        dock.label:SetJustifyH("CENTER")
    elseif alignment == "RIGHT" then
        dock.label:SetJustifyH("RIGHT")
    else
        dock.label:SetJustifyH("LEFT")
    end
end

local function RefreshLabel()
    if not dock then return end
    local db = ClassCodexDB or {}
    local l = L()

    local showSpec = db.dockLoadoutShowSpecIcon ~= false and ThemeShowsIcons()
    if showSpec then
        local iconTex = GetActiveSpecIcon()
        if iconTex then
            dock.specIcon:SetTexture(iconTex)
            dock.specIcon:Show()
        else
            dock.specIcon:Hide()
        end
    else
        dock.specIcon:Hide()
    end

    local showHero = db.dockLoadoutShowHeroIcon ~= false and ThemeShowsIcons()
    local heroName = ns.GetActiveHeroTalentName and ns.GetActiveHeroTalentName()
    local heroAtlas = heroName and ns.HERO_TALENT_ATLAS and ns.HERO_TALENT_ATLAS[heroName]
    if showHero and heroAtlas then
        dock.heroIcon:SetAtlas(heroAtlas)
        dock.heroIcon:Show()
    else
        dock.heroIcon:Hide()
    end

    local labelText
    local active = GetActiveLoadoutName()
    if active and active ~= "" then
        labelText = active
    else
        local specData = ns.GetSpecData and ns.GetSpecData()
        local codexMatch = MatchCodexBuild(specData)
        if codexMatch and ns.FormatBuildLabel then
            labelText = ns.FormatBuildLabel(codexMatch)
        else
            local classToken, specSlug
            if ns.GetClassAndSpec then
                classToken, specSlug = ns.GetClassAndSpec()
            end
            local uggBuild, uggCtx = MatchUggBuild(classToken, specSlug)
            if uggBuild and uggCtx then
                labelText = (ns.GetUggEncounterLabel and ns.GetUggEncounterLabel(uggCtx)) or "U.GG"
            end
        end
    end

    if not labelText or labelText == "" then
        local noSpec = not (GetSpecialization and GetSpecialization())
        local fallback = noSpec and l["loadout_dock.no_spec"] or l["loadout_dock.custom_build"]
        labelText = "|cff808080" .. fallback .. "|r"
    end
    dock.label:SetText(labelText)

    if ClassCodexDB and ClassCodexDB.dockLoadoutAutoWidth then ns.ApplyLoadoutDockWidth() end

    LayoutDockContent()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if dock and dock:IsShown() then
                if ClassCodexDB and ClassCodexDB.dockLoadoutAutoWidth then ns.ApplyLoadoutDockWidth() end
                LayoutDockContent()
            end
        end)
    end
end

local MARKER_CURRENT = "  |TInterface\\Buttons\\UI-CheckBox-Check:16:16:0:0|t"
local MARKER_MATCH = "  |TInterface\\COMMON\\Indicator-Green:12:12:0:0|t"
local function LoadoutMarker(kind)
    if kind == "current" then
        return MARKER_CURRENT
    elseif kind == "match" then
        return MARKER_MATCH
    end
    return ""
end

local function BuildLoadoutMenu(_, root)
    local l = L()
    local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID()
    local specData = ns.GetSpecData and ns.GetSpecData()

    local apply = BuildApplyContext()
    local activeMatches = apply.matches

    local db = ClassCodexDB or {}

    local buildFilter = GetBuildFilter()
    local activeHero = GetEffectiveHero()
    local function buildIsRecommended(build, isOverview)
        if not build then return false end
        return isOverview == true or build.recommended == true
    end
    local function buildIncluded(build, isOverview)
        if not build then return false end
        if buildFilter == "hero" then
            -- follow the current (or chosen) hero talent; fall back to
            -- recommended picks when no hero talent is active
            if activeHero then
                if build.heroTalent ~= activeHero then return false end
            elseif not buildIsRecommended(build, isOverview) then
                return false
            end
            return true
        end
        if buildFilter == "recommended" and not buildIsRecommended(build, isOverview) then return false end
        return true
    end

    local hasBlizzard = false
    if db.dockLoadoutShowSaved ~= false and specID and C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID then
        local configs = C_ClassTalents.GetConfigIDsBySpecID(specID)
        if configs and #configs > 0 then
            local activeSavedID = specID and lastLoadedConfigBySpec[specID]
            if activeSavedID and not IsLiveSavedConfig(specID, activeSavedID) then activeSavedID = nil end
            if not activeSavedID and specID and C_ClassTalents.GetLastSelectedSavedConfigID then
                activeSavedID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
            end
            root:CreateTitle(l["loadout_dock.saved_loadouts"])
            for _, configID in ipairs(configs) do
                local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID)
                local name = info and info.name or ("Loadout " .. configID)

                if ns.IsCCSlotName and ns.IsCCSlotName(name) and ns.WrapCCName then name = ns.WrapCCName(name) end

                local kind
                if activeSavedID and configID == activeSavedID then
                    kind = "current"
                elseif C_Traits and C_Traits.GenerateImportString then
                    local ok, str = pcall(C_Traits.GenerateImportString, configID)
                    if ok and str and activeMatches(str) then kind = "match" end
                end
                name = name .. LoadoutMarker(kind)
                root:CreateButton(name, function()
                    if GuardCombat() then return end
                    ApplySavedConfig(configID, specID)
                end)
            end
            hasBlizzard = true
        end
    end

    local classToken, specSlug
    if ns.GetClassAndSpec then
        classToken, specSlug = ns.GetClassAndSpec()
    end

    local hasIcyVeins = false
    local ivPvpBuilds = {}
    if db.dockLoadoutShowIcyVeins ~= false and classToken and specSlug and ns.GetIcyVeinsTalentSpecData then
        local ivSpecData = ns:GetIcyVeinsTalentSpecData(classToken, specSlug)
        local ivBuilds = {}
        if ivSpecData and ivSpecData.talents then
            for _, build in ipairs(ivSpecData.talents) do
                -- PvP builds nest under their own submenu, mirroring the u.gg
                -- section's grouping, and respect the "Show PvP builds" toggle.
                if buildIncluded(build, false) then
                    if build.context == "PvP" then
                        if GetShowPvp() then ivPvpBuilds[#ivPvpBuilds + 1] = build end
                    else
                        ivBuilds[#ivBuilds + 1] = build
                    end
                end
            end
        end
        if #ivBuilds > 0 or #ivPvpBuilds > 0 then
            if hasBlizzard then root:CreateDivider() end
            root:CreateTitle(
                "|TInterface\\AddOns\\BreadClassCodex\\Media\\icyveins:14:14:0:0|t  "
                    .. (l["settings.value.icyveins"] or "Icy Veins")
            )
            local function ivButton(parent, build)
                local capturedExport = build.exportString
                local capturedLabel = build.buildLabel or build.context or "Build"
                -- Match the submenus: hero-talent icon ahead of the build label.
                local heroAtlas = build.heroTalent and ns.HERO_TALENT_ATLAS and ns.HERO_TALENT_ATLAS[build.heroTalent]
                if heroAtlas then capturedLabel = "|A:" .. heroAtlas .. ":14:14|a " .. capturedLabel end
                local label = capturedLabel
                if activeMatches(capturedExport) then label = label .. MARKER_MATCH end
                parent:CreateButton(label, function()
                    if GuardCombat() then return end
                    ApplyExportString(capturedExport, "Icy Veins " .. capturedLabel)
                end)
            end
            for _, build in ipairs(ivBuilds) do
                ivButton(root, build)
            end
            if #ivPvpBuilds > 0 then
                -- PvP builds nest under their own submenu, mirroring the u.gg
                -- section's grouping; the section survives on PvP-only specs.
                local sub = root:CreateButton(l["pvp.label"] or "PvP")
                for _, build in ipairs(ivPvpBuilds) do
                    ivButton(sub, build)
                end
            end
            hasIcyVeins = true
        end
    end

    local uggSpecData
    if db.dockLoadoutShowUgg ~= false and classToken and specSlug and ns.GetUggSpecData then
        uggSpecData = ns.GetUggSpecData(classToken, specSlug)
    end
    local hasUgg = false

    local uggReason
    if not classToken then
        uggReason = "no class detected"
    elseif not specSlug then
        uggReason = "no spec slug detected"
    elseif not _G.UGGData then
        uggReason = "UGGData global missing"
    elseif not _G.UGGData[classToken] then
        uggReason = "no ugg data for class " .. classToken
    elseif not _G.UGGData[classToken][specSlug] then
        uggReason = "no ugg data for " .. classToken .. "/" .. specSlug
    elseif not uggSpecData then
        uggReason = "spec data resolution returned nil"
    elseif not uggSpecData.contexts then
        uggReason = "spec data has no contexts table"
    elseif not ns.GroupUggContexts then
        uggReason = "GroupUggContexts helper missing"
    end
    if uggReason then
        if hasBlizzard or hasIcyVeins then root:CreateDivider() end
        root:CreateTitle("|TInterface\\AddOns\\BreadClassCodex\\Media\\ugg:14:14:0:0|t  " .. l["settings.value.ugg"])
        root:CreateButton("|cff999999" .. uggReason .. "|r", function() end)
    end
    if uggSpecData and uggSpecData.contexts and ns.GroupUggContexts then
        local groups = ns.GroupUggContexts(uggSpecData)

        -- the recommended pick of a u.gg context is builds[1] — SourceReader
        -- pre-sorts each context by popularity (pickrate weighted by hero usage),
        -- matching how the talents page marks builds
        local function uggTopBuild(entry)
            local builds = entry and entry.ctx and entry.ctx.builds
            if not builds then return nil end
            return builds[1]
        end

        local function uggLabel(entry, override)
            local ctx = entry.ctx
            local base = override or (ns.GetUggEncounterLabel and ns.GetUggEncounterLabel(ctx)) or entry.contextKey
            local build = uggTopBuild(entry)
            if build and build.heroTalent and ns.HERO_TALENT_ATLAS then
                local atlas = ns.HERO_TALENT_ATLAS[build.heroTalent]
                if atlas then base = "|A:" .. atlas .. ":12:12|a " .. base end
            end
            if build and activeMatches(build.exportString) then base = base .. MARKER_MATCH end
            return base, build
        end

        local function uggApply(parent, entry, override, isOverview)
            local label, build = uggLabel(entry, override)
            if not build then return end
            local clean = override
                or (ns.GetUggEncounterLabel and ns.GetUggEncounterLabel(entry.ctx))
                or entry.contextKey
            parent:CreateButton(label, function()
                if GuardCombat() then return end
                ApplyExportString(build.exportString, clean)
            end)
        end

        local raidDiff = (ClassCodexDB and ClassCodexDB.raidDifficulty) or "both"
        local groupDefs = {
            {
                header = l["context.mplus_dungeons"],
                overview = groups.mplusOverview,
                list = groups.mplusDungeons,
            },
        }
        if raidDiff == "heroic" or raidDiff == "both" then
            groupDefs[#groupDefs + 1] = {
                header = l["context.raid_heroic"],
                overview = groups.raidOverviewHeroic,
                list = groups.raidHeroicBosses,
            }
        end
        if raidDiff == "mythic" or raidDiff == "both" then
            groupDefs[#groupDefs + 1] = {
                header = l["context.raid_mythic"],
                overview = groups.raidOverviewMythic,
                list = groups.raidMythicBosses,
            }
        end
        if GetShowPvp() then
            local pvpEntries = {}
            for _, e in ipairs(groups.pvpArena or {}) do
                pvpEntries[#pvpEntries + 1] = e
            end
            for _, e in ipairs(groups.pvpBattleground or {}) do
                pvpEntries[#pvpEntries + 1] = e
            end
            -- the "pvp" all-brackets overview context lands in the arena
            -- bucket; pull it out so it doesn't read as a duplicate header
            local pvpOverview, pvpList = nil, {}
            for _, e in ipairs(pvpEntries) do
                if e.ctx and e.ctx.encounter == "all-brackets" then
                    pvpOverview = e
                else
                    pvpList[#pvpList + 1] = e
                end
            end
            groupDefs[#groupDefs + 1] = {
                header = l["pvp.label"] or "PvP",
                overview = pvpOverview,
                overviewLabel = l["loadout_dock.pvp_all_brackets"],
                list = pvpList,
            }
        end

        local function entryBuild(entry)
            return uggTopBuild(entry)
        end

        local hasAny = false
        for _, def in ipairs(groupDefs) do
            if def.overview and buildIncluded(entryBuild(def.overview), true) then
                hasAny = true
                break
            end
            for _, e in ipairs(def.list or {}) do
                if buildIncluded(entryBuild(e), true) then
                    hasAny = true
                    break
                end
            end
        end
        if hasAny then
            if hasBlizzard or hasIcyVeins then root:CreateDivider() end
            root:CreateTitle("|TInterface\\AddOns\\BreadClassCodex\\Media\\ugg:14:14:0:0|t  " .. l["settings.value.ugg"])

            for _, def in ipairs(groupDefs) do
                local sub = nil
                local overviewShown = false
                if def.overview and buildIncluded(entryBuild(def.overview), true) then
                    sub = root:CreateButton(def.header)
                    uggApply(sub, def.overview, def.overviewLabel, true)
                    overviewShown = true
                end
                local listedAny = false
                for _, e in ipairs(def.list or {}) do
                    if buildIncluded(entryBuild(e), true) then
                        sub = sub or root:CreateButton(def.header)
                        if e.separatorBefore or (overviewShown and not listedAny) then sub:CreateDivider() end
                        listedAny = true
                        uggApply(sub, e)
                    end
                end
            end
            hasUgg = true
        end
    end

    if
        not hasBlizzard
        and not hasUgg
        and not hasIcyVeins
        and (not specData or not specData.talents or #specData.talents == 0)
    then
        root:CreateTitle(l["loadout_dock.no_loadouts"])
    end
end

local function BuildOptionsMenu(_, root)
    local l = L()
    root:CreateTitle(l["loadout_dock.builds_title"])
    local specIconTex = GetActiveSpecIcon()
    local allLabel = (specIconTex and ("|T" .. specIconTex .. ":14:14:0:0|t  ") or "") .. l["loadout_dock.builds_all"]
    local recommendedLabel = "|TInterface\\Common\\FavoritesIcon:14:14:0:0|t  " .. l["loadout_dock.builds_recommended"]
    root:CreateRadio(allLabel, function()
        return GetBuildFilter() == "all"
    end, function()
        if ClassCodexDB then ClassCodexDB.dockLoadoutBuildFilter = "all" end
        return MenuResponse.Refresh
    end)
    root:CreateRadio(recommendedLabel, function()
        return GetBuildFilter() == "recommended"
    end, function()
        if ClassCodexDB then ClassCodexDB.dockLoadoutBuildFilter = "recommended" end
        return MenuResponse.Refresh
    end)

    local specData = ns.GetSpecData and ns.GetSpecData()
    local heroOptions = (specData and ns.GetHeroTalentOptions and ns.GetHeroTalentOptions(specData)) or {}
    local activeHeroName = ns.GetActiveHeroTalentName and ns.GetActiveHeroTalentName()
    for _, heroName in ipairs(heroOptions) do
        local atlas = ns.HERO_TALENT_ATLAS and ns.HERO_TALENT_ATLAS[heroName]
        local label = atlas and ("|A:" .. atlas .. ":14:14|a  " .. heroName) or heroName
        root:CreateRadio(label, function()
            if GetBuildFilter() ~= "hero" then return false end
            local saved = GetHeroFilter()
            if saved ~= "auto" then return saved == heroName end
            return heroName == activeHeroName
        end, function()
            if ClassCodexDB then
                ClassCodexDB.dockLoadoutHeroFilter = heroName
                ClassCodexDB.dockLoadoutBuildFilter = "hero"
            end
            return MenuResponse.Refresh
        end)
    end

    root:CreateDivider()
    local locked = ClassCodexDB and ClassCodexDB.dockLoadoutLocked
    local lockLabel = locked and l["loadout_dock.unlock_position"] or l["loadout_dock.lock_position"]
    root:CreateButton(lockLabel, function()
        if not ClassCodexDB then return end
        ClassCodexDB.dockLoadoutLocked = not ClassCodexDB.dockLoadoutLocked
        return MenuResponse.Refresh
    end)
    root:CreateButton(l["loadout_dock.all_settings"], function()
        if not InCombatLockdown() and ns.loadoutDockSettingsCategory and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(ns.loadoutDockSettingsCategory:GetID())
        elseif ns.OpenSettings then
            ns.OpenSettings(dock)
        end
    end)
end

local ApplyDockBackdrop -- forward declaration; defined after CreateDock

local function CreateDock()
    local f = CreateFrame("Button", "ClassCodexLoadoutDock", UIParent, "BackdropTemplate")
    local savedWidth = (ClassCodexDB and ClassCodexDB.dockLoadoutWidth) or DOCK_DEFAULT_WIDTH
    f:SetSize(math.max(DOCK_MIN_WIDTH, math.min(DOCK_MAX_WIDTH, savedWidth)), DOCK_HEIGHT)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:RegisterForDrag("LeftButton")

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.09, 0.95)
    f:SetBackdropBorderColor(BORDER_CARD[1], BORDER_CARD[2], BORDER_CARD[3], BORDER_CARD[4])

    local tint = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetPoint("TOPLEFT", 3, -3)
    tint:SetPoint("BOTTOMRIGHT", -3, 3)
    tint:SetColorTexture(1, 1, 1, 1)
    f.tint = tint

    local hl = f:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 3, -3)
    hl:SetPoint("BOTTOMRIGHT", -3, 3)
    hl:SetColorTexture(1, 1, 1, 0.06)

    local specIcon = ringedTexture(f, ICON_SIZE)
    f.specIcon = specIcon

    local heroIcon = ringedTexture(f, ICON_SIZE)
    f.heroIcon = heroIcon

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetTextColor(1, 1, 1)
    f.label = label

    f:SetScript("OnDragStart", function(self)
        if ClassCodexDB and ClassCodexDB.dockLoadoutLocked then return end
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not ClassCodexDB then return end
        local point, _, relativePoint, x, y = self:GetPoint()
        ClassCodexDB.dockLoadoutPosition = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end)

    f:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            MenuUtil.CreateContextMenu(self, BuildOptionsMenu)
        else
            MenuUtil.CreateContextMenu(self, BuildLoadoutMenu)
        end
    end)

    f:SetScript("OnEnter", function(self)
        local l = L()
        if GetDockTheme() == "codex" then self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9) end
        ns.Tooltip.Open(self, "ANCHOR_BOTTOMRIGHT")

        local fullName = GetActiveLoadoutName()
        if fullName and fullName ~= "" then
            ns.Tooltip.Title(fullName)
        else
            ns.Tooltip.Title("Bread Codex")
        end

        local isCCLoadout = fullName and ns.IsCCSlotName and ns.IsCCSlotName(fullName)
        if not isCCLoadout then
            local specData = ns.GetSpecData and ns.GetSpecData()
            local codexMatch = MatchCodexBuild(specData)
            if codexMatch and ns.FormatBuildLabel then
                ns.Tooltip.Hint(
                    "|TInterface\\AddOns\\BreadClassCodex\\Media\\ugg:12:12:0:0|t  " .. ns.FormatBuildLabel(codexMatch)
                )
            else
                local classToken, specSlug
                if ns.GetClassAndSpec then
                    classToken, specSlug = ns.GetClassAndSpec()
                end
                local uggBuild, uggCtx = MatchUggBuild(classToken, specSlug)
                if uggBuild and uggCtx then
                    local uggLabel = (ns.GetUggEncounterLabel and ns.GetUggEncounterLabel(uggCtx)) or "U.GG"
                    ns.Tooltip.Hint("|TInterface\\AddOns\\BreadClassCodex\\Media\\ugg:12:12:0:0|t  " .. uggLabel)
                end
            end
        end

        ns.Tooltip.Blank()
        ns.Tooltip.Intro(l["loadout_dock.click_to_switch"])
        ns.Tooltip.Body(l["loadout_dock.right_click_options"])
        ns.Tooltip.Show()
    end)
    f:SetScript("OnLeave", function(self)
        ApplyDockBackdrop(self)
        ns.Tooltip.Hide()
    end)

    local saved = ClassCodexDB and ClassCodexDB.dockLoadoutPosition
    f:ClearAllPoints()
    if saved and saved.point and saved.x and saved.y then
        f:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x, saved.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
    end

    ApplyDockBackdrop(f)
    UpdateDockTint(f)
    return f
end

function ApplyDockBackdrop(f)
    f = f or dock
    if not f then return end
    if GetDockTheme() ~= "codex" then
        f:SetBackdrop(nil)
        return
    end
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    local bgR, bgG, bgB = GetDockBackgroundColor()
    f:SetBackdropColor(bgR, bgG, bgB, 1)
    f:SetBackdropBorderColor(BORDER_CARD[1], BORDER_CARD[2], BORDER_CARD[3], BORDER_CARD[4])
end

function ns.ApplyLoadoutDockTheme()
    if not dock then return end
    ApplyDockBackdrop(dock)
    UpdateDockTint()
    ns.ApplyLoadoutDockWidth()
    RefreshLabel()
end

local function computeContentWidth()
    if not dock then return 0 end
    local showIcons = ThemeShowsIcons()
    local hasSpec = showIcons and dock.specIcon:IsShown()
    local hasHero = showIcons and dock.heroIcon:IsShown()
    local iconCount = (hasSpec and 1 or 0) + (hasHero and 1 or 0)
    local iconsW = iconCount * ICON_SIZE + math.max(0, iconCount - 1) * ICON_GAP
    local labelW = dock.label:GetStringWidth() or 0
    return iconsW + (iconCount > 0 and labelW > 0 and LABEL_GAP or 0) + labelW + PAD
end

function ns.ApplyLoadoutDockWidth()
    if not dock then return end
    if ClassCodexDB and ClassCodexDB.dockLoadoutAutoWidth then
        local content = computeContentWidth()
        local w = math.max(DOCK_MIN_WIDTH, math.min(GetMaxWidth(), math.ceil(content + PAD)))
        dock:SetWidth(w)
    else
        local w = (ClassCodexDB and ClassCodexDB.dockLoadoutWidth) or DOCK_DEFAULT_WIDTH
        dock:SetWidth(math.max(DOCK_MIN_WIDTH, math.min(GetMaxWidth(), w)))
    end
end

function ns.ApplyLoadoutDockScale()
    if not dock then return end
    local pct = (ClassCodexDB and ClassCodexDB.dockLoadoutScale) or 100
    local scale = math.max(0.5, math.min(2.0, pct / 100))
    dock:SetScale(scale)

    if dock:IsShown() then
        ns.ApplyLoadoutDockWidth()
        LayoutDockContent()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if dock and dock:IsShown() then
                    ns.ApplyLoadoutDockWidth()
                    LayoutDockContent()
                end
            end)
        end
    end
end

function ns.ShowLoadoutDock()
    if not dock then dock = CreateDock() end
    dock:Show()
    ns.ApplyLoadoutDockTheme()
    ns.ApplyLoadoutDockWidth()
    ns.ApplyLoadoutDockScale()
    RefreshLabel()

    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            if dock and dock:IsShown() then RefreshLabel() end
        end)
    end
end

function ns.HideLoadoutDock()
    if dock then dock:Hide() end
end

function ns.RefreshLoadoutDock()
    if dock and dock:IsShown() then RefreshLabel() end
end

-- Called by the apply pipeline when a Class Codex commit/rename lands: the
-- label resolves from lastLoadedConfigBySpec / GetLastSelectedSavedConfigID,
-- neither of which reflects a CommitConfig-based apply (no LoadConfig fires,
-- and GetLastSelectedSavedConfigID can lag behind the server), so the dock
-- would keep showing the previously loaded loadout's name.
function ns.NoteCCApplyComplete(configID)
    local specID = GetCurrentSpecID()
    if specID and configID then lastLoadedConfigBySpec[specID] = configID end
    ns.RefreshLoadoutDock()
end

function ns.UpdateLoadoutDockVisibility()
    local db = ClassCodexDB
    if not db then return end
    if not db.dockLoadoutEnabled then
        ns.HideLoadoutDock()
        return
    end
    if db.dockLoadoutHideInCombat and InCombatLockdown() then
        ns.HideLoadoutDock()
        return
    end
    ns.ShowLoadoutDock()
end

if C_ClassTalents and C_ClassTalents.LoadConfig then
    hooksecurefunc(C_ClassTalents, "LoadConfig", function(configID, _autoApply)
        if not configID then return end
        local specID = GetCurrentSpecID()
        if specID then lastLoadedConfigBySpec[specID] = configID end
        if ns.RefreshLoadoutDock then ns.RefreshLoadoutDock() end
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        ns.UpdateLoadoutDockVisibility()
        if dock and dock:IsShown() then RefreshLabel() end
    elseif event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        local perSpec = ns.GetPerSpecState and ns.GetPerSpecState()
        if perSpec and perSpec.pendingApplyBuildExport then
            -- The dock tracks the player's build; never read through the
            -- (possibly stale) inspect override here.
            local bits = ns.GetActiveTalentSignature and ns.GetActiveTalentSignature(true)
            if bits then
                perSpec.lastAppliedBuildExport = perSpec.pendingApplyBuildExport
                perSpec.lastAppliedBuildBits = bits
                perSpec.pendingApplyBuildExport = nil
            end
        end
        ns.RefreshLoadoutDock()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        ns.UpdateLoadoutDockVisibility()
    end
end)
