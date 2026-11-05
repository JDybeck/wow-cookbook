-- Core: addon namespace, saved variables, event bus and slash commands.
local addonName, ns = ...

ns.name = addonName

local DEFAULTS = {
    hideGray = false,
    hideTooHigh = false,
    lastProfession = nil,
    position = nil,
    trainerReq = {}, -- [spellID] = skill level, learned from trainer windows
}

local function ApplyDefaults(db, defaults)
    for key, value in pairs(defaults) do
        if db[key] == nil then
            db[key] = type(value) == "table" and {} or value
        end
    end
end

-- Event bus -------------------------------------------------------------------
-- One frame for the whole addon; services subscribe with ns.On(event, handler).

local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns.On(event, handler)
    if not handlers[event] then
        handlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(handlers[event], handler)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, handler in ipairs(handlers[event]) do
        handler(...)
    end
end)

ns.On("ADDON_LOADED", function(loadedName)
    if loadedName ~= addonName then
        return
    end
    CookbookDB = CookbookDB or {}
    ApplyDefaults(CookbookDB, DEFAULTS)
    ns.db = CookbookDB
end)

function ns.Print(message)
    print("|cffd4a017The Cookbook:|r " .. message)
end

-- Slash commands ----------------------------------------------------------------

local function PrintHelp()
    ns.Print("commands:")
    print("  /cookbook - toggle the window")
    print("  /cookbook <profession> - open a profession, e.g. /cookbook alchemy")
    print("  /cookbook <text> - search the current profession, e.g. /cookbook thorium")
    print("  /cookbook reset - reset window position")
end

SLASH_COOKBOOK1 = "/cookbook"
SLASH_COOKBOOK2 = "/cb"
SlashCmdList.COOKBOOK = function(message)
    local text = strtrim(message or "")
    local lower = text:lower()

    if lower == "help" then
        PrintHelp()
    elseif lower == "reset" then
        ns.MainFrame:ResetPosition()
    elseif text == "" then
        ns.MainFrame:Toggle()
    else
        ns.MainFrame:Open(text)
    end
end

-- Referenced from the TOC (AddonCompartmentFunc), so it must be global.
function Cookbook_OnAddonCompartmentClick()
    ns.MainFrame:Toggle()
end
