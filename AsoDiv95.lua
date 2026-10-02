local API = require("api")
local UTILS = require("utils")

local CanRenewal = {
    muspah = true
}

startTime, afk = os.time(), os.time()
MAX_IDLE_TIME_MINUTES = 15

local IDS = {
    CHRONICLE = { 18205, 51489 },
    RIFTS = { 87306, 93489 },

    ENRICHED_SPRING = {
        18152,18175,18154,18177,18156,18179,18158,18181,
        18160,18183,18162,18185,18164,18187,18166,18189,
        18168,18191,18170,18193,18172,18195,13615,13617
    },

    SPRING = {
        18173,18174,18176,18178,18180,18182,18184,
        18186,18188,18190,18192,18194,13616
    },

    WISPS = {
        18150,18151,18153,18155,18157,18159,18161,
        18163,18165,18167,18169,18171,13614
    }
}


-- =========================
-- FIND NPC
-- =========================
local function foundNPC(ids)
    return API.GetAllObjArray1(ids, 50, {1})[1] ~= nil
end


-- =========================
-- MUSPAH
-- =========================
local MUSPAH_BUFF_ID    = 26095
local MUSPAH_POUCH_ID   = 31328
local SUPER_RESTORE_ID = { 23399, 23401, 23403, 23405, 23407, 23409 }
local lastMuspahAttempt = 0
local MUSPAH_COOLDOWN   = 10  -- segundos entre tentativas

local function muspahBuffActive()
    -- Tenta a Buffbar API (mais confiável para buffs de summon)
    local buff = API.Buffbar_GetIDstatus(MUSPAH_BUFF_ID, false)
    if buff and buff.found then return true end

    -- Fallback: verifica via GetAllObjArray1 tipo 4 (buff/debuff objects)
    if API.GetAllObjArray1({MUSPAH_BUFF_ID}, 100, {4})[1] ~= nil then return true end

    return false
end

local function muspahCheck()
    if CanRenewal.muspah then
        if not API.Buffbar_GetIDstatus(MUSPAH_BUFF_ID, false).found then
            -- Tenta beber a super restore
            if not API.DoAction_Inventory2(SUPER_RESTORE_ID, 0, 1, API.OFF_ACT_GeneralInterface_route) then
                API.printlua("No super restore found in inventory.", 2, false)
                CanRenewal.muspah = false
            else
                API.printlua("Bebendo Super restore", 7, false)
                API.RandomSleep2(600, 200, 200)
                -- Se bebeu a restore, usa a bolsa
                if not API.DoAction_Inventory1(MUSPAH_POUCH_ID, 0, 1, API.OFF_ACT_GeneralInterface_route) then
                    API.printlua("No nightmare muspah pouch found in inventory.", 2, false)
                    CanRenewal.muspah = false
                else
                    API.printlua("Usando Nightmare muspah pouch", 7, false)
                    API.RandomSleep2(1200, 300, 300)
                end
            end
        end
    end
end

-- =========================
-- GATHER
-- =========================
local function gather()
    if Inventory:IsFull() then return end

    local isAnimating = API.CheckAnim(25)

    -- 1. PRIORIDADE MÁXIMA: ENRICHED
    if foundNPC(IDS.ENRICHED_SPRING) then
        local currentTarget = API.ReadLpInteracting()
        -- Se o nosso alvo atual já for uma mola enriquecida, não faz nada (mesmo que a animação pare)
        if currentTarget.Id > 0 and UTILS.tableIncludes(IDS.ENRICHED_SPRING, currentTarget.Id) then
            return
        end

        -- Se não estamos coletando nada, clica na Enriched
        if not isAnimating then
            API.printlua("Coletando Enriched Spring", 7, false)
            API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, IDS.ENRICHED_SPRING, 10)
            UTILS.countTicks(3)
            return
        end
    end

    -- 2. SEM ENRICHED: verifica se já está ocupado
    if isAnimating or API.ReadPlayerMovin2() then
        return
    end

    -- 3. COLETA NORMAL
    if foundNPC(IDS.SPRING) then
        API.printlua("Coletando Spring normal", 7, false)
        API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, IDS.SPRING, 50)
        UTILS.countTicks(3)

    elseif foundNPC(IDS.WISPS) then
        API.printlua("Coletando Wisp", 7, false)
        API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, IDS.WISPS, 50)
        UTILS.countTicks(3)
    end
end

-- =========================
-- DUMP (RIFT)
-- =========================
local function dunkmaster()
    if not Inventory:IsFull() then return end

    API.printlua("Descarregando no Rift", 7, false)
    if API.DoAction_Object_string1(0xc8, API.OFF_ACT_GeneralObject_route0, { "Energy rift", "Energy Rift" }, 50, true) then
        
        local timeout = os.time() + 15
        local lastCount = Inventory:InvItemcount_String("memory")

        while API.Read_LoopyLoop() do
            API.RandomSleep2(400,200,200)

            local current = Inventory:InvItemcount_String("memory")

            -- terminou de descarregar
            if current == 0 then break end

            -- travou (não está reduzindo)
            if current == lastCount and not API.ReadPlayerAnim() then
                -- tenta clicar de novo
                API.printlua("Tentando descarregar novamente no Rift", 7, false)
                API.DoAction_Object_string1(0xc8, API.OFF_ACT_GeneralObject_route0, { "Energy rift", "Energy Rift" }, 50, true)
            end

            lastCount = current

            if os.time() > timeout then break end
        end
    end
end

-- =========================
-- LOOP
-- =========================
API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)
API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do
    

    muspahCheck()
    gather()
    dunkmaster()

    API.RandomSleep2(600, 200, 200)
end