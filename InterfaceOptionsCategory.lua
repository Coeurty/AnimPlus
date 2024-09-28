local options = {
    name = "AnimPlus",
    handler = Animplus,
    type = "group",
    args = {
        wipeCollectionsButton = {
            type = "execute",
            name = "Wipe collections",
            desc = "Delete all auras and emotes.",
            func = function()
                AnimPlus.db.locale.auras = {}
                AnimPlus.db.locale.emotes = {}
                RefreshApAnimationWindow()
                RefreshApCollectionsWindow()
            end,
        },
        -- descriptionOption = {
        --     type = "description",
        --     name = "WIP",
        -- },
    },
}

function CreateAnimPlusInterfaceOptionsCategory()
    LibStub("AceConfig-3.0"):RegisterOptionsTable("AnimPlus", options)
    AnimPlus.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("AnimPlus", "AnimPlus")
end

function ToggleApInterfaceOptionsCategory()
    if InterfaceOptionsFrame:IsShown() then
        if AnimPlus.optionsFrame:IsShown() then
            AnimPlus.optionsFrame:Hide()
            InterfaceOptionsFrame:Hide()
        else
            InterfaceOptionsFrame_OpenToCategory(AnimPlus.optionsFrame)
        end
    else
        InterfaceOptionsFrame:Show()
        InterfaceOptionsFrame_OpenToCategory(AnimPlus.optionsFrame)
    end
end