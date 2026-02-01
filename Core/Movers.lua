-- Core/Movers.lua
-- @module Movers
-- @alias Movers

local _, BS = ...

BS.Movers       = {}
local Movers    = BS.Movers


Movers._movers   = Movers._movers   or {}
Movers._holders  = Movers._holders  or {}
Movers._shown    = Movers._shown    or false
Movers._active   = Movers._active   or nil
Movers._defaults = Movers._defaults or {}


local ARROW_TEX          = "Interface\\AddOns\\BlackSignal\\Media\\ArrowUp.tga" -- Textura de flecha
local CONTROL_STRATA     = "DIALOG"  -- Estrato de los controles
local CONTROL_LEVEL      = 200       -- Nivel de frame base de los controles
local UPDATE_THROTTLE    = 0.02      -- Intervalo mínimo entre actualizaciones durante drag (~50fps)
local CONTROLS_Y_OFFSET  = 20        -- Desplazamiento vertical de controles sobre el mover base

---------------------------------------------------------------
-- Verificación de módulos
---------------------------------------------------------------

--- Determina si un módulo está habilitado consultando su estado en la API.
-- Si la clave es nil o vacía se asume habilitado.
--- @local
--- @param key frame Nombre/clave del módulo a verificar.
--- @return true boolean true  si el módulo está habilitado o no existe registro.
--- @return false boolean false si el módulo o su DB indican que está deshabilitado.
local function IsModuleEnabled(key)
    if not key or key == "" then return true end

    local m = BS and BS.API and BS.API.modules and BS.API.modules[key]
    if not m then return true end

    if m.enabled == false then return false end
    if m.db and m.db.enabled == false then return false end

    return true
end

---------------------------------------------------------------
-- Acceso a la base de datos del módulo
---------------------------------------------------------------

--- Obtiene o inicializa la tabla de datos persistente de un módulo.
-- Utiliza `BS.DB:EnsureDB` como única fuente de verdad.
--- @local
--- @param key string Clave del módulo.
--- @return Table (table|nil) La tabla DB del módulo, o nil si el sistema DB no está disponible.
local function GetModuleDB(key)
    if not BS or not BS.DB or type(BS.DB.EnsureDB) ~= "function" then
        return nil
    end

    local db = BS.DB:EnsureDB(key, {})
    if type(db) ~= "table" then return nil end
    return db
end

---------------------------------------------------------------
-- Utilidades matemáticas y de entrada
---------------------------------------------------------------

--- Redondea un número al entero más cercano (half-up).
--- @local
--- @param n number|nil Valor a redondear. Retorna 0 si es nil.
--- @return number 
local function Round(n)
    if not n then return 0 end
    if n >= 0 then return math.floor(n + 0.5) end
    return math.ceil(n - 0.5)
end

--- Retorna el paso de movimiento según si Shift está presionado.
--- @local
--- @return number 10 si Shift está activo, 1 en caso contrario.
local function ClickStep()
    return IsShiftKeyDown() and 10 or 1
end

---------------------------------------------------------------
-- Utilidades de posicionamiento relativo a UIParent
---------------------------------------------------------------

--- Calcula los offsets del centro de un holder respecto al centro de UIParent.
--- @local
--- @param holder Frame El holder del cual obtener la posición.
--- @return OffsetX number horizontal redondeado (x).
--- @return OffsetY number  vertical redondeado (y).
local function GetCenterOffsets(holder)
    local cx, cy = holder:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not ux then return 0, 0 end
    return Round(cx - ux), Round(cy - uy)
end

--- Posiciona un holder usando offsets CENTER/CENTER respecto a UIParent.
-- Limpia todos los puntos de anclaje previos antes de aplicar.
--- @local
--- @param holder Frame El holder a reposicionar.
--- @param x number Offset horizontal desde el centro de UIParent.
--- @param y number Offset vertical desde el centro de UIParent.
local function SetHolderOffsets(holder, x, y)
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", UIParent, "CENTER", x or 0, y or 0)
end

