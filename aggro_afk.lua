--@discord/jkl0
-- Aggro AFK - Buff Tracker & Maintainer

local API = require("api")

-- =============================================
-- BUFFS A RASTREAR
-- Adicione ou remova entradas conforme necessário
-- =============================================

-- IDs de todas as doses da poção de Aggression (1 a 6)
local AGGRESSION_POTION_IDS = { 37929, 37931, 37933, 37935, 37937, 37939 }

local BUFFS = {
    {
        label      = "Aggression",
        type       = "potion",
        id         = 37969,           -- ID do buff na buff bar
        enabled    = true,
        potionIds  = AGGRESSION_POTION_IDS,
        status     = "Aguardando...",
        lastUsed   = 0,
        cooldown   = 2,               -- segundos mínimos entre usos
    },
    {
        label       = "Penance",
        type        = "aura",
        id          = 35769,           -- ID do buff na buff bar quando ativo
        abilityName = "Penance",       -- nome exato da skill na action bar
        duration    = 1,               -- 1 = 12 minutos, 2 = 1 hora
        enabled     = false,
        status      = "Aguardando...",
        lastUsed    = 0,
        cooldown    = 30,
    },
    {
        label       = "Animate Dead",
        type        = "aura",
        id          = 14764,           -- ID do buff na buff bar quando ativo
        abilityName = "Animate Dead",  -- nome exato da skill na action bar
        duration    = 1,               -- 1 = 12 minutos, 2 = 1 hora
        enabled     = false,
        status      = "Aguardando...",
        lastUsed    = 0,
        cooldown    = 30,
    },
}

local MAX_IDLE_TIME_MINUTES = 5

-- =============================================
-- TEMA (igual ao MINERAÇÃO.lua)
-- =============================================

local MINE = {
    dark   = { 0.05, 0.07, 0.05 },
    medium = { 0.10, 0.18, 0.10 },
    light  = { 0.22, 0.42, 0.22 },
    bright = { 0.35, 0.65, 0.30 },
    glow   = { 0.55, 0.90, 0.45 },
}

-- =============================================
-- ESTADO DA GUI
-- =============================================

local GUI = {
    open        = true,
    started     = false,
    cancelled   = false,
    paused      = false,
    lootEnabled = true,   -- habilita/desabilita o Loot Custom automático
}

-- =============================================
-- FUNÇÕES AUXILIARES
-- =============================================

local afk = os.time()

-- Timer do Loot Custom (intervalo aleatório: 90 a 150 segundos)
local lastLootTime    = os.time()
local nextLootInterval = math.random(90, 150)

local function idleCheck()
    local timeDiff   = os.difftime(os.time(), afk)
    local randomTime = math.random(
        math.floor(MAX_IDLE_TIME_MINUTES * 60 * 0.6),
        math.floor(MAX_IDLE_TIME_MINUTES * 60 * 0.9)
    )
    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

