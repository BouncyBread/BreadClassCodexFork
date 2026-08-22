local _, ns = ...
local L = ns.L

local function fmtPlain(v)
    return tostring(v)
end
local function fmtPercent(v)
    return v .. "%"
end
local function fmtPixels(v)
    return v .. "px"
end

function ns.RegisterSettings()
    local ok, err = pcall(function()
        local aboutCanvas = ns.CreateSettingsAboutCanvas and ns.CreateSettingsAboutCanvas()
        local category
        if aboutCanvas then
            category = Settings.RegisterCanvasLayoutCategory(aboutCanvas, "Bread Codex")
        else
            category = Settings.RegisterVerticalLayoutCategory("Bread Codex")
        end

        local function group(name)
            local subcategory, layout = Settings.RegisterVerticalLayoutSubcategory(category, name)
            local g = { category = subcategory, layout = layout }

            local function shownIf(init, pred)
                if pred and init and init.AddShownPredicate then init:AddShownPredicate(pred) end
                return init
            end

            function g.header(label, pred)
                local init = CreateSettingsListSectionHeaderInitializer(label)
                shownIf(init, pred)
                layout:AddInitializer(init)
            end

            function g.button(name, buttonText, onClick, tooltip)
                local init = CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, true)
                layout:AddInitializer(init)
            end

            function g.check(variable, name, tooltip, default, onChange, pred)
                local setting = Settings.RegisterAddOnSetting(
                    subcategory,
                    variable,
                    variable,
                    ClassCodexDB,
                    type(default),
                    name,
                    default
                )
                if onChange then
                    Settings.SetOnValueChangedCallback(variable, function()
                        onChange(ClassCodexDB[variable])
                    end)
                end
                shownIf(Settings.CreateCheckbox(subcategory, setting, tooltip), pred)
            end

            function g.charCheck(variable, key, name, tooltip, default, onChange)
                if not ClassCodexCharDB then return end
                local setting = Settings.RegisterAddOnSetting(
                    subcategory,
                    variable,
                    key,
                    ClassCodexCharDB,
                    type(default),
                    name,
                    default
                )
                if onChange then
                    Settings.SetOnValueChangedCallback(variable, function()
                        onChange(ClassCodexCharDB[key])
                    end)
                end
                Settings.CreateCheckbox(subcategory, setting, tooltip)
            end

            function g.dropdown(variable, name, tooltip, default, options, onChange, pred)
                local setting = Settings.RegisterAddOnSetting(
                    subcategory,
                    variable,
                    variable,
                    ClassCodexDB,
                    type(default),
                    name,
                    default
                )
                if onChange then
                    Settings.SetOnValueChangedCallback(variable, function()
                        onChange(ClassCodexDB[variable])
                    end)
                end
                shownIf(
                    Settings.CreateDropdown(subcategory, setting, function()
                        local container = Settings.CreateControlTextContainer()
                        for _, opt in ipairs(options) do
                            container:Add(opt.value, opt.label)
                        end
                        return container:GetData()
                    end, tooltip),
                    pred
                )
            end

            function g.slider(variable, name, tooltip, default, minV, maxV, step, fmt, onChange, pred)
                local setting = Settings.RegisterAddOnSetting(
                    subcategory,
                    variable,
                    variable,
                    ClassCodexDB,
                    Settings.VarType.Number,
                    name,
                    default
                )
                if onChange then
                    Settings.SetOnValueChangedCallback(variable, function()
                        onChange()
                    end)
                end
                local opts = Settings.CreateSliderOptions(minV, maxV, step)
                opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, fmt or fmtPlain)
                shownIf(Settings.CreateSlider(subcategory, setting, opts, tooltip), pred)
            end

            return g
        end

        local general = group(L["settings.header.general"])
        general.check(
            "showMinimapButton",
            L["settings.label.minimap_button"],
            L["settings.tooltip.minimap_button"],
            true,
            function(val)
                if ns.LDBIcon then
                    ClassCodexDB.minimap.hide = not val
                    if val then
                        ns.LDBIcon:Show("ClassCodex")
                    else
                        ns.LDBIcon:Hide("ClassCodex")
                    end
                end
            end
        )
        general.check("showLoginMessage", L["settings.label.login_message"], L["settings.tooltip.login_message"], false)

        general.header(L["settings.header.talent_pane"])
        general.check(
            "talentPaneEnabled",
            L["settings.label.talent_pane_show"],
            L["settings.tooltip.talent_pane_show"],
            true,
            function(val)
                if ns.SetTalentPaneEnabled then ns.SetTalentPaneEnabled(val) end
            end
        )
        general.check(
            "pinTalentSource",
            L["settings.label.pin_talent_source"],
            L["settings.tooltip.pin_talent_source"],
            false,
            function()
                if ns.OnPinTalentSourceToggled then ns.OnPinTalentSourceToggled() end
            end
        )

        general.header(L["settings.header.unit_menus"])
        general.check(
            "unitMenuEnabled",
            L["settings.label.unit_menu_enabled"],
            L["settings.tooltip.unit_menu_enabled"],
            true
        )

        general.header(L["settings.header.character_pane_button"])
        general.check(
            "widgetLocked",
            L["settings.label.lock_button_position"],
            L["settings.tooltip.lock_button_position"],
            false,
            function()
                if ns.RefreshWidgetTooltip then ns.RefreshWidgetTooltip() end
            end
        )

        local tooltips = group(L["settings.header.tooltips"])
        tooltips.header(L["settings.header.tooltip_stat_priority"])
        tooltips.check(
            "showTooltipBadges",
            L["settings.label.stat_priority_ranks"],
            L["settings.tooltip.stat_priority_ranks"],
            true
        )
        tooltips.dropdown(
            "tooltipFooterMode",
            L["settings.label.stat_priority_source_line"],
            L["settings.tooltip.stat_priority_source_line"],
            2,
            {
                { value = 0, label = L["settings.value.off"] },
                { value = 1, label = L["settings.value.always"] },
                { value = 2, label = L["settings.value.only_when_different"] },
            },
            function()
                ns.InvalidateTooltipCache()
            end
        )
        tooltips.dropdown(
            "tooltipPriorityStyle",
            L["settings.label.priority_display"],
            L["settings.tooltip.priority_display"],
            3,
            {
                { value = 1, label = L["settings.value.icons"] },
                { value = 2, label = L["settings.value.labels"] },
                { value = 3, label = L["settings.value.both"] },
            },
            function()
                ns.InvalidateTooltipCache()
            end
        )
        tooltips.header(L["settings.header.tooltip_bis"])
        tooltips.dropdown(
            "tooltipSourceStyle",
            L["settings.label.source_display"],
            L["settings.tooltip.source_display"],
            1,
            {
                { value = 1, label = L["settings.value.icons"] },
                { value = 2, label = L["settings.value.labels"] },
                { value = 3, label = L["settings.value.both"] },
            },
            function()
                ns.InvalidateTooltipCache()
            end
        )
        tooltips.dropdown("tooltipBisScope", L["settings.label.bis_scope"], L["settings.tooltip.bis_scope"], "all", {
            { value = "all", label = L["settings.value.bis_scope_all"] },
            { value = "group", label = L["settings.value.bis_scope_group"] },
            { value = "self", label = L["settings.value.bis_scope_self"] },
            { value = "off", label = L["settings.value.off"] },
        }, function()
            ns.InvalidateTooltipCache()
        end)
        tooltips.header(L["settings.header.tooltip_trinket"])
        tooltips.check(
            "showTrinketTooltip",
            L["settings.label.trinket_tier"],
            L["settings.tooltip.trinket_tier"],
            true,
            ns.InvalidateTooltipCache
        )

        local panels = group(L["settings.subcat.panels"])
        panels.header(L["settings.header.panel"])
        panels.slider(
            "panelWidth",
            L["settings.label.panel_width"],
            L["settings.tooltip.panel_width"],
            312,
            260,
            500,
            10,
            fmtPixels,
            function()
                ns.UpdatePanelIfVisible()
            end
        )

        local function sections(check, prefix, refresh, genericTip)
            local function tip(tipKey)
                return genericTip or L["settings.tooltip." .. prefix .. "_" .. tipKey]
            end
            check(prefix .. "ShowStats", L["section.stats"], tip("show_stat_priority"), true, refresh)
            check(prefix .. "ShowTalents", L["section.talents"], tip("show_talents"), true, refresh)
            check(prefix .. "ShowOmnium", L["section.omnium"], tip("show_omnium"), true, refresh)
            check(prefix .. "ShowRotation", L["section.rotation"], tip("show_rotation"), true, refresh)
            check(prefix .. "ShowBisGear", L["tab.gear"], tip("show_bis_gear"), true, refresh)
            check(prefix .. "ShowTrinkets", L["tab.trinkets"], tip("show_trinkets"), true, refresh)
            check(prefix .. "ShowEnchants", L["tab.enhancements"], tip("show_enchants"), true, function(val)
                if ClassCodexDB then
                    ClassCodexDB[prefix .. "ShowGems"] = val
                    ClassCodexDB[prefix .. "ShowConsumables"] = val
                end
                refresh()
            end)
            check(prefix .. "ShowCrafts", L["tab.crafting"], tip("show_crafts"), true, function(val)
                if ClassCodexDB then ClassCodexDB[prefix .. "ShowEmbellishments"] = val end
                refresh()
            end)
        end

        panels.header(L["settings.header.docked_panel"])
        sections(panels.check, "dock", function()
            ns.UpdatePanelIfVisible("docked")
        end)
        panels.check(
            "gearSource_dock",
            L["settings.label.gear_source"],
            L["settings.tooltip.gear_source"],
            false,
            function()
                ns.UpdatePanelIfVisible("docked")
            end
        )

        panels.header(L["settings.header.floating_panel"])
        panels.charCheck(
            "ccFloatingMode",
            "floating",
            L["settings.label.floating_mode"],
            L["settings.tooltip.floating_mode"],
            false,
            function(on)
                if ns.SetFloating then ns.SetFloating(on) end
            end
        )
        local function refreshFloat()
            ns.UpdatePanelIfVisible("floating")
        end
        panels.slider(
            "floatPanelHeight",
            L["settings.label.float_height"],
            L["settings.tooltip.float_height"],
            600,
            360,
            1200,
            10,
            fmtPixels,
            refreshFloat
        )
        sections(panels.check, "float", refreshFloat)
        panels.check(
            "gearSource_float",
            L["settings.label.gear_source"],
            L["settings.tooltip.gear_source"],
            false,
            refreshFloat
        )

        panels.header(L["settings.header.tab_order"])
        panels.button(L["settings.label.reorder_tabs"], L["settings.value.reorder"], function()
            if ns.SetReorderMode then ns.SetReorderMode(true) end
            if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
            if not (ns.isFloating and ns.isFloating()) and CharacterFrame and not CharacterFrame:IsShown() then
                ToggleCharacter("PaperDollFrame")
            end
        end, L["settings.tooltip.reorder_tabs"])
        panels.button(L["settings.label.reset_tabs"], L["settings.value.reset"], function()
            if ClassCodexDB then ClassCodexDB.sectionOrder = nil end
            if ns.LayoutSideTabs then ns.LayoutSideTabs() end
            if ns.UpdatePanelIfVisible then ns.UpdatePanelIfVisible() end
        end, L["settings.tooltip.reset_tabs"])

        local compendium = group(L["settings.subcat.compendium"])
        sections(compendium.check, "comp", function()
            if ns.UpdateCompendium then ns:UpdateCompendium() end
        end, L["settings.tooltip.comp_show_tab"])
        compendium.check(
            "gearSource_comp",
            L["settings.label.gear_source"],
            L["settings.tooltip.gear_source"],
            false,
            function()
                if ns.UpdateCompendium then ns:UpdateCompendium() end
            end
        )

        local dock = group(L["settings.header.loadout_dock"])
        ns.loadoutDockSettingsCategory = dock.category
        local function refreshDock()
            if ns.RefreshLoadoutDock then ns.RefreshLoadoutDock() end
        end
        local function refreshVis()
            if ns.UpdateLoadoutDockVisibility then ns.UpdateLoadoutDockVisibility() end
        end
        dock.check(
            "dockLoadoutEnabled",
            L["settings.label.show_loadout_dock"],
            L["settings.tooltip.show_loadout_dock"],
            false,
            refreshVis
        )
        dock.header(L["settings.header.dock_behavior"])
        dock.check(
            "dockLoadoutHideInCombat",
            L["settings.label.dock_hide_in_combat"],
            L["settings.tooltip.dock_hide_in_combat"],
            true,
            refreshVis
        )
        dock.check(
            "dockLoadoutLocked",
            L["settings.label.dock_lock_position"],
            L["settings.tooltip.dock_lock_position"],
            false,
            nil
        )
        dock.header(L["settings.header.dock_display"])
        dock.dropdown("dockLoadoutTheme", L["loadout_dock.theme_title"], L["settings.tooltip.dock_theme"], "codex", {
            { value = "codex", label = L["loadout_dock.theme_codex"] },
            { value = "compact", label = L["loadout_dock.theme_compact"] },
            { value = "minimalist", label = L["loadout_dock.theme_minimalist"] },
        }, function()
            if ns.ApplyLoadoutDockTheme then ns.ApplyLoadoutDockTheme() end
        end)
        dock.check(
            "dockLoadoutShowSpecIcon",
            L["settings.label.dock_show_icons"],
            L["settings.tooltip.dock_show_icons"],
            true,
            function(val)
                if ClassCodexDB then ClassCodexDB.dockLoadoutShowHeroIcon = val end
                refreshDock()
            end
        )
        dock.check(
            "dockLoadoutShowSaved",
            L["settings.label.dock_show_saved"],
            L["settings.tooltip.dock_show_saved"],
            true,
            nil
        )
        dock.check(
            "dockLoadoutShowIcyVeins",
            L["settings.label.dock_show_icyveins"],
            L["settings.tooltip.dock_show_icyveins"],
            true,
            nil
        )
        dock.check(
            "dockLoadoutShowUgg",
            L["settings.label.dock_show_ugg"],
            L["settings.tooltip.dock_show_ugg"],
            true,
            nil
        )
        dock.check("dockLoadoutShowPvp", L["loadout_dock.show_pvp"], L["settings.tooltip.dock_show_pvp"], true, nil)
        dock.dropdown(
            "raidDifficulty",
            L["settings.label.raid_difficulty"],
            L["settings.tooltip.raid_difficulty"],
            "both",
            {
                { value = "both", label = L["settings.value.both"] },
                { value = "heroic", label = L["settings.value.heroic"] },
                { value = "mythic", label = L["settings.value.mythic"] },
            },
            nil
        )
        dock.header(L["settings.header.dock_appearance"])
        local function refreshDockTheme()
            if ns.ApplyLoadoutDockTheme then ns.ApplyLoadoutDockTheme() end
        end
        dock.dropdown(
            "dockLoadoutBackground",
            L["settings.label.dock_background"],
            L["settings.tooltip.dock_background"],
            "class",
            {
                { value = "class", label = L["settings.value.dock_bg_class"] },
                { value = "custom", label = L["settings.value.dock_bg_custom"] },
            },
            refreshDockTheme
        )
        dock.button(L["settings.label.dock_pick_color"], L["settings.value.dock_pick_color_pick"], function()
            local function storeColor()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                ClassCodexDB.dockLoadoutBackgroundColor = { r = r, g = g, b = b }
                ClassCodexDB.dockLoadoutBackground = "custom"
                refreshDockTheme()
            end
            local cur = ClassCodexDB.dockLoadoutBackgroundColor or {}
            ColorPickerFrame:SetupColorPickerAndShow({
                swatchFunc = storeColor,
                hasOpacity = false,
                r = cur.r or 0.08,
                g = cur.g or 0.08,
                b = cur.b or 0.09,
            })
        end, L["settings.tooltip.dock_pick_color"])
        dock.check(
            "dockLoadoutAutoWidth",
            L["settings.label.dock_auto_width"],
            L["settings.tooltip.dock_auto_width"],
            false,
            refreshDock
        )
        dock.slider(
            "dockLoadoutWidth",
            L["settings.label.dock_width"],
            L["settings.tooltip.dock_width"],
            200,
            120,
            400,
            10,
            fmtPixels,
            function()
                if ns.ApplyLoadoutDockWidth then ns.ApplyLoadoutDockWidth() end
            end
        )
        dock.slider(
            "dockLoadoutMaxWidth",
            L["settings.label.dock_max_width"],
            L["settings.tooltip.dock_max_width"],
            400,
            120,
            600,
            10,
            fmtPixels,
            function()
                if ns.ApplyLoadoutDockWidth then ns.ApplyLoadoutDockWidth() end
            end
        )
        dock.slider(
            "dockLoadoutScale",
            L["settings.label.dock_scale"],
            L["settings.tooltip.dock_scale"],
            100,
            50,
            200,
            5,
            fmtPercent,
            function()
                if ns.ApplyLoadoutDockScale then ns.ApplyLoadoutDockScale() end
            end
        )
        dock.dropdown(
            "dockLoadoutAlignment",
            L["settings.label.dock_alignment"],
            L["settings.tooltip.dock_alignment"],
            "LEFT",
            {
                { value = "LEFT", label = L["settings.value.left"] },
                { value = "CENTER", label = L["settings.value.center"] },
                { value = "RIGHT", label = L["settings.value.right"] },
            },
            refreshDock
        )

        Settings.RegisterAddOnCategory(category)
        ns.settingsCategory = category
    end)

    function ns.OpenSettings()
        if Settings and Settings.OpenToCategory and ns.settingsCategory then
            Settings.OpenToCategory(ns.settingsCategory:GetID())
        end
    end
    if not ok then
        print("|cffff0000Bread Codex:|r " .. L["chat.settings_registration_failed"]:format(tostring(err)))
    end
end
