local _, ns = ...
-- 12.x removed the item globals; they live only on C_Item now.
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local itemCache = {}
local pendingItems = {}
local subscribers = {}

function ns.RequestItemData(itemId)
    if not itemId or itemId == 0 then return end
    if itemCache[itemId] or pendingItems[itemId] then return end
    pendingItems[itemId] = true
    C_Item.RequestLoadItemDataByID(itemId)
end

function ns.GetCachedItem(itemId)
    return itemId and itemCache[itemId] or nil
end

function ns.OnItemLoaded(fn)
    subscribers[#subscribers + 1] = fn
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
frame:SetScript("OnEvent", function(_, _, itemId, success)
    if not success then return end
    pendingItems[itemId] = nil
    local name, _, quality, _, _, _, _, _, _, icon = GetItemInfo(itemId)
    if not name then return end
    itemCache[itemId] = { name = name, quality = quality, icon = icon }
    for _, fn in ipairs(subscribers) do
        pcall(fn, itemId)
    end
end)
