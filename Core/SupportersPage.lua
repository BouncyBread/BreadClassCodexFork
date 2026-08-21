local _, ns = ...

function ns.BuildSupportersPage()
    local parent = ns.contentFrame
    if not parent then return end

    local frame = CreateFrame("Frame", nil, parent)
    local placeTiers = ns.BuildSupporterTiers(frame)

    local function Layout()
        local width = (ns.contentFrame and ns.contentFrame:GetWidth()) or 0
        if width < 40 then return end
        local y = -6
        y = placeTiers(width, y)
        frame:SetHeight(math.abs(y) + 10)
    end

    Layout()
    ns.supportersContent = frame
    ns.RefreshSupportersView = Layout
end
