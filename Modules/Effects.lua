local E, L, V, P, G = unpack(ElvUI)
if not E then return end

local addonName = ...
local QoL = E:GetModule(addonName)

local Effects = {}
QoL.Modules.Effects = Effects

local A = E:GetModule('Auras')
local UF = E:GetModule('UnitFrames')
local config

local function LoadConfig()
    if not E.db.CenterStacks then E.db.CenterStacks = {} end
    
    local defaults = {
        buffs = { enabled = true, position = "TOP", xOffset = 0, yOffset = 3, color = {r = 1, g = 1, b = 1} },
        debuffs = { enabled = true, position = "TOP", xOffset = 0, yOffset = 3, color = {r = 1, g = 1, b = 1} },
        playerDebuffs = { 
            enabled = true, 
            fontSize = 12, 
            color = {r = 1, g = 1, b = 1},
            durationEnabled = false, 
            durationPosition = "BOTTOM",
            durationXOffset = 0,
            durationYOffset = 0,
            durationFontSize = 12,
            durationFont = "Homespun",
            durationFontOutline = "OUTLINE",
            durationColor = {r = 1, g = 1, b = 1},
        },
    }
    
    for group, settings in pairs(defaults) do
        if not E.db.CenterStacks[group] then E.db.CenterStacks[group] = {} end
        for key, value in pairs(settings) do
            if E.db.CenterStacks[group][key] == nil then
                if type(value) == "table" then
                    E.db.CenterStacks[group][key] = {r = value.r, g = value.g, b = value.b}
                else
                    E.db.CenterStacks[group][key] = value
                end
            end
        end
    end
    config = E.db.CenterStacks
end

local function PositionText(button, auraType)
    if not button or not button.count then return end
    local cfg = (auraType == "buffs") and config.buffs or config.debuffs
    if not cfg.enabled then return end
    
    button.count:SetJustifyH('CENTER')
    if cfg.position == "TOP" then
        button.count:SetJustifyV('TOP')
        button.count:ClearAllPoints()
        button.count:SetPoint('TOP', button, 'TOP', cfg.xOffset, cfg.yOffset)
    elseif cfg.position == "CENTER" then
        button.count:SetJustifyV('MIDDLE')
        button.count:ClearAllPoints()
        button.count:SetPoint('CENTER', button, 'CENTER', cfg.xOffset, cfg.yOffset)
    elseif cfg.position == "BOTTOM" then
        button.count:SetJustifyV('BOTTOM')
        button.count:ClearAllPoints()
        button.count:SetPoint('BOTTOM', button, 'BOTTOM', cfg.xOffset, -cfg.yOffset)
    end

    if cfg.color then
        button.count:SetTextColor(cfg.color.r, cfg.color.g, cfg.color.b)
    end
end

local function FormatUFAura(button)
    local cfg = config.playerDebuffs
    if not cfg.enabled then return end

    local countText = button and (button.Count or button.count)
    if countText then
        if cfg.color then
            countText:SetTextColor(cfg.color.r, cfg.color.g, cfg.color.b)
        end
        if cfg.fontSize then
            local font, _, outline = countText:GetFont()
            if font then
                countText:FontTemplate(font, cfg.fontSize, outline)
            end
        end
    end

    if button.QoLDuration then 
        button.QoLDuration:Hide() 
    end

    if cfg.durationEnabled and button.Cooldown then
        button.Cooldown:SetHideCountdownNumbers(false)

        local nativeText = button._nativeText
        if not nativeText then
            for _, region in ipairs({button.Cooldown:GetRegions()}) do
                if region:GetObjectType() == "FontString" then
                    nativeText = region
                    button._nativeText = nativeText
                    break
                end
            end
        end

        if nativeText then
            local fontPath = E.Libs.LSM:Fetch("font", cfg.durationFont)
            if fontPath then
                nativeText:FontTemplate(fontPath, cfg.durationFontSize, cfg.durationFontOutline)
            end
        end

        if not button._qolSafeHook then
            button:HookScript("OnUpdate", function(self)
                local c = config.playerDebuffs
                if not c.enabled or not c.durationEnabled or not self._nativeText then return end
                
                self._nativeText:ClearAllPoints()
                self._nativeText:SetPoint(c.durationPosition, self, c.durationPosition, c.durationXOffset, c.durationYOffset)
                
                if c.durationColor then
                    self._nativeText:SetTextColor(c.durationColor.r, c.durationColor.g, c.durationColor.b, 1)
                end
            end)
            button._qolSafeHook = true
        end
    end
