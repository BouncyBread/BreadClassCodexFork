local _, ns = ...
ns.Sections = ns.Sections or {}

local L = ns.L

local Talents = {}
ns.Sections.Talents = Talents

local CARD_HEIGHT = 36
local CARD_GAP = 3
local MAX_CARDS = 40

local function resolveContentType(args)
    local ct = args.contentType or (ns.Context and ns.Context.contentType()) or "mplus"
    if type(ct) == "string" and ct:sub(1, 4) == "pvp:" then ct = "pvp" end
    return ct
end

local function buildCardList(args)
    local raw = (ns.GetTalentBuilds and ns.GetTalentBuilds(args.class, args.spec, args.source)) or {}
    local ct = resolveContentType(args)
    local diff = (ClassCodexDB and ClassCodexDB.raidDifficulty) or "mythic"
    if diff ~= "heroic" and diff ~= "mythic" then diff = "mythic" end
    local recommendedMode = ClassCodexDB and ClassCodexDB.talentRecommended and true or false
    local activeHero = args.activeHero
    if activeHero == nil and ns.GetActiveHero then activeHero = ns.GetActiveHero() end
    local noHero = not activeHero or activeHero == "All"

    local out = {}
    local usedContext = {}
    for order, b in ipairs(raw) do
        local contentOk = (not b.zoneKind) or b.zoneKind == ct or (b.leveling and ct ~= "pvp")
        local diffOk = (not b.difficulty) or b.difficulty == diff
        if contentOk and diffOk then
            local keep
            if recommendedMode then
                keep = b.recommended
            else
                keep = b.leveling or noHero or b.hero == activeHero
            end

            local cid = b.contextId or b.label
            if keep and not b.leveling then
                if usedContext[cid] then
                    keep = false
                else
                    usedContext[cid] = true
                end
            end

            if keep then
                local icon, portrait, tintKey, portraitPending
                if b.zoneKind == "raid" then
                    tintKey = (ns.GetCurrentRaidName and ns.GetCurrentRaidName()) or "raid"
                    if b.encounterLabel then
                        local ba = ns.GetBossArtByName and ns.GetBossArtByName(b.encounterLabel)
                        if ba then
                            portrait = ba.displayID
                        elseif ns.IsBossMapReady and not ns.IsBossMapReady() then
                            portraitPending = true
                        end
                    end
                elseif b.zoneKind == "mplus" then
                    tintKey = b.encounterLabel or "mythic-plus"
                    if b.encounterLabel then
                        icon = ns.GetDungeonIconByName and ns.GetDungeonIconByName(b.encounterLabel)
                    end
                else
                    tintKey = b.label
                end

                -- No specific art (raid/M+ overview, unknown boss, delves, PvP):
                -- fall back to a generic content-type icon before the spec icon.
                if not portrait and not portraitPending and not icon then
                    icon = ns.GetContentFallbackAtlas and ns.GetContentFallbackAtlas(b.artKind or b.zoneKind)
                end

                out[#out + 1] = {
                    title = b.label,
                    recommended = b.recommended,
                    heroTalent = b.hero,
                    exportString = b.exportString,
                    saveLabel = (b.provider or "Build") .. " - " .. (b.hero or "") .. " " .. (b.label or ""),
                    provider = b.provider,
                    icon = icon,
                    portrait = portrait,
                    portraitPending = portraitPending,
                    tintKey = tintKey,
                    leveling = b.leveling,
                    tags = b.tags,
                    honor = b.honor,
                    _order = order,
                }
            end
        end
    end

    table.sort(out, function(a, b)
        local al, bl = a.leveling and 1 or 0, b.leveling and 1 or 0
        if al ~= bl then return al < bl end
        return (a._order or 0) < (b._order or 0)
    end)
    return out
end

local function ensureCard(inst, i)
    if inst.cards[i] then return inst.cards[i] end
    local card = ns.CreateCard(inst.content, {
        height = CARD_HEIGHT,
        subtitle = true,
        actions = {
            { icon = "Interface\\AddOns\\BreadClassCodex\\Media\\action-copy", tooltip = "Copy talent string" },
            {
                icon = "Interface\\AddOns\\BreadClassCodex\\Media\\action-save",
                tooltip = (ns.L and ns.L["talent_pane.save_as.tooltip"]) or "Save as new loadout",
            },
            { icon = "Interface\\AddOns\\BreadClassCodex\\Media\\action-apply", tooltip = "Apply talents", role = "apply" },
        },
    })
    card:Hide()
    inst.cards[i] = card
    return card
