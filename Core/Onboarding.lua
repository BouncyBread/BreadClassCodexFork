local _, ns = ...
local L = ns.L

local ONBOARDING_CURRENT = 1

local ACCENT = { 1, 0.82, 0 }
local CARD_WIDTH = 340
local CARD_PAD = 16
local CONTENT_TOP = 32
local PAD = 6
local BORDER = 3
local ARROW_TEX = "Interface\\AddOns\\BreadClassCodex\\Media\\arrow-right"
local RESOLVE_DELAYS = { 0.35, 0.9, 1.6 }
local PANEL_STEPS = { context = true, tabs = true, about = true, compendium = true, dock = true }

local card, highlight, arrow, helpBtn
local steps
local index = 0
local active = false
local hooked = false
local armed = nil
local aboutTabHooked = false

local Cleanup, FinishTour, LayoutCard, ResolveAndPlace, UpdateButtons, GoToStep, UpdateHelpButton

local function RectOf(f)
    if not f or not f.IsVisible or not f:IsVisible() then return nil end
    local l, r, b, t = f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop()
    if not (l and r and b and t) then return nil end
    local rr = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    l, r, b, t = l * rr, r * rr, b * rr, t * rr
    return { l - PAD, r + PAD, b - PAD, t + PAD }
end

local function RectOfList(list)
    local l, r, b, t
    for _, f in ipairs(list) do
        local rc = RectOf(f)
        if rc then
            l = math.min(l or rc[1], rc[1])
            r = math.max(r or rc[2], rc[2])
            b = math.min(b or rc[3], rc[3])
            t = math.max(t or rc[4], rc[4])
        end
    end
    if not l then return nil end
    return { l, r, b, t }
end

local function ResolveRect(v)
    if not v then return nil end
    if type(v) == "table" and v.GetObjectType then return RectOf(v) end
    if type(v) == "table" then return RectOfList(v) end
    return nil
end

local function GetSideTabsNoAbout()
    local out = {}
    if ns.GetSideTabs then
        for _, t in ipairs(ns.GetSideTabs()) do
            if t.tabKey ~= "about" then out[#out + 1] = t end
        end
    end
    return out
end

local function GetAboutTab()
    if not ns.GetSideTabs then return nil end
    for _, t in ipairs(ns.GetSideTabs()) do
        if t.tabKey == "about" then return t end
    end
    return nil
end

local function ArmAboutTab()
    local t = GetAboutTab()
    if not t or aboutTabHooked then return end
    aboutTabHooked = true
    t:HookScript("OnClick", function()
        if active and armed == "aboutTab" then
            armed = nil
            C_Timer.After(0, function()
                if active then GoToStep(index + 1) end
            end)
        end
    end)
end

local function CloseCharacterPane()
    if CharacterFrame and CharacterFrame:IsShown() and HideUIPanel then pcall(HideUIPanel, CharacterFrame) end
end

local function OpenClassTalents()
    local util = _G.PlayerSpellsUtil
    if util and util.OpenToClassTalentsTab and pcall(util.OpenToClassTalentsTab) then return end
    if _G.PlayerSpellsFrame and ShowUIPanel then
        pcall(ShowUIPanel, _G.PlayerSpellsFrame)
        local psf = _G.PlayerSpellsFrame
        if psf.SetFrameTab and util and util.FrameTabs and util.FrameTabs.ClassTalents then
            pcall(psf.SetFrameTab, psf, util.FrameTabs.ClassTalents)
        end
        return
    end
    if _G.ToggleTalentFrame then pcall(_G.ToggleTalentFrame) end
end

local function CloseTalents()
    if _G.PlayerSpellsFrame and _G.PlayerSpellsFrame:IsShown() and HideUIPanel then
        pcall(HideUIPanel, _G.PlayerSpellsFrame)
    end
end

local function bobArrow(dx, dy)
    if not arrow.bob then return end
    if arrow.bob:IsPlaying() and arrow._bobX == dx and arrow._bobY == dy then return end
    arrow._bobX, arrow._bobY = dx, dy
    arrow.bob:Stop()
    arrow.bobT:SetOffset(dx, dy)
    arrow.bob:Play()
end

local function PlaceCard(rect, placement)
    card:ClearAllPoints()
    if not rect then
        card:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        if arrow.bob then arrow.bob:Stop() end
        arrow:Hide()
        return
    end
    local l, r, b, t = rect[1], rect[2], rect[3], rect[4]
    local W = UIParent:GetWidth()
    local ch = card:GetHeight()
    if placement == "right" then
        local H = UIParent:GetHeight()
        local cy = math.max(ch / 2 + 10, math.min(H - ch / 2 - 10, (b + t) / 2))
        local x = math.min(r + 28, W - CARD_WIDTH - 10)
        card:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x, cy)
        arrow:ClearAllPoints()
        arrow:SetPoint("RIGHT", card, "LEFT", -2, 0)
        arrow:SetRotationBoth(math.pi)
        arrow:Show()
        bobArrow(-3, 0)
        return
    end
    local cx = (l + r) / 2
    local half = CARD_WIDTH / 2 + 12
    cx = math.max(half, math.min(W - half, cx))
    if b - 28 - ch > 20 then
        card:SetPoint("TOP", UIParent, "BOTTOMLEFT", cx, b - 28)
        arrow:ClearAllPoints()
        arrow:SetPoint("BOTTOM", card, "TOP", 0, 2)
        arrow:SetRotationBoth(math.pi / 2)
        arrow:Show()
        bobArrow(0, 3)
    else
        card:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx, t + 28)
        arrow:ClearAllPoints()
        arrow:SetPoint("TOP", card, "BOTTOM", 0, -2)
        arrow:SetRotationBoth(-math.pi / 2)
        arrow:Show()
        bobArrow(0, -3)
    end
