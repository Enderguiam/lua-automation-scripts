local API = require("api")
local UTILS = require("utils")

-- verifica se está ocupado
local function isBusy()
    return API.CheckAnim(20) or API.isProcessing() or API.ReadPlayerMovin()
end

-- apertar Q (otimizado)
local function pressQ()
    API.KeyboardPress2(0x51, 60, 40) -- Q
    UTILS.randomSleep(300)
end

-- apertar SPACE (otimizado)
local function pressSpace()
    API.KeyboardPress2(0x20, 60, 40) -- SPACE
    UTILS.randomSleep(300)
end

-- carregar preset (otimizado)
local function loadPreset()
    pcall(function()
        Interact:Object("Bank chest", "Load Last Preset from", nil, 15)
    end)
    UTILS.randomSleep(300)
end

-- checar inventário cheio
local function isInventoryFull()
    local inv = API.Container_Get_all(93)

    local count = 0
    for i, item in ipairs(inv) do
        if item.item_id ~= -1 then
            count = count + 1
        end
    end

    return count >= 28
end

-- estados
local state = "NEED_LOAD"

while API.Read_LoopyLoop() do

    if state == "NEED_LOAD" then
        if not isBusy() then
            loadPreset()

            -- Pequeno wait adicional para garantir que o inventário atualizou
            API.RandomSleep2(200, 100, 100)

            -- verifica se carregou itens
            if not isInventoryFull() then
                API.printlua("Sem recursos, encerrando script.")
                API.Write_LoopyLoop(false)
                return
            end

            state = "NEED_Q"
        end

    elseif state == "NEED_Q" then
        if not isBusy() then
            pressQ()
            state = "NEED_START"
        end

    elseif state == "NEED_START" then
        if not isBusy() then
            pressSpace()
            state = "PRODUCING"
        end

    elseif state == "PRODUCING" then
        -- espera terminar produção
        if not isBusy() then
            state = "NEED_LOAD"
        end
    end

    -- Loop principal muito mais rápido (50-100ms)
    UTILS.randomSleep(300)
end