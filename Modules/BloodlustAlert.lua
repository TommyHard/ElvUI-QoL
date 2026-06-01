local E, L, V, P, G = unpack(ElvUI)
if not E then return end

local addonName = ...
local QoL = E:GetModule(addonName)

local BloodlustAlert = {}
QoL.Modules.BloodlustAlert = BloodlustAlert

local iconFrame, barFrame
local config
local activeTimer
local lastSoundHandle
local lastExhaustionExpiration = 0
local isReady = false

local EXHAUSTION_IDS = { 57723, 57724, 80354, 95809, 160455, 207400, 264689, 390435 }
local EXHAUSTION_DURATION = 600
local FRESH_WINDOW = 5
local CD_DURATION = 40

local function LoadConfig()
    if not E.db.BloodlustAlert then E.db.BloodlustAlert = {} end
    
    local defaults = {
        enabled = true,
        spellID = "",
        
        -- Icon Mode Settings
        enableIcon = true,
        hideIcon = false,
        iconSize = 60,
        iconTexture = [[Interface\Icons\SPELL_NATURE_BLOODLUST]],
        useNativeCD = false,
        reverseCD = true,
        showBorder = true,
        borderTexture = "1 Pixel",
        borderSize = 1,
        borderPadding = 1,
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
        iconFont = "PT Sans Narrow",
        iconFontSize = 32,
        iconFontOutline = "OUTLINE",
        
        -- ProgressBar Mode Settings
        enableBar = false,
        barWidth = 220,
        barHeight = 24,
        barTexture = "ElvUI Norm",
        barColor = { r = 1, g = 0.3, b = 0, a = 1 },
        barBgColor = { r = 0, g = 0, b = 0, a = 0.6 },
        barTextLabel = "Bloodlust Alert",
        barFont = "PT Sans Narrow",
        barFontSize = 14,
        barFontOutline = "OUTLINE",
        
        -- Sound Settings
        sound = "None",
        soundChannel = "Master",
        useCustomSound = false,
        randomSound = false,
        customSounds = { "", "", "", "", "", "" },
    }
    
    for key, value in pairs(defaults) do
        if E.db.BloodlustAlert[key] == nil then
            if type(value) == "table" then
                if value.r then
                    E.db.BloodlustAlert[key] = { r = value.r, g = value.g, b = value.b, a = value.a }
                else
                    E.db.BloodlustAlert[key] = { unpack(value) }
                end
            else
                E.db.BloodlustAlert[key] = value
            end
        end
    end
    config = E.db.BloodlustAlert
end

local function StopEffect()
    if lastSoundHandle then
        StopSound(lastSoundHandle)
        lastSoundHandle = nil
    end
    if activeTimer then
        activeTimer:Cancel()
        activeTimer = nil
    end
    if iconFrame then iconFrame:Hide() end
    if barFrame then barFrame:Hide() end
end

local function PlayEffect()
    if not config.enabled then return end
    StopEffect()

    local soundToPlay = nil
    if config.useCustomSound then
        if config.randomSound then
            local validSounds = {}
            for _, s in ipairs(config.customSounds or {}) do
                if s and s ~= "" then table.insert(validSounds, s) end
            end
            if #validSounds > 0 then soundToPlay = validSounds[math.random(1, #validSounds)] end
        else
            local s = config.customSounds and config.customSounds[1]
            if s and s ~= "" then soundToPlay = s end
        end
    else
        if config.sound and config.sound ~= "None" then
            soundToPlay = E.Libs.LSM:Fetch("sound", config.sound)
        end
    end

    if soundToPlay then
        local _, handle = PlaySoundFile(soundToPlay, config.soundChannel or "Master")
        lastSoundHandle = handle
    end

    BloodlustAlert:UpdateLayout()
    
    local now = GetTime()
    local timeLeft = CD_DURATION

    if config.enableIcon and not config.hideIcon then
        iconFrame:Show()
        iconFrame.CD:SetCooldown(now, CD_DURATION)
    end

    if config.enableBar then
        barFrame:Show()
        barFrame:SetValue(timeLeft)
        barFrame.timerText:SetText(string.format("%.1f", timeLeft))
    end

    local lastDisplayNum = math.ceil(timeLeft)
    if not config.useNativeCD then iconFrame.timerText:SetText(lastDisplayNum) end

    activeTimer = C_Timer.NewTicker(0.05, function()
        timeLeft = timeLeft - 0.05
        if timeLeft <= 0 then
            StopEffect()
        else
            if config.enableBar then
                barFrame:SetValue(timeLeft)
                barFrame.timerText:SetText(string.format("%.1f", timeLeft))
            end
            
            local currentDisplayNum = math.ceil(timeLeft)
            if not config.useNativeCD and currentDisplayNum ~= lastDisplayNum then
                lastDisplayNum = currentDisplayNum
                iconFrame.timerText:SetText(currentDisplayNum)
            end
        end
    end)
