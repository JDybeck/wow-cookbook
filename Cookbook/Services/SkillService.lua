-- SkillService: the player's profession skill and all skill-up math.
--
-- Classic-style skill-up rules (which Forever's recipe data is built on):
--   orange  learn level .. yellow-1   -> always skills up
--   yellow  yellow .. green-1         -> chance = (gray - skill) / (gray - yellow)
--   green   green .. gray-1           -> same formula, lower chance
--   gray    gray and above            -> never skills up
-- green is not stored in the game data; it is the midpoint of yellow and gray.
local _, ns = ...

local SkillService = {}
ns.SkillService = SkillService

SkillService.COLORS = {
    red = "ff3030",    -- you can't learn it yet
    orange = "ff8040",
    yellow = "ffff00",
    green = "40bf40",
    gray = "808080",
    none = "ffffff",   -- no skill to compare against
}

-- Forever has child skill lines under each profession (e.g. 2937 "Alchemy" under 171).
local CHILD_TO_PARENT = {
    [2937] = 171, [2938] = 164, [2939] = 185, [2940] = 333, [2941] = 202, [2942] = 129,
    [2943] = 356, [2944] = 182, [2945] = 165, [2946] = 186, [2947] = 393, [2948] = 197,
}

local function MatchesProfession(skillLineID, name, profession)
    if skillLineID and (skillLineID == profession.id or CHILD_TO_PARENT[skillLineID] == profession.id) then
        return true
    end
    return name ~= nil and name == profession.name
end

local function FromModernApi(profession)
    if not (GetProfessions and GetProfessionInfo) then
        return nil
    end
    local a, b, c, d, e, f = GetProfessions()
    for _, index in pairs({ a, b, c, d, e, f }) do
        local name, _, rank, maxRank, _, _, skillLineID = GetProfessionInfo(index)
        if MatchesProfession(skillLineID, name, profession) then
            return rank, maxRank
        end
    end
    return nil
end

local function FromSkillLines(profession)
    if not (GetNumSkillLines and GetSkillLineInfo) then
        return nil
    end
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        if not isHeader and name == profession.name then
            return rank, maxRank
        end
    end
    return nil
end

--- Returns rank, maxRank for the player, or nil when the profession isn't learned.
function SkillService:GetPlayerSkill(profession)
    for _, source in ipairs({ FromModernApi, FromSkillLines }) do
        local ok, rank, maxRank = pcall(source, profession)
        if ok and rank then
            return rank, maxRank
        end
    end
    return nil
end

--- Returns yellow, green, gray, or nil when the recipe has no skill-up range.
function SkillService:GetThresholds(recipe)
    if recipe.yellow == 0 and recipe.gray == 0 then
        return nil
    end
    return recipe.yellow, floor((recipe.yellow + recipe.gray) / 2), recipe.gray
end

--- Difficulty key (see COLORS) for a recipe at a skill level.
function SkillService:GetDifficulty(recipe, skill, learnLevel)
    if not skill then
        return "none"
    end
    if learnLevel and skill < learnLevel then
        return "red"
    end
    local yellow, green, gray = self:GetThresholds(recipe)
    if not yellow then
        return "none"
    elseif skill >= gray then
        return "gray"
    elseif skill >= green then
        return "green"
    elseif skill >= yellow then
        return "yellow"
    end
    return "orange"
end

--- Chance (0..1) that one craft gives a skill point at this skill level.
function SkillService:GetSkillUpChance(recipe, skill)
    local yellow, _, gray = self:GetThresholds(recipe)
    if not yellow or skill >= gray then
        return 0
    end
    if skill < yellow then
        return 1
    end
    return (gray - skill) / (gray - yellow)
end

--- Expected number of crafts to go from one skill level to another with this recipe.
--- Returns crafts, stalledAt (the skill where it turns gray, or nil if the target is reached).
function SkillService:GetExpectedCrafts(recipe, fromSkill, toSkill)
    local crafts = 0
    for skill = fromSkill, toSkill - 1 do
        local chance = self:GetSkillUpChance(recipe, skill)
        if chance <= 0 then
            return crafts, skill
        end
        crafts = crafts + 1 / chance
    end
    return crafts, nil
end

function SkillService:Colorize(difficulty, text)
    return "|cff" .. (self.COLORS[difficulty] or "ffffff") .. text .. "|r"
end
