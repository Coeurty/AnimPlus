ApCollectionsWindow = nil
local ApCollectionsWindowTabGroup = nil
local ApCollectionsWindowSelectedTab = nil
local importExportWindow = nil
local newOrEditObjectWindow = nil

local function FindLastId(collection)
    local lastId = 0
    for _, o in ipairs(collection) do
        if o.id > lastId then
            lastId = o.id
        end
    end
    return lastId
end

local function GetDbCollection(type)
    local copyDb = AnimPlus.db.locale[type]
    if not copyDb then
        copyDb = {}
    end
    return copyDb
end

local function SetDbCollection(type, newDb)
    AnimPlus.db.locale[type] = newDb
end

local function CreateObject(type, object)
    local copyDb = GetDbCollection(type)
    local lastId = FindLastId(copyDb)
    object.id = lastId + 1
    table.insert(copyDb, object)
    SetDbCollection(type, copyDb)
    RefreshApAnimationWindow()
end

local function UpdateObjectById(type, updatedObject, oldObject)
    local copyDb = GetDbCollection(type)
    for _, o in ipairs(copyDb) do
        if o.id == oldObject.id then
            o.name = updatedObject.name
            o.value = updatedObject.value
            o.tags = updatedObject.tags
            if type == "auras" then
                o.cast = updatedObject.cast
            else
                o.cast = nil
            end
            break
        end
    end
    SetDbCollection(type, copyDb)
    RefreshApAnimationWindow()
end

local function DeleteObjectById(type, id)
    local copyDb = GetDbCollection(type)
    for index, o in ipairs(copyDb) do
        if o.id == id then
            table.remove(copyDb, index)
            break
        end
    end
    SetDbCollection(type, copyDb)
    RefreshApAnimationWindow()
end

local function ImportCollection(luaCollection, tag)
    local type = luaCollection.type
    local data = luaCollection.data

    local copyDb = GetDbCollection(type)
    local lastId = FindLastId(copyDb)

    local valuesInCopyDb = {}
    for _, o in ipairs(copyDb) do
        valuesInCopyDb[o["value"]] = true
    end

    local addedItem = 0
    local notAddedItem = 0
    for _, o in ipairs(data) do
        if valuesInCopyDb[o.value] then
            notAddedItem = notAddedItem + 1
        else
            local newObject = o
            newObject.id = lastId + 1
            lastId = lastId + 1
            if tag and tag ~= "" then
                newObject.tags = newObject.tags .. " " .. tag
            end
            table.insert(copyDb, newObject)
            addedItem = addedItem + 1
        end
    end
    local msg = ""
    if notAddedItem == 0 then
        msg = addedItem .. " " .. type .. " imported."
    else
        msg = addedItem .. " " .. type .. " imported, " .. notAddedItem .. " already in collection"
    end
    AnimPlus:Print(msg)
    SetDbCollection(type, copyDb)
    RefreshApAnimationWindow()
end

