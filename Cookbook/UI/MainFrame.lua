-- MainFrame: the Cookbook window. Profession tabs on the left, toolbar on top,
-- recipe list in the middle and the recipe detail/calculator on the right.
local _, ns = ...

local MainFrame = {}
ns.MainFrame = MainFrame

local WIDTH, HEIGHT = 980, 600
local SIDEBAR_WIDTH = 160
local LIST_WIDTH = 340
local TOP_OFFSET = 74 -- title + toolbar
local TAB_HEIGHT = 28

local WINDOW_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

-- Window ------------------------------------------------------------------------

function MainFrame:BuildWindow()
    local frame = CreateFrame("Frame", "CookbookFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetBackdrop(WINDOW_BACKDROP)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        ns.db.position = { point, relativePoint, x, y }
    end)
    frame:SetScript("OnShow", function() self:Refresh() end)
    frame:Hide()
    tinsert(UISpecialFrames, "CookbookFrame") -- close on Escape

    local title = ns.Widgets.Text(frame, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -18)
    title:SetText("The Cookbook")

    local subtitle = ns.Widgets.Text(frame, "GameFontDisableSmall")
    subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)
    subtitle:SetText(("%d recipes, WoW Forever %s"):format(self:CountRecipes(), ns.Data.build))

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    self.frame = frame
    self:RestorePosition()
end

function MainFrame:CountRecipes()
    local total = 0
    for _, profession in ipairs(ns.RecipeService:GetProfessions()) do
        total = total + #ns.RecipeService:GetRecipes(profession.id)
    end
    return total
end

-- Profession tabs ---------------------------------------------------------------

