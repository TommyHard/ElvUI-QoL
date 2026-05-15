local E, L, V, P, G = unpack(ElvUI)
if not E then return end

local addonName = "ElvUI_QoL"
local QoL = E:GetModule(addonName)

local Crosshair = {}
QoL.Modules.Crosshair = Crosshair

local PI = math.pi
local sin, cos = math.sin, math.cos
local TEXEL_HALF = 0.5 / 512
local CIRCLE_TEXTURE = [[Interface\AddOns\ElvUI_QoL\Media\Textures\Ring.tga]]

local DEFAULT_MELEE_SPELLS = {
    DEATHKNIGHT = { 49998, 49998, 49998 },
    DEMONHUNTER = { 162794, 344859 },
    DRUID = { nil, 5221, 33917, nil },
    HUNTER = { nil, nil, 186270 },
    MONK = { 205523, 205523, 205523 },
    PALADIN = { nil, 96231, 96231 },
    ROGUE = { 1752, 1752, 1752 },
    SHAMAN = { nil, 73899, nil },
    WARRIOR = { 6552, 6552, 6552 },
}

local ARM_DEFS = {
    { key = "showTop",    base = 0        },
    { key = "showRight",  base = PI / 2   },
    { key = "showBottom", base = PI       },
    { key = "showLeft",   base = 3*PI / 2 },
}

local HPAL_ITEM_ID = 129055

local config
local cachedMeleeSpellId = nil
local meleeCheckSupported = false
local hpalEnabled = false
local inCombat, isMounted, isOutOfMelee = false, false, false
local lastInRange = nil
local meleeSoundTicker = nil
local lastMeleeSoundTime = 0

-- Frame's
local crosshairFrame
local arms, shadows = {}, {}
local dot, dotShadow, circleRing, circleShadow
local tickFrame = CreateFrame("Frame")
local hpalTickFrame = CreateFrame("Frame")

-- Utilities
local function GetSpecIndex() return GetSpecialization() or 0 end
local function GetClassName() return select(2, UnitClass("player")) end

local function GetCurrentMeleeSpell()
    local classFile = GetClassName()
    local specIndex = GetSpecIndex()
    if not classFile or specIndex == 0 then return nil end
    local classSpells = DEFAULT_MELEE_SPELLS[classFile]
    return classSpells and classSpells[specIndex]
end

local function CacheMeleeSpell()
    if hpalEnabled then return end
    cachedMeleeSpellId = GetCurrentMeleeSpell()
    meleeCheckSupported = (cachedMeleeSpellId ~= nil)
end

local function HasAttackableTarget()
    if not UnitExists("target") then return false end
    if not UnitCanAttack("player", "target") then return false end
    if UnitIsDeadOrGhost("target") then return false end
    return true
end

local function GetColor(r, g, b, useClass)
    if useClass then
        local color = E:ClassColor(E.myclass, true)
        if color then return color.r, color.g, color.b end
    end
    return r, g, b
end

-- Default Settings
local function LoadConfig()
    if not E.db.QoL then E.db.QoL = {} end
    if not E.db.QoL.crosshair then E.db.QoL.crosshair = {} end
    
    local defaults = {
        enabled = true, combatOnly = true, hideWhileMounted = true,
        size = 20, thickness = 2, gap = 6, opacity = 0.8,
        offsetX = 0, offsetY = 0,
        
        showTop = true, showRight = true, showBottom = true, showLeft = true,
        
        useClassColor = false, color = { r = 1, g = 1, b = 1 },
        
        outlineEnabled = false, outlineWeight = 1, 
        outlineUseClassColor = false, outlineColor = { r = 0, g = 0, b = 0 },
        
        dotEnabled = true, dotSize = 2,
        circleEnabled = false, circleSize = 30, 
        circleUseClassColor = false, circleColor = { r = 1, g = 1, b = 1 },

        meleeRecolor = true, meleeOutUseClassColor = false, meleeOutColor = { r = 1, g = 0, b = 0 },
        meleeRecolorBorder = true, meleeRecolorArms = true, meleeRecolorDot = true, meleeRecolorCircle = true,
        
        meleeSoundEnabled = false, meleeSoundInterval = 3, meleeSoundID = 8959,
    }

    for key, value in pairs(defaults) do
        if E.db.QoL.crosshair[key] == nil then
            if type(value) == "table" then
                E.db.QoL.crosshair[key] = {}
                for subKey, subValue in pairs(value) do
                    E.db.QoL.crosshair[key][subKey] = subValue
                end
            else
                E.db.QoL.crosshair[key] = value
            end
        end
    end

    config = E.db.QoL.crosshair
