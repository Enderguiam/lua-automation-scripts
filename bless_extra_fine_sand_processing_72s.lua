-- Bless Extra Fine Sand (processing-based, tuned)
-- Clicks Extra Fine Sand (ID 48674) and waits for processing to start/end via API.isProcessing().
-- Tuned for ~72s blessing duration.

local API = require("api")
local player = API.GetLocalPlayerName()

local SAND_ID = 48674

local START_PROCESS_TIMEOUT = 6
local PROCESS_TIMEOUT = 85
local EXTRA_PROCESS_TIMEOUT = 120

local LOOP_COOLDOWN_MS = 250
local ACTION_COOLDOWN_MS = 600
local MAX_FAILS = 12

local fails = 0

local function sleep(ms)
    API.RandomSleep2(ms, math.floor(ms * 0.3), math.floor(ms * 0.3))
end

local function waitUntil(fn, timeoutSec)
    local start = os.time()
    while API.Read_LoopyLoop() and (os.time() - start) < timeoutSec do
        if fn() then return true end
        sleep(200)
    end
    return false
end

local function waitWhileProcessing(timeoutSec)
    local start = os.time()
    while API.Read_LoopyLoop() and (os.time() - start) < timeoutSec do
        if not API.isProcessing() then
            return true
        end
        sleep(250)
    end
    return false
end

local function blessOnce()
    API.DoAction_Inventory1(SAND_ID, 0, 1, API.OFF_ACT_GeneralInterface_route)
    sleep(150)

    if not waitUntil(API.isProcessing, START_PROCESS_TIMEOUT) then
        return false
    end

    if waitWhileProcessing(PROCESS_TIMEOUT) then
        return true
    end

    if API.isProcessing() then
        return waitWhileProcessing(EXTRA_PROCESS_TIMEOUT)
    end

    return false
end

API.SetDrawLogs(true)
API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    sleep(LOOP_COOLDOWN_MS)

    if API.IsPlayerAnimating_(player, 2) or API.ReadPlayerMovin2() then
        goto continue
    end

    local ok = blessOnce()
    if ok then
        fails = 0
    else
        if API.isProcessing() then
            waitWhileProcessing(EXTRA_PROCESS_TIMEOUT)
        end

        fails = fails + 1
        sleep(1500)

        if fails >= MAX_FAILS then
            API.logError("Too many failures while trying to bless Extra Fine Sand. Stopping for safety.")
            API.Write_LoopyLoop(false)
            break
        end
    end

    sleep(ACTION_COOLDOWN_MS)

::continue::
end