--- Clica no botão LOOT CUSTOM da interface de loot (1622, comp 29).
local function lootCustom()
    if GUI.paused then return end
    API.DoAction_Interface(0x24, 0xffffffff, 1, 1622, 29, -1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(600, 100, 200)
    nextLootInterval = math.random(90, 150)
    lastLootTime     = os.time()
    print("[LOOT] Loot Custom executado. Próximo em " .. nextLootInterval .. "s")
end

--- Verifica se um buff está ativo pelo ID.
local function isBuffActive(id)
    local status = API.Buffbar_GetIDstatus(id, false)
    return status and status.found
end

--- Procura a poção por lista de IDs numéricos e usa a primeira encontrada.
--- Itera do menor dose (37929) ao maior (37939), usando o primeiro encontrado.
local function usePotion(potionIds)
    for _, itemId in ipairs(potionIds) do
        if Inventory:GetItemAmount(itemId) > 0 then
            API.DoAction_Inventory1(itemId, 0, 1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(1200, 400, 600)
            return true
        end
    end
    return false
end

--- Ativa uma aura pela action bar usando o nome da skill.
--- durationOption: 1 = 12 minutos (primeira opção), 2 = 1 hora (segunda opção)
local function useAura(abilityName, durationOption)
    local ab = API.GetABs_name1(abilityName)
    if ab and ab.id ~= 0 then
        -- opção 1 = ação padrão (12 min), opção 2 = segunda ação (1h)
        API.DoAction_Ability_Direct(ab, durationOption, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1500, 300, 500)
        return true
    else
        print("[AURA] Skill '" .. abilityName .. "' não encontrada na action bar.")
        return false
    end
end

-- =============================================
-- CORES DE STATUS
-- =============================================

local function statusColor(txt)
    if txt == "Ativo" then
        return MINE.glow[1], MINE.glow[2], MINE.glow[3], 1.0
    elseif txt == "Reativado!" then
        return 0.4, 0.9, 1.0, 1.0
    elseif txt:find("Sem poção") then
        return 1.0, 0.4, 0.3, 1.0
    elseif txt == "Pausado" or txt == "Aguardando..." then
        return 0.7, 0.7, 0.7, 0.8
    else
        return 1.0, 0.85, 0.3, 1.0
    end
end

-- =============================================
-- GUI PRINCIPAL (setup inicial)
-- =============================================

local function drawSetupGUI()
    ImGui.SetNextWindowSize(380, 0, ImGuiCond.Always)
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

    local title = "Aggro AFK - Setup###AggroSetup"
    local visible = ImGui.Begin(title, 0)

    if visible then
        ImGui.PushStyleColor(ImGuiCol.Text, MINE.glow[1], MINE.glow[2], MINE.glow[3], 1.0)
        ImGui.TextWrapped("Buffs a Manter Ativos")
        ImGui.PopStyleColor(1)

        ImGui.PushStyleColor(ImGuiCol.Text, 0.70, 0.80, 0.65, 1.0)
        ImGui.TextWrapped("Marque quais buffs deseja rastrear e reativar automaticamente.")
        ImGui.PopStyleColor(1)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        for i, buff in ipairs(BUFFS) do
            local chk, newVal = ImGui.Checkbox("  " .. buff.label .. "  (ID: " .. buff.id .. ")##chk" .. i, buff.enabled)
            if chk then
                BUFFS[i].enabled = newVal
            end
            ImGui.PushStyleColor(ImGuiCol.Text, 0.60, 0.70, 0.60, 1.0)
            if buff.type == "aura" then
                ImGui.TextWrapped("   Skill: " .. buff.abilityName)
                ImGui.PopStyleColor(1)
                ImGui.Indent(12)
                ImGui.PushStyleColor(ImGuiCol.Text, 0.85, 0.85, 0.85, 1.0)
                ImGui.Text("Duração:")
                ImGui.PopStyleColor(1)
                ImGui.SameLine()
                if buff.duration == 1 then
                    ImGui.PushStyleColor(ImGuiCol.Button,        MINE.bright[1],   MINE.bright[2],   MINE.bright[3],   1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, MINE.glow[1],     MINE.glow[2],     MINE.glow[3],     1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive,  MINE.glow[1]*0.8, MINE.glow[2]*0.8, MINE.glow[3]*0.8, 1.0)
                else
                    ImGui.PushStyleColor(ImGuiCol.Button,        MINE.medium[1],   MINE.medium[2],   MINE.medium[3],   0.6)
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, MINE.light[1],    MINE.light[2],    MINE.light[3],    0.8)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive,  MINE.bright[1],   MINE.bright[2],   MINE.bright[3],   1.0)
                end
                if ImGui.Button("12 min##d1_" .. i, 68, 22) then BUFFS[i].duration = 1 end
                ImGui.PopStyleColor(3)
                ImGui.SameLine()
                if buff.duration == 2 then
                    ImGui.PushStyleColor(ImGuiCol.Button,        MINE.bright[1],   MINE.bright[2],   MINE.bright[3],   1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, MINE.glow[1],     MINE.glow[2],     MINE.glow[3],     1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive,  MINE.glow[1]*0.8, MINE.glow[2]*0.8, MINE.glow[3]*0.8, 1.0)
                else
                    ImGui.PushStyleColor(ImGuiCol.Button,        MINE.medium[1],   MINE.medium[2],   MINE.medium[3],   0.6)
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, MINE.light[1],    MINE.light[2],    MINE.light[3],    0.8)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive,  MINE.bright[1],   MINE.bright[2],   MINE.bright[3],   1.0)
                end
                if ImGui.Button("1 hora##d2_" .. i, 68, 22) then BUFFS[i].duration = 2 end
                ImGui.PopStyleColor(3)
                ImGui.Unindent(12)
            else
                ImGui.TextWrapped("   IDs: " .. table.concat(buff.potionIds, ", "))
                ImGui.PopStyleColor(1)
            end
            ImGui.Spacing()
        end

        ImGui.Separator()
        ImGui.Spacing()

        local lchk, lnewVal = ImGui.Checkbox("  Loot Custom automático##lootchk", GUI.lootEnabled)
        if lchk then GUI.lootEnabled = lnewVal end
        ImGui.PushStyleColor(ImGuiCol.Text, 0.60, 0.70, 0.60, 1.0)
        ImGui.TextWrapped("   Clica em Loot Custom a cada 90-150s (requer aba de loot aberta).")
        ImGui.PopStyleColor(1)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Button,        MINE.light[1],    MINE.light[2],    MINE.light[3],    0.9)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, MINE.bright[1],   MINE.bright[2],   MINE.bright[3],   1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive,  MINE.glow[1]*0.8, MINE.glow[2]*0.8, MINE.glow[3]*0.8, 1.0)
        if ImGui.Button("Iniciar##start", -1, 32) then
            GUI.started   = true
            GUI.open      = false
            GUI.paused    = false
        end
        ImGui.PopStyleColor(3)

        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Button,        0.3, 0.3, 0.3, 0.4)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.4, 0.4, 0.6)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.5, 0.5, 0.5, 0.8)
        if ImGui.Button("Cancelar##cancel", -1, 26) then
            GUI.cancelled = true
            GUI.open      = false
        end
        ImGui.PopStyleColor(3)
    end

    ImGui.PopStyleVar(4)
    ImGui.PopStyleColor(12)
    ImGui.End()
