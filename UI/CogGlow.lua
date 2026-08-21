local _, ns = ...

-- Gold glow on a cog button, used to hint that the cog is the interactive
-- control for the header/title the mouse is currently over. The glow fades
-- in/out and the icon takes its hover color while glowing.

local GLOW_COLOR = { 1, 0.82, 0 }
local FADE_TIME = 0.25

local LABEL_SEPARATOR = " · "

-- Context menus open at the cursor regardless of owner. When the menu is
-- opened from a region other than the cog (label suffix, page title),
-- suppress it before the cursor position ever renders, then re-anchor it
-- to the cog on the next frame (after the menu manager's layout pass) and
-- fade it back in, so the move is never visible.
local function AnchorOpenMenuToCog(cog)
    pcall(function()
        if Menu and Menu.GetManager then
            local menu = Menu.GetManager():GetOpenMenu()
            if menu and menu.SetAlpha then menu:SetAlpha(0) end
        end
    end)
    C_Timer.After(0, function()
        local ok, menu = pcall(function()
            if Menu and Menu.GetManager then return Menu.GetManager():GetOpenMenu() end
        end)
        if ok and menu and menu.ClearAllPoints then
            menu:ClearAllPoints()
            menu:SetPoint("TOPLEFT", cog, "TOPRIGHT", 2, 0)
            menu:SetAlpha(1)
        end
    end)
end

function ns.MakeCogGlow(cog, icon)
    if not cog or cog.SetCogGlow then return cog end
    icon = icon or cog.icon

    -- Same treatment as the character pane ClassCodex button:
    -- bags-glow-flash in gold ADD blend, with a soft star pulse on top.
    -- The pulses live on the textures; the fx frame's alpha carries the
    -- hover fade so the two compose.
    local fx = CreateFrame("Frame", nil, cog)
    fx:SetAllPoints(cog)
    -- Above the cog so the ADD-blended glow is never buried under the
    -- header/title the cog was re-parented onto.
    fx:SetFrameLevel(cog:GetFrameLevel() + 1)
    local glow = fx:CreateTexture(nil, "BACKGROUND")
    glow:SetSize(cog:GetWidth() + 12, cog:GetHeight() + 12)
    glow:SetPoint("CENTER")
    glow:SetAtlas("bags-glow-flash")
    glow:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3])
    glow:SetBlendMode("ADD")
    local star = fx:CreateTexture(nil, "BACKGROUND")
    star:SetSize(cog:GetWidth() + 18, cog:GetHeight() + 18)
    star:SetPoint("CENTER")
    star:SetTexture("Interface\\Cooldown\\star4")
    star:SetVertexColor(1, 0.9, 0.45, 0.22)
    star:SetBlendMode("ADD")

    local glowPulse = glow:CreateAnimationGroup()
    glowPulse:SetLooping("BOUNCE")
    local glowPulseAlpha = glowPulse:CreateAnimation("Alpha")
    glowPulseAlpha:SetFromAlpha(0.8)
    glowPulseAlpha:SetToAlpha(1)
    glowPulseAlpha:SetDuration(0.9)

    local starPulse = star:CreateAnimationGroup()
    starPulse:SetLooping("BOUNCE")
    local starPulseAlpha = starPulse:CreateAnimation("Alpha")
    starPulseAlpha:SetFromAlpha(0.1)
    starPulseAlpha:SetToAlpha(0.35)
    starPulseAlpha:SetDuration(0.9)

    fx:SetAlpha(0)
    fx:Hide()

    -- Icon color: grey at rest, white while the cog itself is hovered OR
    -- while a linked title/header glows it. The owning section's own hover
    -- handlers run first; these hooks land on the correct final color.
    local HOVER_COLOR = { 1, 1, 1 }
    local IDLE_COLOR = { 0.6, 0.6, 0.6 }
    local function applyColor()
        if not icon then return end
        local c = (cog._cogMouseOver or cog._cogGlowOn) and HOVER_COLOR or IDLE_COLOR
        icon:SetVertexColor(c[1], c[2], c[3])
    end
    cog:HookScript("OnEnter", function()
        cog._cogMouseOver = true
        applyColor()
    end)
    cog:HookScript("OnLeave", function()
        cog._cogMouseOver = false
        applyColor()
    end)

    local level = 0
    local target = 0
    local GLOW_MAX_ALPHA = 0.5
    local animator = CreateFrame("Frame")
    animator:Hide()
    animator:SetScript("OnUpdate", function(_, elapsed)
        local step = elapsed / FADE_TIME
        if level < target then
            level = math.min(target, level + step)
        elseif level > target then
            level = math.max(target, level - step)
        end
        fx:SetAlpha(level * GLOW_MAX_ALPHA)
        if target == 0 and level <= 0 then
            fx:Hide()
            animator:Hide()
        end
    end)

    function cog:SetCogGlow(on)
        self._cogGlowOn = on and true or nil
        applyColor()
        if on then
            if self:IsShown() and self:IsVisible() then
                target = 1
                fx:Show()
                glowPulse:Play()
                starPulse:Play()
                animator:Show()
            end
        else
            target = 0
            glowPulse:Stop()
            starPulse:Stop()
            animator:Show()
        end
    end

    hooksecurefunc(cog, "Hide", function()
        if cog._cogGlowOn or fx:IsShown() then
            cog._cogGlowOn = nil
            applyColor()
            target = 0
            level = 0
            fx:Hide()
            glowPulse:Stop()
            starPulse:Stop()
            animator:Hide()
        end
    end)

    return cog
