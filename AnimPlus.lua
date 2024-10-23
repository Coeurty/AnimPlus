local currentVersion = "1.1.0"
local broadcastChannelName = "animplus_comm"
local versionPrefix = "APVersionCheck"

AnimPlus = LibStub("AceAddon-3.0"):NewAddon("AnimPlus", "AceConsole-3.0")
AnimPlusAceGUI = LibStub("AceGUI-3.0")
local AnimPlusEvent = LibStub("AceEvent-3.0")
local AnimPlusComm = LibStub("AceComm-3.0")

-- Return if version received is highter than current version
local function newVersionAvailable(current, received)
    local currentParts = { strsplit(".", current) }
    local receivedParts = { strsplit(".", received) }
    for i = 1, math.max(#currentParts, #receivedParts) do
        local currentNum = tonumber(currentParts[i]) or 0
        local receivedNum = tonumber(receivedParts[i]) or 0
        if receivedNum > currentNum then
            return true
        elseif receivedNum < currentNum then
            return false
        end
    end
    return false
end

local function SendVersion()
    AnimPlusComm:SendCommMessage(versionPrefix, currentVersion, "CHANNEL", tostring(GetChannelName(broadcastChannelName)))
end

local newVersionNotified = false
local function OnCommReceived(prefix, message, distribution, sender)
    if prefix == versionPrefix and newVersionAvailable(currentVersion, message) and not newVersionNotified then
        AnimPlus:Print("A new version is available : " .. message .. "")
        newVersionNotified = true
    end
end

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

    JoinChannelByName(broadcastChannelName)
    SendVersion()
    AnimPlusComm:RegisterComm(versionPrefix, OnCommReceived)

    self:RegisterChatCommand("animplus", "HandleChatCommand")
    self:RegisterChatCommand("ap", "HandleChatCommand")
    self:Print("Version " .. currentVersion)
    self:Print(
        "'/ap', '/ap edit' or minimap button to open me.\nKey binds are in the 'other' section, or you can use the slash format: '/ap cmd CommandName' (no spaces, each word first letter capitalized).")

    AnimPlusEvent:RegisterEvent("GROUP_JOINED", SendVersion)
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