end

local function CheckExhaustionFresh()
    local UnitAuras = _G.C_UnitAuras
    if not UnitAuras or type(UnitAuras.GetPlayerAuraBySpellID) ~= "function" then return false, nil end
    local now = GetTime()
    for _, id in ipairs(EXHAUSTION_IDS) do
        local aura = UnitAuras.GetPlayerAuraBySpellID(id)
        if aura and aura.expirationTime then
            local remaining = aura.expirationTime - now
            if remaining >= (EXHAUSTION_DURATION - FRESH_WINDOW) then
                return true, aura.expirationTime
            end
        end
    end
    return false, nil
end

local function OnAuraUpdate()
    if not isReady or not config.enabled then return end
    local fresh, expirationTime = CheckExhaustionFresh()
    if not fresh or not expirationTime then return end
    if expirationTime == lastExhaustionExpiration then return end
    
    lastExhaustionExpiration = expirationTime
    PlayEffect()
end

function BloodlustAlert:CreateFrames()
    if iconFrame or barFrame then return end

    -- Icon Frame Base
    iconFrame = CreateFrame("Frame", "ElvUI_QoL_BLIconFrame", E.UIParent)
    iconFrame:SetSize(60, 60)
    iconFrame:SetPoint("CENTER", E.UIParent, "CENTER", -390, 14)
    iconFrame:Hide()
    
    iconFrame.bg = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconFrame.bg:SetAllPoints()
    iconFrame.bg:SetColorTexture(0, 0, 0, 0.5)
    
    iconFrame.tex = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.tex:SetAllPoints()
    iconFrame.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    iconFrame.border = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
    iconFrame.border:SetFrameLevel(iconFrame:GetFrameLevel() + 5)
    
    iconFrame.timerText = iconFrame:CreateFontString(nil, "OVERLAY")
    iconFrame.timerText:SetPoint("CENTER", iconFrame, "CENTER")
    
    iconFrame.CD = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
    iconFrame.CD:SetAllPoints()
    iconFrame.CD:SetDrawEdge(false)

    E:CreateMover(iconFrame, "ElvUI_QoL_BLIconMover", "QoL Bloodlust Icon", nil, nil, nil, "ALL,SOLO")

    -- ProgressBar Frame Base
    barFrame = CreateFrame("StatusBar", "ElvUI_QoL_BLBarFrame", E.UIParent)
    barFrame:SetSize(220, 24)
    barFrame:SetPoint("CENTER", E.UIParent, "CENTER", -390, -60)
    barFrame:SetMinMaxValues(0, CD_DURATION)
    barFrame:Hide()
    
    barFrame.bg = barFrame:CreateTexture(nil, "BACKGROUND")
    barFrame.bg:SetAllPoints()
    
    barFrame.labelText = barFrame:CreateFontString(nil, "OVERLAY")
    barFrame.labelText:SetPoint("LEFT", barFrame, "LEFT", 4, 0)
    
    barFrame.timerText = barFrame:CreateFontString(nil, "OVERLAY")
    barFrame.timerText:SetPoint("RIGHT", barFrame, "RIGHT", -4, 0)

    E:CreateMover(barFrame, "ElvUI_QoL_BLBarMover", "QoL Bloodlust ProgressBar", nil, nil, nil, "ALL,SOLO")

    -- Events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_ENTERING_WORLD" then
            lastExhaustionExpiration = 0
            C_Timer.After(5, function() isReady = true end)
        elseif event == "UNIT_AURA" and unit == "player" then
            C_Timer.After(0.05, OnAuraUpdate)
        end
    end)

    self:UpdateLayout()
end

