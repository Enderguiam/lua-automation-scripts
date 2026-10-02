local API = require("api")

-- intervalo para pressionar U (em segundos)
local U_INTERVAL = 270 -- 4 minutos e 30 segundos

-- marca o último momento em que U foi pressionado
local lastU = os.time()

-- liga o loop
API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do
    local now = os.time()

    -- pressiona U a cada 4m30s
    if os.difftime(now, lastU) >= U_INTERVAL then
        API.TypeOnkeyboard("u")
        lastU = now
    end

    API.RandomSleep2(1200, 500, 1000)
end
