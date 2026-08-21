local _, ns = ...

if not PlayerSpellsFrame and not C_ClassTalents then return end

local secureSetNil
do
    local mixin = TextureLoadingGroupMixin
    if mixin and mixin.RemoveTexture then
        function secureSetNil(tbl, key)
            mixin.RemoveTexture({ textures = tbl }, key)
        end
    else
        function secureSetNil(tbl, key)
            tbl[key] = nil
        end
    end
end

ns.secureSetNil = secureSetNil

local function FixTalentFrameConfigID()
    local talentsFrame = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not talentsFrame then return end

    local shareBtn = talentsFrame.SearchBox and talentsFrame.SearchBox.ShareButton or talentsFrame.ShareButton
    if shareBtn and not shareBtn._classCodexHooked then
        shareBtn:HookScript("PreClick", function()
            if not issecurevariable(talentsFrame, "configID") then
                local configID = C_ClassTalents.GetActiveConfigID()
                if configID then
                    secureSetNil(talentsFrame, "configID")
                    talentsFrame.configID = configID
                end
            end
        end)
        shareBtn._classCodexHooked = true
    end
end

local function FixOnHideTaint()
    local frame = PlayerSpellsFrame
    if not frame or frame._classCodexOnHideHooked then return end

    frame:HookScript("OnHide", function(self)
        for _, key in ipairs({ "inspectUnit", "inspectString", "lockInspect" }) do
            if not issecurevariable(self, key) then secureSetNil(self, key) end
        end
    end)
    frame._classCodexOnHideHooked = true
end

local function FixMultiActionBarTaint()
    local frame = PlayerSpellsFrame
    if not frame or frame._classCodexOnShowHooked then return end

    hooksecurefunc(FrameUtil, "UnregisterFrameForEvents", function(f)
        if f ~= frame then return end
        for _, key in ipairs({ "lockInspect", "inspectUnit", "inspectString" }) do
            if not issecurevariable(frame, key) then
                if not frame[key] then secureSetNil(frame, key) end
            end
        end
    end)

    frame._classCodexOnShowHooked = true
end

local function FixMicroButtonTaint()
    local btn = TalentMicroButton
    if not btn or btn._classCodexTaintHooked then return end

    local cleanupFrame = CreateFrame("Frame")
    cleanupFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    cleanupFrame:SetScript("OnEvent", function()
        if btn and not issecurevariable(btn, "canUseTalentUI") then secureSetNil(btn, "canUseTalentUI") end
        if btn and not issecurevariable(btn, "canUseTalentSpecUI") then secureSetNil(btn, "canUseTalentSpecUI") end
    end)
    btn._classCodexTaintHooked = true
end

local function FixCastbarTaint()
    local talentsFrame = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not talentsFrame or talentsFrame._classCodexCastbarFixed then return end
    secureSetNil(talentsFrame, "enableCommitCastBar")
    talentsFrame._classCodexCastbarFixed = true
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_PlayerSpells" then
        FixTalentFrameConfigID()
        FixOnHideTaint()
        FixMultiActionBarTaint()
        FixMicroButtonTaint()
        FixCastbarTaint()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        if PlayerSpellsFrame then
            FixTalentFrameConfigID()
            FixOnHideTaint()
            FixMultiActionBarTaint()
            FixMicroButtonTaint()
            self:UnregisterEvent("ADDON_LOADED")
        end
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
