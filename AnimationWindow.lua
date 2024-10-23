ApAnimationWindow = nil

local ApAnimationWindowTabGroup = nil
local ApAnimationWindowSelectedTab = nil

local auraFilterInputValue = ""
local emoteFilterInputValue = ""

local lastAuraApplied = nil

-- TODO: refacto & move to AnimPlus.lua
function SaveApAnimationWindowPosition()
    local position = {
        x = ApAnimationWindow.frame:GetLeft(),
        y = ApAnimationWindow.frame:GetBottom()
    }
    AnimPlus.db.char.windowLastPosition = {
        x = position.x,
        y = position.y
    }
end

local function HandleToggleTargetAura(spell, select, phaseForgeNpc)
    local spellId = tonumber(spell.value)
    local spellCast = spell.cast
    if not spellId then
        return
    end

    local targetType = GetTargetType()
    local unitToken = "target"
    if not targetType or TargetIsPlayer() then
        unitToken = "player"
    end

    local unitsAuras = GetUnitAuras(unitToken)
    local targetHasAura = TargetHasAura(spellId, unitsAuras)
    if not targetType or targetType == "player" then
        if targetHasAura then
            SendCmd(".unaura " .. spellId)
        else
            if spellCast then
                SendCmd(".cast " .. spellId .. " tr")
            else
                SendCmd(".aura " .. spellId)
            end
        end
    else
        if targetHasAura then
            if phaseForgeNpc then
                SendCmd(".phase forge npc unaura " .. spellId)
            else
                SendCmd(".npc set unaura " .. spellId)
            end
        else
            if phaseForgeNpc then
                SendCmd(".phase forge npc aura " .. spellId)
            else
                if spellCast then
                    SendCmd(".npc cast " .. spellId)
                else
                    SendCmd(".npc set aura " .. spellId)
                end
            end
        end
    end
    if select then
        select:SetValue(nil)
        C_Timer.After(0.25, function()
            RefreshAuraSelectOptions(select)
        end)
    end
end

local function HandleGroupOrPhaseAura(spell, target, apply, auraSelect)
    auraSelect:SetValue(nil)
    local spellId = tonumber(spell.value)
    if not spellId then
        return
    end
    if target == "group" then
        if apply then
            SendCmd(".group aura " .. spellId)
        else
            SendCmd(".group unaura " .. spellId)
        end
    elseif target == "phase" then
        if apply then
            SendCmd(".phase aura " .. spellId)
        else
            SendCmd(".phase unaura " .. spellId)
        end
    end
    C_Timer.After(0.25, function()
        RefreshAuraSelectOptions(auraSelect)
    end)
end

function RefreshAuraSelectOptions(select)
    local targetType = GetTargetType()
    local unitToken = "target"
    if not targetType or TargetIsPlayer() then
        unitToken = "player"
    end
    select:SetList({})
    local optionCount = 0
    local unitsAuras = GetUnitAuras(unitToken)
    local bdAuras = AnimPlus.db.locale.auras
    if bdAuras then
        for _, o in ipairs(bdAuras) do
            if IsStringInObjectValues(auraFilterInputValue, o) then
                local optionText = o.value .. " - " .. o.name
                if TargetHasAura(tonumber(o.value), unitsAuras) then
                    optionText = "|cFF00FF00" .. optionText .. "|r"
                end
                select:AddItem(o, optionText)
                optionCount = optionCount + 1
            end
        end
        select:SetValue(nil)
        if optionCount == 0 then
            select:SetText("No auras found")
            select.text:SetTextColor(1, 1, 1)
        else
            select:SetText("Select an aura, " .. optionCount .. " found")
            select.text:SetTextColor(1, 1, 1)
        end
    else
        select:SetText("No auras found")
        select.text:SetTextColor(1, 1, 1)
    end
end

