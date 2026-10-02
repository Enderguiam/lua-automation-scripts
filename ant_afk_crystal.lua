local API = require("api")

-- intervalo para pressionar U (em segundos)
local U_INTERVAL = 270

local lastU = os.time()

API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do
    local now = os.time()

    if os.difftime(now, lastU) >= U_INTERVAL then
        API.TypeOnkeyboard("u")
        lastU = now
    end

    API.RandomSleep2(1200, 500, 1000)
end