function BloodlustAlert:UpdateLayout()
    if not iconFrame or not barFrame then return end

    if config.enabled then
        if E.EnableMover then
            E:EnableMover("ElvUI_QoL_BLIconMover")
            E:EnableMover("ElvUI_QoL_BLBarMover")
        end

        -- Update Icon Configuration
        iconFrame:SetSize(config.iconSize, config.iconSize)
        local displayTex = config.iconTexture
        if config.spellID and config.spellID ~= "" then
            local spellIcon = C_Spell.GetSpellTexture(config.spellID)
            if spellIcon then displayTex = spellIcon end
        end
        iconFrame.tex:SetTexture(displayTex)

        local edgeTex = config.showBorder and config.borderTexture and config.borderTexture ~= "None" and E.Libs.LSM:Fetch("border", config.borderTexture) or nil
        if edgeTex then
            local pad, edgeSize = config.borderPadding or 0, config.borderSize or 1
            iconFrame.border:ClearAllPoints()
            iconFrame.border:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -pad, pad)
            iconFrame.border:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", pad, -pad)
            iconFrame.border:SetBackdrop({ edgeFile = edgeTex, edgeSize = edgeSize })
            iconFrame.border:SetBackdropBorderColor(config.borderColor.r, config.borderColor.g, config.borderColor.b, config.borderColor.a)
            iconFrame.border:Show()
        else
            iconFrame.border:Hide()
        end

        local iconFont = E.Libs.LSM:Fetch("font", config.iconFont)
        iconFrame.timerText:FontTemplate(iconFont, config.iconFontSize, config.iconFontOutline)
        iconFrame.CD:SetHideCountdownNumbers(not config.useNativeCD)
        iconFrame.timerText:SetShown(not config.useNativeCD)
        iconFrame.CD:SetReverse(config.reverseCD)

        -- Update ProgressBar Configuration
        barFrame:SetSize(config.barWidth, config.barHeight)
        local barTex = E.Libs.LSM:Fetch("statusbar", config.barTexture)
        barFrame:SetStatusBarTexture(barTex)
        barFrame:SetStatusBarColor(config.barColor.r, config.barColor.g, config.barColor.b, config.barColor.a)
        barFrame.bg:SetTexture(barTex)
        barFrame.bg:SetVertexColor(config.barBgColor.r, config.barBgColor.g, config.barBgColor.b, config.barBgColor.a)
        
        local barFont = E.Libs.LSM:Fetch("font", config.barFont)
        barFrame.labelText:FontTemplate(barFont, config.barFontSize, config.barFontOutline)
        barFrame.timerText:FontTemplate(barFont, config.barFontSize, config.barFontOutline)
        
        barFrame.labelText:SetText(config.barTextLabel or "")
    else
        StopEffect()
        if E.DisableMover then
            E:DisableMover("ElvUI_QoL_BLIconMover")
            E:DisableMover("ElvUI_QoL_BLBarMover")
        end
    end
end