--- Ancla un frame al centro exacto de un holder dado.
-- Se usa tanto para el frame real del módulo como para el overlay del mover.
--- @local
--- @param frame Frame El frame a anclar.
--- @param holder Frame El holder destino.
local function ReanchorToHolder(frame, holder)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", holder, "CENTER", 0, 0)
end

---------------------------------------------------------------
-- Lectura y escritura de posición desde la DB del módulo
---------------------------------------------------------------

--- Aplica la posición almacenada en la DB del módulo sobre un holder.
--- @local
--- @param key string Clave del módulo.
--- @param holder Frame El holder sobre el cual aplicar la posición.
--- @return boolean true si la posición fue aplicada correctamente.
--- @return boolean false si no se pudo obtener la DB del módulo.
local function ApplyFromModuleDB(key, holder)
    local db = GetModuleDB(key)
    if not db then return false end

    local x = tonumber(db.x) or 0
    local y = tonumber(db.y) or 0
    SetHolderOffsets(holder, Round(x), Round(y))
    return true
end

--- Guarda la posición actual del holder en la DB del módulo.
-- Recalcula los offsets desde el centro para garantizar consistencia,
-- y re-aplica el anclaje CENTER/CENTER.
--- @local
--- @param key string Clave del módulo.
--- @param holder Frame El holder cuya posición se guarda.
--- @return boolean true si el guardado fue exitoso.
local function SaveToModuleDBFromHolderCenter(key, holder)
    local db = GetModuleDB(key)
    if not db then return false end

    local x, y = GetCenterOffsets(holder)
    db.x, db.y = x, y

    SetHolderOffsets(holder, x, y)
    return true
end

---------------------------------------------------------------
-- Holder
---------------------------------------------------------------

--- Crea un Frame invisible que actúa como contenedor movible.
-- El holder es el objeto que efectivamente se arrastra; los frames
-- reales y los overlays se anclan a él.
--- @local
--- @param key string Identificador único del mover (se incrusta en el nombre del frame).
--- @return frame Frame El holder creado, hijo de UIParent.
local function CreateHolder(key)
    local h = CreateFrame("Frame", "BS_MoverHolder_" .. key, UIParent)
    h:SetSize(10, 10)
    h:SetPoint("CENTER")
    h:SetMovable(true)
    h:SetClampedToScreen(true)
    h:EnableMouse(false)
    return h
end

---------------------------------------------------------------
-- Mostrar/ocultar controles individuales y globales
---------------------------------------------------------------

--- Oculta los controles (coordenadas + flechas) de un mover específico.
--- @local
--- @param key string  Clave del mover cuya controles se ocultan.
local function HideControls(key)
    local d = Movers._movers[key]
    if not d or not d.mover then return end
    if d.mover._HideControls then d.mover:_HideControls() end
end

--- Oculta los controles de todos los movers registrados y limpia el estado activo.
--- @local
local function HideAllControls()
    for k in pairs(Movers._movers) do
        HideControls(k)
    end
    Movers._active = nil
end

--- Activa los controles visuales (coordenadas, flechas, estilo resaltado)
-- para un mover específico, ocultando los de cualquier otro mover que estuviera activo.
-- No hace nada si el modo movers no está abierto o el módulo está inhabilitado.
--- @local
--- @param key string Clave del mover a activar.
local function ActivateControls(key)
    if not Movers._shown then return end
    local d = Movers._movers[key]
    if not d or not d.mover then return end
    if not IsModuleEnabled(key) then return end

    HideAllControls()
    Movers._active = key

    local m = d.mover
    m:SetFrameStrata(CONTROL_STRATA)
    m:SetFrameLevel(CONTROL_LEVEL)
    m:SetBackdropBorderColor(unpack(BS.Colors.Button.borderHover))
    m:SetBackdropColor(unpack(BS.Colors.Button.active))

    if m._UpdateCoordBadge then
        m:_UpdateCoordBadge(d.holder, false)
    end
    if m._ShowControls then
        m:_ShowControls()
    end
end

---------------------------------------------------------------
-- Captura de ESC para cerrar modo movers
---------------------------------------------------------------