local function CreateImportExportWindow(type, data)
    if importExportWindow then
        importExportWindow:Release()
    end

    importExportWindow = AnimPlusAceGUI:Create("Window")
    importExportWindow:SetTitle("AnimPlus - " .. type)
    importExportWindow:SetHeight(300)
    importExportWindow:SetWidth(500)
    importExportWindow:EnableResize(false)
    importExportWindow:SetLayout("Flow")
    importExportWindow.frame:SetFrameStrata("HIGH")
    importExportWindow:SetCallback("OnClose", function(widget)
        widget:Hide()
    end)

    local textArea = AnimPlusAceGUI:Create("MultiLineEditBox")
    textArea:SetLabel("")
    textArea:SetFullWidth(true)
    textArea:DisableButton(true)

    if type == "Export" and data then
        local jsonCollection = json.encode(data)
        textArea:SetText(jsonCollection)
        textArea:HighlightText()
        textArea:SetFocus()
        importExportWindow:SetLayout("Fill")
    end

    importExportWindow:AddChild(textArea)

    if type == "Import" and not data then
        textArea:SetNumLines(10)

        local addTagsGroup = AnimPlusAceGUI:Create("SimpleGroup")
        addTagsGroup:SetLayout("Flow")
        addTagsGroup:SetFullWidth(true)
        local addTagsLabel = AnimPlusAceGUI:Create("Label")
        addTagsLabel:SetText("Additional tags:")
        addTagsLabel:SetWidth(100)
        local addTagsEditBox = AnimPlusAceGUI:Create("EditBox")
        addTagsEditBox:DisableButton(true)
        addTagsEditBox:SetWidth(250)
        addTagsGroup:AddChildren(addTagsLabel, addTagsEditBox)

        local importButton = AnimPlusAceGUI:Create("Button")
        importButton:SetText("Add to collection")
        importButton:SetWidth(250)
        importButton:SetCallback("OnClick", function()
            local textAreavalue = textArea:GetText()
            if textAreavalue ~= "" then
                local luaCollection = json.decode(textArea:GetText())
                ImportCollection(luaCollection, addTagsEditBox:GetText())
                importExportWindow:Hide()
            end
        end)

        importExportWindow:SetLayout("Flow")
        importExportWindow:AddChildren(addTagsGroup, CreateDividerWidget(), importButton)
    end
end

local function handleCopytargetAurasButton()
    if not PlayerHasTarget() then
        AnimPlus:Print("You don't have a target.")
        return
    else
        local targetAuras = GetUnitAuras("target")
        if #targetAuras == 0 then
            AnimPlus:Print("Your target has no aura.")
            return
        end
        local luaCollection = { type = "auras", data = {} }
        for _, o in ipairs(targetAuras) do
            table.insert(
                luaCollection.data,
                {
                    name = o.name,
                    value = tostring(o.value),
                    tags = "copiedAura",
                    cast = false
                }
            )
        end
        ImportCollection(luaCollection)
    end
end

local function CreateOrRefreshApCollectionsWindowNewSection(container)
    container:ReleaseChildren()
    local addButton = AnimPlusAceGUI:Create("Button")
    addButton:SetText("Create an aura or emote")
    addButton:SetFullWidth(true)
    addButton:SetCallback("OnClick", function()
        if newOrEditObjectWindow and newOrEditObjectWindow:IsShown() then
            return
        end
        CreateNewOrEditObjectWindow()
    end)

    local copyTargetAurasButton = AnimPlusAceGUI:Create("Button")
    copyTargetAurasButton:SetText("Copy target's auras")
    copyTargetAurasButton:SetFullWidth(true)
    copyTargetAurasButton:SetCallback("OnClick", function()
        handleCopytargetAurasButton()
    end)

    local importButton = AnimPlusAceGUI:Create("Button")
    importButton:SetText("Import a collection")
    importButton:SetFullWidth(true)
    importButton:SetCallback("OnClick", function()
        CreateImportExportWindow("Import")
    end)

    container:AddChildren(CreateDividerWidget(), addButton, CreateDividerWidget(), copyTargetAurasButton,
        CreateDividerWidget(), importButton)
end