end

local function CreateCrosshairFrame()
    crosshairFrame = CreateFrame("Frame", "ElvUI_QoL_Crosshair", UIParent)
    crosshairFrame:SetFrameStrata("HIGH")
    crosshairFrame:SetFrameLevel(50)
    crosshairFrame:EnableMouse(false)
    crosshairFrame:Hide()

    for i, def in ipairs(ARM_DEFS) do
        local s = crosshairFrame:CreateTexture(nil, "ARTWORK", nil, 0)
        s:SetTexture(E.media.blankTex)
        shadows[i] = s

        local t = crosshairFrame:CreateTexture(nil, "ARTWORK", nil, 1)
        t:SetTexture(E.media.blankTex)
        arms[i] = t
    end

    dotShadow = crosshairFrame:CreateTexture(nil, "ARTWORK", nil, 0)
    dotShadow:SetTexture(E.media.blankTex)
    dot = crosshairFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    dot:SetTexture(E.media.blankTex)

    circleShadow = crosshairFrame:CreateTexture(nil, "ARTWORK", nil, 0)
    circleShadow:SetTexture(CIRCLE_TEXTURE, "CLAMP", "CLAMP", "TRILINEAR")
    circleShadow:SetTexCoord(TEXEL_HALF, 1 - TEXEL_HALF, TEXEL_HALF, 1 - TEXEL_HALF)

    circleRing = crosshairFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    circleRing:SetTexture(CIRCLE_TEXTURE, "CLAMP", "CLAMP", "TRILINEAR")
    circleRing:SetTexCoord(TEXEL_HALF, 1 - TEXEL_HALF, TEXEL_HALF, 1 - TEXEL_HALF)
end

function Crosshair:ApplyLayout()
    if not config or not crosshairFrame then return end

    local size, thick, gap, alpha = config.size, config.thickness, config.gap, config.opacity
    local r1, g1, b1 = GetColor(config.color.r, config.color.g, config.color.b, config.useClassColor)
    local outline = config.outlineEnabled
    local ow = config.outlineWeight
    local olR, olG, olB = GetColor(config.outlineColor.r, config.outlineColor.g, config.outlineColor.b, config.outlineUseClassColor)

    local meleeOut = config.meleeRecolor and isOutOfMelee
    local moR, moG, moB = GetColor(config.meleeOutColor.r, config.meleeOutColor.g, config.meleeOutColor.b, config.meleeOutUseClassColor)

    if meleeOut and config.meleeRecolorBorder ~= false then
        outline = true
        olR, olG, olB = moR, moG, moB
    end

    local span = (gap + size) + (outline and ow or 0) + 2
    crosshairFrame:SetSize(span * 2, span * 2)
    crosshairFrame:ClearAllPoints()
    
    local uiScale = UIParent:GetEffectiveScale()
    local snappedOx = math.floor(config.offsetX * uiScale + 0.5) / uiScale
    local snappedOy = math.floor(config.offsetY * uiScale + 0.5) / uiScale
    crosshairFrame:SetPoint("CENTER", UIParent, "CENTER", snappedOx, snappedOy)

    local cx, cy = span, span

    for i, def in ipairs(ARM_DEFS) do
        local arm, shd = arms[i], shadows[i]
        local visible = config[def.key] ~= false

        if visible then
            local cr, cg, cb = r1, g1, b1
            if meleeOut and config.meleeRecolorArms then cr, cg, cb = moR, moG, moB end

            local dist = gap + size / 2
            local ax, ay = cx + dist * sin(def.base), cy + dist * cos(def.base)

            arm:SetSize(thick, size)
            arm:ClearAllPoints()
            arm:SetPoint("CENTER", crosshairFrame, "BOTTOMLEFT", ax, ay)
            arm:SetRotation(-def.base)
            arm:SetVertexColor(cr, cg, cb, alpha)
            arm:Show()

            if outline then
                shd:SetSize(thick + ow * 2, size + ow * 2)
                shd:ClearAllPoints()
                shd:SetPoint("CENTER", crosshairFrame, "BOTTOMLEFT", ax, ay)
                shd:SetRotation(-def.base)
                shd:SetVertexColor(olR, olG, olB, alpha)
                shd:Show()
            else shd:Hide() end
        else
            arm:Hide(); shd:Hide()
        end
    end

    if config.dotEnabled then
        local ds = config.dotSize
        dot:SetSize(ds, ds)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", crosshairFrame, "BOTTOMLEFT", cx, cy)
        local dotR, dotG, dotB = r1, g1, b1
        if meleeOut and config.meleeRecolorDot then dotR, dotG, dotB = moR, moG, moB end
        dot:SetVertexColor(dotR, dotG, dotB, alpha)
        dot:Show()

        if outline then
            dotShadow:SetSize(ds + ow * 2, ds + ow * 2)
            dotShadow:ClearAllPoints()
            dotShadow:SetPoint("CENTER", dot, "CENTER", 0, 0)
            dotShadow:SetVertexColor(olR, olG, olB, alpha)
            dotShadow:Show()
        else dotShadow:Hide() end
    else dot:Hide(); dotShadow:Hide() end

    if config.circleEnabled then
        local cs = config.circleSize
        circleRing:SetSize(cs, cs)
        circleRing:ClearAllPoints()
        circleRing:SetPoint("CENTER", crosshairFrame, "BOTTOMLEFT", cx, cy)
        local cR, cG, cB = GetColor(config.circleColor.r, config.circleColor.g, config.circleColor.b, config.circleUseClassColor)
        if meleeOut and config.meleeRecolorCircle then cR, cG, cB = moR, moG, moB end
        circleRing:SetVertexColor(cR, cG, cB, alpha)
        circleRing:Show()

        if outline then
            circleShadow:SetSize(cs + ow * 2, cs + ow * 2)
            circleShadow:ClearAllPoints()
            circleShadow:SetPoint("CENTER", circleRing, "CENTER", 0, 0)
            circleShadow:SetVertexColor(olR, olG, olB, alpha)
            circleShadow:Show()
        else circleShadow:Hide() end
    else circleRing:Hide(); circleShadow:Hide() end
