-- TrainerScanner: trainer "learn at" levels are server-side, not in the client data.
-- When you open a profession trainer, this reads the required skill of every listed recipe
-- and stores it account-wide, so the Cookbook fills in the gaps as you play.
local _, ns = ...

local TrainerScanner = {}
ns.TrainerScanner = TrainerScanner

local function ScanServices()
    local learned = 0
    for i = 1, GetNumTrainerServices() do
        local serviceName = GetTrainerServiceInfo(i)
        local skillName, skillLevel = GetTrainerServiceSkillReq(i)

        if serviceName and skillName and skillLevel and skillLevel > 0 then
            local profession = ns.RecipeService:FindProfession(skillName, true)
            local recipe = profession and ns.RecipeService:FindRecipeByName(profession.id, serviceName)
            if recipe and ns.db.trainerReq[recipe.spell] ~= skillLevel then
                ns.db.trainerReq[recipe.spell] = skillLevel
                learned = learned + 1
            end
        end
    end
    return learned
end

function TrainerScanner:Scan()
    if not ns.db or not (GetNumTrainerServices and GetTrainerServiceInfo and GetTrainerServiceSkillReq) then
        return
    end
    local ok, learned = pcall(ScanServices)
    if ok and learned > 0 then
        ns.Print(("noted the skill requirement for %d recipe(s) from this trainer."):format(learned))
        ns.MainFrame:Refresh()
    end
end

ns.On("TRAINER_SHOW", function() TrainerScanner:Scan() end)
ns.On("TRAINER_UPDATE", function() TrainerScanner:Scan() end)