function CreateOrRefreshAuraTab(container)
    container:ReleaseChildren()
    local auraSelect = AnimPlusAceGUI:Create("Dropdown")
    auraSelect:SetFullWidth(true)
    RefreshAuraSelectOptions(auraSelect)

    local modeSelectLabel = AnimPlusAceGUI:Create("Label")
    modeSelectLabel:SetWidth(50)
    modeSelectLabel:SetText("    Mode:")
    local modeSelect = AnimPlusAceGUI:Create("Dropdown")
    local modeSelectOptions = {
        { name = "Toggle", value = "toggle" },
        { name = "Apply",  value = true },
        { name = "Remove", value = false },
    }
    for _, o in pairs(modeSelectOptions) do
        modeSelect:AddItem(o.value, o.name)
    end
    modeSelect:SetWidth(100)
    -- modeSelect:SetDisabled(true)

    local targetSelectLabel = AnimPlusAceGUI:Create("Label")
    targetSelectLabel:SetWidth(50)
    targetSelectLabel:SetText("    Target:")
    local targetSelect = AnimPlusAceGUI:Create("Dropdown")
    local targetSelectOptions = {
        { name = "Target", value = "target" },
        { name = "Group",  value = "group" },
        { name = "Phase",  value = "phase" },
    }
    for _, o in pairs(targetSelectOptions) do
        targetSelect:AddItem(o.value, o.name)
    end
    local function handleTargetSelectChange(widget, event, value)
        modeSelect:SetItemDisabled("toggle", false)
        modeSelect:SetItemDisabled(true, false)
        modeSelect:SetItemDisabled(false, false)
        local modeSelectValue = modeSelect:GetValue()
        -- modeSelect:SetDisabled(false)
        if value == "target" then
            modeSelect:SetValue("toggle")
            modeSelect:SetItemDisabled(true, true)
            modeSelect:SetItemDisabled(false, true)
            return
        else
            modeSelect:SetItemDisabled("toggle", true)
            if modeSelectValue == "toggle" then
                modeSelect:SetValue(true)
            end
        end
    end
    targetSelect:SetCallback("OnValueChanged", handleTargetSelectChange)
    targetSelect:SetWidth(80)
    targetSelect:SetValue("target")
    handleTargetSelectChange(_, _, targetSelect:GetValue())

    local phaseForgeNpcCheckbox = AnimPlusAceGUI:Create("CheckBox")
    phaseForgeNpcCheckbox:SetFullWidth(true)
    phaseForgeNpcCheckbox:SetLabel(" Phase forge (npc)")

    auraSelect:SetCallback("OnValueChanged", function(widget, event, spell)
        -- print("width", ApAnimationWindow.frame:GetWidth())
        -- print("height", ApAnimationWindow.frame:GetHeight())
        local targetSelectValue = targetSelect:GetValue()
        local modeSelectValue = modeSelect:GetValue()
        lastAuraApplied = spell
        if targetSelectValue == "target" then
            HandleToggleTargetAura(spell, auraSelect, phaseForgeNpcCheckbox:GetValue())
        elseif targetSelectValue == "group" or targetSelectValue == "phase" then
            HandleGroupOrPhaseAura(spell, targetSelectValue, modeSelectValue, auraSelect)
        end
    end)

    local filterFieldLabel = AnimPlusAceGUI:Create("Label")
    filterFieldLabel:SetFullWidth(true)
    filterFieldLabel:SetText("Search auras by name, tags or id:")

    local filterFieldInput = AnimPlusAceGUI:Create("EditBox")
    filterFieldInput:SetText(auraFilterInputValue)
    filterFieldInput:DisableButton(true)
    filterFieldInput:SetCallback("OnTextChanged", function(widget, event, text)
        auraFilterInputValue = text
        RefreshAuraSelectOptions(auraSelect)
        if auraSelect.open then
            CustomAnimPlusLibsFunctions.Dropdown_TogglePullout(auraSelect)
            CustomAnimPlusLibsFunctions.Dropdown_TogglePullout(auraSelect)
        end
    end)
    filterFieldInput.editbox:SetScript("OnTabPressed", function(widget, event, text)
        CustomAnimPlusLibsFunctions.Dropdown_TogglePullout(auraSelect)
    end)
    filterFieldInput.editbox:SetScript("OnEscapePressed", function(widget, event, text)
        CustomAnimPlusLibsFunctions.Dropdown_Close(auraSelect)
    end)

    local clearFilterFieldButton = AnimPlusAceGUI:Create("Button")
    clearFilterFieldButton:SetText("Clear")
    clearFilterFieldButton:SetWidth(100)
    clearFilterFieldButton:SetCallback("OnClick", function()
        filterFieldInput:SetText("")
        auraFilterInputValue = ""
        RefreshAuraSelectOptions(auraSelect)
    end)

    local possessButton = AnimPlusAceGUI:Create("Button")
    possessButton:SetText("Toggle possess")
    possessButton:SetWidth(150)
    possessButton:SetCallback("OnClick", APTogglePossess)

    local unauraAllButton = AnimPlusAceGUI:Create("Button")
    unauraAllButton:SetText("Unaura all")
    unauraAllButton:SetWidth(150)
    unauraAllButton:SetCallback("OnClick", function()
        if GetTargetType() == "npc" then
            SendCmd(".npc set unaura all")
        else
            SendCmd(".unaura all")
        end
        C_Timer.After(0.25, function()
            RefreshAuraSelectOptions(auraSelect)
        end)
    end)

    local phaseDMButton = AnimPlusAceGUI:Create("Button")
    phaseDMButton:SetText("Toggle phase dm")
    phaseDMButton:SetWidth(150)
    phaseDMButton:SetCallback("OnClick", APTogglePhaseDM)

    container:AddChildren(targetSelectLabel, targetSelect, modeSelectLabel, modeSelect)
    if GetTargetType() == "npc" then
        container:AddChildren(phaseForgeNpcCheckbox)
    end
    container:AddChildren(filterFieldLabel, filterFieldInput, clearFilterFieldButton, auraSelect,
        possessButton, unauraAllButton, phaseDMButton)
