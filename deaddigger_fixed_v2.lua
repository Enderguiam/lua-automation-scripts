--[[
# Script Name:   DeadDigger™
# Description:  <Digger Helper>
# Autor:        <Dead (dea.d - Discord)>
# Version:      <3.5>
# Datum:        <2024.03.11>
--]]

local version = "3.5"
print("Run DeadDigger " .. version)

local API = require("api")
local UTILS = require("utils")

API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)

--#region User Inputs
local cartName = "Materials cart"

local soilboxCapacity = 100
--#endregion

--#region Imgui Setup
local imguiBackground = API.CreateIG_answer()
imguiBackground.box_name = "imguiBackground"
imguiBackground.box_start = FFPOINT.new(16, 20, 0)
imguiBackground.box_size = FFPOINT.new(400, 116, 0)

local getTargetBtn = API.CreateIG_answer()
getTargetBtn.box_name = "Get"
getTargetBtn.box_start = FFPOINT.new(16, 20, 0)
getTargetBtn.box_size = FFPOINT.new(50, 30, 0)
getTargetBtn.tooltip_text = "Populate hotspots list"

local setTargetBtn = API.CreateIG_answer()
setTargetBtn.box_name = "Set"
setTargetBtn.box_start = FFPOINT.new(60, 20, 0)
setTargetBtn.box_size = FFPOINT.new(50, 30, 0)
setTargetBtn.tooltip_text = "The script excavate this spot"

local imguicombo = API.CreateIG_answer()
imguicombo.box_name = "Hotspots     "
imguicombo.box_start = FFPOINT.new(100, 20, 0)
imguicombo.stringsArr = { "a", "b" }
imguicombo.tooltip_text = "Available hotspots to target"

local imguiCurrentTarget = API.CreateIG_answer()
imguiCurrentTarget.box_name = "Current Target:"
imguiCurrentTarget.box_start = FFPOINT.new(30, 50, 0)

local imguiExcavate = API.CreateIG_answer()
imguiExcavate.box_name = "Excavate"
imguiExcavate.box_start = FFPOINT.new(18, 60, 0)
imguiExcavate.box_size = FFPOINT.new(80, 30, 0)
imguiExcavate.tooltip_text = "Start/Stop Excavating"

local imguiTerminate = API.CreateIG_answer()
imguiTerminate.box_name = "Stop Script"
imguiTerminate.box_start = FFPOINT.new(100, 60, 0)
imguiTerminate.box_size = FFPOINT.new(100, 30, 0)
imguiTerminate.tooltip_text = "Exit the script"

local imguiRuntime = API.CreateIG_answer()
imguiRuntime.box_name = "imguiRuntime"
imguiRuntime.box_start = FFPOINT.new(30, 90, 0)

local imguiDestroy = API.CreateIG_answer()
imguiDestroy.box_name = "Destroy Artifacts"
imguiDestroy.tooltip_text = "Destroying: false"
imguiDestroy.box_start = FFPOINT.new(200, 60, 0)

local imguiBank = API.CreateIG_answer()
imguiBank.box_name = "Bank Artifacts"
imguiBank.tooltip_text = "Banking: false"
imguiBank.box_start = FFPOINT.new(200, 80, 0)
--#endregion

--#region Variables init
local targetPlaceholder = "None. Click Set Hotspot"
local startTime, lastXpTime, afk = os.time(), os.time(), os.time()
local skillName = "ARCHAEOLOGY"
local currentXp = 0
local MAX_IDLE_TIME_MINUTES = 5
local depositAttempt = 0
local artifactsFound = 0
local soilBoxFull = false
local shouldBank = false
local shouldDestroy = false
local target = targetPlaceholder
local runLoop = false
local targetNotFoundCount = 0
local targets = {}
local GOTE = 44550
local selectedTarget
local COLORS = {
    BACKGROUND = ImColor.new(10, 13, 29),
    TARGET_UNSET = ImColor.new(189, 185, 167),
    TARGET_SET = ImColor.new(70, 143, 126),
    EXCAVATE = ImColor.new(84, 166, 102),
    PAUSED = ImColor.new(238, 59, 83),
    RUNTIME = ImColor.new(198, 120, 102)
}

imguiBackground.colour = COLORS.BACKGROUND
imguiCurrentTarget.colour = COLORS.TARGET_UNSET
imguiRuntime.colour = COLORS.EXCAVATE
--#endregion

--#region Util functions

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function formatElapsedTime(start)
    local currentTime = os.time()
    local elapsedTime = currentTime - start
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("Runtime: %02d:%02d:%02d", hours, minutes, seconds)
end

local function gameStateChecks()
    local gameState = API.GetGameState2()
    if (gameState ~= 3) then
        API.logError('Not ingame with state: ' .. tostring(gameState))
        print('Not ingame with state: ' .. tostring(gameState))
        API.Write_LoopyLoop(false)
        return
    end
    if targetNotFoundCount > 30 then
        imguiExcavate.box_name = "Excavate"
        runLoop = false
        API.Write_LoopyLoop(false)
    end
