local E, L, V, P, G = unpack(ElvUI)
if not E then return end

local addonName = ...
local QoL = E:GetModule(addonName)

local RangeCheck = {}
QoL.Modules.RangeCheck = RangeCheck

local LRC = LibStub("LibRangeCheck-3.0", true) or LibStub("LibRangeCheck-2.0", true)
local frame
local config

local function LoadConfig()
    if not E.db.RangeCheck then E.db.RangeCheck = {} end
    
    local defaults = {
        enabled = true,
        font = "PT Sans Narrow", 
        fontSize = 22,
        fontOutline = "OUTLINE",
        textFormat = "[range]",
        updateInterval = 0.1,
        thresholdClose = 10,
        thresholdMedium = 30,
        
        colorClose = { r = 0, g = 1, b = 0 },  
        colorMedium = { r = 1, g = 1, b = 0 }, 
        colorFar = { r = 1, g = 0, b = 0 },    
    }
    
    for key, value in pairs(defaults) do
        if E.db.RangeCheck[key] == nil then
            if type(value) == "table" then
                E.db.RangeCheck[key] = { r = value.r, g = value.g, b = value.b }
            else
                E.db.RangeCheck[key] = value
            end
        end
    end
    config = E.db.RangeCheck
end

local timeSinceLastUpdate = 0
local function OnUpdate(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate < config.updateInterval then return end
    timeSinceLastUpdate = 0
    
    if not UnitExists("target") or UnitIsDeadOrGhost("target") then
        frame.text:SetText("")
        return
    end
    
    local minRange, maxRange
    if LRC then
        minRange, maxRange = LRC:GetRange("target")
    else
        if CheckInteractDistance("target", 2) then
            minRange, maxRange = 0, 9
        elseif CheckInteractDistance("target", 3) then
            minRange, maxRange = 9, 10
        elseif CheckInteractDistance("target", 4) then
            minRange, maxRange = 10, 28
        else
            minRange, maxRange = 28, nil 
        end
    end
    
    local rangeText = "??"
    local displayMax = maxRange or minRange or 999
    
    if minRange and maxRange then
        rangeText = string.format("%d - %d", minRange, maxRange)
    elseif minRange then
        rangeText = string.format("> %d", minRange)
    elseif maxRange then
        rangeText = string.format("< %d", maxRange)
    end
    
    local finalText = string.gsub(config.textFormat, "%[range%]", rangeText)
    frame.text:SetText(finalText)
    
    if displayMax <= config.thresholdClose then
        frame.text:SetTextColor(config.colorClose.r, config.colorClose.g, config.colorClose.b)
    elseif displayMax <= config.thresholdMedium then
        frame.text:SetTextColor(config.colorMedium.r, config.colorMedium.g, config.colorMedium.b)
    else
        frame.text:SetTextColor(config.colorFar.r, config.colorFar.g, config.colorFar.b)
    end
end

local function OnEvent(self, event, ...)
    if not config.enabled then return end
    if UnitExists("target") and not UnitIsDeadOrGhost("target") then
        frame:Show()
    else
        frame:Hide()
    end
end

function RangeCheck:CreateAnchorFrame()
    if frame then return end
    
    frame = CreateFrame("Frame", "ElvUI_QoL_RangeCheckFrame", E.UIParent)
    frame:SetSize(120, 30)
    frame:SetPoint("CENTER", E.UIParent, "CENTER", 0, -150)
    
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("CENTER", frame, "CENTER")
    
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", OnEvent)
    
    E:CreateMover(frame, "ElvUI_QoL_RangeCheckMover", "QoL Range Check", nil, nil, nil, "ALL,SOLO")
    
    self:UpdateLayout()
end

function RangeCheck:UpdateLayout()
    if not frame then return end
    
    if config.enabled then
        frame:SetScript("OnUpdate", OnUpdate)
        
        local font = E.Libs.LSM:Fetch("font", config.font)
        frame.text:FontTemplate(font, config.fontSize, config.fontOutline)
        
        if E.EnableMover then
            E:EnableMover("ElvUI_QoL_RangeCheckMover")
        end
        
        OnEvent(frame)
    else
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
        
        if E.DisableMover then
            E:DisableMover("ElvUI_QoL_RangeCheckMover")
        end
    end
end

function RangeCheck:InsertOptions()
    E.Options.args.ElvUI_QoL.args.rangeCheck = {
        order = 3,
        type = "group",
        name = "Range Check",
        get = function(info) return E.db.RangeCheck[info[#info]] end,
        set = function(info, value) E.db.RangeCheck[info[#info]] = value; RangeCheck:UpdateLayout() end,
        args = {
            enabled = { order = 1, type = "toggle", name = "Enable Module" },
            
            textSettings = {
                order = 2, type = "group", guiInline = true, name = "Text Settings",
                args = {
                    font = {
                        order = 1, type = "select", dialogControl = "LSM30_Font",
                        name = "Font", values = AceGUIWidgetLSMlists.font,
                    },
                    fontSize = { order = 2, type = "range", name = "Font Size", min = 10, max = 72, step = 1 },
                    fontOutline = {
                        order = 3, type = "select", name = "Font Outline",
                        values = { ["NONE"] = "None", ["OUTLINE"] = "OUTLINE", ["THICKOUTLINE"] = "THICKOUTLINE", ["MONOCHROME"] = "MONOCHROME" },
                    },
                    textFormat = {
                        order = 4, type = "input", width = "full",
                        name = "Custom Format",
                        desc = "Use [range] as an anchor for the value.\nExample: 'To target: [range]'",
                    },
                },
            },
            
            colorSettings = {
                order = 3, type = "group", guiInline = true, name = "Colors & Thresholds",
                args = {
                    thresholdClose = { order = 1, type = "range", name = "Close Range (<= y)", min = 1, max = 100, step = 1 },
                    colorClose = {
                        order = 2, type = "color", name = "Close Color", hasAlpha = false,
                        get = function(info) local c = E.db.RangeCheck.colorClose; return c.r, c.g, c.b end,
                        set = function(info, r, g, b) local c = E.db.RangeCheck.colorClose; c.r, c.g, c.b = r, g, b end,
                    },
                    thresholdMedium = { order = 3, type = "range", name = "Medium Range (<= y)", min = 1, max = 100, step = 1 },
                    colorMedium = {
                        order = 4, type = "color", name = "Medium Color", hasAlpha = false,
                        get = function(info) local c = E.db.RangeCheck.colorMedium; return c.r, c.g, c.b end,
                        set = function(info, r, g, b) local c = E.db.RangeCheck.colorMedium; c.r, c.g, c.b = r, g, b end,
                    },
                    colorFar = {
                        order = 5, type = "color", name = "Far Color", hasAlpha = false,
                        get = function(info) local c = E.db.RangeCheck.colorFar; return c.r, c.g, c.b end,
                        set = function(info, r, g, b) local c = E.db.RangeCheck.colorFar; c.r, c.g, c.b = r, g, b end,
                    },
                },
            },
            
            updateInterval = {
                order = 4, type = "range", name = "Update Interval (s)", min = 0.05, max = 0.5, step = 0.01,
            },
        },
    }
end

function RangeCheck:Initialize()
    LoadConfig()
    self:CreateAnchorFrame()
end