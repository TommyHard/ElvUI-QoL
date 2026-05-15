local E, L, V, P, G = unpack(ElvUI)
if not E then return end

local addonName = ...
local EP = LibStub("LibElvUIPlugin-1.0")

local QoL = E:NewModule(addonName, "AceHook-3.0", "AceEvent-3.0")
QoL.Modules = {}

function QoL:InsertOptions()
    local menuName = "|TInterface\\AddOns\\ElvUI_QoL\\Media\\Icons\\QoLMini:16:16|t |cff8a2be2E|r|cff6275dbl|r|cff3c9fd6v|r|cff35b9d8U|r|cff48c4dbI|r |cff5ccfdfQ|r|cff70dae2o|r|cff84e5e6L|r"

    E.Options.args.ElvUI_QoL = {
        order = 100,
        type = "group",
        name = menuName,
        childGroups = "tab",
        args = {}
    }

    for _, module in pairs(self.Modules) do
        if module.InsertOptions then
            module:InsertOptions()
        end
    end
end

function QoL:Initialize()
    for _, module in pairs(self.Modules) do
        if module.Initialize then
            module:Initialize()
        end
    end
    
    EP:RegisterPlugin(addonName, function() QoL:InsertOptions() end)
end

local function InitializeCallback()
    QoL:Initialize()
end
E:RegisterModule(QoL:GetName(), InitializeCallback)