end

local function HandleChangeEmote(emoteId, emoteSelect, npcRepeatEmote, playerEmoteAsStandstate)
    emoteId = tonumber(emoteId)
    if not emoteId then
        return
    end
    local targetType = GetTargetType()
    local cmd = ""
    if not targetType or targetType == "player" then
        if playerEmoteAsStandstate then
            cmd = ".modify standstate " .. emoteId
        else
            cmd = ".modify anim " .. emoteId
        end
    else
        cmd = ".npc emote " .. emoteId
        if npcRepeatEmote then
            cmd = cmd .. " repeat"
        end
    end
    SendCmd(cmd)
    RefreshEmoteSelectOptions(emoteSelect)
end

function RefreshEmoteSelectOptions(emoteSelect)
    emoteSelect:SetList({})
    local optionCount = 0
    local dbEmotes = AnimPlus.db.locale.emotes
    if dbEmotes then
        for _, o in ipairs(dbEmotes) do
            if IsStringInObjectValues(emoteFilterInputValue, o) then
                local optionText = o.value .. " - " .. o.name
                emoteSelect:AddItem(o.value, optionText)
                optionCount = optionCount + 1
            end
        end
        emoteSelect:SetValue(nil)
        if optionCount == 0 then
            emoteSelect:SetText("No emotes found")
        else
            emoteSelect:SetText("Select an emote, " .. optionCount .. " found")
        end
    else
        -- TODO
        emoteSelect:SetText("No emotes found")
    end
end

local function CreateOrRefreshEmoteTab(container)
    container:ReleaseChildren()
    local emoteSelect = AnimPlusAceGUI:Create("Dropdown")
    emoteSelect:SetFullWidth(true)
    RefreshEmoteSelectOptions(emoteSelect)

    local npcRepeatEmoteCheckbox = AnimPlusAceGUI:Create("CheckBox")
    npcRepeatEmoteCheckbox:SetFullWidth(true)
    npcRepeatEmoteCheckbox:SetLabel(" Repeat (npc)")

    local npcChangeSheathLabel = AnimPlusAceGUI:Create("Label")
    npcChangeSheathLabel:SetText("Npc's sheath state:")
    npcChangeSheathLabel:SetWidth(110)
    local npcChangeSheathDropdown = AnimPlusAceGUI:Create("Dropdown")
    local npcChangeSheathDropdownOptions = {
        { name = "0 - Sheathed", value = 0 },
        { name = "1 - Melee",    value = 1 },
        { name = "2 - Ranged",   value = 2 },
    }
    for _, o in pairs(npcChangeSheathDropdownOptions) do
        npcChangeSheathDropdown:AddItem(o.value, o.name)
    end
    npcChangeSheathDropdown:SetWidth(150)
    npcChangeSheathDropdown:SetText("Select a state")
    npcChangeSheathDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        SendCmd(".npc set sheath " .. value)
        npcChangeSheathDropdown:SetValue(nil)
        npcChangeSheathDropdown:SetText("Select a state")
    end)

    local playerEmoteAsStandstateCheckbox = AnimPlusAceGUI:Create("CheckBox")
    playerEmoteAsStandstateCheckbox:SetLabel(" Standstate (player)")
    playerEmoteAsStandstateCheckbox:SetDescription("Emote as 'standstate' instead as 'anim'")
    playerEmoteAsStandstateCheckbox:SetFullWidth(true)

    emoteSelect:SetCallback("OnValueChanged", function(widget, event, value)
        HandleChangeEmote(value, emoteSelect, npcRepeatEmoteCheckbox:GetValue(),
            playerEmoteAsStandstateCheckbox:GetValue())
    end)

    local filterFieldLabel = AnimPlusAceGUI:Create("Label")
    filterFieldLabel:SetFullWidth(true)
    filterFieldLabel:SetText("Search emotes by name, tags or id:")

    local filterFieldInput = AnimPlusAceGUI:Create("EditBox")
    filterFieldInput:SetText(emoteFilterInputValue)
    filterFieldInput:DisableButton(true)
    filterFieldInput:SetCallback("OnTextChanged", function(widget, event, text)
        emoteFilterInputValue = text
        RefreshEmoteSelectOptions(emoteSelect)
    end)

    local clearFilterFieldButton = AnimPlusAceGUI:Create("Button")
    clearFilterFieldButton:SetText("Clear")
    clearFilterFieldButton:SetWidth(100)
    clearFilterFieldButton:SetCallback("OnClick", function()
        filterFieldInput:SetText("")
        emoteFilterInputValue = ""
        RefreshEmoteSelectOptions(emoteSelect)
    end)

    if GetTargetType() == "npc" then
        container:AddChildren(npcChangeSheathLabel, npcChangeSheathDropdown, npcRepeatEmoteCheckbox)
    else
        container:AddChildren(playerEmoteAsStandstateCheckbox)
    end

    container:AddChildren(filterFieldLabel, filterFieldInput, clearFilterFieldButton, emoteSelect)