end

function Effects:ApplyToAll()
    if A then
        if A.BuffFrame and A.BuffFrame.ForEachChild then
            A.BuffFrame:ForEachChild(function(_, button) PositionText(button, "buffs") end)
        end
        if A.DebuffFrame and A.DebuffFrame.ForEachChild then
            A.DebuffFrame:ForEachChild(function(_, button) PositionText(button, "debuffs") end)
        end
    end

    if _G.ElvUF_Player then
        local frame = _G.ElvUF_Player
        if frame.Debuffs then
            for i = 1, frame.Debuffs.visibleAuras or 0 do
                local button = frame.Debuffs[i]
                if button then FormatUFAura(button) end
            end
        end
        if frame.Auras then
            for i = 1, frame.Auras.visibleAuras or 0 do
                local button = frame.Auras[i]
                if button and (button.filter == "HARMFUL" or button.isDebuff) then 
                    FormatUFAura(button) 
                end
            end
        end
    end
end

function Effects:HookAuras()
    if A and not A._centerHooked then
        QoL:SecureHook(A, "CreateIcon", function(self, button)
            local auraType = (button:GetParent() == A.BuffFrame) and "buffs" or "debuffs"
            PositionText(button, auraType)
        end)
        QoL:SecureHook(A, "UpdateAura", function(self, button, index)
            local auraType = (button:GetParent() == A.BuffFrame) and "buffs" or "debuffs"
            PositionText(button, auraType)
        end)
        A._centerHooked = true
    end

    if UF and not UF._centerHooked then
        QoL:SecureHook(UF, "PostUpdateAura", function(auraFrame, unitString, auraButton, index)
            if type(auraFrame) == "table" and auraFrame.GetParent then
                if auraFrame:GetParent() == _G.ElvUF_Player then
                    local isHarmful = (auraButton and auraButton.filter == "HARMFUL") or (auraFrame.type == "debuffs")
                    if isHarmful then
                        FormatUFAura(auraButton)
                    end
                end
            end
        end)
        UF._centerHooked = true
    end

    self:ApplyToAll()
end

