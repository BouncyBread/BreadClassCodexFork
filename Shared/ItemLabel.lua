local _, ns = ...
-- 12.x removed the item globals; they live only on C_Item now.
local GetItemQualityColor = (C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor

function ns.FormatItemLabel(name, quality)
    if not name or name == "" then return "" end
    if quality == nil then return name end
    local ok, r, g, b = pcall(C_Item.GetItemQualityColor, quality)
    if not ok or not r then return "[" .. name .. "]" end
    local hex = string.format(
        "|cff%02x%02x%02x",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5)
    )
    return hex .. "[" .. name .. "]|r"
end