end

local function CreateApAnimationWindow()
    ApAnimationWindow = AnimPlusAceGUI:Create("Window")
    ApAnimationWindow.frame:SetFrameStrata("BACKGROUND")
    ApAnimationWindow:SetLayout("Fill")
    ApAnimationWindow:SetTitle("AnimPlus - Animation")
    ApAnimationWindow:SetHeight(260)
    ApAnimationWindow:SetWidth(346)
    ApAnimationWindow:EnableResize(false)
    -- ApAnimationWindow.frame:SetMinResize(346, 210)
    -- ApAnimationWindow.frame:SetMaxResize(490, 210)
    ApAnimationWindow.title:SetScript("OnMouseUp", CustomAnimPlusLibsFunctions.FrameOnMouseUp)
    ApAnimationWindow:SetCallback("OnClose", function(widget)
        -- SaveApAnimationWindowPosition()
        widget:Hide()
    end)
    local lastPosition = AnimPlus.db.char.windowLastPosition
    if lastPosition then
        ApAnimationWindow.frame:SetPoint("BOTTOMLEFT", lastPosition.x, lastPosition.y);
    end

    local function SelectGroup(container, event, group)
        container:ReleaseChildren()
        ApAnimationWindowSelectedTab = group
        if group == "aura" then
            CreateOrRefreshAuraTab(container)
        elseif group == "emote" then
            CreateOrRefreshEmoteTab(container)
        end
    end

    ApAnimationWindowTabGroup = AnimPlusAceGUI:Create("TabGroup")
    ApAnimationWindowTabGroup:SetLayout("Flow")
    ApAnimationWindowTabGroup:SetTabs({
        { text = "Aura",  value = "aura" },
        { text = "Emote", value = "emote" }
    })
    ApAnimationWindowTabGroup:SetCallback("OnGroupSelected", SelectGroup)
    ApAnimationWindowTabGroup:SelectTab("aura")
    ApAnimationWindow:AddChild(ApAnimationWindowTabGroup)
    ApAnimationWindowTabGroup.frame:SetPoint("TOPLEFT", ApAnimationWindow.frame, 10, -20);
end

function RefreshApAnimationWindow()
    if not ApAnimationWindow then return end
    if ApAnimationWindowSelectedTab == "aura" then
        CreateOrRefreshAuraTab(ApAnimationWindowTabGroup)
    end
    if ApAnimationWindowSelectedTab == "emote" then
        CreateOrRefreshEmoteTab(ApAnimationWindowTabGroup)
    end
end

function ToggleApAnimationWindow()
    if not ApAnimationWindow then
        CreateApAnimationWindow()
        return
    end
    if ApAnimationWindow:IsShown() then
        -- SaveApAnimationWindowPosition()
        ApAnimationWindow:Hide()
    else
        ApAnimationWindow:Show()
    end
end

function APToggleLastAura()
    if lastAuraApplied then
        HandleToggleTargetAura(lastAuraApplied, nil, false)
    end
end

function APTogglePossess()
    SendCmd(".unpossess")
    if GetTargetType() == "npc" and not UnitPlayerControlled("target") then
        SendCmd(".possess")
    end
end

function APToggleFreeze()
    local freezeSpell = {
        name = nil,
        value = "16245",
        tags = nil,
        cast = false
    }
    HandleToggleTargetAura(freezeSpell, nil, false)
end

function APTogglePhaseDM()
    SendCmd(".phase dm")
end

ApAnimCommands = {
    TogglePossess = APTogglePossess,
    ToggleLastAura = APToggleLastAura,
    ToggleFreeze = APToggleFreeze,
    TogglePhaseDM = APTogglePhaseDM,
}