end

-- =============================================
-- GUI DE MONITORAMENTO (loop principal)
-- =============================================

local function drawMonitorGUI()
    ImGui.SetNextWindowSize(380, 0, ImGuiCond.Always)
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

    local stateStr = GUI.paused and "  ⏸ PAUSADO" or "  ▶ ATIVO"
    local title = "Aggro AFK - " .. API.ScriptRuntimeString() .. stateStr .. "###AggroMonitor"
    local visible = ImGui.Begin(title, 0)

    if visible then
        if GUI.paused then
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.75, 0.2, 1.0)
            ImGui.TextWrapped("Script PAUSADO - clique em Retomar para continuar.")
        else
            ImGui.PushStyleColor(ImGuiCol.Text, MINE.glow[1], MINE.glow[2], MINE.glow[3], 1.0)
            ImGui.TextWrapped("Monitorando buffs ativos...")
        end
        ImGui.PopStyleColor(1)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        for i, buff in ipairs(BUFFS) do
            local chk, newVal = ImGui.Checkbox("##en" .. i, buff.enabled)
            if chk then BUFFS[i].enabled = newVal end

            ImGui.SameLine()

            local r, g, b, a = statusColor(buff.status)
            ImGui.PushStyleColor(ImGuiCol.Text, r, g, b, a)
            ImGui.Text(string.format("%-22s [%s]", buff.label, buff.status))
            ImGui.PopStyleColor(1)
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        local lchk2, lnewVal2 = ImGui.Checkbox("  Loot Custom##lootmon", GUI.lootEnabled)
        if lchk2 then GUI.lootEnabled = lnewVal2 end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if GUI.paused then
            ImGui.PushStyleColor(ImGuiCol.Button,        MINE.light[1],    MINE.light[2],    MINE.light[3],    0.9)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, MINE.bright[1],   MINE.bright[2],   MINE.bright[3],   1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive,  MINE.glow[1]*0.8, MINE.glow[2]*0.8, MINE.glow[3]*0.8, 1.0)
            if ImGui.Button("▶  Retomar##resume", -1, 30) then
                GUI.paused = false
                print("Script retomado.")
            end
            ImGui.PopStyleColor(3)
        else
            ImGui.PushStyleColor(ImGuiCol.Button,        0.45, 0.35, 0.05, 0.9)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.65, 0.50, 0.10, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.80, 0.65, 0.15, 1.0)
            if ImGui.Button("⏸  Pausar##pause", -1, 30) then
                GUI.paused = true
                print("Script pausado.")
                for i = 1, #BUFFS do BUFFS[i].status = "Pausado" end
            end
            ImGui.PopStyleColor(3)
        end

        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Button,        0.3, 0.08, 0.08, 0.6)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.5, 0.12, 0.12, 0.9)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.7, 0.15, 0.15, 1.0)
        if ImGui.Button("■  Parar Script##stop", -1, 26) then
            GUI.cancelled = true
        end
        ImGui.PopStyleColor(3)
    end

    ImGui.PopStyleVar(4)
    ImGui.PopStyleColor(12)
    ImGui.End()
