-- RecipeService: everything about recipes: lookup, learn levels, sources, search and filtering.
--
-- Recipe fields (see Data/Recipes.lua):
--   spell, name, min, yellow, gray, learn (Wowhead), cat, item, count, enchant, auto,
--   recipeItem, recipeReq, tools, reagents = { itemID, count, itemID, count, ... }
local _, ns = ...

local RecipeService = {}
ns.RecipeService = RecipeService

local FALLBACK_ICON = 134400

local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
local GetSpellLink = (C_Spell and C_Spell.GetSpellLink) or GetSpellLink

-- Professions -------------------------------------------------------------------

function RecipeService:GetProfessions()
    return ns.Data.professions
end

function RecipeService:GetProfession(professionID)
    for _, profession in ipairs(ns.Data.professions) do
        if profession.id == professionID then
            return profession
        end
    end
    return nil
end

--- Case-insensitive lookup by name; prefix match unless exact is set ("alch" -> Alchemy).
function RecipeService:FindProfession(text, exact)
    local needle = text:lower()
    for _, profession in ipairs(ns.Data.professions) do
        local name = profession.name:lower()
        if name == needle or (not exact and #needle >= 3 and name:sub(1, #needle) == needle) then
            return profession
        end
    end
    return nil
end

-- Recipes -----------------------------------------------------------------------

function RecipeService:GetRecipes(professionID)
    return ns.Data.recipes[professionID] or {}
end

function RecipeService:FindRecipeByName(professionID, name)
    for _, recipe in ipairs(self:GetRecipes(professionID)) do
        if recipe.name == name then
            return recipe
        end
    end
    return nil
end

--- Reagents as { { id = itemID, count = n }, ... } (cached on the recipe).
function RecipeService:GetReagents(recipe)
    if not recipe._reagents then
        local list = {}
        for i = 1, #recipe.reagents, 2 do
            list[#list + 1] = { id = recipe.reagents[i], count = recipe.reagents[i + 1] }
        end
        recipe._reagents = list
    end
    return recipe._reagents
end

--- Skill needed to learn the recipe, and where that number came from. Most reliable source first:
---   trainer  read from a trainer window in game (TrainerScanner)
---   item     the recipe item's required skill, from the client files (what the game actually checks)
---   wowhead  Wowhead's Forever database (fills in trainer recipes, which the client files lack)
---   data     SkillLineAbility minimum rank from the client files
---   auto     learned automatically with the profession
--- Returns level, source, or nil when unknown.
function RecipeService:GetLearnLevel(recipe)
    local trained = ns.db and ns.db.trainerReq[recipe.spell]
    if trained then
        return trained, "trainer"
    end
    if recipe.recipeReq and recipe.recipeReq > 0 then
        return recipe.recipeReq, "item"
    end
    if recipe.learn then
        return recipe.learn, "wowhead"
    end
    if recipe.min > 1 then
        return recipe.min, "data"
    end
    if recipe.auto then
        return 1, "auto"
    end
    return nil
end

function RecipeService:GetDifficulty(recipe, skill)
    return ns.SkillService:GetDifficulty(recipe, skill, (self:GetLearnLevel(recipe)))
end

function RecipeService:GetIcon(recipe)
    if recipe.item then
        return ns.ItemService:GetIcon(recipe.item)
    end
    return (GetSpellTexture and GetSpellTexture(recipe.spell)) or FALLBACK_ICON
end

function RecipeService:GetLink(recipe)
    if recipe.item then
        return ns.ItemService:GetLink(recipe.item)
    end
    return GetSpellLink and GetSpellLink(recipe.spell)
end

function RecipeService:ShowTooltip(owner, recipe)
    if recipe.item then
        ns.ItemService:ShowTooltip(owner, recipe.item)
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(recipe.spell)
    GameTooltip:Show()
end

function RecipeService:GetSourceText(recipe)
    if recipe.recipeItem then
        return ns.ItemService:GetColoredName(recipe.recipeItem)
    end
    if recipe.auto then
        return "Learned automatically"
    end
    return "Trainer"
end

--- How many times you can craft it right now with what's in your bags and bank.
function RecipeService:GetCraftableCount(recipe)
    local reagents = self:GetReagents(recipe)
    if #reagents == 0 then
        return nil
    end
    local craftable = math.huge
    for _, reagent in ipairs(reagents) do
        craftable = math.min(craftable, floor(ns.ItemService:GetCount(reagent.id) / reagent.count))
    end
    return craftable
end

-- Search & filter ---------------------------------------------------------------

-- Search covers recipe name, product, enchant, category and reagent names,
-- so "thorium bar" also finds everything that uses Thorium Bars.
local function GetSearchText(recipe)
    if not recipe._search then
        local parts = { recipe.name, recipe.cat or "", recipe.enchant or "" }
        if recipe.item then
            parts[#parts + 1] = ns.ItemService:GetName(recipe.item)
        end
        for _, reagent in ipairs(RecipeService:GetReagents(recipe)) do
            parts[#parts + 1] = ns.ItemService:GetName(reagent.id)
        end
        recipe._search = table.concat(parts, "\n"):lower()
    end
    return recipe._search
end

--- options: search (string), skill (number|nil), hideGray, hideTooHigh
function RecipeService:Query(professionID, options)
    local search = options.search and strtrim(options.search):lower() or ""
    local skill = options.skill
    local result = {}

    for _, recipe in ipairs(self:GetRecipes(professionID)) do
        local include = search == "" or GetSearchText(recipe):find(search, 1, true) ~= nil

        if include and skill then
            local difficulty = self:GetDifficulty(recipe, skill)
            if options.hideGray and difficulty == "gray" then
                include = false
            elseif options.hideTooHigh and difficulty == "red" then
                include = false
            end
        end

        if include then
            result[#result + 1] = recipe
        end
    end
    return result
end
