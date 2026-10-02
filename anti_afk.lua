-- Anti-AFK Script
-- Previne DC por inatividade usando SetMaxIdleTime (nativo) + PIdle2 como backup.

local API = require("api")

-- ============================================================
-- CONFIGURAÇÃO
-- ============================================================

local IDLE_LIMIT_MINUTES = 14   -- tempo máximo (em minutos) antes do kick (jogo usa 15-20min)
local MIN_INTERVAL        = 720  -- intervalo mínimo entre ações backup (segundos)
local MAX_INTERVAL        = 840  -- intervalo máximo entre ações backup (segundos)

-- ============================================================
-- TEMA (verde escuro — padrão dos scripts do repositório)
-- ============================================================

local C = {
    dark   = { 0.04, 0.06, 0.04 },
    medium = { 0.09, 0.16, 0.09 },
    light  = { 0.20, 0.38, 0.20 },
    bright = { 0.32, 0.60, 0.28 },
    glow   = { 0.50, 0.88, 0.40 },
    gold   = { 1.00, 0.85, 0.30 },
    red    = { 0.80, 0.20, 0.20 },
    blue   = { 0.30, 0.70, 1.00 },
}

-- ============================================================
-- ESTADO
-- ============================================================

local GUI = {
    started   = false,
    cancelled = false,
    paused    = false,
    open      = true,
}

local State = {
    status       = "Aguardando início...",
    nextAction   = 0,   -- timestamp do próximo PIdle2
    actionCount  = 0,
    lastHP       = 0,
    interval     = MIN_INTERVAL,
}

-- ============================================================
-- HELPERS
-- ============================================================

local function randomInterval()
    return math.random(MIN_INTERVAL, MAX_INTERVAL)
end

local function formatTime(secs)
    if secs <= 0 then return "agora" end
    local m = math.floor(secs / 60)
    local s = secs % 60
    if m > 0 then
        return string.format("%dm %02ds", m, s)
    else
        return string.format("%ds", s)
    end
end

local function getHP()
    local hp    = API.GetHP_()
    local hpMax = API.GetHPMax_()
    if hpMax and hpMax > 0 then
        return hp, hpMax, math.floor((hp / hpMax) * 100)
    end
    return hp, 0, 0
end

-- ============================================================
-- LÓGICA ANTI-AFK
-- ============================================================

local function doAntiAfk()
    -- Método principal: nativo da engine
    API.SetMaxIdleTime(IDLE_LIMIT_MINUTES)

    -- Backup a cada intervalo aleatório: simula micro-ação
    local now = os.time()
    if os.difftime(now, State.nextAction) >= 0 then
        API.PIdle2()
        State.actionCount = State.actionCount + 1
        State.interval    = randomInterval()
        State.nextAction  = now + State.interval
        State.status      = string.format("PIdle2 executado #%d. Próximo em %s",
                                State.actionCount, formatTime(State.interval))
        print(string.format("[Anti-AFK] Ação #%d executada. Próxima em %ds",
                State.actionCount, State.interval))
    end
end

-- ============================================================
-- GUI: SETUP (tela inicial)
-- ============================================================

local function pushTheme()
    ImGui.PushStyleColor(ImGuiCol.WindowBg,       C.dark[1],       C.dark[2],       C.dark[3],       0.97)
    ImGui.PushStyleColor(ImGuiCol.TitleBg,        C.medium[1]*0.7, C.medium[2]*0.7, C.medium[3]*0.7, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive,  C.medium[1],     C.medium[2],     C.medium[3],     1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator,      C.light[1],      C.light[2],      C.light[3],      0.4)
    ImGui.PushStyleColor(ImGuiCol.FrameBg,        C.medium[1]*0.8, C.medium[2]*0.8, C.medium[3]*0.8, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, C.light[1]*0.8,  C.light[2]*0.8,  C.light[3]*0.8,  1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive,  C.bright[1]*0.6, C.bright[2]*0.6, C.bright[3]*0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.CheckMark,      C.glow[1],       C.glow[2],       C.glow[3],       1.0)
    ImGui.PushStyleColor(ImGuiCol.Text,           1.0, 1.0, 1.0, 1.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding,  14, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing,    6,  5)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding,  4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)
end

