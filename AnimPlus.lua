AnimPlus = LibStub("AceAddon-3.0"):NewAddon("AnimPlus", "AceConsole-3.0")
AnimPlusAceGUI = LibStub("AceGUI-3.0")
local AnimPlusEvent = LibStub("AceEvent-3.0")

local function CreateAnimPlusMinimapBtn(db)
    local function OnBrokerTooltipShow(tt)
        tt:AddLine("AnimPlus")
        tt:AddLine("Left-click: |cffffffffto toggle animation window.|r")
        tt:AddLine("Right-click: |cffffffffto toggle collection window.|r")
        tt:AddLine("Middle-click: |cffffffffto open options.|r")
    end

    local ApMinimapBtnDataObj = LibStub("LibDataBroker-1.1"):NewDataObject("AnimPlus", {
        type = "data source",
        icon = "Interface\\Icons\\ability_rogue_sprint",
        OnTooltipShow = OnBrokerTooltipShow,
        OnClick = function(self, button)
            if button == "RightButton" then
                ToggleApCollectionsWindow()
            elseif button == "MiddleButton" then
                ToggleApInterfaceOptionsCategory()
            else
                ToggleApAnimationWindow()
            end
        end,
    })

    LibStub("LibDBIcon-1.0"):Register("AnimPlus", ApMinimapBtnDataObj, db)
end

local function OnPlayerTargetChanged()
    RefreshApAnimationWindow()
end

-- Epsilon.utils.server.receive("DSPLY", function(message, channel, sender)
--     local records = { string.split(Epsilon.record, message) }
--     for _, record in pairs(records) do
--         local displayid = string.split(Epsilon.field, record)
--         if displayid ~= "" then
--             print(displayid)
--             local cmd = ".morph " .. displayid
--             print(cmd)
--             SendCmd(cmd)
--             -- targetMorphtext:SetText("Display: " .. tostring(displayid));
--             -- --print(targetMorphtext:GetText())
--         end
--     end
-- end)

function AnimPlus:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("AnimPLusDB", {
        profile = {
            minimap = {
                hide = false,
            },
        },
    })

    CreateAnimPlusInterfaceOptionsCategory()

    CreateAnimPlusMinimapBtn(self.db.profile.minimap)

    self:RegisterChatCommand("animplus", "HandleChatCommand")
    self:RegisterChatCommand("ap", "HandleChatCommand")
    self:Print(
        "'/ap', '/ap edit' or minimap button to open me.\nKey binds are in the 'other' section, or you can use the slash format: '/ap cmd CommandName' (no spaces, each word first letter capitalized).")
    AnimPlusEvent:RegisterEvent("PLAYER_TARGET_CHANGED", OnPlayerTargetChanged)
end

function AnimPlus:OnEnable() end

function AnimPlus:OnDisable() end

function AnimPlus:HandleChatCommand(text)
    local args = {}
    for word in string.gmatch(text, "%S+") do
        table.insert(args, word)
    end

    if args[1] == "edit" then
        ToggleApCollectionsWindow()
    elseif args[1] == "cmd" and args[2] then
        local commandFunc = ApAnimCommands[args[2]]
        if commandFunc then
            commandFunc()
        else
            print("Unknown command: " .. (args[2] or ""))
        end
        -- elseif args[1] == "t" then
        --     TestWindow()
    else
        ToggleApAnimationWindow()
    end
end

function SendCmd(cmd)
    SendChatMessage(cmd, "SAY")
end

function PlayerHasTarget()
    return not not UnitName("target")
end

function GetTargetType()
    if PlayerHasTarget() then
        if UnitIsPlayer("target") then
            return "player"
        else
            return "npc"
        end
    else
        return nil
    end
end

function TargetIsPlayer()
    if GetTargetType() == "player" then
        if UnitName("target") == UnitName("player") then
            return true
        end
    end
    return false
end

function ReverseTable(tab)
    local reversed = {}
    for i = #tab, 1, -1 do
        table.insert(reversed, tab[i])
    end
    return reversed
end

function IsStringInObjectValues(string, object)
    for _, value in pairs(object) do
        if type(value) == "string" and string.find(value:lower(), string:lower()) then
            return true
        end
    end
    return false
end

function GetUnitAuras(unitToken)
    local aurasOnUnit = {}
    local filters = { "HELPFUL", "HARMFUL", "NOT_CANCELABLE" }
    for _, filter in ipairs(filters) do
        for i = 1, 40 do
            ---@diagnostic disable-next-line: deprecated
            local name, _, _, _, _, _, _, _, _, spellId = UnitAura(unitToken, i, filter)
            if not spellId then
                break
            end
            table.insert(aurasOnUnit, { name = name, value = spellId })
        end
    end
    return aurasOnUnit
end

function TargetHasAura(auraId, unitsAuras)
    for _, aura in ipairs(unitsAuras) do
        if not aura.value then
            break
        end
        if aura.value == auraId then
            return true
        end
    end
    return false
end

function CreateDividerWidget(text)
    local divider = nil
    if text then
        divider = AnimPlusAceGUI:Create("Heading")
        divider:SetText(text)
    else
        divider = AnimPlusAceGUI:Create("Label")
        divider:SetText(" ")
    end
    divider:SetFullWidth(true)
    return divider
end

function CreateSpace(size)
    local element = AnimPlusAceGUI:Create("Label")
    element:SetText(" ")
    element:SetWidth(size)
    return element
end

-- function TestWindow()
--     local fakeSpells = {
--         { icon = "ability_warrior_challange", label = "label1", spellId = 280292 },
--         { icon = "ability_warrior_challange", label = "label2", spellId = 300000 },
--     }
--     local window = AnimPlusAceGUI:Create("Window")
--     window:SetTitle("AnimPlus - Test")
--     -- window:SetHeight(370)
--     -- window:SetWidth(300)
--     -- window:EnableResize(true)
--     for _, o in ipairs(fakeSpells) do
--         local iconW = AnimPlusAceGUI:Create("Icon")
--         iconW:SetImage("Interface\\Icons\\" .. o.icon)
--         iconW:SetLabel(o.label)
--         iconW:SetImageSize(36, 36)
--         iconW:SetWidth(36, 36)
--         iconW:SetCallback("OnClick", function(widget, event, button)
--             print(button)
--             if button == "RightButton" then
--                 print("Right click on spell:", o.spellId)
--             else
--                 print("Left click on spell:", o.spellId)
--             end
--         end)
--         window:AddChild(iconW)
--     end
-- end