--- Se crea una sola vez (guarded por Movers._escFrame).
-- El frame captura el teclado y cierra el modo movers al presionar ESC.
local esc = Movers._escFrame
if not esc then
    esc = CreateFrame("Frame", "BS_Movers_ESC", UIParent)
    esc:EnableKeyboard(true)
    esc:SetPropagateKeyboardInput(true)
    esc:Hide()

    esc:SetScript("OnKeyDown", function(_, key)
        if key ~= "ESCAPE" then return end
        if not Movers._shown then return end
        Movers:Lock()
    end)

    Movers._escFrame = esc
end

---------------------------------------------------------------
-- Overlay visual del mover
---------------------------------------------------------------

--- Crea el overlay visual de un mover: el rectángulo arrastrable, el badge de
-- coordenadas y las cuatro flechas de nudge.
-- Este overlay siempre permanece visible mientras el modo movers esté abierto.
--- @local
--- @param key string Clave identificadora del mover.
--- @param label string Texto visible sobre el mover (si es nil se usa key).
--- @param w number Ancho del overlay en píxeles (por defecto 160).
--- @param h number Alto del overlay en píxeles (por defecto 22).
--- @return button Button El frame Button que representa el overlay, con los métodos
--   internos `_ShowControls`, `_HideControls`, `_UpdateCoordBadge` y `_OnArrow` definidos.
local function CreateMoverOverlay(key, label, w, h)
    local m = CreateFrame("Button", "BS_Mover_" .. key, UIParent, "BackdropTemplate")

    m:SetSize(w or 160, h or 22)
    m:SetFrameStrata(CONTROL_STRATA)
    m:SetFrameLevel(CONTROL_LEVEL)
    m:SetClampedToScreen(true)

    m:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    m:SetBackdropColor(unpack(BS.Colors.Movers.active))
    m:SetBackdropBorderColor(unpack(BS.Colors.Button.borderNormal))

    -- Texto central del overlay
    local title = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("CENTER")
    title:SetText(label or key)
    title:SetTextColor(unpack(BS.Colors.Text.normal))
    m.text = title

    -- Badge de coordenadas (parte de los CONTROLES, se oculta cuando no está activo)
    m._coordBG = CreateFrame("Frame", nil, m, "BackdropTemplate")
    m._coordBG:SetFrameLevel(m:GetFrameLevel() + 5)
    m._coordBG:SetPoint("BOTTOM", m, "TOP", 0, CONTROLS_Y_OFFSET)
    m._coordBG:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    m._coordBG:SetBackdropColor(unpack(BS.Colors.Button.active))
    m._coordBG:SetBackdropBorderColor(unpack(BS.Colors.Button.borderHover))
    m._coordBG:Hide()

    -- Texto dentro del badge de coordenadas
    m._coordText = m._coordBG:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    m._coordText:SetTextColor(unpack(BS.Colors.Text.white))
    m._coordText:SetPoint("CENTER")
    m._coordText:SetJustifyH("CENTER")
    m._coordText:Hide()

    --- Crea un botón de flecha para mover el holder.
    -- Cada flecha es un Button hijo del overlay con una textura rotada.
    --- @local
    --- @param name string Identificador de dirección: "up", "down", "left", "right".
    --- @param point string Punto de anclaje del botón.
    --- @param rel Frame Frame de referencia para el anclaje.
    --- @param relPoint string Punto del frame de referencia.
    --- @param x number Offset horizontal del anclaje.
    --- @param y number Offset vertical del anclaje.
    --- @param rot number Rotación en radianes de la textura de flecha.
    --- @return button Button El botón de flecha creado (oculto por defecto).
    local function MakeArrow(name, point, rel, relPoint, x, y, rot)
        local b = CreateFrame("Button", nil, m)
        b:SetSize(14, 14)
        b:SetPoint(point, rel, relPoint, x, y)

        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        t:SetTexture(ARROW_TEX)
        if t.SetRotation then t:SetRotation(rot) end
        t:SetAlpha(0.85)
        b.tex = t

        b:SetScript("OnClick", function()
            if m._OnArrow then m._OnArrow(name) end
        end)

        b:Hide()
        return b
    end

    -- Creación de las cuatro flechas con sus rotaciones correspondientes
    m._arrows = {
        up    = MakeArrow("up",    "BOTTOM", m._coordBG, "TOP",    0,  2, 0),
        down  = MakeArrow("down",  "TOP",    m._coordBG, "BOTTOM", 0, -2, math.pi),
        left  = MakeArrow("left",  "RIGHT",  m._coordBG, "LEFT",  -2,  0, math.pi/2),
        right = MakeArrow("right", "LEFT",   m._coordBG, "RIGHT",  2,  0, -math.pi/2),
    }

    -- Muestra el badge de coordenadas y las flechas de nudge
    m._ShowControls = function(self)
        self._coordBG:Show()
        self._coordText:Show()
        for _, b in pairs(self._arrows) do b:Show() end
    end

    -- Oculta el badge y las flechas, restaura colores base. No actúa si está en drag.
    m._HideControls = function(self)
        if self._isDragging then return end
        self._coordBG:Hide()
        self._coordText:Hide()
        m:SetBackdropColor(unpack(BS.Colors.Movers.active))
        m:SetBackdropBorderColor(unpack(BS.Colors.Button.borderNormal))
        for _, b in pairs(self._arrows) do b:Hide() end
    end

    -- Actualiza el texto del badge: offsets en tiempo real si está en drag, valores de DB si no
    m._UpdateCoordBadge = function(self, holder, isDragging)
        local x, y
        if isDragging then
            x, y = GetCenterOffsets(holder)
        else
            local key2 = self._key
            local db = key2 and GetModuleDB(key2) or nil
            x = db and tonumber(db.x) or 0
            y = db and tonumber(db.y) or 0
            x, y = Round(x), Round(y)
        end

        self._coordText:SetText(("x:%d  y:%d"):format(x, y))

        -- Redimensiona el background al texto + padding
        local w2 = self._coordText:GetStringWidth() + 18
        local h2 = self._coordText:GetStringHeight() + 10
        self._coordBG:SetSize(w2, h2)
    end

    m:RegisterForDrag("LeftButton")
    m:SetMovable(true)
    m:EnableMouse(true)

    m:_HideControls()
    return m