local function popTheme(colors, vars)
    ImGui.PopStyleColor(colors or 9)
    ImGui.PopStyleVar(vars or 4)
end

local function drawSetupGUI()
    ImGui.SetNextWindowSize(360, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)
    pushTheme()

    local visible = ImGui.Begin("Anti-AFK — Configuração###AntiAfkSetup", 0)
    if visible then
        -- Título
        ImGui.PushStyleColor(ImGuiCol.Text, C.glow[1], C.glow[2], C.glow[3], 1.0)
        ImGui.Text("  Anti-AFK — Prevenção de DC por Inatividade")
        ImGui.PopStyleColor(1)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Info
        ImGui.PushStyleColor(ImGuiCol.Text, 0.75, 0.85, 0.70, 1.0)
        ImGui.TextWrapped("Método Principal:")
        ImGui.PopStyleColor(1)
        ImGui.PushStyleColor(ImGuiCol.Text, C.gold[1], C.gold[2], C.gold[3], 1.0)
        ImGui.TextWrapped("  SetMaxIdleTime(" .. IDLE_LIMIT_MINUTES .. ") — engine nativa.")
        ImGui.PopStyleColor(1)

        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Text, 0.75, 0.85, 0.70, 1.0)
        ImGui.TextWrapped("Método Backup (aleatorizado):")
        ImGui.PopStyleColor(1)
        ImGui.PushStyleColor(ImGuiCol.Text, C.gold[1], C.gold[2], C.gold[3], 1.0)
        ImGui.TextWrapped(string.format("  PIdle2() a cada %d–%ds.", MIN_INTERVAL, MAX_INTERVAL))
        ImGui.PopStyleColor(1)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Botão Iniciar
        ImGui.PushStyleColor(ImGuiCol.Button,        C.light[1],    C.light[2],    C.light[3],    0.9)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, C.bright[1],   C.bright[2],   C.bright[3],   1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive,  C.glow[1]*0.8, C.glow[2]*0.8, C.glow[3]*0.8, 1.0)
        if ImGui.Button("▶  Iniciar##start", -1, 32) then
            GUI.started = true
            GUI.open    = false
        end
        ImGui.PopStyleColor(3)

        ImGui.Spacing()

        -- Botão Cancelar
        ImGui.PushStyleColor(ImGuiCol.Button,        0.25, 0.08, 0.08, 0.5)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.45, 0.12, 0.12, 0.8)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.65, 0.15, 0.15, 1.0)
        if ImGui.Button("✕  Cancelar##cancel", -1, 26) then
            GUI.cancelled = true
            GUI.open      = false
        end
        ImGui.PopStyleColor(3)
    end

    popTheme()
    ImGui.End()
end

-- ============================================================
-- GUI: MONITOR (loop principal)
-- ============================================================

