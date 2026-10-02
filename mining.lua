--@discord/jkl0
--credit to @Prolacrush for his findEntity function

local API = require("api")

-- =============================================
-- CONFIGURAÇÕES
-- =============================================

local GOTE        = 44550
local PORTERS     = { 51490, 29285, 29283, 29281, 29279, 29277, 29275 }
local MAX_IDLE_TIME_MINUTES = 5

-- =============================================
-- GUI DE SELEÇÃO DE MINÉRIO (estilo ZukMeGUI)
-- =============================================

local ORES = {
    "Adamantite rock",     "Argonite rock",       "Banite rock",
    "Bathus rock",         "Coal rock",           "Copper rock",
    "Crystal-flecked sandstone",
    "Dark animica rock",   "Drakolith rock",      "Fractite rock",
    "Gorgonite rock",      "Iron rock",           "Katagon rock",
    "Kratonium rock",      "Light animica rock",  "Luminite rock",
    "Marmaros rock",       "Mineral deposit",     "Mithril rock",
    "Necrite rock",        "Novite rock",         "Orichalcite rock",
    "Phasmatite rock",     "Porcelain clay rock", "Prifddinas gem rock",
    "Promethium rock",     "Red sandstone",       "Runite rock",         "Tin rock",
    "Uncommon gem rock",   "Zephyrium rock",
}

local MINE = {
    dark   = { 0.05, 0.07, 0.05 },
    medium = { 0.10, 0.18, 0.10 },
    light  = { 0.22, 0.42, 0.22 },
    bright = { 0.35, 0.65, 0.30 },
    glow   = { 0.55, 0.90, 0.45 },
}

local GUI = {
    open        = true,
    started     = false,
    cancelled   = false,
    oreIndex    = 0,
}

local function drawGUI()
    ImGui.SetNextWindowSize(360, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)

    ImGui.PushStyleColor(ImGuiCol.WindowBg,       MINE.dark[1],       MINE.dark[2],       MINE.dark[3],       0.97)
    ImGui.PushStyleColor(ImGuiCol.TitleBg,        MINE.medium[1]*0.7, MINE.medium[2]*0.7, MINE.medium[3]*0.7, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive,  MINE.medium[1],     MINE.medium[2],     MINE.medium[3],     1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator,      MINE.light[1],      MINE.light[2],      MINE.light[3],      0.4)
    ImGui.PushStyleColor(ImGuiCol.FrameBg,        MINE.medium[1]*0.8, MINE.medium[2]*0.8, MINE.medium[3]*0.8, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, MINE.light[1]*0.8,  MINE.light[2]*0.8,  MINE.light[3]*0.8,  1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive,  MINE.bright[1]*0.6, MINE.bright[2]*0.6, MINE.bright[3]*0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.CheckMark,      MINE.glow[1],       MINE.glow[2],       MINE.glow[3],       1.0)
    ImGui.PushStyleColor(ImGuiCol.Header,         MINE.medium[1],     MINE.medium[2],     MINE.medium[3],     0.8)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered,  MINE.light[1],      MINE.light[2],      MINE.light[3],      1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive,   MINE.bright[1],     MINE.bright[2],     MINE.bright[3],     1.0)
    ImGui.PushStyleColor(ImGuiCol.Text,           1.0, 1.0, 1.0, 1.0)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding,  14, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing,    6,  5)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding,  4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)

    local title = "Mining AIO - " .. API.ScriptRuntimeString() .. "###MiningAIO"
    local visible = ImGui.Begin(title, 0)

    if visible then
        ImGui.PushStyleColor(ImGuiCol.Text, MINE.glow[1], MINE.glow[2], MINE.glow[3], 1.0)
        ImGui.TextWrapped("Selecione o Minerio")
        ImGui.PopStyleColor(1)

        ImGui.PushStyleColor(ImGuiCol.Text, 0.70, 0.80, 0.65, 1.0)
        ImGui.TextWrapped("Escolha qual rocha deseja minerar.")
        ImGui.PopStyleColor(1)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        ImGui.PushItemWidth(-1)
        local changed, newIdx = ImGui.Combo("##oreSelect", GUI.oreIndex, ORES, #ORES)
        if changed then GUI.oreIndex = newIdx end
        ImGui.PopItemWidth()

        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Text, 0.75, 0.75, 0.75, 1.0)
        ImGui.TextWrapped("Selecionado: " .. ORES[GUI.oreIndex + 1])
        ImGui.PopStyleColor(1)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Button,        MINE.light[1],    MINE.light[2],    MINE.light[3],    0.9)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, MINE.bright[1],   MINE.bright[2],   MINE.bright[3],   1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive,  MINE.glow[1]*0.8, MINE.glow[2]*0.8, MINE.glow[3]*0.8, 1.0)
        if ImGui.Button("Iniciar Mineracao##start", -1, 32) then
            GUI.started = true
            GUI.open = false
        end
        ImGui.PopStyleColor(3)

        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Button,        0.3, 0.3, 0.3, 0.4)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.4, 0.4, 0.6)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.5, 0.5, 0.5, 0.8)
        if ImGui.Button("Cancelar##cancel", -1, 26) then
            GUI.cancelled = true
            GUI.open = false
        end
        ImGui.PopStyleColor(3)

    end

    ImGui.PopStyleVar(4)
    ImGui.PopStyleColor(12)
    ImGui.End()