end

local function terminate()
    runLoop = false
    API.Write_LoopyLoop(false)
end

--#endregion

local DIGSITES = {
    EVERLIGHT = {
        SOIL = { ID = 49519, VB = 9371, NAME = "Saltwater mud" },
        PRODROMOI = { LABEL = "Prodromoi remains", ID = { 116661 }, LEVEL = 42 },
        MONOCEROS = { LABEL = "Monoceros remains", ID = { 116663 }, LEVEL = 48 },
        AMPHITHEATER = { LABEL = "Amphitheatre debris", ID = { 116665 }, LEVEL = 51 },
        CERAMICS = { LABEL = "Ceramics studio debris", ID = { 116666, 116667 }, LEVEL = 56 },
        STADIO = { LABEL = "Stadio debris", ID = { 116669 }, LEVEL = 61 },
        DOMINION = { LABEL = "Dominion Games podium", ID = { 116671 }, LEVEL = 69 },
        OIKOS_STUDIO = { LABEL = "Oikos studio debris", ID = { 116673 }, LEVEL = 72 },
        OIKOS_HUT = { LABEL = "Oikos fishing hut remnants", ID = { 116675 }, LEVEL = 84 },
        ACROPOLIS = { LABEL = "Acropolis debris", ID = { 116677 }, LEVEL = 92 },
        ICYENE = { LABEL = "Icyene weapon rack", ID = { 116679 }, LEVEL = 100 },
        STOCKPILED_ART = { LABEL = "Stockpiled art", ID = { 116683 }, LEVEL = 105 },
        BIBLIOTHEKE = { LABEL = "Bibliotheke debris", ID = { 116680, 116681 }, LEVEL = 109 },
        OPTIMATOI = { LABEL = "Optimatoi remains", ID = { 116685 }, LEVEL = 117 }
    },
    INFERNAL = {
        SOIL = { ID = 49521, VB = 9372, NAME = "Fiery brimstone" },
        LODGE_BAR = { LABEL = "Lodge bar storage", ID = { 116817 }, LEVEL = 20 },
        LODGE_ART = { LABEL = "Lodge art storage", ID = { 116819 }, LEVEL = 24 },
        CULTIST = { LABEL = "Cultist footlocker", ID = { 116821 }, LEVEL = 29 },
        SACRIFICIAL = { LABEL = "Sacrificial altar", ID = { 116823 }, LEVEL = 36 },
        DIS_DUNGEON = { LABEL = "Dis dungeon debris", ID = { 116825 }, LEVEL = 45 },
        INFERNAL = { LABEL = "Infernal art", ID = { 116827 }, LEVEL = 65 },
        SHAKROTH = { LABEL = "Shakroth remains", ID = { 116829 }, LEVEL = 68 },
        ANIMAL_TROPHIES = { LABEL = "Animal trophies", ID = { 116831 }, LEVEL = 81 },
        DIS_OVERSPILL = { LABEL = "Dis overspill", ID = { 116833 }, LEVEL = 89 },
        BYZROTH = { LABEL = "Byzroth remains", ID = { 116835 }, LEVEL = 98 },
        HELLFIRE_FORGE = { LABEL = "Hellfire forge", ID = { 116839 }, LEVEL = 104 },
        CHTHONIAN = { LABEL = "Chthonian trophies", ID = { 116837 }, LEVEL = 110 },
        TSUTSAROTH = { LABEL = "Tsutsaroth remains", ID = { 116841 }, LEVEL = 116 }
    },
    KHARID = {
        SOIL = { ID = 49517, VB = 9370, NAME = "Ancient gravel" },
        VENATOR = { LABEL = "Venator remains", ID = { 117101 }, LEVEL = 5 },
        LEGIONARY = { LABEL = "Legionary remains", ID = { 117103 }, LEVEL = 12 },
        FORT = { LABEL = "Fort debris", ID = { 116921, 116922, 116923, 116924 }, LEVEL = 12 },
        CASTRA = { LABEL = "Castra debris", ID = { 117106 }, LEVEL = 12 },
        ADMINISTRATUM = { LABEL = "Administratum debris", ID = { 117108 }, LEVEL = 25 },
        PRAESIDIO = { LABEL = "Praesidio remains", ID = { 117110 }, LEVEL = 47 },
        CARCERUM = { LABEL = "Carcerem debris", ID = { 117112 }, LEVEL = 58 },
        CHAPEL = { LABEL = "Kharid-et chapel debris", ID = { 117114 }, LEVEL = 74 },
        PONTIFEX = { LABEL = "Pontifex remains", ID = { 117116 }, LEVEL = 81 },
        ORCUS_ALTAR = { LABEL = "Orcus altar", ID = { 117118 }, LEVEL = 86 },
        ARMARIUM = { LABEL = "Armarium debris", ID = { 117120 }, LEVEL = 93 },
        CULINARUM = { LABEL = "Culinarum debris", ID = { 117122, 119386 }, LEVEL = 100 },
        ANCIENT = { LABEL = "Ancient magick munitions", ID = { 117124 }, LEVEL = 107 },
        PRAETORIAN = { LABEL = "Praetorian remains", ID = { 117126 }, LEVEL = 114 },
        WAR = { LABEL = "War table debris", ID = { 117128 }, LEVEL = 118 }
    },
    ORTHEN = {
        SOIL = { ID = 50696, VB = 9578, NAME = "Volcanic ash" },
        VARANUSAUR = { LABEL = "Varanusaur remains", ID = { 119075 }, LEVEL = 90 },
        RELIQUARY = { LABEL = "Dragonkin reliquary", ID = { 119077 }, LEVEL = 96 },
        COFFIN = { LABEL = "Dragonkin coffin", ID = { 119079 }, LEVEL = 99 },
        AUTOPSY = { LABEL = "Autopsy table", ID = { 119081 }, LEVEL = 101 },
        EXPERIMENT = { LABEL = "Experiment workbench", ID = { 119083 }, LEVEL = 102 },
        AUGHRA = { LABEL = "Aughra remains", ID = { 119085 }, LEVEL = 106 },
        MOKSHA = { LABEL = "Moksha device", ID = { 119087 }, LEVEL = 108 },
        MINE = { LABEL = "Xolo mine", ID = { 119089 }, LEVEL = 113 },
        REMAINS = { LABEL = "Xolo remains", ID = { 119091 }, LEVEL = 119 },
        SAURTHEN = { LABEL = "Saurthen debris", ID = { 119093 }, LEVEL = 120 }
    },
    SENNTISTEN = {
        SOIL = { ID = 49517, VB = 9370, NAME = "Ancient gravel" },
        MINISTRY = { LABEL = "Ministry remains", ID = { 121157 }, LEVEL = 60 },
        CATHEDRAL = { LABEL = "Cathedral debris", ID = { 121155 }, LEVEL = 62 },
        MARKETPLACE = { LABEL = "Marketplace debris", ID = { 121159 }, LEVEL = 63 },
        INQUISITOR = { LABEL = "Inquisitor remains", ID = { 121161 }, LEVEL = 64 },
        GLADIATOR = { LABEL = "Gladiator remains", ID = { 121165 }, LEVEL = 66 },
        CITIZEN = { LABEL = "Citizen remains", ID = { 121163 }, LEVEL = 67 }
    },
    STORMGUARD = {
        SOIL = { ID = 49523, VB = 9373, NAME = "Aerated sediment" },
        IKOVIAN = { LABEL = "Ikovian memorial", ID = { 117202 }, LEVEL = 70 },
        KESHIK = { LABEL = "Keshik ger", ID = { 117204 }, LEVEL = 76 },
        TAILORY = { LABEL = "Tailory debris", ID = { 117206 }, LEVEL = 81 },
        WEAPONS = { LABEL = "Weapons research debris", ID = { 117208 }, LEVEL = 85 },
        GRAVITRON = { LABEL = "Gravitron research debris", ID = { 117210 }, LEVEL = 91 },
        TOWER = { LABEL = "Keshik tower debris", ID = { 117214 }, LEVEL = 95 },
        GOLEM = { LABEL = "Destroyed golem", ID = { 117216 }, LEVEL = 98 },
        RACK = { LABEL = "Keshik weapon rack", ID = { 117218 }, LEVEL = 103 },
        FLIGHT = { LABEL = "Flight research debris", ID = { 117212 }, LEVEL = 108 }
    }
}

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function formatElapsedTime(start)
    local currentTime = os.time()
    local elapsedTime = currentTime - start
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("Runtime: %02d:%02d:%02d", hours, minutes, seconds)
end

local function gameStateChecks()
    local gameState = API.GetGameState2()
    if (gameState ~= 3) then
        API.logError('Not ingame with state: ' .. tostring(gameState))
        print('Not ingame with state: ' .. tostring(gameState))
        API.Write_LoopyLoop(false)
        return
    end
    if targetNotFoundCount > 30 then
        imguiExcavate.box_name = "Excavate"
        runLoop = false
        API.Write_LoopyLoop(false)
    end
end

local function terminate()
    runLoop = false
    API.Write_LoopyLoop(false)
end

local function doLoop()
    if not API.Read_LoopyLoop() then return end
    gameStateChecks()
    if runLoop then
        idleCheck()
    end
end

API.Write_LoopyLoop(true)
while API.Read_LoopyLoop() do
    doLoop()
    API.RandomSleep2(500, 200, 200)
end