end

local function bindAction(card, idx, fn)
    local b = card.actions and card.actions[idx]
    if b then b:SetScript("OnClick", fn) end
end

local function build(inst, opts, collapsible)
    inst.section = CreateFrame("Frame", nil, opts.parent)
    inst.header = (opts.header or opts.headerFactory)(inst.section, L["section.talents"], collapsible)
    inst.content = CreateFrame("Frame", nil, inst.section)
    inst.content:SetPoint("TOPLEFT", inst.header, "BOTTOMLEFT", 0, 0)
    inst.content:SetPoint("RIGHT", 0, 0)
    inst.content:SetHeight(1)

    -- Source badge on the subheader: shown only when u.gg builds are borrowed
    -- into a non-u.gg view (e.g. Icy Veins PvP-less specs) — redundant when
    -- u.gg is the active source.
    if ns.CreateSourceAttributionIcon and inst.header and inst.header.AddHeaderWidget then
        inst.uggIcon = ns.CreateSourceAttributionIcon(inst.header, "ugg", "Talent builds", "Data from u.gg", function()
            local c, sp = ns.GetClassAndSpec()
            return ns.ResolveAttribution and select(2, ns.ResolveAttribution("talents", c, sp, "ugg"))
        end)
        inst.header:AddHeaderWidget(inst.uggIcon)
    end

    inst.cards = {}
    inst.fallback = inst.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inst.fallback:SetTextColor(0.5, 0.5, 0.5)
    inst.fallback:Hide()
end

