-- RecipeDetail: right-hand pane. Shows what a recipe makes, its skill levels, source, tools,
-- reagents with have/need counts, and a calculator for batch crafting and leveling.
local _, ns = ...

local RecipeDetail = {}
ns.RecipeDetail = RecipeDetail

local MAX_REAGENTS = 8
local REAGENT_ROW_HEIGHT = 20
local MAX_QUANTITY = 9999
local THRESHOLDS = {
    { key = "orange", label = "Learn" },
    { key = "yellow", label = "Yellow" },
    { key = "green", label = "Green" },
    { key = "gray", label = "Gray" },
}

local function Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

-- Building ----------------------------------------------------------------------

local function ShowRecipeTooltip(owner, recipe) ns.RecipeService:ShowTooltip(owner, recipe) end
local function LinkRecipe(recipe) ns.ItemService:InsertLink(ns.RecipeService:GetLink(recipe)) end
local function ShowItemTooltip(owner, itemID) ns.ItemService:ShowTooltip(owner, itemID) end
local function LinkItem(itemID) ns.ItemService:InsertLink(ns.ItemService:GetLink(itemID)) end

function RecipeDetail:BuildHeader(content)
    self.icon = ns.Widgets.IconButton(content, 40, ShowRecipeTooltip, LinkRecipe, function() return self.recipe end)
    self.icon:SetPoint("TOPLEFT", 12, -12)

    self.title = ns.Widgets.Text(content, "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", 10, -2)
    self.title:SetPoint("RIGHT", -12, 0)
    self.title:SetWordWrap(false)

    self.subtitle = ns.Widgets.Text(content, "GameFontHighlightSmall")
    self.subtitle:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -5)
    self.subtitle:SetPoint("RIGHT", -12, 0)
    self.subtitle:SetWordWrap(false)
end

function RecipeDetail:BuildThresholds(content)
    self.thresholdCells = {}
    for i, threshold in ipairs(THRESHOLDS) do
        local cell = CreateFrame("Frame", nil, content, "BackdropTemplate")
        cell:SetSize(96, 38)
        cell:SetPoint("TOPLEFT", 12 + (i - 1) * 102, -64)
        cell:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        cell:SetBackdropColor(1, 1, 1, 0.05)

        cell.label = ns.Widgets.Text(cell, "GameFontHighlightSmall", "CENTER")
        cell.label:SetPoint("TOP", 0, -4)
        cell.label:SetText(ns.SkillService:Colorize(threshold.key, threshold.label))

        cell.value = ns.Widgets.Text(cell, "GameFontHighlightLarge", "CENTER")
        cell.value:SetPoint("BOTTOM", 0, 4)
        self.thresholdCells[i] = cell
    end

    self.status = ns.Widgets.Text(content, "GameFontHighlightSmall")
    self.status:SetPoint("TOPLEFT", 12, -110)
    self.status:SetPoint("RIGHT", -12, 0)
end

function RecipeDetail:BuildSource(content)
    -- A frame (not just text) so the recipe item can show a tooltip and be linked.
    self.source = CreateFrame("Frame", nil, content)
    self.source:SetPoint("TOPLEFT", 12, -128)
    self.source:SetPoint("RIGHT", -12, 0)
    self.source:SetHeight(16)
    self.source.text = ns.Widgets.Text(self.source, "GameFontHighlightSmall")
    self.source.text:SetAllPoints()
    ns.Widgets.AttachTooltip(self.source, ShowItemTooltip, LinkItem, function()
        return self.recipe and self.recipe.recipeItem
    end)

    self.tools = ns.Widgets.Text(content, "GameFontHighlightSmall")
    self.tools:SetPoint("TOPLEFT", 12, -146)
    self.tools:SetPoint("RIGHT", -12, 0)
end