end

UpdateButtons = function()
    local isFinal = index == #steps
    card.next:SetShown(not isFinal)
    if not isFinal then
        local target = card.next.label or card.next
        target:SetText(L["onboarding.next"])
        if card.next.marker then card.next.marker:SetShown(true) end
    end
end

LayoutCard = function()
    local innerW = CARD_WIDTH - 2 * CARD_PAD
    card.body:ClearAllPoints()
    card.body:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -CONTENT_TOP)
    card.body:SetWidth(innerW)
    local h = CONTENT_TOP + card.body:GetStringHeight()
    local prev
    local shown = 0
    for _, row in ipairs(card.linkRows) do
        if row:IsShown() then
            row:ClearAllPoints()
            if prev then
                row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -5)
            else
                row:SetPoint("TOPLEFT", card.body, "BOTTOMLEFT", 0, -12)
            end
            row:SetPoint("RIGHT", card, "RIGHT", -CARD_PAD, 0)
            prev = row
            shown = shown + 1
        end
    end
    if shown > 0 then h = h + 12 + shown * 34 + (shown - 1) * 5 end
    if card.next:IsShown() then
        local nextH = card.next:GetHeight()
        if not nextH or nextH < 1 then nextH = 34 end
        h = h + 12 + nextH + CARD_PAD
        card:SetHeight(h)
        card.next:ClearAllPoints()
        card.next:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", CARD_PAD, CARD_PAD)
        card.next:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -CARD_PAD, CARD_PAD)
    else
        h = h + CARD_PAD
        card:SetHeight(h)
    end
end

ResolveAndPlace = function(step)
    if not step then return end
    local rect
    if step.anchor then rect = ResolveRect(step.anchor()) end
    if rect then
        highlight:ClearAllPoints()
        highlight:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rect[1], rect[3])
        highlight:SetSize(math.max(1, rect[2] - rect[1]), math.max(1, rect[4] - rect[3]))
        highlight:Show()
        highlight.pulse:Play()
    else
        highlight.pulse:Stop()
        highlight:Hide()
    end
    LayoutCard()
    PlaceCard(rect, step.placement)
end

