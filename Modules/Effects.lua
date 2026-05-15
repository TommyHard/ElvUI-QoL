local E, L, V, P, G = unpack(ElvUI)
if not E then return end

local addonName = ...
local QoL = E:GetModule(addonName)

local Effects = {}
QoL.Modules.Effects = Effects

local A = E:GetModule('Auras')
local config

local function LoadConfig()
    if not E.db.CenterStacks then E.db.CenterStacks = {} end
    
    local defaults = {
        buffs = { enabled = true, position = "TOP", xOffset = 0, yOffset = 3 },
        debuffs = { enabled = true, position = "TOP", xOffset = 0, yOffset = 3 },
    }
    
    if not E.db.CenterStacks.buffs then E.db.CenterStacks.buffs = {} end
    if not E.db.CenterStacks.debuffs then E.db.CenterStacks.debuffs = {} end
    
    for key, value in pairs(defaults.buffs) do
        if E.db.CenterStacks.buffs[key] == nil then E.db.CenterStacks.buffs[key] = value end
    end
    for key, value in pairs(defaults.debuffs) do
        if E.db.CenterStacks.debuffs[key] == nil then E.db.CenterStacks.debuffs[key] = value end
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
end

function Effects:ApplyToAll()
    if not A then return end
    if A.BuffFrame and A.BuffFrame.ForEachChild then
        A.BuffFrame:ForEachChild(function(_, button) PositionText(button, "buffs") end)
    end
    if A.DebuffFrame and A.DebuffFrame.ForEachChild then
        A.DebuffFrame:ForEachChild(function(_, button) PositionText(button, "debuffs") end)
    end
end

function Effects:HookAuras()
    if not A or A._centerHooked then return end
    QoL:SecureHook(A, "CreateIcon", function(self, button)
        local auraType = (button:GetParent() == A.BuffFrame) and "buffs" or "debuffs"
        PositionText(button, auraType)
    end)
    QoL:SecureHook(A, "UpdateAura", function(self, button, index)
        local auraType = (button:GetParent() == A.BuffFrame) and "buffs" or "debuffs"
        PositionText(button, auraType)
    end)
    A._centerHooked = true
    self:ApplyToAll()
end

function Effects:InsertOptions()
    E.Options.args.ElvUI_QoL.args.effects = {
        order = 1,
        type = "group",
        name = "Center Stacks",
        args = {
            buffs = {
                order = 1,
                type = "group",
                name = "Buffs",
                guiInline = true,
                get = function(info) return E.db.CenterStacks.buffs[info[#info]] end,
                set = function(info, value) E.db.CenterStacks.buffs[info[#info]] = value; Effects:ApplyToAll() end,
                args = {
                    enabled = { order = 1, type = "toggle", name = "Enable" },
                    position = { order = 2, type = "select", name = "Position", values = { ["TOP"] = "Top", ["CENTER"] = "Center", ["BOTTOM"] = "Bottom" } },
                    xOffset = { order = 3, type = "range", name = "X Offset", min = -50, max = 50, step = 1 },
                    yOffset = { order = 4, type = "range", name = "Y Offset", min = -50, max = 50, step = 1 },
                },
            },
            debuffs = {
                order = 2,
                type = "group",
                name = "Debuffs",
                guiInline = true,
                get = function(info) return E.db.CenterStacks.debuffs[info[#info]] end,
                set = function(info, value) E.db.CenterStacks.debuffs[info[#info]] = value; Effects:ApplyToAll() end,
                args = {
                    enabled = { order = 1, type = "toggle", name = "Enable" },
                    position = { order = 2, type = "select", name = "Position", values = { ["TOP"] = "Top", ["CENTER"] = "Center", ["BOTTOM"] = "Bottom" } },
                    xOffset = { order = 3, type = "range", name = "X Offset", min = -50, max = 50, step = 1 },
                    yOffset = { order = 4, type = "range", name = "Y Offset", min = -50, max = 50, step = 1 },
                },
            },
        },
    }
end

function Effects:Initialize()
    LoadConfig()
    self:HookAuras()
end