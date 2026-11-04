stds.wow = { read_globals = dofile("tools/luacheck_globals.lua") }

std = "lua51+wow"
globals = { "StuffPlannerDB", "StuffPlannerCharDB", "SLASH_STUFFPLANNER1", "StuffPlanner_OnAddonCompartmentClick" }
exclude_files = { "StuffPlanner/Libs/**", "StuffPlanner_Data/**", "tests/fixtures/data/**", ".lua/**", ".venv/**" }

files["StuffPlanner/Engine/**"] = { std = "lua51" }
files["tests/**"] = { std = "lua51+wow+busted" }
-- Langues générées par tools/gen_locales.py : une chaîne par ligne, longueur libre.
for _, locale in ipairs({ "deDE", "esES", "esMX", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }) do
    files["StuffPlanner/Locales/" .. locale .. ".lua"] = { max_line_length = false }
end