function BloodlustAlert:InsertOptions()
    E.Options.args.ElvUI_QoL.args.bloodlustAlert = {
        order = 4,
        type = "group",
        name = "Bloodlust Alert",
        get = function(info) return E.db.BloodlustAlert[info[#info]] end,
        set = function(info, value) E.db.BloodlustAlert[info[#info]] = value; BloodlustAlert:UpdateLayout() end,
        args = {
            enabled = { order = 1, type = "toggle", name = "Enable Module" },
            spellID = { order = 2, type = "input", name = "Override Spell ID", desc = "Prioritize item/spell texture from a specific ID." },
            
            iconGroup = {
                order = 3, type = "group", guiInline = true, name = "Icon Mode Settings",
                args = {
                    enableIcon = { order = 1, type = "toggle", name = "Enable Icon" },
                    hideIcon = { order = 2, type = "toggle", name = "Hide Icon Graphic", desc = "Keep sound effects active but completely hide icon frame." },
                    useNativeCD = { order = 3, type = "toggle", name = "Use Blizzard Countdown" },
                    reverseCD = { order = 4, type = "toggle", name = "Reverse Cooldown Swipe" },
                    iconTexture = { order = 5, type = "input", name = "Default Texture Path/ID" },
                    iconSize = { order = 6, type = "range", name = "Icon Size", min = 15, max = 200, step = 1 },
                    
                    fontGroup = {
                        order = 7, type = "group", name = "Font Customization", guiInline = true,
                        args = {
                            iconFont = { order = 1, type = "select", dialogControl = "LSM30_Font", name = "Font Family", values = AceGUIWidgetLSMlists.font },
                            iconFontSize = { order = 2, type = "range", name = "Font Size", min = 10, max = 72, step = 1 },
                            iconFontOutline = { order = 3, type = "select", name = "Font Outline", values = { ["NONE"] = "None", ["OUTLINE"] = "OUTLINE", ["THICKOUTLINE"] = "THICKOUTLINE" } },
                        },
                    },
                    borderGroup = {
                        order = 8, type = "group", name = "Border Customization", guiInline = true,
                        args = {
                            showBorder = { order = 1, type = "toggle", name = "Show Border" },
                            borderTexture = { order = 2, type = "select", dialogControl = "LSM30_Border", name = "Border Style", values = AceGUIWidgetLSMlists.border },
                            borderSize = { order = 3, type = "range", name = "Border Width", min = 1, max = 10, step = 1 },
                            borderPadding = { order = 4, type = "range", name = "Border Padding", min = 0, max = 10, step = 1 },
                            borderColor = {
                                order = 5, type = "color", name = "Border Color", hasAlpha = true,
                                get = function(info) local c = E.db.BloodlustAlert.borderColor; return c.r, c.g, c.b, c.a end,
                                set = function(info, r, g, b, a) local c = E.db.BloodlustAlert.borderColor; c.r, c.g, c.b, c.a = r, g, b, a; BloodlustAlert:UpdateLayout() end,
                            },
                        },
                    },
                },
            },
            
            barGroup = {
                order = 4, type = "group", guiInline = true, name = "ProgressBar Mode Settings",
                args = {
                    enableBar = { order = 1, type = "toggle", name = "Enable ProgressBar" },
                    barTextLabel = { order = 2, type = "input", name = "Left Label Text" },
                    barWidth = { order = 3, type = "range", name = "Bar Width", min = 50, max = 500, step = 1 },
                    barHeight = { order = 4, type = "range", name = "Bar Height", min = 6, max = 50, step = 1 },
                    barTexture = { order = 5, type = "select", dialogControl = "LSM30_Statusbar", name = "Statusbar Texture", values = AceGUIWidgetLSMlists.statusbar },
                    barColor = {
                        order = 6, type = "color", name = "Main Bar Color",
                        get = function(info) local c = E.db.BloodlustAlert.barColor; return c.r, c.g, c.b end,
                        set = function(info, r, g, b) local c = E.db.BloodlustAlert.barColor; c.r, c.g, c.b = r, g, b; BloodlustAlert:UpdateLayout() end,
                    },
                    barBgColor = {
                        order = 7, type = "color", name = "Background Color", hasAlpha = true,
                        get = function(info) local c = E.db.BloodlustAlert.barBgColor; return c.r, c.g, c.b, c.a end,
                        set = function(info, r, g, b, a) local c = E.db.BloodlustAlert.barBgColor; c.r, c.g, c.b, c.a = r, g, b, a; BloodlustAlert:UpdateLayout() end,
                    },
                    barFont = { order = 8, type = "select", dialogControl = "LSM30_Font", name = "Font Family", values = AceGUIWidgetLSMlists.font },
                    barFontSize = { order = 9, type = "range", name = "Font Size", min = 8, max = 36, step = 1 },
                    barFontOutline = { order = 10, type = "select", name = "Font Outline", values = { ["NONE"] = "None", ["OUTLINE"] = "OUTLINE", ["THICKOUTLINE"] = "THICKOUTLINE" } },
                },
            },
            
            soundGroup = {
                order = 5, type = "group", guiInline = true, name = "Sound Effect Settings",
                args = {
                    sound = { order = 1, type = "select", dialogControl = "LSM30_Sound", name = "Built-in Sound", values = AceGUIWidgetLSMlists.sound },
                    soundChannel = {
                        order = 2, type = "select", name = "Output Channel",
                        values = { ["Master"] = "Master", ["SFX"] = "SFX", ["Ambience"] = "Ambience", ["Music"] = "Music", ["Dialog"] = "Dialog" },
                    },
                    useCustomSound = { order = 3, type = "toggle", name = "Use Custom Paths Below", width = "full" },
                    randomSound = { order = 4, type = "toggle", name = "Randomize Custom Playlist", disabled = function() return not E.db.BloodlustAlert.useCustomSound end },
                    
                    customSound1 = { order = 5, type = "input", width = "full", name = "Custom Sound Path (1)", get = function() return E.db.BloodlustAlert.customSounds[1] end, set = function(_, v) E.db.BloodlustAlert.customSounds[1] = v end, disabled = function() return not E.db.BloodlustAlert.useCustomSound end },
                    customSound2 = { order = 6, type = "input", width = "full", name = "Custom Sound Path (2)", get = function() return E.db.BloodlustAlert.customSounds[2] end, set = function(_, v) E.db.BloodlustAlert.customSounds[2] = v end, disabled = function() return not E.db.BloodlustAlert.useCustomSound end },
                    customSound3 = { order = 7, type = "input", width = "full", name = "Custom Sound Path (3)", get = function() return E.db.BloodlustAlert.customSounds[3] end, set = function(_, v) E.db.BloodlustAlert.customSounds[3] = v end, disabled = function() return not E.db.BloodlustAlert.useCustomSound end },
                },
            },
            
            testGroup = {
                order = 6, type = "group", guiInline = true, name = "Development & Testing",
                args = {
                    testBtn = {
                        order = 1, type = "execute", name = "Test Trigger",
                        func = function() PlayEffect() end,
                    },
                    stopBtn = {
                        order = 2, type = "execute", name = "Stop Test",
                        func = function() StopEffect() end,
                    },
                },
            },
        },
    }
end

function BloodlustAlert:Initialize()
    LoadConfig()
    self:CreateFrames()
end