local function render(inst, args)
    for _, c in ipairs(inst.cards) do
        c:Hide()
    end
    inst.fallback:Hide()

    local list = buildCardList(args)
    if inst.cogSetShown then inst.cogSetShown(#list > 0) end

    -- The subheader carries the build choice as a suffix on u.gg views — raid
    -- shows "· Heroic/Mythic" (prefixed with "Recommended" while that filter
    -- is on), Mythic+ shows "· Recommended" alone. The suffix is the cog
    -- hotspot (glow + click menu), like the Best in Slot subheader.
    if inst.header and inst.header.label then
        local base = L["section.talents"] or "Talents"
        local ct = resolveContentType(args)
        if args.source ~= "icyveins" and (ct == "raid" or ct == "mplus") then
            local isRec = ClassCodexDB and ClassCodexDB.talentRecommended and true or false
            local suffix
            if ct == "raid" then
                local diff = (ClassCodexDB and ClassCodexDB.raidDifficulty) or "mythic"
                if diff ~= "heroic" and diff ~= "mythic" then diff = "mythic" end
                suffix = diff == "heroic" and "Heroic" or "Mythic"
                if isRec then suffix = "Recommended " .. suffix end
            else
                suffix = isRec and "Recommended" or nil
            end
            if suffix then
                inst.header.label:SetText(base .. " · " .. suffix)
            else
                inst.header.label:SetText(base)
            end
        else
            inst.header.label:SetText(base)
        end
    end

    if inst.uggIcon then
        local borrowed = false
        if args.source ~= "ugg" then
            for _, d in ipairs(list) do
                if d.provider == "u.gg" then
                    borrowed = true
                    break
                end
            end
        end
        inst.uggIcon:SetShown(borrowed)
    end

    local HPAD = ns.PAGE_TITLE_HPAD or 8
    local yPos = 2

    if #list == 0 then
        local source = args.source
        inst.fallback:SetText(
            args.fallbackNoneText
                or (
                    source == "icyveins"
                        and (L["loadout_dock.no_icyveins_builds"] or "No Icy Veins talent builds available.")
                    or (L["loadout_dock.no_talent_builds"] or "No talent builds available.")
                )
        )
        inst.fallback:ClearAllPoints()
        inst.fallback:SetPoint("TOPLEFT", inst.content, "TOPLEFT", 0, -yPos)
        inst.fallback:Show()
        yPos = yPos + 20
        inst.content:SetHeight(math.max(1, yPos - CARD_GAP))
        inst.section:Show()
        return inst.content:GetHeight()
    end

    local matchActive = args.matchActive or ns.BuildMatchesActive
    local showActions = args.showActions ~= false
    local count = math.min(#list, MAX_CARDS)
    for i = 1, count do
        local d = list[i]
        local card = ensureCard(inst, i)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", inst.content, "TOPLEFT", HPAD, -yPos)
        card:SetPoint("RIGHT", inst.content, "RIGHT", -HPAD, 0)

        card:SetTitle(d.title or "Build")
        card:SetRecommended(d.recommended, d.tags)

        local iconSet = false
        if d.portrait then iconSet = card:SetPortrait(d.portrait) end
        if not iconSet and d.portraitPending then
            card:SetPortraitPlaceholder()
            iconSet = true
        end
        if not iconSet and d.icon then
            card:SetIcon(d.icon)
            iconSet = true
        end
        if not iconSet then card:SetIcon(args.specIcon or 134400) end

        local heroAtlas = d.heroTalent and ns.HERO_TALENT_ATLAS and ns.HERO_TALENT_ATLAS[d.heroTalent]
        card:SetHeroIcon(heroAtlas, d.heroTalent)

        if d.tintKey and ns.TintFromKey then
            card:SetBackgroundColor(ns.TintFromKey(d.tintKey))
        else
            card:SetBackgroundColor(nil)
        end

        local isActive = matchActive and matchActive({ exportString = d.exportString }) or false
        card:SetAccent(0.35, 0.35, 0.4)
        card:SetApplied(isActive)

        local export, saveLabel = d.exportString, d.saveLabel or "Build"
        bindAction(card, 1, function()
            if args.onCopy then
                args.onCopy(export, card)
            elseif ns.ShowCopyPopup then
                ns.ShowCopyPopup(export, card)
            end
        end)
        card:SetActionShown(2, showActions)
        card:SetActionShown(3, showActions)
        if showActions then
            bindAction(card, 2, function()
                if args.onSaveAsNew then
                    args.onSaveAsNew(export, saveLabel)
                elseif ns.PromptAndSaveTalentBuild then
                    ns.PromptAndSaveTalentBuild(export, saveLabel)
                end
            end)
            bindAction(card, 3, function(self)
                if args.onApply then
                    args.onApply(export, saveLabel, self)
                elseif ns.ApplyTalentExportString then
                    local ok, err = ns.ApplyTalentExportString(export, saveLabel)
                    -- PvP builds carry their recommended honor talents; apply
                    -- them alongside the tree on success.
                    if ok and d.honor and ns.ApplyPvpHonorTalents then ns.ApplyPvpHonorTalents(d.honor) end
                    if not ok and err then print("|cff00ccffClass Codex:|r " .. err) end
                    if self and self.tex then
                        self.tex:SetVertexColor(ok and 0.3 or 1, ok and 1 or 0.3, 0.3)
                        C_Timer.After(1.2, function()
                            if self.tex then self.tex:SetVertexColor(1, 1, 1) end
                        end)
                    end
                end
            end)
        end

        card:Show()
        yPos = yPos + CARD_HEIGHT + CARD_GAP
    end
    for i = count + 1, #inst.cards do
        inst.cards[i]:Hide()
    end

    inst.content:SetHeight(math.max(1, yPos - CARD_GAP))
    inst.section:Show()
    return inst.content:GetHeight()
end

local function makeCog(inst, refresh)
    local cog = CreateFrame("Button", nil, inst.header)
    cog:SetSize(14, 14)
    cog:RegisterForClicks("LeftButtonUp")
    local cogIcon = cog:CreateTexture(nil, "ARTWORK")
    cogIcon:SetAllPoints()
    cogIcon:SetAtlas("QuestLog-icon-setting")
    cogIcon:SetVertexColor(0.6, 0.6, 0.6)
    cog:SetScript("OnEnter", function(self)
        cogIcon:SetVertexColor(1, 1, 1)
        ns.Tooltip
            .Open(self, "ANCHOR_RIGHT")
            .Title("Talent builds")
            .Blank()
            .Body("Choose raid difficulty and toggle Recommended (the most popular build per boss/dungeon).")
            .Hint("Click to change.")
            .Show()
    end)
    cog:SetScript("OnLeave", function()
        cogIcon:SetVertexColor(0.6, 0.6, 0.6)
        ns.Tooltip.Hide()
    end)
    cog:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        local ct = (inst.contentType and inst.contentType()) or (ns.Context and ns.Context.contentType()) or "mplus"
        if type(ct) == "string" and ct:sub(1, 4) == "pvp:" then ct = "pvp" end
        local isUgg = (inst.source and inst.source() or "icyveins") ~= "icyveins"
        MenuUtil.CreateContextMenu(self, function(_, root)
            if isUgg and ct == "raid" then
                root:CreateTitle("Raid difficulty")
                for _, opt in ipairs({
                    { v = "heroic", l = "Heroic" },
                    { v = "mythic", l = "Mythic" },
                }) do
                    root:CreateRadio(opt.l, function()
                        return ((ClassCodexDB and ClassCodexDB.raidDifficulty) or "mythic") == opt.v
                    end, function()
                        if ClassCodexDB then ClassCodexDB.raidDifficulty = opt.v end
                        if refresh then refresh() end
                        return MenuResponse.Refresh
                    end)
                end
                root:CreateDivider()
            end
            local rec = root:CreateCheckbox("Show Recommended", function()
                return ClassCodexDB and ClassCodexDB.talentRecommended and true or false
            end, function()
                if ClassCodexDB then ClassCodexDB.talentRecommended = not ClassCodexDB.talentRecommended end
                if refresh then refresh() end
                return MenuResponse.Refresh
            end)
            if rec and rec.SetTooltip then
                rec:SetTooltip(function(tip)
                    GameTooltip_SetTitle(tip, "Recommended")
                    GameTooltip_AddNormalLine(
                        tip,
                        "Show the build most players run for each boss or dungeon, from any hero talent. Off shows your current hero talent's build."
                    )
                end)
            end
        end)
    end)
    cog:Hide()
    inst.cog = cog
    inst.cogSetShown = function(shown)
        cog:SetShown(shown)
    end
    -- Same hover treatment as the Best in Slot subheader: the "· Heroic/Mythic"
    -- label suffix glows the cog and opens its menu.
    if ns.MakeCogGlow then
        ns.MakeCogGlow(cog, cogIcon)
        ns.MakeLabelMenuHotspot(inst.header, cog)
    end
    return cog
end

local function placeCog(inst, title)
    if not inst.cog then return end
    if title then
        inst.cog:SetParent(title)
        inst.cog:ClearAllPoints()
        if title.link then
            inst.cog:SetPoint("RIGHT", title.link, "LEFT", -3, 0)
        else
            inst.cog:SetPoint("RIGHT", title, "RIGHT", -(ns.PAGE_TITLE_HPAD or 8), 0)
        end
    elseif inst.header.AddHeaderWidget then
        inst.header:AddHeaderWidget(inst.cog)
    end
end

local panel = {}
local comp = {}

function Talents.InitPanel(opts)
    build(panel, opts, opts.collapsible ~= false)
    panel.contentType = opts.contentType
    panel.source = opts.source
    makeCog(panel, opts.refresh)
    placeCog(panel, opts.cogTitle)
    return panel.section, panel.header, panel.content
end

function Talents.RenderPanel(args)
    return render(panel, args)
end

function Talents.GetPanelContentHeight()
    return panel.content and panel.content:GetHeight() or 0
end

function Talents.SetPanelCogShown(shown)
    if panel.cogSetShown then panel.cogSetShown(shown) end
end

function Talents.InitCompendium(opts)
    build(comp, opts, false)
    comp.contentType = opts.contentType
    comp.source = opts.source
    comp.isCompendium = true
    makeCog(comp, opts.refresh)
    placeCog(comp, opts.cogTitle)
    return comp.section, comp.header, comp.content
end

function Talents.RenderCompendium(args)
    return render(comp, args)
end

function Talents.GetCompendiumContentHeight()
    return comp.content and comp.content:GetHeight() or 0
end

function Talents.PlaceCompendiumCog(title)
    placeCog(comp, title)
end

function Talents.PlacePanelCog(title)
    placeCog(panel, title)
end