function CreateNewOrEditObjectWindow(object, type, container)
    if newOrEditObjectWindow then
        newOrEditObjectWindow:Release()
    end

    local edit = false
    if object then
        edit = true
    end
    newOrEditObjectWindow = AnimPlusAceGUI:Create("Window")
    newOrEditObjectWindow.frame:SetFrameStrata("HIGH")
    if edit then
        newOrEditObjectWindow:SetTitle("AnimPlus - Edit")
        newOrEditObjectWindow:SetHeight(370)
    else
        newOrEditObjectWindow:SetTitle("AnimPlus - Create")
        newOrEditObjectWindow:SetHeight(340)
    end
    newOrEditObjectWindow:SetWidth(300)
    newOrEditObjectWindow:EnableResize(false)
    newOrEditObjectWindow:SetCallback("OnClose", function(widget)
        -- print("width", newOrEditObjectWindow.frame:GetWidth())
        -- print("height", newOrEditObjectWindow.frame:GetHeight())
        newOrEditObjectWindow:Hide()
        -- ApCollectionsWindow:Show()
    end)

    local formContainer = AnimPlusAceGUI:Create("InlineGroup")
    formContainer:SetFullWidth(true)

    local castAuraLabel = AnimPlusAceGUI:Create("Label")
    castAuraLabel:SetText("")
    castAuraLabel:SetWidth(50)

    local castAuraCheckBox = AnimPlusAceGUI:Create("CheckBox")
    castAuraCheckBox:SetLabel(" Cast the aura")
    castAuraCheckBox:SetDescription("'.cast' instead of '.aura'")
    -- castAuraCheckBox:SetFullWidth(true)

    local function refreshCastAuraCheckbox(value)
        local disabled = true
        local checked = false
        if value == "auras" then
            disabled = false
        end
        if object and object.cast then
            castAuraCheckBox:SetValue(object.cast)
        end
        castAuraCheckBox:SetDisabled(disabled)
    end
    refreshCastAuraCheckbox(type or "auras")

    local typeSelectGroup = AnimPlusAceGUI:Create("SimpleGroup")
    typeSelectGroup:SetLayout("Flow")
    typeSelectGroup:SetFullWidth(true)
    local typeSelectLabel = AnimPlusAceGUI:Create("Label")
    typeSelectLabel:SetText("Type:")
    typeSelectLabel:SetWidth(50)
    local typesOptions = {
        { name = "Aura",  value = "auras" },
        { name = "Emote", value = "emotes" }
    }
    local typeSelectDropdown = AnimPlusAceGUI:Create("Dropdown")
    if edit then typeSelectDropdown:SetDisabled(true) end
    for _, o in ipairs(typesOptions) do
        typeSelectDropdown:AddItem(o.value, o.name)
    end
    typeSelectDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        refreshCastAuraCheckbox(value)
    end)
    typeSelectDropdown:SetValue(type or "auras")
    typeSelectGroup:AddChildren(typeSelectLabel, typeSelectDropdown, castAuraLabel, castAuraCheckBox)

    local nameInput = AnimPlusAceGUI:Create("EditBox")
    local valueInput = AnimPlusAceGUI:Create("EditBox")
    local tagsInput = AnimPlusAceGUI:Create("MultiLineEditBox")

    if edit then
        nameInput:SetText(object.name)
        valueInput:SetText(object.value)
        tagsInput:SetText(object.tags)
    end

    --  TODO: à refaire / modifier aura"s" et emote"s"
    local function firstCapitalLetterSingular(s)
        local result = string.sub(s, 1, -2)
        result = string.upper(string.sub(result, 1, 1)) .. string.sub(result, 2)
        return result
    end

    local function handleValidBtn()
        local objectType = typeSelectDropdown:GetValue()
        local newObject = {
            name = nameInput:GetText(),
            value = tostring(valueInput:GetText()),
            tags = tagsInput:GetText(),
        }
        if objectType == "auras" then
            newObject.cast = castAuraCheckBox:GetValue()
        end
        if newObject.name == "" or newObject.value == "" then
            return
        end
        local typeName = firstCapitalLetterSingular(objectType)
        if edit then
            newObject.id = object.id
            UpdateObjectById(objectType, newObject, object)
            if type == typeSelectDropdown:GetValue() then
                refreshTableContent(container, type)
            end
            AnimPlus:Print(typeName .. " updated.")
            newOrEditObjectWindow:Hide()
            return
        else
            CreateObject(objectType, newObject)
            AnimPlus:Print(typeName .. " created.")
            nameInput:SetText("")
            valueInput:SetText("")
            tagsInput:SetText("")
        end
    end

    local function handleTestBtn()
        local id = valueInput:GetText()
        local type = typeSelectDropdown:GetValue()
        if not id then return end
        if type == "auras" then
            if castAuraCheckBox:GetValue() then
                SendCmd(".cast " .. id)
            else
                SendCmd(".aura " .. id)
            end
        else
            SendCmd(".modify anim " .. id)
        end
    end

    local nameGroup = AnimPlusAceGUI:Create("SimpleGroup")
    nameGroup:SetLayout("Flow")
    nameGroup:SetFullWidth(true)
    local nameLabel = AnimPlusAceGUI:Create("Label")
    nameLabel:SetText("Name:")
    nameLabel:SetWidth(50)
    nameInput:DisableButton(true)
    nameInput.editbox:SetScript("OnTabPressed", function()
        valueInput:SetFocus()
    end)
    nameInput.editbox:SetScript("OnEnterPressed", function() handleValidBtn() end)
    nameGroup:AddChildren(nameLabel, nameInput)

    local valueGroup = AnimPlusAceGUI:Create("SimpleGroup")
    valueGroup:SetLayout("Flow")
    valueGroup:SetFullWidth(true)
    local valueLabel = AnimPlusAceGUI:Create("Label")
    valueLabel:SetText("Id:")
    valueLabel:SetWidth(50)
    valueInput:DisableButton(true)
    valueInput:SetWidth(125)
    valueInput.editbox:SetScript("OnTabPressed", function()
        tagsInput:SetFocus()
    end)
    valueInput.editbox:SetScript("OnEnterPressed", function() handleValidBtn() end)
    local testBtn = AnimPlusAceGUI:Create("Button")
    testBtn:SetText("Test")
    testBtn:SetWidth(75)
    testBtn:SetCallback("OnClick", function()
        handleTestBtn()
    end)
    valueGroup:AddChildren(valueLabel, valueInput, testBtn)

    local tagsGroup = AnimPlusAceGUI:Create("SimpleGroup")
    tagsGroup:SetLayout("Flow")
    tagsGroup:SetFullWidth(true)
    local tagsLabel = AnimPlusAceGUI:Create("Label")
    tagsLabel:SetText("Tags:")
    tagsLabel:SetWidth(50)
    tagsInput:DisableButton(true)
    tagsInput:SetLabel("")
    tagsInput:SetNumLines(3)
    tagsInput.editBox:SetScript("OnEnterPressed", function() handleValidBtn() end)
    tagsGroup:AddChildren(tagsLabel, tagsInput)

    local validBtn = AnimPlusAceGUI:Create("Button")
    if edit then
        validBtn:SetText("Save changes")
    else
        validBtn:SetText("Add to collection")
    end
    -- validBtn:SetWidth(250)
    validBtn:SetFullWidth(true)
    validBtn:SetCallback("OnClick", function() handleValidBtn() end)

    formContainer:AddChildren(typeSelectGroup, nameGroup, valueGroup, tagsGroup)
    newOrEditObjectWindow:AddChildren(formContainer)
    newOrEditObjectWindow:AddChildren(CreateDividerWidget(), validBtn)

    if edit then
        local deleteButton = AnimPlusAceGUI:Create("Button")
        deleteButton:SetText("Delete")
        deleteButton:SetFullWidth(true)
        -- TODO
        -- deleteButton.frame:GetNormalTexture():SetVertexColor(1, 0, 0, 1)
        deleteButton:SetCallback("OnClick", function()
            DeleteObjectById(type, object.id)
            local typeName = firstCapitalLetterSingular(type)
            AnimPlus:Print(typeName .. " deleted.")
            refreshTableContent(container, type)
            newOrEditObjectWindow:Hide()
        end)
        newOrEditObjectWindow:AddChildren(CreateDividerWidget(), deleteButton)
    end
