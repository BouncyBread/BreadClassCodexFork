local _, ns = ...

function ns.FormatItemLabel(name, quality)
    if not name or name == "" then return "" end
    if quality == nil then return name end
    local ok, r, g, b = pcall(GetItemQualityColor, quality)
    if not ok or not r then return "[" .. name .. "]" end
    local hex = string.format(
        "|cff%02x%02x%02x",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5)
    )
    return hex .. "[" .. name .. "]|r"
end
