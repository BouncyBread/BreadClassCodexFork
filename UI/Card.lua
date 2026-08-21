local _, ns = ...

local DEFAULT_HEIGHT = 36
local DEFAULT_ICON = 20
local HERO_ICON = 20
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function applyTexture(tex, value)
    if value == nil then
        tex:SetTexture(nil)
        return nil
    end
    if type(value) == "number" then
        tex:SetTexture(value)
        return "texture"
    elseif type(value) == "string" and value:find("\\", 1, true) then
        tex:SetTexture(value)
        return "texture"
    else
        tex:SetAtlas(value, false)
        return "atlas"
    end
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
    return tex, ring
end

function ns.CreateCard(parent, opts)
    opts = opts or {}
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetHeight(opts.height or DEFAULT_HEIGHT)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    card:SetBackdropColor(0.08, 0.08, 0.09, 0.94)
    card:SetBackdropBorderColor(0.32, 0.32, 0.38, 0.7)

    local colorBg = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    colorBg:SetPoint("TOPLEFT", 3, -3)
    colorBg:SetPoint("BOTTOMRIGHT", -3, 3)
    colorBg:Hide()
    card.colorBg = colorBg

    local iconSize = opts.iconSize or DEFAULT_ICON
    local icon = ringedTexture(card, iconSize)
    icon:SetPoint("LEFT", 11, 0)
    card.iconTex = icon

    local heroBtn = CreateFrame("Button", nil, card)
    heroBtn:SetSize(HERO_ICON, HERO_ICON)
    heroBtn:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    local heroTex = ringedTexture(heroBtn, HERO_ICON)
    heroTex:SetAllPoints(heroBtn)
    heroBtn.tex = heroTex
    heroBtn:SetScript("OnEnter", function(self)
        if self.tip then ns.Tooltip.Open(self, "ANCHOR_RIGHT").Title(self.tip).Body("Hero talent").Show() end
    end)
    heroBtn:SetScript("OnLeave", function()
        ns.Tooltip.Hide()
    end)
    heroBtn:Hide()
    card.heroBtn = heroBtn

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetTextColor(1, 1, 1)
    title:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    card.title = title
    local function anchorTitle()
        title:ClearAllPoints()
        title:SetPoint("RIGHT", card, "RIGHT", -8, 0)
        if heroBtn:IsShown() then
            title:SetPoint("LEFT", heroBtn, "RIGHT", 9, 0)
        else
            title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
        end
    end
    anchorTitle()

    local star = CreateFrame("Button", nil, card)
    star:SetFrameLevel(card:GetFrameLevel() + 6)
    star:SetSize(18, 18)
    star:SetPoint("CENTER", card, "TOPLEFT", 7, -5)
    local starTex = star:CreateTexture(nil, "OVERLAY")
    starTex:SetAllPoints()
    starTex:SetTexture("Interface\\Common\\FavoritesIcon")
    local starTipTags = nil
    star:SetScript("OnEnter", function(self)
        local t = ns.Tooltip.Open(self, "ANCHOR_RIGHT").Title("Recommended")
        -- Source-authored labels (High Key, Weekly Key, …) ride on the star
        -- instead of cluttering the visible label.
        if starTipTags and #starTipTags > 0 then t.Body(table.concat(starTipTags, ", ")) end
        t.Show()
    end)
    star:SetScript("OnLeave", function()
        ns.Tooltip.Hide()
    end)
    star:Hide()
    card.star = star

    local appliedCheck = CreateFrame("Button", nil, card)
    appliedCheck:SetFrameLevel(card:GetFrameLevel() + 6)
    appliedCheck:SetSize(18, 18)
    appliedCheck:SetPoint("CENTER", card, "TOPRIGHT", -8, -5)
    local checkTex = appliedCheck:CreateTexture(nil, "OVERLAY")
    checkTex:SetAllPoints()
    checkTex:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    appliedCheck:SetScript("OnEnter", function(self)
        ns.Tooltip.Open(self, "ANCHOR_RIGHT").Title("Currently applied").Show()
    end)
    appliedCheck:SetScript("OnLeave", function()
        ns.Tooltip.Hide()
    end)
    appliedCheck:Hide()
    card.appliedCheck = appliedCheck

    local actionsFrame = CreateFrame("Frame", nil, card)
    actionsFrame:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -4)
    actionsFrame:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 4)
    actionsFrame:SetAlpha(0)
    actionsFrame:Hide()
    card.actionsFrame = actionsFrame

    local GOLD = { 1, 0.82, 0 }
    if opts.actions then
        card.actions = {}
        for i = 1, #opts.actions do
            local a = opts.actions[i]
            local sz = a.size or 18
            local b = CreateFrame("Button", nil, actionsFrame)
            b:SetSize(sz, sz)
            b:RegisterForClicks("LeftButtonUp")
            b._sz = sz
            b._gap = a.gap or 5
            b._isApply = a.role == "apply"
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetAllPoints()
            if a.atlas then
                t:SetAtlas(a.atlas)
            else
                t:SetTexture(a.icon)
            end
            b.baseColor = { GOLD[1], GOLD[2], GOLD[3] }
            t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
            b.tex = t
            b:SetScript("OnEnter", function(s)
                local c = s.baseColor
                t:SetVertexColor(math.min(1, c[1] + 0.15), math.min(1, c[2] + 0.13), math.min(1, c[3] + 0.2))
                if a.tooltip then ns.Tooltip.Open(s, "ANCHOR_RIGHT").Intro(a.tooltip).Show() end
            end)
            b:SetScript("OnLeave", function(s)
                local c = s.baseColor
                t:SetVertexColor(c[1], c[2], c[3])
                ns.Tooltip.Hide()
            end)
            if a.onClick then b:SetScript("OnClick", a.onClick) end
            card.actions[i] = b
        end
    end

    local function layoutActions(self)
        local w, prev = 0, nil
        if self.actions then
            for i = #self.actions, 1, -1 do
                local b = self.actions[i]
                if b._hidden or (self._applied and b._isApply) then
                    b:Hide()
                else
                    b:Show()
                    b:ClearAllPoints()
                    if prev then
                        b:SetPoint("RIGHT", prev, "LEFT", -b._gap, 0)
                    else
                        b:SetPoint("RIGHT", actionsFrame, "RIGHT", 0, 0)
                    end
                    prev = b
                    w = w + b._sz + b._gap
                end
            end
        end
        self._actionsWidth = w
        actionsFrame:SetWidth(math.max(1, w))
    end
    layoutActions(card)

    local CHECK_PAD = 22
    local function applyActionProgress(self, p)
        self._actP = p
        actionsFrame:SetAlpha(p)
        actionsFrame:ClearAllPoints()
        local dx = (1 - p) * 6
        actionsFrame:SetPoint("TOPRIGHT", self, "TOPRIGHT", -8 + dx, -4)
        actionsFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -8 + dx, 4)
        local titlePad = math.max(self._applied and CHECK_PAD or 0, p * ((self._actionsWidth or 0) + 2))
        title:SetPoint("RIGHT", self, "RIGHT", -8 - titlePad, 0)
    end

    local function easeActions(self, elapsed)
        local over = self:IsMouseOver()
        local want = over and 1 or 0
        if not opts.staticBorder then
            if over then
                self:SetBackdropBorderColor(1, 0.82, 0, 0.9)
            else
                self:SetBackdropBorderColor(
                    self._accentR or 0.32,
                    self._accentG or 0.32,
                    self._accentB or 0.38,
                    self._accentA or 0.7
                )
            end
        end
        local p = self._actP or 0
        local step = elapsed / 0.11
        if p < want then
            p = math.min(want, p + step)
        elseif p > want then
            p = math.max(want, p - step)
        end
        applyActionProgress(self, p)
        if p == want then
            self:SetScript("OnUpdate", nil)
            if want == 0 then actionsFrame:Hide() end
        end
    end

    function card:SetTitle(text)
        self.title:SetText(text or "")
    end
    function card:_StopPlaceholder()
        if self._phAnim and self._phAnim:IsPlaying() then self._phAnim:Stop() end
        self.iconTex:SetAlpha(1)
    end
    function card:SetIcon(value)
        self:_StopPlaceholder()
        self._portraitDisplayID = nil
        self.iconTex:SetVertexColor(1, 1, 1)
        applyTexture(self.iconTex, value)
        self.iconTex:SetTexCoord(0, 1, 0, 1)
    end
    function card:SetPortrait(displayID)
        if displayID and SetPortraitTextureFromCreatureDisplayID then
            if self._portraitDisplayID ~= displayID then
                self:_StopPlaceholder()
                self.iconTex:SetVertexColor(1, 1, 1)
                SetPortraitTextureFromCreatureDisplayID(self.iconTex, displayID)
                self.iconTex:SetTexCoord(0, 1, 0, 1)
                self._portraitDisplayID = displayID
            end
            return true
        end
        return false
    end
    function card:SetPortraitPlaceholder()
        self._portraitDisplayID = nil
        self.iconTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        self.iconTex:SetTexCoord(0, 1, 0, 1)
        -- Skeleton gray bright enough to read as "loading" on the dark card
        -- tint; the alpha breathe is deep and quick so it can't pass for an
        -- empty slot.
        self.iconTex:SetVertexColor(0.42, 0.42, 0.48, 1)
        if not self._phAnim then
            local ag = self.iconTex:CreateAnimationGroup()
            ag:SetLooping("REPEAT")
            local down = ag:CreateAnimation("Alpha")
            down:SetFromAlpha(1)
            down:SetToAlpha(0.35)
            down:SetDuration(0.4)
            down:SetOrder(1)
            down:SetSmoothing("OUT")
            local up = ag:CreateAnimation("Alpha")
            up:SetFromAlpha(0.35)
            up:SetToAlpha(1)
            up:SetDuration(0.4)
            up:SetOrder(2)
            up:SetSmoothing("IN")
            self._phAnim = ag
        end
        self.iconTex:SetAlpha(1)
        self._phAnim:Play()
    end
    function card:SetHeroIcon(value, name)
        if value then
            applyTexture(heroBtn.tex, value)
            heroBtn.tex:SetTexCoord(0, 1, 0, 1)
            heroBtn.tip = name
            heroBtn:Show()
        else
            heroBtn:Hide()
        end
        anchorTitle()
    end
    function card:SetRecommended(on, tags)
        starTipTags = tags
        star:SetShown(on and true or false)
    end
    function card:SetApplied(on)
        on = on and true or false
        self._applied = on
        self.appliedCheck:SetShown(on)
        layoutActions(self)
        applyActionProgress(self, self._actP or 0)
    end
    function card:SetActionShown(idx, shown)
        local b = self.actions and self.actions[idx]
        if not b then return end
        b._hidden = not shown
        layoutActions(self)
        applyActionProgress(self, self._actP or 0)
    end
    function card:SetBackgroundColor(r, g, b)
        if r and colorBg.SetGradient and CreateColor then
            colorBg:SetColorTexture(1, 1, 1, 1)
            colorBg:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.32 * 0.35), CreateColor(r, g, b, 0.32))
            colorBg:Show()
        else
            colorBg:Hide()
        end
    end
    function card:SetAccent(r, g, b, a)
        self._accentR, self._accentG, self._accentB, self._accentA = r, g, b, a or 0.85
        self:SetBackdropBorderColor(r, g, b, self._accentA)
    end
    function card:SetActionTint(idx, r, g, b)
        local btn = self.actions and self.actions[idx]
        if not btn then return end
        btn.baseColor[1], btn.baseColor[2], btn.baseColor[3] = r, g, b
        if not btn:IsMouseOver() then btn.tex:SetVertexColor(r, g, b) end
    end

    if opts.title then card:SetTitle(opts.title) end
    if opts.icon then card:SetIcon(opts.icon) end

    card:SetScript("OnEnter", function(self)
        if not opts.staticBorder then self:SetBackdropBorderColor(1, 0.82, 0, 0.9) end
        actionsFrame:Show()
        self:SetScript("OnUpdate", easeActions)
        if opts.onEnter then opts.onEnter(self) end
    end)
    card:SetScript("OnLeave", function(self)
        self:SetScript("OnUpdate", easeActions)
        if opts.onLeave then opts.onLeave(self) end
    end)
    if opts.onClick then
        card:RegisterForClicks("LeftButtonUp")
        card:SetScript("OnClick", opts.onClick)
    end

    return card
end