end

function Crosshair:RefreshVisibility()
    if not config or not config.enabled then crosshairFrame:Hide(); return end
    if config.combatOnly and not inCombat then crosshairFrame:Hide(); return end
    if config.hideWhileMounted and isMounted then crosshairFrame:Hide(); return end
    crosshairFrame:Show()
end

-- Sounds
local function StopMeleeSound()
    if meleeSoundTicker then meleeSoundTicker:Cancel(); meleeSoundTicker = nil end
end

local function PlayMeleeSoundOnce(soundID)
    local now = GetTime()
    if now - lastMeleeSoundTime < 0.9 then return end
    lastMeleeSoundTime = now
    PlaySound(soundID or 8959, "Master")
end

local function StartMeleeSound()
    StopMeleeSound()
    local interval = config.meleeSoundInterval
    PlayMeleeSoundOnce(config.meleeSoundID)
    if interval > 0 then
        meleeSoundTicker = C_Timer.NewTicker(interval, function() PlayMeleeSoundOnce(config.meleeSoundID) end)
    end
end

local TICK_RATE = 0.05
local tickAcc, hpalTickAcc = 0, 0

local function ProcessRangeState(inMelee)
    local wasOut = isOutOfMelee
    isOutOfMelee = not inMelee

    if isOutOfMelee then
        if config.meleeSoundEnabled and lastInRange == true then StartMeleeSound() end
    else
        StopMeleeSound()
    end
    lastInRange = inMelee

    if isOutOfMelee ~= wasOut then Crosshair:ApplyLayout() end
end

tickFrame:SetScript("OnUpdate", function(self, elapsed)
    tickAcc = tickAcc + elapsed
    if tickAcc < TICK_RATE then return end
    tickAcc = 0

    if not config.meleeRecolor or not meleeCheckSupported then
        if isOutOfMelee then isOutOfMelee = false; Crosshair:ApplyLayout() end
        StopMeleeSound(); lastInRange = nil; return
    end

    if not HasAttackableTarget() then
        isOutOfMelee = false; StopMeleeSound(); lastInRange = nil
    else
        local inMelee = C_Spell.IsSpellInRange(cachedMeleeSpellId, "target")
        if inMelee ~= nil then ProcessRangeState(inMelee) end
    end
end)