end

-- local function SetToCenter(widget)
--     local widgetWidth = widget.frame:GetWidth()
--     print("widgetWidth", widgetWidth) -- 250

--     local parent = widget.frame:GetParent()

--     local parentWidth = parent:GetWidth()
--     print("parentWidth", parentWidth) -- 1920

--     local xOffset = (parentWidth - widgetWidth) / 2
--     print("xOffset", xOffset)

--     widget.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, 0)
-- end
local filterParams = {
    auras = "",
    emotes = "",
    showAll = false
}

function refreshTableContent(container, type)
    container:ReleaseChildren()
    local dbCollection = GetDbCollection(type)
    if dbCollection then
        dbCollection = ReverseTable(dbCollection)
        local counter = 0
        local filteredCollection = {}
        for _, o in ipairs(dbCollection) do
            local filterValue = filterParams[type]
            if filterValue == "" and type == "auras" then
                filterValue = "copiedAura"
            end
            if filterParams.showAll and type == "auras" then
                filterValue = ""
            end
            if IsStringInObjectValues(filterValue, o) then
                table.insert(filteredCollection, o)
                counter = counter + 1

                local rowGroup = AnimPlusAceGUI:Create("SimpleGroup")
                rowGroup.frame:SetHeight(20)
                rowGroup:SetLayout("Flow")
                rowGroup:SetFullWidth(true)

                local nameText = AnimPlusAceGUI:Create("Label")
                nameText:SetText(o.name)
                nameText:SetWidth(250)
                rowGroup:AddChild(nameText)

                local valueText = AnimPlusAceGUI:Create("Label")
                valueText:SetText(o.value)
                valueText:SetWidth(100)
                rowGroup:AddChild(valueText)

                local tagsText = AnimPlusAceGUI:Create("Label")
                tagsText:SetText(o.tags)
                tagsText:SetWidth(350)
                rowGroup:AddChild(tagsText)

                local editButton = AnimPlusAceGUI:Create("Button")
                editButton:SetText("Edit")
                editButton:SetWidth(100)
                editButton:SetCallback("OnClick", function()
                    CreateNewOrEditObjectWindow(o, type, container)
                end)
                rowGroup:AddChild(editButton)

                if counter % 2 == 0 then
                    nameText:SetColor(0.7, 0.7, 0.7)
                    valueText:SetColor(0.7, 0.7, 0.7)
                    tagsText:SetColor(0.7, 0.7, 0.7)
                else
                    nameText:SetColor(1, 1, 1)
                    valueText:SetColor(1, 1, 1)
                    tagsText:SetColor(1, 1, 1)
                end

                container:AddChild(rowGroup)
            end
        end
        if #filteredCollection > 0 then
            local exportButtonContainer = AnimPlusAceGUI:Create("SimpleGroup")
            exportButtonContainer:SetLayout("Flow")
            exportButtonContainer:SetFullWidth(true)
            local exportButton = AnimPlusAceGUI:Create("Button")
            exportButton:SetText("Export collection")
            exportButton:SetAutoWidth()
            exportButton:SetCallback("OnClick", function()
                local collectionToExport = {
                    type = type,
                    data = ReverseTable(filteredCollection)
                }
                CreateImportExportWindow("Export", collectionToExport)
            end)
            local spaceSize = (ApCollectionsWindow.frame:GetWidth() / 2) - (exportButtonContainer.frame:GetWidth() / 2)
            exportButtonContainer:AddChildren(CreateSpace(spaceSize), exportButton)
            container:AddChild(exportButtonContainer)
            -- SetToCenter(exportButton)
        end
    end
    -- CONTRE SCROLL QUI SE MET PAS A JOUR
    ApCollectionsWindow:SetHeight(ApCollectionsWindow.frame:GetHeight() + 1)
