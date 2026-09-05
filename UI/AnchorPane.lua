local _, ns = ...

local SIDE_TAB_W = 34
local SIDE_TAB_H = 44
local SIDE_TAB_ATLAS = "QuestLog-tab-side"
local SIDE_TAB_SELECTED_ATLAS = "QuestLog-Tab-side-Glow-Select"
local SIDE_TAB_HOVER_ATLAS = "QuestLog-Tab-side-Glow-hover"
local SIDE_TAB_ICON_SIZE = 16
local SIDE_TAB_ICON_OFFSET_X = -1
local SIDE_TAB_ICON_OFFSET_Y = 0
local SIDE_TAB_ICON_GOLD = { 1.0, 0.82, 0.0 }
local SIDE_TAB_ICON_DIM = { 0.55, 0.45, 0.1 }
local SIDE_TAB_ANCHOR_X = -3
local SIDE_TAB_GAP = -2

local PAGE_WHEEL_STEP = 90
local FREE_WHEEL_STEP = 48
local SNAP_RESISTANCE = 2
local SNAP_COOLDOWN = 0.3

local function CreateSideTab(parent, icon, tooltip, tabKey)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(SIDE_TAB_W, SIDE_TAB_H)
    btn:RegisterForClicks("LeftButtonUp")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAtlas(SIDE_TAB_ATLAS)
    bg:SetAllPoints(btn)
    btn.bg = bg

    local hoverGlow = btn:CreateTexture(nil, "HIGHLIGHT")
    hoverGlow:SetAtlas(SIDE_TAB_HOVER_ATLAS)
    hoverGlow:SetAllPoints(bg)

    local selected = btn:CreateTexture(nil, "OVERLAY")
    selected:SetAtlas(SIDE_TAB_SELECTED_ATLAS)
    selected:SetAllPoints(bg)
    selected:Hide()
    btn.selectedGlow = selected

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetSize(SIDE_TAB_ICON_SIZE, SIDE_TAB_ICON_SIZE)
    tex:SetPoint("CENTER", btn, "CENTER", SIDE_TAB_ICON_OFFSET_X, SIDE_TAB_ICON_OFFSET_Y)
    if type(icon) == "number" then
        tex:SetTexture(icon)
    elseif type(icon) == "string" and icon:find("[\\/]") then
        tex:SetTexture(icon)
    else
        tex:SetAtlas(icon)
    end
    tex:SetDesaturated(true)
    tex:SetVertexColor(SIDE_TAB_ICON_DIM[1], SIDE_TAB_ICON_DIM[2], SIDE_TAB_ICON_DIM[3])
    btn.icon = tex
    btn.tabKey = tabKey

    btn:SetScript("OnEnter", function(self)
        if ns.Tooltip and tooltip then ns.Tooltip.Open(self, "ANCHOR_RIGHT").Intro(tooltip).Show() end
    end)
    btn:SetScript("OnLeave", function()
        if ns.Tooltip then ns.Tooltip.Hide() end
    end)
    return btn
end

