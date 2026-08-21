local _, ns = ...

local PAGE_TITLE_HPAD = 8
local PAGE_TITLE_HEIGHT = 32

function ns.CreatePageTitle(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(PAGE_TITLE_HEIGHT)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", PAGE_TITLE_HPAD, 1)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetTextColor(1, 0.82, 0)
    f.title = title

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", 1, 1)
    divider:SetPoint("BOTTOMRIGHT", -2, 1)
    divider:SetColorTexture(1, 0.82, 0, 0.22)
    f.divider = divider

    f._widgets = {}

    function f:SetTitle(text)
        self.title:SetText(text or "")
    end

    function f:AddWidget(widget, gap)
        for _, e in ipairs(self._widgets) do
            if e.frame == widget then
                if gap then e.gap = gap end
                return widget
            end
        end
        self._widgets[#self._widgets + 1] = { frame = widget, gap = gap or 6 }
        widget:SetParent(self)
        local prev
        for _, e in ipairs(self._widgets) do
            e.frame:ClearAllPoints()
            if prev then
                e.frame:SetPoint("RIGHT", prev, "LEFT", -e.gap, 0)
            else
                e.frame:SetPoint("RIGHT", self, "RIGHT", -2, 0)
            end
            prev = e.frame
        end
        return widget
    end

    return f
end

ns.PAGE_TITLE_HEIGHT = PAGE_TITLE_HEIGHT
ns.PAGE_TITLE_HPAD = PAGE_TITLE_HPAD