end

function CreateOrRefreshApCollectionsWindowAuraSection(container)
    container:ReleaseChildren()
    local scrollFrame = AnimPlusAceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("List")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetFullHeight(true)

    -- Header row
    local tableHeaderGroup = AnimPlusAceGUI:Create("SimpleGroup")
    tableHeaderGroup:SetLayout("Flow")
    tableHeaderGroup:SetFullWidth(true)

    local nameLabel = AnimPlusAceGUI:Create("Button")
    nameLabel:SetText("Name")
    nameLabel:SetWidth(250)
    tableHeaderGroup:AddChild(nameLabel)

    local valueLabel = AnimPlusAceGUI:Create("Button")
    valueLabel:SetText("Id")
    valueLabel:SetWidth(100)
    tableHeaderGroup:AddChild(valueLabel)

    local tagsLabel = AnimPlusAceGUI:Create("Button")
    tagsLabel:SetText("Tags")
    tagsLabel:SetWidth(350)
    tableHeaderGroup:AddChild(tagsLabel)

    local tableContentGroup = AnimPlusAceGUI:Create("SimpleGroup")
    tableContentGroup:SetLayout("Flow")
    tableContentGroup:SetFullWidth(true)

    local scrollFrameContainer = AnimPlusAceGUI:Create("SimpleGroup")
    scrollFrameContainer:SetLayout("Fill")
    scrollFrameContainer:SetFullWidth(true)

    local filterFieldLabel = AnimPlusAceGUI:Create("Label")
    filterFieldLabel:SetFullWidth(true)
    filterFieldLabel:SetText("Search " .. "auras" .. " by name, tags or id:")

    local filterFieldInput = AnimPlusAceGUI:Create("EditBox")
    filterFieldInput:SetText(filterParams["auras"])
    filterFieldInput:DisableButton(true)
    filterFieldInput:SetCallback("OnTextChanged", function(widget, event, text)
        filterParams["auras"] = text
        refreshTableContent(tableContentGroup, "auras")
    end)

    local clearFilterFieldButton = AnimPlusAceGUI:Create("Button")
    clearFilterFieldButton:SetText("Clear")
    clearFilterFieldButton:SetWidth(100)
    clearFilterFieldButton:SetCallback("OnClick", function()
        filterFieldInput:SetText("")
        filterParams["auras"] = ""
        refreshTableContent(tableContentGroup, "auras")
    end)

    local showAllCollection = AnimPlusAceGUI:Create("CheckBox")
    showAllCollection:SetLabel("Show all collection")
    showAllCollection:SetValue(filterParams.showAll)
    showAllCollection:SetCallback("OnValueChanged", function(widget, event, value)
        -- filterFieldInput:SetText("")
        if value == true then
            filterParams.showAll = true
            filterFieldInput:SetDisabled(true)
            clearFilterFieldButton:SetDisabled(true)
        else
            filterParams.showAll = false
            filterFieldInput:SetDisabled(false)
            clearFilterFieldButton:SetDisabled(false)
        end
        refreshTableContent(tableContentGroup, "auras")
    end)

    container:AddChildren(filterFieldLabel, filterFieldInput, clearFilterFieldButton, CreateSpace(50), showAllCollection,
        CreateDividerWidget())

    refreshTableContent(tableContentGroup, "auras")

    scrollFrame:AddChildren(tableHeaderGroup, tableContentGroup)
    container:AddChild(scrollFrame)
