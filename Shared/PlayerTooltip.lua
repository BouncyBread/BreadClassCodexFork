-- Item tooltips the player sees, so other addons' hidden scan tooltips stay unchanged.
local _, ns = ...

-- Blizzard tooltips that show items on screen. Embedded item tooltips (quest
-- rewards, the Encounter Journal) carry the stock IsEmbedded key instead.
local NAMED = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
    "EmbeddedItemTooltip",
}

-- Addons that show items in their own tooltips name them with this prefix
-- (the protocol Auctionator also honors).
local OPT_IN_PREFIX = "NotGameTooltip"

local visible

--- True when `tooltip` is one the player looks at. Hidden scan tooltips
--- (Pawn's PawnPrivateTooltip1 and similar) parse the item's stat lines, so
--- text added to them changes what those addons read.
function ns.IsPlayerTooltip(tooltip)
    if not visible then
        visible = {}
        for i = 1, #NAMED do
            local frame = _G[NAMED[i]]
            if frame then visible[frame] = true end
        end
    end
    if visible[tooltip] or tooltip.IsEmbedded == true then return true end
    local name = tooltip:GetName()
    return name ~= nil and name:sub(1, #OPT_IN_PREFIX) == OPT_IN_PREFIX
end
