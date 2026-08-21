local _, ns = ...
ns.Sections = ns.Sections or {}

local L = ns.L

-- The dedicated empty screen shown in the PvP-relevant tabs when the active
-- source publishes no PvP guide for the spec (e.g. the tank specs on Icy
-- Veins). No data is borrowed or substituted in that case.
local PvpEmpty = {}
ns.Sections.PvpEmpty = PvpEmpty

local HEIGHT = 56

local panel = {}

function PvpEmpty.InitPanel(opts)
    panel.section = CreateFrame("Frame", nil, opts.parent)
    panel.header = opts.header(panel.section, "PvP", false)
    panel.content = CreateFrame("Frame", nil, panel.section)
    panel.content:SetPoint("TOPLEFT", panel.header, "BOTTOMLEFT", 0, 0)
    panel.content:SetPoint("RIGHT", 0, 0)
    panel.content:SetHeight(HEIGHT)

    local icon = panel.content:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 8, -14)
    icon:SetTexture("Interface\\Icons\\INV_Sword_39")

    panel.text = panel.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.text:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 2)
    panel.text:SetPoint("RIGHT", panel.content, "RIGHT", -8, 0)
    panel.text:SetJustifyH("LEFT")
    panel.text:SetTextColor(0.65, 0.65, 0.65)
    panel.text:SetText(L["empty.no_pvp_guide"] or "PvP guide coming soon.\nWe don't have one for this spec yet.")

    panel.section:Hide()
    return panel.section, panel.header, panel.content
end

function PvpEmpty.RenderPanel(args)
    if not (args and args.shown) then
        panel.section:Hide()
        return 0
    end
    panel.content:SetHeight(HEIGHT)
    panel.section:Show()
    return HEIGHT
end