function ns.CreateAnchorPane(opts)
    local parent = opts.parent
    local host = opts.insetFrame or parent
    local insets = opts.scrollInsets or {}

    local pane = {
        tabOrder = {},
        tabByKey = {},
        _tabAnchorY = {},
        _pages = {},
        _pagedMode = false,
        _viewportH = 1,
        activeTab = nil,
    }

    local pageTargetOffset = 0
    local edgeTicks, edgeDir, lastSnapAt = 0, 0, 0

    local scroll = CreateFrame("Frame", opts.scrollName, host, "WowScrollBox")
    if opts.scrollTopAnchor then
        scroll:SetPoint("LEFT", host, "LEFT", insets.left or 4, 0)
        scroll:SetPoint("TOP", opts.scrollTopAnchor, "BOTTOM", 0, -(insets.top or 4))
    else
        scroll:SetPoint("TOPLEFT", host, "TOPLEFT", insets.left or 4, -(insets.top or 8))
    end
    scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -(insets.right or 20), insets.bottom or 4)

    local scrollBar = CreateFrame("EventFrame", nil, host, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)

    local contentFrame = CreateFrame("Frame", nil, scroll)
    contentFrame.scrollable = true
    contentFrame:SetHeight(1)

    local view = CreateScrollBoxLinearView()
    view:SetPanExtent(60)
    ScrollUtil.InitScrollBoxWithScrollBar(scroll, scrollBar, view)
    if scroll.SetInterpolateScroll then scroll:SetInterpolateScroll(true) end
    if scrollBar.SetInterpolateScroll then scrollBar:SetInterpolateScroll(true) end

    if opts.hideScrollBar then
        scrollBar:SetAlpha(0)
        scrollBar:EnableMouse(false)
        scrollBar:SetWidth(1)
        if scrollBar.SetMouseClickEnabled then scrollBar:SetMouseClickEnabled(false) end
        for _, child in ipairs({ scrollBar:GetChildren() }) do
            if child.EnableMouse then child:EnableMouse(false) end
            if child.SetMouseClickEnabled then child:SetMouseClickEnabled(false) end
        end
    end

    pane.scroll = scroll
    pane.scrollBar = scrollBar
    pane.contentFrame = contentFrame

    local function ApplyScrollOffset(off)
        local range = scroll:GetDerivedScrollRange() or 0
        pageTargetOffset = math.max(0, math.min(off or 0, range))
        scroll:SetScrollPercentage(range > 0 and pageTargetOffset / range or 0)
    end
    pane.ApplyScrollOffset = ApplyScrollOffset

    local function CurrentPageIndex()
        local pages = pane._pages
        if not pages or #pages == 0 then return 1 end
        local idx = 1
        for i, p in ipairs(pages) do
            if pageTargetOffset >= p.top - 4 then
                idx = i
            else
                break
            end
        end
        return idx
    end

    local function OnContentWheel(_, delta)
        local pages = pane._pages
        if not pane._pagedMode or not pages or #pages == 0 then
            ApplyScrollOffset(pageTargetOffset - delta * FREE_WHEEL_STEP)
            return
        end

        local now = GetTime and GetTime() or 0
        if now - lastSnapAt < SNAP_COOLDOWN then return end

        local V = pane._viewportH or scroll:GetHeight() or 1
        local idx = CurrentPageIndex()
        local p = pages[idx]
        local pageBottom = p.top + math.max(0, p.height - V)

        local function crossPage(dir, targetOffset)
            if edgeDir ~= dir then
                edgeDir = dir
                edgeTicks = 0
            end
            edgeTicks = edgeTicks + 1
            if edgeTicks >= SNAP_RESISTANCE then
                edgeTicks = 0
                lastSnapAt = now
                ApplyScrollOffset(targetOffset)
            end
        end

        local hardStops = true

        if delta < 0 then
            if pageTargetOffset < pageBottom - 2 then
                edgeTicks, edgeDir = 0, 0
                ApplyScrollOffset(math.min(pageBottom, pageTargetOffset + PAGE_WHEEL_STEP))
            elseif not hardStops and idx < #pages then
                crossPage(-1, pages[idx + 1].top)
            end
        else
            if pageTargetOffset > p.top + 2 then
                edgeTicks, edgeDir = 0, 0
                ApplyScrollOffset(math.max(p.top, pageTargetOffset - PAGE_WHEEL_STEP))
            elseif not hardStops and idx > 1 then
                local pp = pages[idx - 1]
                crossPage(1, pp.top + math.max(0, pp.height - V))
            end
        end
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", OnContentWheel)

    local function UpdateTabAppearance()
        for _, key in ipairs(pane.tabOrder) do
            local tab = pane.tabByKey[key]
            if tab then
                local isActive = pane.activeTab == key
                if tab.selectedGlow then tab.selectedGlow:SetShown(isActive) end
                local c = isActive and SIDE_TAB_ICON_GOLD or SIDE_TAB_ICON_DIM
                tab.icon:SetVertexColor(c[1], c[2], c[3])
            end
        end
    end
    pane.UpdateTabAppearance = UpdateTabAppearance

    pane._topTabKeys = {}
    pane._tabsTopY = opts.tabsTopY or -40
    local prev
    for _, t in ipairs(opts.tabs or {}) do
        local tab = CreateSideTab(parent, t.icon, t.tooltip, t.key)
        tab:ClearAllPoints()
        if prev then
            tab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -SIDE_TAB_GAP)
        else
            tab:SetPoint("TOPLEFT", parent, "TOPRIGHT", SIDE_TAB_ANCHOR_X, pane._tabsTopY)
        end
        tab:SetScript("OnClick", function(self)
            if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB or SOUNDKIT.IG_MAINMENU_OPTION) end
            pane.activeTab = self.tabKey
            UpdateTabAppearance()
            if opts.onTabChange then opts.onTabChange(self.tabKey) end
            pane:ScrollToTab(self.tabKey)
        end)
        pane.tabByKey[t.key] = tab
        pane.tabOrder[#pane.tabOrder + 1] = t.key
        pane._topTabKeys[#pane._topTabKeys + 1] = t.key
        prev = tab
    end

    for _, t in ipairs(opts.bottomTabs or {}) do
        local tab = CreateSideTab(parent, t.icon, t.tooltip, t.key)
        tab:ClearAllPoints()
        tab:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", SIDE_TAB_ANCHOR_X, 13)
        tab:SetScript("OnClick", function(self)
            if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB or SOUNDKIT.IG_MAINMENU_OPTION) end
            pane.activeTab = self.tabKey
            UpdateTabAppearance()
            if opts.onTabChange then opts.onTabChange(self.tabKey) end
            pane:ScrollToTab(self.tabKey)
        end)
        pane.tabByKey[t.key] = tab
        pane.tabOrder[#pane.tabOrder + 1] = t.key
    end

    function pane:SetActiveTab(key)
        self.activeTab = key
        UpdateTabAppearance()
    end

    function pane:GetActiveTab()
        return self.activeTab
    end

    function pane:ApplyTabVisibility(isHidden)
        local prevTop
        local firstVisible
        for _, key in ipairs(self._topTabKeys) do
            local tab = self.tabByKey[key]
            if tab then
                if isHidden and isHidden(key) then
                    tab:Hide()
                else
                    tab:Show()
                    tab:ClearAllPoints()
                    if prevTop then
                        tab:SetPoint("TOPLEFT", prevTop, "BOTTOMLEFT", 0, -SIDE_TAB_GAP)
                    else
                        tab:SetPoint("TOPLEFT", parent, "TOPRIGHT", SIDE_TAB_ANCHOR_X, self._tabsTopY)
                    end
                    prevTop = tab
                    firstVisible = firstVisible or key
                end
            end
        end
        if self.activeTab and isHidden and isHidden(self.activeTab) and firstVisible then
            self.activeTab = firstVisible
        end
        UpdateTabAppearance()
        return self.activeTab
    end

    function pane:ScrollToTab(tabKey)
        C_Timer.After(0, function()
            local offset = self._tabAnchorY and self._tabAnchorY[tabKey]
            if offset then ApplyScrollOffset(offset) end
        end)
    end

    local function SyncActiveTabToScroll()
        if pane._suppressSync then return end
        local s = scroll:GetDerivedScrollOffset() or 0
        local best, bestOff
        for _, k in ipairs(pane.tabOrder) do
            local off = pane._tabAnchorY[k]
            if off and off <= s + 8 and (not bestOff or off >= bestOff) then
                best, bestOff = k, off
            end
        end
        if not best then
            for _, k in ipairs(pane.tabOrder) do
                if pane._tabAnchorY[k] then
                    best = k
                    break
                end
            end
        end
        if best and best ~= pane.activeTab then
            pane.activeTab = best
            UpdateTabAppearance()
            if opts.onSync then opts.onSync(best) end
        end
    end

    scroll:RegisterCallback("OnScroll", function()
        SyncActiveTabToScroll()
    end, scroll)

    function pane:Relayout()
        local targetTab = self.activeTab
        local prevAnchor = self._tabAnchorY
        self._suppressSync = true
        self._tabAnchorY = {}
        self._pages = {}
        local V = math.max(40, scroll:GetHeight() or 1)
        self._viewportH = V
        local anchors, pages, height = opts.onLayout(contentFrame, V)
        self._tabAnchorY = anchors or {}
        self._pages = pages or {}
        self._pagedMode = #self._pages > 0
        contentFrame:SetHeight(math.max(height or 1, 1))
        if scroll.FullUpdate then scroll:FullUpdate(ScrollBoxConstants.UpdateQueued) end
        UpdateTabAppearance()
        C_Timer.After(0, function()
            local top = targetTab and self._tabAnchorY[targetTab]
            if top then
                local within = false
                for _, p in ipairs(self._pages or {}) do
                    if p.key == targetTab then
                        within = pageTargetOffset >= p.top - 4 and pageTargetOffset <= p.top + (p.height or 0)
                        break
                    end
                end
                self.activeTab = targetTab
                -- Preserve position RELATIVE to the tab's top so a reflow that shifts
                -- the page keeps you pinned at the top instead of a few pixels off.
                local prevTop = prevAnchor and prevAnchor[targetTab]
                local target = top
                if within and prevTop then
                    local rel = pageTargetOffset - prevTop
                    if rel > 1 then target = top + rel end
                end
                ApplyScrollOffset(target)
                UpdateTabAppearance()
            end
            self._suppressSync = false
        end)
    end

    function pane:SetTabShown(key, shown)
        local tab = self.tabByKey[key]
        if tab then tab:SetShown(shown) end
    end

    return pane
end