function RecipeDetail:BuildReagents(content)
    local divider = ns.Widgets.Divider(content)
    divider:SetPoint("TOPLEFT", 10, -166)
    divider:SetPoint("TOPRIGHT", -10, -166)

    local header = ns.Widgets.Text(content, "GameFontNormal")
    header:SetPoint("TOPLEFT", 12, -174)
    header:SetText("Reagents")

    local haveHeader = ns.Widgets.Text(content, "GameFontNormalSmall", "RIGHT")
    haveHeader:SetPoint("TOPRIGHT", -14, -176)
    haveHeader:SetText("have / need")

    self.reagentRows = {}
    for i = 1, MAX_REAGENTS do
        local row = CreateFrame("Button", nil, content)
        row:SetHeight(REAGENT_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 12, -194 - (i - 1) * REAGENT_ROW_HEIGHT)
        row:SetPoint("RIGHT", -12, 0)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 2, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        row.count = ns.Widgets.Text(row, "GameFontHighlightSmall", "RIGHT")
        row.count:SetPoint("RIGHT", -2, 0)

        row.name = ns.Widgets.Text(row, "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
        row.name:SetWordWrap(false)

        ns.Widgets.AttachTooltip(row, ShowItemTooltip, LinkItem, function(self) return self.itemID end)
        self.reagentRows[i] = row
    end

    self.noReagents = ns.Widgets.Text(content, "GameFontDisableSmall")
    self.noReagents:SetPoint("TOPLEFT", 14, -196)
    self.noReagents:SetText("No reagents.")
end

function RecipeDetail:BuildCalculator(content)
    local divider = ns.Widgets.Divider(content)
    divider:SetPoint("BOTTOMLEFT", 10, 132)
    divider:SetPoint("BOTTOMRIGHT", -10, 132)

    local header = ns.Widgets.Text(content, "GameFontNormal")
    header:SetPoint("BOTTOMLEFT", 12, 112)
    header:SetText("Calculator")

    -- Quantity: [-] [ n ] [+]
    local quantityLabel = ns.Widgets.Text(content, "GameFontHighlightSmall")
    quantityLabel:SetPoint("BOTTOMLEFT", 12, 90)
    quantityLabel:SetText("Craft")

    local minus = ns.Widgets.Button(content, "-", 22, function() self:SetQuantity(self.quantity - 1) end)
    minus:SetPoint("LEFT", quantityLabel, "RIGHT", 8, 0)

    self.quantityBox = ns.Widgets.NumberBox(content, 44, 4, function(value)
        self.quantity = Clamp(value or 1, 1, MAX_QUANTITY)
        self:UpdateDynamic()
    end)
    self.quantityBox:SetPoint("LEFT", minus, "RIGHT", 8, 0)

    local plus = ns.Widgets.Button(content, "+", 22, function() self:SetQuantity(self.quantity + 1) end)
    plus:SetPoint("LEFT", self.quantityBox, "RIGHT", 4, 0)

    local times = ns.Widgets.Text(content, "GameFontHighlightSmall")
    times:SetPoint("LEFT", plus, "RIGHT", 6, 0)
    times:SetText("times")

    self.craftable = ns.Widgets.Text(content, "GameFontHighlightSmall", "RIGHT")
    self.craftable:SetPoint("BOTTOMRIGHT", -14, 90)

    self.output = ns.Widgets.Text(content, "GameFontHighlightSmall")
    self.output:SetPoint("BOTTOMLEFT", 12, 66)
    self.output:SetPoint("RIGHT", -12, 0)

    -- Leveling: from [a] to [b]
    local levelLabel = ns.Widgets.Text(content, "GameFontHighlightSmall")
    levelLabel:SetPoint("BOTTOMLEFT", 12, 40)
    levelLabel:SetText("Level from")

    self.fromBox = ns.Widgets.NumberBox(content, 40, 3, function(value)
        self.levelFrom = value
        self:UpdateDynamic()
    end)
    self.fromBox:SetPoint("LEFT", levelLabel, "RIGHT", 10, 0)

    local toLabel = ns.Widgets.Text(content, "GameFontHighlightSmall")
    toLabel:SetPoint("LEFT", self.fromBox, "RIGHT", 6, 0)
    toLabel:SetText("to")

    self.toBox = ns.Widgets.NumberBox(content, 40, 3, function(value)
        self.levelTo = value
        self:UpdateDynamic()
    end)
    self.toBox:SetPoint("LEFT", toLabel, "RIGHT", 10, 0)

    self.useButton = ns.Widgets.Button(content, "Use as quantity", 120, function()
        if self.expectedCrafts and self.expectedCrafts > 0 then
            self:SetQuantity(self.expectedCrafts)
        end
    end)
    self.useButton:SetPoint("BOTTOMRIGHT", -12, 38)

    self.levelResult = ns.Widgets.Text(content, "GameFontHighlightSmall")
    self.levelResult:SetPoint("BOTTOMLEFT", 12, 14)
    self.levelResult:SetPoint("RIGHT", -12, 0)
end

function RecipeDetail:Create(parent)
    local panel = ns.Widgets.Panel(parent)

    self.placeholder = ns.Widgets.Text(panel, "GameFontDisable", "CENTER")
    self.placeholder:SetPoint("CENTER")
    self.placeholder:SetText("Select a recipe.")

    self.content = CreateFrame("Frame", nil, panel)
    self.content:SetAllPoints()
    self.content:Hide()

    self:BuildHeader(self.content)
    self:BuildThresholds(self.content)
    self:BuildSource(self.content)
    self:BuildReagents(self.content)
    self:BuildCalculator(self.content)

    self.quantity = 1
    return panel
end

-- Rendering ---------------------------------------------------------------------

--- Show a recipe (or nil) at a skill level (or nil when unknown).
function RecipeDetail:Show(recipe, skill)
    local recipeChanged = recipe ~= self.recipe
    local skillChanged = skill ~= self.skill
    self.recipe = recipe
    self.skill = skill

    self.placeholder:SetShown(recipe == nil)
    self.content:SetShown(recipe ~= nil)
    if not recipe then
        return
    end

    if recipeChanged then
        self.quantity = 1
    end
    if recipeChanged or skillChanged then
        self:ResetLevelRange()
    end
    self:UpdateStatic()
    self:UpdateDynamic()
end

function RecipeDetail:SetQuantity(value)
    self.quantity = Clamp(value, 1, MAX_QUANTITY)
    self:UpdateDynamic()
end

function RecipeDetail:ResetLevelRange()
    local recipe = self.recipe
    local learn = ns.RecipeService:GetLearnLevel(recipe)
    local _, green, gray = ns.SkillService:GetThresholds(recipe)
    self.levelFrom = self.skill or learn or 1
    -- Default target: green (the last stretch to gray is slow), or gray once you're past green.
    if not green then
        self.levelTo = self.levelFrom
    elseif self.levelFrom < green then
        self.levelTo = green
    else
        self.levelTo = math.max(gray, self.levelFrom)
    end
end

--- Parts that only change when the recipe or skill changes.
function RecipeDetail:UpdateStatic()
    local recipe = self.recipe
    local RecipeService, SkillService, ItemService = ns.RecipeService, ns.SkillService, ns.ItemService

    self.icon.icon:SetTexture(RecipeService:GetIcon(recipe))
    self.title:SetText(recipe.item and ItemService:GetColoredName(recipe.item) or recipe.name)

    local subtitle = {}
    if recipe.cat then subtitle[#subtitle + 1] = recipe.cat end
    if recipe.enchant then subtitle[#subtitle + 1] = "|cff71d5ff" .. recipe.enchant .. "|r" end
    if recipe.item and recipe.name ~= ItemService:GetName(recipe.item) then
        subtitle[#subtitle + 1] = recipe.name
    end
    self.subtitle:SetText(table.concat(subtitle, ", "))

    -- Threshold cells
    local learn = RecipeService:GetLearnLevel(recipe)
    local yellow, green, gray = SkillService:GetThresholds(recipe)
    local values = { learn, yellow, green, gray }
    for i, cell in ipairs(self.thresholdCells) do
        cell.value:SetText(values[i] and SkillService:Colorize(THRESHOLDS[i].key, values[i]) or "|cff666666?|r")
    end

    self.status:SetText(self:GetStatusText(learn))

    -- Source and tools
    local source = "|cffffd100Source:|r " .. RecipeService:GetSourceText(recipe)
    local _, learnSource = RecipeService:GetLearnLevel(recipe)
    if recipe.recipeItem then
        source = source .. " |cff808080(shift-click to link)|r"
    elseif learnSource == "wowhead" then
        source = source .. " |cff808080(learn level from Wowhead)|r"
    elseif not learn then
        source = source .. " |cff808080(visit the trainer once to record its level)|r"
    end
    self.source.text:SetText(source)

    if recipe.tools then
        self.tools:SetText("|cffffd100Requires:|r " .. table.concat(recipe.tools, ", "))
    else
        self.tools:SetText("|cffffd100Requires:|r |cff808080no tools|r")
    end

    self.fromBox:SetText(self.levelFrom or "")
    self.toBox:SetText(self.levelTo or "")
end

function RecipeDetail:GetStatusText(learn)
    local recipe, skill = self.recipe, self.skill
    if not ns.SkillService:GetThresholds(recipe) then
        return "|cff808080This recipe gives no skill-ups.|r"
    end
    if not skill then
        return "|cff808080Enter a skill level at the top to see your chances.|r"
    end

    local difficulty = ns.RecipeService:GetDifficulty(recipe, skill)
    if difficulty == "red" then
        return ns.SkillService:Colorize("red", ("At %d you can't learn this yet, it needs %d."):format(skill, learn))
    end
    local chance = ns.SkillService:GetSkillUpChance(recipe, skill)
    local label = difficulty:sub(1, 1):upper() .. difficulty:sub(2)
    return ("At %d it is %s, %d%% chance to skill up per craft."):format(
        skill, ns.SkillService:Colorize(difficulty, label), floor(chance * 100 + 0.5))
end

--- Parts that change with quantity, leveling inputs or bag contents.
function RecipeDetail:UpdateDynamic()
    local recipe = self.recipe
    if not recipe then
        return
    end
    local ItemService = ns.ItemService

    if not self.quantityBox:HasFocus() then
        self.quantityBox:SetText(self.quantity)
    end

    -- Reagents scaled by quantity
    local reagents = ns.RecipeService:GetReagents(recipe)
    for i, row in ipairs(self.reagentRows) do
        local reagent = reagents[i]
        row:SetShown(reagent ~= nil)
        row.itemID = reagent and reagent.id
        if reagent then
            local need = reagent.count * self.quantity
            local have = ItemService:GetCount(reagent.id)
            local color = have >= need and "40ff40" or "ff4040"
            row.icon:SetTexture(ItemService:GetIcon(reagent.id))
            row.name:SetText(("%s |cffaaaaaax%d|r"):format(ItemService:GetColoredName(reagent.id), reagent.count))
            row.count:SetText(("|cff%s%d|r / %d"):format(color, have, need))
        end
    end
    self.noReagents:SetShown(#reagents == 0)

    -- Craftable now
    local craftable = ns.RecipeService:GetCraftableCount(recipe)
    self.craftable:SetText(craftable and ("You can craft |cffffffff%d|r now"):format(craftable) or "")

    -- Output and vendor value
    if recipe.item then
        local made = (recipe.count or 1) * self.quantity
        local value = ItemService:GetSellPrice(recipe.item) * made
        self.output:SetText(("Makes |cffffffff%d|r x %s, vendors for %s"):format(
            made, ItemService:GetColoredName(recipe.item), ItemService:FormatMoney(value)))
    elseif recipe.enchant then
        self.output:SetText(("Applies |cff71d5ff%s|r %d time(s)"):format(recipe.enchant, self.quantity))
    else
        self.output:SetText("")
    end

    self.levelResult:SetText(self:GetLevelingText())
    self.useButton:SetEnabled((self.expectedCrafts or 0) > 0)
end

function RecipeDetail:GetLevelingText()
    local recipe = self.recipe
    local from, to = self.levelFrom, self.levelTo
    self.expectedCrafts = nil

    if not ns.SkillService:GetThresholds(recipe) then
        return "|cff808080No skill-ups from this recipe.|r"
    end
    if not from or not to or to <= from then
        return "|cff808080Enter a target skill higher than the start.|r"
    end

    local learn = ns.RecipeService:GetLearnLevel(recipe)
    if learn and from < learn then
        return ns.SkillService:Colorize("red", ("You need %d skill to learn this."):format(learn))
    end

    local crafts, stalledAt = ns.SkillService:GetExpectedCrafts(recipe, from, to)
    local expected = math.ceil(crafts)
    self.expectedCrafts = expected

    if stalledAt == from then
        return ns.SkillService:Colorize("gray", ("Already gray at %d, no skill-ups left."):format(from))
    elseif stalledAt then
        return ("~|cffffffff%d|r crafts on average gets you to %d, then it turns gray."):format(expected, stalledAt)
    end
    return ("~|cffffffff%d|r crafts on average to go from %d to %d."):format(expected, from, to)
end