end

---------------------------------------------------------------
-- API Pública del módulo
---------------------------------------------------------------

--- Registra un frame externo en el sistema de movers.
-- Si el frame ya estaba registrado bajo esa clave, simplemente reaplica
-- la posición desde la DB y retorna el mover existente.
-- Al registrar por primera vez:
--   1. Crea o reutiliza el holder.
--   2. Inicializa x/y en la DB si no existen (desde la posición actual del frame).
--   3. Captura los valores por defecto para poder hacer reset.
--   4. Aplica la posición al holder y ancla el frame real.
--   5. Crea el overlay visual y conecta todos los eventos (drag, click, flechas).
--- @param frame Frame El frame a hacer movible.
--- @param key string Clave única que identifica este mover (normalmente el nombre del módulo).
--- @param label string? [opcional] Etiqueta visible sobre el overlay. Si es nil se usa key.
--- @return button Button|nil El overlay del mover, o nil si no se pudo crear la DB.
--- @usage
--   local mover = BS.Movers:Register(myFrame, "MyModule", "Mi Módulo")
function Movers:Register(frame, key, label)
    if not frame or not key then return end

    -- Re-registro: reaplica posición y retorna el mover existente
    if self._movers[key] then
        self:Apply(key)
        return self._movers[key].mover
    end

    -- Asegura que la DB del módulo exista
    local mdb = GetModuleDB(key)
    if not mdb then return end

    -- Crea o reutiliza el holder para esta clave
    local holder = self._holders[key]
    if not holder then
        holder = CreateHolder(key)
        self._holders[key] = holder
    end

    -- Inicializa x/y en la DB desde la posición actual del frame si aún no existen
    if mdb.x == nil or mdb.y == nil then
        local cx, cy = frame:GetCenter()
        local ux, uy = UIParent:GetCenter()
        mdb.x = (cx and ux) and Round(cx - ux) or 0
        mdb.y = (cy and uy) and Round(cy - uy) or 0
    else
        mdb.x = Round(tonumber(mdb.x) or 0)
        mdb.y = Round(tonumber(mdb.y) or 0)
    end

    -- Captura los valores por defecto la primera vez (para reset)
    if not Movers._defaults[key] then
        Movers._defaults[key] = { x = Round(tonumber(mdb.x) or 0), y = Round(tonumber(mdb.y) or 0) }
    end

    -- Aplica posición al holder desde la DB
    ApplyFromModuleDB(key, holder)

    -- Ancla el frame real al holder
    ReanchorToHolder(frame, holder)

    -- Crea el overlay visual y lo ancla al holder
    local mover = CreateMoverOverlay(key, label or key, frame:GetWidth(), frame:GetHeight())
    mover._key = key
    ReanchorToHolder(mover, holder)
    mover:SetShown(self._shown and IsModuleEnabled(key))
    mover:_HideControls()

    -- Callback de las flechas: escribe el nudge directamente en la DB del módulo
    mover._OnArrow = function(dir)
        if not self._shown then return end
        if not IsModuleEnabled(key) then return end
        if InCombatLockdown() then return end

        ActivateControls(key)

        local step = ClickStep()
        local dx, dy = 0, 0
        if dir == "left" then dx = -step
        elseif dir == "right" then dx = step
        elseif dir == "up" then dy = step
        elseif dir == "down" then dy = -step
        else return end

        local db = GetModuleDB(key)
        if not db then return end

        local x = Round(tonumber(db.x) or 0) + dx
        local y = Round(tonumber(db.y) or 0) + dy
        db.x, db.y = x, y

        SetHolderOffsets(holder, x, y)
        ReanchorToHolder(mover, holder)
        ReanchorToHolder(frame, holder)

        mover:_UpdateCoordBadge(holder, false)
    end

    -- Click izquierdo: activa controles. Click derecho: reset + activa controles.
    mover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mover:SetScript("OnMouseDown", function(_, btn)
        if not Movers._shown then return end
        if not IsModuleEnabled(key) then return end
        if InCombatLockdown() then return end

        if btn == "LeftButton" then
            ActivateControls(key)
            return
        end

        if btn == "RightButton" then
            Movers:Reset(key)
            ActivateControls(key)
            return
        end
    end)

    -- Inicio del drag: activa controles y comienza a mover el holder
    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        if not Movers._shown then return end
        if not IsModuleEnabled(key) then return end

        ActivateControls(key)

        holder:StartMoving()
        self._isDragging = true
        self._dragThrottle = 0

        self:_UpdateCoordBadge(holder, true)
        self:_ShowControls()
    end)

    -- Fin del drag: detiene el holder, guarda posición en DB y reancla todo
    mover:SetScript("OnDragStop", function(self)
        holder:StopMovingOrSizing()
        self._isDragging = false

        SaveToModuleDBFromHolderCenter(key, holder)

        ReanchorToHolder(self, holder)
        ReanchorToHolder(frame, holder)

        self:_UpdateCoordBadge(holder, false)
        self:_ShowControls()
    end)

    -- Actualización por frame: actualiza coordenadas en el badge durante el drag,
    -- limitada por UPDATE_THROTTLE para no saturar.
    mover:SetScript("OnUpdate", function(self, elapsed)
        if not self._isDragging then return end
        self._dragThrottle = (self._dragThrottle or 0) + elapsed
        if self._dragThrottle < UPDATE_THROTTLE then return end
        self._dragThrottle = 0
        self:_UpdateCoordBadge(holder, true)
    end)

    -- Guarda el registro completo
    self._movers[key] = {
        key    = key,
        frame  = frame,
        holder = holder,
        mover  = mover,
    }

    return mover