local function EnsureFrames()
    if highlight then return end

    highlight = CreateFrame("Frame", "ClassCodexOnboardingHighlight", UIParent)
    highlight:SetFrameStrata("DIALOG")
    highlight:SetFrameLevel(10)
    highlight:Hide()
    highlight.edges = {}
    for i = 1, 4 do
        local e = highlight:CreateTexture(nil, "OVERLAY")
        e:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        highlight.edges[i] = e
    end
    local top, bottom, left, right = highlight.edges[1], highlight.edges[2], highlight.edges[3], highlight.edges[4]
    top:SetPoint("TOPLEFT", highlight, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", highlight, "TOPRIGHT", 0, 0)
    top:SetHeight(BORDER)
    bottom:SetPoint("BOTTOMLEFT", highlight, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", highlight, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(BORDER)
    left:SetPoint("TOPLEFT", highlight, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", highlight, "BOTTOMLEFT", 0, 0)
    left:SetWidth(BORDER)
    right:SetPoint("TOPRIGHT", highlight, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", highlight, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(BORDER)

    local ag = highlight:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0.35)
    a:SetToAlpha(1)
    a:SetDuration(0.7)
    highlight.pulse = ag

    card = CreateFrame("Frame", "ClassCodexOnboardingCard", UIParent, "ButtonFrameTemplate")
    card:SetFrameStrata("DIALOG")
    card:SetFrameLevel(40)
    card:SetWidth(CARD_WIDTH)
    card:SetHeight(160)
    card:EnableMouse(true)
    if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(card) end
    if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(card) end
    if card.SetTitle then card:SetTitle("") end
    local titleFS = card.TitleContainer and card.TitleContainer.TitleText
    if titleFS then
        titleFS:ClearAllPoints()
        titleFS:SetPoint("LEFT", card, "TOPLEFT", 14, -13)
        titleFS:SetJustifyH("LEFT")
    end
    if card.CloseButton then card.CloseButton:SetScript("OnClick", function()
        FinishTour({})
    end) end
    if card.Inset then
        card.Inset:ClearAllPoints()
        card.Inset:SetPoint("TOPLEFT", card, "TOPLEFT", 7, -26)
        card.Inset:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -4, 6)
    end

    arrow = CreateFrame("Frame", nil, card)
    arrow:SetSize(22, 22)
    arrow:Hide()
    arrow.outlines = {}
    for _, off in ipairs({ { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }) do
        local ol = arrow:CreateTexture(nil, "BACKGROUND")
        ol:SetTexture(ARROW_TEX)
        ol:SetVertexColor(0, 0, 0, 1)
        ol:SetPoint("CENTER", arrow, "CENTER", off[1], off[2])
        ol:SetSize(22, 22)
        arrow.outlines[#arrow.outlines + 1] = ol
    end
    arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
    arrow.tex:SetTexture(ARROW_TEX)
    arrow.tex:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    arrow.tex:SetAllPoints(arrow)
    function arrow:SetRotationBoth(r)
        self.tex:SetRotation(r)
        for _, ol in ipairs(self.outlines) do
            ol:SetRotation(r)
        end
    end
    arrow.bob = arrow:CreateAnimationGroup()
    arrow.bob:SetLooping("BOUNCE")
    arrow.bobT = arrow.bob:CreateAnimation("Translation")
    arrow.bobT:SetDuration(0.9)
    arrow.bobT:SetSmoothing("IN_OUT")

    card.body = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.body:SetJustifyH("LEFT")
    card.body:SetSpacing(4)

    card.linkRows = {}
    if ns.AboutLinkRow then
        local DISCORD = { 0.34, 0.40, 0.95 }
        local GREY = { 0.6, 0.6, 0.66 }
        local ivIcon = (ns.SourceTexturePath and ns.SourceTexturePath("icyveins"))
            or "Interface\\AddOns\\BreadClassCodex\\Media\\icyveins"
        local ivColor = ns.SOURCES and ns.SOURCES.icyveins and ns.SOURCES.icyveins.color
        local defs = {
            {
                icon = "Interface\\AddOns\\BreadClassCodex\\Media\\gear",
                label = L["about.all_settings"],
                tip = L["about.settings_tip"],
                marker = ARROW_TEX,
                tint = GREY,
                color = GREY,
                alpha = 0.28,
                onClick = function()
                    FinishTour({})
                    if ns.OpenSettings then ns.OpenSettings() end
                end,
            },
            {
                icon = "Interface\\AddOns\\BreadClassCodex\\Media\\discord",
                label = L["about.discord"],
                tip = L["about.discord_tip"],
                color = DISCORD,
                alpha = 0.75,
                round = true,
                onClick = function(self)
                    if ns.ShowCopyPopup and ns.DISCORD_URL then ns.ShowCopyPopup(ns.DISCORD_URL, self) end
                end,
            },
            {
                icon = ivIcon,
                label = L["about.support_iv"],
                tip = L["about.support_iv_tip"],
                color = ivColor,
                alpha = 0.75,
                round = true,
                onClick = function(self)
                    local url = ns.ICYVEINS_PREMIUM_URL
                    if ns.WithReferral then url = ns.WithReferral(url) end
                    if ns.ShowCopyPopup and url then ns.ShowCopyPopup(url, self) end
                end,
            },
        }
        for _, d in ipairs(defs) do
            local row = ns.AboutLinkRow(card, d)
            row:Hide()
            card.linkRows[#card.linkRows + 1] = row
        end
    end

    local function onNext()
        if index == #steps then
            FinishTour({})
        else
            GoToStep(index + 1)
        end
    end
    if ns.AboutLinkRow then
        card.next = ns.AboutLinkRow(card, {
            label = L["onboarding.next"],
            marker = ARROW_TEX,
            color = { 0.86, 0.22, 0.22 },
            alpha = 0.7,
            onClick = onNext,
        })
        card.next.icon:Hide()
        card.next.label:ClearAllPoints()
        card.next.label:SetPoint("LEFT", card.next, "LEFT", 12, 0)
        card.next.label:SetPoint("RIGHT", card.next.marker, "LEFT", -6, 0)
    else
        card.next = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
        card.next:SetSize(130, 24)
        card.next:SetText(L["onboarding.next"])
        card.next:SetScript("OnClick", onNext)
    end

    card:Hide()
end

Cleanup = function()
    if steps and steps[index] and steps[index].onExit then pcall(steps[index].onExit) end
    if highlight then
        highlight.pulse:Stop()
        highlight:Hide()
    end
    if arrow then arrow:Hide() end
    if card then card:Hide() end
    active = false
    armed = nil
end

FinishTour = function()
    local completed = steps and index == #steps
    Cleanup()
    if ClassCodexDB then
        ClassCodexDB.onboardingVersion = ONBOARDING_CURRENT
        if completed then ClassCodexDB.showHelpButton = false end
    end
    index = 0
    UpdateHelpButton()
end

GoToStep = function(i)
    if not active then return end
    if steps[index] and steps[index].onExit then pcall(steps[index].onExit) end
    if i > #steps then
        FinishTour()
        return
    end
    if i < 1 then i = 1 end
    index = i
    local step = steps[index]
    armed = step.watch
    if step.onEnter then pcall(step.onEnter) end
    if card.SetTitle then card:SetTitle(L["onboarding.title"] .. " · " .. step.title()) end
    card.body:SetText(step.body())
    local showLinks = step.showLinks and true or false
    for _, row in ipairs(card.linkRows) do
        row:SetShown(showLinks)
    end
    if step.watch == "aboutTab" then ArmAboutTab() end
    if helpBtn and index == #steps then helpBtn:Hide() end
    UpdateButtons()
    card:Show()
    ResolveAndPlace(step)
    for _, d in ipairs(RESOLVE_DELAYS) do
        C_Timer.After(d, function()
            if active and index == i then ResolveAndPlace(step) end
        end)
    end
end

local function BuildSteps()
    if steps then return end
    steps = {
        {
            id = "context",
            placement = "right",
            title = function()
                return L["onboarding.ctx_title"]
            end,
            body = function()
                return L["onboarding.ctx_body"]
            end,
            anchor = function()
                return ns.GetContextSelector and ns.GetContextSelector()
            end,
        },
        {
            id = "tabs",
            title = function()
                return L["onboarding.tabs_title"]
            end,
            body = function()
                return L["onboarding.tabs_body"]
            end,
            anchor = function()
                return GetSideTabsNoAbout()
            end,
        },
        {
            id = "about",
            title = function()
                return L["onboarding.about_title"]
            end,
            body = function()
                return L["onboarding.about_body"]
            end,
            watch = "aboutTab",
            anchor = function()
                return GetAboutTab()
            end,
        },
        {
            id = "compendium",
            placement = "right",
            title = function()
                return L["onboarding.comp_title"]
            end,
            body = function()
                return L["onboarding.comp_body"]
            end,
            onEnter = function()
                if ns.SelectPanelTab then ns.SelectPanelTab("about") end
            end,
            anchor = function()
                return ns._onbCompendiumRow
            end,
        },
        {
            id = "dock",
            placement = "right",
            title = function()
                return L["onboarding.dock_title"]
            end,
            body = function()
                return L["onboarding.dock_body"]
            end,
            onEnter = function()
                if ns.SelectPanelTab then ns.SelectPanelTab("about") end
            end,
            anchor = function()
                return ns._onbDockRow
            end,
        },
        {
            id = "talents",
            title = function()
                return L["onboarding.talent_title"]
            end,
            body = function()
                return L["onboarding.talent_body"]
            end,
            onEnter = function()
                CloseCharacterPane()
                OpenClassTalents()
            end,
            anchor = function()
                return _G.ClassCodexTalentIcon
            end,
        },
        {
            id = "minimap",
            title = function()
                return L["onboarding.minimap_title"]
            end,
            body = function()
                return L["onboarding.minimap_body"]
            end,
            onEnter = function()
                CloseTalents()
            end,
            anchor = function()
                if ns.LDBIcon and ns.LDBIcon.GetMinimapButton then
                    local ok, btn = pcall(ns.LDBIcon.GetMinimapButton, ns.LDBIcon, "ClassCodex")
                    if ok and btn then return btn end
                end
                return _G.LibDBIcon10_ClassCodex
            end,
        },
        {
            id = "thanks",
            title = function()
                return L["onboarding.thanks_title"]
            end,
            body = function()
                return L["onboarding.thanks_body"]
            end,
            onEnter = function()
                CloseTalents()
            end,
            showLinks = true,
        },
    }
end

local function EnsurePanelVisible()
    if not ns.panel then return end
    if ns.panel:IsShown() then return end
    if InCombatLockdown() then return end
    if CharacterFrame and not CharacterFrame:IsShown() and ToggleCharacter then ToggleCharacter("PaperDollFrame") end
end

local function EnsureHelpButton()
    if helpBtn or not ns.panel then return end
    local closeBtn = ns.panel.CloseButton
    local host = (closeBtn and closeBtn:GetParent()) or ns.panel
    local vis
    local ok = pcall(function()
        vis = CreateFrame("Button", "ClassCodexHelpButton", host, "MainHelpPlateButton")
    end)
    if ok and vis then
        vis:SetScale(0.6)
        vis:EnableMouse(false)
    else
        vis = CreateFrame("Frame", "ClassCodexHelpButton", host)
        vis:SetSize(18, 18)
        local tex = vis:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(vis)
        tex:SetAtlas("help-i")
        vis.icon = tex
        local ag = tex:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(1)
        a:SetToAlpha(0.2)
        a:SetDuration(0.6)
        vis.blink = ag
    end
    if closeBtn then
        vis:SetFrameLevel(closeBtn:GetFrameLevel() + 1)
        vis:SetPoint("CENTER", closeBtn, "LEFT", -19, 0)
    else
        vis:SetFrameLevel(ns.panel:GetFrameLevel() + 50)
        vis:SetPoint("RIGHT", ns.panel, "TOPRIGHT", -30, -18)
    end

    local click = CreateFrame("Button", nil, vis)
    click:SetAllPoints(vis)
    click:SetFrameLevel(vis:GetFrameLevel() + 2)
    click:RegisterForClicks("LeftButtonUp")
    click:SetScript("OnEnter", function(self)
        ns.Tooltip
            .Open(self, "ANCHOR_LEFT")
            .Title(L["onboarding.help_tooltip_title"])
            .Body(L["onboarding.help_tooltip_body"])
            .Show()
    end)
    click:SetScript("OnLeave", function()
        ns.Tooltip.Hide()
    end)
    click:SetScript("OnClick", function()
        ns.StartOnboarding()
    end)
    vis.click = click
    helpBtn = vis
end

UpdateHelpButton = function()
    EnsureHelpButton()
    if not helpBtn then return end
    local floating = ns.isFloating and ns.isFloating()
    local show = ClassCodexDB and ClassCodexDB.showHelpButton ~= false and not floating
    helpBtn:SetShown(show and true or false)
    if helpBtn.blink then
        local blink = show and ClassCodexDB and ClassCodexDB.onboardingVersion == nil and not active
        if blink then
            helpBtn.blink:Play()
        else
            helpBtn.blink:Stop()
            if helpBtn.icon then helpBtn.icon:SetAlpha(1) end
        end
    end
end

function ns.RefreshHelpButton()
    UpdateHelpButton()
end

function ns.StartOnboarding()
    if not ClassCodexDB then return end
    if InCombatLockdown() then return end
    EnsureFrames()
    BuildSteps()
    active = true
    index = 0
    UpdateHelpButton()
    EnsurePanelVisible()
    GoToStep(1)
end

local function HookPanel()
    if hooked or not ns.panel then return end
    hooked = true
    ns.panel:HookScript("OnShow", function()
        C_Timer.After(0, UpdateHelpButton)
    end)
    ns.panel:HookScript("OnHide", function()
        if not active then return end
        local step = steps and steps[index]
        if step and PANEL_STEPS[step.id] then
            Cleanup()
            index = 0
            UpdateHelpButton()
        end
    end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        HookPanel()
        UpdateHelpButton()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if active then FinishTour({}) end
    elseif event == "PLAYER_LOGOUT" then
        Cleanup()
    end
end)
