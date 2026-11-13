-- CONTRAT
-- Contenu du panneau d'aide (UI/HelpPanel.lua) : gestes puis commandes. Pur : aucun appel d'API.
--   ns.HelpPresenter.build(commands) -> {{title, lines = {{key, text}...}}...}
--     commands = ns:Commands() ({{name, help}...} triées) ; les commandes de même aide sont réunies sur
--     une ligne (« /splan config, /splan options ») ; section des commandes absente si la liste est vide
-- Sections : lignes d'objet, cadre flottant, dans le jeu (info-bulles, pastilles, halo, profils), commandes.

local _, ns = ...

local L = ns.L

local HelpPresenter = {}
ns.HelpPresenter = HelpPresenter

local GESTURES = {
    { "HELP_SECTION_ROWS", {
        { "HELP_KEY_CLICK", "HELP_DO_DETAIL" },
        { "HELP_KEY_RIGHT", "HELP_DO_MENU" },
        { "HELP_KEY_STAR", "HELP_DO_PIN" },
        { "HELP_KEY_SHIFT", "HELP_DO_LINK" },
        { "HELP_KEY_CTRL", "HELP_DO_DRESS" },
    } },
    { "HELP_SECTION_HUD", {
        { "HELP_KEY_TITLE", "HELP_DO_NEXT_MODE" },
        { "HELP_KEY_TITLE_RIGHT", "HELP_DO_COLLAPSE" },
        { "HELP_KEY_DRAG", "HELP_DO_MOVE" },
    } },
    { "HELP_SECTION_GAME", {
        { "HELP_KEY_TOOLTIP", "HELP_DO_TOOLTIP" },
        { "HELP_KEY_BADGE", "HELP_DO_BADGE" },
        { "HELP_KEY_HALO", "HELP_DO_HALO" },
        { "HELP_KEY_PROFILE", "HELP_DO_PROFILE" },
    } },
}

local function commandLines(commands)
    local lines, byHelp = {}, {}
    for _, command in ipairs(commands) do
        local line = byHelp[command.help]
        if line then
            line.key = line.key .. ", /splan " .. command.name
        else
            line = { key = "/splan " .. command.name, text = command.help }
            byHelp[command.help] = line
            lines[#lines + 1] = line
        end
    end
    return lines
end

function HelpPresenter.build(commands)
    local sections = {}
    for _, spec in ipairs(GESTURES) do
        local lines = {}
        for _, pair in ipairs(spec[2]) do
            lines[#lines + 1] = { key = L[pair[1]], text = L[pair[2]] }
        end
        sections[#sections + 1] = { title = L[spec[1]], lines = lines }
    end
    if #commands > 0 then
        sections[#sections + 1] = { title = L.HELP_SECTION_COMMANDS, lines = commandLines(commands) }
    end
    return sections
end