end

--- Reaplica la posición almacenada en la DB sobre un mover ya registrado.
-- Actualiza el tamaño del overlay al tamaño actual del frame real.
--- @param key string Key del mover a reapliear.
--- @usage
---   BS.Movers:Apply("MyModule")
function Movers:Apply(key)
    local d = self._movers[key]
    if not d then return end

    -- Aplica desde la DB del módulo; si falla, centra en (0,0)
    local ok = ApplyFromModuleDB(key, d.holder)
    if not ok then
        SetHolderOffsets(d.holder, 0, 0)
    end

    -- Ajusta el tamaño del overlay al frame real actual
    local fw = d.frame:GetWidth()  or 160
    local fh = d.frame:GetHeight() or 22
    d.mover:SetSize(fw, fh)

    ReanchorToHolder(d.frame, d.holder)
    ReanchorToHolder(d.mover, d.holder)

    -- Actualiza el badge de coordenadas si este mover está activo
    if d.mover._UpdateCoordBadge and Movers._active == key then
        d.mover:_UpdateCoordBadge(d.holder, false)
    end
end

--- Reaplica la posición desde la DB en todos los movers registrados.
--- @usage
---   BS.Movers:ApplyAll()
function Movers:ApplyAll()
    for key in pairs(self._movers) do
        self:Apply(key)
    end
