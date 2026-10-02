local API = require("api")
local UTILS = require("utils")

local function isBusy()
    return API.CheckAnim(20) or API.isProcessing() or API.ReadPlayerMovin()
end

local function isInterfaceOpen()
    return API.Compare2874Status(18)
end

local function startCraft()
    API.KeyboardPress2(0x20, 100, 50)
end

local function loadPreset()
    pcall(function()
        Interact:Object("Bank chest", "Load Last Preset from", nil, 15)
    end)
    API.RandomSleep2(1200, 0, 400)
end

local function clickRange()
    pcall(function()
        Interact:Object("Range", "Cook-at", nil, 15)
    end)
    API.RandomSleep2(600, 0, 250)
end

local pressedSpace = false

while API.Read_LoopyLoop() do
    if isInterfaceOpen() then
        if not pressedSpace then
            startCraft()
            pressedSpace = true
            API.RandomSleep2(300, 0, 200)
        end
    else
        pressedSpace = false

        if not isBusy() then
            loadPreset()
            clickRange()
        end
    end

    API.RandomSleep2(250, 0, 250)
end