local function drawMonitorGUI()
    ImGui.SetNextWindowSize(360, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)
    pushTheme()

    -- Título dinâmico com estado
    local stateTag = GUI.paused and "  ⏸ PAUSADO" or "  ▶ ATIVO"
    local title    = "Anti-AFK — " .. API.ScriptRuntimeString() .. stateTag .. "###AntiAfkMon"
    local visible  = ImGui.Begin(title, 0)

    if visible then

        -- Status principal
        if GUI.paused then
            ImGui.PushStyleColor(ImGuiCol.Text, C.gold[1], C.gold[2], C.gold[3], 1.0)
            ImGui.TextWrapped("⏸  Script pausado. Clique em Retomar.")
        else
            ImGui.PushStyleColor(ImGuiCol.Text, C.glow[1], C.glow[2], C.glow[3], 1.0)
            ImGui.TextWrapped("✔  Protegido contra DC por inatividade.")
        end
        ImGui.PopStyleColor(1)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- ---- HP ----
        local hp, hpMax, hpPct = getHP()
        ImGui.PushStyleColor(ImGuiCol.Text, 0.75, 0.85, 0.70, 1.0)
        ImGui.Text("HP:")
        ImGui.PopStyleColor(1)
        ImGui.SameLine()
        -- Cor do HP
        local hr, hg, hb = C.glow[1], C.glow[2], C.glow[3]
        if hpPct < 50 then hr, hg, hb = C.gold[1], C.gold[2], C.gold[3] end
        if hpPct < 25 then hr, hg, hb = C.red[1],  C.red[2],  C.red[3]  end
        ImGui.PushStyleColor(ImGuiCol.Text, hr, hg, hb, 1.0)
        ImGui.Text(string.format("%d / %d  (%d%%)", hp, hpMax, hpPct))
        ImGui.PopStyleColor(1)

        ImGui.Spacing()

        -- ---- Ações realizadas ----
        ImGui.PushStyleColor(ImGuiCol.Text, 0.75, 0.85, 0.70, 1.0)
        ImGui.Text("Ações backup:")
        ImGui.PopStyleColor(1)
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, C.blue[1], C.blue[2], C.blue[3], 1.0)
        ImGui.Text(tostring(State.actionCount))
        ImGui.PopStyleColor(1)

        -- ---- Próxima ação ----
        local remaining = math.max(0, State.nextAction - os.time())
        ImGui.PushStyleColor(ImGuiCol.Text, 0.75, 0.85, 0.70, 1.0)
        ImGui.Text("Próxima backup em:")
        ImGui.PopStyleColor(1)
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, C.gold[1], C.gold[2], C.gold[3], 1.0)
        ImGui.Text(formatTime(remaining))
        ImGui.PopStyleColor(1)

        ImGui.Spacing()

        -- ---- Último status ----
        ImGui.PushStyleColor(ImGuiCol.Text, 0.60, 0.70, 0.60, 1.0)
        ImGui.TextWrapped("» " .. State.status)
        ImGui.PopStyleColor(1)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- ---- Botão Pausar / Retomar ----
        if GUI.paused then
            ImGui.PushStyleColor(ImGuiCol.Button,        C.light[1],    C.light[2],    C.light[3],    0.9)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, C.bright[1],   C.bright[2],   C.bright[3],   1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive,  C.glow[1]*0.8, C.glow[2]*0.8, C.glow[3]*0.8, 1.0)
            if ImGui.Button("▶  Retomar##resume", -1, 30) then
                GUI.paused   = false
                State.status = "Retomado."
                -- reset timer
                State.interval   = randomInterval()
                State.nextAction = os.time() + State.interval
            end
            ImGui.PopStyleColor(3)
        else
            ImGui.PushStyleColor(ImGuiCol.Button,        0.40, 0.32, 0.04, 0.9)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.60, 0.48, 0.08, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.75, 0.62, 0.12, 1.0)
            if ImGui.Button("⏸  Pausar##pause", -1, 30) then
                GUI.paused   = true
                State.status = "Pausado pelo usuário."
            end
            ImGui.PopStyleColor(3)
        end

        ImGui.Spacing()

        -- ---- Botão Parar ----
        ImGui.PushStyleColor(ImGuiCol.Button,        0.28, 0.06, 0.06, 0.6)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.48, 0.10, 0.10, 0.9)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.68, 0.14, 0.14, 1.0)
        if ImGui.Button("■  Parar Script##stop", -1, 26) then
            GUI.cancelled = true
        end
        ImGui.PopStyleColor(3)
    end

    popTheme()
    ImGui.End()
end

-- ============================================================
-- STARTUP — aguarda "Iniciar"
-- ============================================================

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

-- ============================================================
-- MAIN
-- ============================================================

API.Write_LoopyLoop(true)

if not waitForStart() then
    print("[Anti-AFK] Cancelado.")
    return
end

-- Configuração inicial
API.SetMaxIdleTime(IDLE_LIMIT_MINUTES)
State.interval   = randomInterval()
State.nextAction = os.time() + State.interval
State.status     = string.format("Iniciado. Primeira backup em %ds.", State.interval)

print(string.format("[Anti-AFK] Iniciado. SetMaxIdleTime(%d). Backup a cada %d–%ds.",
    IDLE_LIMIT_MINUTES, MIN_INTERVAL, MAX_INTERVAL))

ClearRender()
DrawImGui(function()
    drawMonitorGUI()
end)

while API.Read_LoopyLoop() do
    if GUI.cancelled then
        print("[Anti-AFK] Encerrado pelo usuário.")
        break
    end

    if not GUI.paused then
        doAntiAfk()
    end

    API.RandomSleep2(1000, 300, 400)
end

ClearRender()
print("[Anti-AFK] Script encerrado.")