function MainFrame:BuildTabs()
    local sidebar = ns.Widgets.Panel(self.frame)
    sidebar:SetPoint("TOPLEFT", 16, -TOP_OFFSET + 30)
    sidebar:SetPoint("BOTTOMLEFT", 16, 16)
    sidebar:SetWidth(SIDEBAR_WIDTH)

    self.tabs = {}
    for i, profession in ipairs(ns.RecipeService:GetProfessions()) do
        local tab = CreateFrame("Button", nil, sidebar)
        tab:SetSize(SIDEBAR_WIDTH - 12, TAB_HEIGHT)
        tab:SetPoint("TOPLEFT", 6, -6 - (i - 1) * (TAB_HEIGHT + 2))
        tab:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        tab.selected = tab:CreateTexture(nil, "BACKGROUND")
        tab.selected:SetAllPoints()
        tab.selected:SetColorTexture(1, 0.82, 0, 0.22)

        tab.icon = tab:CreateTexture(nil, "ARTWORK")
        tab.icon:SetSize(22, 22)
        tab.icon:SetPoint("LEFT", 4, 0)
        tab.icon:SetTexture(profession.icon)
        tab.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        tab.label = ns.Widgets.Text(tab, "GameFontNormal")
        tab.label:SetPoint("LEFT", tab.icon, "RIGHT", 8, 0)
        tab.label:SetText(profession.name)

        tab.count = ns.Widgets.Text(tab, "GameFontDisableSmall", "RIGHT")
        tab.count:SetPoint("RIGHT", -4, 0)
        tab.count:SetText(#ns.RecipeService:GetRecipes(profession.id))

        tab.profession = profession
        tab:SetScript("OnClick", function() self:SelectProfession(profession.id) end)
        self.tabs[i] = tab
    end
end

function MainFrame:UpdateTabs()
    for _, tab in ipairs(self.tabs) do
        local isSelected = tab.profession.id == self.professionID
        tab.selected:SetShown(isSelected)
        tab.label:SetFontObject(isSelected and "GameFontHighlight" or "GameFontNormal")
    end
end

-- Toolbar -----------------------------------------------------------------------

function MainFrame:BuildToolbar()
    local left = 16 + SIDEBAR_WIDTH + 10
    local top = -TOP_OFFSET + 30 -- toolbar sits above the list, aligned with the sidebar top

    self.search = CreateFrame("EditBox", nil, self.frame, "SearchBoxTemplate")
    self.search:SetSize(200, 20)
    self.search:SetPoint("TOPLEFT", left + 6, top)
    self.search:SetAutoFocus(false)
    self.search:HookScript("OnTextChanged", function(box)
        self.searchText = box:GetText()
        self:Refresh(true)
    end)

    local skillLabel = ns.Widgets.Text(self.frame, "GameFontNormalSmall")
    skillLabel:SetPoint("LEFT", self.search, "RIGHT", 18, 0)
    skillLabel:SetText("Skill")

    -- Overrides the player's real skill so you can browse "what would I see at 225?".
    self.skillBox = ns.Widgets.NumberBox(self.frame, 40, 3, function(value)
        self.skillOverrides[self.professionID] = value
        self:Refresh(true)
    end)
    self.skillBox:SetPoint("LEFT", skillLabel, "RIGHT", 10, 0)

    self.skillHint = ns.Widgets.Text(self.frame, "GameFontDisableSmall")
    self.skillHint:SetPoint("LEFT", self.skillBox, "RIGHT", 6, 0)

    self.hideGray = ns.Widgets.CheckBox(self.frame, "Hide gray", function(checked)
        ns.db.hideGray = checked
        self:Refresh(true)
    end)
    self.hideGray:SetPoint("LEFT", self.skillBox, "RIGHT", 110, 0) -- fixed spot so the hint text can't push it

    self.hideTooHigh = ns.Widgets.CheckBox(self.frame, "Hide too high", function(checked)
        ns.db.hideTooHigh = checked
        self:Refresh(true)
    end)
    self.hideTooHigh:SetPoint("LEFT", self.hideGray.label, "RIGHT", 10, -1)

    self.resultCount = ns.Widgets.Text(self.frame, "GameFontDisableSmall", "RIGHT")
    self.resultCount:SetPoint("TOPRIGHT", -24, top - 4)
end

-- Panels ------------------------------------------------------------------------

function MainFrame:BuildPanels()
    local left = 16 + SIDEBAR_WIDTH + 6
    local top = -TOP_OFFSET

    local list = ns.RecipeList:Create(self.frame)
    list:SetPoint("TOPLEFT", left, top)
    list:SetPoint("BOTTOMLEFT", left, 16)
    list:SetWidth(LIST_WIDTH)
    ns.RecipeList:SetOnSelect(function(recipe) self:SelectRecipe(recipe) end)

    local detail = ns.RecipeDetail:Create(self.frame)
    detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
    detail:SetPoint("BOTTOMRIGHT", -16, 16)
end

function MainFrame:Build()
    if self.frame then
        return
    end
    self.skillOverrides = {} -- per profession, this session only
    self.selectedSpells = {} -- remembered selection per profession
    self.searchText = ""

    self:BuildWindow()
    self:BuildTabs()
    self:BuildToolbar()
    self:BuildPanels()

    self.hideGray:SetChecked(ns.db.hideGray)
    self.hideTooHigh:SetChecked(ns.db.hideTooHigh)

    local first = ns.RecipeService:GetProfessions()[1]
    self.professionID = ns.db.lastProfession or (first and first.id)
end

-- State -------------------------------------------------------------------------

--- The skill used for colors and math: typed override, else the player's real skill.
function MainFrame:GetSkill()
    local override = self.skillOverrides[self.professionID]
    if override then
        return override
    end
    local profession = ns.RecipeService:GetProfession(self.professionID)
    return profession and (ns.SkillService:GetPlayerSkill(profession))
end

function MainFrame:SelectProfession(professionID)
    self.professionID = professionID
    ns.db.lastProfession = professionID
    self:Refresh(false)
end

function MainFrame:SelectRecipe(recipe)
    self.selectedSpells[self.professionID] = recipe and recipe.spell
    ns.RecipeDetail:Show(recipe, self:GetSkill())
end

function MainFrame:UpdateSkillDisplay()
    local profession = ns.RecipeService:GetProfession(self.professionID)
    local rank, maxRank = ns.SkillService:GetPlayerSkill(profession)
    local override = self.skillOverrides[self.professionID]

    if not self.skillBox:HasFocus() then
        self.skillBox:SetText(override or rank or "")
    end
    if rank then
        self.skillHint:SetText(("yours: %d/%d"):format(rank, maxRank or rank))
    else
        self.skillHint:SetText("not learned")
    end
end

--- Rebuilds the list for the current profession, search and filters.
--- keepScroll keeps the list position (used while typing/filtering).
function MainFrame:Refresh(keepScroll)
    if not (self.frame and self.frame:IsShown()) then
        return
    end
    local skill = self:GetSkill()
    local recipes = ns.RecipeService:Query(self.professionID, {
        search = self.searchText,
        skill = skill,
        hideGray = ns.db.hideGray,
        hideTooHigh = ns.db.hideTooHigh,
    })

    self:UpdateTabs()
    self:UpdateSkillDisplay()
    self.resultCount:SetText(("%d shown"):format(#recipes))
    ns.RecipeList:SetRecipes(recipes, skill, keepScroll)

    -- Keep the previous selection if it is still in the list, else pick the first recipe.
    local selectedSpell = self.selectedSpells[self.professionID]
    local selected = recipes[1]
    for _, recipe in ipairs(recipes) do
        if recipe.spell == selectedSpell then
            selected = recipe
            break
        end
    end
    ns.RecipeList:Select(selected)
end

-- Open / close ------------------------------------------------------------------

function MainFrame:Toggle()
    self:Build()
    self.frame:SetShown(not self.frame:IsShown())
end

--- Opens the window. arg can be a profession name ("alch") or search text ("thorium").
function MainFrame:Open(arg)
    self:Build()
    local profession = arg and ns.RecipeService:FindProfession(arg)
    if profession then
        self.professionID = profession.id
        ns.db.lastProfession = profession.id
    elseif arg then
        self.search:SetText(arg) -- triggers OnTextChanged -> Refresh
    end
    if self.frame:IsShown() then
        self:Refresh(false)
    else
        self.frame:Show() -- OnShow -> Refresh
    end
end

function MainFrame:RestorePosition()
    local position = ns.db.position
    self.frame:ClearAllPoints()
    if position then
        self.frame:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    else
        self.frame:SetPoint("CENTER")
    end
end

function MainFrame:ResetPosition()
    ns.db.position = nil
    if self.frame then
        self:RestorePosition()
    end
    ns.Print("window position reset.")
end

-- Live updates ------------------------------------------------------------------

ns.On("SKILL_LINES_CHANGED", function() MainFrame:Refresh(true) end)
ns.On("BAG_UPDATE_DELAYED", function()
    if MainFrame.frame and MainFrame.frame:IsShown() then
        ns.RecipeDetail:UpdateDynamic()
    end
end)
