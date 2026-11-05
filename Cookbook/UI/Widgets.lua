-- Widgets: small UI building blocks shared by every Cookbook panel.
local _, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local PANEL_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function Widgets.Text(parent, font, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    text:SetJustifyH(justify or "LEFT")
    return text
end

--- Dark inset panel used for the sidebar, list and detail areas.
function Widgets.Panel(parent)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetBackdrop(PANEL_BACKDROP)
    panel:SetBackdropColor(0, 0, 0, 0.55)
    panel:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.9)
    return panel
end

function Widgets.Button(parent, label, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

--- Numeric input. onChanged(number|nil) fires only for user typing, not SetText.
function Widgets.NumberBox(parent, width, maxLetters, onChanged)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(maxLetters)
    box:SetJustifyH("CENTER")
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            onChanged(tonumber(self:GetText()))
        end
    end)
    return box
end

function Widgets.CheckBox(parent, label, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check.label = Widgets.Text(check, "GameFontHighlightSmall")
    check.label:SetPoint("LEFT", check, "RIGHT", 0, 1)
    check.label:SetText(label)
    check:SetScript("OnClick", function(self)
        onClick(self:GetChecked())
    end)
    return check
end

--- Square icon button with tooltip and shift-click-to-link support.
--- getTarget() returns the object passed to onTooltip/onLink (nil hides the tooltip).
function Widgets.IconButton(parent, size, onTooltip, onLink, getTarget)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    Widgets.AttachTooltip(button, onTooltip, onLink, getTarget)
    return button
end

--- Shared hover/shift-click behavior for anything that represents an item or recipe.
function Widgets.AttachTooltip(frame, onTooltip, onLink, getTarget)
    frame:SetScript("OnEnter", function(self)
        local target = getTarget(self)
        if target then
            onTooltip(self, target)
        end
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
    frame:SetScript("OnMouseUp", function(self)
        local target = getTarget(self)
        if target and IsModifiedClick("CHATLINK") then
            onLink(target)
        end
    end)
end

function Widgets.Divider(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(1, 1, 1, 0.15)
    return line
end