end

function CreateOrRefreshApCollectionsWindowEmoteSection(container)
    container:ReleaseChildren()
    local scrollFrame = AnimPlusAceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("List")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetFullHeight(true)

    -- Header row
    local tableHeaderGroup = AnimPlusAceGUI:Create("SimpleGroup")
    tableHeaderGroup:SetLayout("Flow")
    tableHeaderGroup:SetFullWidth(true)

    local nameLabel = AnimPlusAceGUI:Create("Button")
    nameLabel:SetText("Name")
    nameLabel:SetWidth(250)
    tableHeaderGroup:AddChild(nameLabel)

    local valueLabel = AnimPlusAceGUI:Create("Button")
    valueLabel:SetText("Id")
    valueLabel:SetWidth(100)
    tableHeaderGroup:AddChild(valueLabel)

    local tagsLabel = AnimPlusAceGUI:Create("Button")
    tagsLabel:SetText("Tags")
    tagsLabel:SetWidth(350)
    tableHeaderGroup:AddChild(tagsLabel)

    local tableContentGroup = AnimPlusAceGUI:Create("SimpleGroup")
    tableContentGroup:SetLayout("Flow")
    tableContentGroup:SetFullWidth(true)

    -- Data rows
    refreshTableContent(tableContentGroup, "emotes")

    scrollFrame:AddChildren(tableHeaderGroup, tableContentGroup)
    container:AddChild(scrollFrame)
