CustomAnimPlusLibsFunctions = {}

CustomAnimPlusLibsFunctions.Dropdown_Close = function(dropdown)
    dropdown.open = nil
    dropdown.pullout:Close()
end

CustomAnimPlusLibsFunctions.Dropdown_Open = function(dropdown)
    dropdown.open = true
    dropdown.pullout:SetWidth(dropdown.pulloutWidth or dropdown.frame:GetWidth())
    dropdown.pullout:Open("TOPLEFT", dropdown.frame, "BOTTOMLEFT", 0, dropdown.label:IsShown() and -2 or 0)
end

CustomAnimPlusLibsFunctions.Dropdown_TogglePullout = function(dropdown)
    if dropdown.open then
        CustomAnimPlusLibsFunctions.Dropdown_Close(dropdown)
    else
        CustomAnimPlusLibsFunctions.Dropdown_Open(dropdown)
    end
end

CustomAnimPlusLibsFunctions.FrameOnMouseUp = function(this)
    local frame = this:GetParent()
    frame:StopMovingOrSizing()
    local self = frame.obj
    local status = self.status or self.localstatus
    status.width = frame:GetWidth()
    status.height = frame:GetHeight()
    status.top = frame:GetTop()
    status.left = frame:GetLeft()
    SaveApAnimationWindowPosition()
end