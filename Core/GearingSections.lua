local _, ns = ...

local _enhanceFrames = ns.Sections.Enhancements.InitPanel({
    parent = ns.contentFrame,
    refresh = function()
        ns:UpdateGearingSections()
        ns:LayoutPanel()
    end,
})
local enchantSection = _enhanceFrames.enchSection
local gemSection = _enhanceFrames.gemSection
local consumSection = _enhanceFrames.consumSection

local trinketSection = ns.Sections.Trinkets.InitPanel(ns.contentFrame, nil)
trinketSection._keepHeader = true

local _craftingFrames = ns.Sections.Crafting.InitPanel({
    parent = ns.contentFrame,
    refresh = function()
        ns:UpdateGearingSections()
        ns:LayoutPanel()
    end,
})
local craftsSection = _craftingFrames.craftsSection
local embsSection = _craftingFrames.embsSection

local bisSection = ns.Sections.Gear.InitPanel(ns.contentFrame, nil)
bisSection._keepHeader = true

local lastTrinketCount = 0

function ns:UpdateGearingSections()
    ns.Sections.Enhancements.HidePanelSourceDropdown()

    if ns.RebuildEnchantSpellLookup then ns.RebuildEnchantSpellLookup() end
    local gearData = ns.GetSpecGearData()
    ns.RequestAllItems(gearData)

    local playerClass = select(2, UnitClass("player"))
    local playerSpecKey = ns.GetSpecKey()
    local playerSpec = playerSpecKey and (playerSpecKey:match("-(.+)") or playerSpecKey)
    local source = ns.ActiveSource and ns.ActiveSource() or "icyveins"
    local bisData = playerClass
        and playerSpec
        and ns.GetBisGearData
        and ns.GetBisGearData(source, playerClass, playerSpec)
    if bisData and bisData.bisGear then
        for _, tab in ipairs(bisData.bisGear) do
            for _, g in ipairs(tab.slots) do
                ns.RequestItemData(g.item.itemId)
            end
        end
    end

    ns.Sections.Enhancements.RenderPanel({

        enchants = gearData and gearData.enchants,
        gems = gearData and gearData.gems,
        consumables = gearData and gearData.consumables,

        showSourceDropdown = true,
        specKey = ns.GetSpecKey() or "",
        sourceLabels = ns.ENH_SOURCE_LABELS,
        onChange = function()
            ns:UpdateGearingSections()
            ns:LayoutPanel()
        end,
    })

    lastTrinketCount = ns.Sections.Trinkets.RenderPanel({
        trinkets = gearData and gearData.trinkets,
        onChange = function()
            ns:UpdateGearingSections()
            ns:LayoutPanel()
        end,
    })
    if lastTrinketCount == 0 then trinketSection:Hide() end

    local craftClassToken, craftSpec = ns.GetPlayerClassSpec()
    ns.Sections.Crafting.RenderPanel({
        class = craftClassToken,
        spec = craftSpec,
    })

    ns.Sections.Gear.RenderPanel({
        bisGear = bisData and bisData.bisGear,
        onChange = function()
            ns:UpdateGearingSections()
            ns:LayoutPanel()
        end,
    })

    if ClassCodexDB then
        local prefix = ns.isFloating() and "floatShow" or "dockShow"
        if not ClassCodexDB[prefix .. "Enchants"] then enchantSection:Hide() end
        if not ClassCodexDB[prefix .. "Gems"] then gemSection:Hide() end
        if not ClassCodexDB[prefix .. "Consumables"] then consumSection:Hide() end
        if not ClassCodexDB[prefix .. "Trinkets"] then trinketSection:Hide() end

        local showCrafts = ClassCodexDB[prefix .. "Crafts"] ~= false
        local showEmbs = ClassCodexDB[prefix .. "Embellishments"] ~= false
        if not showCrafts then craftsSection:Hide() end
        if not showEmbs then embsSection:Hide() end
        if not showCrafts and not showEmbs then _craftingFrames.ctxDropdown:Hide() end
        if not ClassCodexDB[prefix .. "BisGear"] then bisSection:Hide() end
    end
end