hpalTickFrame:SetScript("OnUpdate", function(self, elapsed)
    hpalTickAcc = hpalTickAcc + elapsed
    if hpalTickAcc < TICK_RATE then return end
    hpalTickAcc = 0

    if not config.meleeRecolor then return end
    if not HasAttackableTarget() then
        isOutOfMelee = false; StopMeleeSound(); lastInRange = nil
    else
        local inMelee = C_Item.IsItemInRange(HPAL_ITEM_ID, "target")
        if inMelee ~= nil then ProcessRangeState(inMelee) end
    end
end)

local function EvaluateHpalMode()
    local isHPal = (GetClassName() == "PALADIN" and GetSpecIndex() == 1)
    if isHPal and config and config.enabled and config.meleeRecolor then
        hpalEnabled = true; meleeCheckSupported = true
        tickFrame:Hide(); hpalTickFrame:Show()
    else
        hpalEnabled = false; hpalTickFrame:Hide()
        if config and config.enabled and config.meleeRecolor and meleeCheckSupported then tickFrame:Show() else tickFrame:Hide() end
    end
end

-- Ace3
function Crosshair:InsertOptions()
    local function get(info) return config[info[#info]] end
    local function set(info, value) config[info[#info]] = value; Crosshair:ApplyLayout() end
    local function getColor(info) local c = config[info[#info]]; return c.r, c.g, c.b end
    local function setColor(info, r, g, b) config[info[#info]] = {r=r, g=g, b=b}; Crosshair:ApplyLayout() end

    E.Options.args.ElvUI_QoL.args.crosshair = {
        order = 2, type = "group", name = "Crosshair", childGroups = "tab",
        args = {
            general = {
                order = 1, type = "group", name = "General",
                args = {
                    enabled = { order = 1, type = "toggle", name = L["Enable"], get = get, set = function(i, v) config.enabled = v; Crosshair:RefreshVisibility(); EvaluateHpalMode() end },
                    combatOnly = { order = 2, type = "toggle", name = "Combat Only", get = get, set = function(i, v) config.combatOnly = v; Crosshair:RefreshVisibility() end },
                    hideWhileMounted = { order = 3, type = "toggle", name = "Hide While Mounted", get = get, set = function(i, v) config.hideWhileMounted = v; Crosshair:RefreshVisibility() end },
                    offsetX = { order = 4, type = "range", name = "X Offset", min = -500, max = 500, step = 1, get = get, set = set },
                    offsetY = { order = 5, type = "range", name = "Y Offset", min = -500, max = 500, step = 1, get = get, set = set },
                }
            },
            appearance = {
                order = 2, type = "group", name = "Appearance",
                args = {
                    size = { order = 1, type = "range", name = "Size", min = 5, max = 100, step = 1, get = get, set = set },
                    thickness = { order = 2, type = "range", name = "Thickness", min = 1, max = 10, step = 1, get = get, set = set },
                    gap = { order = 3, type = "range", name = "Gap", min = 0, max = 50, step = 1, get = get, set = set },
                    opacity = { order = 4, type = "range", name = "Opacity", min = 0, max = 1, step = 0.05, get = get, set = set },
                    useClassColor = { order = 5, type = "toggle", name = "Use Class Color", get = get, set = set },
                    color = { order = 6, type = "color", name = "Color", get = getColor, set = setColor, disabled = function() return config.useClassColor end },
                    showTop = { order = 7, type = "toggle", name = "Show Top", get = get, set = set },
                    showBottom = { order = 8, type = "toggle", name = "Show Bottom", get = get, set = set },
                    showLeft = { order = 9, type = "toggle", name = "Show Left", get = get, set = set },
                    showRight = { order = 10, type = "toggle", name = "Show Right", get = get, set = set },
                }
            },
            outline = {
                order = 3, type = "group", name = "Outline",
                args = {
                    outlineEnabled = { order = 1, type = "toggle", name = "Enable Outline", get = get, set = set },
                    outlineWeight = { order = 2, type = "range", name = "Thickness", min = 1, max = 5, step = 1, get = get, set = set },
                    outlineUseClassColor = { order = 3, type = "toggle", name = "Use Class Color", get = get, set = set },
                    outlineColor = { order = 4, type = "color", name = "Color", get = getColor, set = setColor, disabled = function() return config.outlineUseClassColor end },
                }
            },
            shapes = {
                order = 4, type = "group", name = "Dot & Circle",
                args = {
                    dotEnabled = { order = 1, type = "toggle", name = "Enable Dot", get = get, set = set },
                    dotSize = { order = 2, type = "range", name = "Dot Size", min = 1, max = 20, step = 1, get = get, set = set },
                    circleEnabled = { order = 3, type = "toggle", name = "Enable Circle", get = get, set = set },
                    circleSize = { order = 4, type = "range", name = "Circle Size", min = 10, max = 150, step = 1, get = get, set = set },
                    circleUseClassColor = { order = 5, type = "toggle", name = "Circle Class Color", get = get, set = set },
                    circleColor = { order = 6, type = "color", name = "Circle Color", get = getColor, set = setColor, disabled = function() return config.circleUseClassColor end },
                }
            },
            melee = {
                order = 5, type = "group", name = "Melee Range",
                args = {
                    meleeRecolor = { order = 1, type = "toggle", name = "Recolor Out of Melee", get = get, set = function(i,v) config.meleeRecolor=v; EvaluateHpalMode(); Crosshair:ApplyLayout() end },
                    meleeOutUseClassColor = { order = 2, type = "toggle", name = "Use Class Color", get = get, set = set },
                    meleeOutColor = { order = 3, type = "color", name = "Out of Melee Color", get = getColor, set = setColor, disabled = function() return config.meleeOutUseClassColor end },
                    recolorGroup = {
                        order = 4, type = "group", name = "Recolor Elements", guiInline = true,
                        args = {
                            meleeRecolorArms = { order = 1, type = "toggle", name = "Arms", get = get, set = set },
                            meleeRecolorDot = { order = 2, type = "toggle", name = "Dot", get = get, set = set },
                            meleeRecolorCircle = { order = 3, type = "toggle", name = "Circle", get = get, set = set },
                            meleeRecolorBorder = { order = 4, type = "toggle", name = "Border", get = get, set = set },
                        }
                    },
                    soundGroup = {
                        order = 5, type = "group", name = "Sound", guiInline = true,
                        args = {
                            meleeSoundEnabled = { order = 1, type = "toggle", name = "Enable Sound", get = get, set = set },
                            meleeSoundID = { order = 2, type = "input", name = "Sound ID (e.g. 8959)", get = function() return tostring(config.meleeSoundID) end, set = function(i,v) config.meleeSoundID = tonumber(v) or 8959 end },
                            meleeSoundInterval = { order = 3, type = "range", name = "Interval (sec)", min = 0, max = 10, step = 0.5, get = get, set = set },
                        }
                    }
                }
            }
        }
    }
end

-- События
local function EventHandler(self, event)
    if event == "PLAYER_LOGIN" then
        isMounted = IsMounted()
        CacheMeleeSpell()
        EvaluateHpalMode()
        Crosshair:ApplyLayout()
        Crosshair:RefreshVisibility()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true; Crosshair:RefreshVisibility()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false; Crosshair:RefreshVisibility()
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        isMounted = IsMounted(); Crosshair:RefreshVisibility()
    elseif event == "PLAYER_TARGET_CHANGED" then
        isOutOfMelee = false; lastInRange = nil
        StopMeleeSound()
        Crosshair:ApplyLayout()
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        CacheMeleeSpell(); EvaluateHpalMode()
    elseif event == "PLAYER_LEAVING_WORLD" then
        StopMeleeSound()
    end
end

function Crosshair:Initialize()
    LoadConfig()
    CreateCrosshairFrame()

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:RegisterEvent("PLAYER_REGEN_DISABLED")
    loader:RegisterEvent("PLAYER_REGEN_ENABLED")
    loader:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    loader:RegisterEvent("PLAYER_TARGET_CHANGED")
    loader:RegisterEvent("PLAYER_ENTERING_WORLD")
    loader:RegisterEvent("PLAYER_LEAVING_WORLD")
    loader:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    loader:SetScript("OnEvent", EventHandler)
end