end

--- Abre el modo movers, haciendo visibles todos los overlays de módulos habilitados.
-- Si el jugador está en combate, muestra un error y no hace nada.
--- @usage
---   BS.Movers:Unlock()
function Movers:Unlock()
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("BlackSignal: no puedes activar movers en combate.", 1, 0.2, 0.2)
        return
    end

    self._shown = true
    HideAllControls()

    -- Muestra u oculta cada overlay según si su módulo está habilitado
    for key, d in pairs(self._movers) do
        if IsModuleEnabled(key) then
            d.mover:Show()
        else
            d.mover:Hide()
        end
        if d.mover._HideControls then d.mover:_HideControls() end
    end

    -- Activa el frame ESC para capturar la tecla de escape
    if self._escFrame then
        self._escFrame:Show()
        self._escFrame:SetFrameStrata(CONTROL_STRATA)
        self._escFrame:SetFrameLevel(CONTROL_LEVEL + 50)
    end
end

--- Cierra el modo movers, ocultando todos los overlays y controles.
--- @usage
---   BS.Movers:Lock()
function Movers:Lock()
    self._shown = false
    HideAllControls()

    for _, d in pairs(self._movers) do
        if d.mover then
            d.mover:_HideControls()
            d.mover:Hide()
        end
    end

    if self._escFrame then
        self._escFrame:Hide()
    end
end

--- Alterna el modo movers: lo abre si está cerrado, lo cierra si está abierto.
--- @usage
---   BS.Movers:Toggle()
function Movers:Toggle()
    if self._shown then self:Lock() else self:Unlock() end
end

--- Restaura la posición de un mover a sus valores por defecto (capturados al registrar).
-- Guarda los valores por defecto en la DB y reancla todos los frames.
--- @param key string Key del mover a restaurar.
--- @usage
---   BS.Movers:Reset("MyModule")
function Movers:Reset(key)
    local d = self._movers[key]
    if not d then return end

    local db = GetModuleDB(key)
    if not db then return end

    local def = Movers._defaults and Movers._defaults[key]
    local x = def and def.x or 0
    local y = def and def.y or 0

    db.x, db.y = x, y

    SetHolderOffsets(d.holder, x, y)
    ReanchorToHolder(d.frame, d.holder)
    ReanchorToHolder(d.mover, d.holder)

    -- Actualiza el badge si este mover tiene controles visibles
    if Movers._active == key and d.mover._UpdateCoordBadge then
        d.mover:_UpdateCoordBadge(d.holder, false)
        d.mover:_ShowControls()
    end
end

--- Restaura todos los movers registrados a sus posiciones por defecto
-- y oculta todos los controles.
--- @usage
---   BS.Movers:ResetAll()
function Movers:ResetAll()
    for key in pairs(self._movers) do
        self:Reset(key)
    end
    HideAllControls()
end