function Effects:InsertOptions()
    E.Options.args.ElvUI_QoL.args.effects = {
        order = 1,
        type = "group",
        name = "Center Stacks",
        args = {
            buffs = {
                order = 1, type = "group", name = "Buffs", guiInline = true,
                get = function(info) return E.db.CenterStacks.buffs[info[#info]] end,
                set = function(info, value) E.db.CenterStacks.buffs[info[#info]] = value; Effects:ApplyToAll() end,
                args = {
                    enabled = { order = 1, type = "toggle", name = "Enable" },
                    position = { order = 2, type = "select", name = "Position", values = { ["TOP"] = "Top", ["CENTER"] = "Center", ["BOTTOM"] = "Bottom" } },
                    xOffset = { order = 3, type = "range", name = "X Offset", min = -50, max = 50, step = 1 },
                    yOffset = { order = 4, type = "range", name = "Y Offset", min = -50, max = 50, step = 1 },
                    color = {
                        order = 5, type = "color", name = "Color", hasAlpha = false,
                        get = function(info) local c = E.db.CenterStacks.buffs.color; return c.r, c.g, c.b end,
                        set = function(info, r, g, b) local c = E.db.CenterStacks.buffs.color; c.r, c.g, c.b = r, g, b; Effects:ApplyToAll() end,
                    },
                },
            },
            debuffs = {
                order = 2, type = "group", name = "Debuffs", guiInline = true,
                get = function(info) return E.db.CenterStacks.debuffs[info[#info]] end,
                set = function(info, value) E.db.CenterStacks.debuffs[info[#info]] = value; Effects:ApplyToAll() end,
                args = {
                    enabled = { order = 1, type = "toggle", name = "Enable" },
                    position = { order = 2, type = "select", name = "Position", values = { ["TOP"] = "Top", ["CENTER"] = "Center", ["BOTTOM"] = "Bottom" } },
                    xOffset = { order = 3, type = "range", name = "X Offset", min = -50, max = 50, step = 1 },
                    yOffset = { order = 4, type = "range", name = "Y Offset", min = -50, max = 50, step = 1 },
                    color = {
                        order = 5, type = "color", name = "Color", hasAlpha = false,
                        get = function(info) local c = E.db.CenterStacks.debuffs.color; return c.r, c.g, c.b end,
                        set = function(info, r, g, b) local c = E.db.CenterStacks.debuffs.color; c.r, c.g, c.b = r, g, b; Effects:ApplyToAll() end,
                    },
                },
            },
            playerDebuffs = {
                order = 3, type = "group", name = "Player UF Debuffs", guiInline = true,
                get = function(info) return E.db.CenterStacks.playerDebuffs[info[#info]] end,
                set = function(info, value) E.db.CenterStacks.playerDebuffs[info[#info]] = value; Effects:ApplyToAll() end,
                args = {
                    enabled = { order = 1, type = "toggle", name = "Enable Stacks Override" },
                    fontSize = { order = 2, type = "range", name = "Stacks Font Size", min = 6, max = 32, step = 1 },
                    color = {
                        order = 3, type = "color", name = "Stacks Color", hasAlpha = false,
                        get = function(info) local c = E.db.CenterStacks.playerDebuffs.color; return c.r, c.g, c.b end,
                        set = function(info, r, g, b) local c = E.db.CenterStacks.playerDebuffs.color; c.r, c.g, c.b = r, g, b; Effects:ApplyToAll() end,
                    },
                    durationHeader = { order = 4, type = "header", name = "Duration Text Customization" },
                    durationEnabled = { order = 5, type = "toggle", name = "Enable Duration Override" },
                    durationPosition = { 
                        order = 6, type = "select", name = "Anchor", 
                        values = { 
                            ["TOP"] = "Top", 
                            ["BOTTOM"] = "Bottom", 
                            ["LEFT"] = "Left", 
                            ["RIGHT"] = "Right", 
                            ["TOPLEFT"] = "Top Left", 
                            ["TOPRIGHT"] = "Top Right", 
                            ["BOTTOMLEFT"] = "Bottom Left", 
                            ["BOTTOMRIGHT"] = "Bottom Right", 
                            ["CENTER"] = "Center" 
                        } 
                    },
                    durationXOffset = { order = 7, type = "range", name = "X Offset", min = -50, max = 50, step = 1 },
                    durationYOffset = { order = 8, type = "range", name = "Y Offset", min = -50, max = 50, step = 1 },
                    durationFontSize = { order = 9, type = "range", name = "Font Size", min = 6, max = 32, step = 1 },
                    durationFont = { order = 10, type = "select", dialogControl = 'LSM30_Font', name = "Font", values = E.Libs.LSM:HashTable("font") },
                    durationFontOutline = { order = 11, type = "select", name = "Font Outline", values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["MONOCHROMEOUTLINE"] = "Monochrome", ["THICKOUTLINE"] = "Thick Outline" } },
                    durationColor = {
                        order = 12, type = "color", name = "Duration Color", hasAlpha = false,
                        get = function(info) local c = E.db.CenterStacks.playerDebuffs.durationColor; return c.r, c.g, c.b end,
                        set = function(info, r, g, b) local c = E.db.CenterStacks.playerDebuffs.durationColor; c.r, c.g, c.b = r, g, b; Effects:ApplyToAll() end,
                    },
                },
            },
        },
    }
end

function Effects:Initialize()
    LoadConfig()
    self:HookAuras()
end