end

local function CreateApCollectionsWindow()
    ApCollectionsWindow = AnimPlusAceGUI:Create("Window")
    ApCollectionsWindow:SetLayout("Fill")
    ApCollectionsWindow.frame:SetFrameStrata("MEDIUM")
    ApCollectionsWindow:SetTitle("AnimPlus - Collections")
    ApCollectionsWindow:SetCallback("OnClose", function(widget)
        -- print("width", ApCollectionsWindow.frame:GetWidth())
        -- print("height", ApCollectionsWindow.frame:GetHeight())
        widget:Hide()
    end)

    ApCollectionsWindowTabGroup = AnimPlusAceGUI:Create("TabGroup")

    local function SelectGroup(container, event, group)
        filterParams.showAll = false
        container:ReleaseChildren()
        ApCollectionsWindowSelectedTab = group
        ApCollectionsWindow:EnableResize(true)
        ApCollectionsWindow.frame:SetMinResize(870, 450)
        ApCollectionsWindow.frame:SetMaxResize(870, 900)
        ApCollectionsWindow:SetHeight(450)
        ApCollectionsWindow:SetWidth(870)
        if group == "new" then
            ApCollectionsWindow:EnableResize(false)
            ApCollectionsWindow:SetHeight(220)
            ApCollectionsWindow:SetWidth(300)
            CreateOrRefreshApCollectionsWindowNewSection(container)
        elseif group == "aura" then
            CreateOrRefreshApCollectionsWindowAuraSection(container)
        elseif group == "emote" then
            CreateOrRefreshApCollectionsWindowEmoteSection(container)
        end
        ApCollectionsWindowTabGroup.frame:SetPoint("TOPLEFT", ApCollectionsWindow.frame, 10, -20);
    end

    ApCollectionsWindowTabGroup:SetLayout("Flow")
    ApCollectionsWindowTabGroup:SetTabs({
        { text = "New",   value = "new" },
        { text = "Aura",  value = "aura" },
        { text = "Emote", value = "emote" }
    })
    ApCollectionsWindowTabGroup:SetCallback("OnGroupSelected", SelectGroup)
    ApCollectionsWindowTabGroup:SelectTab("new")
    ApCollectionsWindow:AddChild(ApCollectionsWindowTabGroup)
    ApCollectionsWindowTabGroup.frame:SetPoint("TOPLEFT", ApCollectionsWindow.frame, 10, -20);
end

function RefreshApCollectionsWindow()
    if not ApCollectionsWindow then return end
    if ApCollectionsWindowSelectedTab == "new" then
        CreateOrRefreshApCollectionsWindowNewSection(ApCollectionsWindowTabGroup)
    elseif ApCollectionsWindowSelectedTab == "aura" then
        CreateOrRefreshApCollectionsWindowAuraSection(ApCollectionsWindowTabGroup)
    elseif ApCollectionsWindowSelectedTab == "emote" then
        CreateOrRefreshApCollectionsWindowEmoteSection(ApCollectionsWindowTabGroup)
    end
    if newOrEditObjectWindow then newOrEditObjectWindow:Hide() end
end

function ToggleApCollectionsWindow()
    if not ApCollectionsWindow then
        CreateApCollectionsWindow()
        return
    end
    if ApCollectionsWindow:IsShown() then
        ApCollectionsWindow:Hide()
    else
        ApCollectionsWindow:Show()
    end
end