end

local afk    = os.time()
local player = API.GetLocalPlayerName()

local function getPorter()
    for _, id in ipairs(PORTERS) do
        if Inventory:InvItemcount(id) > 0 then
            return id
        end
    end
    return nil
end

local function chargeGOTE()
    local buffStatus        = API.Buffbar_GetIDstatus(51490, false)
    local necklaceContainer = API.Container_Get_all(94)[3]
    local porterId          = getPorter()

    if not porterId or not necklaceContainer then return end

    if necklaceContainer.item_id == GOTE then
        local rawText   = buffStatus.text or "0"
        local isK       = rawText:find("K") or rawText:find("k")
        local cleanText = rawText:gsub("[^%d%.]", "")
        local stacks    = tonumber(cleanText) or 0
        if isK then stacks = stacks * 1000 end
        if not buffStatus.found then stacks = 0 end

        if stacks <= 50 and buffStatus.found then
            print("Recarregando GOTE...")
            API.DoAction_Ability("Grace of the elves", 5, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(2000, 1000, 1000)
        end
    else
        if not buffStatus.found then
            print("Equipping new porter!")
            API.DoAction_Inventory1(porterId, 0, 2, API.OFF_ACT_GeneralInterface_route)
        end
    end
    API.RandomSleep2(500, 250, 500)
end

local function idleCheck()
    local timeDiff   = os.difftime(os.time(), afk)
    local randomTime = math.random(
        (MAX_IDLE_TIME_MINUTES * 60) * 0.6,
        (MAX_IDLE_TIME_MINUTES * 60) * 0.9
    )
    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function FindEntity(entityName, maximumDistance)
    local allNPCS = API.ReadAllObjectsArray({0, 12}, {-1}, {})
    local returnEntities = {}
    if #allNPCS > 0 then
        for _, a in pairs(allNPCS) do
            if a.Id > 0 then
                local distance = API.Math_DistanceF(a.Tile_XYZ, API.PlayerCoordfloat())
                a.Distance = distance
                if distance < maximumDistance and a.Name == entityName then
                    table.insert(returnEntities, a.Id)
                end
            end
        end
        return { entity = returnEntities }
    end
end

local function findRock(rockName)
    local isWorking = API.IsPlayerAnimating_(player, 5)
    local ore       = FindEntity(rockName, 5)
    if API.LocalPlayer_HoverProgress() <= 60 and API.LocalPlayer_HoverProgress() ~= 0 and isWorking then
        if ore and ore.entity and ore.entity[1] then
            API.DoAction_Object1(0x3a, API.OFF_ACT_GeneralObject_route0, { ore.entity[1] }, 50)
            API.RandomSleep2(3500, 3000, 12000)
        end
    end
end

local function waitForStart()
    GUI.open = true
    GUI.started = false
    GUI.cancelled = false

    ClearRender()
    DrawImGui(function()
        if GUI.open then drawGUI() end
    end)

    while API.Read_LoopyLoop() and not GUI.started do
        if not GUI.open or GUI.cancelled then
            ClearRender()
            return false
        end
        API.RandomSleep2(100, 50, 50)
    end

    return true
end

if not waitForStart() then
    print("Script cancelado.")
    return
end

ClearRender()

local rockName = ORES[GUI.oreIndex + 1]
print("Iniciando mineracao de: " .. rockName)

while API.Read_LoopyLoop() do
    chargeGOTE()
    findRock(rockName)
    API.DoRandomEvents()
    idleCheck()
    API.SetDrawTrackedSkills(true)
    API.RandomSleep2(200, 100, 100)
end

ClearRender()