end

-- =============================================
-- STARTUP: aguarda configuração e Iniciar
-- =============================================

local function waitForStart()
    GUI.open      = true
    GUI.started   = false
    GUI.cancelled = false

    ClearRender()
    DrawImGui(function()
        if GUI.open then drawSetupGUI() end
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

-- =============================================
-- LÓGICA DE MANUTENÇÃO DE BUFFS
-- =============================================

local function maintainBuffs()
    if GUI.paused then return end

    local now = os.time()

    for i, buff in ipairs(BUFFS) do
        if buff.enabled then
            local active = isBuffActive(buff.id)
            if active then
                BUFFS[i].status = "Ativo"
            else
                local elapsed = os.difftime(now, buff.lastUsed)
                if elapsed >= buff.cooldown then
                    local ok = false
                    if buff.type == "aura" then
                        print("[" .. buff.label .. "] Aura inativa. Ativando por " .. (buff.duration == 1 and "12 minutos" or "1 hora") .. "...")
                        ok = useAura(buff.abilityName, buff.duration)
                    else
                        print("[" .. buff.label .. "] Buff inativo. Aguardando para tomar poção...")
                        API.RandomSleep2(3000, 500, 4000)
                        ok = usePotion(buff.potionIds)
                    end
                    if ok then
                        BUFFS[i].status   = "Reativado!"
                        BUFFS[i].lastUsed = os.time()
                    else
                        BUFFS[i].status = buff.type == "aura" and "Sem aura!" or "Sem poção!"
                        print("[" .. buff.label .. "] Falha ao ativar.")
                    end
                end
            end
        else
            BUFFS[i].status = "Desativado"
        end
    end
end

-- =============================================
-- MAIN
-- =============================================

if not waitForStart() then
    print("Script cancelado.")
    return
end

ClearRender()
print("Aggro AFK iniciado.")

DrawImGui(function()
    drawMonitorGUI()
end)

while API.Read_LoopyLoop() do
    if GUI.cancelled then
        print("Script encerrado pelo usuário.")
        break
    end

    maintainBuffs()
    if GUI.lootEnabled and os.difftime(os.time(), lastLootTime) >= nextLootInterval then
        lootCustom()
    end
    API.DoRandomEvents()
    idleCheck()
    API.SetDrawTrackedSkills(true)
    API.RandomSleep2(800, 300, 300)
end

ClearRender()
print("Aggro AFK encerrado.")