end

-- Makes the "· <selected>" suffix of a section header label ("Best in Slot
-- · Myth+") the interactive region: hovering it glows the cog and clicking
-- it opens the dropdown anchored to the cogwheel. The rest of the header
-- keeps its normal behavior. Tracks label text changes and hides when no
-- selection is shown.
function ns.MakeLabelMenuHotspot(header, cog)
    if not (header and header.label and cog and cog.SetCogGlow) then return end
    if header._cogHotspot then return end

    local measure = header:CreateFontString(nil, nil)
    measure:SetFontObject(header.label:GetFontObject() or "GameFontNormal")

    local hotspot = CreateFrame("Button", nil, header)
    hotspot:RegisterForClicks("LeftButtonUp")
    hotspot:SetFrameLevel(header:GetFrameLevel() + 10)
    hotspot:SetScript("OnClick", function()
        if not cog:IsShown() then return end
        local onClick = cog:GetScript("OnClick")
        if onClick then
            onClick(cog, "LeftButton")
            AnchorOpenMenuToCog(cog)
        end
    end)
    hotspot:SetScript("OnEnter", function()
        if cog:IsShown() then cog:SetCogGlow(true) end
    end)
    hotspot:SetScript("OnLeave", function()
        cog:SetCogGlow(false)
    end)

    local function Update()
        local text = header.label:GetText() or ""
        local prefix = text:match("^(.-" .. LABEL_SEPARATOR .. ")")
        if not prefix or #prefix >= #text then
            hotspot:Hide()
            return
        end
        measure:SetText(prefix)
        hotspot:ClearAllPoints()
        hotspot:SetPoint("TOPLEFT", header.label, "TOPLEFT", measure:GetStringWidth(), 0)
        hotspot:SetPoint("BOTTOMRIGHT", header.label, "BOTTOMRIGHT", 0, 0)
        hotspot:SetShown(cog:IsShown())
    end

    hooksecurefunc(header.label, "SetText", Update)
    Update()
    header._cogHotspot = hotspot
end

-- Lights the cog whenever the mouse is over the trigger frame (page title).
-- header or page title). Idempotent per trigger; a trigger can be linked
-- to at most one cog.
function ns.LinkCogHover(trigger, cog)
    if not (trigger and cog and cog.SetCogGlow) then return end
    if trigger._cogGlowLinked then return end
    trigger._cogGlowLinked = true
    if not trigger:IsMouseEnabled() then trigger:EnableMouse(true) end
    trigger:HookScript("OnEnter", function()
        if cog:IsShown() then cog:SetCogGlow(true) end
    end)
    trigger:HookScript("OnLeave", function()
        cog:SetCogGlow(false)
    end)
end

-- Opens the cog's dropdown when the trigger frame is clicked with the given
-- mouse button ("LeftButton" for page titles, "RightButton" for collapsible
-- section headers whose left click already toggles collapse). Only fires
-- while the cog is shown.
function ns.LinkCogMenu(trigger, cog, button)
    button = button or "LeftButton"
    if not (trigger and cog and cog:IsObjectType("Button")) then return end
    if trigger._cogMenuLinked then return end
    trigger._cogMenuLinked = true
    if not trigger:IsMouseEnabled() then trigger:EnableMouse(true) end
    trigger:HookScript("OnMouseUp", function(_, btn)
        if btn ~= button or not cog:IsShown() then return end
        local onClick = cog:GetScript("OnClick")
        if onClick then
            onClick(cog, "LeftButton")
            AnchorOpenMenuToCog(cog)
        end
    end)
end
