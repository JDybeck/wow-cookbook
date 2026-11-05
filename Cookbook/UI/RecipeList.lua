-- RecipeList: scrollable list of recipes, sorted by skill, with the four skill thresholds per row.
local _, ns = ...

local RecipeList = {}
ns.RecipeList = RecipeList

local ROW_HEIGHT = 22
local LEVEL_COLUMN_WIDTH = 30
local HEADER_LABELS = { "Learn", "Yel", "Grn", "Gray" }

--- Text for each threshold column: learn, yellow, green, gray.
local function GetLevelTexts(recipe)
    local SkillService = ns.SkillService
    local learn = ns.RecipeService:GetLearnLevel(recipe)
    local yellow, green, gray = SkillService:GetThresholds(recipe)
    return {
        learn and SkillService:Colorize("orange", learn) or "|cff666666?|r",
        yellow and SkillService:Colorize("yellow", yellow) or "",
        green and SkillService:Colorize("green", green) or "",
        gray and SkillService:Colorize("gray", gray) or "",
    }
end

local function BuildRow(row)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(1, 0.82, 0, 0.2)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.levels = {}
    for i = #HEADER_LABELS, 1, -1 do
        local text = ns.Widgets.Text(row, "GameFontHighlightSmall", "RIGHT")
        text:SetWidth(LEVEL_COLUMN_WIDTH)
        text:SetPoint("RIGHT", -4 - (#HEADER_LABELS - i) * LEVEL_COLUMN_WIDTH, 0)
        row.levels[i] = text
    end

    row.name = ns.Widgets.Text(row, "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetPoint("RIGHT", row.levels[1], "LEFT", -4, 0)
    row.name:SetWordWrap(false)

    row:SetScript("OnClick", function(self)
        if IsModifiedClick("CHATLINK") then
            ns.ItemService:InsertLink(ns.RecipeService:GetLink(self.recipe))
        else
            RecipeList:Select(self.recipe)
        end
    end)
    row:SetScript("OnEnter", function(self)
        ns.RecipeService:ShowTooltip(self, self.recipe)
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row.built = true
end

function RecipeList:InitRow(row, recipe)
    if not row.built then
        BuildRow(row)
    end
    row.recipe = recipe
    row.icon:SetTexture(ns.RecipeService:GetIcon(recipe))

    local difficulty = ns.RecipeService:GetDifficulty(recipe, self.skill)
    row.name:SetText(ns.SkillService:Colorize(difficulty, recipe.name))

    local texts = GetLevelTexts(recipe)
    for i, text in ipairs(row.levels) do
        text:SetText(texts[i])
    end
    row.selected:SetShown(recipe.spell == self.selectedSpell)
end

function RecipeList:Create(parent)
    local panel = ns.Widgets.Panel(parent)

    -- Column header
    local header = ns.Widgets.Text(panel, "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", 10, -8)
    header:SetText("Recipe")
    for i, label in ipairs(HEADER_LABELS) do
        local text = ns.Widgets.Text(panel, "GameFontNormalSmall", "RIGHT")
        text:SetWidth(LEVEL_COLUMN_WIDTH)
        text:SetPoint("TOPRIGHT", -26 - (#HEADER_LABELS - i) * LEVEL_COLUMN_WIDTH, -8)
        text:SetText(label)
    end

    self.scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    self.scrollBox:SetPoint("TOPLEFT", 6, -24)
    self.scrollBox:SetPoint("BOTTOMRIGHT", -22, 6)

    self.scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    self.scrollBar:SetPoint("TOPLEFT", self.scrollBox, "TOPRIGHT", 6, 0)
    self.scrollBar:SetPoint("BOTTOMLEFT", self.scrollBox, "BOTTOMRIGHT", 6, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", function(row, recipe)
        self:InitRow(row, recipe)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(self.scrollBox, self.scrollBar, view)

    self.emptyText = ns.Widgets.Text(panel, "GameFontDisable", "CENTER")
    self.emptyText:SetPoint("CENTER")
    self.emptyText:SetText("No recipes match.")
    self.emptyText:Hide()

    return panel
end

--- onSelect(recipe) is called when the user clicks a row.
function RecipeList:SetOnSelect(callback)
    self.onSelect = callback
end

function RecipeList:SetRecipes(recipes, skill, keepScroll)
    self.skill = skill
    local retain = keepScroll and ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition
    self.scrollBox:SetDataProvider(CreateDataProvider(recipes), retain)
    self.emptyText:SetShown(#recipes == 0)
end

function RecipeList:Select(recipe)
    self.selectedSpell = recipe and recipe.spell
    self.scrollBox:ForEachFrame(function(row)
        if row.recipe then
            row.selected:SetShown(row.recipe.spell == self.selectedSpell)
        end
    end)
    if self.onSelect then
        self.onSelect(recipe)
    end
end
