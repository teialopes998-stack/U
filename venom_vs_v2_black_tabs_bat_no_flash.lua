local Players            = game:GetService("Players")
local HttpService        = game:GetService("HttpService")
local RunService         = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Stats              = game:GetService("Stats")
local CoreGui            = game:GetService("CoreGui")
local SoundService       = game:GetService("SoundService")
local InsertService      = game:GetService("InsertService")


-- ============================================================
-- MOBILE COMPATIBILITY PATCH
-- Mantem PC e mobile no mesmo boot; no mobile nao depende de tecla.
-- ============================================================
do
    local UIS_MOBILE = UserInputService
    local IS_MOBILE = false
    pcall(function() IS_MOBILE = UIS_MOBILE.TouchEnabled and not UIS_MOBILE.KeyboardEnabled end)
    _G._K7IsMobile = IS_MOBILE

    -- Alguns executores mobile nao expõem APIs opcionais. Nunca deixe
    -- uma dessas APIs interromper a criacao da interface.
    local genv = (type(getgenv) == "function" and getgenv()) or nil
    local function pick(name)
        local v = rawget(_G, name)
        if v == nil and genv then v = rawget(genv, name) end
        return v
    end
    if not checkcaller then _G.checkcaller = function() return true end end
    if not newcclosure then _G.newcclosure = function(f) return f end end
    if not setreadonly then _G.setreadonly = function() end end
    if not getrawmetatable then _G.getrawmetatable = function() return nil end end
    if not getconnections then _G.getconnections = function() return {} end end
    if not setclipboard then _G.setclipboard = pick("toclipboard") end

    -- PlayerGui e' a rota preferida no celular. gethui/CoreGui ficam
    -- como fallback para executores que exigem essa camada.
    function _G._K7GetGuiParent()
        local lp = Players.LocalPlayer
        local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 10))
        if pg then return pg end
        local ok, hui = pcall(function()
            return (type(gethui) == "function" and gethui()) or CoreGui
        end)
        return ok and hui or CoreGui
    end

    -- Escala de interface adequada a telas pequenas.
    function _G._K7MobileScale(root)
        if not root or not IS_MOBILE then return end
        pcall(function()
            local old = root:FindFirstChild("K7MobileScale")
            if old then old:Destroy() end
            local sc = Instance.new("UIScale")
            sc.Name = "K7MobileScale"
            sc.Scale = 0.82
            sc.Parent = root
        end)
    end
end

-- ── Lua version compatibility polyfills ──────────────────────
if not math.clamp then
    math.clamp = function(v, lo, hi)
        if v < lo then return lo elseif v > hi then return hi end
        return v
    end
end
if not math.round then
    math.round = function(v) return math.floor(v + 0.5) end
end
if not typeof then
    typeof = function(v) return type(v) end
end

-- ── Volt / executor compatibility shim ───────────────────────
do
    local genv = getgenv and getgenv()
    local function adopt(name, fallback)
        if _G[name] ~= nil then return end
        local v = rawget(_G, name)
        if v == nil and genv then v = rawget(genv, name) end
        if v == nil and fallback then v = fallback end
        if v ~= nil then _G[name] = v end
    end
    adopt("request")
    adopt("http_request")
    adopt("fireproximityprompt")
    adopt("getconnections")
    adopt("getcustomasset")
    adopt("writefile")
    adopt("readfile")
    adopt("isfile")
    adopt("delfile")
    adopt("setclipboard")
    adopt("getclipboard")
    adopt("getrawmetatable")
    adopt("setreadonly")
    adopt("newcclosure")
    adopt("Drawing")
    if identifyexecutor then
        local ok, id = pcall(identifyexecutor)
        if ok then
            local n = type(id) == "table" and (id.Name or id[1]) or tostring(id or "")
            if tostring(n):lower():find("volt") then
                print("[MAY duels] Volt detected")
            end
        end
    end
end

local request = http_request or (getgenv and (getgenv().request or getgenv().http_request)) or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or request
if not request then
    warn("[MAY duels] No HTTP request function available")
end

-- Mystery.Vs is rendered with native UI text so it always appears without downloads.

local LP = Players.LocalPlayer
if not LP then LP = Players.PlayerAdded:Wait() end

-- >>> ANTI DROP BEGIN (versione con raw metatable)
-- ============================================================
-- ANTI DROP
-- Sempre attivo, non si spegne: nessun toggle, nessun salvataggio.
-- Non tocca la velocita' reale, fa solo vedere al gioco 16 studs/s
-- qualunque sia la velocita' effettiva. Al movimento ci pensa la
-- root.Velocity dell'HRP (speed, jump, Anti Bat: tutti la' sopra).
-- checkcaller() fa passare intatte le scritture dell'hub.
-- ============================================================
do
    local VS_FAKE = 16   -- velocita' mostrata al gioco (walkspeed normale)
    local spoofedVelocity = Vector3.zero
    -- Unico bersaglio: l'HRP. I due proxy (speed booster e infinite jump)
    -- non esistono piu', ora si scrive tutto sulla root.Velocity, quindi i
    -- loro nomi qui erano voci morte.
    local SPOOF_NAMES = {
        HumanoidRootPart = true,
    }
    local function isSpoofTarget(self)
        if typeof(self) ~= "Instance" then return false end
        if not self:IsA("BasePart") then return false end
        if not SPOOF_NAMES[self.Name] then return false end
        local char = LP.Character
        return char ~= nil and self:IsDescendantOf(char)
    end
    -- Hook tramite raw metatable (più robusto e meno rilevabile)
    pcall(function()
        if not (getrawmetatable and setreadonly and newcclosure and checkcaller) then
            return
        end
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local oldIndex = mt.__index
        mt.__index = newcclosure(function(self, key)
            if not checkcaller() and (key == "AssemblyLinearVelocity" or key == "Velocity") then
                if isSpoofTarget(self) then
                    return spoofedVelocity
                end
            end
            return oldIndex(self, key)
        end)
        local oldNewIndex = mt.__newindex
        mt.__newindex = newcclosure(function(self, key, value)
            if not checkcaller() and (key == "AssemblyLinearVelocity" or key == "Velocity") then
                if isSpoofTarget(self) then
                    spoofedVelocity = value   -- memorizza il valore che l'hub vorrebbe scrivere
                    return                     -- blocca la scrittura reale
                end
            end
            return oldNewIndex(self, key, value)
        end)
        setreadonly(mt, true)
    end)
    -- Aggiorna la velocità finta in base alla direzione di movimento
    local function updateFakeVelocity()
        local char = LP.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not hum or not root or hum.Health <= 0 then return end
        local dir = hum.MoveDirection
        if dir.Magnitude > 0.05 then
            -- compatibilità con il client (opzionale)
            pcall(function()
                if root.SetNetworkOwner then root:SetNetworkOwner(LP) end
            end)
            local unit = dir.Unit
            spoofedVelocity = Vector3.new(unit.X * VS_FAKE, root.Velocity.Y, unit.Z * VS_FAKE)
        else
            spoofedVelocity = Vector3.new(0, root.Velocity.Y, 0)
        end
    end
    local sig = RunService.PreSimulation or RunService.Stepped
    sig:Connect(updateFakeVelocity)
end
-- <<< ANTI DROP END

-- Allow re-execute: tear down old GUI if present
pcall(function()
    local pg = game:GetService("Players").LocalPlayer
    pg = pg and pg:FindFirstChild("PlayerGui")
    if pg then
        local old = pg:FindFirstChild("SevenUpDuelsV2")
        if old then old:Destroy() end
        local oldStack = pg:FindFirstChild("SevenUpStackButtons")
        if oldStack then oldStack:Destroy() end
        local oldIntro = pg:FindFirstChild("K7Intro")
        if oldIntro then oldIntro:Destroy() end
    end
end)
pcall(function()
    local cg = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    local oldStack = cg and cg:FindFirstChild("SevenUpStackButtons")
    if oldStack then oldStack:Destroy() end
end)
pcall(function()
    if _G.AceStopAntiDesyncAimbot then _G.AceStopAntiDesyncAimbot() end
    if _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end
end)
_G.SevenUpDuelsV2_Running = true
_G.SevenUpDuelsV2_MainExecuted = false
_G._K7AntiDesyncKeyBound = false

-- ============================================================
-- PC FIX / WATCHDOG  (não altera nenhuma função do hub)
-- Garante que o menu apareça em executores de PC mesmo que a
-- intro ou o boot falhem. Tecla de emergência: RightControl.
-- ============================================================
task.spawn(function()
    local UIS_wd = game:GetService("UserInputService")

    local function getMainFrame()
        local pg = LP and LP:FindFirstChild("PlayerGui")
        local gui = pg and pg:FindFirstChild("SevenUpDuelsV2")
        if not gui then
            local ok, cg = pcall(function()
                return (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
            end)
            if ok and cg then gui = cg:FindFirstChild("SevenUpDuelsV2") end
        end
        return gui and gui:FindFirstChild("MainOuter") or nil
    end

    local function forceShow()
        local mo = getMainFrame()
        if not mo then return false end
        _G._K7IntroHidingUI = false
        pcall(function()
            mo.Visible = true
            if mo.Size.X.Offset < 60 or mo.Size.Y.Offset < 60 then
                mo.Size = UDim2.new(0, 420, 0, 590)
            end
            local sc = mo:FindFirstChild("MainUIOnlyScale")
            if sc and sc:IsA("UIScale") and sc.Scale < 0.3 then sc.Scale = 0.9 end
            if _G._K7FitMenuToScreen then pcall(_G._K7FitMenuToScreen) end
        end)
        pcall(function()
            local pg = LP and LP:FindFirstChild("PlayerGui")
            local cg = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
            for _, holder in ipairs({ pg, cg }) do
                local st = holder and holder:FindFirstChild("SevenUpStackButtons")
                if st then st.Enabled = true end
            end
            if _G._K7StackGui then _G._K7StackGui.Enabled = true end
        end)
        return true
    end
    _G._K7ForceShowMenu = forceShow

    local function rebuild()
        if not _G._K7Main then return false end
        _G.SevenUpDuelsV2_MainExecuted = false
        local ok, err = pcall(_G._K7Main)
        if not ok then warn("[MAY duels] PC fix - Main() falhou:", err) end
        return ok
    end

    -- Emergencia PC: RightControl. No mobile o menu usa toque normalmente.
    UIS_wd.InputBegan:Connect(function(inp, gp)
        if _G._K7IsMobile and inp.UserInputType == Enum.UserInputType.Touch then return end
        if gp then return end
        if inp.KeyCode ~= Enum.KeyCode.RightControl then return end
        if not getMainFrame() then rebuild() end
        task.wait(0.15)
        forceShow()
    end)

    -- 1) menu não foi criado -> tenta de novo
    task.wait(12)
    if not getMainFrame() then
        warn("[MAY duels] PC fix: menu não criado, tentando novamente...")
        rebuild()
        task.wait(1)
        if getMainFrame() then forceShow() end
    end

    -- 2) intro travou e deixou o menu escondido -> libera
    task.wait(8)
    local mo = getMainFrame()
    if mo and (mo.Visible == false or mo.Size.X.Offset < 60) and _G._K7IntroHidingUI ~= false then
        warn("[MAY duels] PC fix: intro travada, liberando o menu")
        forceShow()
        pcall(function()
            local pg = LP and LP:FindFirstChild("PlayerGui")
            for _, n in ipairs({ "K7Intro", "MayDuelsIntro", "K7SodaOpeningIntro" }) do
                local g = pg and pg:FindFirstChild(n)
                if g then g:Destroy() end
            end
        end)
    end
end)


local UIS = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

-- ============================================================
-- SAFE CLICK — botão só ativa com clique/toque de verdade:
-- precisa PRESSIONAR e SOLTAR em cima do botão, quase sem arrastar.
-- Isso impede ativação ao passar o dedo por cima (scroll do menu).
-- ============================================================
_G._K7SafeClick = function(guiObj, fn)
    if not guiObj then return end
    local pressedOn = false
    local pressX, pressY = 0, 0
    guiObj.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pressedOn = true
            pressX, pressY = input.Position.X, input.Position.Y
        end
    end)
    guiObj.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if not pressedOn then return end
        pressedOn = false
        local dx = input.Position.X - pressX
        local dy = input.Position.Y - pressY
        if (dx * dx + dy * dy) > 324 then return end -- ~18px de tolerância
        local okPos, absPos = pcall(function() return guiObj.AbsolutePosition end)
        local okSize, absSize = pcall(function() return guiObj.AbsoluteSize end)
        if okPos and okSize and absPos and absSize then
            local x, y = input.Position.X, input.Position.Y
            if x < absPos.X or x > absPos.X + absSize.X or y < absPos.Y or y > absPos.Y + absSize.Y then
                return
            end
        end
        task.spawn(fn)
    end)
end

local LP = Players.LocalPlayer or Players:WaitForChild("LocalPlayer")

local _isfile = isfile or (syn and syn.isfile) or (getgenv and getgenv().isfile) or function() return false end
local _readfile = readfile or (syn and syn.readfile) or (getgenv and getgenv().readfile) or function() return nil end
local _writefile = writefile or (syn and syn.writefile) or (getgenv and getgenv().writefile) or function() end
local _delfile = delfile or (syn and syn.delfile) or (getgenv and getgenv().delfile) or function() end
local _setclipboard = setclipboard or toclipboard or (syn and syn.write_clipboard) or (getgenv and (getgenv().setclipboard or getgenv().toclipboard))
local _getclipboard = getclipboard or (syn and syn.read_clipboard) or (getgenv and getgenv().getclipboard)
local getconnections = getconnections or (getgenv and getgenv().getconnections) or get_signal_cons or getconnects or (syn and syn.get_signal_cons)

local activeSpeedValue = 60

local _request = request or http_request or (getgenv and (getgenv().request or getgenv().http_request)) or (syn and syn.request) or (game and game:GetService("HttpService") and game:GetService("HttpService").RequestAsync) or nil

if not fireproximityprompt then
    fireproximityprompt = (getgenv and getgenv().fireproximityprompt)
        or (genv and genv().fireproximityprompt)
        or function(prompt)
            pcall(function()
                prompt:InputHoldBegin()
                task.wait(0.05)
                prompt:InputHoldEnd()
            end)
        end
end

repeat task.wait() until game:IsLoaded()

-- ============================================================
-- COLOR SCHEMES (green theme)
-- ============================================================
COLOR_SCHEMES = {
    ["rbxassetid://102557909116203"] = {  -- LIGHT BLUE CYBER
        main = Color3.fromRGB(80, 200, 255),
        mainLight = Color3.fromRGB(80, 80, 80),
        mainDark = Color3.fromRGB(40, 130, 210),
        accent = Color3.fromRGB(100, 220, 255),
        text = Color3.fromRGB(245, 250, 255),
        subText = Color3.fromRGB(180, 220, 245),
        border = Color3.fromRGB(90, 190, 255),
        buttonBg = Color3.fromRGB(50, 140, 220),
        buttonText = Color3.fromRGB(255, 255, 255),
        speedText = Color3.fromRGB(120, 230, 255),
        discordText = Color3.fromRGB(140, 220, 255),
        tabActive = Color3.fromRGB(80, 80, 80),
        tabIdle = Color3.fromRGB(90, 170, 230),
        progressBg = Color3.fromRGB(12, 30, 55),
        toggleOn = Color3.fromRGB(70, 210, 255),
        toggleOff = Color3.fromRGB(20, 45, 80),
        inputBg = Color3.fromRGB(14, 32, 60),
        inputBorder = Color3.fromRGB(70, 160, 230),
        inputText = Color3.fromRGB(220, 240, 255),
        rowBg = Color3.fromRGB(16, 40, 72),
        rowHover = Color3.fromRGB(28, 60, 110),
        sectionHeader = Color3.fromRGB(140, 225, 255),
        closeBtn = Color3.fromRGB(160, 210, 240),
        closeBtnHover = Color3.fromRGB(200, 240, 255),
        titleText = Color3.fromRGB(230, 245, 255),
        subtitleText = Color3.fromRGB(140, 210, 245),
        stackBg = Color3.fromRGB(14, 32, 68),
        stackActive = Color3.fromRGB(60, 200, 255),
        stackText = Color3.fromRGB(180, 230, 255),
        stackActiveText = Color3.fromRGB(255, 255, 255),
        stackBorder = Color3.fromRGB(70, 180, 245),
        stackActiveBorder = Color3.fromRGB(120, 230, 255),
        dot = Color3.fromRGB(70, 140, 200),
        dotOn = Color3.fromRGB(80, 220, 255),
        pillOff = Color3.fromRGB(24, 50, 90),
        pillOn = Color3.fromRGB(60, 200, 255),
        modeBtnBg = Color3.fromRGB(16, 38, 70),
        modeBtnActBg = Color3.fromRGB(50, 170, 245),
        modeBtnTxt = Color3.fromRGB(140, 220, 255),
        modeBtnActTx = Color3.fromRGB(255, 255, 255),
        chipBorder = Color3.fromRGB(70, 160, 230),
        chipTxt = Color3.fromRGB(140, 220, 255),
        btnBg = Color3.fromRGB(16, 36, 70),
        btnTxt = Color3.fromRGB(230, 245, 255),
        btnHov = Color3.fromRGB(30, 70, 130),
        infoTxt = Color3.fromRGB(140, 210, 245),
        infoVal = Color3.fromRGB(220, 245, 255),
        infoFill = Color3.fromRGB(70, 200, 255),
        divider = Color3.fromRGB(50, 120, 190),
        winBorder = Color3.fromRGB(90, 200, 255),
        topBg = Color3.fromRGB(12, 30, 58),
        topBtn = Color3.fromRGB(100, 180, 240),
        tabBarBg = Color3.fromRGB(10, 26, 50),
        tabIdleHov = Color3.fromRGB(160, 230, 255),
        tabActiveBg = Color3.fromRGB(24, 55, 105),
        tabUnderline = Color3.fromRGB(90, 220, 255),
        rowBorder = Color3.fromRGB(50, 130, 200),
        rowLabel = Color3.fromRGB(235, 248, 255),
        rowSub = Color3.fromRGB(160, 210, 240),
        rowValue = Color3.fromRGB(200, 235, 255),
        inputFocus = Color3.fromRGB(90, 210, 255),
        dotOff = Color3.fromRGB(60, 110, 170),
        pillBorder = Color3.fromRGB(80, 180, 240),
        modeBtnBrd = Color3.fromRGB(70, 160, 230),
        presetBg = Color3.fromRGB(16, 38, 70),
        autoGrabLine = Color3.fromRGB(80, 210, 255),
        presetBrd = Color3.fromRGB(75, 75, 75),
        presetLoad = Color3.fromRGB(131, 131, 131),
        presetDel = Color3.fromRGB(87, 87, 87),
        delBrd = Color3.fromRGB(136, 136, 136),
        lockOn = Color3.fromRGB(131, 131, 131),
        adTitle = Color3.fromRGB(131, 131, 131),
        adSub = Color3.fromRGB(207, 207, 207),
        adKeyLbl = Color3.fromRGB(255, 255, 255),
        adKeyBtn = Color3.fromRGB(131, 131, 131),
        adKeyBtnText = Color3.fromRGB(255, 255, 255),
        adActionBtn = Color3.fromRGB(131, 131, 131),
        adActionBtnText = Color3.fromRGB(255, 255, 255),
        adOffBg = Color3.fromRGB(46, 46, 46),
        adDimText = Color3.fromRGB(255, 255, 255),
        adBorder = Color3.fromRGB(131, 131, 131),
        adStroke = Color3.fromRGB(131, 131, 131),
        adBg = Color3.fromRGB(0, 0, 0),
        autoGrabText = Color3.fromRGB(255, 255, 255),
        autoGrabLine = Color3.fromRGB(131, 131, 131),
    },
    ["rbxassetid://85219527046711"] = {  -- 7UP FIZZ
        main = Color3.fromRGB(174, 174, 174),
        mainLight = Color3.fromRGB(218, 218, 218),
        mainDark = Color3.fromRGB(129, 129, 129),
        accent = Color3.fromRGB(174, 174, 174),
        text = Color3.fromRGB(255, 255, 255),
        subText = Color3.fromRGB(218, 218, 218),
        border = Color3.fromRGB(174, 174, 174),
        buttonBg = Color3.fromRGB(174, 174, 174),
        buttonText = Color3.fromRGB(255, 255, 255),
        speedText = Color3.fromRGB(174, 174, 174),
        discordText = Color3.fromRGB(131, 131, 131),
        tabActive = Color3.fromRGB(218, 218, 218),
        tabIdle = Color3.fromRGB(174, 174, 174),
        progressBg = Color3.fromRGB(31, 31, 31),
        toggleOn = Color3.fromRGB(174, 174, 174),
        toggleOff = Color3.fromRGB(31, 31, 31),
        inputBg = Color3.fromRGB(12, 25, 8),
        inputBorder = Color3.fromRGB(84, 84, 84),
        inputText = Color3.fromRGB(218, 218, 218),
        rowBg = Color3.fromRGB(15, 30, 10),
        rowHover = Color3.fromRGB(39, 39, 39),
        sectionHeader = Color3.fromRGB(174, 174, 174),
        closeBtn = Color3.fromRGB(95, 95, 95),
        closeBtnHover = Color3.fromRGB(174, 174, 174),
        titleText = Color3.fromRGB(218, 218, 218),
        subtitleText = Color3.fromRGB(174, 174, 174),
        stackBg = Color3.fromRGB(12, 25, 8),
        stackActive = Color3.fromRGB(129, 129, 129),
        stackText = Color3.fromRGB(234, 234, 234),
        stackActiveText = Color3.fromRGB(255, 255, 255),
        stackBorder = Color3.fromRGB(129, 129, 129),
        stackActiveBorder = Color3.fromRGB(174, 174, 174),
        dot = Color3.fromRGB(79, 79, 79),
        dotOn = Color3.fromRGB(174, 174, 174),
        pillOff = Color3.fromRGB(31, 31, 31),
        pillOn = Color3.fromRGB(174, 174, 174),
        modeBtnBg = Color3.fromRGB(12, 25, 8),
        modeBtnActBg = Color3.fromRGB(174, 174, 174),
        modeBtnTxt = Color3.fromRGB(174, 174, 174),
        modeBtnActTx = Color3.fromRGB(22, 22, 22),
        chipBorder = Color3.fromRGB(84, 84, 84),
        chipTxt = Color3.fromRGB(174, 174, 174),
        btnBg = Color3.fromRGB(12, 25, 8),
        btnTxt = Color3.fromRGB(234, 234, 234),
        btnHov = Color3.fromRGB(39, 39, 39),
        infoTxt = Color3.fromRGB(174, 174, 174),
        infoVal = Color3.fromRGB(218, 218, 218),
        infoFill = Color3.fromRGB(174, 174, 174),
        divider = Color3.fromRGB(79, 79, 79),
        winBorder = Color3.fromRGB(174, 174, 174),
        topBg = Color3.fromRGB(6, 18, 4),
        topBtn = Color3.fromRGB(95, 95, 95),
        tabBarBg = Color3.fromRGB(0, 0, 0),
        tabIdleHov = Color3.fromRGB(218, 218, 218),
        tabActiveBg = Color3.fromRGB(29, 29, 29),
        tabUnderline = Color3.fromRGB(174, 174, 174),
        rowBorder = Color3.fromRGB(79, 79, 79),
        rowLabel = Color3.fromRGB(234, 234, 234),
        rowSub = Color3.fromRGB(188, 188, 188),
        rowValue = Color3.fromRGB(218, 218, 218),
        inputFocus = Color3.fromRGB(174, 174, 174),
        dotOff = Color3.fromRGB(79, 79, 79),
        pillBorder = Color3.fromRGB(84, 84, 84),
        modeBtnBrd = Color3.fromRGB(84, 84, 84),
        presetBg = Color3.fromRGB(12, 25, 8),
        presetBrd = Color3.fromRGB(84, 84, 84),
        presetLoad = Color3.fromRGB(174, 174, 174),
        presetDel = Color3.fromRGB(95, 95, 95),
        delBrd = Color3.fromRGB(139, 139, 139),
        lockOn = Color3.fromRGB(174, 174, 174),
        adTitle = Color3.fromRGB(174, 174, 174),
        adSub = Color3.fromRGB(218, 218, 218),
        adKeyLbl = Color3.fromRGB(255, 255, 255),
        adKeyBtn = Color3.fromRGB(174, 174, 174),
        adKeyBtnText = Color3.fromRGB(255, 255, 255),
        adActionBtn = Color3.fromRGB(174, 174, 174),
        adActionBtnText = Color3.fromRGB(255, 255, 255),
        adOffBg = Color3.fromRGB(52, 52, 52),
        adDimText = Color3.fromRGB(255, 255, 255),
        adBorder = Color3.fromRGB(174, 174, 174),
        adStroke = Color3.fromRGB(174, 174, 174),
        adBg = Color3.fromRGB(0, 0, 0),
        autoGrabText = Color3.fromRGB(255, 255, 255),
        autoGrabLine = Color3.fromRGB(174, 174, 174),
    },
    ["rbxassetid://139630779093907"] = {  -- 7UP DARK
        main = Color3.fromRGB(103, 103, 103),
        mainLight = Color3.fromRGB(163, 163, 163),
        mainDark = Color3.fromRGB(77, 77, 77),
        accent = Color3.fromRGB(103, 103, 103),
        text = Color3.fromRGB(255, 255, 255),
        subText = Color3.fromRGB(177, 177, 177),
        border = Color3.fromRGB(103, 103, 103),
        buttonBg = Color3.fromRGB(103, 103, 103),
        buttonText = Color3.fromRGB(255, 255, 255),
        speedText = Color3.fromRGB(103, 103, 103),
        discordText = Color3.fromRGB(131, 131, 131),
        tabActive = Color3.fromRGB(163, 163, 163),
        tabIdle = Color3.fromRGB(103, 103, 103),
        progressBg = Color3.fromRGB(8, 25, 15),
        toggleOn = Color3.fromRGB(103, 103, 103),
        toggleOff = Color3.fromRGB(10, 35, 20),
        inputBg = Color3.fromRGB(6, 18, 10),
        inputBorder = Color3.fromRGB(58, 58, 58),
        inputText = Color3.fromRGB(177, 177, 177),
        rowBg = Color3.fromRGB(10, 22, 14),
        rowHover = Color3.fromRGB(18, 35, 22),
        sectionHeader = Color3.fromRGB(103, 103, 103),
        closeBtn = Color3.fromRGB(70, 70, 70),
        closeBtnHover = Color3.fromRGB(103, 103, 103),
        titleText = Color3.fromRGB(177, 177, 177),
        subtitleText = Color3.fromRGB(103, 103, 103),
        stackBg = Color3.fromRGB(8, 20, 12),
        stackActive = Color3.fromRGB(77, 77, 77),
        stackText = Color3.fromRGB(231, 231, 231),
        stackActiveText = Color3.fromRGB(255, 255, 255),
        stackBorder = Color3.fromRGB(77, 77, 77),
        stackActiveBorder = Color3.fromRGB(103, 103, 103),
        dot = Color3.fromRGB(57, 57, 57),
        dotOn = Color3.fromRGB(103, 103, 103),
        pillOff = Color3.fromRGB(10, 35, 20),
        pillOn = Color3.fromRGB(103, 103, 103),
        modeBtnBg = Color3.fromRGB(6, 18, 10),
        modeBtnActBg = Color3.fromRGB(103, 103, 103),
        modeBtnTxt = Color3.fromRGB(103, 103, 103),
        modeBtnActTx = Color3.fromRGB(10, 30, 15),
        chipBorder = Color3.fromRGB(58, 58, 58),
        chipTxt = Color3.fromRGB(103, 103, 103),
        btnBg = Color3.fromRGB(8, 20, 12),
        btnTxt = Color3.fromRGB(231, 231, 231),
        btnHov = Color3.fromRGB(18, 35, 22),
        infoTxt = Color3.fromRGB(103, 103, 103),
        infoVal = Color3.fromRGB(177, 177, 177),
        infoFill = Color3.fromRGB(103, 103, 103),
        divider = Color3.fromRGB(57, 57, 57),
        winBorder = Color3.fromRGB(103, 103, 103),
        topBg = Color3.fromRGB(4, 12, 7),
        topBtn = Color3.fromRGB(70, 70, 70),
        tabBarBg = Color3.fromRGB(0, 0, 0),
        tabIdleHov = Color3.fromRGB(177, 177, 177),
        tabActiveBg = Color3.fromRGB(8, 28, 15),
        tabUnderline = Color3.fromRGB(103, 103, 103),
        rowBorder = Color3.fromRGB(57, 57, 57),
        rowLabel = Color3.fromRGB(231, 231, 231),
        rowSub = Color3.fromRGB(171, 171, 171),
        rowValue = Color3.fromRGB(177, 177, 177),
        inputFocus = Color3.fromRGB(103, 103, 103),
        dotOff = Color3.fromRGB(57, 57, 57),
        pillBorder = Color3.fromRGB(58, 58, 58),
        modeBtnBrd = Color3.fromRGB(58, 58, 58),
        presetBg = Color3.fromRGB(6, 18, 10),
        presetBrd = Color3.fromRGB(58, 58, 58),
        presetLoad = Color3.fromRGB(103, 103, 103),
        presetDel = Color3.fromRGB(70, 70, 70),
        delBrd = Color3.fromRGB(112, 112, 112),
        lockOn = Color3.fromRGB(103, 103, 103),
        adTitle = Color3.fromRGB(103, 103, 103),
        adSub = Color3.fromRGB(177, 177, 177),
        adKeyLbl = Color3.fromRGB(255, 255, 255),
        adKeyBtn = Color3.fromRGB(103, 103, 103),
        adKeyBtnText = Color3.fromRGB(255, 255, 255),
        adActionBtn = Color3.fromRGB(103, 103, 103),
        adActionBtnText = Color3.fromRGB(255, 255, 255),
        adOffBg = Color3.fromRGB(37, 37, 37),
        adDimText = Color3.fromRGB(255, 255, 255),
        adBorder = Color3.fromRGB(103, 103, 103),
        adStroke = Color3.fromRGB(103, 103, 103),
        adBg = Color3.fromRGB(0, 0, 0),
        autoGrabText = Color3.fromRGB(255, 255, 255),
        autoGrabLine = Color3.fromRGB(103, 103, 103),
    },
}

-- The red colorway is derived from whichever soda/background palette is
-- selected, so changing the background never silently switches the UI green.
function get7UpThemeScheme(baseScheme, mode)
    baseScheme = baseScheme or COLOR_SCHEMES["rbxassetid://102557909116203"]
    if mode ~= "Red" then return _G._K7ApplyUserColors(baseScheme) end
    local themed = {}
    for key, value in pairs(baseScheme) do
        if typeof(value) == "Color3" then
            local hue, saturation, brightness = Color3.toHSV(value)
            local isGreenFamily = value.G > value.R * 1.08 and value.G > value.B * 1.04
            if isGreenFamily and saturation > 0.12 then
                -- Preserve the original brightness/contrast but move the hue
                -- to 7UP red. Dark greens become dark reds, not flat neon.
                themed[key] = Color3.fromHSV(0.985, math.clamp(saturation * 1.04, 0, 1), brightness)
            else
                themed[key] = value
            end
        else
            themed[key] = value
        end
    end
    themed.main = Color3.fromRGB(220, 32, 46)
    themed.mainLight = Color3.fromRGB(255, 92, 105)
    themed.mainDark = Color3.fromRGB(132, 12, 28)
    themed.accent = themed.main
    themed.border = themed.main
    themed.buttonBg = themed.main
    themed.speedText = themed.mainLight
    themed.discordText = themed.mainLight
    themed.sectionHeader = themed.mainLight
    themed.toggleOn = themed.main
    themed.tabActive = themed.mainLight
    themed.tabIdle = themed.main
    themed.tabUnderline = themed.main
    themed.stackActive = themed.mainDark
    themed.stackActiveBorder = themed.main
    themed.dotOn = themed.main
    themed.pillOn = themed.main
    themed.modeBtnActBg = themed.main
    themed.modeBtnTxt = themed.mainLight
    themed.chipTxt = themed.mainLight
    themed.infoTxt = themed.mainLight
    themed.infoFill = themed.main
    themed.winBorder = themed.main
    themed.inputFocus = themed.main
    themed.presetLoad = themed.main
    themed.lockOn = themed.main
    themed.adTitle = themed.mainLight
    themed.adKeyBtn = themed.main
    themed.adActionBtn = themed.main
    themed.adBorder = themed.main
    themed.adStroke = themed.main
    themed.autoGrabLine = themed.main
    return _G._K7ApplyUserColors(themed)
end


-- ============================================================
-- MONO THEME (black / gray) + USER COLOR OVERRIDES
-- ============================================================
_G._K7UserColors = _G._K7UserColors or {
    letters = nil,   -- menu text
    bottom  = nil,   -- menu background
    btnText = nil,   -- floating button text
    btnBg   = nil,   -- floating button background
    bar     = nil,   -- auto grab loading bar
}
-- Default look: light blue surfaces with dark ink text.
if _G._K7UserColors.letters == nil then _G._K7UserColors.letters = Color3.fromRGB(20,55,95) end
if _G._K7UserColors.bottom  == nil then _G._K7UserColors.bottom  = Color3.fromRGB(210,235,252) end

do
    local UC = _G._K7UserColors

    local LETTER_KEYS = {"text","subText","titleText","subtitleText","rowLabel","rowSub","rowValue",
        "sectionHeader","buttonText","btnTxt","infoTxt","infoVal","chipTxt","modeBtnTxt","tabActive",
        "tabIdle","tabIdleHov","inputText","discordText","speedText","adTitle","adSub","adDimText"}
    local BOTTOM_KEYS = {"topBg","tabBarBg","tabActiveBg","rowBg","rowHover","inputBg","btnBg","btnHov",
        "modeBtnBg","presetBg","adBg","progressBg","adOffBg"}
    local BTN_TEXT_KEYS = {"stackText","stackActiveText"}
    local BTN_BG_KEYS = {"stackBg","stackActive","stackBorder","stackActiveBorder"}
    local BAR_KEYS = {"autoGrabLine"}

    local function lum(c) return c.R*0.299 + c.G*0.587 + c.B*0.114 end

    local function grayOf(c)
        local l = lum(c)
        return Color3.new(l, l, l)
    end

    local function scale(c, f)
        return Color3.new(math.clamp(c.R*f,0,1), math.clamp(c.G*f,0,1), math.clamp(c.B*f,0,1))
    end

    local function mixWhite(c, f)
        return Color3.new(c.R+(1-c.R)*f, c.G+(1-c.G)*f, c.B+(1-c.B)*f)
    end

    -- Inverse/contrast state used when a floating button turns ON.
    -- Dark colors get brighter (black -> gray), bright colors get darker
    -- (red -> dark red), so every palette has a readable active state.
    function _G._K7ActiveVariant(c)
        if not c then return c end
        if lum(c) < 0.28 then
            return mixWhite(c, 0.42)
        end
        return scale(c, 0.55)
    end

    function _G._K7ApplyUserColors(scheme)
        -- Light blue hub: soft sky panels, bright cyan accents.
        local out = {}
        for k, v in pairs(scheme) do out[k] = v end
        local LB_GLOW   = Color3.fromRGB(230, 250, 255)
        local LB_LIGHT  = Color3.fromRGB(120, 220, 255)
        local LB_MID    = Color3.fromRGB(0, 0, 0)
        local LB_DEEP   = Color3.fromRGB(30, 130, 230)
        local LB_SOFT   = Color3.fromRGB(160, 220, 255)
        local LB_PANEL  = Color3.fromRGB(175, 220, 250)
        local LB_ROW    = Color3.fromRGB(155, 210, 245)
        local LB_HOVER  = Color3.fromRGB(120, 200, 250)
        local LB_BG     = Color3.fromRGB(190, 230, 255)
        local LB_VOID   = Color3.fromRGB(170, 215, 250)
        local INK       = Color3.fromRGB(10, 40, 85)
        local INK_SOFT  = Color3.fromRGB(25, 80, 140)
        local WHITE     = Color3.fromRGB(255, 255, 255)

        out.main = LB_MID
        out.mainLight = LB_GLOW
        out.mainDark = LB_DEEP
        out.accent = LB_LIGHT
        out.border = LB_LIGHT
        out.buttonBg = LB_DEEP
        out.buttonText = WHITE
        out.text = INK
        out.subText = INK_SOFT
        out.titleText = INK
        out.subtitleText = LB_DEEP
        out.sectionHeader = LB_DEEP
        out.speedText = LB_DEEP
        out.discordText = LB_DEEP
        out.tabActive = LB_GLOW
        out.tabIdle = LB_MID
        out.tabIdleHov = LB_LIGHT
        out.tabUnderline = LB_LIGHT
        out.tabActiveBg = LB_PANEL
        out.tabBarBg = LB_VOID
        out.topBg = LB_BG
        out.topBtn = LB_DEEP
        out.progressBg = LB_SOFT
        out.toggleOn = LB_MID
        out.toggleOff = LB_SOFT
        out.inputBg = LB_PANEL
        out.inputBorder = LB_MID
        out.inputText = INK
        out.inputFocus = LB_LIGHT
        out.rowBg = LB_ROW
        out.rowHover = LB_HOVER
        out.rowBorder = LB_LIGHT
        out.rowLabel = INK
        out.rowSub = INK_SOFT
        out.rowValue = LB_DEEP
        out.stackBg = LB_PANEL
        out.stackActive = LB_MID
        out.stackText = INK
        out.stackActiveText = WHITE
        out.stackBorder = LB_MID
        out.stackActiveBorder = LB_LIGHT
        out.dot = LB_SOFT
        out.dotOn = LB_MID
        out.dotOff = LB_SOFT
        out.pillOff = LB_SOFT
        out.pillOn = LB_MID
        out.pillBorder = LB_LIGHT
        out.modeBtnBg = LB_PANEL
        out.modeBtnActBg = LB_MID
        out.modeBtnTxt = LB_DEEP
        out.modeBtnActTx = WHITE
        out.modeBtnBrd = LB_MID
        out.chipBorder = LB_MID
        out.chipTxt = LB_DEEP
        out.btnBg = LB_PANEL
        out.btnTxt = INK
        out.btnHov = LB_HOVER
        out.infoTxt = LB_DEEP
        out.infoVal = INK
        out.infoFill = LB_MID
        out.divider = LB_LIGHT
        out.winBorder = LB_LIGHT
        out.presetBg = LB_PANEL
        out.presetBrd = LB_MID
        out.presetLoad = LB_MID
        out.presetDel = LB_DEEP
        out.delBrd = LB_MID
        out.lockOn = LB_MID
        out.closeBtn = LB_DEEP
        out.closeBtnHover = LB_MID
        out.adTitle = LB_DEEP
        out.adSub = INK_SOFT
        out.adKeyLbl = INK
        out.adKeyBtn = LB_MID
        out.adKeyBtnText = WHITE
        out.adActionBtn = LB_MID
        out.adActionBtnText = WHITE
        out.adOffBg = LB_SOFT
        out.adDimText = INK_SOFT
        out.adBorder = LB_LIGHT
        out.adStroke = LB_MID
        out.adBg = LB_BG
        out.autoGrabText = INK
        out.autoGrabLine = LB_MID
        out.primaryForeground = INK

        _G._K7UserColors = {
            letters = INK,
            bottom  = LB_BG,
            btnText = INK,
            btnBg   = LB_PANEL,
            bar     = LB_MID,
        }
        _G._K7LiveScheme = out
        return out
    end

    function _G._K7StackBg(on)
        local live = _G._K7LiveScheme or {}
        local base = UC.btnBg or live.stackBg or Color3.fromRGB(18,18,18)
        if on then return _G._K7ActiveVariant(base) end
        return base
    end

    function _G._K7StackText(on)
        local live = _G._K7LiveScheme or {}
        local base = UC.btnText or live.stackText or Color3.fromRGB(235,235,235)
        if on then return _G._K7ActiveVariant(base) end
        return base
    end

    -- ── Color palette popup ──────────────────────────────────
    local PALETTE = {
        Color3.fromRGB(0,0,0),      Color3.fromRGB(70,70,70),   Color3.fromRGB(140,140,140), Color3.fromRGB(255,255,255),
        Color3.fromRGB(220,32,46),  Color3.fromRGB(120,10,20),  Color3.fromRGB(255,120,120), Color3.fromRGB(255,80,0),
        Color3.fromRGB(255,170,0),  Color3.fromRGB(255,225,0),  Color3.fromRGB(183, 183, 183),   Color3.fromRGB(131, 131, 131),
        Color3.fromRGB(77, 77, 77),   Color3.fromRGB(0,200,200),  Color3.fromRGB(0,140,255),   Color3.fromRGB(20,60,200),
        Color3.fromRGB(120,60,220), Color3.fromRGB(200,80,255), Color3.fromRGB(255,90,200),  Color3.fromRGB(140,90,50),
    }

    local paletteGui

    function _G._K7OpenPalette(titleText, onPick)
        local parent = (_G._K7GetGuiParent and _G._K7GetGuiParent()) or game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not parent then return end
        if paletteGui then paletteGui:Destroy() end

        paletteGui = Instance.new("ScreenGui")
        paletteGui.Name = "SevenUpColorPalette"
        paletteGui.ResetOnSpawn = false
        paletteGui.IgnoreGuiInset = true
        paletteGui.DisplayOrder = 999
        paletteGui.Parent = parent

        local shade = Instance.new("TextButton", paletteGui)
        shade.Size = UDim2.new(1,0,1,0)
        shade.BackgroundColor3 = Color3.fromRGB(0,0,0)
        shade.BackgroundTransparency = 0.5
        shade.BorderSizePixel = 0
        shade.Text = ""
        shade.AutoButtonColor = false

        local box = Instance.new("Frame", paletteGui)
        box.AnchorPoint = Vector2.new(0.5,0.5)
        box.Position = UDim2.new(0.5,0,0.5,0)
        box.Size = UDim2.new(0,300,0,290)
        box.BackgroundColor3 = Color3.fromRGB(16,16,16)
        box.BorderSizePixel = 0
        local c = Instance.new("UICorner", box); c.CornerRadius = UDim.new(0,16)
        local st = Instance.new("UIStroke", box); st.Color = Color3.fromRGB(90,90,90); st.Thickness = 1.5

        local title = Instance.new("TextLabel", box)
        title.Size = UDim2.new(1,-58,0,34)
        title.Position = UDim2.new(0,14,0,6)
        title.BackgroundTransparency = 1
        title.Text = tostring(titleText or "COLOR")
        title.TextColor3 = Color3.fromRGB(240,240,240)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 13
        title.TextXAlignment = Enum.TextXAlignment.Left

        local closeBtn = Instance.new("TextButton", box)
        closeBtn.Size = UDim2.new(0,30,0,30)
        closeBtn.Position = UDim2.new(1,-38,0,8)
        closeBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
        closeBtn.BorderSizePixel = 0
        closeBtn.Text = "X"
        closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 14
        local cc = Instance.new("UICorner", closeBtn); cc.CornerRadius = UDim.new(0,10)

        local grid = Instance.new("Frame", box)
        grid.Size = UDim2.new(1,-28,0,180)
        grid.Position = UDim2.new(0,14,0,46)
        grid.BackgroundTransparency = 1
        local gl = Instance.new("UIGridLayout", grid)
        gl.CellSize = UDim2.new(0,58,0,38)
        gl.CellPadding = UDim2.new(0,8,0,8)

        local function close()
            if paletteGui then paletteGui:Destroy() paletteGui = nil end
        end
        _G._K7SafeClick(closeBtn, close)
        _G._K7SafeClick(shade, close)

        for _, col in ipairs(PALETTE) do
            local sw = Instance.new("TextButton", grid)
            sw.BackgroundColor3 = col
            sw.BorderSizePixel = 0
            sw.Text = ""
            local swc = Instance.new("UICorner", sw); swc.CornerRadius = UDim.new(0,10)
            local sws = Instance.new("UIStroke", sw); sws.Color = Color3.fromRGB(120,120,120); sws.Transparency = 0.4
            _G._K7SafeClick(sw, function()
                pcall(onPick, col)
                close()
            end)
        end

        local resetBtn = Instance.new("TextButton", box)
        resetBtn.Size = UDim2.new(1,-28,0,34)
        resetBtn.Position = UDim2.new(0,14,1,-44)
        resetBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
        resetBtn.BorderSizePixel = 0
        resetBtn.Text = "DEFAULT"
        resetBtn.TextColor3 = Color3.fromRGB(235,235,235)
        resetBtn.Font = Enum.Font.GothamBold
        resetBtn.TextSize = 12
        local rc = Instance.new("UICorner", resetBtn); rc.CornerRadius = UDim.new(0,10)
        _G._K7SafeClick(resetBtn, function()
            pcall(onPick, nil)
            close()
        end)
    end
end

COLOR_SCHEMES["rbxassetid://82457207608895"] = COLOR_SCHEMES["rbxassetid://102557909116203"]
COLOR_SCHEMES["rbxassetid://86319509375427"] = COLOR_SCHEMES["rbxassetid://85219527046711"]
COLOR_SCHEMES["rbxassetid://85428036348598"] = COLOR_SCHEMES["rbxassetid://139630779093907"]
COLOR_SCHEMES["rbxassetid://86238578096423"] = COLOR_SCHEMES["rbxassetid://102557909116203"]
GREEN_7UP_BACKGROUND = "rbxassetid://137970714521556"
RED_7UP_BACKGROUND = "rbxassetid://137970714521556"

_G._K7ThemeMode = _G._K7ThemeMode == "Red" and "Red" or "Green"
_G._K7AccentColor = _G._K7ThemeMode == "Red"
    and Color3.fromRGB(220, 32, 46) or Color3.fromRGB(131, 131, 131)

currentColorScheme = get7UpThemeScheme(
    COLOR_SCHEMES["rbxassetid://102557909116203"], _G._K7ThemeMode
)
currentBgImage = "rbxassetid://137970714521556"

-- One live blend shared by a can's neck and body, so skins/states never split visually.
function adaptiveCanColorSequence(scheme, active)
    return ColorSequence.new(active and Color3.fromRGB(255,255,255) or Color3.fromRGB(0,0,0))
end

-- ============================================================
-- AUTO GRAB MODULE (unchanged)
-- ============================================================
autoGrabModule = (function()
    -- ================================================================
    -- K7 AUTO STEAL MODULE v2 — Normal + Semi modes (ported from Ace)
    -- ================================================================
    local RunService    = game:GetService("RunService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Stats         = game:GetService("Stats")
    local UIS           = game:GetService("UserInputService")
    local TweenService  = game:GetService("TweenService")
    local CoreGui       = game:GetService("CoreGui")

    local Steal = { AutoStealEnabled = false, StealRadius = 10 }
    local selectedStealMode = "Normal"   -- Normal = Auto Grab V3 (80%), Semi = Auto Grab V2
    local StealRadii = { Normal = 63, Semi = 60 }  -- Semi uses the Ambitious V3 prime radius
    local SEMI_V3_DEFAULT_STOP_PERCENT = 75
    local SEMI_V3_DEFAULT_DELAY_RADIUS = 8

    local currentBgImage    = "rbxassetid://137970714521556"
    local currentColorScheme = COLOR_SCHEMES[currentBgImage]

    -- ── StealBar API (shared between Normal and Semi) ─────────────
    local _barGui, _barFrame, _barFill, _barPct, _barBg = nil,nil,nil,nil,nil
    local _barPingLbl, _barRadiusLbl, _barStateLbl, _barCarryLbl = nil,nil,nil,nil
    local _barBrandDisc, _barBrandText, _barFillGradient = nil,nil,nil
    local _barCanWash, _barCanGradient = nil, nil
    local _barSmoothPct = 0
    local _barUI = nil
    local _barScale = 1
    local _barFitScale = 1
    local _barStretch = 0      -- -5..5 : stretch the Auto Grab bar left/right
    local _barBaseWidth = 268

    _G.StealBar = {
        SetState    = function(s)
            local name = tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")

            if _barStateLbl then _barStateLbl.Text = ""; _barStateLbl.Visible = false end
        end,
        SetProgress = function(p)
            p = math.clamp(tonumber(p) or 0, 0, 1)
            if _barFill then
                _barSmoothPct = _barSmoothPct + (p - _barSmoothPct) * 0.8
                _barFill.Size = UDim2.new(_barSmoothPct, 0, 1, 0)
                _barFill.BackgroundColor3 = Color3.fromRGB(45, 205, 255)
            end
            if _barPct then _barPct.Text = tostring(math.floor((_barSmoothPct*100)+0.5)).."%" end
        end,
        Reset = function()
            _barSmoothPct = 0
            if _barFill then _barFill.Size  = UDim2.new(0,0,1,0) end
            if _barPct  then _barPct.Text   = "0%" end
        end,
    }

    local _barBgImg = nil  -- direct reference for instant background updates
    local _barAvatarBg, _barAvatarImg, _barAvatarRing, _barAvatarHolder = nil, nil, nil, nil
    -- Escala compartilhada (usada tambem por setStretch fora desta funcao)
    local function BR(n)
        local s = math.clamp(tonumber(_barScale) or 1, 0.5, 2.5)
        return math.floor(n * s + 0.5)
    end

    -- Brilho cinza que corre pela barra de carregamento do Auto Grab.
    local function _barShineSequence()
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.34, Color3.fromRGB(214, 214, 218)),
            ColorSequenceKeypoint.new(0.46, Color3.fromRGB(150, 150, 156)),
            ColorSequenceKeypoint.new(0.54, Color3.fromRGB(120, 120, 126)),
            ColorSequenceKeypoint.new(0.66, Color3.fromRGB(214, 214, 218)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 255, 255)),
        })
    end

    local _barShineRunning = false
    local function _startBarShine(grad)
        if not grad then return end
        if _barShineRunning then return end
        _barShineRunning = true
        task.spawn(function()
            while true do
                local g = _barFillGradient
                if not (g and g.Parent) then
                    _barShineRunning = false
                    return
                end
                pcall(function()
                    g.Offset = Vector2.new(-1, 0)
                    local tw = TweenService:Create(g, TweenInfo.new(1.15, Enum.EasingStyle.Linear), {Offset = Vector2.new(1, 0)})
                    tw:Play()
                    tw.Completed:Wait()
                end)
                task.wait(0.25)
            end
        end)
    end

    -- ============================================================
    -- AUTO GRAB BAR — painel retangular compacto, sem avatar.
    -- A porcentagem fica no canto inferior esquerdo; Radius e ping real,
    -- no canto inferior direito; a barra fina corre junto da base.
    -- ============================================================
    local function createAutoGrabUI()
        local old = CoreGui:FindFirstChild("K7StealBarGui")
        if old then old:Destroy() end
        local old2 = (LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui")):FindFirstChild("AutoGrab")
        if old2 then old2:Destroy() end

        local scale0 = math.clamp(tonumber(_barScale) or 1, 0.5, 2.5)
        local function R(n) return math.floor(n * scale0 + 0.5) end
        local WHITE = Color3.fromRGB(255, 255, 255)
        local LIGHT_BLUE = Color3.fromRGB(105, 210, 255)
        local CYAN = Color3.fromRGB(45, 205, 255)
        local DARK_CYAN = Color3.fromRGB(10, 105, 155)

        local gui = Instance.new("ScreenGui")
        gui.Name           = "AutoGrab"
        gui.ResetOnSpawn   = false
        gui.DisplayOrder   = 80
        gui.IgnoreGuiInset = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent         = LP:WaitForChild("PlayerGui")
        _barGui = gui
        _G._K7AutoGrabGui = gui

        -- Painel principal
        _barFrame = Instance.new("Frame", gui)
        _barFrame.Name   = "StealBar"
        _barFrame.Size   = UDim2.new(0, R(_barBaseWidth), 0, R(46))
        _barFrame.Position = UDim2.new(0, R(18), 1, -R(46) - 16)
        _barFrame.BackgroundColor3 = WHITE
        _barFrame.BackgroundTransparency = 0
        _barFrame.BorderSizePixel  = 0
        _barFrame.Active           = true
        _barFrame.ClipsDescendants = false
        _barFrame.ZIndex = 20
        Instance.new("UICorner", _barFrame).CornerRadius = UDim.new(0, R(10))
        _G._K7AutoGrabFrame = _barFrame

        _barUI = Instance.new("UIScale", _barFrame)
        _barFitScale = 1
        _barUI.Scale = 1

        local sbStroke = Instance.new("UIStroke", _barFrame)
        sbStroke.Name = "StealBarStroke"
        sbStroke.Color = DARK_CYAN
        sbStroke.Thickness = 1.6
        sbStroke.Transparency = 0

        -- Compat: camada de fundo opcional
        _barBgImg = Instance.new("ImageLabel", _barFrame)
        _barBgImg.Name = "BgImg"
        _barBgImg.Size = UDim2.new(1, 0, 1, 0)
        _barBgImg.Image = ""
        _barBgImg.BackgroundTransparency = 1
        _barBgImg.ImageTransparency = 1
        _barBgImg.BorderSizePixel = 0
        _barBgImg.ZIndex = 1
        _barBgImg.Visible = false
        Instance.new("UICorner", _barBgImg).CornerRadius = UDim.new(1, 0)
        _barCanWash, _barCanGradient = nil, nil
        _barCarryLbl = nil
        _G._K7CarryModeChip = nil
        _G._K7SetCarryStatus = function() end

        -- Trilho interno (fillRegion) com contorno
        _barBg = Instance.new("Frame", _barFrame)
        _barBg.Name = "FillRegion"
        _barBg.Size = UDim2.new(1, R(-16), 0, R(4))
        _barBg.Position = UDim2.new(0, R(8), 1, R(-10))
        _barBg.BackgroundColor3 = Color3.fromRGB(220, 245, 255)
        _barBg.BorderSizePixel = 0
        _barBg.ClipsDescendants = true
        _barBg.ZIndex = 24
        Instance.new("UICorner", _barBg).CornerRadius = UDim.new(0, R(2))
        local fillRegStroke = Instance.new("UIStroke", _barBg)
        fillRegStroke.Color = DARK_CYAN
        fillRegStroke.Thickness = 1
        fillRegStroke.Transparency = 0

        _barFill = Instance.new("Frame", _barBg)
        _barFill.Name = "Fill"
        _barFill.Size = UDim2.new(0, 0, 1, 0)
        _barFill.BackgroundColor3 = CYAN
        _barFill.BorderSizePixel = 0
        _barFill.ZIndex = 25
        Instance.new("UICorner", _barFill).CornerRadius = UDim.new(0, R(2))
        _barFillGradient = Instance.new("UIGradient", _barFill)
        _barFillGradient.Name = "FillAnimGrad"
        _barFillGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, CYAN),
            ColorSequenceKeypoint.new(0.38, CYAN),
            ColorSequenceKeypoint.new(0.50, WHITE),
            ColorSequenceKeypoint.new(0.62, CYAN),
            ColorSequenceKeypoint.new(1.00, CYAN),
        })
        _barFillGradient.Rotation = 0
        _barFillGradient.Offset = Vector2.new(-1, 0)
        _startBarShine(_barFillGradient)

        -- Sem nome fixo: a interface mostra somente os dados úteis.
        _barStateLbl = nil

        -- Porcentagem
        _barPct = Instance.new("TextLabel", _barFrame)
        _barPct.Name = "PctText"
        _barPct.Size = UDim2.new(0, R(48), 0, R(18))
        _barPct.Position = UDim2.new(0, R(10), 0, R(7))
        _barPct.BackgroundTransparency = 1
        _barPct.Text = "0%"
        _barPct.TextColor3 = LIGHT_BLUE
        _barPct.Font = Enum.Font.GothamBold
        _barPct.TextSize = R(12)
        _barPct.TextXAlignment = Enum.TextXAlignment.Left
        _barPct.ZIndex = 26

        -- Radius e ping verdadeiro, sem FPS ou valores substitutos.
        local radiusLbl = Instance.new("TextLabel", _barFrame)
        radiusLbl.Name = "RadiusText"
        radiusLbl.Size = UDim2.new(0, R(82), 0, R(18))
        radiusLbl.Position = UDim2.new(1, R(-92), 0, R(7))
        radiusLbl.BackgroundTransparency = 1
        radiusLbl.Text = "Rad: " .. tostring(StealRadii[selectedStealMode] or Steal.StealRadius or 0)
        radiusLbl.TextColor3 = LIGHT_BLUE
        radiusLbl.Font = Enum.Font.GothamSemibold
        radiusLbl.TextSize = R(9)
        radiusLbl.TextXAlignment = Enum.TextXAlignment.Right
        radiusLbl.ZIndex = 26
        _barRadiusLbl = radiusLbl

        local metaLbl = Instance.new("TextLabel", _barFrame)
        metaLbl.Name = "RealPing"
        metaLbl.Size = UDim2.new(0, R(90), 0, R(18))
        metaLbl.AnchorPoint = Vector2.new(0.5, 0)
        metaLbl.Position = UDim2.new(0.5, 0, 0, R(7))
        metaLbl.BackgroundTransparency = 1
        metaLbl.Text = "Ping: --"
        metaLbl.TextColor3 = LIGHT_BLUE
        metaLbl.Font = Enum.Font.GothamSemibold
        metaLbl.TextSize = R(9)
        metaLbl.TextXAlignment = Enum.TextXAlignment.Center
        metaLbl.TextTruncate = Enum.TextTruncate.None
        metaLbl.ZIndex = 26
        _barPingLbl = metaLbl

        -- Modo (Normal / Semi) — chip abaixo da bola
        local modeLbl = Instance.new("TextLabel", _barFrame)
        modeLbl.Name = "SpeedModeLbl"
        modeLbl.Size = UDim2.new(0, R(46), 0, R(13))
        modeLbl.Position = UDim2.new(0, R(88), 0, R(24))
        modeLbl.BackgroundColor3 = Color3.fromRGB(20, 55, 95)
        modeLbl.BackgroundTransparency = 0.45
        modeLbl.Text = tostring(selectedStealMode or "Normal"):upper()
        modeLbl.TextColor3 = LIGHT_BLUE
        modeLbl.Font = Enum.Font.GothamBold
        modeLbl.TextSize = R(8)
        modeLbl.TextXAlignment = Enum.TextXAlignment.Center
        modeLbl.TextTruncate = Enum.TextTruncate.None
        modeLbl.ZIndex = 27
        Instance.new("UICorner", modeLbl).CornerRadius = UDim.new(1, 0)
        -- Nome do modo (NORMAL / SEMI) removido da interface do Auto Grab.
        modeLbl.Visible = false
        modeLbl.Text = ""
        modeLbl.BackgroundTransparency = 1
        _G._K7StealModeChip = modeLbl

        task.spawn(function()
            local last = nil
            while modeLbl and modeLbl.Parent do
                local m = tostring(selectedStealMode or "Normal"):upper()
                if m ~= last then
                    last = m
                    modeLbl.Text = ""
                    modeLbl.Visible = false
                    if _barRadiusLbl then
                        _barRadiusLbl.Text = "Rad: " .. tostring(StealRadii[selectedStealMode] or Steal.StealRadius or 0)
                    end
                end
                task.wait(0.25)
            end
        end)

        -- Botoes de escala (- / +) fora da pilula, a direita
        local function makeScaleBtn(symbol, yOff, delta)
            local btn = Instance.new("TextButton", _barFrame)
            btn.Size = UDim2.new(0, R(18), 0, R(18))
            btn.Position = UDim2.new(1, R(8), 0.5, yOff)
            btn.BackgroundColor3 = Color3.fromRGB(20, 55, 95)
            btn.BackgroundTransparency = 0
            btn.BorderSizePixel = 0
            btn.AutoButtonColor = false
            btn.Text = symbol
            btn.TextColor3 = LIGHT_BLUE
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = R(13)
            btn.ZIndex = 27
            Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
            local bs = Instance.new("UIStroke", btn)
            bs.Color = DARK_CYAN
            bs.Thickness = 1
            bs.Transparency = 0.35
            _G._K7SafeClick(btn, function()
                _barScale = math.clamp(_barScale + delta, 0.6, 1.6)
                if _barUI then _barUI.Scale = _barScale * (_barFitScale or 1) end
                if _G._K7RequestSave then pcall(_G._K7RequestSave) end
            end)
        end
        makeScaleBtn("+", R(-20), 0.1)
        makeScaleBtn("-", R(2), -0.1)

        -- Arrastar
        do
            local dragging, dragStart, startPos = false, nil, nil
            _barFrame.InputBegan:Connect(function(input)
                if _G._K7UILocked then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true dragStart = input.Position startPos = _barFrame.Position
                    input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then dragging = false end
                    end)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if not dragging then return end
                if _G._K7UILocked then dragging = false return end
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                    local d = input.Position - dragStart
                    _barFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    if dragging and _G._K7RequestSave then pcall(_G._K7RequestSave) end
                    dragging = false
                end
            end)
        end

        -- Ping real do servidor. Mantém a última leitura válida para nunca
        -- piscar 0 ou exibir FPS/outro número no lugar do ping.
        task.spawn(function()
            local lastValidPing = nil
            while metaLbl and metaLbl.Parent do
                local ok, ping = pcall(function()
                    local stat = Stats.Network.ServerStatsItem["Data Ping"]
                    return stat and stat:GetValue() or nil
                end)
                if ok and type(ping) == "number" and ping > 0 and ping < 10000 then
                    lastValidPing = math.floor(ping + 0.5)
                    metaLbl.Text = string.format("Ping: %dms", lastValidPing)
                elseif lastValidPing then
                    metaLbl.Text = string.format("Ping: %dms", lastValidPing)
                end
                task.wait(0.5)
            end
        end)

        print("[Auto Grab] UI Water Duels carregada")
    end

    -- ── updateAutoGrabLineColor (called by changeDuelScriptBackground) ──────
    local function updateAutoGrabLineColor(scheme)
        currentColorScheme = scheme
        local WHITE = Color3.fromRGB(255,255,255)
        local LIGHT_BLUE = Color3.fromRGB(105,210,255)
        local CYAN = Color3.fromRGB(45,205,255)
        local DARK_CYAN = Color3.fromRGB(10,105,155)
        if _barBgImg then _barBgImg.Image = ""; _barBgImg.ImageTransparency = 1; _barBgImg.Visible = false end
        if _barFrame then _barFrame.BackgroundColor3 = WHITE end
        if _barBg then _barBg.BackgroundColor3 = Color3.fromRGB(220,245,255) end
        if _barFill then _barFill.BackgroundColor3 = CYAN end
        if _barFillGradient then
            _barFillGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00,CYAN), ColorSequenceKeypoint.new(0.38,CYAN),
                ColorSequenceKeypoint.new(0.50,WHITE), ColorSequenceKeypoint.new(0.62,CYAN),
                ColorSequenceKeypoint.new(1.00,CYAN)
            })
            _startBarShine(_barFillGradient)
        end
        if _barFrame then
            for _,obj in ipairs(_barFrame:GetChildren()) do if obj:IsA("UIStroke") then obj.Color=DARK_CYAN; obj.Transparency=0 end end
        end
        if _barBg then
            for _,obj in ipairs(_barBg:GetChildren()) do if obj:IsA("UIStroke") then obj.Color=DARK_CYAN; obj.Transparency=0 end end
        end
        if _barPct then _barPct.TextColor3=LIGHT_BLUE end
        if _barPingLbl then _barPingLbl.TextColor3=LIGHT_BLUE end
        if _barRadiusLbl then _barRadiusLbl.TextColor3=LIGHT_BLUE end
    end

    -- ================================================================
    -- NORMAL STEAL SYSTEM (simple proximity, no sync required)
    -- ================================================================
    -- ================================================================
    -- NORMAL STEAL SYSTEM  ==  AUTO STEAL V3 (portado do Adapt Source)
    -- ================================================================
    local getconnections_v3 = getconnections or get_signal_cons or getconnects or (syn and syn.get_signal_cons)
    _G.K7GalaxyV3 = _G.K7GalaxyV3 or {
        conn=nil, active=false, progress=0, paused=false, pauseTime=nil,
        startTime=nil, progressConn=nil, dataCache={}, enabled=false,
        StealRadius=63, StealDuration=1.3, TriggerRadius=10
    }
    _G.K7NormalSteal = _G.K7GalaxyV3
    local GS = _G.K7GalaxyV3

    local function _v3GetHRP()
        local c = LP.Character
        return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso"))
    end

    local function _v3IsMyPlot(plotName)
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return false end
        local plot = plots:FindFirstChild(plotName)
        if not plot then return false end
        local sign = plot:FindFirstChild("PlotSign")
        if sign then
            local yb = sign:FindFirstChild("YourBase")
            if yb and yb:IsA("BillboardGui") then return yb.Enabled == true end
        end
        return false
    end

    local function _v3FindPrompt()
        local hrp = _v3GetHRP()
        if not hrp then return nil, nil end
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return nil, nil end
        local bestPrompt, bestDist, bestSpawn = nil, math.huge, nil

        for _, plot in ipairs(plots:GetChildren()) do
            if plot:IsA("Model") and not _v3IsMyPlot(plot.Name) then
                local pods = plot:FindFirstChild("AnimalPodiums")
                if pods then
                    for _, pod in ipairs(pods:GetChildren()) do
                        pcall(function()
                            local base  = pod:FindFirstChild("Base")
                            local spawn = base and base:FindFirstChild("Spawn")
                            if not spawn then return end
                            local dist = (spawn.Position - hrp.Position).Magnitude
                            if dist >= bestDist or dist > GS.StealRadius then return end

                            local function tryPrompt(container)
                                for _, ch in ipairs(container:GetChildren()) do
                                    if ch:IsA("ProximityPrompt") and ch.Enabled then
                                        bestPrompt = ch; bestDist = dist; bestSpawn = spawn
                                        return true
                                    end
                                end
                                return false
                            end

                            local att = spawn:FindFirstChild("PromptAttachment")
                            if not (att and tryPrompt(att)) then
                                for _, ch in ipairs(spawn:GetDescendants()) do
                                    if ch:IsA("ProximityPrompt") and ch.Enabled then
                                        bestPrompt = ch; bestDist = dist; bestSpawn = spawn
                                        break
                                    end
                                end
                            end
                        end)
                    end
                end
            end
        end
        return bestPrompt, bestSpawn
    end

    local function _v3DistToSpawn(spawnPart)
        local hrp = _v3GetHRP()
        if not hrp then return math.huge end
        if not spawnPart or not spawnPart.Parent then
            local _, ns = _v3FindPrompt()
            return ns and (hrp.Position - ns.Position).Magnitude or math.huge
        end
        return (hrp.Position - spawnPart.Position).Magnitude
    end

    local function _v3UpdateBar(p, state)
        if _G.StealBar then
            pcall(function()
                _G.StealBar.SetProgress(p or 0)
                if state then _G.StealBar.SetState(state) end
            end)
        end
    end

    local function _v3Active()
        return Steal.AutoStealEnabled == true and selectedStealMode == "Normal"
    end

    local function _v3Execute(prompt, spawnPart)
        if GS.active then return end
        -- janela do Ragdoll Steal: apenas PAUSA o grab, nunca desliga o toggle
        if _G.RagdollStealReady and not _G.RagdollStealReady() then return end

        if not GS.dataCache[prompt] then
            local data = {hold={}, trigger={}, ready=true}
            if getconnections_v3 then
                pcall(function()
                    for _, c in ipairs(getconnections_v3(prompt.PromptButtonHoldBegan)) do
                        if c.Function then table.insert(data.hold, c.Function) end
                    end
                    for _, c in ipairs(getconnections_v3(prompt.Triggered)) do
                        if c.Function then table.insert(data.trigger, c.Function) end
                    end
                end)
            end
            GS.dataCache[prompt] = data
        end

        local data = GS.dataCache[prompt]
        if not data.ready then return end

        data.ready   = false
        GS.active    = true
        GS.paused    = false
        GS.startTime = tick() - (GS.progress * GS.StealDuration)
        local pauseArmed = true

        if GS.progressConn then GS.progressConn:Disconnect() end
        _v3UpdateBar(GS.progress, "STEALING")

        GS.progressConn = RunService.Heartbeat:Connect(function()
            if not GS.active then
                if GS.progressConn then GS.progressConn:Disconnect(); GS.progressConn = nil end
                return
            end

            if not GS.enabled or not _v3Active() then
                GS.active = false; GS.progress = 0; GS.paused = false
                data.ready = true
                _v3UpdateBar(0, Steal.AutoStealEnabled and "READY" or "IDLE")
                return
            end

            -- Saiu do Radius do Auto Grab: reseta na hora.
            -- Ao voltar para dentro do Radius o loop principal religa sozinho.
            do
                local rad = tonumber(GS.StealRadius) or 63
                local dNow = _v3DistToSpawn(spawnPart)
                if dNow > rad then
                    GS.active = false
                    GS.progress = 0
                    GS.paused = false
                    GS.pauseTime = nil
                    pauseArmed = true
                    data.ready = true
                    if GS.progressConn then GS.progressConn:Disconnect(); GS.progressConn = nil end
                    _v3UpdateBar(0, Steal.AutoStealEnabled and "READY" or "IDLE")
                    return
                end
            end

            if GS.paused then
                local dist = _v3DistToSpawn(spawnPart)
                if dist <= GS.TriggerRadius then
                    GS.paused = false
                    GS.pauseTime = nil
                    GS.startTime = tick() - (0.8 * GS.StealDuration)
                else
                    if not GS.pauseTime then
                        GS.pauseTime = tick()
                    elseif tick() - GS.pauseTime >= 1.3 then
                        GS.pauseTime = nil
                        GS.paused = false
                        GS.active = false
                        GS.progress = 0
                        data.ready = true
                        pauseArmed = true
                        if GS.progressConn then GS.progressConn:Disconnect(); GS.progressConn = nil end
                        _v3UpdateBar(0, Steal.AutoStealEnabled and "READY" or "IDLE")
                        return
                    end
                    GS.progress = 0.8
                    _v3UpdateBar(0.8, "STEALING")
                    return
                end
            end

            local elapsed = tick() - GS.startTime
            local prog = math.clamp(elapsed / GS.StealDuration, 0, 1)
            GS.progress = prog

            if pauseArmed and prog >= 0.8 then
                GS.paused = true
                pauseArmed = false
                GS.progress = 0.8
                _v3UpdateBar(0.8, "STEALING")
                return
            end

            _v3UpdateBar(prog, "STEALING")

            if prog >= 1 then
                GS.active = false; GS.progress = 0; GS.paused = false
                pauseArmed = true
                if GS.progressConn then GS.progressConn:Disconnect(); GS.progressConn = nil end

                local triggered = false
                for _, fn in ipairs(data.trigger) do
                    triggered = true
                    task.spawn(function() pcall(fn) end)
                end
                if not triggered then
                    pcall(function()
                        if fireproximityprompt then
                            fireproximityprompt(prompt, 0)
                        else
                            prompt:InputHoldBegin()
                            task.wait()
                            prompt:InputHoldEnd()
                        end
                    end)
                end

                data.ready = true
                _v3UpdateBar(0, Steal.AutoStealEnabled and "READY" or "IDLE")
            end
        end)

        for _, fn in ipairs(data.hold) do
            task.spawn(function() pcall(fn) end)
        end
    end

    _G.K7NormalAutoStealSetRadius = function(v)
        GS.StealRadius = tonumber(v) or GS.StealRadius or 63
    end

    _G.K7NormalAutoStealStart = function()
        if GS.conn then GS.conn:Disconnect(); GS.conn = nil end
        GS.enabled       = true
        GS.StealRadius   = tonumber(StealRadii and StealRadii.Normal) or tonumber(Steal.StealRadius) or 63
        GS.StealDuration = 1.3
        GS.TriggerRadius = 10
        GS.conn = RunService.Heartbeat:Connect(function()
            if not GS.enabled or GS.active then return end
            if not _v3Active() then return end
            local prompt, spawnPart = _v3FindPrompt()
            if prompt then _v3Execute(prompt, spawnPart) end
        end)
        _v3UpdateBar(0, "READY")
    end

    _G.K7NormalAutoStealStop = function()
        GS.enabled = false
        if GS.conn then GS.conn:Disconnect(); GS.conn = nil end
        if GS.progressConn then GS.progressConn:Disconnect(); GS.progressConn = nil end
        GS.active = false; GS.progress = 0; GS.paused = false; GS.pauseTime = nil
        GS.dataCache = {}
        _v3UpdateBar(0, Steal.AutoStealEnabled and "READY" or "IDLE")
        pcall(function() if _G.StealBar then _G.StealBar.Reset() end end)
    end

    _G.K7NormalAutoStealSync = function()
        if _v3Active() then
            _G.K7NormalAutoStealStart()
        else
            _G.K7NormalAutoStealStop()
        end
    end

    -- ================================================================
    -- SEMI STEAL SYSTEM (sync-based, tight proximity, waits for range)
    -- ================================================================
    _G.K7SemiSteal = _G.K7SemiSteal or {}
    local AS = _G.K7SemiSteal
    AS.conn         = AS.conn
    AS.scanThread   = AS.scanThread
    AS.enabled      = false
    AS.holdMin      = 1.3
    AS.holdMax      = 2.99
    AS.autoGrabStopPercent = tonumber(State and State.semiStopPercent) or AS.autoGrabStopPercent or SEMI_V3_DEFAULT_STOP_PERCENT
    AS.autoGrabSetDelayRadius = tonumber(State and State.semiDelayRadius) or AS.autoGrabSetDelayRadius or SEMI_V3_DEFAULT_DELAY_RADIUS
    AS.cooldown     = 0.05
    AS.primeRange   = 80
    AS.radius       = StealRadii.Semi
    AS.plotSync     = AS.plotSync or {caches={}, connections={}}
    AS.animals      = AS.animals or {}
    AS.promptCache  = AS.promptCache or {}
    AS.internalCache = AS.internalCache or {}
    AS.state        = AS.state or {active=false, startTime=0, phase="idle", label="", lastResult="", lastResultTime=0}

    local function _semiBarSet(p, label)
        pcall(function()
            if _G.StealBar then
                _G.StealBar.SetState(label or "STEALING")
                _G.StealBar.SetProgress(math.clamp(tonumber(p) or 0, 0, 1))
            end
        end)
    end
    local function _semiBarReset()
        pcall(function() if _G.StealBar then _G.StealBar.Reset() end end)
    end

    local function _semiRoot()
        local c = LP.Character
        return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso")) or nil
    end

    -- path diff helpers
    local function _splitPath(path)
        if typeof(path)=="table" then return path end
        local out = {}
        for p in string.gmatch(tostring(path), "[^%.]+") do
            table.insert(out, tonumber(p) or p)
        end
        return out
    end
    local function _resolvePath(path, root)
        local cur, par, key = root, nil, nil
        for _, p in ipairs(_splitPath(path)) do par=cur; key=p; cur=cur and cur[p] or nil end
        return cur, par, key
    end
    local function _applyDiff(channelName, packet)
        local cache = AS.plotSync.caches[channelName]
        if typeof(cache)~="table" then return end
        local path, action, a, b = packet[1], packet[2], packet[3], packet[4]
        local cur, par, key = _resolvePath(path, cache)
        if action=="Changed" then if par then par[key]=a end
        elseif action=="ArrayInsert" then if cur then table.insert(cur, b, a) end
        elseif action=="ArrayRemoved" then if cur then table.remove(cur, b) end
        elseif action=="DictionaryInsert" then if cur then cur[b]=a end
        elseif action=="DictionaryRemoved" then if cur then cur[b]=nil end
        end
    end

    local function _semiAttachChannel(remote, plots, requestData)
        if AS.plotSync.connections[remote] then return end
        local channelName = tostring(remote.Name)
        if not plots:FindFirstChild(channelName) then return end
        if requestData and AS.plotSync.caches[channelName]==nil then
            local ok, data = pcall(function() return requestData:InvokeServer(channelName) end)
            AS.plotSync.caches[channelName] = (ok and typeof(data)=="table") and data or {}
        elseif AS.plotSync.caches[channelName]==nil then
            AS.plotSync.caches[channelName] = {}
        end
        AS.plotSync.connections[remote] = remote.OnClientEvent:Connect(function(queue)
            for _, packet in ipairs(queue) do _applyDiff(channelName, packet) end
        end)
    end

    local function _semiEnsureSync()
        if AS.syncReady then return true end
        local ok = pcall(function()
            AS.plots = workspace:WaitForChild("Plots", 10)
            local rs = game:GetService("ReplicatedStorage")
            local pkgs = rs:WaitForChild("Packages", 10)
            local datas = rs:WaitForChild("Datas", 10)
            if not (pkgs and datas and AS.plots) then return end
            AS.animalsData = require(datas:WaitForChild("Animals", 10))
            local sync = pkgs:WaitForChild("Synchronizer", 10)
            AS.channelFolder = sync:WaitForChild("Channel", 10)
            AS.routeRemote   = sync:WaitForChild("CommunicationRoute", 10)
            AS.requestData   = sync:FindFirstChild("RequestData")
            for _, child in ipairs(AS.channelFolder:GetChildren()) do
                if child:IsA("RemoteEvent") then _semiAttachChannel(child, AS.plots, AS.requestData) end
            end
            AS.channelFolder.ChildAdded:Connect(function(child)
                if child:IsA("RemoteEvent") then _semiAttachChannel(child, AS.plots, AS.requestData) end
            end)
            AS.routeRemote.OnClientEvent:Connect(function(actions)
                for _, action in ipairs(actions) do
                    local kind, cn = action[1], tostring(action[2])
                    if AS.plots and AS.plots:FindFirstChild(cn) then
                        if kind=="ListenerAdded" then
                            local r = AS.channelFolder and AS.channelFolder:FindFirstChild(cn)
                            if r and r:IsA("RemoteEvent") then _semiAttachChannel(r, AS.plots, AS.requestData) end
                        elseif kind=="ListenerRemoved" then
                            for remote, conn in pairs(AS.plotSync.connections) do
                                if tostring(remote.Name)==cn then
                                    pcall(function() conn:Disconnect() end)
                                    AS.plotSync.connections[remote] = nil
                                    AS.plotSync.caches[cn] = nil
                                    break
                                end
                            end
                        end
                    end
                end
            end)
            AS.syncReady = true
        end)
        return ok and AS.syncReady==true
    end

    local function _semiPlotOwner(plot)
        local sign  = plot and plot:FindFirstChild("PlotSign")
        local frame = sign and sign:FindFirstChild("SurfaceGui") and sign.SurfaceGui:FindFirstChild("Frame")
        local label = frame and frame:FindFirstChild("TextLabel")
        if not label or label.Text=="Empty Base" then return nil end
        return label.Text:gsub("'s [Bb]ase$",""):gsub("%s+$","")
    end
    local function _semiIsMyBase(animalData)
        if not animalData or not animalData.plot or not AS.plots then return false end
        local plot = AS.plots:FindFirstChild(animalData.plot)
        if not plot then return false end
        local owner = _semiPlotOwner(plot)
        return owner==LP.DisplayName or owner==LP.Name
    end
    local function _semiPodiumFor(animalData)
        local plot = AS.plots and AS.plots:FindFirstChild(animalData.plot)
        local pds  = plot and plot:FindFirstChild("AnimalPodiums")
        return pds and pds:FindFirstChild(animalData.slot) or nil
    end
    local function _semiAnimalPos(animalData)
        local pod = _semiPodiumFor(animalData)
        return pod and pod:GetPivot().Position or nil
    end
    local function _semiDistToAnimal(animalData)
        local root = _semiRoot()
        local pos  = _semiAnimalPos(animalData)
        return root and pos and (root.Position-pos).Magnitude or math.huge
    end
    local function _semiFindPrompt(animalData)
        if not animalData then return nil end
        local cached = AS.promptCache[animalData.uid]
        if cached and cached.Parent then return cached end
        local pod    = _semiPodiumFor(animalData)
        local base   = pod and pod:FindFirstChild("Base")
        local spawn  = base and base:FindFirstChild("Spawn")
        local attach = spawn and spawn:FindFirstChild("PromptAttachment")
        if not attach then return nil end
        for _, p in ipairs(attach:GetChildren()) do
            if p:IsA("ProximityPrompt") then AS.promptCache[animalData.uid]=p; return p end
        end
        return nil
    end
    local function _semiBuildCallbacks(prompt)
        if AS.internalCache[prompt] then return end
        local data = {holdCallbacks={}, triggerCallbacks={}, ready=true}
        local okH, holds = pcall(getconnections, prompt.PromptButtonHoldBegan)
        if okH and type(holds)=="table" then
            for _, c in ipairs(holds) do if type(c.Function)=="function" then table.insert(data.holdCallbacks, c.Function) end end
        end
        local okT, triggers = pcall(getconnections, prompt.Triggered)
        if okT and type(triggers)=="table" then
            for _, c in ipairs(triggers) do if type(c.Function)=="function" then table.insert(data.triggerCallbacks, c.Function) end end
        end
        -- Keep the prompt cached even when the executor cannot expose signal
        -- connections; _semiExecute then uses the proximity-prompt fallback.
        AS.internalCache[prompt]=data
    end
    -- Ambitious Auto Steal V3: preload to a configurable percentage,
    -- wait for Delay Radius, then finish the bar and trigger the prompt.
    local function _semiExecute(prompt, animalData)
        if not prompt or not prompt.Parent or not animalData then return false end
        if _G.RagdollStealReady and not _G.RagdollStealReady() then return false end
        if AS.state.active then return false end
        if tick()-(AS.state.lastResultTime or 0) < (AS.cooldown or 0.05) then return false end
        _semiBuildCallbacks(prompt)
        local data = AS.internalCache[prompt]
        if not data or not data.ready then return false end
        data.ready=false; AS.state.active=true
        AS.state.startTime=tick(); AS.state.phase="holding"
        AS.state.label = animalData.name or "Animal"

        task.spawn(function()
            local startTime = AS.state.startTime
            local duration = 1.3
            local pct = math.clamp(tonumber(AS.autoGrabStopPercent) or SEMI_V3_DEFAULT_STOP_PERCENT, 1, 100)
            local stopTime = duration * (pct / 100)
            local cancelled = false

            for _, fn in ipairs(data.holdCallbacks) do task.spawn(function() pcall(fn) end) end

            while AS.enabled and selectedStealMode=="Semi" do
                local elapsed = tick()-startTime
                if elapsed >= stopTime then break end
                _semiBarSet(math.clamp(elapsed/duration, 0, 1), "STEALING")
                local root = _semiRoot()
                if not root or not prompt.Parent or not prompt.Parent.Parent then cancelled=true; break end
                if (root.Position-prompt.Parent.Parent.Position).Magnitude > (tonumber(AS.radius) or 60) then cancelled=true; break end
                task.wait()
            end

            local stopProgress = math.clamp(stopTime/duration, 0, 1)
            if not cancelled then _semiBarSet(stopProgress, "STEALING") end
            local phase2Timeout = math.max(2.99-stopTime-math.max(duration-stopTime, 0), 0.05)
            local phase2Start = tick()

            while not cancelled and AS.enabled and selectedStealMode=="Semi" do
                if tick()-phase2Start >= phase2Timeout then cancelled=true; break end
                if not prompt.Parent or not prompt.Parent.Parent then cancelled=true; break end
                local root = _semiRoot()
                if root then
                    local dist = (root.Position-prompt.Parent.Parent.Position).Magnitude
                    if dist <= (tonumber(AS.autoGrabSetDelayRadius) or SEMI_V3_DEFAULT_DELAY_RADIUS) then
                        break
                    elseif dist > (tonumber(AS.radius) or 60) then
                        cancelled=true; break
                    end
                end
                task.wait()
            end

            local fired = false
            if not cancelled and AS.enabled and selectedStealMode=="Semi" then
                local fillDuration = math.max(duration-stopTime, 0)
                local barLead = math.min(0.05, fillDuration)
                local fillRamp = fillDuration-barLead
                local fillStart = tick()
                while true do
                    local fp = fillRamp > 0 and math.clamp((tick()-fillStart)/fillRamp, 0, 1) or 1
                    _semiBarSet(stopProgress+fp*(1-stopProgress), "STEALING")
                    if fp >= 1 then break end
                    task.wait()
                end
                _semiBarSet(1, "STEALING")
                if barLead > 0 then task.wait(barLead) end
                for _, fn in ipairs(data.triggerCallbacks) do fired=true; task.spawn(function() pcall(fn) end) end
                if not fired then
                    pcall(function()
                        if fireproximityprompt then
                            fireproximityprompt(prompt, 0)
                        else
                            prompt:InputHoldBegin(); task.wait(); prompt:InputHoldEnd()
                        end
                    end)
                    fired=true
                end
                pcall(function()
                    if _G.AutoCarrySpeed and _G.AutoCarrySpeed.WatchPickup then _G.AutoCarrySpeed.WatchPickup(1.25) end
                end)
            end

            AS.state.lastResult = fired and ("Stole "..tostring(AS.state.label)) or (cancelled and "Cancelled" or "Missed")
            AS.state.active=false; AS.state.phase="idle"; AS.state.lastResultTime=tick()
            data.ready=true
            _semiBarReset()
        end)
        return true
    end
    local function _semiScanAllPlots()
        if not _semiEnsureSync() then return 0 end
        local newCache = {}
        for _, plot in ipairs(AS.plots:GetChildren()) do
            local cache = AS.plotSync.caches[plot.Name]
            local animalList = cache and cache.AnimalList
            if typeof(animalList)=="table" then
                for slot, animalData in pairs(animalList) do
                    if type(animalData)=="table" then
                        local animalName = animalData.Index
                        local info = AS.animalsData and AS.animalsData[animalName]
                        if info then
                            table.insert(newCache, {
                                name = info.DisplayName or animalName,
                                plot = plot.Name,
                                slot = tostring(slot),
                                uid  = plot.Name.."_"..tostring(slot),
                                mutation   = animalData.Mutation,
                                traits     = animalData.Traits,
                                generation = animalData.Generation,
                            })
                        end
                    end
                end
            end
        end
        AS.animals = newCache
        return #newCache
    end
    local function _semiPickClosest()
        local root = _semiRoot()
        if not root then return nil end
        local best, bestDist = nil, math.huge
        for _, data in ipairs(AS.animals) do
            if not _semiIsMyBase(data) then
                local pos  = _semiAnimalPos(data)
                local dist = pos and (root.Position-pos).Magnitude or math.huge
                if dist <= (AS.primeRange or 80) and dist < bestDist then
                    best, bestDist = data, dist
                end
            end
        end
        return best
    end
    local function _semiEnsureScanThread()
        if AS.scanThread then return end
        AS.scanThread = task.spawn(function()
            while _G.K7SemiSteal do
                if AS.enabled or selectedStealMode=="Semi" then pcall(_semiScanAllPlots) end
                task.wait(5)
            end
        end)
    end

    _G.K7SemiAutoStealStop = function()
        AS.enabled = false
        if AS.conn then AS.conn:Disconnect(); AS.conn=nil end
        AS.state.active=false; AS.state.phase="idle"
        _semiBarReset()
    end

    _G.K7SemiAutoStealStart = function()
        AS.radius  = StealRadii.Semi
        AS.enabled = true
        pcall(_semiEnsureSync)
        _semiEnsureScanThread()
        pcall(_semiScanAllPlots)
        if AS.conn then AS.conn:Disconnect(); AS.conn=nil end
        AS.conn = RunService.Heartbeat:Connect(function()
            if not AS.enabled then return end
            if selectedStealMode~="Semi" then _G.K7SemiAutoStealStop(); return end
            if AS.state.active then return end
            local target = _semiPickClosest()
            if not target then return end
            local prompt = _semiFindPrompt(target)
            if prompt then _semiExecute(prompt, target) end
        end)
    end

    _G.K7SemiAutoStealSync = function()
        if selectedStealMode=="Semi" and Steal.AutoStealEnabled then
            _G.K7SemiAutoStealStart()
        else
            _G.K7SemiAutoStealStop()
        end
    end

    -- ================================================================
    -- MASTER SYNC
    -- ================================================================
    local function autoStealSync()
        if not Steal.AutoStealEnabled then
            if _G.K7NormalAutoStealStop then _G.K7NormalAutoStealStop() end
            if _G.K7SemiAutoStealStop   then _G.K7SemiAutoStealStop()   end
            return
        end
        if selectedStealMode=="Normal" then
            if _G.K7SemiAutoStealStop   then _G.K7SemiAutoStealStop()   end
            if _G.K7NormalAutoStealSync then _G.K7NormalAutoStealSync() end
        elseif selectedStealMode=="Semi" then
            if _G.K7NormalAutoStealStop then _G.K7NormalAutoStealStop() end
            if _G.K7SemiAutoStealSync   then _G.K7SemiAutoStealSync()   end
        end
    end

    -- ================================================================
    -- WATCHDOG: mantem o Auto Grab SEMPRE ativo
    -- ================================================================
    local _agWatchdogStarted = false
    local function _startAutoGrabWatchdog()
        if _agWatchdogStarted then return end
        _agWatchdogStarted = true
        task.spawn(function()
            while true do
                task.wait(0.5)
                pcall(function()
                    -- pausa TEMPORARIA (ragdoll/morcego) — expira sozinha
                    local pu = _G._K7AutoGrabPauseUntil
                    if pu then
                        if os.clock() < pu then return end
                        _G._K7AutoGrabPauseUntil = nil
                    end
                    -- Auto Grab NUNCA reseta: se caiu sem o usuario desligar, religa
                    if not Steal.AutoStealEnabled then
                        if _G._K7AutoGrabUserOff == true then return end
                        Steal.AutoStealEnabled = true
                        pcall(autoStealSync)
                        if toggleSetters and toggleSetters["autoSteal"] then
                            pcall(toggleSetters["autoSteal"], true)
                        end
                    end
                    if selectedStealMode == "Normal" then
                        if AS and AS.conn then _G.K7SemiAutoStealStop() end
                        if not (GS and GS.conn) or GS.enabled ~= true then
                            _G.K7NormalAutoStealStart()
                        end
                        -- ANTI-TRAVAMENTO: se o ciclo ficou preso (barra em 0% e nunca puxa),
                        -- destrava tudo e reinicia o scanner.
                        if GS then
                            local stuck = false
                            local dur = (GS.StealDuration or 1.3)
                            if GS.active and (not GS.progressConn) then stuck = true end
                            if GS.active and (tick() - (GS.startTime or 0)) > (dur + 3) then stuck = true end
                            if stuck then
                                if GS.progressConn then pcall(function() GS.progressConn:Disconnect() end) GS.progressConn = nil end
                                GS.active = false; GS.progress = 0; GS.paused = false; GS.pauseTime = nil
                                GS.dataCache = {}
                                pcall(function() if _G.StealBar then _G.StealBar.Reset() end end)
                                _G.K7NormalAutoStealStart()
                            elseif not GS.active then
                                -- libera qualquer prompt que ficou com ready=false por bug
                                for _, d in pairs(GS.dataCache or {}) do
                                    if type(d) == "table" then d.ready = true end
                                end
                            end
                        end
                    else
                        if GS and GS.conn then _G.K7NormalAutoStealStop() end
                        if not (AS and AS.conn) or AS.enabled ~= true then
                            _G.K7SemiAutoStealStart()
                        end
                        -- ANTI-TRAVAMENTO do modo Semi
                        if AS and AS.state then
                            if AS.state.active and (tick() - (AS.state.startTime or 0)) > ((AS.holdMax or 2.6) + 3) then
                                AS.state.active = false
                                AS.state.phase = "idle"
                                AS.state.lastResultTime = tick()
                                for _, d in pairs(AS.internalCache or {}) do
                                    if type(d) == "table" then d.ready = true end
                                end
                                pcall(function() if _G.StealBar then _G.StealBar.Reset() end end)
                            elseif not AS.state.active then
                                for _, d in pairs(AS.internalCache or {}) do
                                    if type(d) == "table" then d.ready = true end
                                end
                            end
                        end
                    end
                end)
            end
        end)
        -- respawn nunca deve derrubar o Auto Grab
        LP.CharacterAdded:Connect(function()
            task.wait(1.0)
            if Steal.AutoStealEnabled then pcall(autoStealSync) end
        end)
    end
    _G._K7AutoGrabWatchdog = _startAutoGrabWatchdog

    -- ================================================================
    -- MODULE RETURN
    -- ================================================================
    createAutoGrabUI()
    _startAutoGrabWatchdog()

    -- Start hidden — intro (or finishIntro) will pop it in
    if _barGui then _barGui.Enabled = false end
    if _barFrame then _barFrame.Visible = false end

    -- ================================================================
    -- SOFT STEAL (Auto Switch Carry Speed)
    -- ================================================================
    local softStealAnimals = {}
    local softStealScannerConn = nil
    local softStealScanning = false

    local function softStealScanPlots()
        softStealAnimals = {}
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return end
        for _, plot in ipairs(plots:GetChildren()) do
            if plot:IsA("Model") then
                local podiums = plot:FindFirstChild("AnimalPodiums")
                if podiums then
                    for _, podium in ipairs(podiums:GetChildren()) do
                        if podium:IsA("Model") then
                            local base = podium:FindFirstChild("Base")
                            local spawn = base and base:FindFirstChild("Spawn")
                            if spawn then
                                table.insert(softStealAnimals, {
                                    plot = plot.Name,
                                    slot = podium.Name,
                                    worldPosition = spawn.Position,
                                    uid = plot.Name.."_"..podium.Name,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    local function startSoftStealScanner()
        if softStealScannerConn then return end
        softStealScanning = true
        pcall(softStealScanPlots)
        softStealScannerConn = RunService.Heartbeat:Connect(function()
            if not softStealScanning then return end
            pcall(softStealScanPlots)
        end)
    end

    local function stopSoftStealScanner()
        softStealScanning = false
        if softStealScannerConn then
            softStealScannerConn:Disconnect()
            softStealScannerConn = nil
        end
    end

    local function getNearestSoftStealAnimal(radius)
        local root = LP.Character and (LP.Character:FindFirstChild("HumanoidRootPart") or LP.Character:FindFirstChild("UpperTorso"))
        if not root then return nil, math.huge end
        local best, bestDist = nil, math.huge
        for _, data in ipairs(softStealAnimals) do
            if data.worldPosition then
                local dist = (root.Position - data.worldPosition).Magnitude
                if dist < bestDist then
                    best = data
                    bestDist = dist
                end
            end
        end
        if radius and bestDist > radius then
            return nil, bestDist
        end
        return best, bestDist
    end

    local module = {
        start = function()
            Steal.AutoStealEnabled = true
            autoStealSync()
        end,
        stop = function()
            _G._K7AutoGrabUserOff = true
            Steal.AutoStealEnabled = false
            autoStealSync()
        end,
        setEnabled = function(enabled)
            _G._K7AutoGrabUserOff = (enabled == false)
            Steal.AutoStealEnabled = enabled
            autoStealSync()
        end,
        -- PAUSA TEMPORARIA: usada pelo Ragdoll Steal (morcego).
        -- NAO marca o toggle do usuario como desligado e expira sozinha.
        pauseFor = function(dur)
            local d = tonumber(dur) or 1.5
            _G._K7AutoGrabPauseUntil = os.clock() + d
            Steal.AutoStealEnabled = false
            pcall(autoStealSync)
        end,
        resumeFromPause = function()
            _G._K7AutoGrabPauseUntil = nil
            if _G._K7AutoGrabUserOff == true then return end
            Steal.AutoStealEnabled = true
            pcall(autoStealSync)
        end,
        isPaused = function()
            local pu = _G._K7AutoGrabPauseUntil
            if not pu then return false end
            if os.clock() >= pu then _G._K7AutoGrabPauseUntil = nil return false end
            return true
        end,
        setRadius = function(radius)
            local r = tonumber(radius)
            if r then
                r = math.clamp(r, 1, 200)
                StealRadii[selectedStealMode] = r
                Steal.StealRadius = r
                if _barRadiusLbl then _barRadiusLbl.Text = "Rad: " .. tostring(math.floor(r + 0.5)) end
                if _G._K7SyncGrabRadiusValue then pcall(_G._K7SyncGrabRadiusValue, r) end
                if selectedStealMode=="Normal" then
                    GS.StealRadius = r
                else
                    AS.radius = r
                end
            end
        end,
        setMode = function(mode)
            -- aliases from Zombie Hub naming
            if mode == "v3" or mode == "V3" or mode == "Galaxy" then mode = "Normal" end
            if mode == "v2" or mode == "V2" then mode = "Semi" end
            if mode ~= "Normal" and mode ~= "Semi" then mode = "Normal" end
            selectedStealMode = mode
            if _G._K7StealModeChip then
                _G._K7StealModeChip.Text = ""
                _G._K7StealModeChip.Visible = false
            end
            StealRadii[mode] = StealRadii[mode] or (mode == "Semi" and 60 or 63)
            local selectedRadius = StealRadii[mode] or 0
            Steal.StealRadius = selectedRadius
            if _barRadiusLbl then
                _barRadiusLbl.Text = "Rad: " .. tostring(math.floor(selectedRadius + 0.5))
            end
            if _G._K7SyncGrabRadiusValue then pcall(_G._K7SyncGrabRadiusValue, selectedRadius) end
            autoStealSync()
        end,
        getMode = function() return selectedStealMode end,
        getRadii = function() return StealRadii end,
        getStretch = function() return _barStretch end,
        setStretch = function(v)
            v = math.clamp(math.floor(tonumber(v) or 0), -5, 5)
            _barStretch = v
            if not _barFrame then return end
            -- negativo = encurta a pilula, positivo = alarga. Sempre reversivel
            -- porque a largura e recalculada do valor base (nao acumulativa).
            local newW = BR(math.max(_barBaseWidth + v * 22, 130))
            local sz = _barFrame.Size
            _barFrame.Size = UDim2.new(sz.X.Scale, newW, sz.Y.Scale, sz.Y.Offset)
        end,
        getScale = function() return _barScale end,
        setScale = function(s)
            s = tonumber(s) or 1
            _barScale = math.clamp(s, 0.6, 1.6)
            if _barUI then _barUI.Scale = _barScale * _barFitScale end
        end,
        setBackground = function(imageId)
            currentBgImage = imageId
            local baseScheme = COLOR_SCHEMES[imageId] or COLOR_SCHEMES["rbxassetid://102557909116203"]
            local scheme = get7UpThemeScheme(baseScheme, _G._K7ThemeMode)
            currentColorScheme = scheme
            if _barBgImg then
                _barBgImg.Image = ""
                _barBgImg.ImageTransparency = 1
                _barBgImg.Visible = false
            end
            updateAutoGrabLineColor(scheme)
        end,
        updateColors = function(scheme)
            currentColorScheme = scheme
            updateAutoGrabLineColor(scheme)
        end,
        isEnabled = function() return Steal.AutoStealEnabled end,
        getMode   = function() return selectedStealMode end,
        getSteal  = function() return Steal end,
        updateUI  = function() end,
        updateAutoGrabLineColor = updateAutoGrabLineColor,
        hideUI = function()
            if _barGui then _barGui.Enabled = false end
            if _barFrame then _barFrame.Visible = false end
        end,
        showUI = function(animate)
            if _barGui then _barGui.Enabled = true end
            if not _barFrame then return end
            -- Normal load-in: keep the bar's own size/position, just fade the
            -- scale in slightly. No resize/reposition jumps anymore.
            _barFrame.Visible = true
            if animate and _barUI then
                pcall(function()
                    _barUI.Scale = (_barFitScale or 1) * 0.92
                    TweenService:Create(_barUI, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Scale = _barFitScale or 1
                    }):Play()
                end)
            end
        end,
        -- Soft Steal exports
        startSoftStealScanner = startSoftStealScanner,
        stopSoftStealScanner  = stopSoftStealScanner,
        getNearestSoftStealAnimal = getNearestSoftStealAnimal,
    }
    return module
end)()

-- ============================================================
-- ESP & SKY GLOBALS
-- ============================================================
PlayerESP = { enabled = false, conns = {}, playerData = {} }
BoxedESPOptions = { tracker = false, box = false, trackerColor = Color3.fromRGB(230,230,230) }
BoxedESPData   = {}
BoxedESPConn   = nil
SKY_PRESETS_LIST = nil
SKY_PRESETS      = nil
skyTheme         = "Off"

-- ============================================================
-- STEAL DATA
-- ============================================================
Steal = {
    StealRadius = 63,  -- V3 ~80% style radius from Zombie
    AutoStealEnabled = true,
}
-- v3 style: aggressive radius default
if State and State.autoStealMode == "v3" then
    Steal.StealRadius = 75
end

if autoGrabModule then
    autoGrabModule.setRadius(Steal.StealRadius)
    autoGrabModule.setEnabled(Steal.AutoStealEnabled)
end

-- ============================================================
-- CONFIG SAVING VARIABLES
-- ============================================================
CONFIG_VERSION = 5
CONFIG_FILE = "SevenUpDuels_Green_Config.json"
CONFIG_BACKUP = "SevenUpDuels_Green_Config.bak"

function forceLoadConfig()
    local raw = nil
    if _isfile(CONFIG_FILE) then 
        raw = _readfile(CONFIG_FILE) 
    end
    if not raw or raw == "" then
        if _isfile(CONFIG_BACKUP) then
            raw = _readfile(CONFIG_BACKUP)
        end
    end
    if raw and raw ~= "" then
        local ok, dec = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok and dec then
            return dec
        end
    end
    return nil
end

function saveConfigWithRetry(cfg, attempts)
    attempts = attempts or 3
    for i = 1, attempts do
        local success = false
        pcall(function()
            local encoded = HttpService:JSONEncode(cfg)
            _writefile(CONFIG_FILE, encoded)
            local verify = _readfile(CONFIG_FILE)
            if verify == encoded then
                pcall(function() _writefile(CONFIG_BACKUP, encoded) end)
                success = true
            end
        end)
        if success then return true end
        task.wait(0.1)
    end
    return false
end

-- ============================================================
-- INFINITE JUMP (HOLD MODE)
-- ============================================================
UIS.JumpRequest:Connect(function()
    if not State.infJumpEnabled then return end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        root.Velocity = Vector3.new(root.Velocity.X, 55, root.Velocity.Z)
    end
end)

-- ============================================================
-- CUSTOM TOOLS ENGINE (Rainbow / Transparent / Custom)
-- ============================================================
do
    local _Players    = game:GetService("Players")
    local _RunService = game:GetService("RunService")
    local _LP         = _Players.LocalPlayer

    -- Item riconosciuti (Bat / Slap Bat / Medusa's Head)
    local CT_ITEMS = {
        { key = "Bat",    match = function(n) n = n:lower() return n:find("bat") ~= nil or n:find("slap") ~= nil end },
        { key = "Medusa", match = function(n) return n:lower():find("medusa") ~= nil end },
    }

    local function ctMatchItem(inst)
        if not (inst:IsA("Tool") or inst:IsA("Model") or inst:IsA("Accessory") or inst:IsA("BasePart")) then
            return nil
        end
        for _, item in ipairs(CT_ITEMS) do
            if item.match(inst.Name) then return item end
        end
        return nil
    end

    local function isReplicaStuff(d)
        if d.Name == "LocalReplica" then return true end
        return d:FindFirstAncestor("LocalReplica") ~= nil
    end

    -- ------------------------------------------------------------
    -- GESTORE TRASPARENZA CONDIVISO
    -- Evita che Transparent e Custom Tools si sovrascrivano a vicenda.
    -- Ogni modulo "prenota" un valore, vince la priorita' piu' alta,
    -- e il valore originale vero viene letto una sola volta (baseline).
    -- ------------------------------------------------------------
    local CT_Trans = {}
    do
        local PRIORITY = { "custom", "rainbow", "transparent" }
        local baseline = setmetatable({}, { __mode = "k" })
        local claims   = setmetatable({}, { __mode = "k" })
        -- Connessioni GetPropertyChangedSignal("Transparency") per parte:
        -- servono a rimettere subito il valore se il gioco lo sovrascrive
        -- (e' il motivo per cui la bat originale ricompariva sopra la custom).
        local guards   = setmetatable({}, { __mode = "k" })

        function CT_Trans.getBaseline(part)
            local b = baseline[part]
            if b ~= nil then return b end
            local ok, val = pcall(function() return part.Transparency end)
            if not ok then return nil end
            baseline[part] = val
            return val
        end

        local function wantedValue(part)
            local c = claims[part]
            if not c then return nil end
            for _, who in ipairs(PRIORITY) do
                if c[who] ~= nil then return c[who] end
            end
            return nil
        end

        -- Scrive solo se il valore e' davvero diverso: il watchdog dei
        -- Custom Tools richiama claim() sulle stesse parti ogni 0.4s e
        -- senza questo controllo sarebbero centinaia di property write
        -- inutili al secondo.
        local function setIfDifferent(part, v)
            local ok, cur = pcall(function() return part.Transparency end)
            if ok and cur ~= nil and math.abs(cur - v) <= 0.001 then return end
            pcall(function() part.Transparency = v end)
        end

        local function resolve(part)
            local v = wantedValue(part)
            if v ~= nil then
                setIfDifferent(part, v)
                return
            end
            local b = baseline[part]
            if b ~= nil then
                setIfDifferent(part, b)
            end
        end

        -- Riapplica subito il valore prenotato se qualcun altro lo cambia.
        local function armGuard(part)
            if guards[part] then return end
            local ok, conn = pcall(function()
                return part:GetPropertyChangedSignal("Transparency"):Connect(function()
                    local v = wantedValue(part)
                    if v == nil then return end
                    local ok2, cur = pcall(function() return part.Transparency end)
                    if ok2 and cur ~= nil and math.abs(cur - v) > 0.001 then
                        pcall(function() part.Transparency = v end)
                    end
                end)
            end)
            if ok and conn then guards[part] = conn end
        end

        local function disarmGuard(part)
            local conn = guards[part]
            if conn then
                pcall(function() conn:Disconnect() end)
                guards[part] = nil
            end
        end

        -- Rete di sicurezza: se un evento e' andato perso (o la parte e'
        -- stata sostituita) il sweep periodico rimette tutto a posto.
        function CT_Trans.enforce()
            for part, _ in pairs(claims) do
                if part.Parent then
                    local v = wantedValue(part)
                    if v ~= nil then
                        local ok, cur = pcall(function() return part.Transparency end)
                        if ok and cur ~= nil and math.abs(cur - v) > 0.001 then
                            pcall(function() part.Transparency = v end)
                        end
                    end
                end
            end
        end

        function CT_Trans.claim(part, who, value)
            if not part then return end
            if CT_Trans.getBaseline(part) == nil then return end
            local c = claims[part]
            if not c then c = {}; claims[part] = c end
            c[who] = value
            armGuard(part)
            resolve(part)
        end

        function CT_Trans.release(part, who)
            if not part then return end
            local c = claims[part]
            if not c then return end
            c[who] = nil
            if next(c) == nil then
                claims[part] = nil
                disarmGuard(part)
            end
            if part.Parent then resolve(part) end
        end
    end

    -- ------------------------------------------------------------
    -- JANITOR: ogni 10s scarta le entry di oggetti non piu' esistenti,
    -- cosi' le tabelle non crescono in sessioni molto lunghe.
    -- ------------------------------------------------------------
    local CT_JANITORS = {}
    task.spawn(function()
        while true do
            task.wait(10)
            for _, fn in ipairs(CT_JANITORS) do pcall(fn) end
        end
    end)

    -- Sweep trasparenze: 4 volte al secondo rimette i valori prenotati.
    -- Gira solo se almeno uno dei tre moduli e' acceso.
    task.spawn(function()
        while true do
            task.wait(0.25)
            if _G.AmbitiousCustomToolsEnabled == true
            or _G.AmbitiousTransparentToolsEnabled == true
            or _G.AmbitiousRainbowToolsEnabled == true then
                pcall(CT_Trans.enforce)
            end
        end
    end)

    -- ############################################################
    -- ##                     RAINBOW TOOLS                      ##
    -- ############################################################
    do
        local SPEED       = 0.35
        local SPREAD      = 0.035
        local UPDATE_STEP = 1 / 40

        local enabled  = false
        local tracked  = setmetatable({}, { __mode = "k" })
        local watchers = setmetatable({}, { __mode = "k" })
        local unregister

        local function classify(d)
            if d:IsA("MeshPart") then
                return { obj = d, kind = "part", props = { "Color", "Material", "TextureID" }, clearTexture = "TextureID" }
            elseif d:IsA("BasePart") then
                return { obj = d, kind = "part", props = { "Color", "Material" } }
            elseif d:IsA("SurfaceAppearance") then
                return { obj = d, kind = "surface", props = { "Parent" } }
            elseif d:IsA("Decal") or d:IsA("Texture") then
                return { obj = d, kind = "decal", props = {} }
            elseif d:IsA("SpecialMesh") then
                return { obj = d, kind = "vector", prop = "VertexColor", props = { "VertexColor", "TextureId" }, clearTexture = "TextureId" }
            elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
                return { obj = d, kind = "sequence", prop = "Color", props = { "Color" } }
            elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
                return { obj = d, kind = "color", prop = "Color", props = { "Color" } }
            elseif d:IsA("Highlight") then
                return { obj = d, kind = "color", prop = "FillColor", props = { "FillColor" } }
            end
            return nil
        end

        local function snapshot(node)
            node.original = {}
            for _, prop in ipairs(node.props) do
                local ok, val = pcall(function() return node.obj[prop] end)
                if ok then node.original[prop] = val end
            end
        end

        local function restoreNode(node)
            if node.kind == "decal" then CT_Trans.release(node.obj, "rainbow") end
            if not node.original then return end
            for prop, val in pairs(node.original) do
                pcall(function() node.obj[prop] = val end)
            end
        end

        local function applyOnce(node)
            if node.kind == "surface" then
                pcall(function() node.obj.Parent = nil end)
            elseif node.kind == "decal" then
                CT_Trans.claim(node.obj, "rainbow", 1)
            elseif node.clearTexture then
                pcall(function() node.obj[node.clearTexture] = "" end)
            end
        end

        local function addNode(entry, d)
            local node = classify(d)
            if not node then return end
            snapshot(node)
            applyOnce(node)
            if node.kind == "part" then
                table.insert(entry.parts, node)
            elseif node.kind == "surface" or node.kind == "decal" then
                table.insert(entry.statics, node)
            else
                table.insert(entry.effects, node)
            end
        end

        local function register(root)
            if tracked[root] then return end
            local entry = { parts = {}, effects = {}, statics = {}, conns = {} }
            tracked[root] = entry

            for _, d in ipairs(root:GetDescendants()) do addNode(entry, d) end
            if root:IsA("BasePart") then addNode(entry, root) end

            table.insert(entry.conns, root.DescendantAdded:Connect(function(d)
                addNode(entry, d)
            end))
            table.insert(entry.conns, root.AncestryChanged:Connect(function(_, parent)
                if not parent then unregister(root, false) end
            end))
        end

        function unregister(root, doRestore)
            local entry = tracked[root]
            if not entry then return end
            for _, conn in ipairs(entry.conns) do pcall(function() conn:Disconnect() end) end
            if doRestore then
                for _, node in ipairs(entry.parts)   do restoreNode(node) end
                for _, node in ipairs(entry.effects) do restoreNode(node) end
                for _, node in ipairs(entry.statics) do restoreNode(node) end
            end
            tracked[root] = nil
        end

        local function tryRegister(inst)
            if not enabled then return end
            if ctMatchItem(inst) then register(inst) end
        end

        local function unwatch(container)
            local conns = watchers[container]
            if not conns then return end
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
            watchers[container] = nil
        end

        local function watch(container)
            if not container or watchers[container] then return end
            watchers[container] = { container.ChildAdded:Connect(tryRegister) }
            for _, child in ipairs(container:GetChildren()) do tryRegister(child) end
        end

        local function watchAll()
            watch(_LP:FindFirstChildOfClass("Backpack"))
            watch(_LP.Character)
        end

        _LP.ChildAdded:Connect(function(child)
            if enabled and child:IsA("Backpack") then watch(child) end
        end)

        _LP.CharacterAdded:Connect(function(char)
            for root in pairs(tracked) do unregister(root, false) end
            -- pulizia totale: il vecchio Character e il vecchio Backpack sono morti
            for container in pairs(watchers) do unwatch(container) end
            if not enabled then return end
            watch(char)
            task.defer(function()
                if enabled then watchAll() end
            end)
        end)

        local acc = 0
        _RunService.Heartbeat:Connect(function(dt)
            if not enabled then return end
            if next(tracked) == nil then return end
            acc = acc + dt
            if acc < UPDATE_STEP then return end
            acc = 0

            local baseHue = (tick() * SPEED) % 1

            for _, entry in pairs(tracked) do
                for i, node in ipairs(entry.parts) do
                    local part = node.obj
                    if part.Parent then
                        pcall(function()
                            part.Color = Color3.fromHSV((baseHue + (i - 1) * SPREAD) % 1, 1, 1)
                        end)
                    end
                end
                for i, node in ipairs(entry.effects) do
                    if node.obj.Parent then
                        local col = Color3.fromHSV((baseHue + (i - 1) * SPREAD) % 1, 1, 1)
                        if node.kind == "sequence" then
                            pcall(function() node.obj[node.prop] = ColorSequence.new(col) end)
                        elseif node.kind == "vector" then
                            pcall(function() node.obj[node.prop] = Vector3.new(col.R, col.G, col.B) end)
                        else
                            pcall(function() node.obj[node.prop] = col end)
                        end
                    end
                end
            end
        end)

        table.insert(CT_JANITORS, function()
            for root in pairs(tracked) do
                if not root.Parent then unregister(root, false) end
            end
            for container in pairs(watchers) do
                if container ~= workspace and not container.Parent then unwatch(container) end
            end
        end)

        _G.AmbitiousRainbowTools = {
            setEnabled = function(on)
                on = on and true or false
                enabled = on
                _G.AmbitiousRainbowToolsEnabled = on
                if on then
                    watchAll()
                else
                    for root in pairs(tracked) do unregister(root, true) end
                    for container in pairs(watchers) do unwatch(container) end
                end
            end,
            isEnabled = function() return enabled end,
        }
    end

    -- ############################################################
    -- ##                   TRANSPARENT TOOLS                    ##
    -- ############################################################
    do
        local TRANSPARENCY = 0.5   -- 0 = opaco, 1 = invisibile

        local enabled  = false
        local tracked  = setmetatable({}, { __mode = "k" })
        local watchers = setmetatable({}, { __mode = "k" })
        local unregister

        local function canTouch(d)
            if not d:IsA("BasePart") then return false end
            -- non toccare le parti invisibili di default (baseline, non valore corrente)
            local base = CT_Trans.getBaseline(d)
            if base == nil or base >= 1 then return false end
            return true
        end

        local function addNode(entry, d)
            if not canTouch(d) then return end
            if entry.seen[d] then return end
            entry.seen[d] = true
            local node = { obj = d }
            table.insert(entry.parts, node)
            CT_Trans.claim(d, "transparent", TRANSPARENCY)
        end

        local function register(root)
            if tracked[root] then return end
            local entry = { parts = {}, seen = {}, conns = {} }
            tracked[root] = entry

            for _, d in ipairs(root:GetDescendants()) do addNode(entry, d) end
            if root:IsA("BasePart") then addNode(entry, root) end

            table.insert(entry.conns, root.DescendantAdded:Connect(function(d)
                addNode(entry, d)
            end))
            table.insert(entry.conns, root.AncestryChanged:Connect(function(_, parent)
                if not parent then unregister(root, false) end
            end))
        end

        function unregister(root, doRestore)
            local entry = tracked[root]
            if not entry then return end
            for _, conn in ipairs(entry.conns) do pcall(function() conn:Disconnect() end) end
            for _, node in ipairs(entry.parts) do
                CT_Trans.release(node.obj, "transparent")
            end
            tracked[root] = nil
        end

        local function tryRegister(inst)
            if not enabled then return end
            if ctMatchItem(inst) then register(inst) end
        end

        local function unwatch(container)
            local conns = watchers[container]
            if not conns then return end
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
            watchers[container] = nil
        end

        local function watch(container)
            if not container or watchers[container] then return end
            watchers[container] = { container.ChildAdded:Connect(tryRegister) }
            for _, child in ipairs(container:GetChildren()) do tryRegister(child) end
        end

        local function watchAll()
            watch(_LP:FindFirstChildOfClass("Backpack"))
            watch(_LP.Character)
        end

        _LP.ChildAdded:Connect(function(child)
            if enabled and child:IsA("Backpack") then watch(child) end
        end)

        _LP.CharacterAdded:Connect(function(char)
            for root in pairs(tracked) do unregister(root, false) end
            -- pulizia totale: il vecchio Character e il vecchio Backpack sono morti
            for container in pairs(watchers) do unwatch(container) end
            if not enabled then return end
            watch(char)
            task.defer(function()
                if enabled then watchAll() end
            end)
        end)

        table.insert(CT_JANITORS, function()
            for root in pairs(tracked) do
                if not root.Parent then unregister(root, false) end
            end
            for container in pairs(watchers) do
                if not container.Parent then unwatch(container) end
            end
        end)

        _G.AmbitiousTransparentTools = {
            setEnabled = function(on)
                on = on and true or false
                enabled = on
                _G.AmbitiousTransparentToolsEnabled = on
                if on then
                    watchAll()
                else
                    for root in pairs(tracked) do unregister(root, true) end
                    for container in pairs(watchers) do unwatch(container) end
                end
            end,
            isEnabled = function() return enabled end,
        }
    end

    -- ############################################################
    -- ##                     CUSTOM TOOLS                       ##
    -- ## Bat -> Diamond Sword  Medusa's Head -> Golden Desert Eagle ##
    -- ############################################################
    do
        -- Catalogo skin. "cat" e' la categoria di oggetto su cui si applica.
        local ASSETS = {
            DiamondSword      = { cat = "Bat",    label = "Diamond Sword",
                                  mesh = "rbxassetid://8827558932", tex = "rbxassetid://8827558969",
                                  scale = Vector3.new(0.2, 0.2, 0.2),
                                  c0 = CFrame.new(-0.05, -0.1, -0.12) * CFrame.Angles(math.rad(90), math.rad(180), 300),
                                  -- view = distanza della camera nell'anteprima:
                                  -- piu' alta, piu' piccolo appare l'oggetto
                                  view = 4.9 },
            Katana            = { cat = "Bat",    label = "Katana",
                                  mesh = "rbxassetid://13528902482", tex = "rbxassetid://13528902373",
                                  scale = Vector3.new(1.4, 1.4, 1.4),
                                  c0 = CFrame.new(0, 0.6, 0) * CFrame.Angles(math.rad(270), math.rad(180), math.rad(180)),
                                  view = 6.6 },
            Skull             = { cat = "Medusa", label = "Skull",
                                  mesh = "rbxassetid://2050312704", tex = "rbxassetid://2050313393",
                                  scale = Vector3.new(1, 1, 1),
                                  c0 = CFrame.new(0, 0.65, -0.4) * CFrame.Angles(math.rad(330), 0, 0),
                                  view = 4.2 },
            GoldenDesertEagle = { cat = "Medusa", label = "Golden Desert Eagle",
                                  mesh = "rbxassetid://430251413", tex = "rbxassetid://435840335",
                                  scale = Vector3.new(0.01, 0.01, 0.01),
                                  c0 = CFrame.new(0, 0, -0.8) * CFrame.Angles(math.rad(330), math.rad(180), 0),
                                  view = 3.0 },
        }
        _G.AmbitiousCustomToolAssets = ASSETS

        -- Skin attualmente scelta per ogni categoria.
        _G.AmbitiousCustomToolSkins = _G.AmbitiousCustomToolSkins
            or { Bat = "DiamondSword", Medusa = "GoldenDesertEagle" }

        local function skinFor(cat)
            local key = _G.AmbitiousCustomToolSkins[cat]
            if key and ASSETS[key] and ASSETS[key].cat == cat then return key end
            return (cat == "Bat") and "DiamondSword" or "GoldenDesertEagle"
        end

        local enabled       = false
        local tracked       = setmetatable({}, { __mode = "k" })  -- [tool] = { hidden, conns }
        local watchers      = setmetatable({}, { __mode = "k" })
        local pendingHandle = setmetatable({}, { __mode = "k" })  -- [tool] = conn
        local teardown

        local function buildReplica(handle, mode)
            local existing = handle:FindFirstChild("LocalReplica")
            if existing then existing:Destroy() end

            local data = ASSETS[mode] or ASSETS.DiamondSword

            local m = Instance.new("Model")
            m.Name = "LocalReplica"

            local p = Instance.new("Part")
            p.Name        = "MainPart"
            p.CanCollide  = false
            p.CanQuery    = false
            p.CanTouch    = false
            p.Massless    = true
            p.Size        = Vector3.new(1, 1, 1)
            p.Transparency= 0
            p.Anchored    = false
            p.Parent      = m

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType  = Enum.MeshType.FileMesh
            mesh.MeshId    = data.mesh
            mesh.TextureId = data.tex
            mesh.Parent    = p

            local w = Instance.new("Motor6D")
            w.Part0 = handle
            w.Part1 = p

            -- Scala e impugnatura vengono dal catalogo, non da un if per skin
            mesh.Scale = data.scale
            w.C0 = data.c0

            w.Parent = p
            m.Parent = handle
            return m
        end

        -- Nasconde (NON distrugge) solo la grafica: parti, decal e texture.
        -- Suoni, script e componenti di gioco restano intatti.
        -- Idempotente di proposito: il watchdog lo richiama sulle stesse
        -- parti per ri-prenotare la trasparenza se e' stata persa.
        local function hideNode(entry, d)
            if isReplicaStuff(d) then return end
            if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
                entry.hidden[d] = true
                CT_Trans.claim(d, "custom", 1)
            end
        end

        local function setupTool(tool)
            if tracked[tool] then return end

            local handle = tool:FindFirstChild("Handle")
            if not handle then
                if pendingHandle[tool] then return end
                local c
                c = tool.ChildAdded:Connect(function(child)
                    if child.Name == "Handle" then
                        pcall(function() c:Disconnect() end)
                        pendingHandle[tool] = nil
                        if enabled then setupTool(tool) end
                    end
                end)
                pendingHandle[tool] = c
                return
            end

            local entry = { hidden = {}, conns = {} }
            tracked[tool] = entry

            for _, d in ipairs(tool:GetDescendants()) do hideNode(entry, d) end

            local item = ctMatchItem(tool)
            local mode = skinFor((item and item.key == "Bat") and "Bat" or "Medusa")
            entry.cat = (item and item.key == "Bat") and "Bat" or "Medusa"
            buildReplica(handle, mode)

            table.insert(entry.conns, tool.DescendantAdded:Connect(function(d)
                task.defer(function()
                    if tracked[tool] then hideNode(entry, d) end
                end)
            end))
            table.insert(entry.conns, tool.AncestryChanged:Connect(function(_, parent)
                if not parent then teardown(tool, false) end
            end))
        end

        function teardown(tool, doRestore)
            local entry = tracked[tool]
            if not entry then return end
            for _, conn in ipairs(entry.conns) do pcall(function() conn:Disconnect() end) end

            local handle = tool:FindFirstChild("Handle")
            if handle then
                local rep = handle:FindFirstChild("LocalReplica")
                if rep then pcall(function() rep:Destroy() end) end
            end

            for obj in pairs(entry.hidden) do
                CT_Trans.release(obj, "custom")
            end
            entry.hidden = {}
            tracked[tool] = nil
        end

        local function tryRegister(inst)
            if not enabled then return end
            if inst:IsA("Tool") and ctMatchItem(inst) then
                setupTool(inst)
            end
        end

        local function unwatch(container)
            local conns = watchers[container]
            if not conns then return end
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
            watchers[container] = nil
        end

        local function watch(container)
            if not container or watchers[container] then return end
            watchers[container] = { container.ChildAdded:Connect(tryRegister) }
            for _, child in ipairs(container:GetChildren()) do tryRegister(child) end
        end

        local function watchAll()
            watch(_LP:FindFirstChildOfClass("Backpack"))
            watch(_LP.Character)
        end

        _LP.ChildAdded:Connect(function(child)
            if enabled and child:IsA("Backpack") then watch(child) end
        end)

        _LP.CharacterAdded:Connect(function(char)
            for tool in pairs(tracked) do teardown(tool, false) end
            for _, c in pairs(pendingHandle) do pcall(function() c:Disconnect() end) end
            table.clear(pendingHandle)
            -- pulizia totale: il vecchio Character e il vecchio Backpack sono morti
            for container in pairs(watchers) do unwatch(container) end
            if not enabled then return end
            watch(char)
            task.defer(function()
                if enabled then watchAll() end
            end)
        end)

        table.insert(CT_JANITORS, function()
            for tool in pairs(tracked) do
                if not tool.Parent then teardown(tool, false) end
            end
            for tool, c in pairs(pendingHandle) do
                if not tool.Parent then
                    pcall(function() c:Disconnect() end)
                    pendingHandle[tool] = nil
                end
            end
            for container in pairs(watchers) do
                if not container.Parent then unwatch(container) end
            end
        end)

        -- ------------------------------------------------------------
        -- WATCHDOG INTEGRITA'
        -- Copre i due bug segnalati:
        --  1) la replica custom sparisce e resta solo l'arma originale
        --     (tool ri-parentato, Handle sostituito, replica distrutta);
        --  2) l'arma originale ricompare sopra la replica
        --     (trasparenza sovrascritta dal gioco -> ri-nascosta).
        -- ------------------------------------------------------------
        local function rebuildIfNeeded(tool, entry, deep)
            local handle = tool:FindFirstChild("Handle")
            if not handle then return end
            local rep      = handle:FindFirstChild("LocalReplica")
            local mainPart = rep and rep:FindFirstChild("MainPart")
            local motor    = mainPart and mainPart:FindFirstChildOfClass("Motor6D")
            local broken   = (not rep) or (not mainPart) or (not motor) or motor.Part0 ~= handle
            if broken then
                local item = ctMatchItem(tool)
                buildReplica(handle, skinFor((item and item.key == "Bat") and "Bat" or "Medusa"))
            end
            -- Ripassata completa solo se la replica era rotta o su richiesta
            if broken or deep then
                for _, d in ipairs(tool:GetDescendants()) do hideNode(entry, d) end
            end
        end

        -- deep = ripassa anche tutti i descendant dei tool (piu' costoso).
        -- Il giro leggero controlla solo che la replica esista: la
        -- trasparenza e' gia' coperta dai guard + sweep di CT_Trans.
        local function integrityPass(deep)
            if not enabled then return end
            -- ri-aggancia i container (Backpack ricreato, respawn, ecc.)
            watchAll()
            local bp = _LP:FindFirstChildOfClass("Backpack")
            if bp then for _, ch in ipairs(bp:GetChildren()) do tryRegister(ch) end end
            local chr = _LP.Character
            if chr then for _, ch in ipairs(chr:GetChildren()) do tryRegister(ch) end end
            for tool, entry in pairs(tracked) do
                if not tool.Parent then
                    teardown(tool, false)
                else
                    rebuildIfNeeded(tool, entry, deep)
                end
            end
        end

        _G.AmbitiousCustomToolsRecheck = function() pcall(integrityPass, true) end

        -- Cambio skin: aggiorna la scelta e ricostruisce subito le repliche
        -- gia' agganciate, senza dover spegnere e riaccendere il modulo.
        _G.AmbitiousSetCustomToolSkin = function(cat, key)
            if not ASSETS[key] or ASSETS[key].cat ~= cat then return end
            _G.AmbitiousCustomToolSkins[cat] = key
            for tool, entry in pairs(tracked) do
                if tool.Parent and entry.cat == cat then
                    local handle = tool:FindFirstChild("Handle")
                    if handle then pcall(buildReplica, handle, key) end
                end
            end
            if requestSave then pcall(requestSave) end
        end

        task.spawn(function()
            local n = 0
            while true do
                task.wait(0.4)
                if enabled then
                    n = n + 1
                    pcall(integrityPass, (n % 5) == 0)   -- deep ogni 2s
                end
            end
        end)

        -- Riapplica subito quando equipaggi/sganci un'arma, senza aspettare
        -- il giro del watchdog.
        _LP.CharacterAdded:Connect(function()
            task.delay(0.6, function() if enabled then pcall(integrityPass, true) end end)
        end)

        _G.AmbitiousCustomTools = {
            setEnabled = function(on)
                on = on and true or false
                enabled = on
                _G.AmbitiousCustomToolsEnabled = on
                if on then
                    watchAll()
                    pcall(integrityPass, true)
                else
                    for tool in pairs(tracked) do teardown(tool, true) end
                    for _, c in pairs(pendingHandle) do pcall(function() c:Disconnect() end) end
                    table.clear(pendingHandle)
                    for container in pairs(watchers) do unwatch(container) end
                end
            end,
            isEnabled = function() return enabled end,
        }
    end

    -- ############################################################
    -- ##                    CUSTOM SOUNDS                       ##
    -- ##   Bat -> katana slash      Medusa -> gunshot           ##
    -- ##   Indipendente da Custom Tools: funziona anche da solo ##
    -- ############################################################
    do
        local SOUNDS = {
            Bat    = { id = "rbxassetid://5713085119", skip = 0.2 },
            Medusa = { id = "rbxassetid://3102797479", doublePlay = true, delay = 0.5 },
        }

        -- Un Sound puo' essere agganciato UNA volta sola: senza questo le
        -- connessioni si accumulavano a ogni re-equip (memory leak).
        local hooked = setmetatable({}, { __mode = "k" })

        local enabled       = false
        local tracked       = setmetatable({}, { __mode = "k" })  -- [tool] = { sound, data, conns, muted }
        local watchers      = setmetatable({}, { __mode = "k" })
        local pendingHandle = setmetatable({}, { __mode = "k" })
        local teardown

        local function playCustom(entry)
            local cs = entry.sound
            if not cs or not cs.Parent then return end
            local d = entry.data

            -- cancella un eventuale secondo colpo ancora in coda
            if entry.timer then
                pcall(task.cancel, entry.timer)
                entry.timer = nil
            end

            pcall(function()
                cs:Stop()
                cs.TimePosition = d.skip or 0
                cs.Volume = 1
                cs:Play()
            end)

            if d.doublePlay and d.delay then
                entry.timer = task.delay(d.delay, function()
                    entry.timer = nil
                    if not enabled then return end
                    if cs and cs.Parent then
                        pcall(function()
                            cs:Stop()
                            cs.TimePosition = d.skip or 0
                            cs.Volume = 1
                            cs:Play()
                        end)
                    end
                end)
            end
        end

        -- Silenzia il suono originale e fa partire quello custom
        local function hookSound(entry, snd)
            if not snd:IsA("Sound") then return end
            if snd.Name == "CustomSound" then return end
            if hooked[snd] then return end          -- gia' agganciato: niente doppioni
            if entry.muted[snd] ~= nil then return end

            entry.muted[snd] = snd.Volume
            hooked[snd] = true

            local function trigger()
                if not enabled then return end
                if snd.Playing or snd.TimePosition > 0 then
                    pcall(function()
                        snd.Volume = 0
                        snd:Stop()
                    end)
                    playCustom(entry)
                end
            end

            local c1 = snd:GetPropertyChangedSignal("Playing"):Connect(trigger)
            local c2 = snd:GetPropertyChangedSignal("TimePosition"):Connect(trigger)
            table.insert(entry.conns, c1)
            table.insert(entry.conns, c2)

            -- il Sound viene distrutto: si liberano subito le connessioni
            local c3
            c3 = snd.AncestryChanged:Connect(function(_, parent)
                if parent then return end
                pcall(function() c1:Disconnect() end)
                pcall(function() c2:Disconnect() end)
                pcall(function() c3:Disconnect() end)
                hooked[snd] = nil
                entry.muted[snd] = nil
                if entry.timer then
                    pcall(task.cancel, entry.timer)
                    entry.timer = nil
                end
            end)
            table.insert(entry.conns, c3)

            if snd.Playing then trigger() end
        end

        local function setupTool(tool)
            if tracked[tool] then return end

            local item = ctMatchItem(tool)
            if not item then return end
            local data = SOUNDS[item.key]
            if not data then return end

            local handle = tool:FindFirstChild("Handle")
            if not handle then
                if pendingHandle[tool] then return end
                local c
                c = tool.ChildAdded:Connect(function(child)
                    if child.Name == "Handle" then
                        pcall(function() c:Disconnect() end)
                        pendingHandle[tool] = nil
                        if enabled then setupTool(tool) end
                    end
                end)
                pendingHandle[tool] = c
                return
            end

            local old = handle:FindFirstChild("CustomSound")
            if old then pcall(function() old:Destroy() end) end

            local cs = Instance.new("Sound")
            cs.Name        = "CustomSound"
            cs.SoundId     = data.id
            cs.Volume      = 1
            cs.Looped      = false
            cs.RollOffMode = Enum.RollOffMode.Inverse
            cs.MaxDistance = 1000
            cs.MinDistance = 1000
            cs.Parent      = handle

            local entry = { sound = cs, data = data, conns = {}, muted = {} }
            tracked[tool] = entry

            for _, d in ipairs(tool:GetDescendants()) do hookSound(entry, d) end

            table.insert(entry.conns, tool.DescendantAdded:Connect(function(d)
                if tracked[tool] then hookSound(entry, d) end
            end))
            table.insert(entry.conns, tool.AncestryChanged:Connect(function(_, parent)
                if not parent then teardown(tool) end
            end))
        end

        function teardown(tool)
            local entry = tracked[tool]
            if not entry then return end
            if entry.timer then
                pcall(task.cancel, entry.timer)
                entry.timer = nil
            end
            for _, conn in ipairs(entry.conns) do pcall(function() conn:Disconnect() end) end
            if entry.sound then pcall(function() entry.sound:Destroy() end) end
            for snd, vol in pairs(entry.muted) do
                hooked[snd] = nil
                if snd and snd.Parent then pcall(function() snd.Volume = vol end) end
            end
            tracked[tool] = nil
        end

        local function tryRegister(inst)
            if not enabled then return end
            if inst:IsA("Tool") and ctMatchItem(inst) then setupTool(inst) end
        end

        local function unwatch(container)
            local conns = watchers[container]
            if not conns then return end
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
            watchers[container] = nil
        end

        local function watch(container)
            if not container or watchers[container] then return end
            watchers[container] = { container.ChildAdded:Connect(tryRegister) }
            for _, child in ipairs(container:GetChildren()) do tryRegister(child) end
        end

        local function watchAll()
            watch(_LP:FindFirstChildOfClass("Backpack"))
            watch(_LP.Character)
        end

        _LP.ChildAdded:Connect(function(child)
            if enabled and child:IsA("Backpack") then watch(child) end
        end)

        _LP.CharacterAdded:Connect(function(char)
            for tool in pairs(tracked) do teardown(tool) end
            for _, c in pairs(pendingHandle) do pcall(function() c:Disconnect() end) end
            table.clear(pendingHandle)
            for container in pairs(watchers) do unwatch(container) end
            if not enabled then return end
            watch(char)
            task.defer(function()
                if enabled then watchAll() end
            end)
        end)

        table.insert(CT_JANITORS, function()
            for tool in pairs(tracked) do
                if not tool.Parent then teardown(tool) end
            end
            for tool, c in pairs(pendingHandle) do
                if not tool.Parent then
                    pcall(function() c:Disconnect() end)
                    pendingHandle[tool] = nil
                end
            end
            for container in pairs(watchers) do
                if not container.Parent then unwatch(container) end
            end
        end)

        _G.AmbitiousCustomSounds = {
            setEnabled = function(on)
                on = on and true or false
                enabled = on
                _G.AmbitiousCustomSoundsEnabled = on
                if on then
                    watchAll()
                else
                    for tool in pairs(tracked) do teardown(tool) end
                    for _, c in pairs(pendingHandle) do pcall(function() c:Disconnect() end) end
                    table.clear(pendingHandle)
                    for container in pairs(watchers) do unwatch(container) end
                end
            end,
            isEnabled = function() return enabled end,
        }
    end

    _G.AmbitiousRainbowToolsEnabled     = false
    _G.AmbitiousTransparentToolsEnabled = false
    _G.AmbitiousCustomToolsEnabled      = false
    _G.AmbitiousCustomSoundsEnabled     = false
end


-- ============================================================
-- STATE
-- ============================================================
State = {
    normalSpeed=60, carrySpeed=30, laggerSpeed=15, laggerCarrySpeed=24.5,
    speedToggled=false,
    laggerMode=0,
    infJumpEnabled=true, antiRagdollEnabled=false,
    antiRagdollVersion="V1",
    guiVisible=true, uiLocked=false,
    isStealing=false,
    medusaLastUsed=0, medusaDebounce=false, medusaCounterEnabled=false,
    batAimbotToggled=false, autoSwingEnabled=false,
    hittingCooldown=false,
    batCounterEnabled=false, batCounterDebounce=false,
    ragdollStealEnabled=false, ragdollCountdownEnabled=false,
    dropEnabled=false, _tpInProgress=false,
    _dropInProgress=false, _dropSuppressGrabUntil=0, _dropProtectUntil=0,
    lastMoveDir=Vector3.new(0,0,0),
    _prevCarry=30, _prevSpeed=false,
    stackButtonsHidden=false,
    stackButtonsLocked=false,
    mobileButtonShape="Can",
    nukeOpt=false,
    removeAcc=false,
    antiLagEnabled=false,
    saturatedColorsEnabled=false,
    stretchedResEnabled=false,
    tryardAnimEnabled=false,
    introEnabled=false,
    autoTPEnabled=false,
    autoTPHeight=20,
    autoTPConn=nil,
    _autoTPPauseToken=0,

    stretchValue = 0.7,
    stretchFOV = 120,
    autoLeftEnabled = false,
    autoRightEnabled = false,
    informationE01Enabled = true,
    batAimbotZombie = false, -- Bat Aimbot V2 (porte Ambitious)
    batV2Bypass = true,       -- chase Bypass (pathfinding) do Bat V2
    aimbotV2Speed = 58,
    aimbotV2LaggerSpeed = 40,
    autoStealMode = "v3", -- Normal | Semi | v3
    aimbotMode = "old", -- old | new(BYPASS) (which aimbot the AIMBOT key/stack button drives)
    tpBatMode = "v1", -- modo escolhido no seletor; o botão flutuante executa esta opção
    instaResetVersion = 1, -- Insta Reset (motor Ambitious): 1 = HipHeight, 2 = fling fisico
    antiTpBatMode = "v1", -- versão da proteção; o botão flutuante mantém o nome fixo
    antiBatEnabled = false,
    bodyLockEnabled = false,
    bodyLockRadius = 60,

    bgImage = "rbxassetid://137970714521556",
    espEnabled = false,
    showTrackerEnabled = false,
    trackerColor = {230,230,230},
    semiStopPercent = 75,
    semiDelayRadius = 8,
    skyTheme = "Off",
    changeBatEnabled = false,
    changeBatSkin = "KATANA",
    rainbowToolsEnabled = false,
    transparentToolsEnabled = false,
    customToolsEnabled = false,
    customSoundsEnabled = false,
    customToolSkins = { Bat = "DiamondSword", Medusa = "GoldenDesertEagle" },
    avatarChanger = {},
    antiDieEnabled = false,
    antiFlingShieldEnabled = false,
    headlessEnabled = false,
    korbloxEnabled = false,
    customSkinEnabled = false,
    customSkinVariant = 1,
    uiColorTheme = "Green",
    outfit1Applied = false,
    outfit2Applied = false,
    outfit3Applied = false,
    -- Soft Steal
    softStealEnabled = false,
    softStealRadius = 10,
    softStealSpeed = 30,
    softStealLatched = false,
    _speedEditRevision = 0,
    _initialConfigSettled = false,
}

-- ============================================================
-- CHANGE BAT — integrated from the uploaded Cursed Bat skin.
-- ============================================================
do
-- deobfuscated by crxkv ( every credits to : @itx_crxkv )
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local InsertService = game:GetService("InsertService")

local LocalPlayer = Players.LocalPlayer

local COLORS = {
    background = Color3.new(0.0470588, 0.0470588, 0.054902),
    header = Color3.new(0.0705882, 0.0705882, 0.0862745),
    row = Color3.new(0.0862745, 0.0862745, 0.101961),
    button = Color3.new(0.109804, 0.109804, 0.133333),
    darkButton = Color3.new(0.137255, 0.137255, 0.156863),
    mini = Color3.new(0.0588235, 0.0588235, 0.0705882),
    red = Color3.new(0.784314, 0, 0),
    red2 = Color3.new(1, 0.392157, 0.392157),
    gold = Color3.new(1, 0.72549, 0.196078),
    text = Color3.new(0.941176, 0.941176, 0.960784),
    dim = Color3.new(0.470588, 0.470588, 0.509804),
}

local BatState = {
    Skin = "NONE",
    SelectedSkin = "KATANA",
    Enabled = false,
    Minimized = false,
    SkinOrder = { "KATANA", "SCYTHE", "BAN HAMMER", "NONE" },
    Connections = {},
    LastBat = nil,
    LastAppliedSkin = nil,
    OriginalKatanaTemplate = nil,
    ExactTemplates = {},
    ExactTemplateSearched = {},
    -- The trace did not include MeshId/TextureId or asset-id arguments for
    -- Scythe/Ban Hammer. Paste exact model asset ids here if you have them.
    ExactAssetIds = {
        KATANA = "",
        SCYTHE = "",
        ["BAN HAMMER"] = "",
    },
    Original = {},
}

local function disconnectAll(list)
    for _, conn in ipairs(list) do
        if typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    table.clear(list)
end

local function make(className, props, parent)
    local inst = Instance.new(className)
    if props then
        for key, value in pairs(props) do
            inst[key] = value
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

local function corner(parent, radius)
    return make("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
    }, parent)
end

local function stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = color or COLORS.red,
        Thickness = thickness or 1,
        Transparency = transparency or 0.25,
    }, parent)
end

local function setPartSafe(part)
    if not part or not part:IsA("BasePart") then return end
    part.Anchored = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Massless = true
end

local function weldToHandle(part, handle)
    if not part or not handle or not part:IsA("BasePart") or not handle:IsA("BasePart") then return end
    setPartSafe(part)
    local weld = Instance.new("WeldConstraint")
    weld.Name = "FlowerSkin_AssetWeld"
    weld.Part0 = handle
    weld.Part1 = part
    weld.Parent = part
end

local function findBat()
    local character = LocalPlayer.Character
    if character then
        local tool = character:FindFirstChild("Bat")
        if tool and tool:IsA("Tool") then
            return tool
        end
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        local tool = backpack:FindFirstChild("Bat")
        if tool and tool:IsA("Tool") then
            return tool
        end
    end

    return nil
end

local function rememberOriginal(tool)
    if not tool then return end
    local handle = tool:FindFirstChild("Handle")
    local slash = tool:FindFirstChild("Slash")

    BatState.Original[tool] = BatState.Original[tool] or {}
    local original = BatState.Original[tool]

    if handle and handle:IsA("BasePart") and not original.Handle then
        original.Handle = {
            Transparency = handle.Transparency,
            LocalTransparencyModifier = handle.LocalTransparencyModifier,
            CastShadow = handle.CastShadow,
        }
    end

    if slash and slash:IsA("Sound") and not original.SlashSoundId then
        original.SlashSoundId = slash.SoundId
    end
    if original.SkinFolderCaptured ~= true then
        original.SkinFolderCaptured = true
        local folder = tool:FindFirstChild("FlowerSkin_KatanaRealistic")
        original.SkinFolder = folder and folder:Clone() or nil
        local loose = tool:FindFirstChild("FlowerSkin_AssetKatana")
        original.LooseSkin = loose and loose:Clone() or nil
    end
    if handle and original.FireCaptured ~= true then
        original.FireCaptured = true
        local fire = handle:FindFirstChildOfClass("Fire") or handle:FindFirstChild("Fire")
        if fire and fire:IsA("Fire") then
            original.Fire = { Enabled = fire.Enabled, Color = fire.Color, SecondaryColor = fire.SecondaryColor }
        end
    end
end

local function captureKatanaTemplate()
    if BatState.OriginalKatanaTemplate then return end

    local function scan(container)
        if not container then return end
        local bat = container:FindFirstChild("Bat")
        if not bat then return end
        local folder = bat:FindFirstChild("FlowerSkin_KatanaRealistic")
        local asset = folder and folder:FindFirstChild("FlowerSkin_AssetKatana")
        if asset then
            BatState.OriginalKatanaTemplate = asset:Clone()
        end
    end

    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    scan(LocalPlayer.Character)
end

local function hideOriginalHandle(tool, hidden)
    local handle = tool and tool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return end

    rememberOriginal(tool)

    if hidden then
        handle.LocalTransparencyModifier = 1
        handle.Transparency = 1
        handle.CastShadow = false
    else
        local original = BatState.Original[tool] and BatState.Original[tool].Handle
        handle.LocalTransparencyModifier = original and original.LocalTransparencyModifier or 0
        handle.Transparency = original and original.Transparency or 0
        handle.CastShadow = original and original.CastShadow
        if handle.CastShadow == nil then
            handle.CastShadow = true
        end
    end
end

local function setSlashSound(tool, soundId)
    rememberOriginal(tool)
    local slash = tool and tool:FindFirstChild("Slash")
    if slash and slash:IsA("Sound") then
        slash.SoundId = soundId or ((BatState.Original[tool] and BatState.Original[tool].SlashSoundId) or slash.SoundId)
    end
end

local function removeSkin(tool)
    if not tool then return end

    local oldFolder = tool:FindFirstChild("FlowerSkin_KatanaRealistic")
    if oldFolder then
        oldFolder:Destroy()
    end

    local oldLoose = tool:FindFirstChild("FlowerSkin_AssetKatana")
    if oldLoose then
        oldLoose:Destroy()
    end

    hideOriginalHandle(tool, false)
    setSlashSound(tool, nil)
end

local function restoreOriginalBat(tool)
    if not tool then return end
    removeSkin(tool)
    local original = BatState.Original[tool]
    if not original then return end
    if original.SkinFolder then
        original.SkinFolder:Clone().Parent = tool
    end
    if original.LooseSkin then
        original.LooseSkin:Clone().Parent = tool
    end
    local handle = tool:FindFirstChild("Handle")
    local fire = handle and (handle:FindFirstChildOfClass("Fire") or handle:FindFirstChild("Fire"))
    if fire and original.Fire then
        fire.Enabled = original.Fire.Enabled
        fire.Color = original.Fire.Color
        fire.SecondaryColor = original.Fire.SecondaryColor
    end
end

local function addRedVFX(parentPart)
    if not parentPart or not parentPart:IsA("BasePart") then return end

    local existing = parentPart:FindFirstChild("FlowerSkin_ExtraRedVFX")
    if existing then
        existing:Destroy()
    end

    local top = Instance.new("Attachment")
    top.Name = "FlowerSkin_ExtraRedVFX"
    top.Position = Vector3.new(0, parentPart.Size.Y * 0.5, 0)
    top.Parent = parentPart

    local bottom = Instance.new("Attachment")
    bottom.Name = "FlowerSkin_ExtraRedVFX_End"
    bottom.Position = Vector3.new(0, -parentPart.Size.Y * 0.5, 0)
    bottom.Parent = parentPart

    local trail = Instance.new("Trail")
    trail.Name = "FlowerSkin_ExtraRedVFX"
    trail.Attachment0 = top
    trail.Attachment1 = bottom
    trail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.red2),
        ColorSequenceKeypoint.new(1, Color3.new(0.54902, 0, 0)),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Lifetime = 0.18
    trail.LightEmission = 0.55
    trail.Parent = parentPart

    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "FlowerSkin_ExtraRedVFX"
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0.784314, 0, 0)),
        ColorSequenceKeypoint.new(1, COLORS.red2),
    })
    emitter.LightEmission = 0.55
    emitter.Rate = 14
    emitter.Lifetime = NumberRange.new(0.25, 0.45)
    emitter.Speed = NumberRange.new(0.2, 0.7)
    emitter.SpreadAngle = Vector2.new(12, 12)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.08),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Parent = parentPart
end

local function newPart(parent, name, size, offset, color, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Color = color
    part.Material = material or Enum.Material.Neon
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    setPartSafe(part)
    part.Parent = parent
    return part, offset or CFrame.identity
end

-- =====================================================================
-- Exact mesh resolver
-- =====================================================================
local EXACT_TEMPLATE_NAMES = {
    KATANA = { "FlowerSkin_AssetKatana", "Katana", "FlowerSkin_KatanaRealistic" },
    SCYTHE = { "Scythe", "SCYTHE", "FlowerSkin_AssetScythe", "FlowerSkin_Scythe", "ScytheSkin" },
    ["BAN HAMMER"] = { "Ban Hammer", "BAN HAMMER", "BanHammer", "Hammer", "BanHammerTool", "FlowerSkin_BanHammer", "Tool" },
}

local function isScriptObject(inst)
    return inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript")
end

local function stripScripts(root)
    if not root then return end
    if isScriptObject(root) then
        root:Destroy()
        return
    end
    for _, inst in ipairs(root:GetDescendants()) do
        if isScriptObject(inst) then
            inst:Destroy()
        end
    end
end

local function hasAnyBasePart(root)
    if not root then return false end
    if root:IsA("BasePart") then return true end
    return root:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function isGeneratedProxy(root)
    local ok, value = pcall(function()
        return root:GetAttribute("CursedBatSkinsGenerated")
    end)
    return ok and value == true
end

local function usableTemplate(root)
    if not root or isGeneratedProxy(root) then return nil end
    if root:IsA("Model") or root:IsA("Tool") or root:IsA("Folder") or root:IsA("BasePart") then
        if hasAnyBasePart(root) then
            return root
        end
    end
    return nil
end

local function findUsableNamed(root, names)
    if not root then return nil end

    for _, name in ipairs(names) do
        if root.Name == name then
            local direct = usableTemplate(root)
            if direct then return direct end
        end
    end

    for _, name in ipairs(names) do
        local found = root:FindFirstChild(name, true)
        local usable = usableTemplate(found)
        if usable then
            return usable
        end
    end

    return nil
end

local function assetTextFromId(assetId)
    local raw = tostring(assetId or ""):gsub("%s+", "")
    if raw == "" then return nil end
    if raw:match("^rbxassetid://") or raw:match("^rbxasset://") then
        return raw
    end
    if raw:match("^%d+$") then
        return "rbxassetid://" .. raw
    end
    return raw
end

local function loadExactTemplateFromAssetId(skinName)
    local assetText = assetTextFromId(BatState.ExactAssetIds[skinName])
    if not assetText then return nil end

    local loaded = {}
    pcall(function()
        loaded = game:GetObjects(assetText)
    end)

    if #loaded == 0 then
        local id = tostring(assetText):match("(%d+)")
        if id then
            pcall(function()
                table.insert(loaded, InsertService:LoadAsset(tonumber(id)))
            end)
        end
    end

    local names = EXACT_TEMPLATE_NAMES[skinName] or {}
    for _, root in ipairs(loaded) do
        local exact = findUsableNamed(root, names) or usableTemplate(root)
        if exact then
            local clone = exact:Clone()
            stripScripts(clone)
            return clone
        end
    end

    return nil
end

local function findExactTemplateInGame(skinName)
    local names = EXACT_TEMPLATE_NAMES[skinName]
    if not names then return nil end

    local containers = {
        LocalPlayer.Character,
        LocalPlayer:FindFirstChildOfClass("Backpack"),
        ReplicatedStorage,
        Lighting,
        workspace,
    }

    for _, container in ipairs(containers) do
        local source = findUsableNamed(container, names)
        if source then
            local clone = source:Clone()
            stripScripts(clone)
            return clone
        end
    end

    return nil
end

local function getExactTemplate(skinName)
    if skinName == "KATANA" and BatState.OriginalKatanaTemplate then
        return BatState.OriginalKatanaTemplate
    end

    if BatState.ExactTemplates[skinName] then
        return BatState.ExactTemplates[skinName]
    end

    if BatState.ExactTemplateSearched[skinName] then
        return nil
    end
    BatState.ExactTemplateSearched[skinName] = true

    local loaded = loadExactTemplateFromAssetId(skinName) or findExactTemplateInGame(skinName)
    if loaded then
        BatState.ExactTemplates[skinName] = loaded
    end
    return loaded
end

local function containerToModel(clone, folder)
    if clone:IsA("Model") then
        clone.Name = "FlowerSkin_AssetKatana"
        clone.Parent = folder
        return clone
    end

    if clone:IsA("BasePart") then
        local model = Instance.new("Model")
        model.Name = "FlowerSkin_AssetKatana"
        model.Parent = folder
        clone.Parent = model
        return model
    end

    if clone:IsA("Tool") or clone:IsA("Folder") then
        local nested = clone:FindFirstChild("FlowerSkin_AssetKatana")
            or clone:FindFirstChildWhichIsA("Model")
            or clone:FindFirstChildWhichIsA("BasePart")

        if nested and nested.Parent == clone then
            nested.Parent = nil
            clone:Destroy()
            return containerToModel(nested, folder)
        end

        local model = Instance.new("Model")
        model.Name = "FlowerSkin_AssetKatana"
        model.Parent = folder
        for _, child in ipairs(clone:GetChildren()) do
            if not isScriptObject(child) then
                child.Parent = model
            end
        end
        clone:Destroy()
        return model
    end

    return nil
end

local function applyExactMesh(tool, skinName)
    local handle = tool and tool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return false end

    local template = getExactTemplate(skinName)
    if not template then
        return false
    end

    local folder = Instance.new("Folder")
    folder.Name = "FlowerSkin_KatanaRealistic"
    folder.Parent = tool

    local model = containerToModel(template:Clone(), folder)
    if not model or not hasAnyBasePart(model) then
        folder:Destroy()
        return false
    end

    stripScripts(model)
    pcall(function()
        model:SetAttribute("CursedBatSkinsExactMesh", true)
    end)

    local firstPart = nil
    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("BasePart") then
            firstPart = firstPart or inst
            setPartSafe(inst)
        end
    end

    if not firstPart then
        folder:Destroy()
        return false
    end

    if model:IsA("Model") then
        model.PrimaryPart = model.PrimaryPart or firstPart
        pcall(function()
            -- Preserve the cloned mesh's internal offsets/scale, only move it onto the Bat handle.
            model:PivotTo(handle.CFrame)
        end)
    end

    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("BasePart") then
            weldToHandle(inst, handle)
        end
    end

    local vfxPart = model:FindFirstChild("SharpParts", true)
        or model:FindFirstChild("WeaponPart", true)
        or model:FindFirstChild("Handle", true)
        or firstPart
    if vfxPart and not vfxPart:FindFirstChild("FlowerSkin_ExtraRedVFX") then
        addRedVFX(vfxPart)
    end

    return true
end

local function buildProxyModel(tool, skinName)
    local handle = tool and tool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return nil end

    local folder = Instance.new("Folder")
    folder.Name = "FlowerSkin_KatanaRealistic"
    folder.Parent = tool

    local model = Instance.new("Model")
    model.Name = "FlowerSkin_AssetKatana"
    model:SetAttribute("CursedBatSkinsGenerated", true)
    model.Parent = folder

    local parts = {}
    local function add(name, size, offset, color, material)
        local part, cfOffset = newPart(model, name, size, offset, color, material)
        part.CFrame = handle.CFrame * cfOffset
        weldToHandle(part, handle)
        table.insert(parts, part)
        return part
    end

    if skinName == "SCYTHE" then
        add("Handle2", Vector3.new(0.18, 3.4, 0.18), CFrame.new(0, 0.2, 0), Color3.new(0.06, 0.06, 0.07), Enum.Material.Metal)
        local sharp = add("SharpParts", Vector3.new(2.4, 0.18, 0.42), CFrame.new(0.75, 1.55, 0) * CFrame.Angles(0, 0, math.rad(-25)), COLORS.red, Enum.Material.Neon)
        add("WeaponPart", Vector3.new(1.5, 0.16, 0.35), CFrame.new(1.15, 1.2, 0) * CFrame.Angles(0, 0, math.rad(32)), COLORS.red2, Enum.Material.Neon)
        add("NeonAccent", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 1.25, 0), COLORS.gold, Enum.Material.Neon)
        addRedVFX(sharp)
    elseif skinName == "BAN HAMMER" then
        add("Handle2", Vector3.new(0.22, 3.2, 0.22), CFrame.new(0, 0.1, 0), Color3.new(0.08, 0.08, 0.09), Enum.Material.Metal)
        local head = add("WeaponPart", Vector3.new(1.8, 0.75, 0.75), CFrame.new(0, 1.55, 0), COLORS.red, Enum.Material.Neon)
        add("SharpParts", Vector3.new(2.15, 0.16, 0.9), CFrame.new(0, 1.55, 0), COLORS.gold, Enum.Material.Neon)
        add("NeonAccent", Vector3.new(0.35, 0.95, 0.95), CFrame.new(1.08, 1.55, 0), COLORS.red2, Enum.Material.Neon)
        addRedVFX(head)
    else -- KATANA fallback
        add("Handle2", Vector3.new(0.22, 1.0, 0.22), CFrame.new(0, -0.85, 0), Color3.new(0.04, 0.04, 0.045), Enum.Material.Metal)
        local sharp = add("SharpParts", Vector3.new(0.22, 3.35, 0.12), CFrame.new(0, 1.05, 0), COLORS.red2, Enum.Material.Neon)
        add("WeaponPart", Vector3.new(0.3, 2.7, 0.08), CFrame.new(0.08, 1.15, 0), COLORS.red, Enum.Material.Neon)
        add("NeonAccent", Vector3.new(0.75, 0.12, 0.42), CFrame.new(0, -0.28, 0), COLORS.gold, Enum.Material.Neon)
        addRedVFX(sharp)
    end

    model.PrimaryPart = parts[1]
    return model
end

local function applyTemplateKatana(tool)
    local handle = tool and tool:FindFirstChild("Handle")
    if not handle or not BatState.OriginalKatanaTemplate then
        return false
    end

    local folder = Instance.new("Folder")
    folder.Name = "FlowerSkin_KatanaRealistic"
    folder.Parent = tool

    local clone = BatState.OriginalKatanaTemplate:Clone()
    clone.Name = "FlowerSkin_AssetKatana"
    clone.Parent = folder

    for _, inst in ipairs(clone:GetDescendants()) do
        if inst:IsA("BasePart") then
            setPartSafe(inst)
            pcall(function()
                inst.CFrame = handle.CFrame
            end)
            weldToHandle(inst, handle)
        elseif inst:IsA("Script") or inst:IsA("LocalScript") then
            inst:Destroy()
        end
    end

    pcall(function()
        local _, size = clone:GetBoundingBox()
        local target = math.max(handle.Size.Y, 1)
        local current = math.max(size.Y, 1)
        clone:ScaleTo(math.clamp(target / current * 2.4, 0.35, 2.5))
        clone:PivotTo(handle.CFrame)
    end)

    local sharp = clone:FindFirstChild("SharpParts", true) or clone:FindFirstChildWhichIsA("BasePart", true)
    addRedVFX(sharp)
    return true
end

local SKIN_SOUND_IDS = {
    KATANA = "rbxassetid://111808555599832",
    SCYTHE = "rbxassetid://9113305311",
    ["BAN HAMMER"] = "rbxassetid://137964779511233",
}

local function applySkin(skinName)
    captureKatanaTemplate()

    local tool = findBat()
    if not tool then
        BatState.LastBat = nil
        BatState.LastAppliedSkin = nil
        return false, "Bat tool not found"
    end

    rememberOriginal(tool)
    removeSkin(tool)

    if skinName == "NONE" then
        restoreOriginalBat(tool)
        BatState.LastBat = tool
        BatState.LastAppliedSkin = skinName
        return true
    end

    hideOriginalHandle(tool, true)
    setSlashSound(tool, SKIN_SOUND_IDS[skinName])

    -- Prefer the exact cloned mesh/template when it exists. The proxy model is
    -- only a fallback for traces where the mesh asset id was not captured.
    if not applyExactMesh(tool, skinName) then
        buildProxyModel(tool, skinName)
    end

    local handle = tool:FindFirstChild("Handle")
    if handle then
        local fire = handle:FindFirstChildOfClass("Fire") or handle:FindFirstChild("Fire")
        if fire and fire:IsA("Fire") then
            fire.Enabled = true
            fire.Color = COLORS.red
            fire.SecondaryColor = COLORS.red2
        end
    end

    BatState.LastBat = tool
    BatState.LastAppliedSkin = skinName
    return true
end

local function nextSkin()
    local index = table.find(BatState.SkinOrder, BatState.Skin) or 1
    BatState.Skin = BatState.SkinOrder[(index % #BatState.SkinOrder) + 1]
    applySkin(BatState.Skin)
    return BatState.Skin
end

    local function setBatEnabled(enabled)
        BatState.Enabled = enabled == true
        BatState.Skin = BatState.Enabled and BatState.SelectedSkin or "NONE"
        return applySkin(BatState.Skin)
    end

    local function setBatSkin(skinName)
        skinName = tostring(skinName or "KATANA"):upper()
        if skinName == "BANHAMMER" then skinName = "BAN HAMMER" end
        if skinName == "NONE" then return setBatEnabled(false) end
        if not table.find({"KATANA", "SCYTHE", "BAN HAMMER"}, skinName) then
            return false, "unknown skin"
        end
        BatState.SelectedSkin = skinName
        if BatState.Enabled then
            BatState.Skin = skinName
            return applySkin(skinName)
        end
        return true
    end

    _G._K7ChangeBat = {
        SetEnabled = setBatEnabled,
        SetSkin = setBatSkin,
        GetEnabled = function() return BatState.Enabled end,
        GetSkin = function() return BatState.SelectedSkin end,
        SkinOrder = {"KATANA", "SCYTHE", "BAN HAMMER"},
    }

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if BatState.Enabled then pcall(function() applySkin(BatState.SelectedSkin) end) end
    end)

    task.spawn(function()
        while task.wait(0.5) do
            if BatState.Enabled then
                local batTool = findBat()
                if batTool ~= BatState.LastBat or BatState.LastAppliedSkin ~= BatState.SelectedSkin then
                    pcall(function() applySkin(BatState.SelectedSkin) end)
                end
            end
        end
    end)
end

function markSpeedEdited()
    State._speedEditRevision = (State._speedEditRevision or 0) + 1
end

_early7upConfig = forceLoadConfig()
if _early7upConfig then
    if _early7upConfig.uiColorTheme == "Red" then
        State.uiColorTheme = "Red"
        if type(_early7upConfig.bgImage) ~= "string" or _early7upConfig.bgImage == "" then
            State.bgImage = RED_7UP_BACKGROUND
            currentBgImage = RED_7UP_BACKGROUND
        end
        _G._K7ThemeMode = "Red"
        _G._K7AccentColor = Color3.fromRGB(220, 32, 46)
        currentColorScheme = get7UpThemeScheme(
            COLOR_SCHEMES[State.bgImage] or COLOR_SCHEMES["rbxassetid://102557909116203"],
            "Red"
        )
    end
    if type(_early7upConfig.bgImage) == "string" and _early7upConfig.bgImage ~= "" then
        State.bgImage = _early7upConfig.bgImage
        currentBgImage = State.bgImage
    end
    local earlyVariant = tonumber(_early7upConfig.customSkinVariant)
    if earlyVariant == 1 or earlyVariant == 2 then State.customSkinVariant = earlyVariant end
end

task.spawn(function()
    while task.wait(0.2) do
        if _G._K7SetCarryStatus then
            local textValue, isOn = "CARRY OFF", false
            if State.laggerMode == 2 then
                textValue, isOn = "LAG CARRY", true
            elseif State.speedToggled then
                textValue, isOn = "CARRY ON", true
            elseif State.softStealLatched then
                textValue, isOn = "AUTO CARRY", true
            end
            pcall(_G._K7SetCarryStatus, textValue, isOn)
        end
    end
end)


Keys = {
    speed=Enum.KeyCode.Q, guiHide=Enum.KeyCode.LeftControl,
    lagger=Enum.KeyCode.R,
    tpDown=Enum.KeyCode.F,
    drop=Enum.KeyCode.X, aimbot=Enum.KeyCode.E,
    autoLeft=Enum.KeyCode.L, autoRight=Enum.KeyCode.K,
    antiDesync=Enum.KeyCode.V,
    -- Keybinds dedicadas por botao da stack
    batV2=Enum.KeyCode.Unknown,
    antiBatTp=Enum.KeyCode.Unknown,
    instaReset=Enum.KeyCode.Unknown,
    batAimbot=Enum.KeyCode.Unknown,
}

-- ============================================================
-- SAFE MODE (unchanged)
-- ============================================================
antiKickEnabled = false

function _G.AceSafeModeGetCountdownLabel()
    local ok, label = pcall(function()
        return LP.PlayerGui
            and LP.PlayerGui:FindFirstChild("DuelsMachineTopFrame")
            and LP.PlayerGui.DuelsMachineTopFrame:FindFirstChild("DuelsMachineTopFrame")
            and LP.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame:FindFirstChild("Timer")
            and LP.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame.Timer:FindFirstChild("Label")
    end)
    return (ok and label) or nil
end
function _G.AceSafeModeCountdownNumber(text)
    local t = tostring(text or ""):upper():gsub("^%s+",""):gsub("%s+$","")
    if t=="GO" or t=="START" or t=="READY" then return true end
    local n = tonumber(t)
    return n ~= nil and n >= 0 and n <= 10
end
function _G.AceSafeModeInDuelCountdown()
    local label = _G.AceSafeModeGetCountdownLabel()
    return label and _G.AceSafeModeCountdownNumber(label.Text) or false
end
function _G.AceCooldownActive()
    if _G.AceSafeModeInDuelCountdown and _G.AceSafeModeInDuelCountdown() then return true end
    return false
end
_G.AceSafeModeBlockedTools = {
    bat=true,slap=true,sword=true,gun=true,pistol=true,rifle=true,
    medusa=true,hammer=true,axe=true,knife=true,katana=true,blade=true,fist=true,
}
function _G.AceSafeModeIsCarryableTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local name = tool.Name:lower()
    for word in pairs(_G.AceSafeModeBlockedTools) do
        if name:find(word,1,true) then return false end
    end
    return true
end
function _G.AceSafeModeHoldingBrainrot()
    local okA, vA = pcall(function() return LP:GetAttribute("Stealing") end)
    if okA and vA == true then return true end
    local okB, vB = pcall(function() return LP:GetAttribute("AntiKick") end)
    if okB and vB == true then return true end
    local char = LP.Character; if not char then return false end
    local okC, vC = pcall(function() return char:GetAttribute("Stealing") end)
    if okC and vC == true then return true end
    for _, name in ipairs({"Carrying","IsCarrying","Grabbed","Holding","StealHold","HasGrab"}) do
        local v = char:FindFirstChild(name, true)
        if v then
            if v:IsA("BoolValue") and v.Value then return true end
            if v:IsA("ObjectValue") and v.Value then return true end
            if v:IsA("StringValue") and v.Value ~= "" then return true end
        end
    end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChildWhichIsA("BasePart",true) then
            local n = child.Name:lower()
            if n:find("brainrot") or n:find("animal") or n:find("carry") or n:find("grab") or n:find("steal") or n:find("hold") then
                return true
            end
        end
    end
    return false
end
-- Cache leve: consultado por vários loops sem custo de Heartbeat.
local _brSafeVal, _brSafeAt = false, 0
function _G.AceBrainrotSafe()
    local now = os.clock()
    if now - _brSafeAt < 0.15 then return _brSafeVal end
    _brSafeAt = now
    local ok, holding = pcall(function()
        return _G.AceSafeModeHoldingBrainrot and _G.AceSafeModeHoldingBrainrot()
    end)
    _brSafeVal = (ok and holding == true)
    return _brSafeVal
end

-- Enquanto o Brainrot estiver na mao, NENHUM golpe automatico de morcego
-- pode acontecer (era isso que ativava o morcego e causava o reset).
function _G.AceBatSwingBlocked()
    return _G.AceBrainrotSafe()
end

function _G.AceSafeModeIsLocked()
    if not antiKickEnabled then return false end
    if _G.AceSafeModeInDuelCountdown and _G.AceSafeModeInDuelCountdown() then return true end
    if _G.AceCooldownActive and _G.AceCooldownActive() then return true end
    if _G.AceSafeModeHoldingBrainrot and _G.AceSafeModeHoldingBrainrot() then return true end
    if State and State.softStealLatched then return true end
    if State and State.isStealing then return true end
    return false
end
function _G.AceSafeModeForceStop(reason)
    local stopped = false
    if _G.AceNormalAimbotOn and _G.AceStopNormalAimbot then _G.AceStopNormalAimbot(); stopped=true end
    if _G.AceAntiDesyncAimbotOn and _G.AceStopAntiDesyncAimbot then _G.AceStopAntiDesyncAimbot(); stopped=true end
    if State.batAimbotToggled then
        State.batAimbotToggled = false
        if stackBtnRefs and stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end
        stopped = true
    end
    -- Zombie bat aimbot
    if State.batAimbotZombie then
        pcall(function()
            if _G._7upStopZombieBatAimbot then _G._7upStopZombieBatAimbot()
            elseif stopZombieBatAimbot then stopZombieBatAimbot() end
        end)
        stopped = true
    end
    -- Auto Left / Auto Right
    if State.autoLeftEnabled then
        pcall(function()
            if _G._7upStopAutoLeft then _G._7upStopAutoLeft()
            elseif stopAutoLeft then stopAutoLeft() end
        end)
        stopped = true
    end
    if State.autoRightEnabled then
        pcall(function()
            if _G._7upStopAutoRight then _G._7upStopAutoRight()
            elseif stopAutoRight then stopAutoRight() end
        end)
        stopped = true
    end
    if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
    if stopped then
        pcall(function()
            local pg = LP:FindFirstChild("PlayerGui")
            local notifGui = pg and pg:FindFirstChild("SevenUpDuelsV2") and pg.SevenUpDuelsV2:FindFirstChild("Notif")
            if notifGui then
                local lbl = notifGui:FindFirstChildOfClass("TextLabel")
                if lbl then lbl.Text = reason or "SAFE MODE LOCK"; task.delay(1.5, function() if lbl then lbl.Text="" end end) end
            end
        end)
    end
end
function _G.AceSafeModeTryStart()
    if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
        _G.AceSafeModeForceStop("SAFE MODE LOCK")
        return false
    end
    return true
end
_G.AceSafeModeMonitorStarted = _G.AceSafeModeMonitorStarted or false
if not _G.AceSafeModeMonitorStarted then
    _G.AceSafeModeMonitorStarted = true
    RunService.Heartbeat:Connect(function()
        if antiKickEnabled and _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
            _G.AceSafeModeForceStop("SAFE MODE LOCK")
        end
    end)
end

-- ============================================================
-- MUSIC SYSTEM REMOVED
-- ============================================================
_introEnabled = false
MusicPlayer = {scale=1, volume=1, looped=false, playing=false, songIdx=1, sound=nil, gui=nil}
function stopIntroPlayback() end

-- ============================================================
-- AIMBOT — direct Ace port (green theme)
-- ============================================================
AIMBOT_SPEED = 50
LAGGER_AIMBOT_SPEED = 40
_G.AceNormalAimbotOn = false
_G.AceNormalAimbot = {conn=nil, target=nil, swingCooldown=false}

function _G.AceGetNormalAimbotSpeed()
    return State.laggerMode~=0 and (tonumber(LAGGER_AIMBOT_SPEED) or 40) or (tonumber(AIMBOT_SPEED) or 50)
end
-- Aimbot Speed aplicado conforme o aimbot ativo (BAT AIMBOT ou BAT V2)
AIMBOT_SPEED_BASE_OLD = 50   -- baseline do BAT AIMBOT
AIMBOT_SPEED_BASE_V2  = 63   -- baseline do BAT V2 (ZBat.SPEED)
function _G.AceGetActiveAimbotSpeed()
    local v = _G.AceGetNormalAimbotSpeed()
    local usingV2 = (State.batAimbotZombie == true)
        or (State.aimbotMode == "new" and not _G.AceNormalAimbotOn)
    if usingV2 then
        local Z = _G._7upBypassBatAimbot
        local baseV2 = (Z and tonumber(Z.SPEED)) or AIMBOT_SPEED_BASE_V2
        return v * (baseV2 / (AIMBOT_SPEED_BASE_OLD > 0 and AIMBOT_SPEED_BASE_OLD or 50))
    end
    return v
end

function _G.AceRefreshAimbotSpeedBoxes()
    if _G.AceAimbotSpeedBox then _G.AceAimbotSpeedBox.Text=tostring(AIMBOT_SPEED) end
    if _G.AceLaggerAimbotSpeedBox then _G.AceLaggerAimbotSpeedBox.Text=tostring(LAGGER_AIMBOT_SPEED) end
end

-- shared helpers
function _G.AceFindAimbotBat()
    local char=LP.Character; if not char then return nil end
    for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") and (t.Name:lower():find("bat") or t.Name:lower():find("slap")) then return t end end
    local bp=LP:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and (t.Name:lower():find("bat") or t.Name:lower():find("slap")) then return t end end end
    return nil
end
function _G.AceGetClosestAimbotTarget()
    local root=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not root then return nil end
    local closest,minDist=nil,math.huge
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LP and plr.Character then
            local tRoot=plr.Character:FindFirstChild("HumanoidRootPart")
            local hum=plr.Character:FindFirstChildOfClass("Humanoid")
            if tRoot and hum and hum.Health>0 then
                local dist=(tRoot.Position-root.Position).Magnitude
                if dist<minDist then minDist=dist; closest=tRoot end
            end
        end
    end
    return closest
end

-- ============================================================
-- PATHFINDING / CHASE BYPASS (porte do Ambitious)
-- Raios para desviar de paredes + rota real do PathfindingService,
-- recalculada com frequencia porque o alvo se move.
-- ============================================================
_G.AcePathfind = _G.AcePathfind or {}
_G.AcePathfind.cfg = {
    PROBE = 14, ANGLES = {18,36,54,72,90}, WALL_Y = 0.6,
    WP_REACH = 4, RECOMPUTE = 1.25, GOAL_DRIFT = 6,
}
function _G.AcePathfind.rayParams()
    local params = RaycastParams.new()
    local ignore = {}
    local ch = LP.Character
    if ch then ignore[#ignore+1] = ch end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then ignore[#ignore+1] = plr.Character end
    end
    params.FilterDescendantsInstances = ignore
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    return params
end
function _G.AcePathfind.blocked(origin, dir, dist, params)
    local res = workspace:Raycast(origin, dir * dist, params)
    if not res then return false end
    if math.abs(res.Normal.Y) > _G.AcePathfind.cfg.WALL_Y then return false end
    return true
end
function _G.AcePathfind.steer(origin, dir, dist)
    if dir.Magnitude < 0.01 then return dir end
    dir = dir.Unit
    local C = _G.AcePathfind.cfg
    dist = dist or C.PROBE
    local params = _G.AcePathfind.rayParams()
    local low = origin - Vector3.new(0, 2, 0)
    if not _G.AcePathfind.blocked(origin, dir, dist, params)
       and not _G.AcePathfind.blocked(low, dir, dist, params) then
        return dir
    end
    for _, deg in ipairs(C.ANGLES) do
        for _, sign in ipairs({1, -1}) do
            local rot = CFrame.Angles(0, math.rad(deg * sign), 0)
            local cand = rot:VectorToWorldSpace(dir)
            cand = Vector3.new(cand.X, 0, cand.Z)
            if cand.Magnitude > 0.01 then
                cand = cand.Unit
                if not _G.AcePathfind.blocked(origin, cand, dist, params)
                   and not _G.AcePathfind.blocked(low, cand, dist, params) then
                    return cand
                end
            end
        end
    end
    return dir
end
_G.AcePathfind.paths = _G.AcePathfind.paths or {}
function _G.AcePathfind.reset(key) _G.AcePathfind.paths[key] = nil end
function _G.AcePathfind.dirTo(key, from, goal, opts)
    local C = _G.AcePathfind.cfg
    local st = _G.AcePathfind.paths[key]
    local now = os.clock()
    local recompute = (opts and tonumber(opts.recompute)) or C.RECOMPUTE
    local drift     = (opts and tonumber(opts.drift))     or C.GOAL_DRIFT
    if st and st.goal and (st.goal - goal).Magnitude > drift then st = nil end
    if not st then
        st = {goal = goal, wp = nil, i = 1, computing = false, last = 0}
        _G.AcePathfind.paths[key] = st
    end
    if not st.computing and (not st.wp or (now - st.last) > recompute) then
        st.computing = true
        st.last = now
        st.goal = goal
        local origin = from
        task.spawn(function()
            local ok, path = pcall(function()
                _G.AcePathfind.svc = _G.AcePathfind.svc or game:GetService("PathfindingService")
                local pth = _G.AcePathfind.svc:CreatePath({
                    AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6,
                })
                pth:ComputeAsync(origin, goal)
                return pth
            end)
            local cur = _G.AcePathfind.paths[key]
            if cur ~= st then return end
            st.computing = false
            if ok and path and path.Status == Enum.PathStatus.Success then
                local pts = path:GetWaypoints()
                st.wp = pts
                st.i = math.min(2, #pts)
            else
                st.wp = nil
            end
        end)
    end
    local wp = st.wp
    if not wp or #wp == 0 then return nil end
    while st.i <= #wp do
        local pt = wp[st.i].Position
        local d = Vector3.new(pt.X - from.X, 0, pt.Z - from.Z)
        if d.Magnitude > C.WP_REACH then
            if d.Magnitude < 0.01 then return nil end
            return d.Unit
        end
        st.i = st.i + 1
    end
    return nil
end

-- O único controle Aimbot Speed comanda Bat Aimbot V1 e V2.
function _G.AceGetBatAimbotV2Speed()
    return _G.AceGetNormalAimbotSpeed()
end
-- Chase mode do aimbot ativo: o Bypass pertence ao Bat V2.
function _G.AceAimbotChaseMode()
    if _G.AceBatAimbotV2On == true then
        return (State.batV2Bypass ~= false) and "BYPASS" or "NORMAL"
    end
    return "NORMAL"
end

-- Normal aimbot
function _G.AceStopNormalAimbot()
    _G.AceNormalAimbotOn=false
    if _G.AceNormalAimbot.conn then _G.AceNormalAimbot.conn:Disconnect(); _G.AceNormalAimbot.conn=nil end
    _G.AceNormalAimbot.target=nil; _G.AceNormalAimbot.swingCooldown=false
    if _G.AcePathfind then pcall(_G.AcePathfind.reset, "aimbot") end
    local c=LP.Character; local root=c and c:FindFirstChild("HumanoidRootPart")
    if root then root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero end
    local hum=c and c:FindFirstChildOfClass("Humanoid"); if hum then hum.AutoRotate=true end
    State.batAimbotToggled = false
    if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
end
function _G.AceStartNormalAimbot(keepV2)
    if _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then return false end
    -- keepV2 = true quando quem chama e o Bat Aimbot V2 (fase 1 do chase)
    if not keepV2 then
        if _G.AceBatAimbotV2On and _G.AceStopBatAimbotV2 then pcall(_G.AceStopBatAimbotV2) end
        _G.AceBatAimbotV2On = false
    end
    _G.AceNormalAimbotOn=true
    if _G.AceNormalAimbot.conn then _G.AceNormalAimbot.conn:Disconnect(); _G.AceNormalAimbot.conn=nil end
    local hum0=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum0 then hum0.AutoRotate=false end
    _G.AceNormalAimbot.conn=RunService.RenderStepped:Connect(function()
        if not _G.AceNormalAimbotOn then return end
        local char=LP.Character; if not char then return end
        local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
        local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
        local bat=char:FindFirstChildOfClass("Tool") or _G.AceFindAimbotBat()
        if bat and bat.Parent~=char then pcall(function() hum:EquipTool(bat) end) end
        local target=_G.AceGetClosestAimbotTarget(); if not target then return end
        _G.AceNormalAimbot.target=target
        local _isV2 = (_G.AceBatAimbotV2On == true)
        local chaseSpeed = _isV2
            and ((_G.AceGetBatAimbotV2Speed and _G.AceGetBatAimbotV2Speed()) or 58)
            or ((_G.AceGetActiveAimbotSpeed and _G.AceGetActiveAimbotSpeed()) or _G.AceGetNormalAimbotSpeed())
        local myPos=root.Position
        local targetPos=target.Position

        -- >>> CHASE BYPASS (pathfinding) — usado pelo Bat V2
        if (_G.AceAimbotChaseMode and _G.AceAimbotChaseMode() or "NORMAL") == "BYPASS" then
            local direction = targetPos - myPos
            local flatDir = Vector3.new(direction.X, 0, direction.Z)
            if flatDir.Magnitude > 0 then flatDir = flatDir.Unit else flatDir = Vector3.zero end
            if _G.AcePathfind and flatDir.Magnitude > 0 then
                local pd = _G.AcePathfind.dirTo("aimbot", myPos, targetPos, {recompute=0.35, drift=4})
                if pd then flatDir = pd end
                flatDir = _G.AcePathfind.steer(myPos, flatDir, _G.AcePathfind.cfg.PROBE)
            end
            -- V2 persegue na mesma altura do inimigo; V1 sobe 3.7 studs.
            local desiredHeight = targetPos.Y + (_isV2 and 0 or 3.7)
            local yVel = (desiredHeight - myPos.Y) * 19.5
            if not _isV2 and hum.FloorMaterial ~= Enum.Material.Air then yVel = math.max(yVel, 13) end
            yVel = math.clamp(yVel, -70, 110)
            root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(
                Vector3.new(flatDir.X * chaseSpeed, yVel, flatDir.Z * chaseSpeed), 0.8)
            local toTarget = targetPos - myPos
            if toTarget.Magnitude > 0.1 then
                local goalCF = CFrame.lookAt(myPos, targetPos)
                local diffCF = root.CFrame:Inverse() * goalCF
                local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
                root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(
                    Vector3.new(math.clamp(rx,-2.5,2.5)*42, math.clamp(ry,-2.5,2.5)*42, math.clamp(rz,-2.5,2.5)*42))
            end
            -- BAT V2 (Bypass do Ambitious): o proprio chase bate, sem TP Bat.
            if State.autoSwingEnabled and bat
                and not _G.AceNormalAimbot.swingCooldown
                and not (_G.AceBatSwingBlocked and _G.AceBatSwingBlocked()) then
                _G.AceNormalAimbot.swingCooldown=true
                pcall(function() bat:Activate() end)
                task.delay(0.08,function() if _G.AceNormalAimbot then _G.AceNormalAimbot.swingCooldown=false end end)
            end
            return
        end

        local targetVel=target.AssemblyLinearVelocity
        -- V1 antecipa o alvo; V2 mira na posicao real.
        local predictPos = targetPos
        if not _isV2 then
            predictPos = targetPos + targetVel*0.14 + target.CFrame.LookVector*0.3
        end
        local direction=predictPos-myPos
        if direction.Magnitude<0.01 then return end
        local flatDir=Vector3.new(direction.X,0,direction.Z)
        if flatDir.Magnitude<0.01 then return end
        flatDir=flatDir.Unit
        local desiredHeight=targetPos.Y+(_isV2 and 0 or 3.7)
        local yVel=(desiredHeight-myPos.Y)*19.5
        if not _isV2 then yVel = yVel + targetVel.Y*0.8 end
        if not _isV2 and hum.FloorMaterial~=Enum.Material.Air then yVel=math.max(yVel,13) end
        yVel=math.clamp(yVel,-70,110)
        root.AssemblyLinearVelocity=root.AssemblyLinearVelocity:Lerp(Vector3.new(flatDir.X*chaseSpeed,yVel,flatDir.Z*chaseSpeed),0.8)
        local predictedPos = targetPos
        if not _isV2 then
            local predictTime=math.clamp(targetVel.Magnitude/150,0.05,0.2)
            predictedPos=targetPos+targetVel*predictTime
        end
        local toPredict=predictedPos-myPos
        if toPredict.Magnitude>0.1 then
            local goalCF=CFrame.lookAt(myPos,predictedPos)
            local diffCF=root.CFrame:Inverse()*goalCF
            local rx,ry,rz=diffCF:ToEulerAnglesXYZ()
            root.AssemblyAngularVelocity=root.CFrame:VectorToWorldSpace(Vector3.new(math.clamp(rx,-2.5,2.5)*42,math.clamp(ry,-2.5,2.5)*42,math.clamp(rz,-2.5,2.5)*42))
        end
        if State.autoSwingEnabled and bat and not _G.AceNormalAimbot.swingCooldown
            and not (_G.AceBatSwingBlocked and _G.AceBatSwingBlocked()) then
            _G.AceNormalAimbot.swingCooldown=true
            pcall(function() bat:Activate() end)
            task.delay(0.08,function() if _G.AceNormalAimbot then _G.AceNormalAimbot.swingCooldown=false end end)
        end
    end)
    if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
    return true
end

function _G.AceRefreshAimbotVisual()
    local _v2 = (_G.AceBatAimbotV2On == true)
    local _v1On = (_G.AceNormalAimbotOn == true) and not _v2
    -- Bat V2 reutiliza apenas o motor de perseguição; nunca acende o Bat Aimbot.
    if _G.AceAimbotSetVisual then _G.AceAimbotSetVisual(_v1On) end
    State.batAimbotToggled = _v1On
    if toggleSetters then
        if toggleSetters["batAimbotV1"] then pcall(toggleSetters["batAimbotV1"], _v1On) end
        if toggleSetters["batAimbotV2"] then pcall(toggleSetters["batAimbotV2"], _v2) end
    end
    if stackBtnRefs and stackBtnRefs.aimbot then
        stackBtnRefs.aimbot.setOn(_v1On)
        if stackBtnRefs.aimbot.setLabel then
            stackBtnRefs.aimbot.setLabel("BAT\nAIMBOT")
        end
    end
    if stackBtnRefs and stackBtnRefs.batV2 then
        stackBtnRefs.batV2.setOn(State.batAimbotZombie==true)
        if stackBtnRefs.batV2.setLabel then
            stackBtnRefs.batV2.setLabel("BAT V2")
        end
    end
end
-- OLD aimbot (floating button "BAT AIMBOT")
function _G.AceToggleOldAimbot()
    State.aimbotMode = "old"
    if _G.AceNormalAimbotOn then
        _G.AceStopNormalAimbot()
    else
        if State.batAimbotZombie and _G._7upStopZombieBatAimbot then pcall(_G._7upStopZombieBatAimbot) end
        _G.AceStartNormalAimbot()
    end
    if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
end

-- BYPASS aimbot (floating button "BAT V2")
function _G.AceToggleBypassAimbot()
    State.aimbotMode = "new"
    if State.batAimbotZombie then
        if _G._7upStopZombieBatAimbot then pcall(_G._7upStopZombieBatAimbot) end
    else
        if _G.AceNormalAimbotOn then _G.AceStopNormalAimbot() end
        if _G._7upStartZombieBatAimbot then pcall(_G._7upStartZombieBatAimbot) end
    end
    if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
end

function _G.AceToggleSelectedAimbot()
    if State.aimbotMode == "new" then
        if State.batAimbotZombie then
            if _G._7upStopZombieBatAimbot then pcall(_G._7upStopZombieBatAimbot) end
        else
            if _G.AceNormalAimbotOn then _G.AceStopNormalAimbot() end
            if _G._7upStartZombieBatAimbot then pcall(_G._7upStartZombieBatAimbot) end
        end
    else
        if _G.AceNormalAimbotOn then _G.AceStopNormalAimbot()
        else
            if State.batAimbotZombie and _G._7upStopZombieBatAimbot then pcall(_G._7upStopZombieBatAimbot) end
            _G.AceStartNormalAimbot()
        end
    end
end

-- ============================================================
-- BAT AIMBOT V2 (porte do Ambitious)
-- Fase 1: chase com a logica do V1 (mesma altura do inimigo, sem
-- predicao, com o chase Bypass/pathfinding). Fase 2: a 4 studs o
-- controle passa para o TP Bat, que cuida do swing.
-- ============================================================
_G.AceBatAimbotV2On = _G.AceBatAimbotV2On or false
_G.AceBatAimbotV2State = _G.AceBatAimbotV2State or {conn=nil, lastChase=0}
_G.AceBatAimbotV2TPDistance = 4

function _G.AceBatAimbotV2GetClosest()
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil, math.huge end
    local closest, minDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tRoot and hum and hum.Health > 0 then
                local dist = (tRoot.Position - root.Position).Magnitude
                if dist < minDist then minDist = dist; closest = tRoot end
            end
        end
    end
    return closest, minDist
end

function _G.AceBatAimbotV2StartChase()
    if _G.AceStartNormalAimbot then _G.AceStartNormalAimbot(true) end
end

local function _aceTpBatIsOn()
    return (_G.AceAntiDesyncAimbotOn == true) or (_G.AceFlowTpBatOn == true)
end

function _G.AceStartBatAimbotV2()
    if _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then return false end
    if _G.AceNormalAimbotOn and _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end
    -- garante que nenhum TP Bat fique ligado junto com o Bat V2
    if _G.AceAntiDesyncAimbotOn and _G.AceStopAntiDesyncAimbot then pcall(_G.AceStopAntiDesyncAimbot) end
    if _G.AceFlowTpBatOn and _G.AceStopFlowTpBat then pcall(_G.AceStopFlowTpBat) end
    _G.AceBatAimbotV2On = true
    State.batAimbotZombie = true
    State.aimbotMode = "new"
    _G.AceBatAimbotV2StartChase()
    if _G.AceBatAimbotV2State.conn then
        pcall(function() _G.AceBatAimbotV2State.conn:Disconnect() end)
        _G.AceBatAimbotV2State.conn = nil
    end
    _G.AceBatAimbotV2State.conn = RunService.Heartbeat:Connect(function()
        if not _G.AceBatAimbotV2On then return end
        -- Enquanto o TP Bat manda, nenhum chase em paralelo.
        if _aceTpBatIsOn() then return end
        -- BAT V2 = Bypass puro (porte do Ambitious): o chase com pathfinding
        -- cuida de tudo, inclusive do swing. NUNCA liga o TP Bat ao chegar perto.
        if not _G.AceNormalAimbotOn then
            local now = tick()
            if now - (_G.AceBatAimbotV2State.lastChase or 0) >= 0.15 then
                _G.AceBatAimbotV2State.lastChase = now
                _G.AceBatAimbotV2StartChase()
            end
        end
    end)
    if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
    return true
end

function _G.AceStopBatAimbotV2()
    _G.AceBatAimbotV2On = false
    State.batAimbotZombie = false
    if _G.AceBatAimbotV2State and _G.AceBatAimbotV2State.conn then
        pcall(function() _G.AceBatAimbotV2State.conn:Disconnect() end)
        _G.AceBatAimbotV2State.conn = nil
    end
    if _G.AceNormalAimbotOn and _G.AceStopNormalAimbot then pcall(_G.AceStopNormalAimbot) end
    if _G.AceAntiDesyncAimbotOn and _G.AceStopAntiDesyncAimbot then pcall(_G.AceStopAntiDesyncAimbot) end
    if _G.AceFlowTpBatOn and _G.AceStopFlowTpBat then pcall(_G.AceStopFlowTpBat) end
    local c = LP.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if root then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if hum then hum.AutoRotate = true end
    if _G.AcePathfind then pcall(_G.AcePathfind.reset, "aimbot") end
    if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
end

function _G.AceToggleBatAimbotV2()
    if _G.AceBatAimbotV2On then _G.AceStopBatAimbotV2() else _G.AceStartBatAimbotV2() end
end

-- compat stubs
startBatAimbot=function() _G.AceStartNormalAimbot(); State.batAimbotToggled=true end
stopBatAimbot=function() _G.AceStopNormalAimbot(); State.batAimbotToggled=false end

-- ============================================================
-- ANTI-DESYNC — Ace port (hardened)
-- ============================================================
_G.AceAntiDesyncAimbotOn = false
_G.AceAntiDesync = _G.AceAntiDesync or {
    conn=nil, hittingCooldown=false, h=nil, hrp=nil,
    lastSafeCFrame=nil, lastPosition=nil, lastSampleTime=0,
    voidRecoverUntil=0, targetSamples={}, targetPlayer=nil,
    safeEngagementCFrame=nil,
}
_G.AceAntiDesync.targetSamples = _G.AceAntiDesync.targetSamples or {}
antiDesyncAutoSwingEnabled = true

_G.AceAntiDesyncSlapList = {
    "Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap",
    "Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap",
}

function _G.AceAntiDesyncGetBat()
    local char = LP.Character
    if not char then return nil end
    for _, name in ipairs(_G.AceAntiDesyncSlapList) do
        local t = char:FindFirstChild(name)
        if t and t:IsA("Tool") then return t end
    end
    for _, ch in ipairs(char:GetChildren()) do
        if ch:IsA("Tool") then
            local n = ch.Name:lower()
            if n:find("bat") or n:find("slap") then return ch end
        end
    end
    local bp = LP:FindFirstChild("Backpack") or LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, name in ipairs(_G.AceAntiDesyncSlapList) do
            local t = bp:FindFirstChild(name)
            if t and t:IsA("Tool") then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum:EquipTool(t) end) end
                return t
            end
        end
        for _, ch in ipairs(bp:GetChildren()) do
            if ch:IsA("Tool") then
                local n = ch.Name:lower()
                if n:find("bat") or n:find("slap") then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then pcall(function() hum:EquipTool(ch) end) end
                    return ch
                end
            end
        end
    end
    return nil
end

function _G.AceAntiDesyncTrySwing()
    if not _G.AceAntiDesync then return end
    if _G.AceAntiDesync.hittingCooldown then return end
    _G.AceAntiDesync.hittingCooldown = true
    pcall(function()
        local char = LP.Character
        if not char then return end
        local bat = _G.AceAntiDesyncGetBat()
        if not bat then return end
        if bat.Parent ~= char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum:EquipTool(bat) end) end
        end
        pcall(function() bat:Activate() end)
        local ev = bat:FindFirstChildWhichIsA("RemoteEvent")
        if ev then pcall(function() ev:FireServer() end) end
    end)
    task.delay(0.08, function()
        if _G.AceAntiDesync then _G.AceAntiDesync.hittingCooldown = false end
    end)
end

function _G.AceAntiDesyncGetClosestPlayer()
    local hrp = _G.AceAntiDesync and _G.AceAntiDesync.hrp
    if not hrp or not hrp.Parent then
        local c = LP.Character
        hrp = c and c:FindFirstChild("HumanoidRootPart")
        if hrp then _G.AceAntiDesync.hrp = hrp end
    end
    if not hrp then return nil, math.huge end
    local cp, cd = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local tr = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if tr and hum and hum.Health > 0 then
                local targetY = tr.Position.Y
                -- Ignore decoy/void targets and immediately select another
                -- living enemy so tracking and swinging never stall.
                if targetY >= -30 and targetY <= 1200 then
                    local d = (hrp.Position - tr.Position).Magnitude
                    if d < cd then cd = d; cp = p end
                end
            end
        end
    end
    return cp, cd
end

function _G.AceAntiDesyncSetupChar(char)
    if not char then return end
    if not _G.AceAntiDesync then return end
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    local root = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
    _G.AceAntiDesync.h = hum
    _G.AceAntiDesync.hrp = root
    if root and root.Position.Y > -30 then
        _G.AceAntiDesync.lastSafeCFrame = root.CFrame
        _G.AceAntiDesync.lastPosition = root.Position
        _G.AceAntiDesync.lastSampleTime = tick()
    end
end

function _aceFiniteVector3(v)
    return v.X==v.X and v.Y==v.Y and v.Z==v.Z
        and math.abs(v.X)<1e7 and math.abs(v.Y)<1e7 and math.abs(v.Z)<1e7
end
function _G.AceAntiDesyncInspectTarget(player,targetRoot,myRoot)
    if not player or not targetRoot or not targetRoot.Parent then return true,nil end
    local guard=_G.AceAntiDesync; guard.targetSamples=guard.targetSamples or {}
    local sample=guard.targetSamples[player] or {}; guard.targetSamples[player]=sample
    local now=tick(); local pos=targetRoot.Position; local vel=targetRoot.AssemblyLinearVelocity
    local destroyHeight=workspace.FallenPartsDestroyHeight or -500
    local voidFloor=math.max(destroyHeight+90,-50)
    local dt=sample.time and math.max(now-sample.time,1/240) or math.huge
    local delta=sample.position and (pos-sample.position) or Vector3.zero
    local impossibleStep=sample.position~=nil and dt<0.4 and (delta.Magnitude>90 or math.abs(delta.Y)>38)
    local badVelocity=not _aceFiniteVector3(vel) or vel.Magnitude>650 or math.abs(vel.Y)>150
    local badPosition=not _aceFiniteVector3(pos) or pos.Y<=voidFloor or pos.Y>650
        or (myRoot and (pos-myRoot.Position).Magnitude>4000)
    if badPosition or badVelocity or impossibleStep then sample.suspiciousUntil=now+1.35
    elseif now>=(sample.suspiciousUntil or 0) then sample.safePosition=pos; sample.safeCFrame=targetRoot.CFrame end
    sample.position=pos; sample.time=now
    return now<(sample.suspiciousUntil or 0),sample
end

function _G.AceAntiDesyncGuardVoid(root, hum, targetRoot)
    if not root or not hum or not _G.AceAntiDesync then return false end
    local guard = _G.AceAntiDesync
    local now = tick()
    local position = root.Position
    local velocity = root.AssemblyLinearVelocity
    local destroyHeight = workspace.FallenPartsDestroyHeight or -500
    local voidFloor = math.max(destroyHeight + 80, -55)
    local dt = now - (guard.lastSampleTime or now)
    local suddenDrop = guard.lastPosition and dt <= 0.35 and position.Y < guard.lastPosition.Y - 40
    -- Anti TP-bat sky-drag: detect any fast upward pull
    local suddenRise = guard.lastPosition and dt <= 0.35 and position.Y > guard.lastPosition.Y + 25
    local safeRise = guard.lastSafeCFrame and position.Y > guard.lastSafeCFrame.Position.Y + 30
    local forcedLaunch = math.abs(velocity.Y) > 90 or velocity.Magnitude > 450
    local inVoid = position.Y <= voidFloor
    local resetHeight = position.Y > 400
    local recovering = now < (guard.voidRecoverUntil or 0)

    if inVoid or suddenDrop or suddenRise or safeRise or forcedLaunch or resetHeight then
        -- Break PhysicsRepRootPart so their anti can no longer sky-drag us
        if sethiddenproperty then
            pcall(function() sethiddenproperty(root, "PhysicsRepRootPart", root) end)
        end
        -- Prefer snap back onto the target (keep TP bat stuck on them)
        local recoveryCFrame = guard.safeEngagementCFrame or guard.lastSafeCFrame
        if targetRoot and targetRoot.Parent and targetRoot.Position.Y > voidFloor + 10 and targetRoot.Position.Y < 350 then
            local tp = targetRoot.Position
            local recoveryPos = Vector3.new(tp.X, tp.Y + 0.9, tp.Z)
            local facing = Vector3.new(targetRoot.CFrame.LookVector.X, 0, targetRoot.CFrame.LookVector.Z)
            if facing.Magnitude < 0.01 then facing = Vector3.new(0, 0, -1) end
            recoveryCFrame = CFrame.lookAt(recoveryPos, recoveryPos + facing.Unit)
        end
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            pcall(function() root.Velocity = Vector3.zero end)
            pcall(function() root.RotVelocity = Vector3.zero end)
            hum.PlatformStand = false
            hum.Sit = false
            hum.AutoRotate = true
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
            if recoveryCFrame then root.CFrame = recoveryCFrame end
        end)
        guard.voidRecoverUntil = now + 0.55
        guard._physPulseUntil = now + 0.2
        recovering = true
    elseif not recovering and position.Y > voidFloor + 15 and math.abs(velocity.Y) < 85 and position.Y < 250 then
        guard.lastSafeCFrame = root.CFrame
    end

    if recovering then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            -- Keep re-snapping to target during recovery so anti cannot peel us off
            if targetRoot and targetRoot.Parent and targetRoot.Position.Y > voidFloor + 10 and targetRoot.Position.Y < 350 then
                local tp = targetRoot.Position + Vector3.new(0, 0.9, 0)
                root.CFrame = CFrame.new(tp)
            end
        end)
        if sethiddenproperty then
            pcall(function() sethiddenproperty(root, "PhysicsRepRootPart", root) end)
        end
    end
    guard.lastPosition = root.Position
    guard.lastSampleTime = now
    return recovering
end

function _G.AceStartTpBatV1()
    if _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then
        warn("[MAY duels] TP Bat blocked by safe mode")
        return false
    end
    pcall(function() if _G.AceStopAutoTPForAction then _G.AceStopAutoTPForAction() end end)
    pcall(function() if _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end end)
    pcall(function() if stopBatAimbot then stopBatAimbot() end end)
    pcall(function() if stopZombieBatAimbot then stopZombieBatAimbot() end end)
    State.batAimbotToggled = false
    if stackBtnRefs and stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end

    _G.AceAntiDesyncAimbotOn = true
    if _G.AceAntiDesync and _G.AceAntiDesync.conn then
        pcall(function() _G.AceAntiDesync.conn:Disconnect() end)
        _G.AceAntiDesync.conn = nil
    end
    _G.AceAntiDesync = _G.AceAntiDesync or {}
    _G.AceAntiDesync.hittingCooldown = false
    _G.AceAntiDesync.targetSamples = _G.AceAntiDesync.targetSamples or {}

    local function getBat()
        return _G.AceAntiDesyncGetBat and _G.AceAntiDesyncGetBat() or nil
    end
    local function tryHit()
        if _G.AceBatSwingBlocked and _G.AceBatSwingBlocked() then return end
        if _G.AceAntiDesync.hittingCooldown then return end
        _G.AceAntiDesync.hittingCooldown = true
        pcall(function()
            local bat = getBat()
            if not bat then return end
            local char = LP.Character
            if bat.Parent ~= char then
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum:EquipTool(bat) end) end
            end
            pcall(function() bat:Activate() end)
            local ev = bat:FindFirstChildWhichIsA("RemoteEvent")
            if ev then pcall(function() ev:FireServer() end) end
        end)
        task.delay(0.08, function()
            if _G.AceAntiDesync then _G.AceAntiDesync.hittingCooldown = false end
        end)
    end
    local function closestRoot()
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local locked=_G.AceAntiDesync.targetPlayer
        if locked and locked.Parent==Players and locked.Character then
            local lr=locked.Character:FindFirstChild("HumanoidRootPart")
            local lh=locked.Character:FindFirstChildOfClass("Humanoid")
            if lr and lh and lh.Health>0 then return lr,locked end
        end
        local best, bd = nil, math.huge
        local bestPlayer=nil
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local tr = p.Character:FindFirstChild("HumanoidRootPart")
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if tr and hum and hum.Health > 0 then
                    local suspicious,sample=_G.AceAntiDesyncInspectTarget(p,tr,hrp)
                    local pos=suspicious and sample and sample.safePosition or tr.Position
                    if pos then local d=(hrp.Position-pos).Magnitude
                        if d<bd then bd=d; best=tr; bestPlayer=p end end
                end
            end
        end
        _G.AceAntiDesync.targetPlayer=bestPlayer
        return best,bestPlayer
    end

    _G.AceAntiDesync.conn = RunService.Heartbeat:Connect(function()
        if not _G.AceAntiDesyncAimbotOn then return end
        if antiKickEnabled and _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
            _G.AceStopAntiDesyncAimbot()
            return
        end
        local char = LP.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        local tr,targetPlayer = closestRoot()
        if not tr then return end
        local suspicious,sample=_G.AceAntiDesyncInspectTarget(targetPlayer,tr,hrp)
        if _G.AceAntiDesyncGuardVoid(hrp,hum,suspicious and nil or tr) then tryHit(); return end
        if suspicious then
            local recovery=_G.AceAntiDesync.safeEngagementCFrame or _G.AceAntiDesync.lastSafeCFrame
            if sethiddenproperty then pcall(function() sethiddenproperty(hrp,"PhysicsRepRootPart",hrp) end) end
            local safePos=sample and sample.safePosition
            local anchor=recovery and recovery.Position or hrp.Position
            local targetXZ=safePos or anchor
            if _aceFiniteVector3(tr.Position) then
                local reference=safePos or anchor
                local horizontalDelta=Vector3.new(tr.Position.X-reference.X,0,tr.Position.Z-reference.Z).Magnitude
                if horizontalDelta<=180 then targetXZ=tr.Position end
            end
            local sanitizedPos=Vector3.new(targetXZ.X,anchor.Y,targetXZ.Z)
            local facing=Vector3.new(tr.CFrame.LookVector.X,0,tr.CFrame.LookVector.Z)
            if facing.Magnitude<0.01 then facing=Vector3.new(0,0,-1) end
            local sanitizedCFrame=CFrame.lookAt(sanitizedPos,sanitizedPos+facing.Unit)
            pcall(function()
                hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero
                if (hrp.Position-sanitizedPos).Magnitude>5 then hrp.CFrame=sanitizedCFrame end
            end)
            local cam=workspace.CurrentCamera
            if cam then cam.CFrame=CFrame.new(cam.CFrame.Position,sanitizedPos) end
            tryHit(); return
        end
        local guard = _G.AceAntiDesync
        local now = tick()
        -- Live target position every frame (predict slightly with velocity so follow stays on them)
        local tvel = tr.AssemblyLinearVelocity
        local predict = Vector3.new(tvel.X, 0, tvel.Z) * 0.05
        local rawTarget = tr.Position + Vector3.new(0, 0.9, 0) + predict
        -- Use LIVE target Y; do not freeze to old lastSafeCFrame (that caused stuck old pos)
        local targetPos = rawTarget
        if targetPos.Y < -20 then
            targetPos = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)
        end
        local facing = Vector3.new(tr.CFrame.LookVector.X, 0, tr.CFrame.LookVector.Z)
        if facing.Magnitude < 0.01 then
            local flat = Vector3.new(tr.Position.X - hrp.Position.X, 0, tr.Position.Z - hrp.Position.Z)
            facing = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
        end
        guard.safeEngagementCFrame = CFrame.lookAt(targetPos, targetPos + facing.Unit)

        -- ALWAYS snap to current target each frame so we never sit on old position
        pcall(function()
            hrp.CFrame = guard.safeEngagementCFrame
            hrp.AssemblyLinearVelocity = Vector3.new(tvel.X, 0, tvel.Z)
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)

        -- PhysicsRepRootPart for desync stick, but skip during void-recovery window
        if sethiddenproperty and now >= (guard._physPulseUntil or 0) then
            pcall(function() sethiddenproperty(hrp, "PhysicsRepRootPart", tr) end)
        end

        local cam = workspace.CurrentCamera
        if cam then
            cam.CFrame = CFrame.new(cam.CFrame.Position, tr.Position)
        end
        tryHit()
    end)

    if stackBtnRefs and stackBtnRefs.antiDesync then stackBtnRefs.antiDesync.setOn(true) end
    pcall(function() if requestSave then requestSave() end end)
    print("[MAY duels] TP Bat ON (anti-anti hardened)")
    return true
end

function _G.AceStopAntiDesyncAimbot()
    _G.AceAntiDesyncAimbotOn = false
    if _G.AceAntiDesync and _G.AceAntiDesync.conn then
        pcall(function() _G.AceAntiDesync.conn:Disconnect() end)
        _G.AceAntiDesync.conn = nil
    end

    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if sethiddenproperty then pcall(function() sethiddenproperty(root,"PhysicsRepRootPart",root) end) end
    end

    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.AutoRotate = (_G.AceAntiDesync.prevAutoRotate == nil) and true or _G.AceAntiDesync.prevAutoRotate
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end

    if _G.AceAntiDesync then
        _G.AceAntiDesync.hittingCooldown=false
        _G.AceAntiDesync.targetPlayer=nil
        _G.AceAntiDesync.safeEngagementCFrame=nil
    end
    if stackBtnRefs and stackBtnRefs.antiDesync then stackBtnRefs.antiDesync.setOn(false) end
    pcall(function() if requestSave then requestSave() end end)
    print("[MAY duels] TP Bat OFF")
end

-- ============================================================
-- TP BAT V3 (portado do Adapt Source) + TP BAT V2 (classico)
-- ============================================================
TPBATV2_TOOL_NAMES = {
    "Bat","Slap","Iron Slap","Gold Slap","Diamond Slap",
    "Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap",
    "Nuclear Slap","Galaxy Slap","Glitched Slap"
}

function _G.AceTpBatV2GetBat()
    local char = LP.Character
    if not char then return nil end
    for _, name in ipairs(TPBATV2_TOOL_NAMES) do
        local tool = char:FindFirstChild(name)
        if tool and tool:IsA("Tool") then return tool end
    end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, name in ipairs(TPBATV2_TOOL_NAMES) do
            local tool = bp:FindFirstChild(name)
            if tool and tool:IsA("Tool") then
                tool.Parent = char
                return tool
            end
        end
    end
    return nil
end

function _G.AceTpBatV2TrySwing()
    if _G.AceBatSwingBlocked and _G.AceBatSwingBlocked() then return end
    if _G.AceAntiDesync.hittingCooldown then return end
    _G.AceAntiDesync.hittingCooldown = true
    pcall(function()
        local bat = _G.AceTpBatV2GetBat()
        if not bat then return end
        bat:Activate()
        local ev = bat:FindFirstChildWhichIsA("RemoteEvent")
        if ev then ev:FireServer() end
    end)
    task.delay(0.08, function()
        if _G.AceAntiDesync then _G.AceAntiDesync.hittingCooldown = false end
    end)
end

function _G.AceTpBatV2GetClosestPlayer()
    local hrp = _G.AceAntiDesync and _G.AceAntiDesync.hrp
    if not hrp then return nil end
    local closest, bestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local dist = (hrp.Position - root.Position).Magnitude
                if dist < bestDist then bestDist = dist; closest = player end
            end
        end
    end
    return closest, bestDist
end

function _G.AceStartTpBatV3()
    if _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then
        warn("[MAY duels] TP Bat V2 blocked by safe mode")
        return false
    end
    pcall(function() if _G.AceStopAutoTPForAction then _G.AceStopAutoTPForAction() end end)
    pcall(function() if _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end end)
    pcall(function() if stopBatAimbot then stopBatAimbot() end end)
    pcall(function() if stopZombieBatAimbot then stopZombieBatAimbot() end end)
    State.batAimbotToggled = false
    if stackBtnRefs and stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end

    _G.AceAntiDesync = _G.AceAntiDesync or {}
    if _G.AceAntiDesync.conn then
        pcall(function() _G.AceAntiDesync.conn:Disconnect() end)
        _G.AceAntiDesync.conn = nil
    end
    _G.AceAntiDesyncAimbotOn = true
    _G.AceAntiDesync.hittingCooldown = false

    local char = LP.Character
    if char then
        _G.AceAntiDesync.h = char:FindFirstChildOfClass("Humanoid")
        _G.AceAntiDesync.hrp = char:FindFirstChild("HumanoidRootPart")
    end

    _G.AceAntiDesync.conn = RunService.Heartbeat:Connect(function()
        if not _G.AceAntiDesyncAimbotOn then return end
        if not _G.AceAntiDesync.h or not _G.AceAntiDesync.hrp
            or not _G.AceAntiDesync.hrp.Parent then
            local currentChar = LP.Character
            if not currentChar then return end
            _G.AceAntiDesync.h = currentChar:FindFirstChildOfClass("Humanoid")
            _G.AceAntiDesync.hrp = currentChar:FindFirstChild("HumanoidRootPart")
            if not _G.AceAntiDesync.h or not _G.AceAntiDesync.hrp then return end
        end

        local target = _G.AceTpBatV2GetClosestPlayer()
        _G.AceAntiDesync.targetPlayer = target
        _G.AceCurrentAimbotTarget = target
        if not target or not target.Character then return end

        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end

        if sethiddenproperty then
            pcall(sethiddenproperty, _G.AceAntiDesync.hrp, "PhysicsRepRootPart", targetRoot)
        end

        local targetPos = targetRoot.Position + Vector3.new(0, 0.9, 0)
        if (_G.AceAntiDesync.hrp.Position - targetPos).Magnitude > 8 then
            _G.AceAntiDesync.hrp.CFrame = CFrame.new(targetPos)
        end

        local cam = workspace.CurrentCamera
        if cam then
            cam.CFrame = CFrame.new(cam.CFrame.Position, targetRoot.Position)
        end

        _G.AceTpBatV2TrySwing()
    end)

    if stackBtnRefs and stackBtnRefs.antiDesync then stackBtnRefs.antiDesync.setOn(true) end
    pcall(function() if requestSave then requestSave() end end)
    print("[MAY duels] TP Bat V3 ON (Adapt Source)")
    return true
end

-- ============================================================
-- TP BAT V2 (classico May Duels: TP atras do alvo + swing travado)
-- ============================================================
function _G.AceStartTpBatV2()
    if _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then
        warn("[MAY duels] TP Bat V2 blocked by safe mode")
        return false
    end
    pcall(function() if _G.AceStopAutoTPForAction then _G.AceStopAutoTPForAction() end end)
    pcall(function() if _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end end)
    pcall(function() if stopBatAimbot then stopBatAimbot() end end)
    pcall(function() if stopZombieBatAimbot then stopZombieBatAimbot() end end)
    State.batAimbotToggled = false
    if stackBtnRefs and stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end

    _G.AceAntiDesync = _G.AceAntiDesync or {}
    if _G.AceAntiDesync.conn then
        pcall(function() _G.AceAntiDesync.conn:Disconnect() end)
        _G.AceAntiDesync.conn = nil
    end
    _G.AceAntiDesyncAimbotOn = true
    _G.AceAntiDesync.hittingCooldown = false

    local char = LP.Character
    if char then
        _G.AceAntiDesync.h = char:FindFirstChildOfClass("Humanoid")
        _G.AceAntiDesync.hrp = char:FindFirstChild("HumanoidRootPart")
    end

    _G.AceAntiDesync.conn = RunService.Heartbeat:Connect(function()
        if not _G.AceAntiDesyncAimbotOn then return end
        local hrp = _G.AceAntiDesync.hrp
        if not hrp or not hrp.Parent then
            local cc = LP.Character
            if not cc then return end
            _G.AceAntiDesync.h = cc:FindFirstChildOfClass("Humanoid")
            _G.AceAntiDesync.hrp = cc:FindFirstChild("HumanoidRootPart")
            hrp = _G.AceAntiDesync.hrp
            if not hrp then return end
        end

        local target = _G.AceTpBatV2GetClosestPlayer()
        _G.AceAntiDesync.targetPlayer = target
        _G.AceCurrentAimbotTarget = target
        if not target or not target.Character then return end
        local troot = target.Character:FindFirstChild("HumanoidRootPart")
        if not troot then return end

        -- V2: cola ATRAS do alvo e trava a velocidade (sem PhysicsRepRootPart)
        local behind = troot.CFrame * CFrame.new(0, 0, 3.2)
        if (hrp.Position - behind.Position).Magnitude > 4 then
            hrp.CFrame = CFrame.new(behind.Position, troot.Position)
        end
        hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
        hrp.AssemblyAngularVelocity = Vector3.zero

        local cam = workspace.CurrentCamera
        if cam then
            cam.CFrame = CFrame.new(cam.CFrame.Position, troot.Position)
        end

        _G.AceTpBatV2TrySwing()
    end)

    if stackBtnRefs and stackBtnRefs.antiDesync then stackBtnRefs.antiDesync.setOn(true) end
    pcall(function() if requestSave then requestSave() end end)
    print("[MAY duels] TP Bat V2 ON (classico)")
    return true
end

-- ============================================================
-- ============================================================
-- TP BAT V3 (motor portado do Ambitious -- lá é o "TP BAT V2")
-- Orbita fixa ao redor do inimigo com predicao de velocidade.
-- ============================================================
_G.AceTpBatOrbit = _G.AceTpBatOrbit or {
    velHist = setmetatable({}, { __mode = "k" }),
    angle   = 0,
    radius  = 4.2,
    speed   = 80,
}

function _G.AceTpBatOrbitTrackVel(tr)
    local O = _G.AceTpBatOrbit
    local now = os.clock()
    local pos = tr.Position
    local vel = tr.AssemblyLinearVelocity or Vector3.zero
    local h = O.velHist[tr]
    if h then
        local dt = now - h.t
        if dt > 0.004 and dt < 0.5 then
            local measured = (pos - h.p) / dt
            if measured.Magnitude < 180 then
                local blend = math.clamp(dt * 12, 0.2, 0.85)
                vel = (h.v or vel):Lerp(measured, blend)
            end
        end
    end
    O.velHist[tr] = { t = now, p = pos, v = vel }
    return vel
end

function _G.AceTpBatOrbitSnap(hrp, pos, lookAt)
    if (pos - lookAt).Magnitude > 0.001 then
        hrp.CFrame = CFrame.new(pos, lookAt)
    else
        hrp.CFrame = CFrame.new(pos)
    end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end

function _G.AceStartTpBatAmbV2()
    if _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then
        warn("[MAY duels] TP Bat V3 blocked by safe mode")
        return false
    end
    pcall(function() if _G.AceStopAutoTPForAction then _G.AceStopAutoTPForAction() end end)
    pcall(function() if _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end end)
    pcall(function() if stopBatAimbot then stopBatAimbot() end end)
    pcall(function() if stopZombieBatAimbot then stopZombieBatAimbot() end end)
    State.batAimbotToggled = false
    if stackBtnRefs and stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end

    _G.AceAntiDesync = _G.AceAntiDesync or {}
    if _G.AceAntiDesync.conn then
        pcall(function() _G.AceAntiDesync.conn:Disconnect() end)
        _G.AceAntiDesync.conn = nil
    end
    _G.AceAntiDesyncAimbotOn = true
    _G.AceAntiDesync.hittingCooldown = false

    local O = _G.AceTpBatOrbit
    O.angle = 0
    table.clear(O.velHist)

    local char = LP.Character
    if char then
        _G.AceAntiDesync.h = char:FindFirstChildOfClass("Humanoid")
        _G.AceAntiDesync.hrp = char:FindFirstChild("HumanoidRootPart")
    end

    _G.AceAntiDesync.conn = RunService.Heartbeat:Connect(function(dt)
        if not _G.AceAntiDesyncAimbotOn then return end
        dt = (type(dt) == "number" and dt > 0 and dt < 0.1) and dt or (1/60)

        local hrp = _G.AceAntiDesync.hrp
        if not hrp or not hrp.Parent then
            local cc = LP.Character
            if not cc then return end
            _G.AceAntiDesync.h = cc:FindFirstChildOfClass("Humanoid")
            _G.AceAntiDesync.hrp = cc:FindFirstChild("HumanoidRootPart")
            hrp = _G.AceAntiDesync.hrp
            if not hrp then return end
        end
        local hum = _G.AceAntiDesync.h
        if hum and hum.Health <= 0 then return end

        local target = _G.AceTpBatV2GetClosestPlayer()
        _G.AceAntiDesync.targetPlayer = target
        _G.AceCurrentAimbotTarget = target
        if not target or not target.Character then return end
        local troot = target.Character:FindFirstChild("HumanoidRootPart")
        if not troot then return end

        -- >>> ANTI VOID (igual ao TP Bat V2 do Ambitious)
        -- Inimigo jogado no void: a orbita trabalha no ponto de origem dele.
        local rawPos, isGhost = troot.Position, false
        if _G.AceVoidESP then
            rawPos, isGhost = _G.AceVoidESP.posForPart(troot, troot.Position)
        end
        if sethiddenproperty then
            if isGhost then
                pcall(function() sethiddenproperty(hrp, "PhysicsRepRootPart", nil) end)
            else
                pcall(function() sethiddenproperty(hrp, "PhysicsRepRootPart", troot) end)
            end
        end
        -- <<< ANTI VOID

        local center = rawPos + Vector3.new(0, 0.9, 0)
        local flatVel = Vector3.zero
        if not isGhost then
            local tv = _G.AceTpBatOrbitTrackVel(troot)
            flatVel = Vector3.new(tv.X, 0, tv.Z)
            if flatVel.Magnitude > 110 then flatVel = flatVel.Unit * 110 end
        end
        local predicted = center + flatVel * 0.05

        O.angle = (O.angle or 0) + (O.speed or 80) * dt
        local ang = O.angle
        local orbitPos = predicted + Vector3.new(
            math.cos(ang) * (O.radius or 4.2),
            0,
            math.sin(ang) * (O.radius or 4.2)
        )
        _G.AceTpBatOrbitSnap(hrp, orbitPos, predicted)

        local cam = workspace.CurrentCamera
        if cam then
            cam.CFrame = CFrame.new(cam.CFrame.Position, rawPos)
        end

        _G.AceTpBatV2TrySwing()
    end)

    if stackBtnRefs and stackBtnRefs.antiDesync then stackBtnRefs.antiDesync.setOn(true) end
    pcall(function() if requestSave then requestSave() end end)
    print("[MAY duels] TP Bat V3 ON (motor Ambitious / orbita)")
    return true
end

-- TP BAT 2 (motor importado do Flow Hub: VisionBat X/Y hysteresis)
-- ============================================================
_G.AceFlowTpBat = _G.AceFlowTpBat or {
    on=false, conn=nil, hitCD=false, target=nil,
    maxY=100, returnY=80, maxX=90, returnX=70,
    yBlocked=false, xBlocked=false,
}

function _G.AceStopFlowTpBat()
    local F = _G.AceFlowTpBat
    F.on = false
    _G.AceFlowTpBatOn = false
    if F.conn then pcall(function() F.conn:Disconnect() end); F.conn=nil end
    F.hitCD=false; F.target=nil; F.yBlocked=false; F.xBlocked=false
    local char=LP.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if root then
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
        if sethiddenproperty then pcall(function() sethiddenproperty(root,"PhysicsRepRootPart",root) end) end
    end
    if hum then hum.AutoRotate=true; hum.PlatformStand=false end
    if _G._K7SetTpBat2Visual then pcall(_G._K7SetTpBat2Visual,false) end
end

function _G.AceStartFlowTpBat()
    if _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then return false end
    if _G.AceAntiDesyncAimbotOn then _G.AceStopAntiDesyncAimbot() end
    pcall(function() if _G.AceStopAutoTPForAction then _G.AceStopAutoTPForAction() end end)
    pcall(function() if _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end end)
    pcall(function() if stopBatAimbot then stopBatAimbot() end end)
    pcall(function() if stopZombieBatAimbot then stopZombieBatAimbot() end end)

    local F=_G.AceFlowTpBat
    if F.conn then pcall(function() F.conn:Disconnect() end) end
    F.on=true; _G.AceFlowTpBatOn=true; F.hitCD=false
    F.yBlocked=false; F.xBlocked=false

    local function getBat()
        return _G.AceTpBatV2GetBat and _G.AceTpBatV2GetBat() or nil
    end
    local function hit()
        if F.hitCD or (_G.AceBatSwingBlocked and _G.AceBatSwingBlocked()) then return end
        F.hitCD=true
        pcall(function()
            local bat=getBat(); local char=LP.Character
            if not bat then return end
            if char and bat.Parent~=char then
                local hum=char:FindFirstChildOfClass("Humanoid")
                if hum then hum:EquipTool(bat) end
            end
            bat:Activate()
            local ev=bat:FindFirstChildWhichIsA("RemoteEvent")
            if ev then ev:FireServer() end
            local rf=bat:FindFirstChildWhichIsA("RemoteFunction")
            if rf then rf:InvokeServer() end
        end)
        task.delay(0.08,function() F.hitCD=false end)
    end
    local function closest(root)
        local yLimit=F.yBlocked and F.returnY or F.maxY
        local xLimit=F.xBlocked and F.returnX or F.maxX
        local best,bestDist=nil,math.huge
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and p.Character then
                local tr=p.Character:FindFirstChild("HumanoidRootPart")
                local hum=p.Character:FindFirstChildOfClass("Humanoid")
                if tr and hum and hum.Health>0 then
                    local yd=math.abs(tr.Position.Y-root.Position.Y)
                    local xd=math.abs(tr.Position.X-root.Position.X)
                    if yd<=yLimit and xd<=xLimit then
                        local d=(root.Position-tr.Position).Magnitude
                        if d<bestDist then bestDist=d; best=tr end
                    end
                end
            end
        end
        return best
    end

    F.conn=RunService.Heartbeat:Connect(function()
        if not F.on then return end
        local char=LP.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health<=0 then return end
        local tr=closest(root)
        if not tr then
            F.yBlocked=true; F.xBlocked=true
            if sethiddenproperty then pcall(function() sethiddenproperty(root,"PhysicsRepRootPart",root) end) end
            return
        end
        local yd=math.abs(tr.Position.Y-root.Position.Y)
        local xd=math.abs(tr.Position.X-root.Position.X)
        if yd>(F.yBlocked and F.returnY or F.maxY) then F.yBlocked=true; return end
        if xd>(F.xBlocked and F.returnX or F.maxX) then F.xBlocked=true; return end
        F.yBlocked=false; F.xBlocked=false; F.target=tr
        if sethiddenproperty then pcall(function() sethiddenproperty(root,"PhysicsRepRootPart",tr) end) end
        local pos=tr.Position+Vector3.new(0,0.9,0)
        root.CFrame=CFrame.new(pos,tr.Position+tr.CFrame.LookVector)
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
        local cam=workspace.CurrentCamera
        if cam then cam.CFrame=CFrame.new(cam.CFrame.Position,tr.Position) end
        hit()
    end)
    if _G._K7SetTpBat2Visual then pcall(_G._K7SetTpBat2Visual,true) end
    return true
end

function _G.AceToggleFlowTpBat()
    if _G.AceFlowTpBatOn then _G.AceStopFlowTpBat() else _G.AceStartFlowTpBat() end
end

-- ============================================================
-- BODY LOCK (portado do Adapt)
-- ============================================================
_G.AceBodyLockEnabled = _G.AceBodyLockEnabled == true
_G.AceBodyLockConn = _G.AceBodyLockConn or nil

function _G.AceBodyLockRadius()
    return (State and tonumber(State.bodyLockRadius)) or 60
end

function _G.AceGetNearestBodyLockTarget()
    local character = LP.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local nearest, shortest = nil, math.huge
    local radius = _G.AceBodyLockRadius()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local tr = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tr and hum and hum.Health > 0 then
                local d = (tr.Position - root.Position).Magnitude
                if d <= radius and d < shortest then
                    shortest = d
                    nearest = plr
                end
            end
        end
    end
    return nearest
end

function _G.AceStartBodyLock()
    if _G.AceBodyLockConn then return end
    _G.AceBodyLockEnabled = true
    _G.AceBodyLockConn = RunService.Heartbeat:Connect(function()
        if not _G.AceBodyLockEnabled then return end
        local character = LP.Character
        local myRoot = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not myRoot or not humanoid or humanoid.Health <= 0 then return end

        local target = _G.AceGetNearestBodyLockTarget()
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = target.Character.HumanoidRootPart.Position
            local myPos = myRoot.Position
            local offset = Vector3.new(targetPos.X, myPos.Y, targetPos.Z) - myPos
            if offset.Magnitude > 0.1 then
                humanoid.AutoRotate = false
                local lookDir = offset.Unit
                local currentDir = myRoot.CFrame.LookVector
                local cross = currentDir:Cross(lookDir)
                local currentVel = myRoot.AssemblyAngularVelocity
                myRoot.AssemblyAngularVelocity = Vector3.new(currentVel.X, cross.Y * 40, currentVel.Z)
            end
        else
            humanoid.AutoRotate = true
        end
    end)
end

function _G.AceStopBodyLock()
    _G.AceBodyLockEnabled = false
    if _G.AceBodyLockConn then
        pcall(function() _G.AceBodyLockConn:Disconnect() end)
        _G.AceBodyLockConn = nil
    end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.AutoRotate = true end
end

function _G.AceSetBodyLock(on)
    _G.AceBodyLockEnabled = on == true
    if State then State.bodyLockEnabled = _G.AceBodyLockEnabled end
    if _G.AceBodyLockEnabled then
        _G.AceStartBodyLock()
    else
        _G.AceStopBodyLock()
    end
    if _G.AceBodyLockSetVisual then
        pcall(function() _G.AceBodyLockSetVisual(_G.AceBodyLockEnabled) end)
    end
end

LP.CharacterAdded:Connect(function()
    if _G.AceBodyLockEnabled then
        task.wait(0.3)
        _G.AceStopBodyLock()
        _G.AceStartBodyLock()
    end
end)

-- Rótulo e dispatcher do botão flutuante conforme o modo selecionado.
function _G.AceTpBatStackLabel()
    local m = State and State.tpBatMode or "v1"
    if m == "v3" then return "TP BAT\nV3" end
    if m == "v2" then return "TP BAT\nV2" end
    return "TP BAT\nV1"
end

-- V1 = TP Bat V1 nativo do Mystery.Vs
-- V2 = TP Bat V2 do May Duels (motor Flow Hub com histerese X/Y)
-- V3 = TP Bat V2 do Ambitious (orbita)
function _G.AceStartAntiDesyncAimbot()
    local m = State and State.tpBatMode or "v1"
    if _G.AceFlowTpBatOn and _G.AceStopFlowTpBat then pcall(_G.AceStopFlowTpBat) end
    if _G.AceAntiDesyncAimbotOn and _G.AceStopAntiDesyncAimbot then pcall(_G.AceStopAntiDesyncAimbot) end
    if m == "v3" then return _G.AceStartTpBatAmbV2() end
    if m == "v2" then return _G.AceStartFlowTpBat() end
    return _G.AceStartTpBatV1()
end

function _G.AceSetTpBatMode(mode)
    if mode ~= "v1" and mode ~= "v2" and mode ~= "v3" then mode = "v1" end
    -- Selecionar não ativa nada; apenas define o motor usado no próximo toque.
    if _G.AceAntiDesyncAimbotOn and _G.AceStopAntiDesyncAimbot then pcall(_G.AceStopAntiDesyncAimbot) end
    if _G.AceFlowTpBatOn and _G.AceStopFlowTpBat then pcall(_G.AceStopFlowTpBat) end
    State.tpBatMode = mode
    if stackBtnRefs and stackBtnRefs.antiDesync then
        stackBtnRefs.antiDesync.setOn(false)
        if stackBtnRefs.antiDesync.setLabel then stackBtnRefs.antiDesync.setLabel(_G.AceTpBatStackLabel()) end
    end
    if _G._K7SyncTpBatModeBox then pcall(_G._K7SyncTpBatModeBox) end
    pcall(function() if requestSave then requestSave() end end)
end

function _G.AceToggleAntiDesyncAimbot()
    local isOn = (_G.AceAntiDesyncAimbotOn == true) or (_G.AceFlowTpBatOn == true)
    if isOn then
        if _G.AceAntiDesyncAimbotOn and _G.AceStopAntiDesyncAimbot then _G.AceStopAntiDesyncAimbot() end
        if _G.AceFlowTpBatOn and _G.AceStopFlowTpBat then _G.AceStopFlowTpBat() end
    else
        _G.AceStartAntiDesyncAimbot()
    end
end

-- Global keybind backup
if not _G._K7AntiDesyncKeyBound then
    _G._K7AntiDesyncKeyBound = true
    UserInputService.InputBegan:Connect(function(inp, gp)
        if UserInputService:GetFocusedTextBox() then return end
        if not Keys or not Keys.antiDesync then return end
        if inp.KeyCode ~= Keys.antiDesync then return end
        if _G.SevenUpDuelsV2_MainExecuted then return end
        print("[MAY duels] AntiDesync global bind:", Keys.antiDesync.Name)
        if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
            if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
            return
        end
        pcall(function() _G.AceToggleAntiDesyncAimbot() end)
    end)
end

for _, name in ipairs({"EnvyAutoBatDesyncGUI","MwvaneNewaBatDesyncGUI","PhazeAutoBatDesyncGUI","VisionBatGui","K7AntiDesync"}) do
    pcall(function()
        local o = CoreGui:FindFirstChild(name)
        if o then o:Destroy() end
    end)
    pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        local o = pg and pg:FindFirstChild(name)
        if o then o:Destroy() end
    end)
end

LP.CharacterAdded:Connect(function(char)
    task.defer(function()
        pcall(function() _G.AceAntiDesyncSetupChar(char) end)
    end)
end)
if LP.Character then
    task.spawn(function()
        pcall(function() _G.AceAntiDesyncSetupChar(LP.Character) end)
    end)
end

-- ============================================================
-- DROP TYPES
-- ============================================================
DROP_TYPES = {
    JUMP = "Jump Drop"
}
currentDropType = DROP_TYPES.JUMP

-- ============================================================
-- ANTI-RAGDOLL (v1 boost method)
-- ============================================================
do
antiRagdollConn = nil
antiRagdollMode = nil
ragdollConnections = {}
cachedCharData = {}
isBoosting = false
arWasRagdolled = false

-- ── helpers de recuperacao (sem mexer na Speed) ───────────────
local AR_RAY = RaycastParams.new()
AR_RAY.FilterType = Enum.RaycastFilterType.Exclude
AR_RAY.IgnoreWater = true

function arSnapToGround(char, hum, root)
    if not char or not hum or not root then return end
    -- Segurando Brainrot: nunca mexer no root (era isso que bugava/resetava)
    if _G.AceBrainrotSafe and _G.AceBrainrotSafe() then return end
    pcall(function()
        AR_RAY.FilterDescendantsInstances = { char }
        local origin = root.Position + Vector3.new(0, 3, 0)
        local result = workspace:Raycast(origin, Vector3.new(0, -250, 0), AR_RAY)
        -- zera qualquer impulso que mantem o boneco no ar
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if root:FindFirstChild("Velocity") == nil then
            root.Velocity = Vector3.zero
            root.RotVelocity = Vector3.zero
        end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BodyVelocity") or obj:IsA("BodyForce")
                or obj:IsA("BodyGyro") or obj:IsA("LinearVelocity")
                or obj:IsA("VectorForce") or obj:IsA("AngularVelocity")
                or obj:IsA("AlignPosition") then
                obj:Destroy()
            end
        end
        if result then
            local hip = (hum.HipHeight or 0) + (root.Size.Y * 0.5) + 0.1
            local _, y, _ = root.CFrame:ToEulerAnglesYXZ()
            root.CFrame = CFrame.new(result.Position + Vector3.new(0, hip, 0))
                * CFrame.Angles(0, y, 0)
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end)
end

-- Reinicia o motor de Speed para ele nao ficar preso no estado do ragdoll.
function arRefreshSpeedEngine()
    if _G.__K7CleanupSpeedPhysics then
        pcall(_G.__K7CleanupSpeedPhysics)
    end
end

function arV2ResetCharacter(char)
    if _G.AceBrainrotSafe and _G.AceBrainrotSafe() then return end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return end

    pcall(function()
        hum.PlatformStand = false
        hum.Sit = false
        hum.AutoRotate = true
        root.Anchored = false

        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Motor6D") then
                obj.Enabled = true
            elseif obj:IsA("BallSocketConstraint") then
                obj:Destroy()
            elseif obj:IsA("Constraint") or obj:IsA("HingeConstraint") then
                obj.Enabled = true
            elseif obj:IsA("BasePart") then
                obj.CanCollide = (obj.Name == "HumanoidRootPart") and obj.CanCollide or true
                obj.AssemblyLinearVelocity = Vector3.zero
                obj.AssemblyAngularVelocity = Vector3.zero
            end
        end

        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        arSnapToGround(char, hum, root)
        hum:ChangeState(Enum.HumanoidStateType.Landed)
        hum:ChangeState(Enum.HumanoidStateType.Running)
        -- NUNCA sobrescrevemos WalkSpeed aqui: isso bugava a Speed do hub.
        if hum.JumpPower <= 0 then hum.JumpPower = 50 end

        if workspace.CurrentCamera then workspace.CurrentCamera.CameraSubject = hum end
        local playerModule = LP:FindFirstChild("PlayerScripts") and LP.PlayerScripts:FindFirstChild("PlayerModule")
        local controlModule = playerModule and playerModule:FindFirstChild("ControlModule")
        if controlModule then
            local loaded, module = pcall(require, controlModule)
            if loaded and module and module.Enable then module:Enable() end
        end
    end)
    arRefreshSpeedEngine()
end

function arCacheCharacterData()
    local char = LP.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    cachedCharData = { character = char, humanoid = hum, root = root }
    State._ragdollCache = cachedCharData
    return true
end

function arDisconnectAll()
    for _, conn in ipairs(ragdollConnections) do
        pcall(function() conn:Disconnect() end)
    end
    ragdollConnections = {}
end

function arIsRagdolled()
    if not cachedCharData.humanoid then return false end
    local hum = cachedCharData.humanoid
    local state = hum:GetState()
    local ragdollStates = {
        [Enum.HumanoidStateType.Physics] = true,
        [Enum.HumanoidStateType.Ragdoll] = true,
        [Enum.HumanoidStateType.FallingDown] = true,
    }
    if ragdollStates[state] then return true end
    if hum.PlatformStand == true then return true end
    local endTime = LP:GetAttribute("RagdollEndTime")
    if endTime and (endTime - workspace:GetServerTimeNow()) > 0 then return true end
    return false
end

function arForceExitRagdoll()
    if _G.AceBrainrotSafe and _G.AceBrainrotSafe() then return end
    if not cachedCharData.humanoid or not cachedCharData.root then return end
    local char, hum, root = cachedCharData.character, cachedCharData.humanoid, cachedCharData.root
    pcall(function()
        LP:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow())
    end)
    pcall(function()
        for _, descendant in ipairs(char:GetDescendants()) do
            if descendant:IsA("BallSocketConstraint") or
               (descendant:IsA("Attachment") and descendant.Name:find("RagdollAttachment")) then
                descendant:Destroy()
            elseif descendant:IsA("Motor6D") then
                descendant.Enabled = true
            end
        end
    end)
    if hum.Health <= 0 then return end
    pcall(function()
        root.Anchored = false
        hum.PlatformStand = false
        hum.Sit = false
        hum.AutoRotate = true
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        arSnapToGround(char, hum, root)
        hum:ChangeState(Enum.HumanoidStateType.Landed)
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end)
    arWasRagdolled = true
end

function arHeartbeatLoop()
    while antiRagdollMode == "v1" do
        task.wait()
        local currentlyRagdolled = arIsRagdolled()
        if currentlyRagdolled then
            arForceExitRagdoll()
        elseif arWasRagdolled then
            arWasRagdolled = false
            -- ao sair do ragdoll: garante chao + Speed intacta
            if cachedCharData.humanoid and cachedCharData.root then
                arSnapToGround(cachedCharData.character, cachedCharData.humanoid, cachedCharData.root)
            end
            arRefreshSpeedEngine()
        end
    end
end

startAntiRagdollNew = function()
    local requestedMode = State.antiRagdollVersion == "V2" and "v2" or "v1"
    if antiRagdollMode == requestedMode then return end

    antiRagdollMode = nil
    if antiRagdollConn then
        antiRagdollConn:Disconnect()
        antiRagdollConn = nil
    end
    isBoosting = false
    isBoosting = false
    arDisconnectAll()
    cachedCharData = {}

    if not arCacheCharacterData() then return end
    antiRagdollMode = requestedMode

    if requestedMode == "v2" then
        antiRagdollConn = RunService.Heartbeat:Connect(function()
            if antiRagdollMode ~= "v2" or not State.antiRagdollEnabled then return end
            local char = LP.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Physics
                or state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.FallingDown
                or state == Enum.HumanoidStateType.Dead
                or hum.PlatformStand == true
                or hum.Sit == true then
                arV2ResetCharacter(char)
            end
        end)
        return
    end

    local camConn = RunService.RenderStepped:Connect(function()
        local cam = Workspace.CurrentCamera
        if cam and cachedCharData.humanoid then
            cam.CameraSubject = cachedCharData.humanoid
        end
    end)
    table.insert(ragdollConnections, camConn)

    local respawnConn = LP.CharacterAdded:Connect(function()
        isBoosting = false
        task.wait(0.5)
        arCacheCharacterData()
    end)
    table.insert(ragdollConnections, respawnConn)

    task.spawn(arHeartbeatLoop)
end

stopAntiRagdollNew = function()
    antiRagdollMode = nil
    if antiRagdollConn then
        antiRagdollConn:Disconnect()
        antiRagdollConn = nil
    end
    isBoosting = false
    isBoosting = false
    arDisconnectAll()
    cachedCharData = {}
    State._ragdollCache = {}
end
end

-- ============================================================
-- INFINITE JUMP (HOLD MODE)
-- ============================================================
RunService.Heartbeat:Connect(function()
    if not State.infJumpEnabled then return end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local jumpHeld = UIS:IsKeyDown(Enum.KeyCode.Space) or (hum and hum.Jump == true)
    if jumpHeld and root.Velocity.Y < 30 then
        root.Velocity = Vector3.new(root.Velocity.X, 55, root.Velocity.Z)
    end
end)

-- ============================================================
-- ANTI-LAG FUNCTION (unchanged)
-- ============================================================
antiLagDescConn = nil
antiLagActive = false

-- Nunca mexer no avatar local: o Anti-Lag apagava as texturas/decais da skin,
-- por isso a skin sumia ou ficava sem cor com o Anti-Lag ligado.
function isAvatarChangerObject(obj)
    if not obj then return false end
    local ok, result = pcall(function()
        local node = obj
        for _ = 1, 6 do
            if not node then break end
            if node:GetAttribute("MysteryAvatarCategory") ~= nil then return true end
            if node:GetAttribute("SevenUpCustomSkinItem") == true then return true end
            node = node.Parent
        end
        return false
    end)
    return ok and result == true
end

function isLocalAvatarObject(obj)
    if not obj then return false end
    -- Itens do Avatar Change ficam sempre protegidos, mesmo durante o
    -- carregamento (antes de estarem parentados no character).
    if isAvatarChangerObject(obj) then return true end
    local char = LP and LP.Character
    if not char then return false end
    local ok, result = pcall(function()
        return obj == char or obj:IsDescendantOf(char)
    end)
    return ok and result == true
end

function enableAntiLag()
    if antiLagActive then return end
    antiLagActive = true

    pcall(function() Lighting.GlobalShadows = false end)

    for _, e in ipairs(Lighting:GetDescendants()) do
        pcall(function()
            if e:IsA("PostEffect") or e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or
               e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") or
               e:IsA("Atmosphere") or e:IsA("Clouds") then
                e.Enabled = false
            end
        end)
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        pcall(function()
            if isLocalAvatarObject(obj) then return end
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.Plastic
                obj.Reflectance = 0
                obj.CastShadow = false
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or
                   obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = false
            elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                obj.Enabled = false
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                if not (obj.Name == "face" and obj.Parent and obj.Parent.Name == "Head") then
                    pcall(function() obj:Destroy() end)
                end
            elseif obj:IsA("SurfaceAppearance") then
                pcall(function() obj:Destroy() end)
            elseif obj:IsA("Model") then
                -- NUNCA destruir brainrot/carry (causava reset ao pegar).
            elseif obj:IsA("Animator") and obj.Parent and obj.Parent.Parent ~= LP.Character then
                pcall(function() obj:Destroy() end)
            end
        end)
    end

    if antiLagDescConn then antiLagDescConn:Disconnect() end
    antiLagDescConn = workspace.DescendantAdded:Connect(function(obj)
        if not antiLagActive then return end
        task.defer(function()
            pcall(function()
                if isLocalAvatarObject(obj) then return end
                if obj:IsA("BasePart") then
                    obj.Material = Enum.Material.Plastic
                    obj.Reflectance = 0
                    obj.CastShadow = false
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or
                       obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                    obj.Enabled = false
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    if not (obj.Name == "face" and obj.Parent and obj.Parent.Name == "Head") then
                        pcall(function() obj:Destroy() end)
                    end
                elseif obj:IsA("SurfaceAppearance") then
                    pcall(function() obj:Destroy() end)
                elseif obj:IsA("Model") then
                    -- NUNCA destruir brainrot/carry: destruir esses modelos fazia
                    -- o servidor resetar o personagem ao pegar o Brainrot.
                elseif obj:IsA("Animator") and obj.Parent and obj.Parent.Parent ~= LP.Character then
                    pcall(function() obj:Destroy() end)
                elseif obj:IsA("PostEffect") or obj:IsA("BlurEffect") or obj:IsA("SunRaysEffect") or
                       obj:IsA("ColorCorrectionEffect") or obj:IsA("BloomEffect") or obj:IsA("DepthOfFieldEffect") or
                       obj:IsA("Atmosphere") or obj:IsA("Clouds") then
                    obj.Enabled = false
                end
            end)
        end)
    end)
end

function disableAntiLag()
    antiLagActive = false
    if antiLagDescConn then antiLagDescConn:Disconnect(); antiLagDescConn = nil end
    pcall(function()
        Lighting.GlobalShadows = true
        for _, e in ipairs(Lighting:GetDescendants()) do
            pcall(function()
                if e:IsA("PostEffect") or e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or
                   e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") or
                   e:IsA("Atmosphere") or e:IsA("Clouds") then
                    e.Enabled = true
                end
            end)
        end
    end)
end

-- ============================================================
-- SATURATED COLORS (vivid post-processing)
-- ============================================================
SAT_TAG = "SevenUpSaturatedColors"
satPulseConn = nil
satColorFx = nil

function clearSaturatedColors()
    if satPulseConn then
        pcall(function() satPulseConn:Disconnect() end)
        satPulseConn = nil
    end
    satColorFx = nil
    pcall(function()
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:GetAttribute(SAT_TAG) then
                pcall(function() e:Destroy() end)
            end
        end
    end)
end

function enableSaturatedColors()
    clearSaturatedColors()
    local lighting = Lighting
    local color = Instance.new("ColorCorrectionEffect")
    color:SetAttribute(SAT_TAG, true)
    color.Name = "SevenUpColorCorrection"
    color.Saturation = 0.6
    color.Contrast = 0.4
    color.Brightness = 0.05
    color.TintColor = Color3.fromRGB(255, 240, 220)
    color.Parent = lighting
    satColorFx = color

    local bloom = Instance.new("BloomEffect")
    bloom:SetAttribute(SAT_TAG, true)
    bloom.Name = "SevenUpBloom"
    bloom.Intensity = 0.8
    bloom.Size = 24
    bloom.Threshold = 1
    bloom.Parent = lighting

    local atmosphere = Instance.new("Atmosphere")
    atmosphere:SetAttribute(SAT_TAG, true)
    atmosphere.Name = "SevenUpAtmosphere"
    atmosphere.Density = 0.3
    atmosphere.Offset = 0.25
    atmosphere.Color = Color3.fromRGB(199, 199, 255)
    atmosphere.Decay = Color3.fromRGB(106, 112, 125)
    atmosphere.Glare = 0.2
    atmosphere.Haze = 1
    atmosphere.Parent = lighting

    local sun = Instance.new("SunRaysEffect")
    sun:SetAttribute(SAT_TAG, true)
    sun.Name = "SevenUpSunRays"
    sun.Intensity = 0.2
    sun.Spread = 0.8
    sun.Parent = lighting

    local dof = Instance.new("DepthOfFieldEffect")
    dof:SetAttribute(SAT_TAG, true)
    dof.Name = "SevenUpDOF"
    dof.FocusDistance = 25
    dof.InFocusRadius = 10
    dof.NearIntensity = 0.2
    dof.FarIntensity = 0.4
    dof.Parent = lighting

    satPulseConn = RunService.Heartbeat:Connect(function()
        if not State.saturatedColorsEnabled then return end
        if satColorFx and satColorFx.Parent then
            satColorFx.Contrast = 0.35 + math.sin(tick() * 2) * 0.05
        end
    end)
end

function disableSaturatedColors()
    State.saturatedColorsEnabled = false
    clearSaturatedColors()
end

-- ============================================================
-- REMOVE ACCESSORIES (FIXED: functions were referenced but never defined)
-- ============================================================
removeAccConn = nil
removeAccChildConn = nil
removeAccActive = false

function isHatOrHairAccessory(accessory)
    if not accessory or not accessory:IsA("Accessory") then return false end
    local accessoryType = nil
    pcall(function() accessoryType = accessory.AccessoryType end)
    if accessoryType == Enum.AccessoryType.Hat or accessoryType == Enum.AccessoryType.Hair then
        return true
    end
    for _, item in ipairs(accessory:GetDescendants()) do
        if item:IsA("Attachment")
            and (item.Name == "HatAttachment" or item.Name == "HairAttachment") then
            return true
        end
    end
    local lowerName = tostring(accessory.Name):lower()
    return lowerName:find("hair", 1, true) ~= nil or lowerName:find("hat", 1, true) ~= nil
end

function removeCharAccessories(char)
    if not char then return end
    -- IGUAL AO AMBITIOUS: o Remove Accessories nunca mexe no proprio avatar,
    -- so nos outros jogadores. Assim o Avatar Change sempre aparece para voce.
    if LP and LP.Character and char == LP.Character then return end
    for _, child in ipairs(char:GetChildren()) do
        pcall(function()
            if child:IsA("Accessory") then
                local sourceId = nil
                pcall(function() sourceId = child.SourceAssetId end)
                local customHatName = tostring(_G._K7CustomSkinHatName or "")
                -- Only hats and hair are removed. Explicit skin-hat checks
                -- cover catalog accessories whose AccessoryType is delayed.
                if child:GetAttribute("MysteryAvatarCategory") ~= nil then return end
                if isHatOrHairAccessory(child)
                    or child:GetAttribute("SevenUpCustomSkinItem") == true
                    or child.Name == "SevenUpCustomSkinHat"
                    or tostring(sourceId or "") == "127854264346577"
                    or (customHatName ~= "" and child.Name == customHatName) then
                    child:Destroy()
                end
            end
        end)
    end
end

-- IGUAL AO AMBITIOUS: limpa chapeus/cabelos dos OUTROS jogadores.
-- O proprio avatar (e o Avatar Change) nunca e tocado.
removeAccPlayerConns = removeAccPlayerConns or {}

_G._removeAccStart = function()
    removeAccActive = true

    local function bindOther(player)
        if player == LP then return end
        if removeAccPlayerConns[player] then
            pcall(function() removeAccPlayerConns[player]:Disconnect() end)
        end
        removeAccPlayerConns[player] = player.CharacterAdded:Connect(function(char)
            task.wait(0.35)
            if removeAccActive then removeCharAccessories(char) end
        end)
        if player.Character then removeCharAccessories(player.Character) end
    end

    for _, player in ipairs(Players:GetPlayers()) do pcall(bindOther, player) end

    if removeAccConn then removeAccConn:Disconnect() end
    removeAccConn = Players.PlayerAdded:Connect(function(player)
        if removeAccActive then pcall(bindOther, player) end
    end)

    if removeAccChildConn then removeAccChildConn:Disconnect() end
    removeAccChildConn = Players.PlayerRemoving:Connect(function(player)
        if removeAccPlayerConns[player] then
            pcall(function() removeAccPlayerConns[player]:Disconnect() end)
            removeAccPlayerConns[player] = nil
        end
    end)
end

_G._removeAccStop = function()
    removeAccActive = false
    if removeAccConn then removeAccConn:Disconnect(); removeAccConn = nil end
    if removeAccChildConn then removeAccChildConn:Disconnect(); removeAccChildConn = nil end
    for player, conn in pairs(removeAccPlayerConns) do
        pcall(function() conn:Disconnect() end)
        removeAccPlayerConns[player] = nil
    end
end

-- ============================================================
-- STRETCH REZ (zombie-style matrix + stretch value)
-- ============================================================
-- Stretch Rez from Zombie Hub (matrix only + stretchValue)
stretchRezConn = nil

function enableStretchRez()
    State.stretchedResEnabled = true
    local cam = workspace.CurrentCamera
    if not cam then return end
    if stretchRezConn then stretchRezConn:Disconnect() end
    stretchRezConn = RunService.RenderStepped:Connect(function()
        if not State.stretchedResEnabled then
            if stretchRezConn then stretchRezConn:Disconnect(); stretchRezConn = nil end
            return
        end
        local cam2 = workspace.CurrentCamera
        if not cam2 then return end
        local val = tonumber(State.stretchValue) or 0.7
        pcall(function()
            cam2.CFrame = cam2.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, val, 0, 0, 0, 1)
        end)
    end)
end

function disableStretchRez()
    State.stretchedResEnabled = false
    if stretchRezConn then stretchRezConn:Disconnect(); stretchRezConn = nil end
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam and _G._VezyFOV then cam.FieldOfView = _G._VezyFOV end
    end)
end

-- ============================================================
-- TRYARD ANIMATION (unchanged)
-- ============================================================
TryardAnims = {
    idle1 = "rbxassetid://133806214992291",
    idle2 = "rbxassetid://94970088341563",
    walk  = "rbxassetid://707897309",
    run   = "rbxassetid://707861613",
    jump  = "rbxassetid://116936326516985",
    fall  = "rbxassetid://116936326516985",
    climb = "rbxassetid://116936326516985",
    swim  = "rbxassetid://116936326516985",
    swimidle = "rbxassetid://116936326516985",
}
task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync({
        TryardAnims.idle1, TryardAnims.idle2, TryardAnims.walk, TryardAnims.run,
        TryardAnims.jump, TryardAnims.fall, TryardAnims.climb, TryardAnims.swim, TryardAnims.swimidle,
    }) end)
end)
tryardHeartbeatConn = nil
originalTryardAnims = nil
function isTryardPackAnim(id) for _,v in pairs(TryardAnims) do if v==id then return true end end return false end
function saveOriginalTryardAnims(char)
    local animate = char:FindFirstChild("Animate")
    if not animate then return end
    local function g(obj) return obj and obj.AnimationId or nil end
    local ids = {
        idle1 = g(animate.idle and animate.idle.Animation1),
        idle2 = g(animate.idle and animate.idle.Animation2),
        walk  = g(animate.walk and animate.walk.WalkAnim),
        run   = g(animate.run  and animate.run.RunAnim),
        jump  = g(animate.jump and animate.jump.JumpAnim),
        fall  = g(animate.fall and animate.fall.FallAnim),
        climb = g(animate.climb and animate.climb.ClimbAnim),
        swim  = g(animate.swim and animate.swim.Swim),
        swimidle = g(animate.swimidle and animate.swimidle.SwimIdle),
    }
    if not isTryardPackAnim(ids.walk) then originalTryardAnims = ids end
end
function applyTryardAnimPack(char)
    local animate = char:FindFirstChild("Animate")
    if not animate then return end
    local function s(obj,id) if obj then obj.AnimationId=id end end
    s(animate.idle and animate.idle.Animation1, TryardAnims.idle1)
    s(animate.idle and animate.idle.Animation2, TryardAnims.idle2)
    s(animate.walk and animate.walk.WalkAnim, TryardAnims.walk)
    s(animate.run  and animate.run.RunAnim,   TryardAnims.run)
    s(animate.jump and animate.jump.JumpAnim, TryardAnims.jump)
    s(animate.fall and animate.fall.FallAnim, TryardAnims.fall)
    s(animate.climb and animate.climb.ClimbAnim, TryardAnims.climb)
    s(animate.swim and animate.swim.Swim, TryardAnims.swim)
    s(animate.swimidle and animate.swimidle.SwimIdle, TryardAnims.swimidle)
end
function stopTryardAnim()
    if tryardHeartbeatConn then tryardHeartbeatConn:Disconnect(); tryardHeartbeatConn=nil end
    if originalTryardAnims and LP.Character then
        local animate = LP.Character:FindFirstChild("Animate")
        if animate then
            local function s(obj,id) if obj then obj.AnimationId=id end end
            s(animate.idle and animate.idle.Animation1, originalTryardAnims.idle1)
            s(animate.idle and animate.idle.Animation2, originalTryardAnims.idle2)
            s(animate.walk and animate.walk.WalkAnim, originalTryardAnims.walk)
            s(animate.run  and animate.run.RunAnim,   originalTryardAnims.run)
            s(animate.jump and animate.jump.JumpAnim, originalTryardAnims.jump)
            s(animate.fall and animate.fall.FallAnim, originalTryardAnims.fall)
            s(animate.climb and animate.climb.ClimbAnim, originalTryardAnims.climb)
            s(animate.swim and animate.swim.Swim, originalTryardAnims.swim)
            s(animate.swimidle and animate.swimidle.SwimIdle, originalTryardAnims.swimidle)
        end
    end
end
-- ============================================================
-- ANIMATION PACK SYSTEM (ported from Ace, replaces Tryard only toggle)
-- ============================================================
selectedAnimationPack = "OFF"
_G._K7SelectedAnimationPack = "OFF"
AnimationPackList = {"OFF","Unwalk","Hit Harder","Zombie","Ninja","Knight","Elder","Levitate","Astronaut","Pirate","Toy","Vampire","Werewolf","Rthro","Stylish"}
AnimationPackIndex = 1

-- Trim only — never strip internal spaces ("Hit Harder" must stay intact)
local function _K7NormPackName(p)
    if type(p) ~= "string" then return nil end
    p = p:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[%z\r\n]", "")
    if p == "" then return nil end
    return p
end

local function _K7ResolvePackName(p)
    p = _K7NormPackName(p)
    if not p then return nil end
    for _, name in ipairs(AnimationPackList) do
        if name == p then return name end
    end
    local compact = p:lower():gsub("%s+", " ")
    for _, name in ipairs(AnimationPackList) do
        if name:lower():gsub("%s+", " ") == compact then return name end
    end
    local nospace = p:lower():gsub("%s+", "")
    for _, name in ipairs(AnimationPackList) do
        if name:lower():gsub("%s+", "") == nospace then return name end
    end
    return nil
end
_G._K7ResolvePackName = _K7ResolvePackName

function _K7SaveAnimPackFile(pack)
    pcall(function()
        local name = _K7ResolvePackName(pack) or _K7NormPackName(pack) or "OFF"
        if writefile then writefile("K7_AnimPack.txt", name) end
    end)
end

function _K7LoadAnimPackFile()
    local p = nil
    pcall(function()
        if isfile and isfile("K7_AnimPack.txt") and readfile then
            p = readfile("K7_AnimPack.txt")
        end
    end)
    return _K7ResolvePackName(p)
end

-- Load saved pack from disk immediately (file wins over default OFF)
pcall(function()
    local saved = _K7LoadAnimPackFile()
    if saved and saved ~= "OFF" then
        selectedAnimationPack = saved
        _G._K7SelectedAnimationPack = saved
        for i, name in ipairs(AnimationPackList) do
            if name == saved then AnimationPackIndex = i; break end
        end
        if State then State.tryardAnimEnabled = true end
        print("[MAY duels] Anim pack restored from file:", saved)
    end
end)

AnimationPacks = {
    ["Zombie"]    = {idle={{"rbxassetid://616158929",1},{"rbxassetid://616158929",1}},walk="rbxassetid://616168032",run="rbxassetid://616163682",jump="rbxassetid://616161997",fall="rbxassetid://616157476",climb="rbxassetid://616156119"},
    ["Ninja"]     = {idle={{"rbxassetid://656117400",1},{"rbxassetid://656117400",1}},walk="rbxassetid://656121766",run="rbxassetid://656118852",jump="rbxassetid://656117878",fall="rbxassetid://656115606",climb="rbxassetid://656114359"},
    ["Knight"]    = {idle={{"rbxassetid://657595757",1},{"rbxassetid://657595757",1}},walk="rbxassetid://657552124",run="rbxassetid://657564596",jump="rbxassetid://658409194",fall="rbxassetid://657600338",climb="rbxassetid://658360781"},
    ["Elder"]     = {idle={{"rbxassetid://845397899",1},{"rbxassetid://845397899",1}},walk="rbxassetid://845403856",run="rbxassetid://845386501",jump="rbxassetid://845398858",fall="rbxassetid://845397673",climb="rbxassetid://845392038"},
    ["Levitate"]  = {idle={{"rbxassetid://616006778",1},{"rbxassetid://616006778",1}},walk="rbxassetid://616013216",run="rbxassetid://616013216",jump="rbxassetid://616008936",fall="rbxassetid://616005863",climb="rbxassetid://616003713"},
    ["Astronaut"] = {idle={{"rbxassetid://891621366",1},{"rbxassetid://891621366",1}},walk="rbxassetid://891636393",run="rbxassetid://891636393",jump="rbxassetid://891627522",fall="rbxassetid://891617961",climb="rbxassetid://891609353"},
    ["Pirate"]    = {idle={{"rbxassetid://750781874",1},{"rbxassetid://750781874",1}},walk="rbxassetid://750785693",run="rbxassetid://750783738",jump="rbxassetid://750782230",fall="rbxassetid://750780242",climb="rbxassetid://750779899"},
    ["Toy"]       = {idle={{"rbxassetid://782841498",1},{"rbxassetid://782841498",1}},walk="rbxassetid://782843345",run="rbxassetid://782842708",jump="rbxassetid://782847020",fall="rbxassetid://782846423",climb="rbxassetid://782843869"},
    ["Vampire"]   = {idle={{"rbxassetid://1083445855",1},{"rbxassetid://1083445855",1}},walk="rbxassetid://1083473930",run="rbxassetid://1083462077",jump="rbxassetid://1083455352",fall="rbxassetid://1083443587",climb="rbxassetid://1083439238"},
    ["Werewolf"]  = {idle={{"rbxassetid://1083195517",1},{"rbxassetid://1083195517",1}},walk="rbxassetid://1083178339",run="rbxassetid://1083216690",jump="rbxassetid://1083218792",fall="rbxassetid://1083189019",climb="rbxassetid://1083182000"},
    ["Rthro"]     = {idle={{"rbxassetid://2510196951",1},{"rbxassetid://2510196951",1}},walk="rbxassetid://2510202577",run="rbxassetid://2510198475",jump="rbxassetid://2510197830",fall="rbxassetid://2510195892",climb="rbxassetid://2510192778"},
    ["Stylish"]   = {idle={{"rbxassetid://616136790",1},{"rbxassetid://616136790",1}},walk="rbxassetid://616146177",run="rbxassetid://616140816",jump="rbxassetid://616139451",fall="rbxassetid://616134815",climb="rbxassetid://616133594"},
}
HIT_HARDER_ANIMS = {
    idle1="rbxassetid://133806214992291", idle2="rbxassetid://94970088341563",
    walk="rbxassetid://707897309", run="rbxassetid://707861613",
    jump="rbxassetid://116936326516985", fall="rbxassetid://116936326516985",
}
OriginalAnims = {}
unwalkEnabled = false
unwalkSavedAnimate = nil
hitHarderAnimEnabled = false
enableUnwalk, disableUnwalk, enableHitHarderAnim, disableHitHarderAnim = nil, nil, nil, nil

function getAnimate(char)
    char = char or LP.Character
    return char and char:FindFirstChild("Animate") or nil
end
function stopCurrentAnimations(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do pcall(function() track:Stop(0) end) end
end
function backupAnimations(char)
    local animate = getAnimate(char)
    if not animate or next(OriginalAnims) ~= nil then return end
    local function getId(obj) return obj and obj.AnimationId or nil end
    OriginalAnims = {
        idle1 = getId(animate.idle and animate.idle:FindFirstChild("Animation1")),
        idle2 = getId(animate.idle and animate.idle:FindFirstChild("Animation2")),
        walk  = getId(animate.walk and animate.walk:FindFirstChild("WalkAnim")),
        run   = getId(animate.run  and animate.run:FindFirstChild("RunAnim")),
        jump  = getId(animate.jump and animate.jump:FindFirstChild("JumpAnim")),
        fall  = getId(animate.fall and animate.fall:FindFirstChild("FallAnim")),
        climb = getId(animate.climb and animate.climb:FindFirstChild("ClimbAnim")),
    }
end
function setAnimId(obj, id) if obj and id then pcall(function() obj.AnimationId = id end) end end
function reloadAnimate(animate)
    if not animate then return end
    pcall(function() animate.Disabled=true; task.wait(); animate.Disabled=false end)
end
function resetAnimations()
    local char = LP.Character
    local animate = getAnimate(char)
    if not animate or next(OriginalAnims)==nil then return end
    stopCurrentAnimations(char)
    setAnimId(animate.idle and animate.idle:FindFirstChild("Animation1"), OriginalAnims.idle1)
    setAnimId(animate.idle and animate.idle:FindFirstChild("Animation2"), OriginalAnims.idle2)
    setAnimId(animate.walk and animate.walk:FindFirstChild("WalkAnim"),   OriginalAnims.walk)
    setAnimId(animate.run  and animate.run:FindFirstChild("RunAnim"),     OriginalAnims.run)
    setAnimId(animate.jump and animate.jump:FindFirstChild("JumpAnim"),   OriginalAnims.jump)
    setAnimId(animate.fall and animate.fall:FindFirstChild("FallAnim"),   OriginalAnims.fall)
    setAnimId(animate.climb and animate.climb:FindFirstChild("ClimbAnim"),OriginalAnims.climb)
    reloadAnimate(animate)
end
function applyAnimationPack(packName)
    selectedAnimationPack = packName or "OFF"
    _G._K7SelectedAnimationPack = selectedAnimationPack
    pcall(function() if _K7SaveAnimPackFile then _K7SaveAnimPackFile(selectedAnimationPack) end end)
    local char = LP.Character
    if not char then return false end
    local animate = getAnimate(char)
    if not animate then
        animate = char:FindFirstChild("Animate") or char:WaitForChild("Animate", 3)
    end
    if selectedAnimationPack ~= "Unwalk" and unwalkEnabled then disableUnwalk() end
    if selectedAnimationPack ~= "Hit Harder" then
        hitHarderAnimEnabled = false
        pcall(function()
            local ch = LP.Character
            if ch then stopCurrentAnimations(ch) end
        end)
    end
    if selectedAnimationPack == "Unwalk" then
        resetAnimations()
        enableUnwalk()
        return true
    end
    if selectedAnimationPack == "Hit Harder" then
        disableUnwalk()
        enableHitHarderAnim()
        return true
    end
    if selectedAnimationPack == "OFF" then
        resetAnimations()
        return true
    end
    local pack = AnimationPacks[selectedAnimationPack]
    animate = getAnimate(char)
    if not pack or not animate then return false end
    backupAnimations(char)
    stopCurrentAnimations(char)
    setAnimId(animate.idle and animate.idle:FindFirstChild("Animation1"), pack.idle[1][1])
    setAnimId(animate.idle and animate.idle:FindFirstChild("Animation2"), pack.idle[2][1])
    setAnimId(animate.walk and animate.walk:FindFirstChild("WalkAnim"),   pack.walk)
    setAnimId(animate.run  and animate.run:FindFirstChild("RunAnim"),     pack.run)
    setAnimId(animate.jump and animate.jump:FindFirstChild("JumpAnim"),   pack.jump)
    setAnimId(animate.fall and animate.fall:FindFirstChild("FallAnim"),   pack.fall)
    setAnimId(animate.climb and animate.climb:FindFirstChild("ClimbAnim"),pack.climb)
    reloadAnimate(animate)
    return true
end
enableUnwalk = function()
    unwalkEnabled = true
    local char = LP.Character
    local animate = getAnimate(char)
    if animate then
        if not unwalkSavedAnimate then unwalkSavedAnimate = animate:Clone() end
        stopCurrentAnimations(char)
        animate:Destroy()
    end
end
disableUnwalk = function()
    unwalkEnabled = false
    local char = LP.Character
    if char and not char:FindFirstChild("Animate") and unwalkSavedAnimate then
        unwalkSavedAnimate:Clone().Parent = char
    end
end
enableHitHarderAnim = function()
    hitHarderAnimEnabled = true
    local char = LP.Character
    local animate = getAnimate(char)
    if not animate then return end
    backupAnimations(char)
    stopCurrentAnimations(char)
    setAnimId(animate.idle and animate.idle:FindFirstChild("Animation1"), HIT_HARDER_ANIMS.idle1)
    setAnimId(animate.idle and animate.idle:FindFirstChild("Animation2"), HIT_HARDER_ANIMS.idle2)
    setAnimId(animate.walk and animate.walk:FindFirstChild("WalkAnim"),   HIT_HARDER_ANIMS.walk)
    setAnimId(animate.run  and animate.run:FindFirstChild("RunAnim"),     HIT_HARDER_ANIMS.run)
    setAnimId(animate.jump and animate.jump:FindFirstChild("JumpAnim"),   HIT_HARDER_ANIMS.jump)
    setAnimId(animate.fall and animate.fall:FindFirstChild("FallAnim"),   HIT_HARDER_ANIMS.fall)
    reloadAnimate(animate)
end
disableHitHarderAnim = function()
    hitHarderAnimEnabled = false
    resetAnimations()
    if selectedAnimationPack ~= "OFF" then task.wait(); applyAnimationPack(selectedAnimationPack) end
end
function syncAnimationPackIndex()
    local candidate = _G._K7SelectedAnimationPack or selectedAnimationPack
    local resolved = _K7ResolvePackName and _K7ResolvePackName(candidate) or candidate
    if resolved then
        selectedAnimationPack = resolved
        _G._K7SelectedAnimationPack = resolved
        for i, name in ipairs(AnimationPackList) do
            if name == resolved then
                AnimationPackIndex = i
                return
            end
        end
    end
    -- Only fall back to OFF if nothing valid is stored anywhere
    local disk = _K7LoadAnimPackFile and _K7LoadAnimPackFile() or nil
    if disk and disk ~= "OFF" then
        selectedAnimationPack = disk
        _G._K7SelectedAnimationPack = disk
        for i, name in ipairs(AnimationPackList) do
            if name == disk then AnimationPackIndex = i; return end
        end
    end
    -- Keep current text if unknown; do not force OFF over a non-empty selection
    if type(selectedAnimationPack) == "string" and selectedAnimationPack ~= "" and selectedAnimationPack ~= "OFF" then
        AnimationPackIndex = AnimationPackIndex or 1
        return
    end
    selectedAnimationPack = "OFF"
    _G._K7SelectedAnimationPack = "OFF"
    AnimationPackIndex = 1
end

function applySavedAnimationPackToCharacter(char)
    char = char or LP.Character
    if not char then return end
    OriginalAnims = {}
    unwalkSavedAnimate = nil
    unwalkEnabled = false
    hitHarderAnimEnabled = false

    -- Resolve pack: memory > disk > current. Never treat empty as intentional OFF if disk has a pack.
    local disk = nil
    pcall(function() if _K7LoadAnimPackFile then disk = _K7LoadAnimPackFile() end end)
    local pack = _K7ResolvePackName(_G._K7SelectedAnimationPack)
        or _K7ResolvePackName(selectedAnimationPack)
        or disk
        or "OFF"
    if (not pack or pack == "OFF") and disk and disk ~= "OFF" then
        pack = disk
    end
    if not pack or pack == "OFF" then
        if _G._K7AnimPackRefreshRow then pcall(_G._K7AnimPackRefreshRow) end
        return
    end

    selectedAnimationPack = pack
    _G._K7SelectedAnimationPack = pack
    State.tryardAnimEnabled = true
    syncAnimationPackIndex()
    if _G._K7AnimPackRefreshRow then pcall(_G._K7AnimPackRefreshRow) end
    pcall(function() if _K7SaveAnimPackFile then _K7SaveAnimPackFile(pack) end end)

    task.spawn(function()
        local ok = false
        for attempt = 1, 16 do
            if not LP.Character or LP.Character ~= char then return end
            selectedAnimationPack = pack
            _G._K7SelectedAnimationPack = pack
            local animate = char:FindFirstChild("Animate") or char:WaitForChild("Animate", 1.5)
            if animate then
                local applied = false
                pcall(function()
                    applied = applyAnimationPack(pack) == true
                end)
                selectedAnimationPack = pack
                _G._K7SelectedAnimationPack = pack
                if applied then
                    ok = true
                    if _G._K7AnimPackRefreshRow then pcall(_G._K7AnimPackRefreshRow) end
                    if attempt == 1 or attempt == 4 or attempt == 8 then
                        print("[MAY duels] Anim pack locked:", pack, "attempt", attempt)
                    end
                    -- keep reinforcing a few more times so the game Animate cannot wipe it
                    if attempt >= 6 then return end
                end
            end
            task.wait(0.35)
        end
        if not ok then
            warn("[MAY duels] Anim pack reapply failed (kept selection):", pack)
        end
        if _G._K7AnimPackRefreshRow then pcall(_G._K7AnimPackRefreshRow) end
    end)
end

function startTryardAnim()
    State.tryardAnimEnabled = true
    local pack = _K7ResolvePackName(_G._K7SelectedAnimationPack or selectedAnimationPack)
    if pack and pack ~= "OFF" then
        pcall(function() applyAnimationPack(pack) end)
    end
end
function stopTryardAnim()
    -- Do not clear the selected pack name; user asked pack to stay saved/active
    State.tryardAnimEnabled = true
end

-- Watchdog: whenever Animate is (re)created after death, re-lock the pack
local function _K7HookAnimWatch(char)
    if not char then return end
    pcall(function()
        char.ChildAdded:Connect(function(child)
            if child.Name == "Animate" then
                task.defer(function()
                    task.wait(0.1)
                    local pack = _K7ResolvePackName(_G._K7SelectedAnimationPack or selectedAnimationPack)
                    if pack and pack ~= "OFF" and LP.Character == char then
                        pcall(applySavedAnimationPackToCharacter, char)
                    end
                end)
            end
        end)
    end)
end

LP.CharacterAdded:Connect(function(char)
    _K7HookAnimWatch(char)
    task.defer(function()
        for _, delay in ipairs({0.1, 0.35, 0.75, 1.25, 2.0, 3.5, 5.0}) do
            task.delay(delay, function()
                if LP.Character == char then
                    pcall(applySavedAnimationPackToCharacter, char)
                end
            end)
        end
    end)
end)
if LP.Character then
    _K7HookAnimWatch(LP.Character)
    task.spawn(function() applySavedAnimationPackToCharacter(LP.Character) end)
end

-- Light safety net: keep name/UI locked; only re-apply if Animate was replaced
task.spawn(function()
    local lastAnimate = nil
    while _G.SevenUpDuelsV2_Running do
        task.wait(2.5)
        pcall(function()
            local pack = _K7ResolvePackName(_G._K7SelectedAnimationPack or selectedAnimationPack)
            if not pack or pack == "OFF" then
                if _G._K7AnimPackRefreshRow then pcall(_G._K7AnimPackRefreshRow) end
                return
            end
            selectedAnimationPack = pack
            _G._K7SelectedAnimationPack = pack
            if _G._K7AnimPackRefreshRow then pcall(_G._K7AnimPackRefreshRow) end
            local char = LP.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end
            local animate = char:FindFirstChild("Animate")
            if animate and animate ~= lastAnimate then
                lastAnimate = animate
                pcall(applySavedAnimationPackToCharacter, char)
            end
        end)
    end
end)

_G._K7ReapplyAnimPack = function()
    local pack = _K7ResolvePackName(_G._K7SelectedAnimationPack or selectedAnimationPack) or "OFF"
    selectedAnimationPack = pack
    _G._K7SelectedAnimationPack = pack
    applySavedAnimationPackToCharacter(LP.Character)
end

_G._K7SetAnimationPack = function(packName)
    local resolved = _K7ResolvePackName(packName) or _K7NormPackName(packName) or "OFF"
    selectedAnimationPack = resolved
    _G._K7SelectedAnimationPack = resolved
    pcall(function() if _K7SaveAnimPackFile then _K7SaveAnimPackFile(resolved) end end)
    State.tryardAnimEnabled = resolved ~= "OFF"
    syncAnimationPackIndex()
    if resolved ~= "OFF" then
        pcall(function() applyAnimationPack(resolved) end)
    else
        pcall(function() applyAnimationPack("OFF") end)
    end
    if _G._K7AnimPackRefreshRow then pcall(_G._K7AnimPackRefreshRow) end
    pcall(function() if requestSave then requestSave() end end)
end


-- ============================================================
-- STACK BUTTONS (green theme)
-- ============================================================
-- ============================================================
-- INSTANT RESET (portado do Adapt Source)
-- ============================================================
do
    local AceResetCooldown = false
    local AceResetThread = nil
    local AceResetSuccessful = false
    local AceStopResetSequence = false
    local AceResetMaxDuration = 0.05

    local AceResetArmedUntil = 0
    local AceResetLastRun = 0

    -- So o botao/keybind de Insta Reset arma o disparo. Qualquer outra chamada
    -- (speed, auto left/right, aimbots, loops) e ignorada: nada de disparo sozinho.
    -- INSTA RESET REMOVIDO: nada mais arma ou executa reset.
    function _G.AceArmInstantReset() end

    function _G.AceInstantReset(armed)
        do return end -- removido: reset nunca acontece
        if armed ~= true and tick() > AceResetArmedUntil then return end
        -- Reset NUNCA acontece sozinho: exige o botao/keybind armado e nenhum
        -- modo de movimento (speed/carry/lagger/auto) ligado.
        if tick() > AceResetArmedUntil then return end
        if _7upMovementModeActive and _7upMovementModeActive() then return end
        -- Segurando Brainrot: NUNCA resetar.
        if _G.AceSafeModeHoldingBrainrot then
            local okHold, holding = pcall(_G.AceSafeModeHoldingBrainrot)
            if okHold and holding then return end
        end
        AceResetArmedUntil = 0
        if AceResetCooldown then return end
        if tick() - AceResetLastRun < 1 then return end
        if State and (State.autoLeftEnabled or State.autoRightEnabled) then return end
        AceResetLastRun = tick()
        AceResetCooldown = true
        AceResetSuccessful = false
        AceStopResetSequence = false

        local character = LP.Character
        if not character then AceResetCooldown = false return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then AceResetCooldown = false return end

        local camera = workspace.CurrentCamera
        local lockedCF = camera and camera.CFrame or nil
        if camera and lockedCF then camera.CFrame = lockedCF end

        local isRespawning = false
        AceResetThread = task.spawn(function()
            local attempts = 0
            local maxAttempts = 40
            local originalHipHeight = humanoid.HipHeight

            while character and character.Parent and humanoid and humanoid.Health > 0
                and not isRespawning and not AceStopResetSequence do
                if LP.Character ~= character then isRespawning = true break end

                pcall(function()
                    humanoid.HipHeight = 1e30
                    humanoid.AutoRotate = true
                    local rootPart = character:FindFirstChild("HumanoidRootPart")
                    if rootPart then rootPart.CanCollide = false end
                    for _, part in ipairs(character:GetChildren()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.CanCollide = false
                        end
                    end
                end)

                if not character or not character.Parent or not humanoid
                    or humanoid.Health <= 0 or LP.Character ~= character then
                    AceResetSuccessful = true
                    break
                end

                attempts = attempts + 1
                if attempts >= maxAttempts then break end
                task.wait(AceResetMaxDuration)
            end

            if not AceResetSuccessful and character and character.Parent and humanoid
                and humanoid.Health > 0 and not isRespawning then
                -- nao mata o personagem: sem reset forcado
                task.wait(0.1)
                if not character.Parent or humanoid.Health <= 0 then AceResetSuccessful = true end
            end

            if not AceResetSuccessful and character and character.Parent and humanoid then
                pcall(function()
                    humanoid.HipHeight = originalHipHeight
                    local rootPart = character:FindFirstChild("HumanoidRootPart")
                    if rootPart then rootPart.CanCollide = true end
                    for _, part in ipairs(character:GetChildren()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.CanCollide = true
                        end
                    end
                end)
            end

            AceResetCooldown = false
            AceResetThread = nil
            AceStopResetSequence = false
        end)
    end

    function _G.AceStopInstantReset()
        AceStopResetSequence = true
        if AceResetThread then
            pcall(task.cancel, AceResetThread)
            AceResetThread = nil
        end
        AceResetCooldown = false
    end

    LP.CharacterAdded:Connect(function()
        pcall(function() _G.AceStopInstantReset() end)
        AceResetSuccessful = false
    end)
end

-- ============================================================
-- INSTA RESET (motor portado do Ambitious)
-- V1 = HipHeight 1e30 (metodo classico)
-- V2 = fling fisico (PlatformStand + velocidade absurda)
-- A versao e escolhida no menu COMBAT; o botao flutuante
-- "INSTA RESET" executa a versao selecionada.
-- ============================================================
_G.AceInstaResetBusy = false
_G.AceInstaResetGaveUp = false
_G.AceInstaResetCamConn = nil
_G.AceInstaResetCamSaved = nil

function _G.AceInstaResetUnlockCamera()
    if _G.AceInstaResetCamConn then
        pcall(function() _G.AceInstaResetCamConn:Disconnect() end)
        _G.AceInstaResetCamConn = nil
    end
    local saved = _G.AceInstaResetCamSaved
    _G.AceInstaResetCamSaved = nil
    if not saved then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    pcall(function()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        cam.CameraType = (saved.type == Enum.CameraType.Scriptable)
            and Enum.CameraType.Custom or saved.type
        cam.CameraSubject = hum or saved.subject
    end)
end

function _G.AceInstaResetLockCamera()
    local cam = workspace.CurrentCamera
    if not cam then return end
    _G.AceInstaResetUnlockCamera()
    _G.AceInstaResetCamSaved = {
        cframe  = cam.CFrame,
        type    = cam.CameraType,
        subject = cam.CameraSubject,
    }
    cam.CameraType = Enum.CameraType.Scriptable
    _G.AceInstaResetCamConn = RunService.RenderStepped:Connect(function()
        local c = workspace.CurrentCamera
        local saved = _G.AceInstaResetCamSaved
        if not c or not saved then return end
        if c.CameraType ~= Enum.CameraType.Scriptable then
            c.CameraType = Enum.CameraType.Scriptable
        end
        c.CFrame = saved.cframe
    end)
end

function _G.AceInstaResetV1()
    _G.AceInstaResetGaveUp = false
    local character = LP.Character
    if not character then _G.AceInstaResetGaveUp = true return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then _G.AceInstaResetGaveUp = true return end

    local originalHipHeight = humanoid.HipHeight
    local attempts = 0
    local done = false

    while character and character.Parent and humanoid
          and humanoid.Health > 0 and LP.Character == character
          and attempts < 40 do
        pcall(function()
            humanoid.HipHeight = 1e30
            humanoid.AutoRotate = true
            for _, part in ipairs(character:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end)
        if not character.Parent or humanoid.Health <= 0 or LP.Character ~= character then
            done = true
            break
        end
        attempts = attempts + 1
        task.wait(0.05)
    end

    if not done and character and character.Parent and humanoid and humanoid.Health > 0 then
        pcall(function() humanoid.Health = 0 end)
        task.wait(0.1)
        if not character.Parent or humanoid.Health <= 0 then done = true end
    end

    if not done then
        _G.AceInstaResetGaveUp = true
        if character and character.Parent and humanoid then
            pcall(function()
                humanoid.HipHeight = originalHipHeight
                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end)
        end
    end
end

function _G.AceInstaResetV2()
    _G.AceInstaResetGaveUp = false
    local character = LP.Character
    if not character then _G.AceInstaResetGaveUp = true return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then _G.AceInstaResetGaveUp = true return end

    local savedPlatform = humanoid.PlatformStand
    local savedBreak    = humanoid.BreakJointsOnDeath
    local BURST, WINDOW = 500, 0.3
    local FLING = 1e9

    local function applyFling(hum, r)
        hum.BreakJointsOnDeath = true
        hum.PlatformStand = true
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        r.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        r.AssemblyLinearVelocity = Vector3.new(0, FLING, 0)
    end

    local function attempt()
        local ch = LP.Character
        if ch ~= character or not character.Parent then return false end
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        local r = ch:FindFirstChild("HumanoidRootPart")
        if r then pcall(applyFling, hum, r) end
        return true
    end

    local t0 = os.clock()
    for _ = 1, BURST do
        if not attempt() then return end
    end
    while (os.clock() - t0) < WINDOW do
        RunService.Heartbeat:Wait()
        if not attempt() then return end
    end

    if not character.Parent or LP.Character ~= character then return end
    if humanoid.Health <= 0 then return end

    _G.AceInstaResetGaveUp = true
    pcall(function()
        humanoid.PlatformStand = savedPlatform
        humanoid.BreakJointsOnDeath = savedBreak
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end)
end

function _G.AceRunInstaReset()
    if _G.AceInstaResetBusy then return end
    _G.AceInstaResetBusy = true
    local ver = math.clamp(tonumber(State and State.instaResetVersion) or 1, 1, 2)
    local oldChar = LP.Character
    pcall(_G.AceInstaResetLockCamera)
    task.spawn(function()
        if ver == 2 then pcall(_G.AceInstaResetV2) else pcall(_G.AceInstaResetV1) end
        if not _G.AceInstaResetGaveUp then
            local deadline = tick() + 20
            while tick() < deadline do
                local ch = LP.Character
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                if ch and ch ~= oldChar and ch.Parent and hum and hum.Health > 0 then break end
                task.wait(0.1)
            end
        end
        pcall(_G.AceInstaResetUnlockCamera)
        _G.AceInstaResetBusy = false
    end)
end

function _G.AceSetInstaResetVersion(v)
    v = math.clamp(tonumber(v) or 1, 1, 2)
    if State then State.instaResetVersion = v end
    if _G._K7SyncInstaResetBar then pcall(_G._K7SyncInstaResetBar) end
    if stackBtnRefs and stackBtnRefs.instaReset and stackBtnRefs.instaReset.setLabel then
        stackBtnRefs.instaReset.setLabel("INSTA\nRESET")
    end
    pcall(function() if requestSave then requestSave() end end)
    return v
end

BTN_W=62; BTN_H=62; BTN_GAP=8; COLS=2; EDGE_MARGIN=20
stackButtonScale=1

-- ============================================================
-- ANTI BAT TP V1 (Mystery.Vs) / V2 (Anti Anti Rinval)
-- ============================================================
AntiBatTp = {
    enabled = false, myHRP = nil, fakeHRP = nil, conn = nil,
    lastSafeCFrame = nil, lastCheckTime = 0,
}
ANTI_BAT_TP_FAKE_Y = -1000
ANTI_BAT_TP_RANGE = 5

function antiBatTpStop()
    pcall(function() if ambAtpDisable then ambAtpDisable() end end)
    -- V1 tambem trava o movimento: garantir o destravamento ao desligar.
    pcall(function() if ambAtpUnlockMovement then ambAtpUnlockMovement() end end)
    if AntiBatTp.conn then AntiBatTp.conn:Disconnect(); AntiBatTp.conn = nil end
    if AntiBatTp.fakeHRP then pcall(function() AntiBatTp.fakeHRP:Destroy() end); AntiBatTp.fakeHRP = nil end
    AntiBatTp.lastSafeCFrame = nil
    AntiBatTp.lastCheckTime = 0
    pcall(function()
        if sethiddenproperty and AntiBatTp.myHRP and AntiBatTp.myHRP.Parent then
            sethiddenproperty(AntiBatTp.myHRP, "PhysicsRepRootPart", AntiBatTp.myHRP)
        end
    end)
end

-- V1 preserva exatamente o motor Anti Tp Bat nativo do Mystery.Vs.
function antiBatTpStartV1()
    antiBatTpStop()
    if not AntiBatTp.myHRP then
        local ch = LP.Character
        if ch then AntiBatTp.myHRP = ch:FindFirstChild("HumanoidRootPart") end
    end
    if not AntiBatTp.myHRP then return end

    local fake = Instance.new("Part")
    fake.Name         = "BlodyAntiBatFakeHRP"
    fake.Size         = Vector3.new(2, 2, 1)
    fake.Anchored     = true
    fake.CanCollide   = false
    fake.CanTouch     = false
    fake.CanQuery     = false
    fake.Transparency = 1
    fake.CFrame       = CFrame.new(AntiBatTp.myHRP.Position.X, ANTI_BAT_TP_FAKE_Y, AntiBatTp.myHRP.Position.Z)
    fake.Parent       = workspace
    AntiBatTp.fakeHRP = fake

    AntiBatTp.conn = RunService.Heartbeat:Connect(function()
        if not AntiBatTp.enabled or State.antiTpBatMode ~= "v1" then return end
        local myHRP, fakeHRP = AntiBatTp.myHRP, AntiBatTp.fakeHRP
        if not myHRP or not myHRP.Parent then return end
        if not fakeHRP or not fakeHRP.Parent then return end
        fakeHRP.CFrame = CFrame.new(myHRP.Position.X, ANTI_BAT_TP_FAKE_Y, myHRP.Position.Z)
        fakeHRP.AssemblyLinearVelocity = Vector3.new(0, -1000, 0)
        pcall(function()
            if sethiddenproperty then
                sethiddenproperty(myHRP, "PhysicsRepRootPart", fakeHRP)
            end
        end)
    end)

    -- Mesmo comportamento do V2/V3/V4: trava andar/pular enquanto ativo.
    pcall(function() if ambAtpLockMovement then ambAtpLockMovement() end end)
end

-- ============================================================
-- ANTI TP BAT V2 / V3 / V4 — motor do Ambitious
-- Desync do PhysicsRepRootPart numa part isca + lock do movimento.
--   V2 Azul  : Y = -120
--   V3 Verde : jitter aleatório recriando a part continuamente
--   V4 Roxo  : posição fixa (400, 0, 400)
-- Hard stop automático na morte do inimigo / morte própria / ragdoll.
-- ============================================================
AmbAtp = {
    active = false, voidPart = nil, jitterThread = nil, jitterRunning = false,
    lockConn = nil, frozenCFrame = nil, ws = nil, jp = nil, ar = nil,
    hooked = false,
}

function ambAtpVersion()
    local m = State.antiTpBatMode
    if m == "v3" then return 3 end
    if m == "v4" then return 4 end
    return 2
end

function ambAtpGetHRP()
    local c = LP.Character
    if not c then return nil, nil end
    return c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end

function ambAtpSetPartAppearance(part, version)
    local color, transparency
    if version == 2 then
        color, transparency = Color3.fromRGB(50, 100, 255), 0.5
    elseif version == 3 then
        color, transparency = Color3.fromRGB(50, 255, 50), 0.5
    elseif version == 4 then
        color, transparency = Color3.fromRGB(200, 50, 200), 0.5
    else
        color, transparency = Color3.fromRGB(255, 255, 255), 1
    end
    pcall(function()
        part.Color = color
        part.Transparency = transparency
    end)
end

function ambAtpRepTo(target)
    local hrp = ambAtpGetHRP()
    if hrp and sethiddenproperty and target then
        pcall(function() sethiddenproperty(hrp, "PhysicsRepRootPart", target) end)
    end
end

function ambAtpDestroyPart()
    if AmbAtp.voidPart then
        local hrp = ambAtpGetHRP()
        if hrp then ambAtpRepTo(hrp) end
        pcall(function() AmbAtp.voidPart:Destroy() end)
        AmbAtp.voidPart = nil
    end
end

function ambAtpMakePart(ver, pos)
    local p = Instance.new("Part")
    p.Name       = "DesyncTrapPart"
    p.Size       = Vector3.new(1, 1, 1)
    p.CanCollide = false
    p.Anchored   = true
    p.Position   = pos
    ambAtpSetPartAppearance(p, ver)
    p.Parent = workspace
    return p
end

function ambAtpCreateVoidPart()
    if AmbAtp.voidPart then
        pcall(function() AmbAtp.voidPart:Destroy() end)
        AmbAtp.voidPart = nil
    end
    local ver = ambAtpVersion()
    local pos
    if ver == 4 then
        pos = Vector3.new(400, 0, 400)
    elseif ver == 3 then
        local rx, rz = math.random(-300, 300), math.random(-300, 300)
        if rx == 0 and rz == 0 then rx, rz = 1, 1 end
        pos = Vector3.new(rx, 0, rz)
    else
        pos = Vector3.new(0, -120, 0)
    end
    AmbAtp.voidPart = ambAtpMakePart(ver, pos)
end

function ambAtpStopJitter()
    AmbAtp.jitterRunning = false
    if AmbAtp.jitterThread then
        pcall(task.cancel, AmbAtp.jitterThread)
        AmbAtp.jitterThread = nil
    end
end

function ambAtpStartJitter()
    ambAtpStopJitter()
    AmbAtp.jitterRunning = true
    AmbAtp.jitterThread = task.spawn(function()
        while AmbAtp.jitterRunning and AmbAtp.active and ambAtpVersion() == 3 do
            local rx, rz
            repeat
                rx = math.random(-300, 300)
                rz = math.random(-300, 300)
            until not (rx == 0 and rz == 0)
            if AmbAtp.voidPart then
                pcall(function() AmbAtp.voidPart:Destroy() end)
                AmbAtp.voidPart = nil
            end
            AmbAtp.voidPart = ambAtpMakePart(3, Vector3.new(rx, 0, rz))
            ambAtpRepTo(AmbAtp.voidPart)
            task.wait(0)
        end
    end)
end

function ambAtpLockMovement()
    local hrp, hum = ambAtpGetHRP()
    if not hrp then return end
    AmbAtp.frozenCFrame = hrp.CFrame
    if hum then
        AmbAtp.ws = hum.WalkSpeed
        AmbAtp.jp = hum.JumpPower
        AmbAtp.ar = hum.AutoRotate
        pcall(function()
            hum.WalkSpeed  = 0
            hum.JumpPower  = 0
            hum.AutoRotate = false
        end)
    end
    if AmbAtp.lockConn then pcall(function() AmbAtp.lockConn:Disconnect() end) end
    AmbAtp.lockConn = RunService.RenderStepped:Connect(function()
        local r = ambAtpGetHRP()
        if AmbAtp.frozenCFrame and r and r.Parent then
            r.CFrame = AmbAtp.frozenCFrame
        end
    end)
end

function ambAtpUnlockMovement()
    local _, hum = ambAtpGetHRP()
    if hum then
        pcall(function()
            hum.WalkSpeed = AmbAtp.ws or 16
            hum.JumpPower = AmbAtp.jp or 50
            if AmbAtp.ar == nil then hum.AutoRotate = true else hum.AutoRotate = AmbAtp.ar end
        end)
    end
    AmbAtp.ws, AmbAtp.jp, AmbAtp.ar = nil, nil, nil
    if AmbAtp.lockConn then
        pcall(function() AmbAtp.lockConn:Disconnect() end)
        AmbAtp.lockConn = nil
    end
    AmbAtp.frozenCFrame = nil
end

function ambAtpEnable()
    if AmbAtp.active then return end
    AmbAtp.active = true
    ambAtpCreateVoidPart()
    ambAtpRepTo(AmbAtp.voidPart)
    ambAtpLockMovement()
    if ambAtpVersion() == 3 then ambAtpStartJitter() end
end

function ambAtpDisable()
    if not AmbAtp.active then return end
    AmbAtp.active = false
    ambAtpStopJitter()
    ambAtpUnlockMovement()
    ambAtpDestroyPart()
end

function ambAtpApplyDesync()
    if not AmbAtp.active then return end
    if ambAtpVersion() == 3 then return end
    if not AmbAtp.voidPart or not AmbAtp.voidPart.Parent then ambAtpCreateVoidPart() end
    ambAtpRepTo(AmbAtp.voidPart)
end

-- Desliga tudo (morte do inimigo, morte própria, ragdoll)
function ambAtpHardStop()
    if not (AmbAtp.active or AntiBatTp.enabled) then return end
    AntiBatTp.enabled = false
    ambAtpDisable()
    antiBatTpStop()
    if stackBtnRefs and stackBtnRefs.antiBatTp then
        pcall(function() stackBtnRefs.antiBatTp.setOn(false) end)
    end
    if _G._K7SyncAntiTpBatRow then pcall(_G._K7SyncAntiTpBatRow) end
end

function ambAtpWatchEnemy(plr, character)
    if not character then return end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function() ambAtpHardStop() end)
    end
end

function ambAtpSetupSelf(character)
    if not character then return end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.Died:Connect(function() ambAtpHardStop() end)
    hum.StateChanged:Connect(function(_, newState)
        local isRag = (newState == Enum.HumanoidStateType.Physics)
        pcall(function()
            if newState == Enum.HumanoidStateType.Ragdoll then isRag = true end
        end)
        if isRag then ambAtpHardStop() end
    end)
end

if not AmbAtp.hooked then
    AmbAtp.hooked = true
    RunService.Heartbeat:Connect(ambAtpApplyDesync)
    RunService.Stepped:Connect(ambAtpApplyDesync)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            pcall(function()
                if p.Character then ambAtpWatchEnemy(p, p.Character) end
                p.CharacterAdded:Connect(function(c) ambAtpWatchEnemy(p, c) end)
            end)
        end
    end
    Players.PlayerAdded:Connect(function(p)
        if p == LP then return end
        pcall(function()
            p.CharacterAdded:Connect(function(c) ambAtpWatchEnemy(p, c) end)
        end)
    end)

    if LP.Character then pcall(ambAtpSetupSelf, LP.Character) end
    LP.CharacterAdded:Connect(function(c)
        task.wait(0.2)
        pcall(ambAtpSetupSelf, c)
        AntiBatTp.enabled = false
        ambAtpDisable()
        if stackBtnRefs and stackBtnRefs.antiBatTp then
            pcall(function() stackBtnRefs.antiBatTp.setOn(false) end)
        end
        if _G._K7SyncAntiTpBatRow then pcall(_G._K7SyncAntiTpBatRow) end
    end)

    -- Watchdog: realinha o estado real ao flag
    task.spawn(function()
        while true do
            task.wait(0.5)
            if AntiBatTp.enabled and State.antiTpBatMode ~= "v1" then
                if not AmbAtp.active then pcall(ambAtpEnable) end
            elseif AntiBatTp.enabled and State.antiTpBatMode == "v1" then
                -- V1 usa o mesmo lock de movimento: reaplica se cair.
                if not AmbAtp.lockConn then pcall(ambAtpLockMovement) end
            else
                if AmbAtp.active then pcall(ambAtpDisable) end
                if AmbAtp.lockConn then pcall(ambAtpUnlockMovement) end
            end
        end
    end)
end

function antiBatTpStart()
    if State.antiTpBatMode == "v1" then
        antiBatTpStartV1()
    else
        ambAtpEnable()
    end
end

function _G.AceSetAntiTpBatMode(mode)
    if mode ~= "v1" and mode ~= "v2" and mode ~= "v3" and mode ~= "v4" then mode = "v1" end
    local wasEnabled = AntiBatTp.enabled == true
    antiBatTpStop()
    State.antiTpBatMode = mode
    if wasEnabled then antiBatTpStart() end
    if stackBtnRefs and stackBtnRefs.antiBatTp then
        stackBtnRefs.antiBatTp.setOn(wasEnabled)
        if stackBtnRefs.antiBatTp.setLabel then stackBtnRefs.antiBatTp.setLabel("ANTI\nBAT TP") end
    end
    if _G._K7SyncAntiTpBatModeBox then pcall(_G._K7SyncAntiTpBatModeBox) end
    pcall(function() if requestSave then requestSave() end end)
end

function _G.AceToggleAntiBatTp()
    AntiBatTp.enabled = not AntiBatTp.enabled
    if AntiBatTp.enabled then antiBatTpStart() else antiBatTpStop() end
    if stackBtnRefs and stackBtnRefs.antiBatTp then
        stackBtnRefs.antiBatTp.setOn(AntiBatTp.enabled)
        if stackBtnRefs.antiBatTp.setLabel then stackBtnRefs.antiBatTp.setLabel("ANTI\nBAT TP") end
    end
end

function antiBatTpSetupChar(char)
    task.wait(0.2)
    AntiBatTp.myHRP = char:WaitForChild("HumanoidRootPart", 5)
    if AntiBatTp.enabled and AntiBatTp.myHRP then
        antiBatTpStop()
        task.wait(0.1)
        antiBatTpStart()
    end
end

LP.CharacterAdded:Connect(function(char)
    antiBatTpStop()
    task.spawn(function() antiBatTpSetupChar(char) end)
end)
if LP.Character then task.spawn(function() antiBatTpSetupChar(LP.Character) end) end

-- >>> ANTI BAT BEGIN
-- ============================================================
-- ANTI BAT
-- Quando attivo: lo Speed Booster smette di usare il suo proxy (che
-- viene distrutto) e scrive su root.Velocity. L'Infinite Jump non viene
-- toccato e continua a usare il suo proxy. Spegnendolo il proxy dello
-- speed booster viene ricreato: nulla di permanente.
-- ============================================================
do
  local AntiBatConn = nil
  local Speed     = 10000
  local Angle     = 0
  local Direction = 1   -- 1 aumenta, -1 diminuisce

  local function stopAntiBat()
    if AntiBatConn then
      pcall(function() AntiBatConn:Disconnect() end)
      AntiBatConn = nil
    end
    Speed     = 10000
    Angle     = 0
    Direction = 1
    _G._AmbitiousAntiBatDesiredXZ = nil
    _G._AmbitiousAntiBatSpiking = false
  end

  local function startAntiBat()
    stopAntiBat()
    AntiBatConn = RunService.Heartbeat:Connect(function()
      if not _G.AmbitiousAntiBatEnabled then return end
      local char = LP.Character
      local root = char and char:FindFirstChild("HumanoidRootPart")
      if not root or not root.Parent then return end

      -- Salva la velocita' originale X e Z
      local origXZ = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)

      -- Speed oscillante tra 10000 e 20000
      Speed = Speed + (50 * Direction)
      if Speed >= 20000 then
        Speed = 20000
        Direction = -1
      elseif Speed <= 10000 then
        Speed = 10000
        Direction = 1
      end

      -- Angolo caotico + raggio variabile
      Angle = Angle + (math.random() * 0.5)
      local radius = Speed + math.random(-5000, 5000)
      local newX = math.cos(Angle) * radius
      local newZ = math.sin(Angle) * radius

      _G._AmbitiousAntiBatSpiking = true
      root.Velocity = Vector3.new(newX, root.Velocity.Y, newZ)

      RunService.RenderStepped:Wait()

      -- Ripristina X e Z: se lo speed booster ha una velocita' desiderata
      -- si riscrive quella (la speed dell'hub), altrimenti l'originale.
      if root.Parent then
        local want = _G._AmbitiousAntiBatDesiredXZ
        if want then
          root.Velocity = Vector3.new(want.X, root.Velocity.Y, want.Z)
        else
          root.Velocity = Vector3.new(origXZ.X, root.Velocity.Y, origXZ.Z)
        end
      end
      _G._AmbitiousAntiBatSpiking = false
    end)
  end

  _G.AmbitiousAntiBatEnabled = _G.AmbitiousAntiBatEnabled == true

  -- Ogni fase e' protetta: se una fallisce non blocca le altre e si vede l'errore
  local function step(_, fn)
    pcall(fn)
  end

  _G.AmbitiousAntiBat = {
    setEnabled = function(on)
      on = on and true or false
      _G.AmbitiousAntiBatEnabled = on
      if on then
        step("startAntiBat", startAntiBat)
      else
        step("stopAntiBat", stopAntiBat)
      end
    end,
    isEnabled = function() return _G.AmbitiousAntiBatEnabled == true end,
  }

  -- Watchdog permanente: se il flag e' acceso ma i loop non ci sono
  -- (errore, respawn, disconnessione imprevista) li riavvia da solo.
  task.spawn(function()
    while true do
      task.wait(0.5)
      if _G.AmbitiousAntiBatEnabled then
        if not AntiBatConn then
          step("watchdog:start", startAntiBat)
        end
      elseif AntiBatConn then
        step("watchdog:stop", stopAntiBat)
      end
    end
  end)

  -- Respawn: il vecchio HRP e' morto, si riparte pulito
  LP.CharacterAdded:Connect(function(char)
    if _G._AmbitiousWaitCharReady then _G._AmbitiousWaitCharReady(char, 10) end
    if _G.AmbitiousAntiBatEnabled then
      startAntiBat()
    else
      stopAntiBat()
    end
  end)
end
-- <<< ANTI BAT END


stackDefs = {
    -- Order matches Flow.VS mobile grid (2 cols, right-center)
    {key="drop",       label="DROP"},
    {key="autoLeft",   label="AUTO\nLEFT"},
    {key="autoRight",  label="AUTO\nRIGHT"},
    {key="tpDown",     label="TP\nDOWN"},
    {key="carrySpeed", label="CARRY\nSPD"},
    {key="lagger",     label="LAGGER\nMODE"},
    {key="laggerCarry",label="LAGGER\nCARRY"},
    {key="antiBatTp",  label="ANTI\nBAT TP"},
    {key="antiDesync", label="TP\nBAT"},
    {key="aimbot",     label="BAT\nAIMBOT"},
    {key="batV2",      label="BAT V2"},
    {key="instaReset", label="INSTA\nRESET"},
}
function getDefaultStackPos(i)
    -- Flow.VS layout: 2-col grid anchored to the right-center of the screen
    local col=(i-1)%COLS
    local row2=math.floor((i-1)/COLS)
    local totalW = COLS*BTN_W + (COLS-1)*BTN_GAP
    local totalH = math.ceil(#stackDefs/COLS)*BTN_H + (math.ceil(#stackDefs/COLS)-1)*BTN_GAP
    local px = col*(BTN_W+BTN_GAP)
    local py = row2*(BTN_H+BTN_GAP)
    local edge = EDGE_MARGIN or 20
    return UDim2.new(1, -edge - totalW + px, 0.5, -totalH/2 + py)
end

stackWrappers = {}
function styleSingleMobileButton(wrapper, requestedShape)
    if not wrapper then return end
    local shape = tostring(requestedShape or "Can")
    if shape ~= "Circle" and shape ~= "Square" then shape = "Can" end

    local surface = wrapper:FindFirstChild("SodaCanSurface")
    local top = wrapper:FindFirstChild("IndentedCanTop")
    local logo = wrapper:FindFirstChild("FrontSevenDisc")
    local up = wrapper:FindFirstChild("MiniUp")
    local label = wrapper:FindFirstChild("StackFeatureLabel")
    local rootCorner = wrapper:FindFirstChildOfClass("UICorner")

    -- May Duels floating-button look: flat tile with a centered label only.
    if surface then surface.Visible=false end
    if top then top.Visible=false end
    if logo then logo.Visible=false end
    if up then up.Visible=false end
    if rootCorner then
        if shape == "Circle" then rootCorner.CornerRadius=UDim.new(1,0)
        elseif shape == "Square" then rootCorner.CornerRadius=UDim.new(0,12)
        else rootCorner.CornerRadius=UDim.new(0,16) end
    end
    if label then
        label.Size=UDim2.new(1,-8,1,-8)
        label.Position=UDim2.new(0,4,0,4)
        label.TextSize=12
        label.TextWrapped=true
        label.TextXAlignment=Enum.TextXAlignment.Center
        label.TextYAlignment=Enum.TextYAlignment.Center
    end
end

function applyMobileButtonShape(requestedShape)
    local shape = tostring(requestedShape or "Can")
    if shape ~= "Circle" and shape ~= "Square" then shape = "Can" end
    State.mobileButtonShape = shape
    for _,wrapper in pairs(stackWrappers or {}) do
        styleSingleMobileButton(wrapper, shape)
    end
    return shape
end

function applyStackButtonScale(value)
    stackButtonScale=math.clamp(tonumber(value) or 1,0.6,1.5)
    for _,wrapper in pairs(stackWrappers or {}) do
        if wrapper then
            local scaleObj=wrapper:FindFirstChild("MobileButtonOnlyScale")
            if scaleObj and scaleObj:IsA("UIScale") then scaleObj.Scale=stackButtonScale end
        end
    end
    return stackButtonScale
end
STACK_POS_FILE = "sevenup_stack_pos.json"

function saveStackPositionsNow()
    pcall(function()
        local btnPositions = {}
        for key, wrapper in pairs(stackWrappers) do
            if wrapper and wrapper.Parent and wrapper.Position then
                btnPositions[key] = {
                    XS = wrapper.Position.X.Scale,
                    X  = wrapper.Position.X.Offset,
                    YS = wrapper.Position.Y.Scale,
                    Y  = wrapper.Position.Y.Offset,
                }
            end
        end
        if next(btnPositions) then
            local encoded = HttpService:JSONEncode(btnPositions)
            if _writefile then
                _writefile(STACK_POS_FILE, encoded)
            end
        end
    end)
end

function loadStackPositionsNow()
    -- Restore saved floating-button positions; fall back to the default grid
    local saved = nil
    pcall(function()
        if _isfile and _isfile(STACK_POS_FILE) then
            local raw = _readfile(STACK_POS_FILE)
            if raw and raw ~= "" then
                local ok, dec = pcall(function() return HttpService:JSONDecode(raw) end)
                if ok and type(dec) == "table" then saved = dec end
            end
        end
    end)
    local applied = 0
    for i, def in ipairs(stackDefs) do
        local wrapper = stackWrappers[def.key]
        if wrapper then
            local p = saved and saved[def.key]
            if type(p) == "table" and tonumber(p.X) and tonumber(p.Y) then
                wrapper.Position = UDim2.new(tonumber(p.XS) or 0, tonumber(p.X) or 0,
                                             tonumber(p.YS) or 0, tonumber(p.Y) or 0)
            else
                wrapper.Position = getDefaultStackPos(i)
            end
            applied = applied + 1
        end
    end
    return applied > 0
end

function resetStackPositionsNow()
    pcall(function() if _delfile then _delfile(STACK_POS_FILE) end end)
    for i, def in ipairs(stackDefs) do
        local wrapper = stackWrappers[def.key]
        if wrapper then wrapper.Position = getDefaultStackPos(i) end
    end
end

-- ============================================================
-- PRESETS (unchanged)
-- ============================================================
Presets = {}
PRESET_FILE = "GreenDuelsPresets.json"
LAST_PRESET_FILE = "GreenDuelsLastPreset.json"

function buildPresetSnapshot() return {
    normalSpeed=State.normalSpeed, carrySpeed=State.carrySpeed,
    laggerSpeed=State.laggerSpeed, laggerCarrySpeed=State.laggerCarrySpeed,
    stealRadius=Steal.StealRadius, stealDuration=Steal.StealDuration,
    infJump=State.infJumpEnabled, antiRagdoll=State.antiRagdollEnabled,
    medusaCounter=State.medusaCounterEnabled, batCounter=State.batCounterEnabled,
    autoSteal=Steal.AutoStealEnabled,
    autoTP=State.autoTPEnabled, autoTPHeight=State.autoTPHeight,
} end
function savePresetsFile()
    local ok,enc=pcall(function() return HttpService:JSONEncode(Presets) end)
    if ok then pcall(function() _writefile(PRESET_FILE,enc) end) end
end
function loadPresetsFile()
    if not _isfile(PRESET_FILE) then return end
    local raw; pcall(function() raw=_readfile(PRESET_FILE) end)
    if raw then
        local ok,dec=pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and dec then Presets=dec end
    end
end
function saveLastPresetName(name)
    local ok,enc=pcall(function() return HttpService:JSONEncode({lastPreset=name}) end)
    if ok then pcall(function() _writefile(LAST_PRESET_FILE,enc) end) end
end
function loadLastPresetName()
    if not _isfile(LAST_PRESET_FILE) then return nil end
    local raw; pcall(function() raw=_readfile(LAST_PRESET_FILE) end)
    if raw then
        local ok,dec=pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and dec then return dec.lastPreset end
    end
    return nil
end

MOVE_KEYS={[Enum.KeyCode.W]=true,[Enum.KeyCode.A]=true,[Enum.KeyCode.S]=true,[Enum.KeyCode.D]=true,
    [Enum.KeyCode.Up]=true,[Enum.KeyCode.Left]=true,[Enum.KeyCode.Down]=true,[Enum.KeyCode.Right]=true}

Conns={autoSteal=nil,antiRag=nil,aimbot=nil,anchor={},progress=nil,batCounter=nil, autoTP=nil}
h, hrp = nil, nil
setInfJump, setAntiRag = nil, nil
setMedusaCounter, setAimbot, setAutoSwing = nil, nil, nil
setLagger, setLaggerCarry, setDropBrainrot, setInstaGrab = nil, nil, nil, nil
setNukeOpt, setRemoveAcc, setNoCam = nil, nil, nil
setupMedusaCounter, stopMedusaCounter = nil, nil
startAutoSteal, stopAutoSteal = nil, nil
saveConfig, loadConfig, runDrop, stopDrop, runTPDown = nil, nil, nil, nil, nil
requestSave = nil
startBatAimbot, stopBatAimbot, startBatCounter, stopBatCounter, setBatCounter = nil, nil, nil, nil, nil
stackBtnRefs={}; keybindBtnRefs={}

    local normalBox,carryBox,laggerBox,laggerCarryBox,uiScaleBox,buttonScaleBox,stealRadBox,stealDurBox,autoTPHeightBox,softStealSpeedBox,softStealRadiusBox
setHideButtonsToggle, setLockButtonsToggle = nil, nil
presetListFrame=nil; presetNameBox=nil; rebuildPresetList = nil
toggleSetters = {}
standDropBtn, jumpDropBtn = nil, nil -- stand removed; kept nil for compat

-- ============================================================
-- THEME COLORS (green)
-- ============================================================
C = {
    winBg=Color3.fromRGB(0,0,0), winBg2=Color3.fromRGB(6,6,6),
    winBorder=Color3.fromRGB(127, 127, 127),
    sidebarBg=Color3.fromRGB(0,0,0),
    sidebarDiv=Color3.fromRGB(52, 52, 52),
    topBg=Color3.fromRGB(4,12,7), topTitle=Color3.fromRGB(131, 131, 131),
    topSub=Color3.fromRGB(103, 103, 103),
    topBtn=Color3.fromRGB(64, 64, 64), topBtnHov=Color3.fromRGB(115, 115, 115),
    topDivider=Color3.fromRGB(52, 52, 52),
    tabBarBg=Color3.fromRGB(0,0,0), tabBarDiv=Color3.fromRGB(52, 52, 52),
    tabIdle=Color3.fromRGB(103, 103, 103), tabIdleHov=Color3.fromRGB(131, 131, 131),
    tabActive=Color3.fromRGB(192, 192, 192), tabActiveBg=Color3.fromRGB(8,30,15),
    tabUnderline=Color3.fromRGB(131, 131, 131),
    sectionTxt=Color3.fromRGB(131, 131, 131), sectionDiv=Color3.fromRGB(52, 52, 52),
    rowBg=Color3.fromRGB(0,0,0), rowBorder=Color3.fromRGB(52, 52, 52),
    rowLabel=Color3.fromRGB(235, 235, 235), rowSub=Color3.fromRGB(156, 156, 156),
    rowValue=Color3.fromRGB(131, 131, 131), rowHov=Color3.fromRGB(10,30,15),
    inputBg=Color3.fromRGB(6,18,10), inputBorder=Color3.fromRGB(64, 64, 64),
    inputFocus=Color3.fromRGB(131, 131, 131), inputTxt=Color3.fromRGB(207, 207, 207),
    pillOff=Color3.fromRGB(10,40,25), pillOn=Color3.fromRGB(131, 131, 131),
    dotOff=Color3.fromRGB(67, 67, 67), dotOn=Color3.fromRGB(10,30,15),
    pillBorder=Color3.fromRGB(58, 58, 58),
    modeBtnBg=Color3.fromRGB(6,18,10), modeBtnBrd=Color3.fromRGB(58, 58, 58),
    modeBtnTxt=Color3.fromRGB(103, 103, 103), modeBtnActBg=Color3.fromRGB(131, 131, 131),
    modeBtnActTx=Color3.fromRGB(10,30,15),
    chipBg=Color3.fromRGB(6,18,10), chipBorder=Color3.fromRGB(58, 58, 58),
    chipTxt=Color3.fromRGB(103, 103, 103),
    btnBg=Color3.fromRGB(8,22,15), btnBorder=Color3.fromRGB(58, 58, 58),
    btnTxt=Color3.fromRGB(235, 235, 235), btnHov=Color3.fromRGB(18,40,28),
    stackBg=Color3.fromRGB(8,22,15), stackBrd=Color3.fromRGB(64, 64, 64),
    stackTxt=Color3.fromRGB(235, 235, 235), stackActBg=Color3.fromRGB(97, 97, 97),
    stackActBrd=Color3.fromRGB(131, 131, 131), stackActTxt=Color3.fromRGB(255,255,255),
    stackDot=Color3.fromRGB(67, 67, 67), stackDotOn=Color3.fromRGB(131, 131, 131),
    infoBg=Color3.fromRGB(4,14,9), infoBrd=Color3.fromRGB(64, 64, 64),
    infoTxt=Color3.fromRGB(103, 103, 103), infoVal=Color3.fromRGB(131, 131, 131),
    infoFill=Color3.fromRGB(131, 131, 131), accent=Color3.fromRGB(131, 131, 131),
    accentDim=Color3.fromRGB(64, 64, 64), presetBg=Color3.fromRGB(6,18,10),
    presetBrd=Color3.fromRGB(64, 64, 64), presetLoad=Color3.fromRGB(131, 131, 131),
    presetDel=Color3.fromRGB(64, 64, 64), delBrd=Color3.fromRGB(97, 97, 97),
    lockOn=Color3.fromRGB(131, 131, 131), divider=Color3.fromRGB(52, 52, 52),
}

do
    local cleanupNames = {"VyseSlottedGUI","VyseAsireGUI","VyseAsireHubV4","VyseAsireHubV5","VyseAsireHubV5_1","AsireHubV5_1","AsireHubV5_2","LaitoHubV1","GreenDuelsV1"}
    for _,name in ipairs(cleanupNames) do
        pcall(function() local o=game:GetService("CoreGui"):FindFirstChild(name); if o then o:Destroy() end end)
        pcall(function() local o=LP:WaitForChild("PlayerGui"):FindFirstChild(name); if o then o:Destroy() end end)
    end
end

function mkCorner(p,r) local c=Instance.new("UICorner",p); local rr=tonumber(r) or 8; if rr>12 then rr=12 end; c.CornerRadius=UDim.new(0,rr); return c end
function mkStroke(p,col,th) local s=Instance.new("UIStroke",p); s.Color=col; s.Thickness=th or 1; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; return s end

-- ============================================================
-- AUTO TP (unchanged)
-- ============================================================
function _7upMovementModeActive()
    if not State then return false end
    return State.autoLeftEnabled == true
        or State.autoRightEnabled == true
        or State.speedToggled == true
        or (State.laggerMode ~= nil and State.laggerMode ~= 0)
end

function _7upCarryingNow()
    local ok, carrying = pcall(function()
        return isCurrentlyCarrying and isCurrentlyCarrying() == true
    end)
    return ok and carrying == true
end

function doAutoTPDown(force)
    -- Nunca faz TP Down automatico enquanto Auto Left/Right, Carry Mode,
    -- Lagger Mode ou Lagger Carry estao ligados: o player so anda.
    -- Excecao: segurando pet/brainrot, o TP Down sempre funciona.
    if not force and not _7upCarryingNow() and _7upMovementModeActive() then return end
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if not force then
        if hum.FloorMaterial ~= Enum.Material.Air then return end
        if hrp.Position.Y < State.autoTPHeight then return end
    end
    hrp.CFrame = CFrame.new(hrp.Position.X, -7, hrp.Position.Z) * CFrame.Angles(0, select(2, hrp.CFrame:ToEulerAnglesYXZ()), 0)
    hrp.AssemblyLinearVelocity = Vector3.zero
end

function startAutoTP()
    if State.autoTPConn then task.cancel(State.autoTPConn); State.autoTPConn = nil end
    if not State.autoTPEnabled then return end
    State.autoTPConn = task.spawn(function()
        while State.autoTPEnabled do
            task.wait(0.1)
            if _7upCarryingNow() or not _7upMovementModeActive() then
                pcall(function() doAutoTPDown(false) end)
            end
        end
        State.autoTPConn = nil
    end)
end

function stopAutoTP()
    State.autoTPEnabled = false
    State._autoTPPauseToken = (State._autoTPPauseToken or 0) + 1
    if State.autoTPConn then task.cancel(State.autoTPConn); State.autoTPConn = nil end
end

_G.AceStopAutoTPForAction = function()
    if not State.autoTPEnabled then return end

    -- Combat/drop actions only pause the worker. The user's ON setting stays
    -- untouched, so autosave cannot accidentally remember Auto TP as OFF.
    State._autoTPPauseToken = (State._autoTPPauseToken or 0) + 1
    local pauseToken = State._autoTPPauseToken
    if State.autoTPConn then task.cancel(State.autoTPConn); State.autoTPConn = nil end

    task.spawn(function()
        -- Let the action set its active flag after calling this helper.
        task.wait(0.12)
        while State.autoTPEnabled
            and pauseToken == State._autoTPPauseToken
            and ((_G.AceAntiDesyncAimbotOn == true) or (State._dropInProgress == true)) do
            task.wait(0.1)
        end
        if State.autoTPEnabled
            and pauseToken == State._autoTPPauseToken
            and not State.autoTPConn then
            startAutoTP()
        end
    end)
end

runTPDown = function()
    if stackBtnRefs and stackBtnRefs.tpDown then
        stackBtnRefs.tpDown.setOn(true)
        task.delay(0.22,function()
            if stackBtnRefs and stackBtnRefs.tpDown then stackBtnRefs.tpDown.setOn(false) end
        end)
    end
    pcall(function() doAutoTPDown(true) end)
end

-- ============================================================

-- ============================================================
-- ============================================================
-- CARRY DETECTION (decoupled; used by Soft Steal latch)
-- Detects steal/carry (WalkSpeed < 25 or Stealing attribute)
-- ============================================================
_acsWasCarrying = false
_acsCharacter = nil
_acsSpawnedAt = 0
_acsSawNormalSpeed = false
_acsLowSince = 0
function isCurrentlyCarrying()
    local char = LP.Character
    if not char then
        _acsWasCarrying = false
        return false
    end
    if char ~= _acsCharacter then
        _acsCharacter = char
        _acsSpawnedAt = tick()
        _acsSawNormalSpeed = false
        _acsLowSince = 0
        _acsWasCarrying = false
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local ws = hum and (hum.WalkSpeed or 16) or 16
    local bySpeed = false
    if ws >= 28 then
        _acsSawNormalSpeed = true
        _acsLowSince = 0
    elseif _acsSawNormalSpeed and tick() - _acsSpawnedAt >= 2 then
        if ws < 25 then
            if _acsLowSince == 0 then _acsLowSince = tick() end
            bySpeed = _acsWasCarrying or tick() - _acsLowSince >= 0.3
        else
            _acsLowSince = 0
            bySpeed = _acsWasCarrying and ws < 28
        end
    end
    local byAttr = false
    local ok, v = pcall(function() return LP:GetAttribute("Stealing") end)
    if ok and v == true then byAttr = true end
    local ok2, v2 = pcall(function() return char:GetAttribute("Stealing") end)
    if ok2 and v2 == true then byAttr = true end
    if not byAttr then
        for _, name in ipairs({"Carrying", "IsCarrying", "Grabbed", "Holding", "StealHold", "HasGrab"}) do
            local obj = char:FindFirstChild(name)
            if obj then
                if obj:IsA("BoolValue") and obj.Value then byAttr = true; break end
                if obj:IsA("ObjectValue") and obj.Value then byAttr = true; break end
                if obj:IsA("StringValue") and obj.Value ~= "" then byAttr = true; break end
            end
        end
    end
    _acsWasCarrying = bySpeed or byAttr
    return _acsWasCarrying
end

-- ============================================================
-- ANTI DIE / ANTI DROP (adaptado da source Noxa Anti Drop)
-- Mantém o toggle original da aba Main e não cria uma segunda UI.
-- ============================================================
AntiDie = {
    enabled = false,
    loop = nil,
    charConn = nil,
    rootPart = nil,
}

local function antiDieUpdateCharacter(char)
    if not AntiDie.enabled or not char then return end
    AntiDie.rootPart = char:WaitForChild("HumanoidRootPart", 5)
end

function startAntiDie()
    -- Evita conexões duplicadas ao ligar/recarregar o toggle.
    if AntiDie.loop then
        AntiDie.loop:Disconnect()
        AntiDie.loop = nil
    end
    if AntiDie.charConn then
        AntiDie.charConn:Disconnect()
        AntiDie.charConn = nil
    end

    AntiDie.enabled = true
    State.antiDieEnabled = true
    AntiDie.rootPart = nil

    if LP.Character then
        antiDieUpdateCharacter(LP.Character)
    end

    AntiDie.charConn = LP.CharacterAdded:Connect(function(char)
        if not AntiDie.enabled then return end
        task.defer(function()
            antiDieUpdateCharacter(char)
        end)
    end)

    -- Comportamento da Noxa Anti Drop:
    -- zera apenas a velocidade vertical descendente e estabiliza a inclinação.
    AntiDie.loop = RunService.PreSimulation:Connect(function()
        if not AntiDie.enabled then return end

        local char = LP.Character
        if not char then return end

        local root = AntiDie.rootPart
        if not root or not root.Parent or root.Parent ~= char then
            root = char:FindFirstChild("HumanoidRootPart")
            AntiDie.rootPart = root
        end
        if not root then return end

        local velocity = root.AssemblyLinearVelocity
        local currentCFrame = root.CFrame

        if velocity.Y < 0 then
            root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
        end

        local _, yaw, _ = currentCFrame:ToOrientation()
        root.CFrame = CFrame.new(currentCFrame.Position) * CFrame.Angles(0, yaw, 0)
    end)
end

function stopAntiDie()
    AntiDie.enabled = false
    State.antiDieEnabled = false

    if AntiDie.loop then
        AntiDie.loop:Disconnect()
        AntiDie.loop = nil
    end
    if AntiDie.charConn then
        AntiDie.charConn:Disconnect()
        AntiDie.charConn = nil
    end

    AntiDie.rootPart = nil
end


-- Anti-Fling Shield from the supplied source. Normal movement is left alone;
-- only launch velocity above the source's threshold is stabilized.
AntiFlingShield = {
    enabled = false,
    loop = nil,
    velocityThreshold = 80,
}

function _afsStabilizeRoot(root)
    if not root or not root.Parent then return end
    local velocity
    local ok = pcall(function() velocity = root.AssemblyLinearVelocity end)
    if not ok or typeof(velocity) ~= "Vector3" then
        local legacyOk
        legacyOk, velocity = pcall(function() return root.Velocity end)
        if not legacyOk or typeof(velocity) ~= "Vector3" then return end
    end
    if velocity.Magnitude <= AntiFlingShield.velocityThreshold then return end

    local stabilized = Vector3.new(0, velocity.Y, 0)
    pcall(function() root.AssemblyLinearVelocity = stabilized end)
    pcall(function() root.AssemblyAngularVelocity = Vector3.zero end)
    pcall(function() root.Velocity = stabilized end)
    pcall(function() root.RotVelocity = Vector3.zero end)
end

function startAntiFlingShield()
    AntiFlingShield.enabled = true
    State.antiFlingShieldEnabled = true
    if AntiFlingShield.loop then AntiFlingShield.loop:Disconnect() end
    AntiFlingShield.loop = RunService.Heartbeat:Connect(function()
        if not AntiFlingShield.enabled then return end
        local char = LP.Character
        _afsStabilizeRoot(char and char:FindFirstChild("HumanoidRootPart"))
    end)
end

function stopAntiFlingShield()
    AntiFlingShield.enabled = false
    State.antiFlingShieldEnabled = false
    if AntiFlingShield.loop then
        AntiFlingShield.loop:Disconnect()
        AntiFlingShield.loop = nil
    end
end

-- DROP METHODS (original Jump Drop — Stand removed)
-- ============================================================
_wfConns = {}
dropActive = false
DROP_ASCEND_DURATION = 0.2
DROP_ASCEND_SPEED = 150
_dropConn = nil

function runJumpDrop()
    if dropActive then return end
    if _G.AceStopAutoTPForAction then pcall(_G.AceStopAutoTPForAction) end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")

    dropActive = true
    State._dropInProgress = true
    State._dropSuppressGrabUntil = tick() + 1.0
    if stackBtnRefs and stackBtnRefs.drop then stackBtnRefs.drop.setOn(true) end

    -- Stop walk mover immediately so walking/carry speed can't cancel the burst
    pcall(function()
        if hum then
            hum:Move(Vector3.zero, false)
            hum.AutoRotate = true
        end
        for _, inst in ipairs(root:GetChildren()) do
            if inst:IsA("LinearVelocity") or inst:IsA("BodyVelocity") or inst:IsA("VectorForce") then
                inst.Enabled = false
            end
        end
    end)

    local t0 = tick()
    if _dropConn then _dropConn:Disconnect(); _dropConn = nil end
    -- RenderStepped so we win over the walk Heartbeat mover
    _dropConn = RunService.RenderStepped:Connect(function()
        local cchar = LP.Character
        local r = cchar and cchar:FindFirstChild("HumanoidRootPart")
        if not r then
            if _dropConn then _dropConn:Disconnect(); _dropConn = nil end
            dropActive = false
            State._dropInProgress = false
            if stackBtnRefs and stackBtnRefs.drop then stackBtnRefs.drop.setOn(false) end
            return
        end
        if not dropActive then
            if _dropConn then _dropConn:Disconnect(); _dropConn = nil end
            State._dropInProgress = false
            if stackBtnRefs and stackBtnRefs.drop then stackBtnRefs.drop.setOn(false) end
            return
        end

        -- Keep walk boosters off during drop
        pcall(function()
            for _, inst in ipairs(r:GetChildren()) do
                if inst:IsA("LinearVelocity") then
                    inst.Enabled = false
                    if inst.PlaneVelocity ~= nil then
                        inst.PlaneVelocity = Vector2.zero
                    end
                end
            end
        end)

        if tick() - t0 >= DROP_ASCEND_DURATION then
            if _dropConn then _dropConn:Disconnect(); _dropConn = nil end
            pcall(function()
                local rp = RaycastParams.new()
                rp.FilterDescendantsInstances = {cchar}
                rp.FilterType = Enum.RaycastFilterType.Exclude
                local rr = workspace:Raycast(r.Position, Vector3.new(0, -2000, 0), rp)
                if rr then
                    local hum2 = cchar:FindFirstChildOfClass("Humanoid")
                    local off = ((hum2 and hum2.HipHeight) or 2) + (r.Size.Y / 2)
                    r.CFrame = CFrame.new(r.Position.X, rr.Position.Y + off, r.Position.Z)
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.AssemblyAngularVelocity = Vector3.zero
                    if r.Velocity then r.Velocity = Vector3.zero end
                end
            end)
            dropActive = false
            State._dropInProgress = false
            State._dropSuppressGrabUntil = tick() + 0.6
            if stackBtnRefs and stackBtnRefs.drop then stackBtnRefs.drop.setOn(false) end
            return
        end

        -- Force upward burst (works while walking / carrying)
        r.AssemblyLinearVelocity = Vector3.new(0, DROP_ASCEND_SPEED, 0)
        r.AssemblyAngularVelocity = Vector3.zero
        if r.Velocity then
            r.Velocity = Vector3.new(0, DROP_ASCEND_SPEED, 0)
        end
    end)
end

function runSelectedDrop()
    runJumpDrop()
end

runDrop = runSelectedDrop

LP.CharacterRemoving:Connect(function()
    dropActive = false
    State._dropInProgress = false
    for _, c in ipairs(_wfConns) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect()
        elseif type(c) == "thread" then pcall(coroutine.close, c) end
    end
    _wfConns = {}
    if _dropConn then _dropConn:Disconnect(); _dropConn = nil end
    stopAntiRagdollNew()
end)

stopDrop = function()
    dropActive = false
    State._dropInProgress = false
    State._dropSuppressGrabUntil = tick() + 0.45
    if _dropConn then _dropConn:Disconnect(); _dropConn = nil end
    for _, c in ipairs(_wfConns) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect()
        elseif type(c) == "thread" then pcall(coroutine.close, c) end
    end
    _wfConns = {}
    if stackBtnRefs.drop then stackBtnRefs.drop.setOn(false) end
end

-- ============================================================
-- HEADLESS, KORBLOX, OUTFIT CHANGER FUNCTIONS (green theme applied)
-- ============================================================
(function()
HEADLESS_MESH_ID = "rbxassetid://1095708"
KORBLOX_MESH_ID = "rbxassetid://101851696"
KORBLOX_TEXTURE_ID = "rbxassetid://101851254"
DARK_GREY_COLOR = Color3.fromRGB(64, 64, 64)

-- Outfit 1 IDs
OUTFIT1_HEAD_MESH = "rbxassetid://137685008029440"
OUTFIT1_SHIRT_ID = 6281968058
OUTFIT1_PANTS_ID = 1073888653
-- Try Hard 1 IDs
OUTFIT2_HEAD_MESH = "rbxassetid://11711107876"
OUTFIT2_SHIRT_ID = 14101026303
OUTFIT2_PANTS_ID = 4620736485
-- Venom Fit IDs
OUTFIT3_SHIRT_ID = 13950309240
OUTFIT3_PANTS_ID = 12421776639

-- Headless
function applyHeadlessToChar(char, enabled)
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    if enabled then
        head.Transparency = 1
        head.CanCollide = false
        local face = head:FindFirstChild("face")
        if face then face:Destroy() end

        local mesh = head:FindFirstChild("HeadlessMesh")
        if not mesh then
            mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = HEADLESS_MESH_ID
            mesh.Scale = Vector3.new(0.001, 0.001, 0.001)
            mesh.Name = "HeadlessMesh"
            mesh.Parent = head
        end

        if not head:GetAttribute("HeadlessHooked") then
            head:SetAttribute("HeadlessHooked", true)
            head:GetPropertyChangedSignal("Transparency"):Connect(function()
                if head:GetAttribute("HeadlessHooked") and head.Transparency ~= 1 then
                    head.Transparency = 1
                end
            end)
            head.ChildAdded:Connect(function(child)
                if head:GetAttribute("HeadlessHooked") and child.Name == "face" and child:IsA("Decal") then
                    child:Destroy()
                end
            end)
        end
    else
        head.Transparency = 0
        head.CanCollide = true
        head:SetAttribute("HeadlessHooked", nil)
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("SpecialMesh") and child.Name == "HeadlessMesh" then
                child:Destroy()
            end
        end
        local face = head:FindFirstChild("face")
        if not face then
            face = Instance.new("Decal")
            face.Name = "face"
            face.Texture = "rbxassetid://2002749760"
            face.Parent = head
        end
    end
end

-- Korblox
function applyKorbloxToChar(char, enabled)
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if enabled then
        if humanoid.RigType == Enum.HumanoidRigType.R6 then
            local rightLeg = char:FindFirstChild("Right Leg")
            if rightLeg then
                for _, child in ipairs(rightLeg:GetChildren()) do
                    if child:IsA("CharacterMesh") then
                        child:Destroy()
                    end
                end
                local mesh = rightLeg:FindFirstChild("KorbloxMesh")
                if not mesh then
                    for _, child in ipairs(rightLeg:GetChildren()) do
                        if child:IsA("SpecialMesh") then
                            child:Destroy()
                        end
                    end
                    mesh = Instance.new("SpecialMesh")
                    mesh.MeshType = Enum.MeshType.FileMesh
                    mesh.MeshId = KORBLOX_MESH_ID
                    mesh.TextureId = KORBLOX_TEXTURE_ID
                    mesh.Scale = Vector3.new(1, 1, 1)
                    mesh.Name = "KorbloxMesh"
                    mesh.Parent = rightLeg
                end
                rightLeg.Color = DARK_GREY_COLOR
                if not rightLeg:GetAttribute("KorbloxHooked") then
                    rightLeg:SetAttribute("KorbloxHooked", true)
                    rightLeg:GetPropertyChangedSignal("Color"):Connect(function()
                        if rightLeg:GetAttribute("KorbloxHooked") and rightLeg.Color ~= DARK_GREY_COLOR then
                            rightLeg.Color = DARK_GREY_COLOR
                        end
                    end)
                end
            end
        elseif humanoid.RigType == Enum.HumanoidRigType.R15 then
            local rightUpperLeg = char:FindFirstChild("RightUpperLeg")
            if rightUpperLeg then
                rightUpperLeg.Transparency = 1
                local rightLowerLeg = char:FindFirstChild("RightLowerLeg")
                local rightFoot = char:FindFirstChild("RightFoot")
                if rightLowerLeg then rightLowerLeg.Transparency = 1 end
                if rightFoot then rightFoot.Transparency = 1 end

                local korbloxLeg = char:FindFirstChild("KorbloxLeg")
                if not korbloxLeg then
                    korbloxLeg = Instance.new("Part")
                    korbloxLeg.Name = "KorbloxLeg"
                    korbloxLeg.Size = Vector3.new(1, 2, 1)
                    korbloxLeg.Anchored = false
                    korbloxLeg.CanCollide = false
                    korbloxLeg.Color = DARK_GREY_COLOR
                    korbloxLeg.Parent = char

                    local mesh = Instance.new("SpecialMesh")
                    mesh.MeshType = Enum.MeshType.FileMesh
                    mesh.MeshId = KORBLOX_MESH_ID
                    mesh.TextureId = KORBLOX_TEXTURE_ID
                    mesh.Scale = Vector3.new(1, 1, 1)
                    mesh.Name = "KorbloxMesh"
                    mesh.Parent = korbloxLeg

                    local weld = Instance.new("Weld")
                    weld.Part0 = rightUpperLeg
                    weld.Part1 = korbloxLeg
                    weld.C0 = CFrame.new(0, -0.8, 0)
                    weld.Name = "KorbloxWeld"
                    weld.Parent = korbloxLeg
                end
            end
        end
    else
        if humanoid.RigType == Enum.HumanoidRigType.R6 then
            local rightLeg = char:FindFirstChild("Right Leg")
            if rightLeg then
                rightLeg:SetAttribute("KorbloxHooked", nil)
                for _, child in ipairs(rightLeg:GetChildren()) do
                    if child:IsA("SpecialMesh") and child.Name == "KorbloxMesh" then
                        child:Destroy()
                    end
                end
                rightLeg.Color = Color3.fromRGB(255, 255, 255)
            end
        elseif humanoid.RigType == Enum.HumanoidRigType.R15 then
            local rightUpperLeg = char:FindFirstChild("RightUpperLeg")
            if rightUpperLeg then
                rightUpperLeg.Transparency = 0
                local rightLowerLeg = char:FindFirstChild("RightLowerLeg")
                local rightFoot = char:FindFirstChild("RightFoot")
                if rightLowerLeg then rightLowerLeg.Transparency = 0 end
                if rightFoot then rightFoot.Transparency = 0 end
                local korbloxLeg = char:FindFirstChild("KorbloxLeg")
                if korbloxLeg then korbloxLeg:Destroy() end
            end
        end
    end
end

-- Outfit 1
function applyOutfit1ToChar(char)
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head then
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("SpecialMesh") and child.Name ~= "HeadlessMesh" then
                child:Destroy()
            end
        end
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = OUTFIT1_HEAD_MESH
        mesh.Scale = Vector3.new(1, 1, 1)
        mesh.Name = "OutfitHeadMesh"
        mesh.Parent = head
        head.Transparency = 0
        head.CanCollide = true
    end

    local shirt = char:FindFirstChildOfClass("Shirt")
    if not shirt then
        shirt = Instance.new("Shirt")
        shirt.Parent = char
    end
    shirt.ShirtTemplate = "rbxassetid://" .. tostring(OUTFIT1_SHIRT_ID)

    local pants = char:FindFirstChildOfClass("Pants")
    if not pants then
        pants = Instance.new("Pants")
        pants.Parent = char
    end
    pants.PantsTemplate = "rbxassetid://" .. tostring(OUTFIT1_PANTS_ID)

    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Accessory") then
            child:Destroy()
        end
    end

    local redColor = Color3.fromRGB(255, 0, 0)
    local blackColor = Color3.fromRGB(0, 0, 0)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if part.Name == "Head" or part.Name:find("Torso") or part.Name:find("Arm") then
                part.Color = redColor
            elseif part.Name:find("Leg") then
                part.Color = blackColor
            end
        end
    end
end

-- Try Hard 1 Fit
function applyOutfit2ToChar(char)
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head then
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("SpecialMesh") and child.Name ~= "HeadlessMesh" then
                child:Destroy()
            end
        end
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = OUTFIT2_HEAD_MESH
        mesh.Scale = Vector3.new(1, 1, 1)
        mesh.Name = "OutfitHeadMesh"
        mesh.Parent = head
        head.Transparency = 0
        head.CanCollide = true
    end

    local shirt = char:FindFirstChildOfClass("Shirt")
    if not shirt then
        shirt = Instance.new("Shirt")
        shirt.Parent = char
    end
    shirt.ShirtTemplate = "rbxassetid://" .. tostring(OUTFIT2_SHIRT_ID)

    local pants = char:FindFirstChildOfClass("Pants")
    if not pants then
        pants = Instance.new("Pants")
        pants.Parent = char
    end
    pants.PantsTemplate = "rbxassetid://" .. tostring(OUTFIT2_PANTS_ID)

    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Accessory") then
            child:Destroy()
        end
    end
end

-- Venom Fit
function applyOutfit3ToChar(char)
    if not char then return end
    local shirt = char:FindFirstChildOfClass("Shirt")
    if not shirt then
        shirt = Instance.new("Shirt")
        shirt.Parent = char
    end
    shirt.ShirtTemplate = "rbxassetid://" .. tostring(OUTFIT3_SHIRT_ID)

    local pants = char:FindFirstChildOfClass("Pants")
    if not pants then
        pants = Instance.new("Pants")
        pants.Parent = char
    end
    pants.PantsTemplate = "rbxassetid://" .. tostring(OUTFIT3_PANTS_ID)

    local blackColor = Color3.fromRGB(10, 10, 10)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Color = blackColor
        end
    end
end

-- Custom Skins variants supplied by the user. Both use the 7UP hat; each
-- variant keeps its own resolved asset cache so switching is immediate.
CUSTOM_SKIN_VARIANTS = {
    [1] = {
        name = "MAY SKIN",
        hatId = "127854264346577",
        shirtId = 10692517352,
        pantsId = 6294855872,
        headId = 101106043267082,
        bodyColor = Color3.fromRGB(56, 56, 56),
    },
    [2] = {
        name = "BART SKIN",
        hatId = "127854264346577",
        shirtId = 135553740919809,
        pantsId = 5309277694,
        headId = 18913474191,
        bodyColor = Color3.fromRGB(245, 205, 45),
    },
}
CUSTOM_SKIN_HAT_ID = CUSTOM_SKIN_VARIANTS[1].hatId
CUSTOM_SKIN_SHIRT_ID = CUSTOM_SKIN_VARIANTS[1].shirtId
CUSTOM_SKIN_PANTS_ID = CUSTOM_SKIN_VARIANTS[1].pantsId
CUSTOM_SKIN_HEAD_ID = CUSTOM_SKIN_VARIANTS[1].headId
CUSTOM_SKIN_TAG = "SevenUpCustomSkinItem"
CUSTOM_SKIN_SNAPSHOT_ATTR = "SevenUpCustomSkinSnapshot"
CUSTOM_SKIN_SHIRT_ATTR = "SevenUpOriginalShirt"
CUSTOM_SKIN_PANTS_ATTR = "SevenUpOriginalPants"

CustomSkinAssetCache = {
    [1] = {shirtTemplate=nil, pantsTemplate=nil, hatTemplate=nil, lastAttempt=0},
    [2] = {shirtTemplate=nil, pantsTemplate=nil, hatTemplate=nil, lastAttempt=0},
}
CustomSkinAssets = CustomSkinAssetCache[1]
CustomSkinSnapshots = setmetatable({}, {__mode = "k"})
_G.SevenUpCustomSkinDescriptions = _G.SevenUpCustomSkinDescriptions or setmetatable({}, {__mode = "k"})
CustomSkinDescriptions = _G.SevenUpCustomSkinDescriptions
CUSTOM_SKIN_GREEN = CUSTOM_SKIN_VARIANTS[1].bodyColor

function syncCustomSkinVariant(variantIndex)
    variantIndex = tonumber(variantIndex) == 2 and 2 or 1
    State.customSkinVariant = variantIndex
    local variant = CUSTOM_SKIN_VARIANTS[variantIndex]
    CUSTOM_SKIN_HAT_ID = variant.hatId
    CUSTOM_SKIN_SHIRT_ID = variant.shirtId
    CUSTOM_SKIN_PANTS_ID = variant.pantsId
    CUSTOM_SKIN_HEAD_ID = variant.headId
    CUSTOM_SKIN_GREEN = variant.bodyColor
    CustomSkinAssets = CustomSkinAssetCache[variantIndex]
    return variant
end

syncCustomSkinVariant(State.customSkinVariant)

function getCustomSkinAccessoryProperty()
    local property = "HatAccessory"
    pcall(function()
        local info = MarketplaceService:GetProductInfo(tonumber(CUSTOM_SKIN_HAT_ID))
        local propertyByType = {
            [8] = "HatAccessory", [41] = "HairAccessory", [42] = "FaceAccessory",
            [43] = "NeckAccessory", [44] = "ShouldersAccessory", [45] = "FrontAccessory",
            [46] = "BackAccessory", [47] = "WaistAccessory",
        }
        property = propertyByType[tonumber(info.AssetTypeId)] or property
        _G._K7CustomSkinHatName = tostring(info.Name or "")
    end)
    return property
end

function appendCustomSkinAccessory(description)
    local property = getCustomSkinAccessoryProperty()
    local ok = pcall(function()
        local current = tostring(description[property] or "")
        local found = false
        for id in current:gmatch("[^,]+") do
            if id:gsub("%s+", "") == CUSTOM_SKIN_HAT_ID then found = true; break end
        end
        if not found then
            description[property] = current == "" and CUSTOM_SKIN_HAT_ID
                or (current .. "," .. CUSTOM_SKIN_HAT_ID)
        end
    end)
    if not ok then
        local current = tostring(description.HatAccessory or "")
        if not current:find(CUSTOM_SKIN_HAT_ID, 1, true) then
            description.HatAccessory = current == "" and CUSTOM_SKIN_HAT_ID
                or (current .. "," .. CUSTOM_SKIN_HAT_ID)
        end
    end
end

CUSTOM_SKIN_ACCESSORY_PROPERTIES = {
    "HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory",
    "ShouldersAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory",
}

function stripCustomSkinAccessory(description)
    if not description then return end
    for _, property in ipairs(CUSTOM_SKIN_ACCESSORY_PROPERTIES) do
        pcall(function()
            if property == "HatAccessory" or property == "HairAccessory" then
                description[property] = ""
                return
            end
            local kept = {}
            for id in tostring(description[property] or ""):gmatch("[^,]+") do
                local clean = id:gsub("%s+", "")
                if clean ~= "" and clean ~= CUSTOM_SKIN_HAT_ID then
                    table.insert(kept, clean)
                end
            end
            description[property] = table.concat(kept, ",")
        end)
    end
end

function applyCustomSkinGreen(char, enabled)
    if not char then return end
    local bodyColors = char:FindFirstChildOfClass("BodyColors")
    local colorProperties = {"HeadColor3","LeftArmColor3","LeftLegColor3","RightArmColor3","RightLegColor3","TorsoColor3"}
    if bodyColors then
        for _, property in ipairs(colorProperties) do
            local attribute = "SevenUpOriginal" .. property
            if enabled then
                if bodyColors:GetAttribute(attribute) == nil then
                    bodyColors:SetAttribute(attribute, bodyColors[property])
                end
                bodyColors[property] = CUSTOM_SKIN_GREEN
            else
                local original = bodyColors:GetAttribute(attribute)
                if typeof(original) == "Color3" then bodyColors[property] = original end
                bodyColors:SetAttribute(attribute, nil)
            end
        end
    end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local attribute = "SevenUpOriginalBodyColor"
            if enabled then
                if part:GetAttribute(attribute) == nil then part:SetAttribute(attribute, part.Color) end
                part.Color = CUSTOM_SKIN_GREEN
            else
                local original = part:GetAttribute(attribute)
                if typeof(original) == "Color3" then part.Color = original end
                part:SetAttribute(attribute, nil)
            end
        end
    end
end

function absorbCustomSkinAssets(root)
    if not root then return end
    local shirt = root:IsA("Shirt") and root or root:FindFirstChildWhichIsA("Shirt", true)
    local pants = root:IsA("Pants") and root or root:FindFirstChildWhichIsA("Pants", true)
    local hat = root:IsA("Accessory") and root or root:FindFirstChildWhichIsA("Accessory", true)
    if shirt and shirt.ShirtTemplate ~= "" then
        CustomSkinAssets.shirtTemplate = shirt.ShirtTemplate
    end
    if pants and pants.PantsTemplate ~= "" then
        CustomSkinAssets.pantsTemplate = pants.PantsTemplate
    end
    if hat and not CustomSkinAssets.hatTemplate then
        _G._K7CustomSkinHatName = hat.Name
        CustomSkinAssets.hatTemplate = hat:Clone()
        CustomSkinAssets.hatTemplate.Parent = nil
    end
end

function loadCustomSkinAssetObject(assetId)
    local objects = nil
    pcall(function()
        objects = game:GetObjects("rbxassetid://" .. tostring(assetId))
    end)
    if type(objects) == "table" then
        for _, object in ipairs(objects) do
            absorbCustomSkinAssets(object)
        end
        for _, object in ipairs(objects) do
            pcall(function() object:Destroy() end)
        end
    end
    if not CustomSkinAssets.hatTemplate and tostring(assetId) == CUSTOM_SKIN_HAT_ID then
        local container = nil
        pcall(function() container = InsertService:LoadAsset(tonumber(assetId)) end)
        if container then
            absorbCustomSkinAssets(container)
            container:Destroy()
        end
    end
end

function resolveCustomSkinAssets()
    if CustomSkinAssets.shirtTemplate
        and CustomSkinAssets.pantsTemplate
        and CustomSkinAssets.hatTemplate then
        return CustomSkinAssets
    end
    local now = tick()
    if now - (CustomSkinAssets.lastAttempt or 0) < 20 then
        return CustomSkinAssets
    end
    CustomSkinAssets.lastAttempt = now

    -- A HumanoidDescription resolves catalog clothing IDs to their real
    -- templates, which is more reliable than using a catalog ID as a texture.
    local previewModel = nil
    pcall(function()
        local description = Instance.new("HumanoidDescription")
        description.Shirt = CUSTOM_SKIN_SHIRT_ID
        description.Pants = CUSTOM_SKIN_PANTS_ID
        description.Head = CUSTOM_SKIN_HEAD_ID
        appendCustomSkinAccessory(description)
        previewModel = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
        description:Destroy()
    end)
    if previewModel then
        absorbCustomSkinAssets(previewModel)
        previewModel:Destroy()
    end

    if not CustomSkinAssets.shirtTemplate then loadCustomSkinAssetObject(CUSTOM_SKIN_SHIRT_ID) end
    if not CustomSkinAssets.pantsTemplate then loadCustomSkinAssetObject(CUSTOM_SKIN_PANTS_ID) end
    if not CustomSkinAssets.hatTemplate then loadCustomSkinAssetObject(CUSTOM_SKIN_HAT_ID) end

    CustomSkinAssets.shirtTemplate = CustomSkinAssets.shirtTemplate
        or ("rbxassetid://" .. tostring(CUSTOM_SKIN_SHIRT_ID))
    CustomSkinAssets.pantsTemplate = CustomSkinAssets.pantsTemplate
        or ("rbxassetid://" .. tostring(CUSTOM_SKIN_PANTS_ID))
    return CustomSkinAssets
end

function removeTaggedCustomSkinItems(char)
    if not char then return end
    for _, child in ipairs(char:GetChildren()) do
        if child:GetAttribute(CUSTOM_SKIN_TAG) == true then
            child:Destroy()
        end
    end
end

function snapshotCustomSkinClothing(char)
    if CustomSkinSnapshots[char] then return CustomSkinSnapshots[char] end
    local snapshot = {shirts = {}, pants = {}, accessoryNames = {}}
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Accessory") and child:GetAttribute(CUSTOM_SKIN_TAG) ~= true then
            local name = tostring(child.Name)
            snapshot.accessoryNames[name] = (snapshot.accessoryNames[name] or 0) + 1
        end
    end
    _G._K7OriginalAccessoryNames = _G._K7OriginalAccessoryNames
        or setmetatable({}, {__mode = "k"})
    _G._K7OriginalAccessoryNames[char] = snapshot.accessoryNames
    if char:GetAttribute(CUSTOM_SKIN_SNAPSHOT_ATTR) == true then
        local oldShirt = char:GetAttribute(CUSTOM_SKIN_SHIRT_ATTR)
        local oldPants = char:GetAttribute(CUSTOM_SKIN_PANTS_ATTR)
        if type(oldShirt) == "string" and oldShirt ~= "" then
            local shirt = Instance.new("Shirt")
            shirt.ShirtTemplate = oldShirt
            table.insert(snapshot.shirts, shirt)
        end
        if type(oldPants) == "string" and oldPants ~= "" then
            local pants = Instance.new("Pants")
            pants.PantsTemplate = oldPants
            table.insert(snapshot.pants, pants)
        end
    else
        local savedShirt, savedPants = "", ""
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Shirt") and child:GetAttribute(CUSTOM_SKIN_TAG) ~= true then
                table.insert(snapshot.shirts, child:Clone())
                if savedShirt == "" then savedShirt = child.ShirtTemplate end
            elseif child:IsA("Pants") and child:GetAttribute(CUSTOM_SKIN_TAG) ~= true then
                table.insert(snapshot.pants, child:Clone())
                if savedPants == "" then savedPants = child.PantsTemplate end
            end
        end
        char:SetAttribute(CUSTOM_SKIN_SNAPSHOT_ATTR, true)
        char:SetAttribute(CUSTOM_SKIN_SHIRT_ATTR, savedShirt)
        char:SetAttribute(CUSTOM_SKIN_PANTS_ATTR, savedPants)
    end
    CustomSkinSnapshots[char] = snapshot
    return snapshot
end

function clearCharacterClothing(char)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Shirt") or child:IsA("Pants") then
            child:Destroy()
        end
    end
end

function attachCustomSkinHat(char, assets)
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not humanoid then return end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Accessory") then
            if child:GetAttribute(CUSTOM_SKIN_TAG) == true then return end
            local sourceId = nil
            pcall(function() sourceId = child.SourceAssetId end)
            local matchingName = assets.hatTemplate and child.Name == assets.hatTemplate.Name
            if tostring(sourceId or "") == CUSTOM_SKIN_HAT_ID or matchingName then
                child:SetAttribute(CUSTOM_SKIN_TAG, true)
                return
            end
        end
    end
    if not assets.hatTemplate then return end
    local hat = assets.hatTemplate:Clone()
    hat.Name = "SevenUpCustomSkinHat"
    hat:SetAttribute(CUSTOM_SKIN_TAG, true)
    for _, child in ipairs(hat:GetDescendants()) do
        if child:IsA("Script") or child:IsA("LocalScript") then child:Destroy() end
        if child:IsA("BasePart") then
            child.Anchored = false
            child.CanCollide = false
            child.Massless = true
        end
    end
    local added = pcall(function() humanoid:AddAccessory(hat) end)
    if not added or not hat.Parent then hat.Parent = char end

    -- Some executors parent catalog accessories without creating the weld.
    -- Repair it from matching attachments so the hat is visible on both rigs.
    local handle = hat:FindFirstChild("Handle") or hat:FindFirstChildWhichIsA("BasePart", true)
    if handle and not handle:FindFirstChild("AccessoryWeld") then
        local handleAttachment = handle:FindFirstChildWhichIsA("Attachment")
        local bodyAttachment = nil
        if handleAttachment then
            for _, item in ipairs(char:GetDescendants()) do
                if item:IsA("Attachment") and item.Name == handleAttachment.Name
                    and not item:IsDescendantOf(hat) then
                    bodyAttachment = item
                    break
                end
            end
        end
        if handleAttachment and bodyAttachment and bodyAttachment.Parent:IsA("BasePart") then
            handle.CFrame = bodyAttachment.WorldCFrame * handleAttachment.CFrame:Inverse()
            local weld = Instance.new("WeldConstraint")
            weld.Name = "SevenUpSkinWeld"
            weld.Part0 = handle
            weld.Part1 = bodyAttachment.Parent
            weld.Parent = handle
        end
    end
end

function applyCustomSkinDescription(char, assets)
    syncCustomSkinVariant(State.customSkinVariant)
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    if not CustomSkinDescriptions[char] then
        local original = nil
        pcall(function() original = humanoid:GetAppliedDescription():Clone() end)
        if original then CustomSkinDescriptions[char] = original end
    end
    local original = CustomSkinDescriptions[char]
    if not original then return false end

    local description = original:Clone()
    description.Shirt = CUSTOM_SKIN_SHIRT_ID
    description.Pants = CUSTOM_SKIN_PANTS_ID
    description.Head = CUSTOM_SKIN_HEAD_ID
    description.HeadColor = CUSTOM_SKIN_GREEN
    description.LeftArmColor = CUSTOM_SKIN_GREEN
    description.LeftLegColor = CUSTOM_SKIN_GREEN
    description.RightArmColor = CUSTOM_SKIN_GREEN
    description.RightLegColor = CUSTOM_SKIN_GREEN
    description.TorsoColor = CUSTOM_SKIN_GREEN
    if State.removeAcc then
        stripCustomSkinAccessory(description)
    else
        appendCustomSkinAccessory(description)
    end
    local applied = pcall(function() humanoid:ApplyDescription(description) end)
    description:Destroy()
    if not applied then return false end

    local foundHat = false
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Shirt") or child:IsA("Pants") then
            child:SetAttribute(CUSTOM_SKIN_TAG, true)
        elseif child:IsA("Accessory") then
            local sourceId = nil
            pcall(function() sourceId = child.SourceAssetId end)
            local matchingName = assets.hatTemplate and child.Name == assets.hatTemplate.Name
            if tostring(sourceId or "") == CUSTOM_SKIN_HAT_ID or matchingName then
                child:SetAttribute(CUSTOM_SKIN_TAG, true)
                foundHat = true
            end
        end
    end
    if not State.removeAcc and not foundHat then attachCustomSkinHat(char, assets) end
    if State.removeAcc then removeCharAccessories(char) end
    return true
end

function restoreCustomSkinDescription(char)
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local original = char and CustomSkinDescriptions[char]
    if not humanoid or not original then return false end
    local restored = pcall(function() humanoid:ApplyDescription(original) end)
    if restored then CustomSkinDescriptions[char] = nil end
    return restored
end

CUSTOM_SKIN_APPLIED_ATTR = "SevenUpSkinAppliedVariant"
_G._K7SkinApplyBusy = false
_G._K7SkinLastApply = 0

-- force = true ignora o cache e reaplica de verdade (usado pelo reparo).
function applyCustomSkinToChar(char, force)
    if not char then return end
    if _G._K7SkinApplyBusy then return end
    local variant = tonumber(State.customSkinVariant) == 2 and 2 or 1
    -- Ja aplicada: sair imediatamente. Sem isso o script reaplicava a
    -- HumanoidDescription varias vezes por segundo e travava a tela inteira.
    if not force and char:GetAttribute(CUSTOM_SKIN_APPLIED_ATTR) == variant then return end
    local now = tick()
    if not force and now - (_G._K7SkinLastApply or 0) < 1.5 then return end
    _G._K7SkinApplyBusy = true
    _G._K7SkinLastApply = now
    local ok = pcall(function()
        syncCustomSkinVariant(variant)
        local assets = resolveCustomSkinAssets()
        snapshotCustomSkinClothing(char)
        if not applyCustomSkinDescription(char, assets) then
            clearCharacterClothing(char)

            local shirt = Instance.new("Shirt")
            shirt.Name = "SevenUpCustomSkinShirt"
            shirt.ShirtTemplate = assets.shirtTemplate
            shirt:SetAttribute(CUSTOM_SKIN_TAG, true)
            shirt.Parent = char

            local pants = Instance.new("Pants")
            pants.Name = "SevenUpCustomSkinPants"
            pants.PantsTemplate = assets.pantsTemplate
            pants:SetAttribute(CUSTOM_SKIN_TAG, true)
            pants.Parent = char

            if not State.removeAcc then attachCustomSkinHat(char, assets) end
        end
        applyCustomSkinGreen(char, true)
        if State.removeAcc then removeCharAccessories(char) end
    end)
    if ok then char:SetAttribute(CUSTOM_SKIN_APPLIED_ATTR, variant) end
    _G._K7SkinApplyBusy = false
end

function restoreCustomSkinFromChar(char)
    if not char then return end
    -- Nada aplicado: nao encostar no avatar (evita "sumir" a skin original).
    if char:GetAttribute(CUSTOM_SKIN_APPLIED_ATTR) == nil
        and not CustomSkinSnapshots[char]
        and not CustomSkinDescriptions[char] then
        return
    end
    local snapshot = CustomSkinSnapshots[char]
    local descriptionRestored = restoreCustomSkinDescription(char)
    removeTaggedCustomSkinItems(char)

    -- Se a descricao guardada falhar, buscar o avatar real da conta.
    -- Esta e a correcao do bug de ficar sem roupa ao desativar.
    if not descriptionRestored then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local realDesc = nil
            pcall(function() realDesc = Players:GetHumanoidDescriptionFromUserId(LP.UserId) end)
            if realDesc then
                descriptionRestored = pcall(function() humanoid:ApplyDescription(realDesc) end)
                pcall(function() realDesc:Destroy() end)
            end
        end
    end

    if snapshot and not descriptionRestored then
        clearCharacterClothing(char)
        for _, shirt in ipairs(snapshot.shirts) do shirt:Clone().Parent = char end
        for _, pants in ipairs(snapshot.pants) do pants:Clone().Parent = char end
    end

    -- Ultima rede de seguranca: repor camisa/calca salvas nos atributos.
    if not descriptionRestored then
        local oldShirt = char:GetAttribute(CUSTOM_SKIN_SHIRT_ATTR)
        local oldPants = char:GetAttribute(CUSTOM_SKIN_PANTS_ATTR)
        if type(oldShirt) == "string" and oldShirt ~= "" and not char:FindFirstChildOfClass("Shirt") then
            local s = Instance.new("Shirt")
            s.ShirtTemplate = oldShirt
            s.Parent = char
        end
        if type(oldPants) == "string" and oldPants ~= "" and not char:FindFirstChildOfClass("Pants") then
            local p = Instance.new("Pants")
            p.PantsTemplate = oldPants
            p.Parent = char
        end
    end

    CustomSkinSnapshots[char] = nil
    if _G._K7OriginalAccessoryNames then _G._K7OriginalAccessoryNames[char] = nil end
    applyCustomSkinGreen(char, false)
    char:SetAttribute(CUSTOM_SKIN_SNAPSHOT_ATTR, nil)
    char:SetAttribute(CUSTOM_SKIN_SHIRT_ATTR, nil)
    char:SetAttribute(CUSTOM_SKIN_PANTS_ATTR, nil)
    char:SetAttribute(CUSTOM_SKIN_APPLIED_ATTR, nil)
    if State.removeAcc then removeCharAccessories(char) end
end

function renderCustomSkinPreview(viewport, variantIndex)
    if not viewport or not viewport.Parent then return false end
    local variant = syncCustomSkinVariant(variantIndex or State.customSkinVariant)
    viewport:ClearAllChildren()
    local camera = Instance.new("Camera")
    camera.Name = "SkinPreviewCamera"
    camera.FieldOfView = 32
    camera.Parent = viewport
    viewport.CurrentCamera = camera
    local world = Instance.new("WorldModel")
    world.Name = "SkinPreviewWorld"
    world.Parent = viewport

    local source = LP.Character
    local sourceHumanoid = source and source:FindFirstChildOfClass("Humanoid")
    local rigType = sourceHumanoid and sourceHumanoid.RigType or Enum.HumanoidRigType.R15
    local description = nil
    if sourceHumanoid then
        pcall(function()
            local original = CustomSkinDescriptions[source]
            description = original and original:Clone() or sourceHumanoid:GetAppliedDescription():Clone()
        end)
    end
    if not description then
        pcall(function() description = Players:GetHumanoidDescriptionFromUserId(LP.UserId) end)
    end
    if description then
        description.Shirt = variant.shirtId
        description.Pants = variant.pantsId
        description.Head = variant.headId
        description.HeadColor = variant.bodyColor
        description.LeftArmColor = variant.bodyColor
        description.LeftLegColor = variant.bodyColor
        description.RightArmColor = variant.bodyColor
        description.RightLegColor = variant.bodyColor
        description.TorsoColor = variant.bodyColor
        if not State.removeAcc then appendCustomSkinAccessory(description) end
    end

    local preview = nil
    -- When this variant is equipped, cloning the live character is the most
    -- accurate preview because it includes every locally applied skin asset.
    if source and State.customSkinEnabled then
        local wasArchivable = source.Archivable
        source.Archivable = true
        pcall(function() preview = source:Clone() end)
        source.Archivable = wasArchivable
    end
    -- Primary preview path for an unequipped variant.
    if not preview and description then
        pcall(function()
            preview = Players:CreateHumanoidModelFromDescription(description, rigType)
        end)
    end
    -- Roblox occasionally refuses one catalog asset on the first call. Build
    -- a base avatar and apply the description to it as a second path.
    if not preview then
        pcall(function() preview = Players:CreateHumanoidModelFromUserId(LP.UserId) end)
        local fallbackHumanoid = preview and preview:FindFirstChildOfClass("Humanoid")
        if fallbackHumanoid and description then
            pcall(function() fallbackHumanoid:ApplyDescription(description) end)
        end
    end

    if preview and description and not State.customSkinEnabled then
        local previewHumanoid = preview:FindFirstChildOfClass("Humanoid")
        if previewHumanoid then pcall(function() previewHumanoid:ApplyDescription(description) end) end
    end
    if description then description:Destroy() end

    if preview then
        -- Enforce the visible clothing/body tint even if Roblox only applied a
        -- partial HumanoidDescription. This is especially important for large
        -- layered-catalog IDs on some executors.
        local assets = resolveCustomSkinAssets()
        local shirt = preview:FindFirstChildOfClass("Shirt") or Instance.new("Shirt")
        shirt.ShirtTemplate = assets.shirtTemplate or ("rbxassetid://" .. tostring(variant.shirtId))
        shirt.Parent = preview
        local pants = preview:FindFirstChildOfClass("Pants") or Instance.new("Pants")
        pants.PantsTemplate = assets.pantsTemplate or ("rbxassetid://" .. tostring(variant.pantsId))
        pants.Parent = preview
        applyCustomSkinGreen(preview, true)
        if not State.removeAcc then attachCustomSkinHat(preview, assets) end
    end

    if not preview then
        -- Last-resort visual preview: catalog thumbnails still show all three
        -- selected skin pieces instead of leaving an empty black preview.
        camera:Destroy()
        world:Destroy()
        viewport.CurrentCamera = nil
        local ids = {variant.headId, variant.shirtId, variant.pantsId}
        local positions = {
            UDim2.new(0.25,-48,0.5,-48),
            UDim2.new(0.5,-48,0.5,-48),
            UDim2.new(0.75,-48,0.5,-48),
        }
        for index, assetId in ipairs(ids) do
            local tile = Instance.new("ImageLabel", viewport)
            tile.Size = UDim2.new(0,96,0,96)
            tile.Position = positions[index]
            tile.BackgroundColor3 = currentColorScheme.modeBtnBg
            tile.BackgroundTransparency = 0.12
            tile.BorderSizePixel = 0
            tile.Image = "rbxthumb://type=Asset&id=" .. tostring(assetId) .. "&w=420&h=420"
            tile.ScaleType = Enum.ScaleType.Fit
            tile.ZIndex = 124
            Instance.new("UICorner", tile).CornerRadius = UDim.new(0,16)
        end
        return true
    end

    preview.Name = "CustomSkinPreview"
    preview.Parent = world
    for _, child in ipairs(preview:GetDescendants()) do
        if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("Tool") then
            child:Destroy()
        elseif child:IsA("BasePart") then
            child.Anchored = true
            child.CanCollide = false
        end
    end
    local previewHumanoid = preview:FindFirstChildOfClass("Humanoid")
    if previewHumanoid then
        previewHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end

    -- Put the avatar at a fixed origin facing the preview camera. This keeps
    -- it visible during dragging and avoids cloning the player's world yaw.
    preview:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180), 0))
    local boxCFrame, boxSize = preview:GetBoundingBox()
    local target = boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.04, 0)
    local distance = math.max(boxSize.X, boxSize.Y, boxSize.Z) * 1.35
    camera.CFrame = CFrame.new(target + Vector3.new(0, boxSize.Y * 0.01, distance), target)
    return true
end

-- Master apply function
function applyCharterToChar(char)
    if not char then return end
    -- Apply/restore the full skin description first, then layer the local
    -- Headless and Korblox variants on top so they are not overwritten.
    if State.customSkinEnabled then
        applyCustomSkinToChar(char)
    elseif CustomSkinSnapshots[char] then
        restoreCustomSkinFromChar(char)
    end
    -- Disabled effects must be inert. Their old false branches created a
    -- generic face and white leg, which overwrote the player's own avatar.
    if State.headlessEnabled then applyHeadlessToChar(char, true) end
    if State.korbloxEnabled then applyKorbloxToChar(char, true) end
end

LP.CharacterAdded:Connect(function(char)
    task.wait(0.15)
    applyCharterToChar(char)
end)

-- Repair clothing/accessories if the game refreshes the avatar appearance
-- after CharacterAdded. This stays idle while the variant is disabled.
task.spawn(function()
    while task.wait(4) do
        if State.customSkinEnabled and not _G._K7SkinApplyBusy then
            local char = LP.Character
            if char then
                local customShirts, customPants, customHats = 0, 0, 0
                local allShirts, allPants = 0, 0
                for _, child in ipairs(char:GetChildren()) do
                    if child:IsA("Shirt") then
                        allShirts = allShirts + 1
                        if child:GetAttribute(CUSTOM_SKIN_TAG) == true then customShirts = customShirts + 1 end
                    elseif child:IsA("Pants") then
                        allPants = allPants + 1
                        if child:GetAttribute(CUSTOM_SKIN_TAG) == true then customPants = customPants + 1 end
                    elseif child:IsA("Accessory") and child:GetAttribute(CUSTOM_SKIN_TAG) == true then
                        customHats = customHats + 1
                    end
                end
                local needsRepair = customShirts ~= 1 or customPants ~= 1
                    or allShirts ~= 1 or allPants ~= 1
                    or (not State.removeAcc and CustomSkinAssets.hatTemplate and customHats ~= 1)
                    or (State.removeAcc and customHats ~= 0)
                -- Reparo no maximo a cada 8s para nunca travar a tela.
                if needsRepair and tick() - (_G._K7SkinLastApply or 0) > 8 then
                    pcall(applyCustomSkinToChar, char, true)
                end
            end
        end
    end
end)

-- Antes isto rodava em Heartbeat (todo frame). Agora e um loop leve.
task.spawn(function()
    while task.wait(0.4) do
        local char = LP.Character
        if char then
            local sig = table.concat({
                State.headlessEnabled and "H" or "h",
                State.korbloxEnabled and "K" or "k",
                State.customSkinEnabled and "C" or "c",
                State.outfit1Applied and "1" or "0",
                State.outfit2Applied and "2" or "0",
                State.outfit3Applied and "3" or "0",
                char.Name,
            }, "")
            if sig ~= _G._lastCharterSig then
                _G._lastCharterSig = sig
                pcall(applyCharterToChar, char)
            end
        end
    end
end)

-- ============================================================
-- FUNCTION TO UPDATE ALL COLORS (green)
-- ============================================================
function updateAllColors(scheme, forcedOld)
    local oldScheme = forcedOld or currentColorScheme
    currentColorScheme = scheme

    local function colorKey(col)
        return math.round(col.R*255)..","..math.round(col.G*255)..","..math.round(col.B*255)
    end

    local bgMap, txtMap, strokeMap = {}, {}, {}
    for prop, oldColor in pairs(oldScheme) do
        local newColor = scheme[prop]
        if newColor and typeof(oldColor) == "Color3" and typeof(newColor) == "Color3" then
            local k = colorKey(oldColor)
            bgMap[k] = newColor
            txtMap[k] = newColor
            strokeMap[k] = newColor
        end
    end

    local gui = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("SevenUpDuelsV2")
    if gui then
        for _, obj in ipairs(gui:GetDescendants()) do
            pcall(function()
                if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("ScrollingFrame") then
                    local newBg = bgMap[colorKey(obj.BackgroundColor3)]
                    if newBg then obj.BackgroundColor3 = newBg end
                    if obj:IsA("ScrollingFrame") then
                        local newSb = strokeMap[colorKey(obj.ScrollBarImageColor3)]
                        if newSb then obj.ScrollBarImageColor3 = newSb end
                    end
                end

                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    local name = obj.Name or ""
                    local txt = tostring(obj.Text or "")
                    if name == "SevenUpNavLabel" then
                        local tab = obj.Parent
                        obj.TextColor3 = tab and tab:GetAttribute("Selected")
                            and (scheme.text or Color3.fromRGB(255,255,255))
                            or (scheme.mainLight or scheme.rowLabel)
                    elseif name == "StackFeatureLabel" then
                        obj.TextColor3 = Color3.fromRGB(20,55,95)
                    elseif name == "SevenUpNavTab" then
                        obj.TextColor3 = obj:GetAttribute("Selected")
                            and (scheme.text or Color3.fromRGB(255,255,255))
                            or (scheme.mainLight or scheme.rowLabel)
                    elseif name == "K7Toggle" then
                        obj.BackgroundColor3 = Color3.fromRGB(4, 48, 62)
                        obj.BackgroundTransparency = 0
                        obj.TextColor3 = Color3.fromRGB(45, 225, 255)
                        obj.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
                        obj.TextStrokeTransparency = 0
                        local border = obj:FindFirstChild("K7ToggleWhiteBorder")
                        if border and border:IsA("UIStroke") then
                            border.Color = Color3.fromRGB(255, 255, 255)
                            border.Thickness = 2
                            border.Transparency = 0
                        end
                    elseif txt == "×" then
                        obj.TextColor3 = scheme.closeBtn or scheme.main
                    elseif name == "DiscordSubTitle" or name == "discordLbl" or txt:lower():find("discord") then
                        obj.TextColor3 = scheme.discordText or scheme.subText or scheme.main
                    elseif name == "SpeedBillLbl" or name:lower():find("speed") then
                        obj.TextColor3 = scheme.speedText or scheme.main
                    elseif name:find("StackBtn_") then
                    else
                        local newTxt = txtMap[colorKey(obj.TextColor3)]
                        if newTxt then
                            obj.TextColor3 = newTxt
                        else
                            local rr = math.round(obj.TextColor3.R*255)
                            local gg = math.round(obj.TextColor3.G*255)
                            local bb = math.round(obj.TextColor3.B*255)
                            if rr > 200 and gg > 200 and bb > 200 then
                                obj.TextColor3 = scheme.text or scheme.rowLabel or Color3.fromRGB(255,255,255)
                            elseif math.max(rr,gg,bb) - math.min(rr,gg,bb) < 40 then
                                obj.TextColor3 = scheme.subText or scheme.rowSub or scheme.text
                            else
                                obj.TextColor3 = scheme.rowValue or scheme.main or scheme.text
                            end
                        end
                    end
                end

                if obj:IsA("TextBox") then
                    local newTxt = txtMap[colorKey(obj.TextColor3)]
                    if newTxt then
                        obj.TextColor3 = newTxt
                    else
                        obj.TextColor3 = scheme.inputText or scheme.rowValue or scheme.main or Color3.fromRGB(255,255,255)
                    end
                    local newBg = bgMap[colorKey(obj.BackgroundColor3)]
                    if newBg then obj.BackgroundColor3 = newBg end
                    local parent = obj.Parent
                    if parent and (parent:IsA("Frame") or parent:IsA("TextButton")) then
                        local pBg = bgMap[colorKey(parent.BackgroundColor3)]
                        if pBg then parent.BackgroundColor3 = pBg
                        else parent.BackgroundColor3 = scheme.inputBg or parent.BackgroundColor3 end
                    end
                end

                if obj:IsA("UIStroke") then
                    local newStroke = strokeMap[colorKey(obj.Color)]
                    if newStroke then
                        obj.Color = newStroke
                    else
                        obj.Color = scheme.border or scheme.main or obj.Color
                    end
                end

                if obj:IsA("UIGradient") then
                    local points = {}
                    local changed = false
                    for _, point in ipairs(obj.Color.Keypoints) do
                        local replacement = bgMap[colorKey(point.Value)]
                            or txtMap[colorKey(point.Value)]
                        if replacement then changed = true end
                        table.insert(points, ColorSequenceKeypoint.new(point.Time, replacement or point.Value))
                    end
                    if changed then obj.Color = ColorSequence.new(points) end
                end
            end)
        end
    end

    -- The music player lives in its own ScreenGui, so recolor it alongside
    -- the main window instead of waiting until it is reopened.
    local musicRoot = MusicPlayer and MusicPlayer.gui
    if musicRoot and musicRoot.Parent and musicRoot ~= gui then
        for _, obj in ipairs(musicRoot:GetDescendants()) do
            pcall(function()
                if obj:IsA("GuiObject") then
                    local bg = bgMap[colorKey(obj.BackgroundColor3)]
                    if bg then obj.BackgroundColor3 = bg end
                end
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    local replacement = txtMap[colorKey(obj.TextColor3)]
                    if replacement then obj.TextColor3 = replacement end
                end
                if obj:IsA("UIStroke") then
                    obj.Color = strokeMap[colorKey(obj.Color)] or scheme.border or scheme.main
                elseif obj:IsA("UIGradient") then
                    local points, changed = {}, false
                    for _, point in ipairs(obj.Color.Keypoints) do
                        local replacement = bgMap[colorKey(point.Value)] or txtMap[colorKey(point.Value)]
                        if replacement then changed = true end
                        table.insert(points, ColorSequenceKeypoint.new(point.Time, replacement or point.Value))
                    end
                    if changed then obj.Color = ColorSequence.new(points) end
                end
            end)
        end
    end

    pcall(function()
        local boxes = {normalBox, carryBox, laggerBox, laggerCarryBox, uiScaleBox, buttonScaleBox, stealRadBox, stealDurBox, autoTPHeightBox}
        for _, box in ipairs(boxes) do
            if box and box.Parent then
                box.TextColor3 = Color3.fromRGB(255,255,255)
                local holder = box.Parent
                if holder:IsA("Frame") or holder:IsA("TextButton") then
                    holder.BackgroundColor3 = Color3.fromRGB(0,0,0)
                    local hgrad = holder:FindFirstChildWhichIsA("UIGradient")
                    if hgrad then hgrad.Color = ColorSequence.new(Color3.fromRGB(0,0,0)) end
                    for _, item in ipairs(holder:GetChildren()) do
                        if item:IsA("UIStroke") then item.Color = Color3.fromRGB(65,65,65) end
                    end
                end
                local row = holder.Parent
                if row and row:IsA("Frame") then
                    if row:FindFirstChildWhichIsA("UIListLayout") then
                        -- faixa dos botoes + / - do Speed: sem fundo cinza
                        row.BackgroundTransparency = 1
                        row = row.Parent
                    end
                    if row and row:IsA("Frame") then
                        if row:GetAttribute("AlwaysCyanOptionBar") == true or row:GetAttribute("MysteryToggleRow") == true then
                            row.BackgroundColor3 = Color3.fromRGB(0,0,0); row.BackgroundTransparency = 0
                        else
                            row.BackgroundTransparency = 1
                        end
                        for _, item in ipairs(row:GetChildren()) do
                            if item:IsA("TextLabel") then item.TextColor3 = Color3.fromRGB(255,255,255) end
                        end
                    end
                end
            end
        end
    end)

    -- Gradients and stateful arrows need an explicit semantic refresh instead
    -- of relying only on exact RGB replacement.
    if gui then
        for _, obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextLabel") and string.upper(obj.Text) == "VENOM.VS" then
                obj.TextColor3 = Color3.fromRGB(255,255,255)
                local gradient = obj:FindFirstChildWhichIsA("UIGradient")
                if gradient then
                    gradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
                        ColorSequenceKeypoint.new(0.52, Color3.fromRGB(255,255,255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255)),
                    })
                end
            elseif obj:IsA("Frame") and obj:GetAttribute("MysteryToggleRow") == true then
                local on = obj:GetAttribute("ActiveState") == true
                local activator = obj:FindFirstChild("SevenUpActivator")
                if activator and activator:IsA("Frame") then
                    activator.BackgroundColor3 = Color3.fromRGB(0,0,0)
                    activator.BackgroundTransparency = 0
                    local fill = activator:FindFirstChild("ToggleActiveFill")
                    if fill then
                        fill.BackgroundColor3 = Color3.fromRGB(0,0,0)
                        fill.BackgroundTransparency = on and 0 or 1
                    end
                    local cap = activator:FindFirstChild("SodaCap")
                    if cap and cap:IsA("Frame") then
                        cap.BackgroundColor3 = on and Color3.fromRGB(0,0,0) or Color3.fromRGB(255,255,255)
                        local capStroke = cap:FindFirstChildWhichIsA("UIStroke")
                        if capStroke then capStroke.Color = on and Color3.fromRGB(0,0,0) or Color3.fromRGB(255,255,255); capStroke.Transparency = 0 end
                        local glow = cap:FindFirstChild("SodaGlow")
                        if glow and glow:IsA("ImageLabel") then glow.ImageColor3 = Color3.fromRGB(255,255,255) end
                    end
                    local trackStroke = activator:FindFirstChildWhichIsA("UIStroke")
                    if trackStroke then trackStroke.Color = Color3.fromRGB(255,255,255); trackStroke.Transparency = 0 end
                end
            elseif obj:IsA("TextButton") and obj.Name == "SevenUpDefenseArrow" then
                local expanded = obj:GetAttribute("Expanded") == true
                obj.BackgroundColor3 = expanded and (scheme.modeBtnActBg or scheme.main)
                    or (scheme.modeBtnBg or scheme.rowBg)
                obj.TextColor3 = expanded and (scheme.buttonText or scheme.text)
                    or (scheme.mainLight or scheme.main)
            end
        end
    end

    if _G._K7RefreshMusicPlayerTheme then pcall(_G._K7RefreshMusicPlayerTheme) end
    if _G._K7RefreshAnimPackTheme then pcall(_G._K7RefreshAnimPackTheme) end

    if autoGrabModule then
        pcall(function()
            autoGrabModule.updateColors(scheme)
            autoGrabModule.setBackground(currentBgImage)
        end)
    end

    for key, wrapper in pairs(stackWrappers or {}) do
        if wrapper and wrapper.Parent then
            local isOn = false
            pcall(function()
                if key == "antiDesync" then isOn = _G.AceAntiDesyncAimbotOn == true
                elseif key == "aimbot" then isOn = (_G.AceNormalAimbotOn == true) and (_G.AceBatAimbotV2On ~= true)
                elseif key == "batV2" then isOn = (State.batAimbotZombie == true)
                elseif key == "speed" or key == "carrySpeed" then isOn = State.speedToggled == true
                elseif key == "autoCarry" then isOn = State.softStealEnabled == true
                elseif key == "lagger" then isOn = State.laggerMode == 1
                elseif key == "laggerCarry" then isOn = State.laggerMode == 2
                end
            end)
            wrapper.BackgroundColor3 = isOn and Color3.fromRGB(60,210,255) or Color3.fromRGB(14,32,68)
            wrapper.BackgroundTransparency = isOn and 0.18 or 0.08
            wrapper.TextColor3 = isOn and (scheme.stackActiveText or scheme.buttonText or Color3.fromRGB(255,255,255)) or (scheme.stackText or scheme.text)
            local canSurface=wrapper:FindFirstChild("SodaCanSurface")
            local canTop=wrapper:FindFirstChild("IndentedCanTop")
            local canColor=isOn and (scheme.stackActive or scheme.main) or (scheme.stackBg or scheme.mainDark)
            if canSurface then canSurface.BackgroundColor3=canColor end
            if canTop then canTop.BackgroundColor3=canColor end
            wrapper:SetAttribute("Active",isOn)
            local stackLabel=wrapper:FindFirstChild("StackFeatureLabel")
            if stackLabel then
                stackLabel.TextColor3=Color3.fromRGB(20,55,95)
            end
            local miniSeven=wrapper:FindFirstChild("MobileSevenLogo",true)
            if miniSeven and miniSeven:IsA("TextLabel") then
                miniSeven.TextColor3=Color3.fromRGB(255,255,255)
                miniSeven.TextStrokeColor3=scheme.mainDark
            end
            local sharedBlend=adaptiveCanColorSequence(scheme,isOn)
            local bodyBlend=canSurface and canSurface:FindFirstChild("AdaptiveCanBlend")
            local topBlend=canTop and canTop:FindFirstChild("AdaptiveCanBlend")
            if bodyBlend and bodyBlend:IsA("UIGradient") then bodyBlend.Color=sharedBlend end
            if topBlend and topBlend:IsA("UIGradient") then topBlend.Color=sharedBlend end
        end
    end

    for _, btn in pairs(keybindBtnRefs or {}) do
        if btn and btn.Parent then
            btn.BackgroundColor3 = scheme.main
            btn.TextColor3 = scheme.buttonText or scheme.text
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            local head = player.Character:FindFirstChild("Head")
            if head then
                for _, bbName in ipairs({"SevenUpDuelsBB", "SevenUpDuelsBB_Other"}) do
                    local bb = head:FindFirstChild(bbName)
                    if bb then
                        local speedLbl = bb:FindFirstChild("SpeedBillLbl")
                        if speedLbl then speedLbl.TextColor3 = scheme.speedText or scheme.main end
                        local discordLbl = bb:FindFirstChild("discordLbl")
                        if not discordLbl then
                            for _, child in ipairs(bb:GetChildren()) do
                                if child:IsA("TextLabel") and tostring(child.Text or ""):lower():find("discord") then
                                    discordLbl = child
                                    child.Name = "discordLbl"
                                    break
                                end
                            end
                        end
                        if discordLbl then discordLbl.TextColor3 = scheme.discordText or scheme.subText or scheme.main end
                    end
                end
            end
        end
    end

    for _, d in pairs(PlayerESP.playerData or {}) do
        pcall(function()
            if d.highlight then
                d.highlight.OutlineColor = scheme.main or Color3.fromRGB(245,245,245)
            end
            if d.billboard then
                for _, item in ipairs(d.billboard:GetDescendants()) do
                    if item:IsA("UIStroke") then item.Color = scheme.main end
                    if item:IsA("TextLabel") then
                        item.TextColor3 = item.Name == "OtherPlayerNameLabel"
                            and (scheme.subText or scheme.mainLight)
                            or scheme.main
                    end
                end
            end
        end)
    end

    if gui then
        local sodaBadge = gui:FindFirstChild("SevenUpSodaBadge", true)
        if sodaBadge and sodaBadge:IsA("Frame") then
            sodaBadge.BackgroundColor3 = scheme.mainDark
            local gradient = sodaBadge:FindFirstChildWhichIsA("UIGradient")
            if gradient then gradient.Color = adaptiveCanColorSequence(scheme,true) end
            local badgeStroke = sodaBadge:FindFirstChildWhichIsA("UIStroke")
            if badgeStroke then badgeStroke.Color = scheme.mainLight end
            for _, item in ipairs(sodaBadge:GetChildren()) do
                if item:IsA("TextLabel") and tostring(item.Text):lower():find("discord",1,true) then
                    item.TextColor3 = scheme.discordText or scheme.mainLight
                end
            end
            local badgeSeven=sodaBadge:FindFirstChild("BadgeSevenLogo",true)
            if badgeSeven and badgeSeven:IsA("TextLabel") then
                badgeSeven.TextStrokeColor3=scheme.mainDark
            end
        end
        local titleMusicButton=gui:FindFirstChild("SevenUpTitleMusicButton",true)
        if titleMusicButton then
            local titleLogo=titleMusicButton:FindFirstChild("TitleSevenLogo",true)
            if titleLogo and titleLogo:IsA("TextLabel") then titleLogo.TextStrokeColor3=scheme.mainDark end
        end
    end
    if _G._K7RefreshMobileButtonShape then pcall(_G._K7RefreshMobileButtonShape) end
end

-- ============================================================
-- BACKGROUND CHANGER FUNCTION (green)
-- ============================================================

-- ============================================================
-- DIRECT USER COLOR APPLIER
-- letters = every menu text, bottom = menu background,
-- btnText/btnBg = floating buttons only, bar = auto grab bar.
-- ============================================================
function _G._K7ApplyDirectUserColors()
    local UC = _G._K7UserColors or {}
    local pg = LP:FindFirstChild("PlayerGui")
    local gui = pg and pg:FindFirstChild("SevenUpDuelsV2")
    if not gui then return end
    local mainOuter = gui:FindFirstChild("MainOuter")

    local function isStackDesc(obj)
        local node = obj
        while node and node ~= gui do
            if tostring(node.Name):find("StackBtn_") then return true end
            node = node.Parent
        end
        return false
    end

    -- Keep hub artwork visible; only tint non-background panels lightly
    if UC.bottom and mainOuter then
        local bg = mainOuter:FindFirstChild("BgImage")
        if bg then
            bg.Image = "rbxassetid://137970714521556"
            bg.ImageTransparency = 0
            bg.BackgroundTransparency = 1
            bg.Visible = true
            local g = bg:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
        end
        local atmo = mainOuter:FindFirstChild("GradientAtmosphere")
        if atmo then
            atmo.BackgroundTransparency = 0.97
        end
    end

    -- every letter inside the menu
    if UC.letters then
        for _, obj in ipairs(gui:GetDescendants()) do
            pcall(function()
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    if not isStackDesc(obj) then obj.TextColor3 = UC.letters end
                end
            end)
        end
    end

    -- floating buttons only (they live in their own top-layer ScreenGui now,
    -- so iterate the button registry instead of the main menu's children)
    for _, child in pairs(stackWrappers or {}) do
        if child and child.Parent then
            local fixedBlack = Color3.fromRGB(0, 0, 0)
            local fixedWhite = Color3.fromRGB(255, 255, 255)
            pcall(function() child.BackgroundColor3 = fixedBlack; child.BackgroundTransparency = 0 end)
            for _, obj in ipairs(child:GetDescendants()) do
                pcall(function()
                    if obj:IsA("UIGradient") and obj.Name == "AdaptiveCanBlend" then
                        obj.Color = ColorSequence.new(fixedBlack)
                    elseif obj:IsA("Frame") and (obj.Name == "SodaCanSurface" or obj.Name == "IndentedCanTop") then
                        obj.BackgroundColor3 = fixedBlack
                        obj.BackgroundTransparency = 0
                    elseif obj:IsA("TextLabel") or obj:IsA("TextButton") then
                        obj.TextColor3 = fixedWhite
                    end
                end)
            end
            pcall(function() child.TextColor3 = fixedWhite end)
        end
    end

    -- Auto Grab palette is fixed by updateAutoGrabLineColor: white panel, cyan fill and white shine.
    -- Reassert the fixed menu palette after any saved colour preferences.
    -- This does not reach the separately registered floating buttons.
    if _G._K7ApplyOpaqueMenuStyle then pcall(_G._K7ApplyOpaqueMenuStyle) end
end

-- Keeps the menu panels opaque (no see-through rounded boxes) while letting
-- the background image stay visible. Floating buttons are untouched.
function _G._K7ApplyOpaqueMenuStyle()
    local pg = LP:FindFirstChild("PlayerGui")
    local gui = pg and pg:FindFirstChild("SevenUpDuelsV2")
    local mainOuter = gui and gui:FindFirstChild("MainOuter")
    if not mainOuter then return end

    local LB_GLOW  = Color3.fromRGB(220, 245, 255)
    local LB_LIGHT = Color3.fromRGB(140, 210, 255)
    local LB_MID   = Color3.fromRGB(90, 180, 245)
    local LB_PANEL = Color3.fromRGB(200, 230, 250)
    local LB_BG    = Color3.fromRGB(210, 235, 252)
    local LB_SOFT  = Color3.fromRGB(175, 220, 250)

    mainOuter.BackgroundTransparency = 1

    local bg = mainOuter:FindFirstChild("BgImage") or mainOuter:FindFirstChild("BgImage", true)
    if bg then
        bg.Image = "rbxassetid://137970714521556"
        bg.ImageTransparency = 0
        bg.BackgroundTransparency = 1
        bg.BackgroundColor3 = Color3.fromRGB(8, 28, 55)
        bg.ImageColor3 = Color3.fromRGB(255, 255, 255)
        bg.ScaleType = Enum.ScaleType.Crop
        bg.Visible = true
        -- Remove any gradient that could wash out the artwork
        local g = bg:FindFirstChild("CyberBgGradient")
        if g then g:Destroy() end
    end
    local topBg = mainOuter:FindFirstChild("TopBgImage")
    if topBg then
        topBg.ImageTransparency = 1
        topBg.Visible = false
    end
    local atmosphere = mainOuter:FindFirstChild("GradientAtmosphere")
    if atmosphere then
        -- Very light veil so the background image stays dominant
        atmosphere.BackgroundTransparency = 0.97
        atmosphere.BackgroundColor3 = LB_LIGHT
        atmosphere.Visible = true
        local ag = atmosphere:FindFirstChildOfClass("UIGradient")
        if ag then
            ag.Rotation = 90
            ag.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, LB_GLOW),
                ColorSequenceKeypoint.new(0.35, LB_LIGHT),
                ColorSequenceKeypoint.new(0.70, LB_MID),
                ColorSequenceKeypoint.new(1.00, LB_SOFT),
            })
            ag.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0.00, 0.75),
                NumberSequenceKeypoint.new(0.40, 0.88),
                NumberSequenceKeypoint.new(0.75, 0.85),
                NumberSequenceKeypoint.new(1.00, 0.72),
            })
        end
    end
    local outerStroke = mainOuter:FindFirstChildWhichIsA("UIStroke")
    if outerStroke then
        outerStroke.Color = LB_LIGHT
        outerStroke.Transparency = 0.2
        outerStroke.Thickness = 1.6
    end

    local function cyberEdge(obj)
        local stroke = obj:FindFirstChild("BlackBarWhiteEdge")
        if not stroke then
            stroke = Instance.new("UIStroke")
            stroke.Name = "BlackBarWhiteEdge"
            stroke.Parent = obj
        end
        stroke.Thickness = 1.2
        stroke.Transparency = 0.25
        stroke.Color = LB_LIGHT
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        for _, other in ipairs(obj:GetChildren()) do
            if other:IsA("UIStroke") and other ~= stroke then other.Transparency = 1 end
        end
    end

    for _, obj in ipairs(mainOuter:GetDescendants()) do
        pcall(function()
            if obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
                if obj:GetAttribute("AlwaysCyanOptionBar") == true then
                    obj.BackgroundColor3 = Color3.fromRGB(0,0,0)
                    obj.BackgroundTransparency = 0
                    cyberEdge(obj)
                elseif obj:GetAttribute("AlwaysBlackOptionBar") == true
                    or obj.Name == "MechanicsNavigationBar" then
                    obj.BackgroundColor3 = Color3.fromRGB(0,0,0)
                    obj.BackgroundTransparency = 0
                    local gradient = obj:FindFirstChildWhichIsA("UIGradient")
                    if gradient then
                        gradient.Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, LB_GLOW),
                            ColorSequenceKeypoint.new(0.5, LB_PANEL),
                            ColorSequenceKeypoint.new(1, LB_SOFT),
                        })
                    end
                    cyberEdge(obj)
                elseif obj.Name == "TitleBar" or obj.Name == "MainContent"
                    or obj.Name == "TabContainer" or obj.Name == "TabScroll" then
                    if obj.Name == "TitleBar" then
                        obj.BackgroundColor3 = LB_PANEL
                        obj.BackgroundTransparency = 0.12
                        cyberEdge(obj)
                    else
                        obj.BackgroundTransparency = 1
                    end
                end
            elseif obj:IsA("TextButton") and obj.Text ~= "" and obj.BackgroundTransparency < 1 then
                obj.BackgroundColor3 = LB_PANEL
                obj.BackgroundTransparency = 0.18
                cyberEdge(obj)
            end
        end)
    end

end

_G._K7BaseUpdateAllColors = updateAllColors
updateAllColors = function(scheme, forcedOld)
    local r = _G._K7BaseUpdateAllColors(scheme, forcedOld)
    pcall(_G._K7ApplyDirectUserColors)
    pcall(_G._K7ApplyOpaqueMenuStyle)
    if _G._K7RefreshStackColors then pcall(_G._K7RefreshStackColors) end
    return r
end

function changeDuelScriptBackground(imageId)
    -- Single fixed hub background only.
    imageId = "rbxassetid://137970714521556"
    State.bgImage = imageId
    currentBgImage = imageId
    local prevScheme = currentColorScheme
    local baseScheme = COLOR_SCHEMES[imageId] or COLOR_SCHEMES["rbxassetid://102557909116203"]
    local scheme = get7UpThemeScheme(baseScheme, State.uiColorTheme)
    _G._K7ThemeMode = State.uiColorTheme == "Red" and "Red" or "Green"
    _G._K7AccentColor = scheme.main
    
    local gui = LP:FindFirstChild("PlayerGui"):FindFirstChild("SevenUpDuelsV2")
    if gui then
        local mainOuter = gui:FindFirstChild("MainOuter")
        if mainOuter then
            local bg = mainOuter:FindFirstChild("BgImage") or mainOuter:FindFirstChild("BgImage", true)
            if bg then
                bg.Image = imageId
                bg.ImageTransparency = 0
                bg.BackgroundTransparency = 1
                bg.ImageColor3 = Color3.fromRGB(255,255,255)
                bg.Visible = true
            end
            local topBg = mainOuter:FindFirstChild("TopBgImage")
            if topBg then
                -- Carry the selected skin through the overlapping can neck.
                topBg.Image = imageId
                topBg.ImageTransparency = 0.04
                topBg.ImageColor3 = Color3.fromRGB(255,255,255)
                topBg.BackgroundColor3 = scheme.mainDark or Color3.fromRGB(59, 59, 59)
                topBg.Visible = false
                local blend = topBg:FindFirstChild("AdaptiveCanBlend")
                if blend and blend:IsA("UIGradient") then
                    blend.Color = adaptiveCanColorSequence(scheme,false)
                end
            end
            local atmosphere = mainOuter:FindFirstChild("GradientAtmosphere")
            if atmosphere then
                atmosphere.BackgroundColor3 = scheme.main
                atmosphere.BackgroundTransparency = 0.92
            end
        end
    end
    
    if autoGrabModule then
        autoGrabModule.setBackground(imageId)
        autoGrabModule.updateColors(scheme)
    end
    if MusicPlayer and MusicPlayer.gui and MusicPlayer.gui.Parent then
        local musicBg = MusicPlayer.gui:FindFirstChild("MusicBackground", true)
        if musicBg and musicBg:IsA("ImageLabel") then
            musicBg.Image = imageId
            musicBg.ImageTransparency = 0.08
            musicBg.ImageColor3 = Color3.fromRGB(255,255,255)
            musicBg.Visible = true
        end
    end
    
    updateAllColors(scheme, prevScheme)
    if _G._K7RefreshColorThemeButtons then pcall(_G._K7RefreshColorThemeButtons) end
    if _G._K7RefreshCustomSkinTheme then pcall(_G._K7RefreshCustomSkinTheme) end
    if _G._K7RefreshMusicPlayerTheme then pcall(_G._K7RefreshMusicPlayerTheme) end
    if _G._K7RefreshAnimPackTheme then pcall(_G._K7RefreshAnimPackTheme) end
    
    requestSave()
end

function set7UpColorTheme(mode, skipSave)
    mode = mode == "Red" and "Red" or "Green"
    local previous = currentColorScheme
    State.uiColorTheme = mode
    _G._K7ThemeMode = mode
    local themeBackground = "rbxassetid://137970714521556"
    State.bgImage = themeBackground
    currentBgImage = themeBackground
    local baseScheme = COLOR_SCHEMES[currentBgImage]
        or COLOR_SCHEMES["rbxassetid://102557909116203"]
    local scheme = get7UpThemeScheme(baseScheme, mode)
    _G._K7AccentColor = scheme.main
    updateAllColors(scheme, previous)

    local playerGui = LP:FindFirstChild("PlayerGui")
    local mainGui = playerGui and playerGui:FindFirstChild("SevenUpDuelsV2")
    if mainGui then
        for _, name in ipairs({"BgImage", "TopBgImage"}) do
            local image = mainGui:FindFirstChild(name, true)
            if image and image:IsA("ImageLabel") then
                image.Image = themeBackground
                image.ImageColor3 = Color3.fromRGB(255,255,255)
                image.ImageTransparency = name == "BgImage" and 0 or 1
                image.BackgroundTransparency = 1
                image.ImageColor3 = Color3.fromRGB(255,255,255)
                image.Visible = name == "BgImage"
            end
        end
        local atmosphere = mainGui:FindFirstChild("GradientAtmosphere", true)
        if atmosphere then
            atmosphere.BackgroundColor3 = scheme.main
            atmosphere.BackgroundTransparency = mode == "Red" and 0.94 or 0.88
        end
    end
    if MusicPlayer and MusicPlayer.gui and MusicPlayer.gui.Parent then
        local musicBg = MusicPlayer.gui:FindFirstChild("MusicBackground", true)
        if musicBg then
            musicBg.Image = themeBackground
            musicBg.ImageColor3 = Color3.fromRGB(255,255,255)
        end
    end
    if _G._K7RefreshColorThemeButtons then pcall(_G._K7RefreshColorThemeButtons) end
    if _G._K7RefreshCustomSkinTheme then pcall(_G._K7RefreshCustomSkinTheme) end
    if _G._K7RefreshMusicPlayerTheme then pcall(_G._K7RefreshMusicPlayerTheme) end
    if _G._K7RefreshAnimPackTheme then pcall(_G._K7RefreshAnimPackTheme) end
    if not skipSave then requestSave() end
end

-- ============================================================
-- SKY THEME SYSTEM (unchanged)
-- ============================================================
SKY_PRESETS_LIST = {"Off","Night","Aurora","Sunset","Galaxy","Tech","Sakura","Pink Night",
    "Blood Moon","Emerald Dawn","Volcanic","Arctic","Midnight Ocean","Vaporwave","Toxic","Solar Eclipse",
    "Hellscape","Heaven","Storm","Sunrise","Deep Space","Lavender Dream","Inferno","Mint Sky"}
SKY_PRESETS = {
    ["Off"]            = {kind="off"},
    ["Night"]          = {clock=22,  brightness=2,   ambient={110,100,130}, outAmb={120,110,140}, sky={stars=4000,moon=18,sun=0,moonTex=true},      atm={dens=0.45,color={120,60,180}, decay={60,20,100},  glare=0.5,haze=1.2}},
    ["Aurora"]         = {clock=14,  brightness=3,   ambient={150,120,150}, outAmb={160,130,150}, atm={dens=0.55,color={255,80,200}, decay={255,20,150}, glare=2.5,haze=3},   clouds={cover=0.7, dens=0.7, color={255,240,250}}},
    ["Sunset"]         = {clock=17.2,brightness=2.5, ambient={170,120,100}, outAmb={180,130,110}, sky={stars=0,sun=25,moon=0},                       atm={dens=0.5, color={255,130,60}, decay={255,80,30}, glare=2,  haze=2.5}, clouds={cover=0.55,dens=0.55,color={255,200,140}}},
    ["Galaxy"]         = {clock=0,   brightness=1.5, ambient={70,60,100},   outAmb={80,70,110},   sky={stars=10000,moon=30,sun=0},                   atm={dens=0.15,color={40,20,80},  decay={20,10,50},  glare=0.3,haze=0.5}},
    ["Tech"]           = {clock=21,  brightness=2.2, ambient={90,130,170},  outAmb={100,140,180}, sky={stars=2000,moon=12},                          atm={dens=0.4, color={0,200,255}, decay={150,0,255}, glare=2,  haze=2},   clouds={cover=0.4, dens=0.6, color={100,200,255}}},
    ["Sakura"]         = {clock=11,  brightness=3.5, ambient={170,150,160}, outAmb={180,160,170}, sky={sun=8},                                        atm={dens=0.3, color={255,200,220},decay={255,170,200},glare=1, haze=1.5}, clouds={cover=0.6, dens=0.4, color={255,250,252}}},
    ["Pink Night"]     = {clock=23,  brightness=2.2, ambient={120,60,110},  outAmb={140,70,120},  sky={stars=5000,moon=22,sun=0,moonTex=true},       atm={dens=0.5, color={255,80,180},decay={140,30,100},glare=0.7,haze=1.4}, clouds={cover=0.3, dens=0.5, color={180,90,150}}},
    ["Blood Moon"]     = {clock=22.5,brightness=1.6, ambient={130,40,40},   outAmb={150,50,50},   sky={stars=1500,moon=28,sun=0,moonTex=true},       atm={dens=0.6, color={220,30,30}, decay={120,10,10}, glare=1.4,haze=2},   clouds={cover=0.5, dens=0.7, color={120,30,30}}},
    ["Emerald Dawn"]   = {clock=6.5, brightness=2.8, ambient={130,170,140}, outAmb={140,180,150}, sky={sun=18,moon=0,stars=0},                       atm={dens=0.4, color={80,200,140},decay={40,150,90}, glare=1.8,haze=2.2}, clouds={cover=0.5, dens=0.5, color={200,255,220}}},
    ["Volcanic"]       = {clock=19,  brightness=2,   ambient={180,80,40},   outAmb={200,90,50},   sky={stars=200,sun=12,moon=0},                     atm={dens=0.75,color={255,60,0},  decay={180,20,0},  glare=3,  haze=3.5}, clouds={cover=0.8, dens=0.9, color={120,40,20}}},
    ["Arctic"]         = {clock=9,   brightness=3.2, ambient={200,220,235}, outAmb={210,230,245}, sky={sun=10,stars=0,moon=0},                       atm={dens=0.3, color={180,220,255},decay={140,200,240},glare=1.5,haze=1.8},clouds={cover=0.7, dens=0.6, color={250,253,255}}},
    ["Midnight Ocean"] = {clock=1.5, brightness=1.7, ambient={60,90,130},   outAmb={70,100,140},  sky={stars=6000,moon=24,sun=0,moonTex=true},       atm={dens=0.5, color={20,60,140}, decay={10,30,90},  glare=0.6,haze=1.5}},
    ["Vaporwave"]      = {clock=19.5,brightness=2.4, ambient={180,120,200}, outAmb={190,130,210}, sky={stars=1000,moon=14},                          atm={dens=0.45,color={255,100,220},decay={120,60,255},glare=2.2,haze=2.4},clouds={cover=0.5, dens=0.55,color={200,150,255}}},
    ["Toxic"]          = {clock=13,  brightness=2.5, ambient={140,180,80},  outAmb={150,190,90},  atm={dens=0.55,color={100,220,40},decay={60,150,20},glare=1.8,haze=2.6},  clouds={cover=0.65,dens=0.7, color={180,255,120}}},
    ["Solar Eclipse"]  = {clock=12,  brightness=0.9, ambient={50,40,60},    outAmb={60,50,70},    sky={stars=3500,sun=22,moon=0},                    atm={dens=0.5, color={255,140,40},decay={30,20,40},  glare=2.8,haze=1.8}},
    ["Hellscape"]      = {clock=18,  brightness=1.8, ambient={200,60,30},   outAmb={220,70,40},   sky={stars=100,sun=30,moon=0},                     atm={dens=0.85,color={255,30,0},  decay={120,0,0},   glare=3.5,haze=4},   clouds={cover=0.95,dens=0.95,color={80,20,10}}},
    ["Heaven"]         = {clock=12,  brightness=4,   ambient={240,235,210}, outAmb={250,245,220}, sky={sun=16,moon=0,stars=0},                       atm={dens=0.25,color={255,250,220},decay={255,240,200},glare=3, haze=1.5}, clouds={cover=0.85,dens=0.5, color={255,255,255}}},
    ["Storm"]          = {clock=15,  brightness=1.4, ambient={90,90,110},   outAmb={100,100,120}, sky={stars=0,sun=6,moon=0},                        atm={dens=0.65,color={80,90,120}, decay={40,50,80},  glare=0.5,haze=3},   clouds={cover=0.95,dens=0.95,color={60,65,80}}},
    ["Sunrise"]        = {clock=6.2, brightness=2.8, ambient={220,180,130}, outAmb={230,190,140}, sky={sun=22,stars=0,moon=0},                       atm={dens=0.45,color={255,180,100},decay={255,140,80},glare=2.4,haze=2.2},clouds={cover=0.4, dens=0.4, color={255,220,180}}},
    ["Deep Space"]     = {clock=0,   brightness=1,   ambient={30,25,50},    outAmb={40,35,60},    sky={stars=15000,moon=0,sun=0},                    atm={dens=0.08,color={15,5,40},   decay={5,0,20},    glare=0.2,haze=0.3}},
    ["Lavender Dream"] = {clock=18.5,brightness=2.6, ambient={180,160,220}, outAmb={190,170,230}, sky={stars=800,moon=16,sun=0},                     atm={dens=0.4, color={200,160,255},decay={160,120,220},glare=1.4,haze=1.8},clouds={cover=0.55,dens=0.5, color={220,200,255}}},
    ["Inferno"]        = {clock=17.5,brightness=2.2, ambient={220,100,40},  outAmb={235,110,50},  sky={sun=26,moon=0,stars=0},                       atm={dens=0.6, color={255,90,20}, decay={200,40,0},  glare=3,  haze=3.2}, clouds={cover=0.7, dens=0.7, color={200,80,40}}},
    ["Mint Sky"]       = {clock=10,  brightness=3.2, ambient={180,230,210}, outAmb={190,240,220}, sky={sun=10},                                       atm={dens=0.32,color={150,255,210},decay={100,220,180},glare=1.6,haze=1.6},clouds={cover=0.55,dens=0.45,color={240,255,250}}},
}
function _vC3(t) return Color3.fromRGB(t[1], t[2], t[3]) end
function _v4mpClearSky()
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:GetAttribute("_K7Sky") then pcall(function() v:Destroy() end) end
    end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        for _, v in ipairs(terrain:GetChildren()) do
            if v:GetAttribute("_K7Sky") then pcall(function() v:Destroy() end) end
        end
    end
end
function applyCustomSky(mode)
    _v4mpClearSky()
    local preset = SKY_PRESETS and SKY_PRESETS[mode]
    if not preset or preset.kind == "off" then
        Lighting.FogEnd=100000; Lighting.FogStart=0
        Lighting.FogColor=Color3.fromRGB(192,192,192)
        Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.GlobalShadows=true
        State.skyTheme="Off"; skyTheme="Off"; return
    end
    Lighting.FogEnd=100000; Lighting.FogStart=0
    Lighting.FogColor=Color3.fromRGB(200,200,200)
    Lighting.GlobalShadows=true
    Lighting.ClockTime = preset.clock or 14
    Lighting.Brightness = preset.brightness or 2
    if preset.outAmb then Lighting.OutdoorAmbient = _vC3(preset.outAmb) end
    if preset.ambient then Lighting.Ambient = _vC3(preset.ambient) end
    if preset.sky then
        local sky = Instance.new("Sky")
        sky:SetAttribute("_K7Sky", true)
        if preset.sky.stars  then sky.StarCount        = preset.sky.stars end
        if preset.sky.moon   then sky.MoonAngularSize  = preset.sky.moon  end
        if preset.sky.sun    then sky.SunAngularSize   = preset.sky.sun   end
        if preset.sky.moonTex then sky.MoonTextureId   = "rbxasset://sky/moon.jpg" end
        sky.Parent = Lighting
    end
    if preset.atm then
        local atm = Instance.new("Atmosphere")
        atm:SetAttribute("_K7Sky", true)
        atm.Density = preset.atm.dens or 0.3
        atm.Color   = _vC3(preset.atm.color)
        atm.Decay   = _vC3(preset.atm.decay)
        atm.Glare   = preset.atm.glare or 1
        atm.Haze    = preset.atm.haze  or 1
        atm.Parent  = Lighting
    end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if preset.clouds and terrain then
        local clouds = Instance.new("Clouds")
        clouds:SetAttribute("_K7Sky", true)
        clouds.Cover   = preset.clouds.cover or 0.5
        clouds.Density = preset.clouds.dens  or 0.5
        clouds.Color   = _vC3(preset.clouds.color)
        clouds.Parent  = terrain
    end
    State.skyTheme = mode; skyTheme = mode
end

-- ============================================================
-- PLAYER ESP (Ambitious: outline + enemy speed)
-- ============================================================
function startPlayerESP()
    if PlayerESP.enabled then return end
    PlayerESP.enabled = true
    local function cleanupPlayer(plr)
        local d = PlayerESP.playerData[plr]; if not d then return end
        pcall(function() if d.highlight then d.highlight:Destroy() end end)
        pcall(function() if d.billboard then d.billboard:Destroy() end end)
        if d.conns then for _,c in ipairs(d.conns) do pcall(function() c:Disconnect() end) end end
        PlayerESP.playerData[plr] = nil
    end
    local function setupPlayer(plr, char)
        if not PlayerESP.enabled or plr == LP then return end
        cleanupPlayer(plr)
        local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart",5))
        local head = char and (char:FindFirstChild("Head") or char:WaitForChild("Head",5))
        if not hrp or not head then return end
        local hl=Instance.new("Highlight")
        hl.Name="AmbitiousHubESP"; hl.Adornee=char; hl.FillColor=Color3.fromRGB(35,35,35); hl.FillTransparency=0.72
        hl.OutlineColor=Color3.fromRGB(245,245,245); hl.OutlineTransparency=0; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=char
        local bb=Instance.new("BillboardGui")
        bb.Name="AmbitiousHubESPTag"; bb.Adornee=head; bb.Size=UDim2.new(0,124,0,34); bb.StudsOffset=Vector3.new(0,2.7,0); bb.AlwaysOnTop=true; bb.LightInfluence=0; bb.Parent=head
        local box=Instance.new("Frame",bb); box.Size=UDim2.new(1,0,1,0); box.BackgroundTransparency=1; box.BorderSizePixel=0
        local label=Instance.new("TextLabel",box); label.Name="Speed"; label.Size=UDim2.new(1,-10,0,20); label.Position=UDim2.new(0,5,0,2); label.BackgroundTransparency=1
        label.TextColor3=Color3.fromRGB(45,205,255); label.Font=Enum.Font.GothamBold; label.TextSize=16; label.TextStrokeTransparency=0.15
        label.TextStrokeColor3=Color3.fromRGB(0,30,50); label.Text="Speed: 0.0"
        -- Speed: 0.0  -> velocidade horizontal real do jogador, 1 decimal.
        -- Medida pelo deslocamento na janela de tempo (mais estavel que ler
        -- a velocity crua) e suavizada para nao piscar.
        local _spSmooth, _spLastP, _spLastT = 0, hrp.Position, os.clock()
        local conn=RunService.Heartbeat:Connect(function()
            if not PlayerESP.enabled or not hrp.Parent then return end
            local now=os.clock()
            local pos=hrp.Position
            local dt=now-_spLastT
            local raw
            if dt>0.03 then
                local d=pos-_spLastP
                local moved=Vector3.new(d.X,0,d.Z).Magnitude/dt
                _spLastP, _spLastT = pos, now
                if moved==moved and moved<400 then raw=moved end
            end
            if raw==nil then
                local v=hrp.AssemblyLinearVelocity or hrp.Velocity
                local m=Vector3.new(v.X,0,v.Z).Magnitude
                if m==m and m<400 then raw=m end
            end
            if raw then _spSmooth=_spSmooth+(raw-_spSmooth)*0.35 end
            label.Text=string.format("Speed: %.1f",_spSmooth); label.TextColor3=Color3.fromRGB(45,205,255)
        end)
        PlayerESP.playerData[plr]={highlight=hl,billboard=bb,conns={conn}}
    end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LP then
            if plr.Character then task.spawn(setupPlayer,plr,plr.Character) end
            table.insert(PlayerESP.conns,plr.CharacterAdded:Connect(function(c) task.defer(setupPlayer,plr,c) end))
        end
    end
    table.insert(PlayerESP.conns,Players.PlayerAdded:Connect(function(plr)
        if plr~=LP then table.insert(PlayerESP.conns,plr.CharacterAdded:Connect(function(c) task.defer(setupPlayer,plr,c) end)) end
    end))
    table.insert(PlayerESP.conns,Players.PlayerRemoving:Connect(cleanupPlayer))
    -- Watchdog: recria o indicador se outro script o remover, desativar ou
    -- desconectar da cabeca enquanto o ESP estiver ligado.
    table.insert(PlayerESP.conns,RunService.Heartbeat:Connect(function()
        PlayerESP._nextBadgeCheck = PlayerESP._nextBadgeCheck or 0
        local now = os.clock()
        if now < PlayerESP._nextBadgeCheck then return end
        PlayerESP._nextBadgeCheck = now + 0.5
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local head = plr.Character:FindFirstChild("Head")
                local data = PlayerESP.playerData[plr]
                local bb = data and data.billboard
                local label = bb and bb:FindFirstChild("Speed", true)
                if head and (not bb or not bb.Parent or bb.Adornee ~= head or not label) then
                    task.defer(setupPlayer, plr, plr.Character)
                elseif bb then
                    bb.Enabled = true
                    bb.AlwaysOnTop = true
                end
            end
        end
    end))
end
function stopPlayerESP()
    PlayerESP.enabled=false
    for _,c in ipairs(PlayerESP.conns or {}) do pcall(function() c:Disconnect() end) end
    PlayerESP.conns={}
    for plr,d in pairs(PlayerESP.playerData or {}) do
        pcall(function() if d.highlight then d.highlight:Destroy() end end)
        pcall(function() if d.billboard then d.billboard:Destroy() end end)
        if d.conns then for _,c in ipairs(d.conns) do pcall(function() c:Disconnect() end) end end
        PlayerESP.playerData[plr]=nil
    end
end

    -- ============================================================
    -- RAGDOLL COUNTDOWN (Ambitious: local player + enemies)
    -- ============================================================
    do
        local conns,labels,ends={}, {}, {}
        local updateConn,addedConn,removeConn
        local function clearPlayer(plr)
            if conns[plr] then for _,c in ipairs(conns[plr]) do pcall(function() c:Disconnect() end) end end; conns[plr]=nil
            if labels[plr] then pcall(function() labels[plr]:Destroy() end) end; labels[plr]=nil; ends[plr]=nil
        end
        local function attach(plr,char)
            clearPlayer(plr); if not char then return end
            local hum=char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",4); local head=char:FindFirstChild("Head") or char:WaitForChild("Head",4); if not hum or not head then return end
            local bb=Instance.new("BillboardGui"); bb.Name="MysteryRagdollCountdown"; bb.Adornee=head; bb.Size=UDim2.new(0,150,0,30); bb.StudsOffset=Vector3.new(0,5.0,0); bb.AlwaysOnTop=true; bb.LightInfluence=0; bb.Parent=head
            local lbl=Instance.new("TextLabel",bb); lbl.Name="Countdown"; lbl.Size=UDim2.fromScale(1,1); lbl.BackgroundTransparency=1; lbl.Text=""; lbl.Visible=false; lbl.TextColor3=Color3.fromRGB(80,255,120); lbl.TextStrokeColor3=Color3.fromRGB(0,0,0); lbl.TextStrokeTransparency=0; lbl.Font=Enum.Font.GothamBlack; lbl.TextSize=20
            labels[plr]=bb; conns[plr]={}
            local function begin() ends[plr]=tick()+2.6; lbl.Visible=true end
            table.insert(conns[plr],hum.StateChanged:Connect(function(_,st) if st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll then begin() end end))
            table.insert(conns[plr],char.DescendantAdded:Connect(function(d) if d:IsA("BallSocketConstraint") then begin() end end))
        end
        function _G.MysteryStopRagdollCountdown()
            if updateConn then updateConn:Disconnect(); updateConn=nil end; if addedConn then addedConn:Disconnect(); addedConn=nil end; if removeConn then removeConn:Disconnect(); removeConn=nil end
            for plr in pairs(labels) do clearPlayer(plr) end
        end
        function _G.MysteryStartRagdollCountdown()
            _G.MysteryStopRagdollCountdown(); if not State.ragdollCountdownEnabled then return end
            local function watch(plr) attach(plr,plr.Character); conns[plr]=conns[plr] or {}; table.insert(conns[plr],plr.CharacterAdded:Connect(function(char) task.defer(attach,plr,char) end)) end
            for _,plr in ipairs(Players:GetPlayers()) do watch(plr) end
            addedConn=Players.PlayerAdded:Connect(watch); removeConn=Players.PlayerRemoving:Connect(clearPlayer)
            updateConn=RunService.Heartbeat:Connect(function() local now=tick(); for plr,t in pairs(ends) do local bb=labels[plr]; local lbl=bb and bb:FindFirstChild("Countdown"); local left=t-now; if lbl then if left>0 then lbl.Visible=true; lbl.Text=string.format("RAGDOLL %.1f",left); lbl.TextColor3=left<=1 and Color3.fromRGB(255,230,90) or Color3.fromRGB(80,255,120) else lbl.Visible=false; lbl.Text=""; ends[plr]=nil end end end end)
        end
    end


-- ============================================================
-- ESP TRACKER + BOX (Trace line + square box around humanoid)
-- Box and line always follow the opponent (ragdoll / void aware).
-- ============================================================
function _safeDrawing(kind, props)
    if not Drawing or not Drawing.new then return nil end
    local ok, obj = pcall(function() return Drawing.new(kind) end)
    if not ok or not obj then return nil end
    for k, v in pairs(props or {}) do pcall(function() obj[k] = v end) end
    return obj
end

function _cleanupBoxedESPPlayer(player)
    local data = BoxedESPData[player]
    if not data then return end
    for _, obj in pairs(data) do
        pcall(function()
            if typeof(obj) == "Instance" then
                obj:Destroy()
            else
                obj.Visible = false
                if obj.Remove then obj:Remove() end
            end
        end)
    end
    BoxedESPData[player] = nil
end

function _cleanupBoxedESP()
    for player in pairs(BoxedESPData) do _cleanupBoxedESPPlayer(player) end
end

local function _ambitiousTrackerColor()
    return (BoxedESPOptions and BoxedESPOptions.trackerColor) or Color3.fromRGB(230,230,230)
end

local function _espBoxColor()
    return Color3.fromRGB(45, 205, 255)
end

-- 8 world corners of a character-sized box around the humanoid root
local function _K7GetWorldBoxCorners(root, head, hum)
    local pos = root.Position
    local topY = head and head.Position.Y + 0.6 or (pos.Y + 2.5)
    local botY = pos.Y - (hum and (hum.HipHeight + 1.2) or 3)
    local h = math.max(topY - botY, 3)
    local midY = (topY + botY) * 0.5
    local halfW = 1.6
    local halfD = 1.2
    local cf = CFrame.new(pos.X, midY, pos.Z) * (root.CFrame - root.CFrame.Position)
    local corners = {}
    for _, ox in ipairs({-halfW, halfW}) do
        for _, oy in ipairs({-h * 0.5, h * 0.5}) do
            for _, oz in ipairs({-halfD, halfD}) do
                corners[#corners + 1] = (cf * CFrame.new(ox, oy, oz)).Position
            end
        end
    end
    return corners
end

-- Project world corners -> 2D axis-aligned screen box (min/max)
local function _K7WorldCornersToScreenBox(cam, corners)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyFront = false
    for _, w in ipairs(corners) do
        local sp, on = cam:WorldToViewportPoint(w)
        if sp.Z > 0 then
            anyFront = true
            if sp.X < minX then minX = sp.X end
            if sp.Y < minY then minY = sp.Y end
            if sp.X > maxX then maxX = sp.X end
            if sp.Y > maxY then maxY = sp.Y end
        end
    end
    if not anyFront then return nil end
    -- padding
    minX, minY = minX - 2, minY - 2
    maxX, maxY = maxX + 2, maxY + 2
    return minX, minY, maxX, maxY
end

local function _K7EnsureBoxLines(data, color)
    if not data.boxLines then
        data.boxLines = {}
        for i = 1, 4 do
            data.boxLines[i] = _safeDrawing("Line", {
                Thickness = 2,
                Transparency = 0,
                Color = color,
                Visible = false,
            })
        end
    end
    return data.boxLines
end

local function _K7SetBoxLines(lines, minX, minY, maxX, maxY, color)
    if not lines then return end
    local pts = {
        Vector2.new(minX, minY), Vector2.new(maxX, minY),
        Vector2.new(maxX, maxY), Vector2.new(minX, maxY),
    }
    for i = 1, 4 do
        local a = pts[i]
        local b = pts[(i % 4) + 1]
        local ln = lines[i]
        if ln then
            pcall(function()
                ln.From = a
                ln.To = b
                ln.Color = color
                ln.Thickness = 2
                ln.Transparency = 0
                ln.Visible = true
            end)
        end
    end
end

local function _K7HideBoxLines(data)
    if data and data.boxLines then
        for _, ln in ipairs(data.boxLines) do
            pcall(function() ln.Visible = false end)
        end
    end
end

function _updateBoxedESP()
    local cam = workspace.CurrentCamera
    if not cam then return end

    local showTracker = BoxedESPOptions and BoxedESPOptions.tracker == true
    local showBox = (BoxedESPOptions and BoxedESPOptions.box == true)
        or (PlayerESP and PlayerESP.enabled == true)

    if not showTracker and not showBox then
        _cleanupBoxedESP()
        return
    end

    local myChar = LP.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local fromPoint = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y - 10)
    if myRoot then
        local myPos, onScreen = cam:WorldToViewportPoint(myRoot.Position - Vector3.new(0, 1, 0))
        if onScreen or myPos.Z > 0 then
            fromPoint = Vector2.new(myPos.X, myPos.Y)
        end
    end

    local lineColor = _ambitiousTrackerColor()
    local boxColor = _espBoxColor()
    local seen = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            seen[player] = true
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local dead = humanoid and humanoid.Health <= 0

            if not char or not root or dead then
                _cleanupBoxedESPPlayer(player)
            else
                -- Target position (chest); void ghost if available
                local torsoPos = head and ((root.Position + head.Position) / 2 + Vector3.new(0, -0.7, 0)) or root.Position
                if _G.AceVoidESP and _G.AceVoidESP.posFor then
                    local ghostPos, isGhost = _G.AceVoidESP.posFor(player, root.Position)
                    if isGhost and ghostPos then
                        torsoPos = ghostPos + Vector3.new(0, 1.2, 0)
                    end
                end

                local data = BoxedESPData[player]
                if not data then
                    data = {}
                    BoxedESPData[player] = data
                end

                -- TRACE LINE
                if showTracker then
                    local torsoScreen = cam:WorldToViewportPoint(torsoPos)
                    if not data.tracker then
                        data.tracker = _safeDrawing("Line", {
                            Thickness = 2.5,
                            Transparency = 0,
                            Color = lineColor,
                            Visible = false,
                        })
                    end
                    if data.tracker then
                        pcall(function()
                            data.tracker.Color = lineColor
                            data.tracker.Thickness = 2.5
                            data.tracker.Transparency = 0
                            data.tracker.From = fromPoint
                            data.tracker.To = Vector2.new(torsoScreen.X, torsoScreen.Y)
                            data.tracker.Visible = torsoScreen.Z > -5
                        end)
                    end
                elseif data.tracker then
                    pcall(function() data.tracker.Visible = false end)
                end

                -- SQUARE BOX around humanoid
                if showBox then
                    local useRoot = root
                    local useHead = head or root
                    if _G.AceVoidESP and _G.AceVoidESP.isOut and _G.AceVoidESP.isOut(player) then
                        local g = _G.AceVoidESP.ghostOf and _G.AceVoidESP.ghostOf(player)
                        if g then
                            -- synthetic corners around ghost
                            local h = 5
                            local corners = {
                                g + Vector3.new(-1.6, -h * 0.5, -1.2),
                                g + Vector3.new(1.6, -h * 0.5, -1.2),
                                g + Vector3.new(-1.6, h * 0.5, -1.2),
                                g + Vector3.new(1.6, h * 0.5, -1.2),
                                g + Vector3.new(-1.6, -h * 0.5, 1.2),
                                g + Vector3.new(1.6, -h * 0.5, 1.2),
                                g + Vector3.new(-1.6, h * 0.5, 1.2),
                                g + Vector3.new(1.6, h * 0.5, 1.2),
                            }
                            local minX, minY, maxX, maxY = _K7WorldCornersToScreenBox(cam, corners)
                            if minX then
                                local lines = _K7EnsureBoxLines(data, boxColor)
                                _K7SetBoxLines(lines, minX, minY, maxX, maxY, boxColor)
                            else
                                _K7HideBoxLines(data)
                            end
                        else
                            _K7HideBoxLines(data)
                        end
                    else
                        local corners = _K7GetWorldBoxCorners(useRoot, useHead, humanoid)
                        local minX, minY, maxX, maxY = _K7WorldCornersToScreenBox(cam, corners)
                        if minX then
                            local lines = _K7EnsureBoxLines(data, boxColor)
                            _K7SetBoxLines(lines, minX, minY, maxX, maxY, boxColor)
                        else
                            _K7HideBoxLines(data)
                        end
                    end
                else
                    _K7HideBoxLines(data)
                end
            end
        end
    end

    for player in pairs(BoxedESPData) do
        if not player.Parent or not seen[player] then
            _cleanupBoxedESPPlayer(player)
        end
    end
end

function refreshBoxedESP()
    if BoxedESPConn then BoxedESPConn:Disconnect(); BoxedESPConn = nil end
    local showTracker = BoxedESPOptions and BoxedESPOptions.tracker == true
    local showBox = (BoxedESPOptions and BoxedESPOptions.box == true)
        or (PlayerESP and PlayerESP.enabled == true)
    if showTracker or showBox then
        BoxedESPConn = RunService.RenderStepped:Connect(_updateBoxedESP)
        pcall(_updateBoxedESP)
    else
        _cleanupBoxedESP()
    end
end

Players.PlayerRemoving:Connect(_cleanupBoxedESPPlayer)


-- ============================================================
-- VOID ESP (portado do "Esp Void" do Ambitious)
-- Quando um inimigo e teleportado pra fora do mapa (void), congela uma
-- copia do corpo na ultima posicao valida dentro do mapa, com o mesmo
-- contorno/overhead do ESP e a palavra VOID embaixo da Speed. O ESP real
-- fica escondido para nao seguir o jogador no void.
-- Fica ativo junto com o ESP / Show Tracker (linha).
-- ============================================================
do
    -- Bounds are soft: also treat huge teleports / deep falls as void
    local MAP_BOUNDS = { MinX=-535.7, MaxX=-422.0, MinY=-7.9, MaxY=115.0, MinZ=-72.0, MaxZ=193.3 }
    local TP_TOTAL, TP_DELTA_Y, WINDOW = 80, 60, 0.08
    local WALK_CLEAR, STEP_MAX = 12, 55
    local VOID_Y_FLOOR = -40
    local VOID_FAR = 900

    local function enabled()
        return (PlayerESP and PlayerESP.enabled == true)
            or (BoxedESPOptions and BoxedESPOptions.tracker == true)
    end

    local ghost   = setmetatable({}, { __mode = "k" })
    local ghostCF = setmetatable({}, { __mode = "k" })
    local isOutOf = setmetatable({}, { __mode = "k" })
    local tracked = setmetatable({}, { __mode = "k" })

    local function isWithinBounds(pos)
        if typeof(pos) ~= "Vector3" then return false end
        if pos.Y < VOID_Y_FLOOR then return false end
        local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if myRoot and (pos - myRoot.Position).Magnitude > VOID_FAR then return false end
        -- Prefer arena box when the local player is near it; otherwise treat nearby space as valid
        local inBox = pos.X >= MAP_BOUNDS.MinX and pos.X <= MAP_BOUNDS.MaxX
           and pos.Y >= MAP_BOUNDS.MinY and pos.Y <= MAP_BOUNDS.MaxY
           and pos.Z >= MAP_BOUNDS.MinZ and pos.Z <= MAP_BOUNDS.MaxZ
        if inBox then return true end
        if myRoot then
            local nearArena = myRoot.Position.X >= (MAP_BOUNDS.MinX - 80)
                and myRoot.Position.X <= (MAP_BOUNDS.MaxX + 80)
                and myRoot.Position.Z >= (MAP_BOUNDS.MinZ - 80)
                and myRoot.Position.Z <= (MAP_BOUNDS.MaxZ + 80)
            if nearArena then
                return false -- outside arena while fighting = void candidate
            end
            return (pos - myRoot.Position).Magnitude < VOID_FAR and pos.Y > VOID_Y_FLOOR
        end
        return pos.Y > VOID_Y_FLOOR
    end

    local function isDefinitelyVoid(pos, prevPos)
        if typeof(pos) ~= "Vector3" then return false end
        if pos.Y < VOID_Y_FLOOR then return true end
        local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if myRoot and (pos - myRoot.Position).Magnitude > VOID_FAR then return true end
        if prevPos and (pos - prevPos).Magnitude >= TP_TOTAL then return true end
        if prevPos and math.abs(pos.Y - prevPos.Y) >= TP_DELTA_Y then return true end
        return false
    end

    local function trackPlayer(player)
        if player == LP then return end
        if tracked[player] then return end
        tracked[player] = true
        local history, walkedXZ, lastCheckPos = {}, 0, nil
        task.spawn(function()
            while player and player.Parent do
                if not enabled() then
                    isOutOf[player] = false
                    history, walkedXZ, lastCheckPos = {}, 0, nil
                    task.wait(0.5)
                else
                    local char = player.Character
                    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                    local hum  = char and char:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and hum.Health > 0 then
                        local now = tick()
                        local currentCFrame = hrp.CFrame
                        local currentPos = currentCFrame.Position
                        if isOutOf[player] then
                            if lastCheckPos then
                                local mv = currentPos - lastCheckPos
                                local moveXZ = Vector3.new(mv.X, 0, mv.Z).Magnitude
                                if moveXZ < STEP_MAX and isWithinBounds(currentPos) then
                                    walkedXZ = walkedXZ + moveXZ
                                end
                            end
                            lastCheckPos = currentPos
                            if walkedXZ >= WALK_CLEAR then
                                isOutOf[player] = false
                                ghost[player]   = currentPos
                                ghostCF[player] = currentCFrame
                                history, walkedXZ, lastCheckPos = {}, 0, nil
                            end
                        else
                            walkedXZ = 0
                            lastCheckPos = currentPos
                            ghost[player]   = currentPos
                            ghostCF[player] = currentCFrame
                            table.insert(history, {time = now, cframe = currentCFrame})
                            while #history > 0 and (now - history[1].time) > WINDOW do
                                table.remove(history, 1)
                            end
                            local oldest = history[1]
                            if oldest then
                                local total  = (currentPos - oldest.cframe.Position).Magnitude
                                local deltaY = math.abs(currentPos.Y - oldest.cframe.Position.Y)
                                local voidHit = total >= TP_TOTAL or deltaY >= TP_DELTA_Y
                                    or isDefinitelyVoid(currentPos, oldest.cframe.Position)
                                    or (not isWithinBounds(currentPos) and isWithinBounds(oldest.cframe.Position))
                                if voidHit then
                                    local refCFrame = oldest.cframe
                                    local refPos    = refCFrame.Position
                                    -- Freeze at last VALID in-map position
                                    local originPos = refPos
                                    if not isWithinBounds(originPos) and ghost[player] then
                                        originPos = ghost[player]
                                    end
                                    local exactCF = CFrame.new(originPos) * (refCFrame - refPos)
                                    isOutOf[player] = true
                                    ghostCF[player] = exactCF
                                    ghost[player]   = exactCF.Position
                                    history = {}
                                end
                            end
                            -- Instant void if they drop below floor while we still have a ghost
                            if isDefinitelyVoid(currentPos, ghost[player]) and ghost[player] then
                                isOutOf[player] = true
                            end
                        end
                    else
                        isOutOf[player] = false
                        history, walkedXZ, lastCheckPos = {}, 0, nil
                    end
                    RunService.Heartbeat:Wait()
                end
            end
            tracked[player] = nil
        end)
    end

    local function startAll()
        for _, plr in ipairs(Players:GetPlayers()) do trackPlayer(plr) end
    end
    Players.PlayerAdded:Connect(trackPlayer)
    startAll()

    local function posFor(player, rawPos)
        if not player or not enabled() then return rawPos, false end
        if isOutOf[player] then
            local g = ghost[player]
            if g then return g, true end
        end
        return rawPos, false
    end

    local function posForPart(part, rawPos)
        if not part then return rawPos, false end
        local model = part:FindFirstAncestorOfClass("Model")
        local player = model and Players:GetPlayerFromCharacter(model)
        return posFor(player, rawPos or part.Position)
    end

    -- ---------- REPLICA DO CORPO NA POSICAO FANTASMA ----------
    local replicas = {}
    local ghostFolder = nil

    local function ensureFolder()
        if ghostFolder and ghostFolder.Parent then return ghostFolder end
        ghostFolder = Instance.new("Folder")
        ghostFolder.Name = "AceVoidESP"
        ghostFolder.Parent = workspace
        return ghostFolder
    end

    local function setRealESP(char, visible)
        if not char then return end
        local hl = char:FindFirstChild("AmbitiousHubESP")
        if hl then pcall(function() hl.Enabled = visible end) end
        local head = char:FindFirstChild("Head")
        local tag = head and head:FindFirstChild("AmbitiousHubESPTag")
        if tag then pcall(function() tag.Enabled = visible end) end
        local spd = head and head:FindFirstChild("K7SpeedESP")
        if spd then pcall(function() spd.Enabled = visible end) end
    end

    local function clearReplica(plr)
        local r = replicas[plr]
        if r then pcall(function() r:Destroy() end) end
        replicas[plr] = nil
    end

    local function buildReplica(plr, char, cf)
        clearReplica(plr)
        -- ESP / tracker must be on (enabled() already checked by caller loop)
        if not enabled() then return end
        local ok, clone = pcall(function()
            char.Archivable = true
            return char:Clone()
        end)
        if not ok or not clone then return end
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Humanoid") then
                pcall(function() d:Destroy() end)
            elseif d:IsA("BasePart") then
                d.Anchored   = true
                d.CanCollide = false
                d.CanQuery   = false
                d.CanTouch   = false
            end
        end
        clone.Name = "GhostReplica_" .. tostring(plr.Name)
        clone.Parent = ensureFolder()
        pcall(function() clone:PivotTo(cf) end)

        local hl = clone:FindFirstChild("AmbitiousHubESP")
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "AmbitiousHubESP"
            hl.Adornee = clone
            hl.FillColor = Color3.fromRGB(20, 40, 70)
            hl.FillTransparency = 0.55
            hl.OutlineColor = Color3.fromRGB(45, 205, 255)
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = clone
        end
        pcall(function() hl.Enabled = true end)

        local cloneHead = clone:FindFirstChild("Head") or clone:FindFirstChild("HumanoidRootPart")
        if cloneHead and not cloneHead:FindFirstChild("AmbitiousHubESPTag") then
            local bb = Instance.new("BillboardGui")
            bb.Name = "AmbitiousHubESPTag"
            bb.Adornee = cloneHead
            bb.Size = UDim2.new(0, 130, 0, 40)
            bb.StudsOffset = Vector3.new(0, 2.8, 0)
            bb.AlwaysOnTop = true
            bb.LightInfluence = 0
            bb.Parent = cloneHead
            local box0 = Instance.new("Frame", bb)
            box0.Size = UDim2.new(1, 0, 1, 0)
            box0.BackgroundTransparency = 1
            local spd0 = Instance.new("TextLabel", box0)
            spd0.Name = "Speed"
            spd0.Size = UDim2.new(1, -8, 0, 18)
            spd0.Position = UDim2.new(0, 4, 0, 2)
            spd0.BackgroundTransparency = 1
            spd0.Text = "Speed: 0.0"
            spd0.TextColor3 = Color3.fromRGB(45, 205, 255)
            spd0.Font = Enum.Font.GothamBold
            spd0.TextSize = 15
            spd0.TextStrokeTransparency = 0.15
            spd0.TextStrokeColor3 = Color3.fromRGB(0, 30, 50)
        end
        local tag = cloneHead and cloneHead:FindFirstChild("AmbitiousHubESPTag")
        if tag then
            pcall(function() tag.Enabled = true end)
            local box = tag:FindFirstChildOfClass("Frame") or tag
            if box:FindFirstChild("VoidTag") then box:FindFirstChild("VoidTag"):Destroy() end
            local vl = Instance.new("TextLabel")
            vl.Name = "VoidTag"
            vl.Size = UDim2.new(1, -10, 0, 18)
            vl.Position = UDim2.new(0, 5, 0, 18)
            vl.BackgroundTransparency = 1
            vl.TextColor3 = Color3.fromRGB(45, 205, 255)
            vl.Font = Enum.Font.GothamBold
            vl.TextSize = 15
            vl.TextStrokeTransparency = 0.12
            vl.TextStrokeColor3 = Color3.fromRGB(0, 30, 50)
            vl.Text = "VOID"
            vl.Parent = box
            -- Also stamp VOID on clone head if SpeedESP exists
            local spd = cloneHead:FindFirstChild("K7SpeedESP")
            if spd then
                local existing = spd:FindFirstChild("VoidName")
                if not existing then
                    local vn = Instance.new("TextLabel")
                    vn.Name = "VoidName"
                    vn.Size = UDim2.new(1, 0, 0, 14)
                    vn.Position = UDim2.new(0, 0, 1, 0)
                    vn.BackgroundTransparency = 1
                    vn.Text = "VOID"
                    vn.TextColor3 = Color3.fromRGB(45, 205, 255)
                    vn.Font = Enum.Font.GothamBold
                    vn.TextSize = 13
                    vn.TextStrokeTransparency = 0.15
                    vn.TextStrokeColor3 = Color3.fromRGB(0, 30, 50)
                    vn.Parent = spd
                end
            end
        end
        replicas[plr] = clone
    end

    local lastTick = 0
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - lastTick < 0.1 then return end
        lastTick = now
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                local c   = plr.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                local out = enabled() and (hrp ~= nil) and (hum ~= nil) and hum.Health > 0 and isOutOf[plr] == true
                if out and ghostCF[plr] then
                    setRealESP(c, false)
                    if not replicas[plr] or not replicas[plr].Parent then
                        buildReplica(plr, c, ghostCF[plr])
                    end
                else
                    if replicas[plr] then
                        clearReplica(plr)
                        setRealESP(c, true)
                    end
                end
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(plr)
        ghost[plr] = nil
        isOutOf[plr] = nil
        ghostCF[plr] = nil
        tracked[plr] = nil
        clearReplica(plr)
    end)

    _G.AceVoidESP = {
        bounds     = MAP_BOUNDS,
        posFor     = posFor,
        posForPart = posForPart,
        isOut      = function(player) return player and isOutOf[player] == true end,
        ghostOf    = function(player) return player and ghost[player] or nil end,
        ghostCFOf  = function(player) return player and ghostCF[player] or nil end,
    }
end
-- ============================================================
-- FIM VOID ESP
-- ============================================================

-- ============================================================
-- SPEED ESP (shows "Speed: 0.0" above other players' heads)
-- ============================================================
SpeedESP = { enabled = false, gui = {}, conn = nil, last = {}, smooth = {} }

SpeedESP.removeTag = function(plr)
    local g = SpeedESP.gui[plr]
    if g then pcall(function() g:Destroy() end) end
    SpeedESP.gui[plr] = nil
    SpeedESP.last[plr] = nil
    SpeedESP.smooth[plr] = nil
    if SpeedESP.samples then SpeedESP.samples[plr] = nil end
    if SpeedESP.shown then SpeedESP.shown[plr] = nil end
end

SpeedESP.clear = function()
    for plr, _ in pairs(SpeedESP.gui) do SpeedESP.removeTag(plr) end
    SpeedESP.gui = {}
    SpeedESP.last = {}
    SpeedESP.smooth = {}
    SpeedESP.samples = {}
    SpeedESP.shown = {}
end

SpeedESP.makeTag = function(plr, head)
    SpeedESP.removeTag(plr)
    local bb = Instance.new("BillboardGui")
    bb.Name = "K7SpeedESP"
    bb.Adornee = head
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 140, 0, 26)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
    bb.ResetOnSpawn = false
    local lbl = Instance.new("TextLabel")
    lbl.Name = "SpeedLabel"
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = false
    lbl.TextSize = 15
    lbl.TextColor3 = Color3.fromRGB(45, 205, 255)
    lbl.TextStrokeTransparency = 0.15
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 30, 50)
    lbl.Text = "Speed: 0.0"
    lbl.Parent = bb
    bb.Parent = head
    SpeedESP.gui[plr] = bb
    return bb
end

-- ============================================================
-- SPEED ESP (medidor estavel)
-- Mede pelo deslocamento real numa janela de tempo (0.20s).
-- Ignora teleporte/lag spike e nunca fica preso em 0.0.
-- ============================================================
SpeedESP.samples = SpeedESP.samples or {}
SpeedESP.shown   = SpeedESP.shown or {}
SpeedESP.WINDOW  = 0.20      -- janela de medicao
SpeedESP.MAXSPD  = 400       -- acima disso e teleporte, descarta

SpeedESP.update = function()
    if not SpeedESP.enabled then return end
    local now = tick()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local char = plr.Character
            local head = char and char:FindFirstChild("Head")
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if head and hrp then
                local bb = SpeedESP.gui[plr]
                if not bb or bb.Parent ~= head then bb = SpeedESP.makeTag(plr, head) end
                local lbl = bb and bb:FindFirstChild("SpeedLabel")
                if lbl then
                    local pos = hrp.Position
                    local buf = SpeedESP.samples[plr]
                    if not buf then buf = {}; SpeedESP.samples[plr] = buf end
                    buf[#buf + 1] = {p = pos, t = now}
                    -- mantem somente a janela
                    while #buf > 2 and (now - buf[1].t) > (SpeedESP.WINDOW * 1.6) do
                        table.remove(buf, 1)
                    end

                    -- velocidade da janela (mais estavel que frame a frame)
                    local winSpd = nil
                    local first = buf[1]
                    local dt = now - first.t
                    if dt >= 0.06 then
                        local d = pos - first.p
                        local flat = Vector3.new(d.X, 0, d.Z).Magnitude / dt
                        if flat == flat and flat < SpeedESP.MAXSPD then
                            winSpd = flat
                        end
                    end

                    -- velocidade replicada (quando existe, ajuda a confirmar)
                    local v = hrp.AssemblyLinearVelocity
                    local repSpd = Vector3.new(v.X, 0, v.Z).Magnitude
                    if repSpd ~= repSpd or repSpd >= SpeedESP.MAXSPD then repSpd = nil end

                    local raw = winSpd
                    if raw == nil then raw = repSpd end
                    if raw ~= nil and repSpd ~= nil then
                        -- usa a maior das duas leituras validas (a replicada as vezes vem 0)
                        if repSpd > raw then raw = repSpd end
                    end

                    if raw ~= nil then
                        -- suavizacao leve: segue rapido, sem pular entre varias speeds
                        local prev = SpeedESP.smooth[plr]
                        if prev == nil or math.abs(raw - prev) > 12 then
                            SpeedESP.smooth[plr] = raw
                        else
                            SpeedESP.smooth[plr] = prev + (raw - prev) * 0.35
                        end
                    end

                    local spd = SpeedESP.smooth[plr] or 0
                    if spd < 0.15 then spd = 0 end

                    -- velocidade REAL da pessoa com uma casa decimal (ex.: 24.9)
                    local exact = math.floor(spd * 10 + 0.5) / 10

                    -- estabilidade: so redesenha quando o valor muda de verdade
                    local shown = SpeedESP.shown[plr]
                    local prevExact = shown and shown.v or nil
                    if prevExact ~= nil and math.abs(exact - prevExact) < 0.1 then
                        exact = prevExact
                    end

                    if (not shown) or (now - shown.t) >= 0.10 or exact ~= prevExact then
                        SpeedESP.shown[plr] = {t = now, v = exact}
                        lbl.Text = string.format("Speed: %.1f", exact)
                        lbl.TextColor3 = Color3.fromRGB(45, 205, 255)
                    end
                end
            else
                SpeedESP.removeTag(plr)
                SpeedESP.samples[plr] = nil
                SpeedESP.shown[plr] = nil
            end
        end
    end
end

SpeedESP.start = function()
    SpeedESP.enabled = true
    if not SpeedESP.conn then
        SpeedESP.conn = RunService.RenderStepped:Connect(SpeedESP.update)
    end
end

SpeedESP.stop = function()
    SpeedESP.enabled = false
    if SpeedESP.conn then pcall(function() SpeedESP.conn:Disconnect() end); SpeedESP.conn = nil end
    SpeedESP.clear()
end

Players.PlayerRemoving:Connect(_removeSpeedTag)




-- ============================================================
-- AUTO LEFT / AUTO RIGHT (from Zombie Hub)
-- ============================================================
AP_L1 = Vector3.new(-476.48, -6.28, 92.73)
AP_L2 = Vector3.new(-483.12, -4.95, 94.80)
AP_L_FACE = Vector3.new(-482.25, -4.96, 92.09)
AP_R1 = Vector3.new(-476.16, -6.52, 25.62)
AP_R2 = Vector3.new(-483.06, -5.03, 25.48)
AP_R_FACE = Vector3.new(-482.06, -6.93, 35.47)
alConn, arConn = nil, nil
alPhase, arPhase = 1, 1

function _apKillSpeedEngine()
    if _G.__K7CleanupSpeedPhysics then pcall(_G.__K7CleanupSpeedPhysics) end
end

function _apMoveTo(hum, hrp, target, spd)
    local d = target - hrp.Position
    local mv = Vector3.new(d.X, 0, d.Z)
    if mv.Magnitude <= 0.05 then return end
    mv = mv.Unit
    pcall(function() if hrp.SetNetworkOwner then hrp:SetNetworkOwner(LP) end end)
    if hum.WalkSpeed < spd then hum.WalkSpeed = spd end
    hum:Move(mv, false)
    hrp.AssemblyLinearVelocity = Vector3.new(mv.X * spd, hrp.AssemblyLinearVelocity.Y, mv.Z * spd)
end

function _apFace(hrp, facePoint)
    local facePos = Vector3.new(facePoint.X, hrp.Position.Y, facePoint.Z)
    if (facePos - hrp.Position).Magnitude > 0.01 then
        pcall(function() hrp.CFrame = CFrame.new(hrp.Position, facePos) end)
    end
end

function stopAutoLeft()
    if alConn then alConn:Disconnect(); alConn = nil end
    State.autoLeftEnabled = false
    alPhase = 1
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum:Move(Vector3.zero, false) end
    if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0) end
    if stackBtnRefs and stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end
    if _G.__K7SpeedFlush then pcall(_G.__K7SpeedFlush) end
    -- Carry Mode is left exactly as the user set it.
end

function stopAutoRight()
    if arConn then arConn:Disconnect(); arConn = nil end
    State.autoRightEnabled = false
    arPhase = 1
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum:Move(Vector3.zero, false) end
    if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0) end
    if stackBtnRefs and stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end
    if _G.__K7SpeedFlush then pcall(_G.__K7SpeedFlush) end
    -- Carry Mode is left exactly as the user set it.
end

function startAutoLeft()
    if antiKickEnabled and _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
        _G.AceSafeModeForceStop("SAFE MODE LOCK")
        return
    end
    if State.autoRightEnabled then stopAutoRight() end
    if alConn then alConn:Disconnect(); alConn = nil end
    alPhase = 1
    State.autoLeftEnabled = true
    _apKillSpeedEngine()
    if stackBtnRefs and stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(true) end
    alConn = RunService.Heartbeat:Connect(function()
        if not State.autoLeftEnabled then return end
        if antiKickEnabled and _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
            stopAutoLeft()
            return
        end
        local char = LP.Character
        if not char then return end
        local hrp2 = char:FindFirstChild("HumanoidRootPart")
        local hum2 = char:FindFirstChildOfClass("Humanoid")
        if not hrp2 or not hum2 or hum2.Health <= 0 then return end
        local spd = State.normalSpeed or 60
        if alPhase == 1 then
            local tgt = Vector3.new(AP_L1.X, hrp2.Position.Y, AP_L1.Z)
            if (tgt - hrp2.Position).Magnitude < 1 then
                alPhase = 2
                _apMoveTo(hum2, hrp2, AP_L2, spd)
                return
            end
            _apMoveTo(hum2, hrp2, AP_L1, spd)
        else
            local tgt = Vector3.new(AP_L2.X, hrp2.Position.Y, AP_L2.Z)
            if (tgt - hrp2.Position).Magnitude < 1 then
                hum2:Move(Vector3.zero, false)
                hrp2.AssemblyLinearVelocity = Vector3.new(0, hrp2.AssemblyLinearVelocity.Y, 0)
                stopAutoLeft()
                _apFace(hrp2, AP_L_FACE)
                return
            end
            _apMoveTo(hum2, hrp2, AP_L2, spd)
        end
    end)
end

function startAutoRight()
    if antiKickEnabled and _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
        _G.AceSafeModeForceStop("SAFE MODE LOCK")
        return
    end
    if State.autoLeftEnabled then stopAutoLeft() end
    if arConn then arConn:Disconnect(); arConn = nil end
    arPhase = 1
    State.autoRightEnabled = true
    _apKillSpeedEngine()
    if stackBtnRefs and stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(true) end
    arConn = RunService.Heartbeat:Connect(function()
        if not State.autoRightEnabled then return end
        if antiKickEnabled and _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
            stopAutoRight()
            return
        end
        local char = LP.Character
        if not char then return end
        local hrp2 = char:FindFirstChild("HumanoidRootPart")
        local hum2 = char:FindFirstChildOfClass("Humanoid")
        if not hrp2 or not hum2 or hum2.Health <= 0 then return end
        local spd = State.normalSpeed or 60
        if arPhase == 1 then
            local tgt = Vector3.new(AP_R1.X, hrp2.Position.Y, AP_R1.Z)
            if (tgt - hrp2.Position).Magnitude < 1 then
                arPhase = 2
                _apMoveTo(hum2, hrp2, AP_R2, spd)
                return
            end
            _apMoveTo(hum2, hrp2, AP_R1, spd)
        else
            local tgt = Vector3.new(AP_R2.X, hrp2.Position.Y, AP_R2.Z)
            if (tgt - hrp2.Position).Magnitude < 1 then
                hum2:Move(Vector3.zero, false)
                hrp2.AssemblyLinearVelocity = Vector3.new(0, hrp2.AssemblyLinearVelocity.Y, 0)
                stopAutoRight()
                _apFace(hrp2, AP_R_FACE)
                return
            end
            _apMoveTo(hum2, hrp2, AP_R2, spd)
        end
    end)
end

-- ============================================================
-- ZOMBIE BAT AIMBOT (keeps existing aimbots separate)
-- ============================================================
-- BAT AIMBOT BYPASS (portado do Adapt Source - Anti Bypass)
ZBat = {
    on = false,
    conn = nil,
    swingCooldown = false,
    prevAutoRotate = nil,
    SPEED = 63,
    VERT_SPEED = 52,
    DISTANCE = -2.8,
    HEIGHT = 4.75,
    V_OFFSET = 1,
    TURN_SPEED = 285,
    MAX_TURN_RATE = 28,
    AUTO_SWING = true,
}
_G._7upBypassBatAimbot = ZBat

BypassSlapList = {
    "Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap",
    "Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap",
}

function zFindBat()
    local char = LP.Character
    if not char then return nil end
    for _, name in ipairs(BypassSlapList) do
        local t = char:FindFirstChild(name)
        if t and t:IsA("Tool") then return t end
    end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("bat") or n:find("slap") then return tool end
        end
    end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("bat") or n:find("slap") then return tool end
            end
        end
    end
    return nil
end

function zEnsureBat()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum then return nil end
    local equipped = char:FindFirstChildOfClass("Tool")
    if equipped then return equipped end
    local bat = zFindBat()
    if bat then pcall(function() hum:EquipTool(bat) end) end
    return bat
end

function zTrySwing()
    if _G.AceBatSwingBlocked and _G.AceBatSwingBlocked() then return end
    if ZBat.swingCooldown then return end
    ZBat.swingCooldown = true
    pcall(function()
        local bat = zEnsureBat()
        if bat and bat:IsA("Tool") then bat:Activate() end
    end)
    task.delay(0.3, function() if ZBat then ZBat.swingCooldown = false end end)
end

function zGetTarget()
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil, math.huge end
    local closest, minDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tRoot and hum and hum.Health > 0 then
                local d = (tRoot.Position - root.Position).Magnitude
                if d < minDist then minDist = d; closest = tRoot end
            end
        end
    end
    return closest, minDist
end

function startZombieBatAimbot()
    if antiKickEnabled and _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
        _G.AceSafeModeForceStop("SAFE MODE LOCK")
        return
    end
    pcall(function() if _G.AceStopNormalAimbot then _G.AceStopNormalAimbot() end end)
    pcall(function() if _G.AceAntiDesyncAimbotOn and _G.AceStopAntiDesyncAimbot then _G.AceStopAntiDesyncAimbot() end end)
    ZBat.on = true
    State.batAimbotZombie = true
    if ZBat.conn then ZBat.conn:Disconnect(); ZBat.conn = nil end
    if State.autoLeftEnabled then stopAutoLeft() end
    if State.autoRightEnabled then stopAutoRight() end

    local hum0 = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum0 then
        ZBat.prevAutoRotate = hum0.AutoRotate
        hum0.AutoRotate = false
    end

    ZBat.conn = RunService.Heartbeat:Connect(function()
        if not ZBat.on or not State.batAimbotZombie then return end
        if antiKickEnabled and _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
            stopZombieBatAimbot()
            return
        end
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not hum or not root or hum.Health <= 0 then return end
        local S = ZBat
        hum.AutoRotate = false
        zEnsureBat()
        local target, targetDist = zGetTarget()
        if not target then
            root.AssemblyAngularVelocity = Vector3.zero
            return
        end
        local aimTargetPos = target.Position + Vector3.new(0, S.V_OFFSET, 0)
        local look = aimTargetPos - root.Position
        local flatLook = Vector3.new(look.X, 0, look.Z)
        if flatLook.Magnitude > 0.01 then
            local targetYaw = math.deg(math.atan2(-flatLook.X, -flatLook.Z))
            local yawDelta = (targetYaw - root.Orientation.Y + 180) % 360 - 180
            local yawRate = math.clamp(yawDelta * 8, -S.MAX_TURN_RATE, S.MAX_TURN_RATE)
            root.AssemblyAngularVelocity = Vector3.new(0, yawRate, 0)
        else
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if look.Magnitude > 0.01 then
            local dir = look.Unit
            local standPos = aimTargetPos - (dir * S.DISTANCE) + Vector3.new(0, S.HEIGHT, 0)
            local moveDir = standPos - root.Position
            local hDir = Vector3.new(moveDir.X, 0, moveDir.Z)
            local speed = (_G.AceGetActiveAimbotSpeed and _G.AceGetActiveAimbotSpeed())
                or (_G.AceGetNormalAimbotSpeed and _G.AceGetNormalAimbotSpeed()) or S.SPEED
            local vertMax = S.VERT_SPEED * (speed / ((tonumber(S.SPEED) or 63) > 0 and tonumber(S.SPEED) or 63))
            vertMax = math.clamp(vertMax, 10, 400)
            local hVel = hDir.Magnitude > 0.1 and hDir.Unit * speed or Vector3.zero
            local vVel = Vector3.new(0, math.clamp(moveDir.Y * 3, -vertMax, vertMax), 0)
            root.AssemblyLinearVelocity = hVel + vVel
            if hDir.Magnitude > 0.5 then hum:Move(hDir.Unit, false) end
        end
        if S.AUTO_SWING and State.autoSwingEnabled and targetDist < 5 then zTrySwing() end
    end)
end

function stopZombieBatAimbot()
    ZBat.on = false
    State.batAimbotZombie = false
    if ZBat.conn then ZBat.conn:Disconnect(); ZBat.conn = nil end
    ZBat.swingCooldown = false
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if root then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    if hum then
        hum.AutoRotate = (ZBat.prevAutoRotate == nil) and true or ZBat.prevAutoRotate
    end
    ZBat.prevAutoRotate = nil
end

-- BAT V2 agora roda o motor portado do Ambitious (chase + TP Bat).
startZombieBatAimbot = function() return _G.AceStartBatAimbotV2() end
stopZombieBatAimbot  = function() return _G.AceStopBatAimbotV2() end
_G._7upStartZombieBatAimbot = startZombieBatAimbot
_G._7upStopZombieBatAimbot = stopZombieBatAimbot
_G._7upStopAutoLeft = stopAutoLeft
_G._7upStopAutoRight = stopAutoRight


-- ============================================================
-- MAIN FUNCTION
-- ============================================================
function Main()
    if _G.SevenUpDuelsV2_MainExecuted then return end
    _G.SevenUpDuelsV2_MainExecuted = true

    local gui=Instance.new("ScreenGui")
    gui.Name="SevenUpDuelsV2"; gui.ResetOnSpawn=false; gui.DisplayOrder=10
    gui.IgnoreGuiInset=true; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    gui.Parent=LP:WaitForChild("PlayerGui")

    -- Floating stack buttons live in their OWN ScreenGui with a very high
    -- DisplayOrder (parented to gethui/CoreGui when the executor allows it),
    -- so they always render one layer ABOVE any other script's UI.
    local stackGui=Instance.new("ScreenGui")
    stackGui.Name="SevenUpStackButtons"; stackGui.ResetOnSpawn=false
    stackGui.DisplayOrder=999999
    stackGui.IgnoreGuiInset=true; stackGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    local stackParented=pcall(function()
        stackGui.Parent=(typeof(gethui)=="function" and gethui()) or game:GetService("CoreGui")
    end)
    if not stackParented or not stackGui.Parent then
        stackGui.Parent=LP:WaitForChild("PlayerGui")
    end
    _G._K7StackGui=stackGui
    -- Main UI scaling is isolated from mobile/stack buttons.
    local uiScaleObj=nil
    local updateLaggerButtons, setLaggerMode

    local function makeDraggable(frame,handle)
        local src=handle or frame
        local dragging,dragInput,dragStart,startPos=false,nil,nil,nil
        src.InputBegan:Connect(function(inp)
            if State.uiLocked then return end
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
                dragging=true; dragStart=inp.Position; startPos=frame.Position
                inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging=false end end)
            end
        end)
        src.InputChanged:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then dragInput=inp end
        end)
        UIS.InputChanged:Connect(function(inp)
            if inp==dragInput and dragging and not State.uiLocked then
                local dx=inp.Position.X-dragStart.X; local dy=inp.Position.Y-dragStart.Y
                local nsx=startPos.X.Scale; local nx=startPos.X.Offset+dx
                local nsy=startPos.Y.Scale; local ny=startPos.Y.Offset+dy
                -- Allow the window to be dragged partially OFF screen.
                -- Only a small handle stays grabbable so it can always come back.
                local cam=workspace.CurrentCamera
                if cam then
                    local vp=cam.ViewportSize
                    local sc=1
                    local scObj=frame:FindFirstChildWhichIsA("UIScale")
                    if scObj then sc=scObj.Scale end
                    local w=frame.Size.X.Offset*sc
                    local h=frame.Size.Y.Offset*sc
                    local KEEP=48
                    nx=math.clamp(vp.X*nsx+nx,-(math.max(0,w-KEEP)),math.max(0,vp.X-KEEP)); nsx=0
                    ny=math.clamp(vp.Y*nsy+ny,-(math.max(0,h-KEEP)),math.max(0,vp.Y-KEEP)); nsy=0
                end
                frame.Position=UDim2.new(nsx,nx,nsy,ny)
                pcall(function()
                    local pos = frame.Position
                    local posData = {x = pos.X.Offset, y = pos.Y.Offset}
                    _writefile("sevenup_gui_pos.json", HttpService:JSONEncode(posData))
                end)
            end
        end)
    end

    local function animateFloatingButton(frame)
        if not frame or not frame.Parent then return end
        local scaleObj = frame:FindFirstChild("MobileButtonOnlyScale")
        if not (scaleObj and scaleObj:IsA("UIScale")) then return end
        local restScale = math.clamp(tonumber(stackButtonScale) or 1, 0.6, 1.5)
        local animationId = (tonumber(frame:GetAttribute("TapAnimationId")) or 0) + 1
        frame:SetAttribute("TapAnimationId", animationId)
        pcall(function()
            local pressTween = TweenService:Create(scaleObj, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = restScale * 0.88})
            pressTween:Play()
            pressTween.Completed:Wait()
            if frame:GetAttribute("TapAnimationId") ~= animationId or not frame.Parent then return end
            TweenService:Create(scaleObj, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = restScale}):Play()
        end)
    end

    local function makeStackDraggable(frame, onTap)
        local dragStartPos, startPos = nil, nil
        local isDragging = false
        local movedEnough = false
        local wasPressed = false
        local pressTime = 0
        local movementAllowed = not State.stackButtonsLocked
        local saveDebounce = nil
        local activeInput = nil
        local moveConn, endConn = nil, nil

        local lockChangedConn = RunService.Heartbeat:Connect(function()
            movementAllowed = not State.stackButtonsLocked
        end)

        local function savePosNow()
            pcall(saveStackPositionsNow)
            if saveDebounce then task.cancel(saveDebounce) end
            saveDebounce = task.delay(0.2, function()
                pcall(function()
                    if requestSave then requestSave() end
                end)
                saveDebounce = nil
            end)
        end

        local function stopDrag(input)
            if not isDragging then return end
            if activeInput and input and activeInput ~= input then return end
            local wasPressedLocal = wasPressed
            local didMove = movedEnough
            wasPressed = false
            isDragging = false
            activeInput = nil
            if moveConn then moveConn:Disconnect(); moveConn = nil end
            if endConn then endConn:Disconnect(); endConn = nil end


            if didMove then
                savePosNow()
            elseif wasPressedLocal and (tick() - pressTime) < 0.35 then
                task.spawn(animateFloatingButton, frame)
                if onTap then onTap() end
            end
        end

        frame.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            if isDragging then return end
            wasPressed = true
            pressTime = tick()
            dragStartPos = input.Position
            startPos = frame.Position
            isDragging = true
            movedEnough = false
            activeInput = input

            if moveConn then moveConn:Disconnect() end
            if endConn then endConn:Disconnect() end
            moveConn = UIS.InputChanged:Connect(function(inp)
                if not isDragging or not movementAllowed then return end
                if inp ~= activeInput and inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then return end
                if activeInput and inp.UserInputType == Enum.UserInputType.Touch and inp ~= activeInput then return end
                local pos = inp.Position
                local delta = pos - dragStartPos
                if delta.Magnitude > 6 then movedEnough = true end
                if movedEnough then
                    frame.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + delta.X,
                        startPos.Y.Scale, startPos.Y.Offset + delta.Y
                    )
                end
            end)
            endConn = UIS.InputEnded:Connect(function(inp)
                if inp == activeInput or (activeInput == nil and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch)) then
                    stopDrag(inp)
                end
            end)
        end)

        frame.AncestryChanged:Connect(function()
            if not frame.Parent then
                lockChangedConn:Disconnect()
                if moveConn then moveConn:Disconnect() end
                if endConn then endConn:Disconnect() end
            end
        end)
    end

    -- ============================================================
    -- UI CREATION - green theme
    -- ============================================================
    local WIN_W = 460
    local WIN_H = 590
    local TITLE_H = 44
    local mainOuter = Instance.new("Frame", gui)
    mainOuter.Name = "MainOuter"
    mainOuter.Size = UDim2.new(0, WIN_W, 0, WIN_H)
    uiScaleObj=Instance.new("UIScale",mainOuter)
    uiScaleObj.Name="MainUIOnlyScale"
    uiScaleObj.Scale = math.clamp(tonumber(_G._K7MenuScale) or 1, 0.4, 1.5)
    _G._K7MenuScale = 0.9
    
    local savedPos = UDim2.new(0, 10, 0.5, -WIN_H/2 + 40)
    pcall(function()
        if _isfile("sevenup_gui_pos.json") then
            local posData = HttpService:JSONDecode(_readfile("sevenup_gui_pos.json"))
            if posData and posData.x and posData.y then
                savedPos = UDim2.new(0, posData.x, 0, posData.y)
            end
        end
    end)
    mainOuter.Position = savedPos
    _G._K7MainFrame = mainOuter
    -- Mobile: start compact enough for portrait screens, then auto-fit.
    if _G._K7IsMobile then
        _G._K7MenuScale = 0.72
        pcall(function() uiScaleObj.Scale = 0.72 end)
    end

    -- ── Auto-fit: the menu always adapts to the player's screen/DPI ──
    local function clampMenuIntoScreen()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local sc = (uiScaleObj and uiScaleObj.Scale) or 1
        local pos = mainOuter.Position
        local w, h = WIN_W*sc, WIN_H*sc
        local KEEP = 48
        local ax = math.clamp(vp.X*pos.X.Scale + pos.X.Offset, -(math.max(0, w - KEEP)), math.max(0, vp.X - KEEP))
        local ay = math.clamp(vp.Y*pos.Y.Scale + pos.Y.Offset, -(math.max(0, h - KEEP)), math.max(0, vp.Y - KEEP))
        mainOuter.Position = UDim2.new(0, ax, 0, ay)
    end
    local function fitMenuToScreen()
        local cam = workspace.CurrentCamera
        if not (cam and uiScaleObj) then return end
        local vp = cam.ViewportSize
        local desired = tonumber(_G._K7MenuScale) or 1
        if _G._K7IsMobile and not _G._K7MenuScaleManual then desired = math.min(desired, 0.82) end
        if _G._K7MenuScaleManual then
            -- The user picked a size by hand: always honour it.
            uiScaleObj.Scale = math.clamp(desired, 0.35, 1.5)
        else
            local fit = math.min((vp.X - 16)/WIN_W, (vp.Y - 16)/WIN_H)
            uiScaleObj.Scale = math.clamp(math.min(desired, fit), 0.35, 1.5)
        end
        clampMenuIntoScreen()
    end
    local function hookViewportFit(cam)
        if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitMenuToScreen) end
    end
    hookViewportFit(workspace.CurrentCamera)
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() hookViewportFit(workspace.CurrentCamera) end)
    task.defer(fitMenuToScreen)
    _G._K7FitMenuToScreen = fitMenuToScreen

    mainOuter.BackgroundColor3 = Color3.fromRGB(28,39,32); mainOuter.BackgroundTransparency = 1; mainOuter.BorderSizePixel = 0; mainOuter.ClipsDescendants = false
    mkCorner(mainOuter, 12); makeDraggable(mainOuter)
    local mainOuterStroke = Instance.new("UIStroke", mainOuter)
    mainOuterStroke.Thickness = 2.4
    mainOuterStroke.Color = Color3.fromRGB(100, 220, 255)
    mainOuterStroke.Transparency = 0.08
    local mainBorderGradient = Instance.new("UIGradient", mainOuterStroke)
    mainBorderGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 160, 255)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(180, 245, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 190, 255)),
    })
    local innerBorder = Instance.new("Frame",mainOuter)
    innerBorder.Name = "InnerBorder"
    innerBorder.Size = UDim2.new(1,-10,1,-10); innerBorder.Position = UDim2.new(0,5,0,5)
    innerBorder.BackgroundTransparency = 1; innerBorder.BorderSizePixel = 0; innerBorder.ZIndex = 3
    mkCorner(innerBorder,10)
    local innerStroke = Instance.new("UIStroke",innerBorder)
    innerStroke.Thickness = 1; innerStroke.Transparency = 1; innerStroke.Color = Color3.fromRGB(58, 58, 58)
    local innerGradient = Instance.new("UIGradient",innerStroke)
    innerGradient.Color = ColorSequence.new(Color3.fromRGB(141, 141, 141),Color3.fromRGB(136, 136, 136))
    for _, sideX in ipairs({7, WIN_W-13}) do
        local sideRail=Instance.new("Frame",mainOuter)
        sideRail.Name="CanSideRail"; sideRail.Size=UDim2.new(0,6,1,-38); sideRail.Position=UDim2.new(0,sideX,0,19)
        sideRail.BackgroundColor3=sideX < WIN_W/2 and Color3.fromRGB(255,255,255) or Color3.fromRGB(26, 26, 26)
        sideRail.BackgroundTransparency=sideX < WIN_W/2 and 0.72 or 0.42
        sideRail.BorderSizePixel=0; sideRail.ZIndex=4; mkCorner(sideRail,3)
        sideRail.Visible=false
        local railGradient=Instance.new("UIGradient",sideRail)
        railGradient.Color=ColorSequence.new(Color3.fromRGB(112, 112, 112),Color3.fromRGB(255,255,255)); railGradient.Rotation=90
    end
    for _, rimY in ipairs({3, WIN_H-21}) do
        local canRim=Instance.new("Frame",mainOuter)
        local isTop = rimY == 3
        canRim.Name="CanRim"; canRim.Size=isTop and UDim2.new(1,-58,0,18) or UDim2.new(1,-20,0,18)
        canRim.Position=isTop and UDim2.new(0,29,0,rimY) or UDim2.new(0,10,0,rimY)
        canRim.BackgroundColor3=Color3.fromRGB(146,159,150); canRim.BackgroundTransparency=0
        canRim.BorderSizePixel=0; canRim.ZIndex=4; mkCorner(canRim,9)
        canRim.Visible=false
        local rimGradient=Instance.new("UIGradient",canRim)
        rimGradient.Color=ColorSequence.new(Color3.fromRGB(66,82,72),Color3.fromRGB(178,189,181))
    end
    local pullTab=Instance.new("Frame",mainOuter)
    pullTab.Name="CanPullTab"; pullTab.Size=UDim2.new(0,72,0,9); pullTab.Position=UDim2.new(0.5,-36,0,7)
    pullTab.BackgroundColor3=Color3.fromRGB(66,78,70); pullTab.BorderSizePixel=0; pullTab.ZIndex=5; mkCorner(pullTab,5)
    pullTab.Visible=false
    _G._K7MainOuter = mainOuter

    -- Stable scale-only animation. Reuse the menu's existing UIScale instead
    -- of stacking a second UIScale, which could leave descendants scattered.
    local menuTween = nil
    local menuAnimationId = 0
    local menuRestPosition = mainOuter.Position
    local menuRestScale = uiScaleObj.Scale

    local function getSavedRestPosition()
        local pos = nil
        pcall(function()
            if _isfile("sevenup_gui_pos.json") then
                local posData = HttpService:JSONDecode(_readfile("sevenup_gui_pos.json"))
                if posData and posData.x and posData.y then
                    pos = UDim2.new(0, posData.x, 0, posData.y)
                end
            end
        end)
        return pos or menuRestPosition
    end

    local function cancelMenuTween()
        menuAnimationId = menuAnimationId + 1
        if menuTween then
            pcall(function() menuTween:Cancel() end)
            menuTween = nil
        end
    end

    local function animateMenuOpen()
        if not mainOuter or not uiScaleObj then return end
        cancelMenuTween()
        local animationId = menuAnimationId
        menuRestPosition = getSavedRestPosition()
        mainOuter.Position = menuRestPosition
        mainOuter.Rotation = 0
        mainOuter.ClipsDescendants = true
        mainOuter.Visible = true

        -- Recalculate the configured size before the grow animation.
        fitMenuToScreen()
        menuRestScale = uiScaleObj.Scale
        uiScaleObj.Scale = math.max(0.05, menuRestScale * 0.18)
        menuTween = TweenService:Create(
            uiScaleObj,
            TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Scale = menuRestScale}
        )
        menuTween:Play()
        menuTween.Completed:Connect(function(playbackState)
            if playbackState == Enum.PlaybackState.Completed
                and animationId == menuAnimationId and State.guiVisible then
                uiScaleObj.Scale = menuRestScale
                mainOuter.Position = menuRestPosition
                mainOuter.ClipsDescendants = false
                menuTween = nil
            end
        end)
    end

    local function animateMenuClose()
        if not mainOuter or not uiScaleObj then return end
        cancelMenuTween()
        local animationId = menuAnimationId
        menuRestPosition = getSavedRestPosition()
        mainOuter.Position = menuRestPosition
        mainOuter.Rotation = 0
        mainOuter.ClipsDescendants = true
        mainOuter.Visible = true
        menuRestScale = math.max(0.05, uiScaleObj.Scale)

        menuTween = TweenService:Create(
            uiScaleObj,
            TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {Scale = math.max(0.05, menuRestScale * 0.18)}
        )
        menuTween:Play()
        menuTween.Completed:Connect(function(playbackState)
            if playbackState == Enum.PlaybackState.Completed
                and animationId == menuAnimationId and not State.guiVisible then
                mainOuter.Visible = false
                uiScaleObj.Scale = menuRestScale
                mainOuter.Position = menuRestPosition
                mainOuter.ClipsDescendants = false
                menuTween = nil
            end
        end)
    end

    local function setMenuVisible(visible)
        State.guiVisible = visible == true
        if State.guiVisible then animateMenuOpen() else animateMenuClose() end
        if _G.GreenDuelsQAHide then pcall(_G.GreenDuelsQAHide, not State.guiVisible) end
    end
    _G._K7AnimateMenuOpen = animateMenuOpen
    _G._K7AnimateMenuClose = animateMenuClose
    _G._K7SetMenuVisible = setMenuVisible
    _G._K7GetMenuRestPosition = function()
        if menuTween then return menuRestPosition end
        return mainOuter.Position
    end

    local toggleBtn = Instance.new("TextButton", gui)
    toggleBtn.Name = "K7Toggle"
    toggleBtn.Size = UDim2.new(0, 120, 0, 38)
    toggleBtn.Position = UDim2.new(0, 12, 0, 50)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(4, 48, 62)
    toggleBtn.BackgroundTransparency = 0
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = "venom.vs"
    toggleBtn.TextColor3 = Color3.fromRGB(45, 225, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 16
    toggleBtn.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextStrokeTransparency = 0
    toggleBtn:SetAttribute("MysteryVsGlowText", true)
    toggleBtn.ZIndex = 30
    mkCorner(toggleBtn, 19)
    local toggleStroke = Instance.new("UIStroke",toggleBtn)
    toggleStroke.Name = "K7ToggleWhiteBorder"
    toggleStroke.Color = Color3.fromRGB(255, 255, 255); toggleStroke.Thickness = 2; toggleStroke.Transparency = 0
    local toggleScale = Instance.new("UIScale",toggleBtn)

    toggleBtn.MouseEnter:Connect(function()
        TweenService:Create(toggleBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.1, TextColor3 = currentColorScheme.mainLight}):Play()
        TweenService:Create(toggleScale,TweenInfo.new(0.15,Enum.EasingStyle.Back),{Scale=1.06}):Play()
        TweenService:Create(toggleStroke,TweenInfo.new(0.15),{Thickness=2,Transparency=0}):Play()
    end)
    toggleBtn.MouseLeave:Connect(function()
        TweenService:Create(toggleBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.25, TextColor3 = currentColorScheme.main}):Play()
        TweenService:Create(toggleScale,TweenInfo.new(0.15),{Scale=1}):Play()
        TweenService:Create(toggleStroke,TweenInfo.new(0.15),{Thickness=1.5,Transparency=0.12}):Play()
    end)
    toggleBtn.MouseButton1Down:Connect(function() TweenService:Create(toggleScale,TweenInfo.new(0.07),{Scale=0.92}):Play() end)
    toggleBtn.MouseButton1Up:Connect(function() TweenService:Create(toggleScale,TweenInfo.new(0.14,Enum.EasingStyle.Back),{Scale=1.04}):Play() end)

    local function toggleMainUI()
        setMenuVisible(not State.guiVisible)
        requestSave()
    end
    local toggleDragBlocked = false
    do
        local dragging,moved,startIn,startPos = false,false,nil,nil
        local mConn,eConn = nil,nil
        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            if State.stackButtonsLocked then return end
            dragging,moved = true,false
            startIn,startPos = input.Position, toggleBtn.Position
            if mConn then mConn:Disconnect() end
            mConn = UIS.InputChanged:Connect(function(inp)
                if not dragging then return end
                if inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then return end
                local d = inp.Position - startIn
                if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then moved = true end
                if moved then
                    toggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
                end
            end)
            if eConn then eConn:Disconnect() end
            eConn = UIS.InputEnded:Connect(function(inp)
                if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
                dragging = false
                if mConn then mConn:Disconnect(); mConn=nil end
                if eConn then eConn:Disconnect(); eConn=nil end
                if moved then
                    toggleDragBlocked = true
                    task.delay(0.2, function() toggleDragBlocked = false end)
                    -- Remember where the user dropped the menu button.
                    State.menuButtonPos = {
                        XS = toggleBtn.Position.X.Scale, X = toggleBtn.Position.X.Offset,
                        YS = toggleBtn.Position.Y.Scale, Y = toggleBtn.Position.Y.Offset,
                    }
                    if _G._K7RequestSave then pcall(_G._K7RequestSave) end
                end
            end)
        end)
    end
    _G._K7ToggleBtn = toggleBtn
    _G._K7SafeClick(toggleBtn, function()
        if toggleDragBlocked then return end
        toggleMainUI()
    end)

    local bgImg = Instance.new("ImageLabel", mainOuter)
    bgImg.Name = "BgImage"
    bgImg.Size = UDim2.new(1, 0, 1, 0)
    bgImg.Position = UDim2.new(0, 0, 0, 0)
    bgImg.Image = "rbxassetid://137970714521556"
    bgImg.ScaleType = Enum.ScaleType.Crop
    bgImg.BackgroundColor3 = Color3.fromRGB(8, 28, 55)
    bgImg.BackgroundTransparency = 1
    bgImg.ImageTransparency = 0
    bgImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
    bgImg.Visible = true
    bgImg.BorderSizePixel = 0
    bgImg.ZIndex = 0
    mkCorner(bgImg, 16)
    -- No UIGradient on BgImage: gradients wash out the artwork
    pcall(function()
        ContentProvider:PreloadAsync({bgImg})
    end)

    local topBgImg = Instance.new("ImageLabel", mainOuter)
    topBgImg.Name = "TopBgImage"
    topBgImg.Size = UDim2.new(1, 0, 0, 1)
    topBgImg.Position = UDim2.new(0, 0, 0, 0)
    topBgImg.Image = ""
    topBgImg.BackgroundTransparency = 1
    topBgImg.ImageTransparency = 1
    topBgImg.BorderSizePixel = 0
    topBgImg.Visible = false
    topBgImg.ZIndex = 0
    local topCanGradient = Instance.new("UIGradient", topBgImg)
    topCanGradient.Name = "AdaptiveCanBlend"
    topCanGradient.Color = adaptiveCanColorSequence(currentColorScheme, false)

    -- Light blue atmosphere
    local atmosphere = Instance.new("Frame", mainOuter)
    atmosphere.Name = "GradientAtmosphere"
    atmosphere.Size = UDim2.new(1,0,1,-14)
    atmosphere.Position = UDim2.new(0,0,0,14)
    atmosphere.BackgroundColor3 = Color3.fromRGB(90, 180, 245)
    atmosphere.BackgroundTransparency = 0.97
    atmosphere.BorderSizePixel = 0
    atmosphere.ZIndex = 1
    mkCorner(atmosphere,12)
    local atmosphereGradient = Instance.new("UIGradient", atmosphere)
    atmosphereGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(220, 245, 255)),
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(140, 210, 255)),
        ColorSequenceKeypoint.new(0.70, Color3.fromRGB(90, 180, 245)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(175, 220, 250)),
    })
    atmosphereGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.78),
        NumberSequenceKeypoint.new(0.40, 0.90),
        NumberSequenceKeypoint.new(0.75, 0.86),
        NumberSequenceKeypoint.new(1.00, 0.75),
    })
    atmosphereGradient.Rotation = 90

    local canArtwork=Instance.new("Frame",mainOuter)
    canArtwork.Size=UDim2.new(1,-16,1,-36); canArtwork.Position=UDim2.new(0,8,0,18)
    canArtwork.BackgroundTransparency=1; canArtwork.BorderSizePixel=0; canArtwork.ClipsDescendants=true; canArtwork.ZIndex=1
    mkCorner(canArtwork,12)
    local flavorSweep=Instance.new("Frame",canArtwork)
    flavorSweep.Size=UDim2.new(0,28,1,90); flavorSweep.Position=UDim2.new(0.56,0,0,-42)
    flavorSweep.Rotation=16; flavorSweep.BackgroundColor3=Color3.fromRGB(224,228,46)
    flavorSweep.BackgroundTransparency=0.63; flavorSweep.BorderSizePixel=0; flavorSweep.ZIndex=1
    mkCorner(flavorSweep,14)
    flavorSweep.Visible=false
    local logoWatermark=Instance.new("TextLabel",canArtwork)
    logoWatermark.Size=UDim2.new(0,320,0,170); logoWatermark.Position=UDim2.new(0,22,0,112)
    logoWatermark.BackgroundTransparency=1; logoWatermark.Text="MAY"; logoWatermark.TextColor3=Color3.fromRGB(255,255,255)
    logoWatermark.TextTransparency=0.84; logoWatermark.TextStrokeColor3=Color3.fromRGB(27, 27, 27); logoWatermark.TextStrokeTransparency=0.82
    logoWatermark.Font=Enum.Font.GothamBold; logoWatermark.TextSize=108; logoWatermark.Rotation=-10; logoWatermark.ZIndex=1
    local logoDiscWatermark=Instance.new("Frame",canArtwork)
    logoDiscWatermark.Size=UDim2.new(0,82,0,82); logoDiscWatermark.Position=UDim2.new(0,155,0,165)
    logoDiscWatermark.BackgroundColor3=Color3.fromRGB(220,35,43); logoDiscWatermark.BackgroundTransparency=0.82
    logoDiscWatermark.BorderSizePixel=0; logoDiscWatermark.ZIndex=1; mkCorner(logoDiscWatermark,41)
    logoDiscWatermark.Visible=false
    for _,bubbleData in ipairs({{252,48,5},{265,64,8},{247,80,4},{278,95,6},{204,318,5},{218,335,8},{230,354,4}}) do
        local bubble=Instance.new("Frame",canArtwork)
        bubble.Size=UDim2.new(0,bubbleData[3],0,bubbleData[3]); bubble.Position=UDim2.new(0,bubbleData[1],0,bubbleData[2])
        bubble.BackgroundColor3=Color3.fromRGB(255,255,255); bubble.BackgroundTransparency=0.76
        bubble.BorderSizePixel=0; bubble.ZIndex=1; mkCorner(bubble,bubbleData[3]/2)
    end

    local mainContent = Instance.new("Frame", mainOuter)
    mainContent.Name = "MainContent"
    mainContent.Size = UDim2.new(1, -16, 1, -36)
    mainContent.Position = UDim2.new(0, 8, 0, 18)
    mainContent.BackgroundTransparency = 1
    mainContent.BorderSizePixel = 0
    mainContent.ZIndex = 2
    mainContent.ClipsDescendants = true
    mkCorner(mainContent, 12)

    local accentBar = Instance.new("Frame", mainContent)
    accentBar.Size = UDim2.new(1, -60, 0, 1); accentBar.Position = UDim2.new(0,30,0,0)
    accentBar.BackgroundColor3 = currentColorScheme.accent; accentBar.BackgroundTransparency = 0.85
    accentBar.BorderSizePixel = 0; accentBar.ZIndex = 5
    accentBar.Visible = false

    local titleBar = Instance.new("Frame", mainContent)
    titleBar.Name = "TitleBar"
    titleBar:SetAttribute("AlwaysBlackOptionBar", true)
    titleBar.Size = UDim2.new(1,0,0,TITLE_H)
    titleBar.BackgroundColor3 = Color3.fromRGB(200, 230, 250)
    titleBar.BackgroundTransparency = 0.05
    titleBar.BorderSizePixel = 0
    titleBar.ZIndex = 5
    mkCorner(titleBar, 10)
    local titleBarGrad = Instance.new("UIGradient", titleBar)
    titleBarGrad.Rotation = 0
    titleBarGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 245, 255)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(160, 215, 245)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 190, 240)),
    })

    local avatarBg = Instance.new("Frame", titleBar)
    avatarBg.Name = "SevenUpTitleMusicButton"
    avatarBg.Size = UDim2.new(0,28,0,28); avatarBg.Position = UDim2.new(0,12,0,6)
    avatarBg.BackgroundColor3 = Color3.fromRGB(45,205,255); avatarBg.BackgroundTransparency = 0
    avatarBg.BorderSizePixel = 0; avatarBg.ZIndex = 6
    avatarBg.Visible = false
    mkCorner(avatarBg,14)
    local avatarStroke = Instance.new("UIStroke",avatarBg)
    avatarStroke.Thickness = 1; avatarStroke.Transparency = 0.35
    local avatarGradient = Instance.new("UIGradient",avatarStroke)
    avatarGradient.Color = ColorSequence.new(Color3.fromRGB(0,0,0),Color3.fromRGB(0,0,0))
    local avatarImg = Instance.new("ImageLabel", avatarBg)
    avatarImg.Size = UDim2.new(1,-4,1,-4); avatarImg.Position = UDim2.new(0,2,0,2)
    avatarImg.BackgroundTransparency = 1; avatarImg.Image = ""; avatarImg.ScaleType = Enum.ScaleType.Crop
    avatarImg.ZIndex = 7; mkCorner(avatarImg,12)
    avatarImg.Visible = false
    local titleLogoSeven=Instance.new("TextLabel",avatarBg)
    titleLogoSeven.Name="TitleSevenLogo"
    titleLogoSeven.Size=UDim2.new(1,0,1,0); titleLogoSeven.BackgroundTransparency=1; titleLogoSeven.Text=""
    titleLogoSeven.TextColor3=Color3.fromRGB(255,255,255); titleLogoSeven.TextStrokeColor3=currentColorScheme.mainDark
    titleLogoSeven.TextStrokeTransparency=0.25; titleLogoSeven.Font=Enum.Font.GothamBold; titleLogoSeven.TextSize=20
    titleLogoSeven.Rotation=-8; titleLogoSeven.ZIndex=8
    local titleLogoClick=Instance.new("TextButton",avatarBg)
    titleLogoClick.Size=UDim2.new(1,0,1,0); titleLogoClick.BackgroundTransparency=1; titleLogoClick.BorderSizePixel=0; titleLogoClick.Text=""; titleLogoClick.ZIndex=9

    local userNameLbl = Instance.new("TextLabel", titleBar)
    userNameLbl.Size = UDim2.new(0,90,0,9); userNameLbl.Position = UDim2.new(0,12,0,34)
    userNameLbl.BackgroundTransparency = 1; userNameLbl.ZIndex = 6
    userNameLbl.Text = ""
    userNameLbl.TextColor3 = Color3.fromRGB(233, 233, 233)
    userNameLbl.Font = Enum.Font.GothamBold; userNameLbl.TextSize = 7
    userNameLbl.TextXAlignment = Enum.TextXAlignment.Left
    userNameLbl.TextWrapped = true
    userNameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    userNameLbl.Visible = false


    -- Cabeçalho com Mystery.Vs e Discord logo abaixo.
    local titleShadow = Instance.new("TextLabel", titleBar)
    titleShadow.Name = "MysteryVsMetalShadow"
    titleShadow.AnchorPoint = Vector2.new(0, 0.5)
    titleShadow.Size = UDim2.new(1, -70, 0, 24); titleShadow.Position = UDim2.new(0, 16, 0, 13)
    titleShadow.BackgroundTransparency = 1
    titleShadow.Text = "venom.vs"
    titleShadow.TextColor3 = Color3.fromRGB(255,255,255)
    titleShadow.TextStrokeColor3 = Color3.fromRGB(150,150,150)
    titleShadow.TextStrokeTransparency = 0.35
    titleShadow:SetAttribute("MysteryVsGlowText", true)
    titleShadow.Font = Enum.Font.GothamBold
    titleShadow.TextScaled = true
    titleShadow.TextXAlignment = Enum.TextXAlignment.Left
    titleShadow.TextYAlignment = Enum.TextYAlignment.Center
    titleShadow.ZIndex = 6
    titleShadow.Visible = true
    local shadowLimit = Instance.new("UITextSizeConstraint", titleShadow)
    shadowLimit.MinTextSize = 12; shadowLimit.MaxTextSize = 22

    local titleLbl = Instance.new("TextLabel", titleBar)
    titleLbl.Name = "MysteryVsMainLogo"
    titleLbl.AnchorPoint = Vector2.new(0, 0.5)
    titleLbl.Size = UDim2.new(1, -70, 0, 24); titleLbl.Position = UDim2.new(0, 15, 0, 12)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "venom.vs"
    titleLbl.TextColor3 = Color3.fromRGB(255,255,255)
    titleLbl.TextStrokeColor3 = Color3.fromRGB(150,150,150)
    titleLbl.TextStrokeTransparency = 0.25
    titleLbl:SetAttribute("MysteryVsGlowText", true)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextScaled = true
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextYAlignment = Enum.TextYAlignment.Center
    titleLbl.ZIndex = 7
    titleLbl.Visible = true
    local titleLimit = Instance.new("UITextSizeConstraint", titleLbl)
    titleLimit.MinTextSize = 12; titleLimit.MaxTextSize = 22
    local titleStroke = Instance.new("UIStroke", titleLbl)
    titleStroke.Name = "MysteryVsGlowStroke"
    titleStroke.Color = Color3.fromRGB(100,230,255)
    titleStroke.Thickness = 2
    titleStroke.Transparency = 0.05
    titleStroke.LineJoinMode = Enum.LineJoinMode.Round


    local subTitleLbl = Instance.new("TextLabel", titleBar)
    subTitleLbl.Name = "DiscordSubTitle"
    subTitleLbl.Size = UDim2.new(1, -70, 0, 14); subTitleLbl.Position = UDim2.new(0, 15, 0, 30)
    subTitleLbl.BackgroundTransparency = 1; subTitleLbl.Text = "discord.gg/GvBQmT7Xj"
    subTitleLbl.TextColor3 = currentColorScheme.discordText or currentColorScheme.subtitleText
    subTitleLbl.Font = Enum.Font.GothamMedium; subTitleLbl.TextSize = 10
    subTitleLbl.TextXAlignment = Enum.TextXAlignment.Left; subTitleLbl.ZIndex = 8
    subTitleLbl.Visible = true

    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0,26,0,26); closeBtn.Position = UDim2.new(1,-34,0,8)
    closeBtn.BackgroundColor3 = currentColorScheme.modeBtnBg; closeBtn.BackgroundTransparency = 0.85
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "--"; closeBtn.TextColor3 = currentColorScheme.closeBtn; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 14
    closeBtn.ZIndex = 7; mkCorner(closeBtn,6)
    local closeStroke = Instance.new("UIStroke",closeBtn); closeStroke.Color = Color3.fromRGB(127, 127, 127); closeStroke.Transparency = 0.65
    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn,TweenInfo.new(0.12),{TextColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=0.2,BackgroundColor3=Color3.fromRGB(77, 77, 77)}):Play()
        TweenService:Create(closeStroke,TweenInfo.new(0.12),{Transparency=0,Thickness=2}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn,TweenInfo.new(0.12),{TextColor3=currentColorScheme.closeBtn,BackgroundTransparency=0.85,BackgroundColor3=currentColorScheme.modeBtnBg}):Play()
        TweenService:Create(closeStroke,TweenInfo.new(0.12),{Transparency=0.65,Thickness=1}):Play()
    end)
    _G._K7SafeClick(closeBtn, function()
        setMenuVisible(false)
        requestSave()
    end)

    local titleDiv = Instance.new("Frame", mainContent)
    titleDiv.Size = UDim2.new(1,0,0,1); titleDiv.Position = UDim2.new(0,0,0,TITLE_H)
    titleDiv.BackgroundColor3 = currentColorScheme.divider; titleDiv.BackgroundTransparency = 0.18
    titleDiv.BorderSizePixel = 0; titleDiv.ZIndex = 5
    titleDiv.Visible = true
    local titleDivGradient = Instance.new("UIGradient", titleDiv)
    titleDivGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(141, 141, 141)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(207, 207, 207)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(151, 151, 151)),
    })
    titleDivGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.18,0.12),
        NumberSequenceKeypoint.new(0.82,0.12), NumberSequenceKeypoint.new(1,1),
    })

    local CONTENT_Y = TITLE_H + 1
    local contentBg = Instance.new("Frame", mainContent)
    contentBg.Size = UDim2.new(1,0,1,-CONTENT_Y); contentBg.Position = UDim2.new(0,0,0,CONTENT_Y)
    contentBg.BackgroundColor3 = Color3.fromRGB(45,205,255)
    contentBg.BackgroundTransparency = 1
    contentBg.BorderSizePixel = 0; contentBg.ClipsDescendants = true; contentBg.ZIndex = 2
    mkCorner(contentBg, 24)

    do
        local scanLine = Instance.new("Frame", contentBg)
        scanLine.Name = "ScanHighlight"
        scanLine.Size = UDim2.new(1,-20,0,1)
        scanLine.Position = UDim2.new(0,10,0,-2)
        scanLine.BackgroundColor3 = Color3.fromRGB(141, 141, 141)
        scanLine.BackgroundTransparency = 0.82
        scanLine.BorderSizePixel = 0
        scanLine.ZIndex = 3
        scanLine.Visible = false
        local scanFade = Instance.new("UIGradient", scanLine)
        scanFade.Color = ColorSequence.new(Color3.fromRGB(141, 141, 141),Color3.fromRGB(151, 151, 151))
        scanFade.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(1,1)})
        TweenService:Create(scanLine,TweenInfo.new(5.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Position=UDim2.new(0,10,1,1)}):Play()

        local function cornerPart(position,size)
            local part=Instance.new("Frame",contentBg)
            part.Position=position; part.Size=size; part.BackgroundColor3=Color3.fromRGB(127, 127, 127)
            part.BackgroundTransparency=0; part.BorderSizePixel=0; part.ZIndex=3
            part.Visible=false
            local fade=Instance.new("UIGradient",part)
            fade.Color=ColorSequence.new(Color3.fromRGB(141, 141, 141),Color3.fromRGB(151, 151, 151))
        end
        cornerPart(UDim2.new(0,10,0,10),UDim2.new(0,28,0,1))
        cornerPart(UDim2.new(0,10,0,10),UDim2.new(0,1,0,28))
        cornerPart(UDim2.new(1,-38,1,-11),UDim2.new(0,28,0,1))
        cornerPart(UDim2.new(1,-11,1,-38),UDim2.new(0,1,0,28))
    end

    -- TABS
    -- Cada grupo possui sua própria página para facilitar a navegação.
    local TABS = {"Speed", "Main", "Visual", "Steal", "Config"}
    local TAB_LABELS = {"SPEED", "COMBAT", "VISUAL", "STEAL", "SETTINGS"}
    local tabPages = {}
    local currentPage = nil
    local lo = 0
    local function LO() lo = lo+1; return lo end

    -- Side tab rail (organized, fixed spacing)
    local TAB_BTN_W = 112
    local SIDE_NAV_W = 128
    local TAB_GAP = 10
    local TAB_TOP = 14
    local TAB_H = 42
    local TAB_COUNT = #TABS
    local TAB_BAR_H = TAB_TOP + (TAB_COUNT * TAB_H) + ((TAB_COUNT - 1) * TAB_GAP) + 14

    local tabBar = Instance.new("Frame", contentBg)
    tabBar.Name = "MechanicsNavigationBar"
    tabBar.Size = UDim2.new(0, SIDE_NAV_W, 0, TAB_BAR_H)
    tabBar.Position = UDim2.new(1, -SIDE_NAV_W, 0, 0)
    tabBar.BackgroundColor3 = Color3.fromRGB(25, 95, 210)
    tabBar.BackgroundTransparency = 0
    tabBar.Visible = true
    tabBar.BorderSizePixel = 0
    tabBar.ClipsDescendants = true
    tabBar.ZIndex = 4
    mkCorner(tabBar, 12)
    local tabBarGradient = Instance.new("UIGradient", tabBar)
    tabBarGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 130, 240)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(25, 95, 210)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 70, 180)),
    })
    tabBarGradient.Rotation = 90
    local tabBarStroke = Instance.new("UIStroke", tabBar)
    tabBarStroke.Color = currentColorScheme.border
    tabBarStroke.Transparency = 0.45
    tabBarStroke.Thickness = 1.2

    local tabDivider = Instance.new("Frame", contentBg)
    tabDivider.Size = UDim2.new(0, 1, 1, -24)
    tabDivider.Position = UDim2.new(1, -SIDE_NAV_W - 1, 0, 12)
    tabDivider.BackgroundColor3 = currentColorScheme.border
    tabDivider.BackgroundTransparency = 0.35
    tabDivider.BorderSizePixel = 0
    tabDivider.ZIndex = 6
    tabDivider.Visible = true
    local tabDividerGradient = Instance.new("UIGradient", tabDivider)
    tabDividerGradient.Color = ColorSequence.new(currentColorScheme.mainLight, currentColorScheme.main)
    tabDividerGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.2, 0.2),
        NumberSequenceKeypoint.new(0.8, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    tabDividerGradient.Rotation = 90

    local TAB_POSITIONS = {}
    for i = 1, TAB_COUNT do
        TAB_POSITIONS[i] = { y = TAB_TOP + (i - 1) * (TAB_H + TAB_GAP) }
    end

    local tabButtons = {}
    local selectedTab = nil

    for i, tabName in ipairs(TABS) do
        local btn = Instance.new("TextButton", tabBar)
        btn.Name = "SevenUpNavTab"
        btn.Size = UDim2.new(0, TAB_BTN_W, 0, 36)
        btn.Position = UDim2.new(0.5, -TAB_BTN_W/2, 0, TAB_POSITIONS[i].y + 3)
        btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        btn.BackgroundTransparency = 0
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.ClipsDescendants = false
        btn.Text = ""
        btn.ZIndex = 8
        mkCorner(btn, 10)
        local tabScale = Instance.new("UIScale",btn)
        tabScale.Scale=1
        local tabSurface = Instance.new("Frame", btn)
        tabSurface.Name = "GradientSurface"
        tabSurface.Size = UDim2.new(1,0,1,0)
        tabSurface.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        tabSurface.BackgroundTransparency = 0
        tabSurface.BorderSizePixel = 0
        tabSurface.Active = false
        tabSurface.ZIndex = 7
        mkCorner(tabSurface,10)
        local tabGradient = Instance.new("UIGradient", tabSurface)
        tabGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        })
        tabGradient.Rotation = 90
        for _,isRightCap in ipairs({false,true}) do
            local canCap=Instance.new("Frame",btn)
            canCap.Name="CanEndCap"
            canCap.Size=UDim2.new(0,4,1,-14)
            canCap.Position=isRightCap and UDim2.new(1,-7,0,7) or UDim2.new(0,3,0,7)
            canCap.BackgroundColor3=Color3.fromRGB(126,143,132)
            canCap.BorderSizePixel=0; canCap.ZIndex=8; mkCorner(canCap,3)
            canCap.Visible=false
        end
        -- Contorno completo (ciano escuro) em volta de cada opcao lateral
        local btnStroke = Instance.new("UIStroke", btn)
        btnStroke.Name = "DarkCyanOutline"
        btnStroke.Color = Color3.fromRGB(55, 55, 55)
        btnStroke.Transparency = 0
        btnStroke.Thickness = 2
        btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        local tabLabel = Instance.new("TextLabel", btn)
        tabLabel.Name = "SevenUpNavLabel"
        tabLabel.Size = UDim2.new(1,-12,1,0)
        tabLabel.Position = UDim2.new(0,6,0,0)
        tabLabel.BackgroundTransparency = 1
        tabLabel.Text = TAB_LABELS[i] or tabName
        tabLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        tabLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        tabLabel.TextStrokeTransparency = 0.7
        tabLabel.Font = Enum.Font.GothamBold
        tabLabel.TextSize = 12
        tabLabel.TextScaled = false
        tabLabel.TextTruncate = Enum.TextTruncate.AtEnd
        tabLabel.TextXAlignment = Enum.TextXAlignment.Center
        tabLabel.ZIndex = 10

        -- Somente o nome da seção é exibido.

        local tabNumber=Instance.new("TextLabel",btn)
        tabNumber.Size=UDim2.new(0,25,0,22); tabNumber.Position=UDim2.new(0,8,0.5,-11)
        tabNumber.BackgroundColor3=Color3.fromRGB(35, 35, 35); tabNumber.BackgroundTransparency=0.08
        tabNumber.BorderSizePixel=0; tabNumber.Text=string.format("%02d",i); tabNumber.TextColor3=Color3.fromRGB(223, 223, 223)
        tabNumber.Font=Enum.Font.GothamBold; tabNumber.TextSize=8; tabNumber.ZIndex=10; mkCorner(tabNumber,7)
        tabNumber.Visible=false
        local numberStroke=Instance.new("UIStroke",tabNumber); numberStroke.Color=Color3.fromRGB(216, 216, 216); numberStroke.Transparency=0.55

        local bar = Instance.new("Frame", btn)
        bar.AnchorPoint = Vector2.new(0.5, 0)
        bar.Size = UDim2.new(0, 22, 0, 3)
        bar.Position = UDim2.new(0.5, 0, 1, -4)
        bar.BackgroundColor3 = Color3.fromRGB(224,38,45)
        bar.BackgroundTransparency = 1
        bar.BorderSizePixel = 0
        bar.ZIndex = 9
        mkCorner(bar, 2)
        bar.Visible = false

        -- Quadrado arredondado com borda branca que aparece quando a aba está selecionada
        -- Agora esticado para ficar como uma moldura ao redor do texto, sem sobrepor as letras.
        local selSquare = Instance.new("Frame", btn)
        selSquare.Name = "SelectedSquare"
        selSquare.AnchorPoint = Vector2.new(0.5, 0.5)
        selSquare.Size = UDim2.new(1, -10, 0, 28)
        selSquare.Position = UDim2.new(0.5, 0, 0.5, 0)
        selSquare.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        selSquare.BackgroundTransparency = 1
        selSquare.BorderSizePixel = 0
        selSquare.ZIndex = 5
        mkCorner(selSquare, 8)
        local selSquareStroke = Instance.new("UIStroke", selSquare)
        selSquareStroke.Color = Color3.fromRGB(80, 80, 80)
        selSquareStroke.Transparency = 1
        selSquareStroke.Thickness = 1.4

        btn.MouseEnter:Connect(function()
            if selectedTab ~= i then
                TweenService:Create(tabLabel, TweenInfo.new(0.14), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                TweenService:Create(tabSurface, TweenInfo.new(0.14), {BackgroundTransparency = 0}):Play()
                TweenService:Create(tabScale,TweenInfo.new(0.14,Enum.EasingStyle.Back),{Scale=1.03}):Play()
                TweenService:Create(btnStroke, TweenInfo.new(0.14), {Color = Color3.fromRGB(70, 70, 70), Transparency = 0, Thickness = 2.2}):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if selectedTab ~= i then
                TweenService:Create(tabLabel, TweenInfo.new(0.14), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                TweenService:Create(tabSurface, TweenInfo.new(0.14), {BackgroundTransparency = 0}):Play()
                TweenService:Create(tabScale,TweenInfo.new(0.14),{Scale=1}):Play()
                TweenService:Create(btnStroke, TweenInfo.new(0.14), {Color = Color3.fromRGB(55, 55, 55), Transparency = 0, Thickness = 2}):Play()
            end
        end)
        btn.MouseButton1Down:Connect(function()
            TweenService:Create(tabScale,TweenInfo.new(0.08),{Scale=0.96}):Play()
        end)
        btn.MouseButton1Up:Connect(function()
            TweenService:Create(tabScale,TweenInfo.new(0.12,Enum.EasingStyle.Back),{Scale=1.025}):Play()
        end)

        tabButtons[i] = {btn = btn, label = tabLabel, bar = bar, stroke = btnStroke, surface = tabSurface, selSquare = selSquare, selSquareStroke = selSquareStroke}
    end

    local tabContainer = Instance.new("Frame", contentBg)
    tabContainer.Size = UDim2.new(1, -(SIDE_NAV_W + 8), 1, 0)
    tabContainer.Position = UDim2.new(0, 0, 0, 0)
    tabContainer.BackgroundColor3 = Color3.fromRGB(3, 4, 8)
    tabContainer.BackgroundTransparency = 1
    tabContainer.BorderSizePixel = 0
    tabContainer.ZIndex = 3
    tabContainer.ClipsDescendants = true
    mkCorner(tabContainer, 18)
    local contentPanelStroke = Instance.new("UIStroke", tabContainer)
    contentPanelStroke.Color = Color3.fromRGB(97, 97, 97)
    contentPanelStroke.Transparency = 0.68
    contentPanelStroke.Thickness = 1

    local tabScroll = Instance.new("ScrollingFrame", tabContainer)
    tabScroll.Size = UDim2.new(1,0,1,0)
    tabScroll.BackgroundTransparency = 1
    tabScroll.BorderSizePixel = 0
    tabScroll.ScrollBarThickness = 0
    tabScroll.ScrollBarImageColor3 = currentColorScheme.main
    tabScroll.ScrollBarImageTransparency = 0.4
    tabScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabScroll.CanvasSize = UDim2.new(0,0,0,0)
    tabScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    tabScroll.ZIndex = 3
    tabScroll.ClipsDescendants = true

    local tabScrollPad = Instance.new("UIPadding", tabScroll)
    tabScrollPad.PaddingLeft = UDim.new(0,8)
    tabScrollPad.PaddingRight = UDim.new(0,8)
    tabScrollPad.PaddingTop = UDim.new(0,6)
    tabScrollPad.PaddingBottom = UDim.new(0,12)

    local function selectTab(index)
        -- Keep the fixed cyber background image visible in every tab.
        if bgImg then
            bgImg.Image = "rbxassetid://137970714521556"
            bgImg.ImageTransparency = 0
            bgImg.BackgroundTransparency = 1
            bgImg.ImageColor3 = Color3.fromRGB(255,255,255)
            bgImg.Visible = true
        end
        tabContainer.BackgroundTransparency = 1
        tabScroll.BackgroundTransparency = 1
        local settingsPage = tabPages.Config
        if settingsPage then
            settingsPage.BackgroundTransparency = 1
        end
        if atmosphere then
            atmosphere.BackgroundTransparency = 0.92
        end

        for i, data in ipairs(tabButtons) do
            local btn = data.btn
            if i == index then
                selectedTab = i
                btn:SetAttribute("Selected", true)
                if data.label then TweenService:Create(data.label, TweenInfo.new(0.18), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end
                if data.surface then TweenService:Create(data.surface, TweenInfo.new(0.18), {BackgroundTransparency=0}):Play() end
                if data.bar then TweenService:Create(data.bar, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play() end
                if data.stroke then TweenService:Create(data.stroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(70, 70, 70), Transparency = 0, Thickness = 2.4}):Play() end
                if data.selSquare then TweenService:Create(data.selSquare, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0}):Play() end
                if data.selSquareStroke then TweenService:Create(data.selSquareStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(80, 80, 80), Transparency = 0.05}):Play() end
            else
                btn:SetAttribute("Selected", false)
                if data.label then TweenService:Create(data.label, TweenInfo.new(0.18), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end
                if data.surface then TweenService:Create(data.surface, TweenInfo.new(0.18), {BackgroundTransparency=0}):Play() end
                if data.bar then TweenService:Create(data.bar, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play() end
                if data.stroke then TweenService:Create(data.stroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(55, 55, 55), Transparency = 0, Thickness = 2}):Play() end
                if data.selSquare then TweenService:Create(data.selSquare, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play() end
                if data.selSquareStroke then TweenService:Create(data.selSquareStroke, TweenInfo.new(0.15), {Transparency = 1}):Play() end
            end
        end

        for name, page in pairs(tabPages) do
            page.Visible = (name == TABS[index])
            if page.Visible then
                page.Position=UDim2.new(0,-14,0,0)
                TweenService:Create(page,TweenInfo.new(0.24,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.new(0,0,0,0)}):Play()
            end
        end
    end

    for i, data in ipairs(tabButtons) do
        _G._K7SafeClick(data.btn, function()
            if data.surface then data.surface.BackgroundTransparency=0.62 end
            if data.label then
                data.label.Position=UDim2.new(0,8,0,0)
                TweenService:Create(data.label,TweenInfo.new(0.22,Enum.EasingStyle.Back),{Position=UDim2.new(0,6,0,0)}):Play()
            end
            selectTab(i)
        end)
    end

    local function buildPage(tabName, buildFn)
        local page = Instance.new("Frame", tabScroll)
        page.Name = tabName
        page.Size = UDim2.new(1,0,0,0)
        page.AutomaticSize = Enum.AutomaticSize.Y
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.Visible = false
        page.ZIndex = 3

        local ll = Instance.new("UIListLayout", page)
        ll.SortOrder = Enum.SortOrder.LayoutOrder
        ll.Padding = UDim.new(0,4)
        ll.HorizontalAlignment = Enum.HorizontalAlignment.Center

        tabPages[tabName] = page
        lo = 0
        currentPage = page
        buildFn()
        currentPage = nil
        return page
    end

    -- Helper Functions
    -- Barra de versoes reutilizavel: mesmo visual do seletor do Anti TP Bat.
    local function makeVersionBar(holderParent, labels, getIndex, onPick)
        local N = #labels
        local SEG = 1/N
        local holder=Instance.new("Frame",holderParent)
        holder.Size=UDim2.new(1,-4,0,42); holder.Position=UDim2.new(0,2,0,1)
        holder.BackgroundColor3=Color3.fromRGB(24,25,32); holder.BackgroundTransparency=0.28
        holder.BorderSizePixel=0; holder.ClipsDescendants=true
        mkCorner(holder,14)
        local hStroke=Instance.new("UIStroke",holder)
        hStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
        hStroke.Color=Color3.fromRGB(45,205,255); hStroke.Transparency=0.32; hStroke.Thickness=1.4

        local slide=Instance.new("Frame",holder)
        slide.AnchorPoint=Vector2.new(0.5,0.5)
        slide.Size=UDim2.new(SEG,-4,1,-8); slide.Position=UDim2.new(SEG*0.5,0,0.5,0)
        slide.BackgroundColor3=Color3.fromRGB(45,205,255); slide.BackgroundTransparency=0.1
        slide.BorderSizePixel=0; slide.ZIndex=5
        mkCorner(slide,13)
        local sStroke=Instance.new("UIStroke",slide)
        sStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
        sStroke.Color=Color3.fromRGB(190,240,255); sStroke.Thickness=1.5; sStroke.Transparency=0.1
        local grad=Instance.new("UIGradient",slide)
        grad.Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(150,235,255)),
            ColorSequenceKeypoint.new(0.5,Color3.fromRGB(45,205,255)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(10,140,200)),
        })
        grad.Rotation=22

        local lbls={}
        for i,txt in ipairs(labels) do
            local lbl=Instance.new("TextLabel",holder)
            lbl.BackgroundTransparency=1
            lbl.Text=txt
            lbl.TextColor3=Color3.fromRGB(255,255,255)
            lbl.TextStrokeColor3=Color3.fromRGB(0,0,0)
            lbl.TextStrokeTransparency=0.2
            lbl.TextSize=12
            lbl.Font=Enum.Font.GothamBlack
            lbl.AnchorPoint=Vector2.new(0.5,0.5)
            lbl.Size=UDim2.new(SEG,0,1,0)
            lbl.Position=UDim2.new(SEG*(i-0.5),0,0.5,0)
            lbl.ZIndex=8
            lbls[i]=lbl

            local click=Instance.new("TextButton",holder)
            click.BackgroundTransparency=1; click.Text=""; click.AutoButtonColor=false
            click.AnchorPoint=Vector2.new(0.5,0.5)
            click.Size=UDim2.new(SEG,0,1,0)
            click.Position=UDim2.new(SEG*(i-0.5),0,0.5,0)
            click.ZIndex=10
            local idx=i
            _G._K7SafeClick(click,function() onPick(idx) end)
        end

        local function refresh()
            local index=math.clamp(tonumber(getIndex()) or 1,1,N)
            TweenService:Create(slide,TweenInfo.new(0.18,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
                Position=UDim2.new(SEG*(index-0.5),0,0.5,0),
                Size=UDim2.new(SEG,-4,1,-8),
            }):Play()
            for i,lbl in ipairs(lbls) do
                local sel=(i==index)
                TweenService:Create(lbl,TweenInfo.new(0.14),{
                    TextTransparency=sel and 0 or 0.22,
                    TextStrokeTransparency=sel and 0.2 or 0.45,
                }):Play()
            end
        end
        refresh()
        return refresh
    end

    -- Cabecalho com opcoes sempre visiveis embaixo (sem +/-)
    local function makeExpandableSection(titleText)
        local header=Instance.new("Frame",currentPage)
        header:SetAttribute("AlwaysCyanOptionBar",true)
        header.Size=UDim2.new(1,-16,0,44); header.BackgroundColor3=Color3.fromRGB(90,225,255)
        header.BorderSizePixel=0; header.LayoutOrder=LO(); mkCorner(header,10)
        local hs=Instance.new("UIStroke",header); hs.Color=Color3.fromRGB(255,255,255); hs.Transparency=0.25; hs.Thickness=1.5
        local title=Instance.new("TextLabel",header)
        title.Size=UDim2.new(1,-16,1,0); title.Position=UDim2.new(0,12,0,0); title.BackgroundTransparency=1
        title.Text=titleText; title.TextColor3=Color3.fromRGB(255,255,255); title.Font=Enum.Font.GothamBold
        title.TextSize=14; title.TextXAlignment=Enum.TextXAlignment.Left

        local options=Instance.new("Frame",currentPage)
        options.Size=UDim2.new(1,-16,0,44); options.BackgroundTransparency=1
        options.BorderSizePixel=0; options.LayoutOrder=LO(); options.Visible=true
        return options
    end

    local function makeGap(px) local f=Instance.new("Frame",currentPage); f.Size=UDim2.new(1,0,0,px or 6); f.BackgroundTransparency=1; f.BorderSizePixel=0; f.LayoutOrder=LO() end

    local function makeSectionHeader(label)
        -- Header agora e um chip DENTRO da area das opcoes (mesma largura das
        -- rows), com padding e truncate — nao vaza mais para fora do painel.
        local wrap = Instance.new("Frame", currentPage)
        wrap:SetAttribute("AlwaysCyanOptionBar", true)
        wrap.Size = UDim2.new(1,-16,0,26); wrap.BackgroundColor3 = Color3.fromRGB(45,205,255)
        wrap.BackgroundTransparency = 0
        wrap.BorderSizePixel=0; wrap.LayoutOrder=LO(); wrap.ClipsDescendants = true
        mkCorner(wrap,10)
        local wStroke = Instance.new("UIStroke", wrap)
        wStroke.Color = currentColorScheme.mainDark; wStroke.Transparency = 0.8
        local lbl = Instance.new("TextLabel", wrap)
        lbl.Size = UDim2.new(1,-20,1,0); lbl.Position = UDim2.new(0,12,0,0)
        lbl.BackgroundTransparency=1; lbl.Text = label and label:upper() or ""
        lbl.TextColor3 = currentColorScheme.sectionHeader
        lbl.Font = Enum.Font.GothamBold; lbl.TextSize=11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
    end

    local function makeInputRow(label, default, onChange)
        local CYAN_ROW = Color3.fromRGB(90, 225, 255)
        local CYAN_SOFT = Color3.fromRGB(80, 80, 80)
        local INK = Color3.fromRGB(10, 40, 85)
        local BOX_BG = Color3.fromRGB(20, 55, 95)
        local BOX_TXT = Color3.fromRGB(125, 235, 255)
        local row = Instance.new("Frame", currentPage)
        row:SetAttribute("AlwaysCyanOptionBar", true)
        row.Size = UDim2.new(1,-16,0,50); row.BackgroundColor3 = CYAN_ROW
        row.BackgroundTransparency = 0
        row.BorderSizePixel=0; row.LayoutOrder=LO(); mkCorner(row,12)
        local rowStroke = Instance.new("UIStroke", row); rowStroke.Color = Color3.fromRGB(65,65,65); rowStroke.Transparency = 0; rowStroke.Thickness = 1.5
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1,-138,1,0); lbl.Position = UDim2.new(0,10,0,0)
        lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=INK
        lbl.Font = Enum.Font.GothamBold; lbl.TextSize=14; lbl.TextXAlignment=Enum.TextXAlignment.Left
        local boxWrap = Instance.new("Frame", row)
        boxWrap.Size = UDim2.new(0,70,0,28); boxWrap.Position = UDim2.new(1,-120,0.5,-14)
        boxWrap.BackgroundColor3 = BOX_BG; boxWrap.BackgroundTransparency = 0
        boxWrap.BorderSizePixel=0
        mkCorner(boxWrap,8)
        local inputStroke = Instance.new("UIStroke", boxWrap); inputStroke.Color = Color3.fromRGB(10,85,140); inputStroke.Transparency = 0; inputStroke.Thickness = 1.5
        local box = Instance.new("TextBox", boxWrap)
        box.Size = UDim2.new(1,-8,1,0); box.Position = UDim2.new(0,4,0,0)
        box.BackgroundTransparency=1; box.Text = tostring(default)
        box.TextColor3 = BOX_TXT; box.Font = Enum.Font.GothamBold
        box.TextSize=15; box.ClearTextOnFocus=false; box.ZIndex=8; box.TextXAlignment=Enum.TextXAlignment.Center
        box.Focused:Connect(function()
            TweenService:Create(boxWrap,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(30,90,140)}):Play()
            TweenService:Create(inputStroke,TweenInfo.new(0.15),{Thickness=2}):Play()
        end)
        local function commitInput()
            if not onChange then return end
            local n = tonumber(box.Text)
            if n then
                onChange(n)
                pcall(requestSave)
            else
                box.Text = tostring(default)
            end
        end
        box.FocusLost:Connect(function()
            TweenService:Create(boxWrap,TweenInfo.new(0.15),{BackgroundColor3=BOX_BG}):Play()
            TweenService:Create(inputStroke,TweenInfo.new(0.15),{Thickness=1.5}):Play()
            commitInput()
        end)
        box.InputEnded:Connect(function(inp)
            if inp.KeyCode == Enum.KeyCode.Return or inp.KeyCode == Enum.KeyCode.KeypadEnter then
                commitInput()
            end
        end)
        return box,row
    end

    -- Speed stepper: + value - layout with enlarged circular buttons.
    local function makeSpeedStepperRow(label, default, minValue, maxValue, step, onChange)
        local row = Instance.new("Frame", currentPage)
        row:SetAttribute("AlwaysCyanOptionBar", true)
        row.Size = UDim2.new(1,-16,0,42); row.BackgroundColor3 = Color3.fromRGB(45,205,255)
        row.BackgroundTransparency = 0
        row.BorderSizePixel=0; row.LayoutOrder=LO(); mkCorner(row,12)
        local speedRowStroke=Instance.new("UIStroke",row)
        speedRowStroke.Color=Color3.fromRGB(10,85,140); speedRowStroke.Transparency=0; speedRowStroke.Thickness=1.5

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1,-174,1,0); lbl.Position = UDim2.new(0,12,0,0)
        lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=Color3.fromRGB(125,235,255)
        lbl.Font=Enum.Font.GothamBold; lbl.TextSize=15; lbl.TextXAlignment=Enum.TextXAlignment.Left
        lbl.TextWrapped=false; lbl.TextTruncate=Enum.TextTruncate.AtEnd

        local controls = Instance.new("Frame", row)
        controls.Size=UDim2.new(0,126,0,30); controls.Position=UDim2.new(1,-136,0.5,-15)
        controls.BackgroundTransparency=1
        local layout=Instance.new("UIListLayout",controls)
        layout.FillDirection=Enum.FillDirection.Horizontal; layout.HorizontalAlignment=Enum.HorizontalAlignment.Right
        layout.VerticalAlignment=Enum.VerticalAlignment.Center; layout.Padding=UDim.new(0,6)

        local function makeCircle(text)
            local button=Instance.new("TextButton",controls)
            button.Size=UDim2.fromOffset(30,30); button.BackgroundColor3=Color3.fromRGB(20,55,95)
            button.BackgroundTransparency=0; button.BorderSizePixel=0; button.Text=text
            button.TextColor3=Color3.fromRGB(125,235,255); button.Font=Enum.Font.GothamBold
            button.TextSize=25; button.AutoButtonColor=false; button.ZIndex=8
            mkCorner(button,15)
            local stroke=Instance.new("UIStroke",button)
            stroke.Color=Color3.fromRGB(10,85,140); stroke.Transparency=0.15; stroke.Thickness=1.5
            stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
            button.MouseEnter:Connect(function()
                TweenService:Create(stroke,TweenInfo.new(0.1),{Transparency=0,Thickness=2}):Play()
            end)
            button.MouseLeave:Connect(function()
                TweenService:Create(stroke,TweenInfo.new(0.1),{Transparency=0.15,Thickness=1.5}):Play()
            end)
            return button
        end

        local plus=makeCircle("+")
        plus.LayoutOrder=1
        local boxWrap=Instance.new("Frame",controls)
        boxWrap.LayoutOrder=2
        boxWrap.Size=UDim2.fromOffset(54,30); boxWrap.BackgroundColor3=Color3.fromRGB(20,55,95)
        boxWrap.BackgroundTransparency=0; boxWrap.BorderSizePixel=0; boxWrap.ZIndex=8
        mkCorner(boxWrap,15)
        local inputStroke=Instance.new("UIStroke",boxWrap)
        inputStroke.Color=Color3.fromRGB(10,85,140); inputStroke.Transparency=0; inputStroke.Thickness=1.5
        local box=Instance.new("TextBox",boxWrap)
        box.Size=UDim2.fromScale(1,1); box.BackgroundTransparency=1; box.Text=tostring(default)
        box.TextColor3=Color3.fromRGB(125,235,255); box.Font=Enum.Font.GothamBold; box.TextSize=16
        box.ClearTextOnFocus=false; box.TextXAlignment=Enum.TextXAlignment.Center; box.ZIndex=9
        local minus=makeCircle("−")
        minus.LayoutOrder=3

        local function applyValue(value)
            local n=math.clamp(tonumber(value) or tonumber(box.Text) or default,minValue,maxValue)
            if math.abs(n-math.round(n)) < 0.0001 then n=math.round(n) end
            box.Text=tostring(n)
            if onChange then onChange(n) end
            if requestSave then requestSave() end
        end
        plus.MouseButton1Click:Connect(function() applyValue((tonumber(box.Text) or default)+step) end)
        minus.MouseButton1Click:Connect(function() applyValue((tonumber(box.Text) or default)-step) end)
        box.FocusLost:Connect(function() applyValue(box.Text) end)
        box.InputEnded:Connect(function(inp)
            if inp.KeyCode==Enum.KeyCode.Return or inp.KeyCode==Enum.KeyCode.KeypadEnter then applyValue(box.Text) end
        end)
        return box,row
    end

    local function makeToggleRow(label, defaultOn, onToggle)
        local ON_BG    = Color3.fromRGB(0,0,0)
        local OFF_BG   = Color3.fromRGB(0,0,0)
        local ON_TXT   = Color3.fromRGB(255,255,255)
        local OFF_TXT  = Color3.fromRGB(255,255,255)
        -- Fixed activation colors: OFF = gray/white, ON = cyan track / black dot.
        local TRACK_ON = Color3.fromRGB(0,0,0)
        local TRACK_OFF= Color3.fromRGB(110,110,110)
        local DOT_ON   = Color3.fromRGB(0,0,0)
        local DOT_OFF  = Color3.fromRGB(255,255,255)

        local row = Instance.new("Frame", currentPage)
        row:SetAttribute("MysteryToggleRow", true)
        row.Size = UDim2.new(1,-16,0,40); row.BackgroundColor3 = ON_BG
        row.BackgroundTransparency = 0
        row.BorderSizePixel=0; row.LayoutOrder=LO(); mkCorner(row,12)
        row:SetAttribute("ActiveState",defaultOn==true)
        local rowStroke = Instance.new("UIStroke", row); rowStroke.Color = Color3.fromRGB(65,65,65); rowStroke.Transparency = 0; rowStroke.Thickness=1.5
        row.MouseEnter:Connect(function()
            rowStroke.Color=Color3.fromRGB(65,65,65); rowStroke.Transparency=0; rowStroke.Thickness=1.5
        end)
        row.MouseLeave:Connect(function()
            rowStroke.Color=Color3.fromRGB(65,65,65); rowStroke.Transparency=0; rowStroke.Thickness=1.5
        end)
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1,-86,1,0); lbl.Position = UDim2.new(0,12,0,0)
        lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=defaultOn and ON_TXT or OFF_TXT
        lbl.Font = Enum.Font.GothamBold; lbl.TextSize=15; lbl.TextXAlignment=Enum.TextXAlignment.Left
        lbl.TextWrapped=false; lbl.TextTruncate=Enum.TextTruncate.AtEnd

        local pillBg = Instance.new("Frame", row)
        pillBg.Name = "SevenUpActivator"
        pillBg.AnchorPoint = Vector2.new(1, 0.5)
        pillBg.Size = UDim2.new(0,50,0,26)
        pillBg.Position = UDim2.new(1,-12,0.5,0)
        pillBg.BackgroundColor3 = defaultOn and TRACK_ON or TRACK_OFF
        pillBg.BackgroundTransparency = 0
        pillBg.BorderSizePixel=0; pillBg.ZIndex=7; pillBg.ClipsDescendants=true; mkCorner(pillBg,13)
        local pillStroke = Instance.new("UIStroke", pillBg)
        pillStroke.Color = Color3.fromRGB(255,255,255)
        pillStroke.Transparency = 0.15
        pillStroke.Thickness=1.2

        local activeFill = Instance.new("Frame", pillBg)
        activeFill.Name = "ToggleActiveFill"
        activeFill.Size = UDim2.new(1,0,1,0)
        activeFill.BackgroundColor3=TRACK_ON; activeFill.BackgroundTransparency=defaultOn and 0 or 1
        activeFill.BorderSizePixel=0; activeFill.ZIndex=7; mkCorner(activeFill,13)
        local fillGradient=Instance.new("UIGradient",activeFill)
        fillGradient.Color=ColorSequence.new(TRACK_ON,TRACK_ON); fillGradient.Rotation=8

        local dot = Instance.new("Frame", pillBg)
        dot.Name = "SodaCap"
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Size=UDim2.new(0,18,0,18)
        dot.Position=defaultOn and UDim2.new(1,-13,0.5,0) or UDim2.new(0,13,0.5,0)
        dot.BackgroundColor3=defaultOn and DOT_ON or DOT_OFF; dot.BorderSizePixel=0; dot.ZIndex=10; mkCorner(dot,9)
        local coreStroke=Instance.new("UIStroke",dot); coreStroke.Color=Color3.fromRGB(255,255,255); coreStroke.Transparency=0; coreStroke.Thickness=2
        local dotGlow=Instance.new("ImageLabel",dot)
        dotGlow.Name="SodaGlow"
        dotGlow.BackgroundTransparency=1
        dotGlow.Image="rbxassetid://4996891970"
        dotGlow.ImageColor3=Color3.fromRGB(255,255,255)
        dotGlow.ImageTransparency=0.45
        dotGlow.AnchorPoint=Vector2.new(0.5,0.5)
        dotGlow.Position=UDim2.new(0.5,0,0.5,0)
        dotGlow.Size=UDim2.new(1,16,1,16)
        dotGlow.ZIndex=9

        local isOn = defaultOn or false
        local forceState
        local function setV(on)
            isOn = on
            row:SetAttribute("ActiveState",on)
            if on then
                activeFill.Position=UDim2.new(0.5,0,0,0)
                activeFill.Size=UDim2.new(0,0,1,0)
                activeFill.BackgroundTransparency=0
                TweenService:Create(activeFill,TweenInfo.new(0.28,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.new(0,0,0,0),Size=UDim2.new(1,0,1,0)}):Play()
                fillGradient.Rotation=8
                TweenService:Create(fillGradient,TweenInfo.new(0.35,Enum.EasingStyle.Quart),{Rotation=188}):Play()
            else
                TweenService:Create(activeFill,TweenInfo.new(0.2,Enum.EasingStyle.Quart),{BackgroundTransparency=1}):Play()
            end
            row.BackgroundColor3=ON_BG; row.BackgroundTransparency=0
            lbl.TextColor3=ON_TXT
            fillGradient.Color=ColorSequence.new(TRACK_ON,TRACK_ON)
            rowStroke.Color=Color3.fromRGB(65,65,65); rowStroke.Transparency=0; rowStroke.Thickness=1.5
            TweenService:Create(pillBg,TweenInfo.new(0.18),{BackgroundColor3=Color3.fromRGB(0,0,0)}):Play()
            TweenService:Create(dot,TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=on and UDim2.new(1,-13,0.5,0) or UDim2.new(0,13,0.5,0),BackgroundColor3=on and DOT_ON or DOT_OFF}):Play()
            TweenService:Create(pillStroke,TweenInfo.new(0.18),{Color=Color3.fromRGB(255,255,255),Transparency=0}):Play()
            TweenService:Create(coreStroke,TweenInfo.new(0.18),{Color=Color3.fromRGB(255,255,255),Transparency=0}):Play()
            task.delay(0.3, function() forceState(on) end)
        end
        forceState = function(on)
            row:SetAttribute("ActiveState",on)
            row.BackgroundColor3 = ON_BG
            row.BackgroundTransparency = 0
            lbl.TextColor3 = ON_TXT
            lbl.TextStrokeTransparency = 1
            pillBg.BackgroundColor3 = Color3.fromRGB(0,0,0)
            activeFill.BackgroundColor3 = TRACK_ON
            activeFill.BackgroundTransparency = on and 0 or 1
            if on then
                activeFill.Position=UDim2.new(0,0,0,0); activeFill.Size=UDim2.new(1,0,1,0)
            else
                activeFill.Position=UDim2.new(0.5,0,0,0); activeFill.Size=UDim2.new(0,0,1,0)
            end
            fillGradient.Color = ColorSequence.new(TRACK_ON,TRACK_ON)
            dot.Position = on and UDim2.new(1,-13,0.5,0) or UDim2.new(0,13,0.5,0)
            dot.BackgroundColor3 = on and DOT_ON or DOT_OFF
            pillStroke.Color = Color3.fromRGB(255,255,255); pillStroke.Transparency = 0
            coreStroke.Color = Color3.fromRGB(255,255,255); coreStroke.Transparency = 0
            rowStroke.Color = Color3.fromRGB(65,65,65)
            rowStroke.Transparency = 0
            rowStroke.Thickness = 1.5
        end
        
        task.defer(function() forceState(isOn) end)
        task.delay(1.5, function() if row.Parent then forceState(isOn) end end)
        local function toggle()
            isOn = not isOn; setV(isOn)
            if onToggle then pcall(onToggle, isOn) end
            requestSave()
        end
        local clk = Instance.new("TextButton", row); clk.Size = UDim2.new(1,-78,1,0); clk.BackgroundTransparency=1; clk.Text=""; clk.ZIndex=5; clk.BorderSizePixel=0; _G._K7SafeClick(clk, toggle)
        local pClk = Instance.new("TextButton", pillBg); pClk.Size = UDim2.new(1,0,1,0); pClk.BackgroundTransparency=1; pClk.Text=""; pClk.ZIndex=11; pClk.BorderSizePixel=0; _G._K7SafeClick(pClk, toggle)
        local activatorScale=Instance.new("UIScale",pillBg); activatorScale.Scale=1
        pClk.MouseEnter:Connect(function()
            TweenService:Create(pillStroke,TweenInfo.new(0.12),{Transparency=0,Thickness=2}):Play()
            TweenService:Create(activatorScale,TweenInfo.new(0.12,Enum.EasingStyle.Back),{Scale=1.055}):Play()
        end)
        pClk.MouseLeave:Connect(function()
            TweenService:Create(pillStroke,TweenInfo.new(0.12),{Color=Color3.fromRGB(255,255,255),Transparency=0,Thickness=1.5}):Play()
            TweenService:Create(activatorScale,TweenInfo.new(0.12),{Scale=1}):Play()
        end)
        pClk.MouseButton1Down:Connect(function() TweenService:Create(activatorScale,TweenInfo.new(0.07),{Scale=0.94}):Play() end)
        pClk.MouseButton1Up:Connect(function() TweenService:Create(activatorScale,TweenInfo.new(0.12,Enum.EasingStyle.Back),{Scale=1.04}):Play() end)
        return setV, row, lbl
    end

    local function getKeyDisplayName(kc)
        if not kc or kc == Enum.KeyCode.Unknown then return "None" end
        local n = kc.Name
        local pretty = {
            LeftControl="LCtrl", RightControl="RCtrl", LeftShift="LShift", RightShift="RShift",
            LeftAlt="LAlt", RightAlt="RAlt", LeftSuper="LWin", RightSuper="RWin",
            Return="Enter", Backspace="Bksp", Delete="Del", Escape="Esc",
            Space="Space", Tab="Tab", CapsLock="Caps",
            ButtonA="A", ButtonB="B", ButtonX="X", ButtonY="Y",
            ButtonL1="LB", ButtonL2="LT", ButtonL3="LS",
            ButtonR1="RB", ButtonR2="RT", ButtonR3="RS",
            ButtonSelect="View", ButtonStart="Menu",
            DPadUp="D↑", DPadDown="D↓", DPadLeft="D←", DPadRight="D→",
        }
        if pretty[n] then return pretty[n] end
        -- Keyboard: keep readable name (not truncated like controller labels)
        if n:match("^Button") or n:match("^DPad") or n:match("^Thumbstick") then
            return n:gsub("Button",""):sub(1,5)
        end
        if #n <= 6 then return n end
        return n:sub(1,6)
    end

    local function isGamepadKeyCode(kc)
        if not kc then return false end
        local n = kc.Name
        return n:find("Button") == 1 or n:find("DPad") == 1 or n:find("Thumbstick") == 1
    end

    local function refreshAllKeybindButtons()
        for keyName, btn in pairs(keybindBtnRefs) do
            if btn and Keys[keyName] then
                btn.Text = getKeyDisplayName(Keys[keyName])
            end
        end
    end

    local function makeKeybindRow(label, currentKey, onChanged, keyName)
        local row = Instance.new("Frame", currentPage)
        row:SetAttribute("AlwaysCyanOptionBar", true)
        row.Size = UDim2.new(1,0,0,44); row.BackgroundColor3=Color3.fromRGB(45,205,255); row.BackgroundTransparency=0; row.BorderSizePixel=0; row.LayoutOrder=LO()
        mkCorner(row,6)
        local div = Instance.new("Frame", row); div.Size = UDim2.new(1,-28,0,1); div.Position = UDim2.new(0,14,1,-1)
        div.BackgroundColor3 = currentColorScheme.divider; div.BackgroundTransparency = 0.85
        div.BorderSizePixel=0
        div.Visible=false
        local lbl = Instance.new("TextLabel", row); lbl.Size = UDim2.new(1,-88,1,0); lbl.Position = UDim2.new(0,14,0,0)
        lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=currentColorScheme.rowLabel; lbl.Font=Enum.Font.GothamBold
        lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Left
        local kbtn = Instance.new("TextButton", row); kbtn.Size = UDim2.new(0,60,0,26); kbtn.Position = UDim2.new(1,-72,0.5,-13)
        kbtn.BackgroundColor3 = Color3.fromRGB(45,205,255); kbtn.BackgroundTransparency = 0
        kbtn.BorderSizePixel=0; kbtn.Text = getKeyDisplayName(currentKey)
        kbtn.TextColor3 = currentColorScheme.buttonText; kbtn.Font = Enum.Font.GothamBold; kbtn.TextSize=11; kbtn.ZIndex=8
        kbtn.AutoButtonColor = false
        kbtn.Selectable = false -- prevent controller UI focus stealing on PC
        mkCorner(kbtn,13)

        local listening = false
        local lconn = nil
        local listenStartedAt = 0

        local function stopL(key)
            listening = false
            if lconn then lconn:Disconnect(); lconn = nil end
            TweenService:Create(kbtn, TweenInfo.new(0.12), {
                BackgroundColor3 = Color3.fromRGB(45,205,255),
                BackgroundTransparency = 0
            }):Play()
            kbtn.TextColor3 = currentColorScheme.buttonText
            if key then
                kbtn.Text = getKeyDisplayName(key)
                if onChanged then onChanged(key) end
                if requestSave then
                    requestSave()
                elseif saveConfig then
                    pcall(saveConfig)
                end
            else
                kbtn.Text = getKeyDisplayName(Keys[keyName] or Enum.KeyCode.Unknown)
            end
        end

        _G._K7SafeClick(kbtn, function()
            if listening then
                stopL(nil)
                return
            end
            listening = true
            listenStartedAt = tick()
            kbtn.Text = "..."
            kbtn.TextColor3 = currentColorScheme.buttonText
            TweenService:Create(kbtn, TweenInfo.new(0.12), {
                BackgroundColor3 = Color3.fromRGB(45,205,255),
                BackgroundTransparency = 0
            }):Play()

            if lconn then lconn:Disconnect() end
            lconn = UIS.InputBegan:Connect(function(inp, _gameProcessed)
                if not listening then return end
                -- ignore the click that opened listening + short grace period
                if tick() - listenStartedAt < 0.18 then return end

                local uit = inp.UserInputType
                local kc = inp.KeyCode

                -- Escape cancels
                if uit == Enum.UserInputType.Keyboard and kc == Enum.KeyCode.Escape then
                    stopL(nil)
                    return
                end

                -- Keyboard bind (PC default)
                if uit == Enum.UserInputType.Keyboard then
                    if kc == Enum.KeyCode.Unknown then return end
                    -- ignore pure modifiers alone if you want; allow them as binds
                    stopL(kc)
                    return
                end

                -- Only accept gamepad if a real gamepad is connected AND input is a face/bumper button
                if tostring(uit):find("Gamepad") then
                    local hasPad = false
                    pcall(function()
                        local pads = UIS:GetConnectedGamepads()
                        hasPad = pads and #pads > 0
                    end)
                    if not hasPad then return end -- ghost controller on PC
                    if not isGamepadKeyCode(kc) then return end
                    if kc == Enum.KeyCode.Thumbstick1 or kc == Enum.KeyCode.Thumbstick2 then return end
                    if kc == Enum.KeyCode.Unknown then return end
                    stopL(kc)
                    return
                end
                -- ignore mouse / touch while rebinding
            end)
        end)

        if keyName then keybindBtnRefs[keyName] = kbtn end
        return kbtn
    end

    -- ============================================================
    -- BUILD PAGES
    -- ============================================================
    -- SPEED TAB (unchanged)
    do
        local page = buildPage("Speed", function()
            makeGap(2)
            makeSectionHeader("Speed Values")
            makeGap(2)
            normalBox = makeSpeedStepperRow("Speed Normal", State.normalSpeed, 1, 500, 1, function(n)
                n = math.clamp(tonumber(n) or State.normalSpeed, 1, 500)
                State.normalSpeed = n
                markSpeedEdited()
                if normalBox then normalBox.Text = tostring(n) end
                if requestSave then requestSave() end
            end)
            carryBox = makeSpeedStepperRow("Carry Mode", State.carrySpeed, 1, 500, 1, function(n)
                n = math.clamp(tonumber(n) or State.carrySpeed, 1, 500)
                State.carrySpeed = n
                State._prevCarry = n
                markSpeedEdited()
                if carryBox then carryBox.Text = tostring(n) end
                if requestSave then requestSave() end
            end)
            laggerBox = makeSpeedStepperRow("Lagger", State.laggerSpeed, 0.1, 500, 1, function(n)
                n = math.clamp(tonumber(n) or State.laggerSpeed, 0.1, 500)
                State.laggerSpeed = n
                if laggerBox then laggerBox.Text = tostring(n) end
                if requestSave then requestSave() end
            end)
            laggerCarryBox = makeSpeedStepperRow("Lagger Carry", State.laggerCarrySpeed, 0.1, 500, 1, function(n)
                n = math.clamp(tonumber(n) or State.laggerCarrySpeed, 0.1, 500)
                State.laggerCarrySpeed = n
                if laggerCarryBox then laggerCarryBox.Text = tostring(n) end
                if requestSave then requestSave() end
            end)

            -- ── NEW: Auto Switch Carry Speed ─────────────────────────────
            makeGap(8)
            makeSectionHeader("Automatic Carry")
            makeGap(2)

            local softStealToggle = makeToggleRow("Auto Carry Switch", State.softStealEnabled or false, function(on)
                State.softStealEnabled = on
                if on then
                    if autoGrabModule and autoGrabModule.startSoftStealScanner then
                        autoGrabModule.startSoftStealScanner()
                    end
                else
                    if autoGrabModule and autoGrabModule.stopSoftStealScanner then
                        autoGrabModule.stopSoftStealScanner()
                    end
                end
                if stackBtnRefs.autoCarry then stackBtnRefs.autoCarry.setOn(on) end
                requestSave()
            end)
            toggleSetters["softSteal"] = softStealToggle

            makeGap(2)
            softStealRadiusBox = makeInputRow("Switch Radius", State.softStealRadius or 10, function(n)
                if n and n >= 1 and n <= 200 then State.softStealRadius = n; requestSave() end
            end)
            makeGap(2)
            softStealSpeedBox = makeInputRow("Switch Speed", State.softStealSpeed or 30, function(n)
                if n and n>0 then State.softStealSpeed = n; requestSave() end
            end)


            -- Carry Mode e Lagger Mode são acionados somente pelos botões flutuantes ou keybinds.


        end)
        page.LayoutOrder = 1
    end

    -- OPÇÕES PRINCIPAIS (exibidas diretamente, sem aba MAIN)
    do
        local page = buildPage("Main", function()
            makeGap(2)

            -- TP BATS: expandable selector requested by the user.
            do
                local header=Instance.new("Frame",currentPage)
                header:SetAttribute("AlwaysCyanOptionBar",true)
                header.Size=UDim2.new(1,-16,0,44); header.BackgroundColor3=Color3.fromRGB(90,225,255)
                header.BorderSizePixel=0; header.LayoutOrder=LO(); mkCorner(header,10)
                local hs=Instance.new("UIStroke",header); hs.Color=Color3.fromRGB(255,255,255); hs.Transparency=0.25; hs.Thickness=1.5
                local title=Instance.new("TextLabel",header)
                title.Size=UDim2.new(1,-60,1,0); title.Position=UDim2.new(0,12,0,0); title.BackgroundTransparency=1
                title.Text="TP BATS"; title.TextColor3=Color3.fromRGB(255,255,255); title.Font=Enum.Font.GothamBold
                title.TextSize=14; title.TextXAlignment=Enum.TextXAlignment.Left
                title.Size=UDim2.new(1,-16,1,0)

                local options=Instance.new("Frame",currentPage)
                options.Size=UDim2.new(1,-16,0,44); options.BackgroundTransparency=1
                options.BorderSizePixel=0; options.LayoutOrder=LO(); options.Visible=true

                -- V1 = TP Bat V1 do Mystery.Vs
                -- V2 = TP Bat V2 do Mystery.Vs
                -- V3 = TP Bat V2 do Ambitious (orbita)
                local TPB_MODES={"v1","v2","v3"}
                local refreshTpBar=makeVersionBar(options,{"V1","V2","V3"},function()
                    for i,m in ipairs(TPB_MODES) do
                        if State.tpBatMode==m then return i end
                    end
                    return 1
                end,function(idx)
                    _G.AceSetTpBatMode(TPB_MODES[idx])
                end)
                _G._K7SyncTpBatModeBox=refreshTpBar
                _G._K7SyncTpBatModeBox()
            end

            -- ANTI TP BAT: versão escolhida pelo mesmo botão flutuante de nome fixo.
            do
                local header=Instance.new("Frame",currentPage)
                header:SetAttribute("AlwaysCyanOptionBar",true)
                header.Size=UDim2.new(1,-16,0,44); header.BackgroundColor3=Color3.fromRGB(90,225,255)
                header.BorderSizePixel=0; header.LayoutOrder=LO(); mkCorner(header,10)
                local hs=Instance.new("UIStroke",header); hs.Color=Color3.fromRGB(255,255,255); hs.Transparency=0.25; hs.Thickness=1.5
                local title=Instance.new("TextLabel",header)
                title.Size=UDim2.new(1,-60,1,0); title.Position=UDim2.new(0,12,0,0); title.BackgroundTransparency=1
                title.Text="ANTI TP BAT"; title.TextColor3=Color3.fromRGB(255,255,255); title.Font=Enum.Font.GothamBold
                title.TextSize=14; title.TextXAlignment=Enum.TextXAlignment.Left
                title.Size=UDim2.new(1,-16,1,0)

                local options=Instance.new("Frame",currentPage)
                options.Size=UDim2.new(1,-16,0,44); options.BackgroundTransparency=1
                options.BorderSizePixel=0; options.LayoutOrder=LO(); options.Visible=true

                -- Barra de versões no estilo do Ambitious: V1 / V2 / V3 / V4
                local ATP_LABELS={"V1","V2","V3","V4"}
                local ATP_N=#ATP_LABELS
                local ATP_SEG=1/ATP_N
                local ATP_MODES={"v1","v2","v3","v4"}

                local verHolder=Instance.new("Frame",options)
                verHolder.Size=UDim2.new(1,-4,0,42)
                verHolder.Position=UDim2.new(0,2,0,1)
                verHolder.BackgroundColor3=Color3.fromRGB(24,25,32)
                verHolder.BackgroundTransparency=0.28
                verHolder.BorderSizePixel=0
                verHolder.ClipsDescendants=true
                mkCorner(verHolder,14)
                local vhStroke=Instance.new("UIStroke",verHolder)
                vhStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
                vhStroke.Color=Color3.fromRGB(45,205,255); vhStroke.Transparency=0.32; vhStroke.Thickness=1.4

                local verSlide=Instance.new("Frame",verHolder)
                verSlide.AnchorPoint=Vector2.new(0.5,0.5)
                verSlide.Size=UDim2.new(ATP_SEG,-4,1,-8)
                verSlide.Position=UDim2.new(ATP_SEG*0.5,0,0.5,0)
                verSlide.BackgroundColor3=Color3.fromRGB(45,205,255)
                verSlide.BackgroundTransparency=0.1
                verSlide.BorderSizePixel=0; verSlide.ZIndex=5
                mkCorner(verSlide,13)
                local slideStroke=Instance.new("UIStroke",verSlide)
                slideStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
                slideStroke.Color=Color3.fromRGB(190,240,255); slideStroke.Thickness=1.5; slideStroke.Transparency=0.1
                local slideGrad=Instance.new("UIGradient",verSlide)
                slideGrad.Color=ColorSequence.new({
                    ColorSequenceKeypoint.new(0,Color3.fromRGB(150,235,255)),
                    ColorSequenceKeypoint.new(0.5,Color3.fromRGB(45,205,255)),
                    ColorSequenceKeypoint.new(1,Color3.fromRGB(10,140,200)),
                })
                slideGrad.Rotation=22

                local verLabels={}
                for i,txt in ipairs(ATP_LABELS) do
                    local lbl=Instance.new("TextLabel",verHolder)
                    lbl.BackgroundTransparency=1
                    lbl.Text=txt
                    lbl.TextColor3=Color3.fromRGB(255,255,255)
                    lbl.TextStrokeColor3=Color3.fromRGB(0,0,0)
                    lbl.TextStrokeTransparency=0.2
                    lbl.TextSize=12
                    lbl.Font=Enum.Font.GothamBlack
                    lbl.AnchorPoint=Vector2.new(0.5,0.5)
                    lbl.Size=UDim2.new(ATP_SEG,0,1,0)
                    lbl.Position=UDim2.new(ATP_SEG*(i-0.5),0,0.5,0)
                    lbl.ZIndex=8
                    verLabels[i]=lbl

                    local click=Instance.new("TextButton",verHolder)
                    click.BackgroundTransparency=1; click.Text=""; click.AutoButtonColor=false
                    click.AnchorPoint=Vector2.new(0.5,0.5)
                    click.Size=UDim2.new(ATP_SEG,0,1,0)
                    click.Position=UDim2.new(ATP_SEG*(i-0.5),0,0.5,0)
                    click.ZIndex=10
                    local idx=i
                    _G._K7SafeClick(click,function() _G.AceSetAntiTpBatMode(ATP_MODES[idx]) end)
                end

                local function refreshAntiTpBar()
                    local index=1
                    for i,m in ipairs(ATP_MODES) do
                        if State.antiTpBatMode==m then index=i end
                    end
                    TweenService:Create(verSlide,TweenInfo.new(0.18,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
                        Position=UDim2.new(ATP_SEG*(index-0.5),0,0.5,0),
                        Size=UDim2.new(ATP_SEG,-4,1,-8),
                    }):Play()
                    for i,lbl in ipairs(verLabels) do
                        local sel=(i==index)
                        TweenService:Create(lbl,TweenInfo.new(0.14),{
                            TextTransparency=sel and 0 or 0.22,
                            TextStrokeTransparency=sel and 0.2 or 0.45,
                        }):Play()
                    end
                end
                _G._K7SyncAntiTpBatModeBox=refreshAntiTpBar
                refreshAntiTpBar()
            end

            -- AIMBOT: escolha da versao usada pelo keybind do Aimbot.
            -- V1 = Bat Aimbot (botao flutuante BAT AIMBOT)
            -- V2 = Bat V2 / bypass (botao flutuante BAT V2)
            do
                local options = makeExpandableSection("AIMBOT")
                local AIM_MODES={"old","new"}
                local refreshAimBar=makeVersionBar(options,{"V1","V2"},function()
                    return (State.aimbotMode=="new") and 2 or 1
                end,function(idx)
                    State.aimbotMode=AIM_MODES[idx]
                    if _G._K7SyncAimbotVersionBar then pcall(_G._K7SyncAimbotVersionBar) end
                    requestSave()
                end)
                _G._K7SyncAimbotVersionBar=refreshAimBar
            end

            -- INSTA RESET: motor do Ambitious, V1 = HipHeight / V2 = fling.
            -- O botao flutuante INSTA RESET executa a versao escolhida aqui.
            do
                local options = makeExpandableSection("INSTA RESET")
                local refreshResetBar=makeVersionBar(options,{"V1","V2"},function()
                    return math.clamp(tonumber(State.instaResetVersion) or 1,1,2)
                end,function(idx)
                    if _G.AceSetInstaResetVersion then _G.AceSetInstaResetVersion(idx) end
                end)
                _G._K7SyncInstaResetBar=refreshResetBar
            end

            makeGap(2)
            local setAntiBatRow = makeToggleRow("Anti Bat", _G.AmbitiousAntiBatEnabled == true, function(on)
                State.antiBatEnabled = on
                if _G.AmbitiousAntiBat then pcall(function() _G.AmbitiousAntiBat.setEnabled(on) end) end
                requestSave()
            end)
            toggleSetters["antiBat"] = setAntiBatRow

            makeGap(6)
            makeSectionHeader("Aimbot")
            makeGap(2)

            setAutoSwing = makeToggleRow("Auto Swing", State.autoSwingEnabled, function(on)
                State.autoSwingEnabled = on
                requestSave()
            end)
            toggleSetters["autoSwing"] = setAutoSwing
            setBatCounter = makeToggleRow("Bat Counter", State.batCounterEnabled, function(on)
                State.batCounterEnabled = on
                if on then startBatCounter() else stopBatCounter() end
                requestSave()
            end)
            toggleSetters["batCounter"] = setBatCounter
            setMedusaCounter = makeToggleRow("Medusa Counter", State.medusaCounterEnabled, function(on)
                State.medusaCounterEnabled = on
                if on then setupMedusaCounter(LP.Character) else stopMedusaCounter() end
                requestSave()
            end)
            toggleSetters["medusaCounter"] = setMedusaCounter

            makeGap(6)
            makeSectionHeader("Ragdoll")
            makeGap(2)
            local setRagdollCountdown = makeToggleRow("Ragdoll Countdown", State.ragdollCountdownEnabled, function(on)
                State.ragdollCountdownEnabled = on
                if on then _G.MysteryStartRagdollCountdown() else _G.MysteryStopRagdollCountdown() end
                requestSave()
            end)
            toggleSetters["ragdollCountdown"] = setRagdollCountdown

            makeGap(6)

            -- Aimbot enable is via stack button / keybind only; OLD/NEW switch below
            _G.AceAimbotSetVisual = function(on)
                local oldOnly = (on == true) and (_G.AceBatAimbotV2On ~= true)
                if stackBtnRefs and stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(oldOnly) end
            end

            -- OLD/BYPASS switch removed from the menu.
            -- OLD  -> floating button "BAT AIMBOT"
            -- BYPASS -> floating button "BAT V2"

            -- Mantem a sincronizacao visual definida pelo seletor TP BATS.

            makeGap(6)
            makeSectionHeader("Body Lock")
            makeGap(2)

            local setBodyLock = makeToggleRow("Body Lock", State.bodyLockEnabled == true, function(on)
                State.bodyLockEnabled = on
                if _G.AceSetBodyLock then _G.AceSetBodyLock(on) end
                requestSave()
            end)
            toggleSetters["bodyLock"] = setBodyLock
            _G.AceBodyLockSetVisual = function(on)
                pcall(setBodyLock, on == true)
            end

            makeInputRow("Body Lock Radius", State.bodyLockRadius or 60, function(n)
                State.bodyLockRadius = math.clamp(n, 5, 200)
                requestSave()
            end)

            makeGap(4)
            makeSectionHeader("Aimbot Speed")
            makeGap(2)

            _G.AceAimbotSpeedBox = makeSpeedStepperRow("Aimbot Speed (Bat Aimbot / Bat V2)", tonumber(AIMBOT_SPEED) or 50, 1, 500, 1, function(v)
                AIMBOT_SPEED = v
                LAGGER_AIMBOT_SPEED = v
                State.aimbotV2Speed = v
                State.aimbotV2LaggerSpeed = v
                if _G.AceAimbotSpeedBox then _G.AceAimbotSpeedBox.Text = tostring(v) end
                requestSave()
            end)


            makeGap(8)
            makeSectionHeader("Safe Mode")
            makeGap(2)
            do
                local smRow = makeToggleRow("Safe Mode", antiKickEnabled, function(on)
                    antiKickEnabled = on
                    if not on then
                    else
                        if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
                            _G.AceSafeModeForceStop("SAFE MODE ACTIVE")
                        end
                    end
                    if _G._K7SafeModeSetVisual then _G._K7SafeModeSetVisual(on) end
                    requestSave()
                end)
                _G._K7SafeModeSetVisual = smRow
                toggleSetters["safeMode"] = smRow

                local infoRow = Instance.new("Frame", currentPage)
                infoRow.Size = UDim2.new(1,-16,0,30)
                infoRow.BackgroundColor3 = Color3.fromRGB(45,205,255)
                infoRow.BackgroundTransparency = 0.18
                infoRow.BorderSizePixel = 0
                infoRow.LayoutOrder = LO()
                mkCorner(infoRow, 8)
                local infoLbl = Instance.new("TextLabel", infoRow)
                infoLbl.Size = UDim2.new(1,-16,1,0)
                infoLbl.Position = UDim2.new(0,8,0,0)
                infoLbl.BackgroundTransparency = 1
                infoLbl.Text = "Blocks aimbot during countdown & brainrot carry"
                infoLbl.TextColor3 = currentColorScheme.subText
                infoLbl.Font = Enum.Font.Gotham
                infoLbl.TextSize = 9
                infoLbl.TextXAlignment = Enum.TextXAlignment.Left
                infoLbl.TextWrapped = true
            end

            makeGap(8)
            makeSectionHeader("Infinite Jump & Defense")
            makeGap(2)
            setInfJump = makeToggleRow("Infinite Jump", State.infJumpEnabled, function(on)
                State.infJumpEnabled = on
                requestSave()
            end)
            toggleSetters["infJump"] = setInfJump
            local function attachDefenseArrow(parentRow, parentLabel, subRow)
                if parentLabel then parentLabel.Size = UDim2.new(1,-170,1,-4) end
                local arrow = Instance.new("TextButton", parentRow)
                arrow.Name = "SevenUpDefenseArrow"
                arrow.Size = UDim2.new(0,26,0,26)
                arrow.Position = UDim2.new(1,-152,0.5,-13)
                arrow.BackgroundColor3 = currentColorScheme.modeBtnBg or currentColorScheme.rowBg
                arrow.BackgroundTransparency = 0.14
                arrow.BorderSizePixel = 0
                arrow.Text = ">"
                arrow.TextColor3 = currentColorScheme.mainLight or currentColorScheme.main
                arrow.Font = Enum.Font.GothamBold
                arrow.TextSize = 16
                arrow.ZIndex = 20
                mkCorner(arrow,13)
                local open = false
                arrow:SetAttribute("Expanded", false)
                _G._K7SafeClick(arrow, function()
                    open = not open
                    arrow:SetAttribute("Expanded", open)
                    subRow.Visible = open
                    arrow.Text = open and "v" or ">"
                    local live = currentColorScheme
                    arrow.BackgroundColor3 = open and (live.modeBtnActBg or live.main)
                        or (live.modeBtnBg or live.rowBg)
                    arrow.TextColor3 = open and (live.buttonText or live.text)
                        or (live.mainLight or live.main)
                end)
                return arrow
            end

            local antiRagRow, antiRagLabel
            setAntiRag, antiRagRow, antiRagLabel = makeToggleRow("Anti Ragdoll", State.antiRagdollEnabled, function(on)
                State.antiRagdollEnabled = on
                if on then startAntiRagdollNew() else stopAntiRagdollNew() end
                requestSave()
            end)
            toggleSetters["antiRagdoll"] = setAntiRag

            local antiRagModeRow = Instance.new("Frame", currentPage)
            antiRagModeRow.Name = "AntiRagdollVersionRow"
            antiRagModeRow.Size = UDim2.new(1,-16,0,42)
            antiRagModeRow.BackgroundColor3 = Color3.fromRGB(4,28,15)
            antiRagModeRow.BackgroundTransparency = 0.18
            antiRagModeRow.BorderSizePixel = 0
            antiRagModeRow.LayoutOrder = LO()
            antiRagModeRow.Visible = false
            mkCorner(antiRagModeRow,12)
            local antiRagModeLabel = Instance.new("TextLabel", antiRagModeRow)
            antiRagModeLabel.Size = UDim2.new(1,-150,1,0)
            antiRagModeLabel.Position = UDim2.new(0,10,0,0)
            antiRagModeLabel.BackgroundTransparency = 1
            antiRagModeLabel.Text = "Anti-Ragdoll Mode"
            antiRagModeLabel.TextColor3 = currentColorScheme.rowLabel
            antiRagModeLabel.Font = Enum.Font.GothamSemibold
            antiRagModeLabel.TextSize = 11
            antiRagModeLabel.TextXAlignment = Enum.TextXAlignment.Left

            local function makeRagdollVersionButton(text, xOffset)
                local button = Instance.new("TextButton", antiRagModeRow)
                button.Size = UDim2.new(0,42,0,28)
                button.Position = UDim2.new(1,xOffset,0.5,-14)
                button.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
                button.BackgroundTransparency = 0.2
                button.BorderSizePixel = 0
                button.Text = text
                button.Font = Enum.Font.GothamBold
                button.TextSize = 11
                button.ZIndex = 8
                mkCorner(button,10)
                return button
            end
            local ragV1Button = makeRagdollVersionButton("V1",-136)
            local ragV2Button = makeRagdollVersionButton("V2",-90)
            local function refreshRagdollVersionButtons()
                local useV2 = State.antiRagdollVersion == "V2"
                ragV1Button.BackgroundColor3 = useV2 and Color3.fromRGB(31, 31, 31) or Color3.fromRGB(112, 112, 112)
                ragV2Button.BackgroundColor3 = useV2 and Color3.fromRGB(112, 112, 112) or Color3.fromRGB(31, 31, 31)
                ragV1Button.TextColor3 = useV2 and Color3.fromRGB(171, 171, 171) or Color3.fromRGB(255,255,255)
                ragV2Button.TextColor3 = useV2 and Color3.fromRGB(255,255,255) or Color3.fromRGB(171, 171, 171)
            end
            local function selectRagdollVersion(version)
                State.antiRagdollVersion = version
                refreshRagdollVersionButtons()
                if State.antiRagdollEnabled then
                    stopAntiRagdollNew()
                    startAntiRagdollNew()
                end
                requestSave()
            end
            _G._K7SafeClick(ragV1Button, function() selectRagdollVersion("V1") end)
            _G._K7SafeClick(ragV2Button, function() selectRagdollVersion("V2") end)
            _G._K7RefreshRagdollVersionButtons = refreshRagdollVersionButtons
            refreshRagdollVersionButtons()
            attachDefenseArrow(antiRagRow, antiRagLabel, antiRagModeRow)

            local antiDieToggle, antiDieRow, antiDieLabel = makeToggleRow("Anti Die", State.antiDieEnabled, function(on)
                if on then
                    startAntiDie()
                else
                    stopAntiDie()
                end
                requestSave()
            end)
            toggleSetters["antiDie"] = antiDieToggle

            local antiFlingToggle, antiFlingRow = makeToggleRow("Anti-Fling Shield", State.antiFlingShieldEnabled, function(on)
                if on then startAntiFlingShield() else stopAntiFlingShield() end
                requestSave()
            end)
            antiFlingRow.Name = "AntiFlingShieldRow"
            antiFlingRow.Visible = false
            toggleSetters["antiFlingShield"] = antiFlingToggle
            attachDefenseArrow(antiDieRow, antiDieLabel, antiFlingRow)

            makeGap(8)
            makeSectionHeader("Auto TP")
            makeGap(2)
            local autoTPToggle = makeToggleRow("Auto TP", State.autoTPEnabled, function(on)
                State.autoTPEnabled = on
                if on then startAutoTP() else stopAutoTP() end
                requestSave()
            end)
            toggleSetters["autoTP"] = autoTPToggle
            autoTPHeightBox = makeInputRow("Auto TP Height", State.autoTPHeight, function(n)
                if n and n >= 2 and n <= 500 then State.autoTPHeight = n; requestSave() end
            end)

            makeGap(8)
            makeSectionHeader("Combat")
            makeGap(2)

            local informationE01Toggle = makeToggleRow("Information E01", State.informationE01Enabled ~= false, function(on)
                State.informationE01Enabled = on
                if not on then
                    local playerGui = LP and LP:FindFirstChildOfClass("PlayerGui")
                    local activeMessage = playerGui and playerGui:FindFirstChild("BrainrotEnterIntro")
                    if activeMessage then activeMessage:Destroy() end
                end
                requestSave()
            end)
            toggleSetters["informationE01"] = informationE01Toggle

            makeGap(4)
            local autoLeftSetter = makeToggleRow("Auto Left", State.autoLeftEnabled == true, function(on)
                if on then startAutoLeft() else stopAutoLeft() end
                requestSave()
            end)
            toggleSetters["autoLeft"] = autoLeftSetter

            local autoRightSetter = makeToggleRow("Auto Right", State.autoRightEnabled == true, function(on)
                if on then startAutoRight() else stopAutoRight() end
                requestSave()
            end)
            toggleSetters["autoRight"] = autoRightSetter

            -- Bat Aimbot V1/V2: ativação disponível somente em Settings > Keybinds.
            makeGap(8)
        end)
        page.LayoutOrder = 2
    end

    -- VISUAL TAB (updated with Headless, Korblox, Outfit Changer)
    do
        local page = buildPage("Visual", function()
            makeGap(2)
            makeSectionHeader("Visual Settings")
            makeGap(2)
            
            antiLagSetter = makeToggleRow("Anti-Lag", State.antiLagEnabled, function(on)
                State.antiLagEnabled = on
                if on then enableAntiLag() else disableAntiLag() end
                -- Avatar Change continua aparecendo com o Anti-Lag ligado.
                task.spawn(function()
                    task.wait(0.4)
                    if _G._K7AvatarChangerReapply then pcall(_G._K7AvatarChangerReapply, true) end
                end)
                -- Garante que a skin continue aparecendo normal.
                if State.customSkinEnabled then
                    task.spawn(function()
                        task.wait(0.35)
                        pcall(applyCustomSkinToChar, LP.Character, true)
                    end)
                end
                requestSave()
            end)
            toggleSetters["antiLag"] = antiLagSetter

            local satSetter = makeToggleRow("Saturated Colors", State.saturatedColorsEnabled, function(on)
                State.saturatedColorsEnabled = on
                if on then enableSaturatedColors() else disableSaturatedColors() end
                if State.customSkinEnabled then
                    task.spawn(function()
                        task.wait(0.35)
                        pcall(applyCustomSkinToChar, LP.Character, true)
                    end)
                end
                requestSave()
            end)
            toggleSetters["saturatedColors"] = satSetter

            makeGap(4)
            makeSectionHeader("Field of View")
            makeGap(2)
            
            makeInputRow("FOV (Normal)", _G._VezyFOV or 70, function(n)
                if n >= 70 and n <= 180 then
                    _G._VezyFOV = n
                    local cam = workspace.CurrentCamera
                    if cam and not State.stretchedResEnabled then
                        pcall(function() cam.FieldOfView = n end)
                    end
                    requestSave()
                end
            end)

            makeGap(4)
            makeSectionHeader("Wide Stretch")
            makeGap(2)
            
            stretchSetter = makeToggleRow("Stretch Rez", State.stretchedResEnabled, function(on)
                State.stretchedResEnabled = on
                if on then enableStretchRez() else disableStretchRez() end
                requestSave()
            end)
            toggleSetters["stretchedRes"] = stretchSetter

            makeInputRow("Stretch Value", State.stretchValue or 0.7, function(n)
                n = math.clamp(tonumber(n) or 0.7, 0.3, 1.5)
                State.stretchValue = n
                if State.stretchedResEnabled then
                    disableStretchRez()
                    enableStretchRez()
                end
                requestSave()
            end)

            makeGap(4)
            makeSectionHeader("Character Visuals")
            makeGap(2)
            
            removeAccSetter = makeToggleRow("Remove Accessories", State.removeAcc, function(on)
                State.removeAcc = on
                if not on then
                    if _G._removeAccStop then _G._removeAccStop() end
                end
                if State.customSkinEnabled then pcall(applyCustomSkinToChar, LP.Character) end
                if on then
                    if _G._removeAccStart then _G._removeAccStart() end
                    -- Avatar Change continua aparecendo com Remove Accessories.
                    task.spawn(function()
                        task.wait(0.4)
                        if _G._K7AvatarChangerReapply then pcall(_G._K7AvatarChangerReapply, true) end
                    end)
                    -- ApplyDescription may stream the catalog accessory back
                    -- a few frames later. Keep purging only the skin-added hat
                    -- during that short window.
                    task.spawn(function()
                        for _ = 1, 16 do
                            if not State.removeAcc then break end
                            pcall(removeCharAccessories, LP.Character)
                            task.wait(0.12)
                        end
                    end)
                end
                requestSave()
            end)
            toggleSetters["removeAcc"] = removeAccSetter

            -- ── NEW: Headless Toggle ──────────────────────────────
            local headlessSetter = makeToggleRow("Headless", State.headlessEnabled, function(on)
                State.headlessEnabled = on
                applyCharterToChar(LP.Character)
                requestSave()
            end)
            toggleSetters["headless"] = headlessSetter

            -- ── NEW: Korblox Toggle ──────────────────────────────
            local korbloxSetter = makeToggleRow("Korblox", State.korbloxEnabled, function(on)
                State.korbloxEnabled = on
                applyCharterToChar(LP.Character)
                requestSave()
            end)
            toggleSetters["korblox"] = korbloxSetter

            -- Custom Skin removida do menu.

            State.outfit1Applied = false
            State.outfit2Applied = false
            State.outfit3Applied = false
            if false then -- legacy outfit UI removed

            -- ── NEW: Outfit Changer ──────────────────────────────
            do
                local row = Instance.new("Frame", currentPage)
                row:SetAttribute("AlwaysCyanOptionBar", true)
                row.Size = UDim2.new(1,-16,0,42)
                row.BackgroundColor3 = Color3.fromRGB(90,225,255)
                row.BackgroundTransparency = 0.18
                row.BorderSizePixel = 0
                row.LayoutOrder = LO()
                mkCorner(row, 12)

                local lbl = Instance.new("TextLabel", row)
                lbl.Size = UDim2.new(0.5,0,1,0)
                lbl.Position = UDim2.new(0,14,0,0)
                lbl.BackgroundTransparency = 1
                lbl.Text = "Legacy Style 1"
                lbl.TextColor3 = currentColorScheme.rowLabel
                lbl.Font = Enum.Font.GothamBold
                lbl.TextSize = 13
                lbl.TextXAlignment = Enum.TextXAlignment.Left

                local applyBtn = Instance.new("TextButton", row)
                applyBtn.Size = UDim2.new(0, 70, 0, 28)
                applyBtn.Position = UDim2.new(1, -84, 0.5, -14)
                applyBtn.BackgroundColor3 = State.outfit1Applied and currentColorScheme.main or currentColorScheme.inputBg
                applyBtn.BackgroundTransparency = 0.15
                applyBtn.BorderSizePixel = 0
                applyBtn.Text = State.outfit1Applied and "On" or "Off"
                applyBtn.TextColor3 = State.outfit1Applied and currentColorScheme.buttonText or currentColorScheme.text
                applyBtn.Font = Enum.Font.GothamBold
                applyBtn.TextSize = 12
                applyBtn.ZIndex = 5
                mkCorner(applyBtn, 6)

                local function updateOutfitBtn()
                    applyBtn.Text = State.outfit1Applied and "On" or "Off"
                    applyBtn.BackgroundColor3 = State.outfit1Applied and currentColorScheme.main or currentColorScheme.inputBg
                    applyBtn.TextColor3 = State.outfit1Applied and currentColorScheme.buttonText or currentColorScheme.text
                end
                toggleSetters["outfit1"] = function() updateOutfitBtn() end

                _G._K7SafeClick(applyBtn, function()
                    State.outfit1Applied = not State.outfit1Applied
                    if State.outfit1Applied then
                        State.outfit3Applied = false
                    end
                    applyCharterToChar(LP.Character)
                    updateOutfitBtn()
                    if toggleSetters["outfit3"] then pcall(toggleSetters["outfit3"]) end
                    requestSave()
                end)

                local info = Instance.new("Frame", currentPage)
                info.Size = UDim2.new(1,-16,0,24)
                info.BackgroundColor3 = Color3.fromRGB(45,205,255)
                info.BackgroundTransparency = 0.18
                info.BorderSizePixel = 0
                info.LayoutOrder = LO()
                mkCorner(info, 8)
                local infoLbl = Instance.new("TextLabel", info)
                infoLbl.Size = UDim2.new(1,-16,1,0)
                infoLbl.Position = UDim2.new(0,8,0,0)
                infoLbl.BackgroundTransparency = 1
                infoLbl.Text = "Head: 137685008029440  •  Shirt: 6281968058  •  Pants: 1073888653"
                infoLbl.TextColor3 = currentColorScheme.subText
                infoLbl.Font = Enum.Font.Gotham
                infoLbl.TextSize = 9
                infoLbl.TextXAlignment = Enum.TextXAlignment.Left
                infoLbl.TextWrapped = true
            end

            -- Try Hard 1 Button
            do
                local row2 = Instance.new("Frame", currentPage)
                row2.Size = UDim2.new(1,-16,0,42)
                row2.BackgroundColor3 = Color3.fromRGB(90,225,255)
                row2.BackgroundTransparency = 0.18
                row2.BorderSizePixel = 0
                row2.LayoutOrder = LO()
                mkCorner(row2, 12)

                local lbl2 = Instance.new("TextLabel", row2)
                lbl2.Size = UDim2.new(0.5,0,1,0)
                lbl2.Position = UDim2.new(0,14,0,0)
                lbl2.BackgroundTransparency = 1
                lbl2.Text = "Try Hard 1"
                lbl2.TextColor3 = currentColorScheme.rowLabel
                lbl2.Font = Enum.Font.GothamBold
                lbl2.TextSize = 13
                lbl2.TextXAlignment = Enum.TextXAlignment.Left

                local applyBtn2 = Instance.new("TextButton", row2)
                applyBtn2.Size = UDim2.new(0, 70, 0, 28)
                applyBtn2.Position = UDim2.new(1, -84, 0.5, -14)
                applyBtn2.BackgroundColor3 = State.outfit2Applied and currentColorScheme.main or currentColorScheme.inputBg
                applyBtn2.BackgroundTransparency = 0.15
                applyBtn2.BorderSizePixel = 0
                applyBtn2.Text = State.outfit2Applied and "On" or "Off"
                applyBtn2.TextColor3 = State.outfit2Applied and currentColorScheme.buttonText or currentColorScheme.text
                applyBtn2.Font = Enum.Font.GothamBold
                applyBtn2.TextSize = 12
                applyBtn2.ZIndex = 5
                mkCorner(applyBtn2, 6)

                local function updateOutfitBtn2()
                    applyBtn2.Text = State.outfit2Applied and "On" or "Off"
                    applyBtn2.BackgroundColor3 = State.outfit2Applied and currentColorScheme.main or currentColorScheme.inputBg
                    applyBtn2.TextColor3 = State.outfit2Applied and currentColorScheme.buttonText or currentColorScheme.text
                end
                toggleSetters["outfit2"] = function() updateOutfitBtn2() end

                _G._K7SafeClick(applyBtn2, function()
                    State.outfit2Applied = not State.outfit2Applied
                    if State.outfit2Applied then
                        State.outfit1Applied = false
                        State.outfit3Applied = false
                    end
                    applyCharterToChar(LP.Character)
                    updateOutfitBtn2()
                    if toggleSetters["outfit1"] then pcall(toggleSetters["outfit1"]) end
                    if toggleSetters["outfit3"] then pcall(toggleSetters["outfit3"]) end
                    requestSave()
                end)

                local info2 = Instance.new("Frame", currentPage)
                info2.Size = UDim2.new(1,-16,0,24)
                info2.BackgroundColor3 = Color3.fromRGB(45,205,255)
                info2.BackgroundTransparency = 0.18
                info2.BorderSizePixel = 0
                info2.LayoutOrder = LO()
                mkCorner(info2, 8)
                local infoLbl2 = Instance.new("TextLabel", info2)
                infoLbl2.Size = UDim2.new(1,-16,1,0)
                infoLbl2.Position = UDim2.new(0,8,0,0)
                infoLbl2.BackgroundTransparency = 1
                infoLbl2.Text = "Head: 11711107876  •  Shirt: 14101026303  •  Pants: 4620736485"
                infoLbl2.TextColor3 = currentColorScheme.subText
                infoLbl2.Font = Enum.Font.Gotham
                infoLbl2.TextSize = 9
                infoLbl2.TextXAlignment = Enum.TextXAlignment.Left
                infoLbl2.TextWrapped = true
            end

            -- Venom Fit Button
            do
                local row3 = Instance.new("Frame", currentPage)
                row3.Size = UDim2.new(1,-16,0,42)
                row3.BackgroundColor3 = Color3.fromRGB(90,225,255)
                row3.BackgroundTransparency = 0.18
                row3.BorderSizePixel = 0
                row3.LayoutOrder = LO()
                mkCorner(row3, 12)

                local lbl3 = Instance.new("TextLabel", row3)
                lbl3.Size = UDim2.new(0.5,0,1,0)
                lbl3.Position = UDim2.new(0,14,0,0)
                lbl3.BackgroundTransparency = 1
                lbl3.Text = "Venom Fit"
                lbl3.TextColor3 = currentColorScheme.rowLabel
                lbl3.Font = Enum.Font.GothamBold
                lbl3.TextSize = 13
                lbl3.TextXAlignment = Enum.TextXAlignment.Left

                local applyBtn3 = Instance.new("TextButton", row3)
                applyBtn3.Size = UDim2.new(0, 70, 0, 28)
                applyBtn3.Position = UDim2.new(1, -84, 0.5, -14)
                applyBtn3.BackgroundColor3 = State.outfit3Applied and currentColorScheme.main or currentColorScheme.inputBg
                applyBtn3.BackgroundTransparency = 0.15
                applyBtn3.BorderSizePixel = 0
                applyBtn3.Text = State.outfit3Applied and "On" or "Off"
                applyBtn3.TextColor3 = State.outfit3Applied and currentColorScheme.buttonText or currentColorScheme.text
                applyBtn3.Font = Enum.Font.GothamBold
                applyBtn3.TextSize = 12
                applyBtn3.ZIndex = 5
                mkCorner(applyBtn3, 6)

                local function updateOutfitBtn3()
                    applyBtn3.Text = State.outfit3Applied and "On" or "Off"
                    applyBtn3.BackgroundColor3 = State.outfit3Applied and currentColorScheme.main or currentColorScheme.inputBg
                    applyBtn3.TextColor3 = State.outfit3Applied and currentColorScheme.buttonText or currentColorScheme.text
                end
                toggleSetters["outfit3"] = function() updateOutfitBtn3() end

                _G._K7SafeClick(applyBtn3, function()
                    State.outfit1Applied = false
                    State.outfit3Applied = not State.outfit3Applied
                    applyCharterToChar(LP.Character)
                    updateOutfitBtn3()
                    if toggleSetters["outfit1"] then pcall(toggleSetters["outfit1"]) end
                    requestSave()
                end)
            end

            -- ── Animation Pack selector ──────────────────────────────
            makeGap(4)
            end -- legacy outfit UI removed
            makeGap(4)
            makeSectionHeader("Animation Pack")
            makeGap(2)

            do
                local packRow = Instance.new("Frame", currentPage)
                packRow.Size = UDim2.new(1,-16,0,58)
                packRow.BackgroundColor3 = Color3.fromRGB(90,225,255); packRow.BackgroundTransparency = 0
                packRow.BorderSizePixel=0; packRow.LayoutOrder=LO()
                mkCorner(packRow, 17)
                local packRowStroke=Instance.new("UIStroke",packRow); packRowStroke.Color=currentColorScheme.mainLight; packRowStroke.Transparency=0.46; packRowStroke.Thickness=1.4
                local packRowGradient=Instance.new("UIGradient",packRow)
                packRowGradient.Color=adaptiveCanColorSequence(currentColorScheme,false)

                local packLbl = Instance.new("TextLabel",packRow)
                packLbl.Size=UDim2.new(0,48,1,0); packLbl.Position=UDim2.new(0,8,0,0)
                packLbl.BackgroundTransparency=1; packLbl.Text="PACK"
                packLbl.TextColor3=currentColorScheme.rowLabel; packLbl.Font=Enum.Font.GothamBold; packLbl.TextSize=9
                packLbl.TextXAlignment=Enum.TextXAlignment.Left

                local packHolder = Instance.new("Frame",packRow)
                packHolder.Size=UDim2.new(0,124,0,36); packHolder.Position=UDim2.new(0,96,0.5,-18)
                packHolder.BackgroundColor3=currentColorScheme.modeBtnBg; packHolder.BackgroundTransparency=0.05
                packHolder.BorderSizePixel=0; packHolder.ClipsDescendants=true
                mkCorner(packHolder,12)
                local packHolderStroke=Instance.new("UIStroke",packHolder); packHolderStroke.Color=currentColorScheme.mainLight; packHolderStroke.Transparency=0.34; packHolderStroke.Thickness=1.3
                local packHolderGradient=Instance.new("UIGradient",packHolder); packHolderGradient.Color=ColorSequence.new(currentColorScheme.mainDark,currentColorScheme.stackBg); packHolderGradient.Rotation=15

                local packValLbl = Instance.new("TextLabel",packHolder)
                packValLbl.Size=UDim2.new(1,0,1,0); packValLbl.BackgroundTransparency=1
                packValLbl.Text=selectedAnimationPack; packValLbl.TextColor3=currentColorScheme.text
                packValLbl.Font=Enum.Font.GothamBold; packValLbl.TextSize=9; packValLbl.TextXAlignment=Enum.TextXAlignment.Center; packValLbl.ZIndex=9
                packValLbl.TextTruncate=Enum.TextTruncate.AtEnd
                _G._K7AnimPackValLbl = packValLbl

                local function setPackIdx(next)
                    if next<1 then next=#AnimationPackList end
                    if next>#AnimationPackList then next=1 end
                    AnimationPackIndex = next
                    local pack = AnimationPackList[next]
                    selectedAnimationPack = pack
                    _G._K7SelectedAnimationPack = pack
                    pcall(function() if _K7SaveAnimPackFile then _K7SaveAnimPackFile(pack) end end)
                    packValLbl.Text = pack
                    State.tryardAnimEnabled = pack ~= "OFF"
                    pcall(function()
                        if _G._K7SetAnimationPack then _G._K7SetAnimationPack(pack)
                        else applyAnimationPack(pack) end
                    end)
                    requestSave()
                end
                _G._K7AnimPackRefreshRow = function()
                    syncAnimationPackIndex()
                    local shown = _G._K7SelectedAnimationPack or selectedAnimationPack or "OFF"
                    if _K7ResolvePackName then shown = _K7ResolvePackName(shown) or shown end
                    packValLbl.Text = tostring(shown)
                    selectedAnimationPack = shown
                    _G._K7SelectedAnimationPack = shown
                end
                -- Sync label to saved pack as soon as the row is built
                task.defer(function()
                    pcall(function()
                        local disk = _K7LoadAnimPackFile and _K7LoadAnimPackFile()
                        local pack = (_K7ResolvePackName and _K7ResolvePackName(_G._K7SelectedAnimationPack or selectedAnimationPack)) or disk or selectedAnimationPack
                        if pack and pack ~= "" then
                            selectedAnimationPack = pack
                            _G._K7SelectedAnimationPack = pack
                            packValLbl.Text = pack
                            syncAnimationPackIndex()
                        end
                    end)
                end)

                local packLeft = Instance.new("TextButton",packRow)
                packLeft.Size=UDim2.new(0,30,0,36); packLeft.Position=UDim2.new(0,60,0.5,-18)
                packLeft.BackgroundColor3=currentColorScheme.main; packLeft.BackgroundTransparency=0.05
                packLeft.BorderSizePixel=0; packLeft.Text="<"; packLeft.TextColor3=currentColorScheme.buttonText
                packLeft.Font=Enum.Font.GothamBold; packLeft.TextSize=15; packLeft.AutoButtonColor=false
                mkCorner(packLeft,15)
                local packLeftStroke=Instance.new("UIStroke",packLeft); packLeftStroke.Color=currentColorScheme.mainLight; packLeftStroke.Transparency=0.45
                _G._K7SafeClick(packLeft, function() setPackIdx(AnimationPackIndex-1) end)
                packLeft.MouseEnter:Connect(function() TweenService:Create(packLeft,TweenInfo.new(0.1),{BackgroundColor3=currentColorScheme.mainLight,BackgroundTransparency=0}):Play() end)
                packLeft.MouseLeave:Connect(function() TweenService:Create(packLeft,TweenInfo.new(0.1),{BackgroundColor3=currentColorScheme.main,BackgroundTransparency=0.05}):Play() end)

                local packRight = Instance.new("TextButton",packRow)
                packRight.Size=UDim2.new(0,30,0,36); packRight.Position=UDim2.new(1,-38,0.5,-18)
                packRight.BackgroundColor3=currentColorScheme.main; packRight.BackgroundTransparency=0.05
                packRight.BorderSizePixel=0; packRight.Text=">"; packRight.TextColor3=currentColorScheme.buttonText
                packRight.Font=Enum.Font.GothamBold; packRight.TextSize=15; packRight.AutoButtonColor=false
                mkCorner(packRight,15)
                local packRightStroke=Instance.new("UIStroke",packRight); packRightStroke.Color=currentColorScheme.mainLight; packRightStroke.Transparency=0.45
                _G._K7SafeClick(packRight, function() setPackIdx(AnimationPackIndex+1) end)
                packRight.MouseEnter:Connect(function() TweenService:Create(packRight,TweenInfo.new(0.1),{BackgroundColor3=currentColorScheme.mainLight,BackgroundTransparency=0}):Play() end)
                packRight.MouseLeave:Connect(function() TweenService:Create(packRight,TweenInfo.new(0.1),{BackgroundColor3=currentColorScheme.main,BackgroundTransparency=0.05}):Play() end)

                local function refreshAnimPackTheme()
                    local live = currentColorScheme
                    packRow.BackgroundColor3 = Color3.fromRGB(90,225,255); packRow.BackgroundTransparency = 0
                    packRowStroke.Color = live.mainLight
                    packRowGradient.Color = adaptiveCanColorSequence(live,false)
                    packLbl.TextColor3 = live.rowLabel
                    packHolder.BackgroundColor3 = live.modeBtnBg
                    packHolderStroke.Color = live.mainLight
                    packHolderGradient.Color = ColorSequence.new(live.mainDark,live.stackBg)
                    packValLbl.TextColor3 = live.text
                    for _, button in ipairs({packLeft,packRight}) do
                        button.BackgroundColor3 = live.main
                        button.TextColor3 = live.buttonText
                        local buttonStroke = button:FindFirstChildWhichIsA("UIStroke")
                        if buttonStroke then buttonStroke.Color = live.mainLight end
                    end
                end
                _G._K7RefreshAnimPackTheme = refreshAnimPackTheme
                refreshAnimPackTheme()

                syncAnimationPackIndex(); packValLbl.Text=selectedAnimationPack
            end
            local tryardSetter = nil
            toggleSetters["tryardAnim"] = function(on)
                if on then
                    local pack = _G._K7SelectedAnimationPack or selectedAnimationPack
                    if not pack or pack == "OFF" then pack = "Stylish" end
                    applyAnimationPack(pack)
                else
                    -- keep selected pack saved; only stop applying temporarily is not desired
                    -- user asked pack to stay saved and active by name
                    local pack = _G._K7SelectedAnimationPack or selectedAnimationPack
                    if pack and pack ~= "OFF" then applyAnimationPack(pack) end
                end
            end

            -- ── Sky Theme ──────────────────────────────────────────
            makeGap(4)
            makeSectionHeader("Sky Theme")
            makeGap(2)

            do
                local skyRow = Instance.new("Frame", currentPage)
                skyRow.Size = UDim2.new(1,-16,0,58)
                skyRow.BackgroundColor3 = Color3.fromRGB(90, 225, 255)
                skyRow.BackgroundTransparency = 0.18
                skyRow.BorderSizePixel = 0
                skyRow.LayoutOrder = LO()
                mkCorner(skyRow, 17)
                local skyRowStroke=Instance.new("UIStroke",skyRow); skyRowStroke.Color=Color3.fromRGB(206, 206, 206); skyRowStroke.Transparency=0.46; skyRowStroke.Thickness=1.4
                local skyRowGradient=Instance.new("UIGradient",skyRow)
                skyRowGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(220, 220, 220)),ColorSequenceKeypoint.new(0.08,Color3.fromRGB(99, 99, 99)),ColorSequenceKeypoint.new(0.72,Color3.fromRGB(35, 35, 35)),ColorSequenceKeypoint.new(1,Color3.fromRGB(164, 164, 164))})

                local skyLbl = Instance.new("TextLabel", skyRow)
                skyLbl.Size = UDim2.new(0,48,1,0)
                skyLbl.Position = UDim2.new(0,8,0,0)
                skyLbl.BackgroundTransparency = 1
                skyLbl.Text = "SKY"
                skyLbl.TextColor3 = Color3.fromRGB(255,255,255)
                skyLbl.Font = Enum.Font.GothamBold
                skyLbl.TextSize = 9
                skyLbl.TextXAlignment = Enum.TextXAlignment.Left

                local _skyIdx = 1
                for i, name in ipairs(SKY_PRESETS_LIST) do
                    if name == State.skyTheme then _skyIdx = i; break end
                end

                local skyHolder = Instance.new("Frame", skyRow)
                skyHolder.Size = UDim2.new(0,124,0,36)
                skyHolder.Position = UDim2.new(0,96,0.5,-18)
                skyHolder.BackgroundColor3 = Color3.fromRGB(0,18,9)
                skyHolder.BackgroundTransparency = 0.05
                skyHolder.BorderSizePixel = 0
                skyHolder.ClipsDescendants = true
                mkCorner(skyHolder, 12)
                local skyHolderStroke=Instance.new("UIStroke",skyHolder); skyHolderStroke.Color=currentColorScheme.mainLight; skyHolderStroke.Transparency=0.34; skyHolderStroke.Thickness=1.3
                local skyHolderGradient=Instance.new("UIGradient",skyHolder); skyHolderGradient.Color=ColorSequence.new(Color3.fromRGB(61, 61, 61),Color3.fromRGB(0,25,12)); skyHolderGradient.Rotation=15

                local skyValLbl = Instance.new("TextLabel", skyHolder)
                skyValLbl.Size = UDim2.new(1,0,1,0)
                skyValLbl.BackgroundTransparency = 1
                skyValLbl.Text = SKY_PRESETS_LIST[_skyIdx]
                skyValLbl.TextColor3 = Color3.fromRGB(240,240,240)
                skyValLbl.Font = Enum.Font.GothamBold
                skyValLbl.TextSize = 9
                skyValLbl.TextXAlignment = Enum.TextXAlignment.Center
                skyValLbl.ZIndex = 9
                skyValLbl.TextTruncate = Enum.TextTruncate.AtEnd

                local function setSkyIdx(next)
                    if next < 1 then next = #SKY_PRESETS_LIST end
                    if next > #SKY_PRESETS_LIST then next = 1 end
                    _skyIdx = next
                    State.skyTheme = SKY_PRESETS_LIST[_skyIdx]
                    skyValLbl.Text = State.skyTheme
                    pcall(applyCustomSky, State.skyTheme)
                    requestSave()
                end

                local skyLeft = Instance.new("TextButton", skyRow)
                skyLeft.Size = UDim2.new(0,30,0,36)
                skyLeft.Position = UDim2.new(0,60,0.5,-18)
                skyLeft.BackgroundColor3 = Color3.fromRGB(184,28,38)
                skyLeft.BackgroundTransparency = 0.05
                skyLeft.BorderSizePixel = 0
                skyLeft.Text = "<"
                skyLeft.TextColor3 = Color3.fromRGB(255,255,255)
                skyLeft.Font = Enum.Font.GothamBold
                skyLeft.TextSize = 15
                skyLeft.AutoButtonColor = false
                mkCorner(skyLeft, 15)
                local skyLeftStroke=Instance.new("UIStroke",skyLeft); skyLeftStroke.Color=Color3.fromRGB(255,210,210); skyLeftStroke.Transparency=0.45
                _G._K7SafeClick(skyLeft, function() setSkyIdx(_skyIdx - 1) end)
                skyLeft.MouseEnter:Connect(function() TweenService:Create(skyLeft,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(235,48,55),BackgroundTransparency=0}):Play() end)
                skyLeft.MouseLeave:Connect(function() TweenService:Create(skyLeft,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(184,28,38),BackgroundTransparency=0.05}):Play() end)

                local skyRight = Instance.new("TextButton", skyRow)
                skyRight.Size = UDim2.new(0,30,0,36)
                skyRight.Position = UDim2.new(1,-38,0.5,-18)
                skyRight.BackgroundColor3 = Color3.fromRGB(184,28,38)
                skyRight.BackgroundTransparency = 0.05
                skyRight.BorderSizePixel = 0
                skyRight.Text = ">"
                skyRight.TextColor3 = Color3.fromRGB(255,255,255)
                skyRight.Font = Enum.Font.GothamBold
                skyRight.TextSize = 15
                skyRight.AutoButtonColor = false
                mkCorner(skyRight, 15)
                local skyRightStroke=Instance.new("UIStroke",skyRight); skyRightStroke.Color=Color3.fromRGB(255,210,210); skyRightStroke.Transparency=0.45
                _G._K7SafeClick(skyRight, function() setSkyIdx(_skyIdx + 1) end)
                skyRight.MouseEnter:Connect(function() TweenService:Create(skyRight,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(235,48,55),BackgroundTransparency=0}):Play() end)
                skyRight.MouseLeave:Connect(function() TweenService:Create(skyRight,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(184,28,38),BackgroundTransparency=0.05}):Play() end)
            end


            -- Tools imported from AmbitiousTest.
            makeGap(4)
            makeSectionHeader("Tools")
            makeGap(2)

            local function setToolModule(stateKey, globalFlag, apiName, on)
                State[stateKey] = on == true
                _G[globalFlag] = State[stateKey]
                local api = _G[apiName]
                if api and api.setEnabled then pcall(api.setEnabled, State[stateKey]) end
                requestSave()
            end

            local customToolsSetter = makeToggleRow("Custom Tools", State.customToolsEnabled == true, function(on)
                setToolModule("customToolsEnabled", "AmbitiousCustomToolsEnabled", "AmbitiousCustomTools", on)
            end)
            toggleSetters["customTools"] = customToolsSetter

            local customToolsPicker
            local function closeCustomToolsPicker()
                if customToolsPicker and customToolsPicker.Parent then customToolsPicker:Destroy() end
                customToolsPicker=nil
            end
            local function openCustomToolsPicker()
                if customToolsPicker and customToolsPicker.Parent then closeCustomToolsPicker(); return end
                local assets=_G.AmbitiousCustomToolAssets or {}
                customToolsPicker=Instance.new("Frame",gui); customToolsPicker.Name="MysteryCustomToolsPicker"
                customToolsPicker.Size=UDim2.fromScale(1,1); customToolsPicker.BackgroundColor3=Color3.fromRGB(45,205,255)
                customToolsPicker.BackgroundTransparency=.3; customToolsPicker.ZIndex=100
                local panel=Instance.new("Frame",customToolsPicker); panel.Size=UDim2.new(0,420,0,470); panel.Position=UDim2.new(.5,-210,.5,-235)
                panel.BackgroundColor3=Color3.fromRGB(8,18,28); panel.BorderSizePixel=0; panel.ZIndex=101; mkCorner(panel,12)
                local title=Instance.new("TextLabel",panel); title.Size=UDim2.new(1,-58,0,44); title.Position=UDim2.new(0,14,0,0)
                title.BackgroundTransparency=1; title.Text="CUSTOM TOOLS SELECTOR"; title.TextColor3=Color3.fromRGB(125,235,255)
                title.Font=Enum.Font.GothamBold; title.TextSize=15; title.TextXAlignment=Enum.TextXAlignment.Left; title.ZIndex=102
                local close=Instance.new("TextButton",panel); close.Size=UDim2.fromOffset(34,30); close.Position=UDim2.new(1,-42,0,7)
                close.Text="X"; close.BackgroundColor3=Color3.fromRGB(20,55,95); close.TextColor3=Color3.fromRGB(255,255,255)
                close.BorderSizePixel=0; close.ZIndex=104; mkCorner(close,8); _G._K7SafeClick(close,closeCustomToolsPicker)
                local tabs=Instance.new("Frame",panel); tabs.Size=UDim2.new(1,-24,0,38); tabs.Position=UDim2.new(0,12,0,54)
                tabs.BackgroundColor3=Color3.fromRGB(20,55,95); tabs.BorderSizePixel=0; tabs.ZIndex=102; mkCorner(tabs,9)
                local page=Instance.new("Frame",panel); page.Size=UDim2.new(1,-24,1,-108); page.Position=UDim2.new(0,12,0,100)
                page.BackgroundTransparency=1; page.ZIndex=102
                local cards={}; local current="Bat"; local spinConn
                local function refresh()
                    for _,entry in ipairs(cards) do
                        entry.card.Visible=entry.def.cat==current
                        local isSelected=_G.AmbitiousCustomToolSkins[entry.def.cat]==entry.key
                        entry.stroke.Color=isSelected and Color3.fromRGB(255,255,255) or Color3.fromRGB(20,55,95)
                        entry.stroke.Thickness=isSelected and 2.4 or 1.2
                        entry.selectionCircle.Visible=isSelected
                    end
                end
                for i,cat in ipairs({"Bat","Medusa"}) do
                    local tab=Instance.new("TextButton",tabs); tab.Size=UDim2.new(.5,0,1,0); tab.Position=UDim2.new((i-1)*.5,0,0,0)
                    tab.BackgroundTransparency=1; tab.Text=string.upper(cat); tab.TextColor3=Color3.fromRGB(255,255,255)
                    tab.Font=Enum.Font.GothamBold; tab.TextSize=12; tab.ZIndex=104
                    _G._K7SafeClick(tab,function() current=cat; refresh() end)
                end
                local order={"DiamondSword","Katana","GoldenDesertEagle","Skull"}
                local catIndex={Bat=0,Medusa=0}
                for _,key in ipairs(order) do
                    local def=assets[key]
                    if def then
                        catIndex[def.cat]=(catIndex[def.cat] or 0)+1; local idx=catIndex[def.cat]
                        local card=Instance.new("TextButton",page); card.Name="Skin_"..key; card.Size=UDim2.new(.5,-8,0,188)
                        card.Position=UDim2.new((idx-1)*.5,(idx-1)*8,0,8); card.Text=""; card.BackgroundColor3=Color3.fromRGB(20,55,95); card.BackgroundTransparency=.08
                        card.BorderSizePixel=0; card.ZIndex=103; mkCorner(card,10)
                        local stroke=Instance.new("UIStroke",card); stroke.Transparency=.1
                        local selectionCircle=Instance.new("Frame",card); selectionCircle.Name="SelectedCircle"
                        selectionCircle.Size=UDim2.fromOffset(20,20); selectionCircle.Position=UDim2.new(1,-28,0,10)
                        selectionCircle.BackgroundTransparency=1; selectionCircle.BorderSizePixel=0; selectionCircle.ZIndex=108
                        local selectionCorner=Instance.new("UICorner",selectionCircle); selectionCorner.CornerRadius=UDim.new(1,0)
                        local selectionStroke=Instance.new("UIStroke",selectionCircle); selectionStroke.Color=Color3.fromRGB(255,255,255); selectionStroke.Thickness=2
                        local selectionDot=Instance.new("Frame",selectionCircle); selectionDot.Size=UDim2.fromOffset(10,10); selectionDot.Position=UDim2.new(.5,-5,.5,-5)
                        selectionDot.BackgroundColor3=Color3.fromRGB(255,255,255); selectionDot.BorderSizePixel=0; selectionDot.ZIndex=109
                        local dotCorner=Instance.new("UICorner",selectionDot); dotCorner.CornerRadius=UDim.new(1,0)
                        -- Preview 3D real da skin, igual ao seletor do Ambitious.
                        -- O WorldModel evita que alguns executores renderizem apenas
                        -- o nome e deixem a area da miniatura transparente.
                        local vp=Instance.new("ViewportFrame",card); vp.Name="Preview"; vp.Size=UDim2.new(1,-16,0,116); vp.Position=UDim2.new(0,8,0,8)
                        vp.BackgroundColor3=Color3.fromRGB(8,18,28); vp.BackgroundTransparency=.05; vp.BorderSizePixel=0; vp.ZIndex=104
                        vp.Ambient=Color3.fromRGB(190,190,200); vp.LightColor=Color3.fromRGB(255,255,255); vp.LightDirection=Vector3.new(-.4,-1,-.6); mkCorner(vp,8)
                        local world=Instance.new("WorldModel",vp); world.Name="SkinPreviewWorld"
                        local part=Instance.new("Part",world); part.Name="SkinPreview"; part.Anchored=true; part.CanCollide=false; part.CanQuery=false; part.CanTouch=false
                        part.Transparency=0; part.Size=Vector3.new(1,1,1); part.CFrame=CFrame.new(0,0,0)
                        local mesh=Instance.new("SpecialMesh",part); mesh.MeshType=Enum.MeshType.FileMesh; mesh.MeshId=def.mesh; mesh.TextureId=def.tex; mesh.Scale=def.scale
                        local cam=Instance.new("Camera",vp); cam.Name="SkinPreviewCamera"; cam.FieldOfView=45; vp.CurrentCamera=cam; local dist=def.view or 4
                        cam.CFrame=CFrame.new(Vector3.new(0,dist*.35,dist),Vector3.zero)
                        local name=Instance.new("TextLabel",card); name.Size=UDim2.new(1,-10,0,40); name.Position=UDim2.new(0,5,0,132)
                        name.BackgroundColor3=Color3.fromRGB(12,34,56); name.BackgroundTransparency=.12; name.Text=def.label; name.TextWrapped=true; name.TextColor3=Color3.fromRGB(255,255,255)
                        name.Font=Enum.Font.GothamBold; name.TextSize=11; name.ZIndex=105
                        cards[#cards+1]={card=card,stroke=stroke,selectionCircle=selectionCircle,part=part,key=key,def=def}
                        _G._K7SafeClick(card,function()
                            State.customToolSkins[def.cat]=key; _G.AmbitiousCustomToolSkins=_G.AmbitiousCustomToolSkins or {}
                            _G.AmbitiousCustomToolSkins[def.cat]=key
                            if _G.AmbitiousSetCustomToolSkin then pcall(_G.AmbitiousSetCustomToolSkin,def.cat,key) end
                            refresh(); requestSave()
                        end)
                    end
                end
                spinConn=RunService.RenderStepped:Connect(function(dt)
                    for _,entry in ipairs(cards) do if entry.card.Visible then entry.part.CFrame=entry.part.CFrame*CFrame.Angles(0,dt*1.2,0) end end
                end)
                customToolsPicker.AncestryChanged:Connect(function(_,parent) if not parent and spinConn then spinConn:Disconnect(); spinConn=nil end end)
                refresh()
            end
            local skinRow=Instance.new("Frame",currentPage); skinRow.Size=UDim2.new(1,-16,0,42); skinRow.BackgroundColor3=Color3.fromRGB(45,205,255)
            skinRow.BorderSizePixel=0; skinRow.LayoutOrder=LO(); mkCorner(skinRow,12)
            local skinStroke=Instance.new("UIStroke",skinRow); skinStroke.Color=Color3.fromRGB(10,85,140); skinStroke.Thickness=1.5
            local skinLabel=Instance.new("TextLabel",skinRow); skinLabel.Size=UDim2.new(1,-90,1,0); skinLabel.Position=UDim2.new(0,12,0,0)
            skinLabel.BackgroundTransparency=1; skinLabel.Text="Custom Tools Selector"; skinLabel.TextColor3=Color3.fromRGB(125,235,255)
            skinLabel.Font=Enum.Font.GothamBold; skinLabel.TextSize=13; skinLabel.TextXAlignment=Enum.TextXAlignment.Left
            local skinPick=Instance.new("TextButton",skinRow); skinPick.Size=UDim2.fromOffset(58,28); skinPick.Position=UDim2.new(1,-70,.5,-14)
            skinPick.BackgroundColor3=Color3.fromRGB(20,55,95); skinPick.TextColor3=Color3.fromRGB(125,235,255); skinPick.Text="PICK"
            skinPick.Font=Enum.Font.GothamBold; skinPick.TextSize=11; skinPick.BorderSizePixel=0; skinPick.ZIndex=8; mkCorner(skinPick,8)
            _G._K7SafeClick(skinPick,openCustomToolsPicker)

            local rainbowToolsSetter = makeToggleRow("Rainbow Tools", State.rainbowToolsEnabled == true, function(on)
                setToolModule("rainbowToolsEnabled", "AmbitiousRainbowToolsEnabled", "AmbitiousRainbowTools", on)
            end)
            toggleSetters["rainbowTools"] = rainbowToolsSetter
            local transparentToolsSetter = makeToggleRow("Transparent Tools", State.transparentToolsEnabled == true, function(on)
                setToolModule("transparentToolsEnabled", "AmbitiousTransparentToolsEnabled", "AmbitiousTransparentTools", on)
            end)
            toggleSetters["transparentTools"] = transparentToolsSetter
            local customSoundsSetter = makeToggleRow("Custom Sounds", State.customSoundsEnabled == true, function(on)
                setToolModule("customSoundsEnabled", "AmbitiousCustomSoundsEnabled", "AmbitiousCustomSounds", on)
            end)
            toggleSetters["customSounds"] = customSoundsSetter

            -- Avatar Changer original do Ambitious (visual e opções padrão).
            makeGap(4)
            makeSectionHeader("Avatar Change")
            makeGap(2)
            do
              local Utility=Instance.new("Frame",currentPage)
              Utility.Name="AmbitiousAvatarChangerHost"
              Utility.Size=UDim2.new(1,-16,0,0)
              Utility.BackgroundTransparency=1
              Utility.BorderSizePixel=0
              Utility.LayoutOrder=LO()
              Utility.AutomaticSize=Enum.AutomaticSize.Y

              -- Mesma paleta visual dos demais painéis e toggles do Mystery.Vs.
              local COLORS={
                bg=Color3.fromRGB(8,25,45), row=Color3.fromRGB(45,205,255), row2=Color3.fromRGB(14,32,60),
                stroke=Color3.fromRGB(125,235,255), strokeSoft=Color3.fromRGB(10,85,140),
                white=Color3.fromRGB(255,255,255), textDim=Color3.fromRGB(125,235,255),
                toggleOn=Color3.fromRGB(45,205,255), toggleOff=Color3.fromRGB(110,110,110),
                knobOn=Color3.fromRGB(0,0,0), knobOff=Color3.fromRGB(255,255,255),
                panel=Color3.fromRGB(14,32,60), panelSoft=Color3.fromRGB(16,40,72),
              }
              local function corner(parent,radius)
                local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,radius or 8); c.Parent=parent; return c
              end
              local function stroke(parent,color,thickness,transparency)
                local s=Instance.new("UIStroke"); s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
                s.Color=color or COLORS.stroke; s.Thickness=thickness or 1; s.Transparency=transparency or .35; s.Parent=parent
                local g=Instance.new("UIGradient",s)
                g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(155,160,185)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,255,255))})
                g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(.5,.1),NumberSequenceKeypoint.new(1,.55)})
                return s
              end
              local function tween(obj,props,time)
                TweenService:Create(obj,TweenInfo.new(time or .14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props):Play()
              end
              local function baseRow(parent,labelText,order)
                local row=Instance.new("Frame"); row.Name=labelText; row.BackgroundColor3=COLORS.row; row.BackgroundTransparency=.3
                row.Size=UDim2.new(1,-4,0,34); row.BorderSizePixel=0; row.LayoutOrder=order; row.ZIndex=4; row.Parent=parent
                corner(row,9); stroke(row,COLORS.strokeSoft,1.15,.38)
                local label=Instance.new("TextLabel"); label.Name="Label"; label.BackgroundTransparency=1; label.Text=labelText
                label.TextColor3=Color3.fromRGB(245,245,255); label.TextStrokeColor3=Color3.fromRGB(0,0,0); label.TextStrokeTransparency=.25
                label.TextSize=12; label.Font=Enum.Font.GothamSemibold; label.TextXAlignment=Enum.TextXAlignment.Left
                label.Position=UDim2.new(0,12,0,0); label.Size=UDim2.new(1,-132,1,0); label.ZIndex=5; label.Parent=row
                row.MouseEnter:Connect(function() tween(row,{BackgroundTransparency=.22}) end)
                row.MouseLeave:Connect(function() tween(row,{BackgroundTransparency=.3}) end)
                return row
              end
              _G._AmbitiousWaitCharReady=_G._AmbitiousWaitCharReady or function(character,timeout)
                character=character or LP.Character; if not character then return false end
                local deadline=os.clock()+(tonumber(timeout) or 5)
                while os.clock()<deadline do
                  if not character.Parent or (LP.Character and LP.Character~=character) then return false end
                  if character:FindFirstChild("Head") and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChildOfClass("Humanoid") then return true end
                  task.wait(.05)
                end
                return false
              end
              _G._AmbitiousRegAccent=function() end
              _G._AmbitiousToggleOnColor=function() return COLORS.toggleOn,COLORS.white end
              _G._AmbitiousClampCanvas=function(page)
                if not page or not page.Parent or not page:IsA("ScrollingFrame") then return end
                task.defer(function()
                  if not page or not page.Parent then return end
                  local maxY=math.max(0,page.AbsoluteCanvasSize.Y-page.AbsoluteWindowSize.Y)
                  local cp=page.CanvasPosition
                  if cp.Y>maxY then page.CanvasPosition=Vector2.new(cp.X,maxY) end
                end)
              end
              _G._AmbitiousExpandAuto=function(holder,open,layout,arrow)
                if not holder or not holder.Parent then return end
                holder.ClipsDescendants=true
                local info=TweenInfo.new(.26,Enum.EasingStyle.Quart,open and Enum.EasingDirection.Out or Enum.EasingDirection.In)
                holder:SetAttribute("_expandToken",(holder:GetAttribute("_expandToken") or 0)+1)
                local token=holder:GetAttribute("_expandToken")
                local function contentHeight()
                  local total,n=0,0
                  for _,ch in ipairs(holder:GetChildren()) do if ch:IsA("GuiObject") and ch.Visible then total=total+ch.Size.Y.Offset; n=n+1 end end
                  if layout and layout:IsA("UIListLayout") and n>1 then total=total+layout.Padding.Offset*(n-1) end
                  local pad=holder:FindFirstChildOfClass("UIPadding")
                  if pad then total=total+pad.PaddingTop.Offset+pad.PaddingBottom.Offset end
                  return total
                end
                local sx,ox=holder.Size.X.Scale,holder.Size.X.Offset
                arrow.Text=open and "▼" or "▲"
                if open then
                  holder.AutomaticSize=Enum.AutomaticSize.None; holder.Visible=true; holder.Size=UDim2.new(sx,ox,0,0)
                  local tw=TweenService:Create(holder,info,{Size=UDim2.new(sx,ox,0,contentHeight())})
                  tw.Completed:Connect(function() if holder.Parent and holder:GetAttribute("_expandToken")==token then holder.Size=UDim2.new(sx,ox,0,0); holder.AutomaticSize=Enum.AutomaticSize.Y; holder.ClipsDescendants=false end end)
                  tw:Play()
                else
                  holder.AutomaticSize=Enum.AutomaticSize.None; holder.Size=UDim2.new(sx,ox,0,contentHeight())
                  local tw=TweenService:Create(holder,info,{Size=UDim2.new(sx,ox,0,0)})
                  tw.Completed:Connect(function() if holder.Parent and holder:GetAttribute("_expandToken")==token then holder.Visible=false end end)
                  tw:Play()
                end
              end
  do
    -- ---- Stato persistente ----
    State.avatarChanger = State.avatarChanger or {}
    _G._AmbitiousAvatarChanger = State.avatarChanger
    for _, _name in ipairs({"Hair","Hats","Face","Neck","Shoulder","Front","Back","Waist","Shirts","Pants","T-Shirts","Jackets","Sweaters","Bottoms"}) do
      local _old = _G._AmbitiousAvatarChanger[_name]
      _G._AmbitiousAvatarChanger[_name] = {
        enabled = _old and _old.enabled == true or false,
        savedId = _old and tonumber(_old.savedId) or nil,
        savedName = _old and tostring(_old.savedName or "") or "",
      }
    end
    -- Applica i dati caricati dal config se presenti
    if type(_G._AmbitiousAvatarChangerPending) == "table" then
      for k,v in pairs(_G._AmbitiousAvatarChangerPending) do
        if _G._AmbitiousAvatarChanger[k] then
          _G._AmbitiousAvatarChanger[k].enabled   = v.enabled == true
          _G._AmbitiousAvatarChanger[k].savedId   = tonumber(v.savedId)
          _G._AmbitiousAvatarChanger[k].savedName = tostring(v.savedName or "")
        end
      end
      _G._AmbitiousAvatarChangerPending = nil
    end

    local AC_CATEGORIES = {
      { Name="Hair",     AssetTypes={Enum.AvatarAssetType.HairAccessory} },
      { Name="Hats",     AssetTypes={Enum.AvatarAssetType.Hat} },
      { Name="Face",     AssetTypes={Enum.AvatarAssetType.FaceAccessory} },
      { Name="Neck",     AssetTypes={Enum.AvatarAssetType.NeckAccessory} },
      { Name="Shoulder", AssetTypes={Enum.AvatarAssetType.ShoulderAccessory} },
      { Name="Front",    AssetTypes={Enum.AvatarAssetType.FrontAccessory} },
      { Name="Back",     AssetTypes={Enum.AvatarAssetType.BackAccessory} },
      { Name="Waist",    AssetTypes={Enum.AvatarAssetType.WaistAccessory} },
      { Name="Shirts",   AssetTypes={Enum.AvatarAssetType.Shirt} },
      { Name="Pants",    AssetTypes={Enum.AvatarAssetType.Pants} },
      { Name="T-Shirts", AssetTypes={Enum.AvatarAssetType.TShirt} },
      { Name="Jackets",  AssetTypes={Enum.AvatarAssetType.JacketAccessory} },
      { Name="Sweaters", AssetTypes={Enum.AvatarAssetType.SweaterAccessory} },
      { Name="Bottoms",  AssetTypes={Enum.AvatarAssetType.ShortsAccessory} },
    }

    -- ---- Equip ----
    -- Generazione: cresce ad ogni respawn. Serve ad abortire gli equip
    -- rimasti in sospeso su un character ormai vecchio.
    local _acGen = 0
    -- Cache dei template scaricati: il watcher puo' riapplicare un item
    -- molte volte, senza cache ogni volta sarebbe una richiesta di rete.
    local _acAssetCache = {}

    -- Usa l'helper condiviso definito in cima allo script
    local _acWaitCharReady = _G._AmbitiousWaitCharReady

    -- Ritorna true solo se l'item e' stato davvero applicato.
    local function _acEquipItem(itemId, itemType, itemName, gen)
      if not itemId then return false end
      if gen == nil then gen = _acGen end
      local ok, applied = pcall(function()
        local objects
        local cached = _acAssetCache[itemId]
        if cached then
          objects = { cached:Clone() }
        else
          objects = game:GetObjects("rbxassetid://"..tostring(itemId))
          if objects and objects[1] then
            _acAssetCache[itemId] = objects[1]:Clone()
          end
        end
        -- GetObjects fa una richiesta di rete: nel frattempo il character
        -- puo' essere cambiato, quindi si rilegge adesso e non prima.
        if gen ~= _acGen then return false end
        local character = LP.Character
        if not character or not character.Parent then return false end
        if not _acWaitCharReady(character, 5) then return false end
        if gen ~= _acGen then return false end
        if not objects or #objects==0 then return false end
          local item = objects[1]
          if item:IsA("Folder") or item:IsA("Model") then
            local core = item:FindFirstChildOfClass("Accessory")
              or item:FindFirstChildOfClass("Shirt")
              or item:FindFirstChildOfClass("Pants")
              or item:FindFirstChildOfClass("ShirtGraphic")
            if core then item=core end
          end
          if item:IsA("Shirt") then
            for _,c in pairs(character:GetChildren()) do if c:IsA("Shirt") then c:Destroy() end end
            item.Name="ACShirt"; item.Parent=character; return true
          elseif item:IsA("Pants") then
            for _,c in pairs(character:GetChildren()) do if c:IsA("Pants") then c:Destroy() end end
            item.Name="ACPants"; item.Parent=character; return true
          elseif item:IsA("ShirtGraphic") then
            for _,c in pairs(character:GetChildren()) do if c:IsA("ShirtGraphic") then c:Destroy() end end
            item.Name="ACTShirt"; item.Parent=character; return true
          end
          if item:IsA("Accessory") then
            local handle=item:FindFirstChild("Handle")
            if handle then
              if itemType==Enum.AvatarAssetType.HairAccessory then
                for _,c in pairs(character:GetChildren()) do
                  if c:IsA("Accessory") and (c.Name:lower():find("hair") or (c:FindFirstChild("Handle") and c.Handle:FindFirstChild("HairAttachment"))) then c:Destroy() end
                end
              else
                for _,c in pairs(character:GetChildren()) do
                  if c:IsA("Accessory") and (c.Name==itemName or c.Name=="AC"..itemName) then c:Destroy() end
                end
              end
              local attachment=handle:FindFirstChildOfClass("Attachment")
              local targetPart=character:FindFirstChild("Head")
              local targetAttachment=nil
              if attachment then
                for _,bodyPart in pairs(character:GetChildren()) do
                  if bodyPart:IsA("BasePart") then
                    targetAttachment=bodyPart:FindFirstChild(attachment.Name)
                    if targetAttachment then targetPart=bodyPart; break end
                  end
                end
              end
              -- Senza un punto di aggancio valido il weld esplode: meglio
              -- fallire pulito e lasciare che il retry ci riprovi.
              if not targetPart then
                targetPart = character:FindFirstChild("HumanoidRootPart")
              end
              if not targetPart then return false end
              item.Name="AC"..itemName; item.Parent=character
              handle.CFrame=targetPart.CFrame
              for _,j in pairs(handle:GetChildren()) do
                if j:IsA("Weld") or j:IsA("ManualWeld") or j:IsA("WeldConstraint") then j:Destroy() end
              end
              local w=Instance.new("Weld")
              w.Name="ACManualWeld"; w.Part0=handle; w.Part1=targetPart
              if attachment and targetAttachment then w.C0=attachment.CFrame; w.C1=targetAttachment.CFrame
              else w.C0=CFrame.new(0,0.5,0) end
              w.Parent=handle
              return true
            end
          end
          return false
      end)
      return ok and applied == true
    end

    -- ---- Rimuovi item dal character ----
    local function _acRemoveItem(itemType, itemName)
      local character = LP.Character
      if not character then return end
      pcall(function()
        if itemType == Enum.AvatarAssetType.Shirt then
          for _,c in pairs(character:GetChildren()) do
            if c:IsA("Shirt") and (c.Name=="ACShirt" or c.Name==itemName) then c:Destroy() end
          end
        elseif itemType == Enum.AvatarAssetType.Pants then
          for _,c in pairs(character:GetChildren()) do
            if c:IsA("Pants") and (c.Name=="ACPants" or c.Name==itemName) then c:Destroy() end
          end
        elseif itemType == Enum.AvatarAssetType.TShirt then
          for _,c in pairs(character:GetChildren()) do
            if c:IsA("ShirtGraphic") and (c.Name=="ACTShirt" or c.Name==itemName) then c:Destroy() end
          end
        else
          -- Accessory: rimuovi per nome salvato
          for _,c in pairs(character:GetChildren()) do
            if c:IsA("Accessory") and (c.Name=="AC"..itemName or c.Name==itemName) then c:Destroy() end
          end
        end
      end)
    end

    -- ---- Save/Load separato ----
    local function _acSaveConfig()
      pcall(requestSave)
    end

    -- (load avviene in loadAmbitiousConfig, già eseguita prima di questo blocco)

    -- Applica tutti gli item con toggle ON
    local function _acApplyAll(gen)
      if gen == nil then gen = _acGen end
      -- Si aspetta che il character sia completo PRIMA di iniziare:
      -- l'attesa a tempo fisso era la causa degli item saltati al reset.
      local character = LP.Character
      if not character then return end
      if not _acWaitCharReady(character, 10) then return end
      if gen ~= _acGen then return end

      for _,cat in ipairs(AC_CATEGORIES) do
        if gen ~= _acGen then return end   -- respawn nel frattempo: si abortisce
        local entry=_G._AmbitiousAvatarChanger[cat.Name]
        if entry and entry.enabled and entry.savedId then
          -- Fino a 3 tentativi: se l'asset tarda o il weld non trova
          -- l'attachment, si riprova invece di perdere l'item.
          for attempt = 1, 3 do
            if gen ~= _acGen then return end
            if _acEquipItem(entry.savedId, cat.AssetTypes[1], entry.savedName, gen) then
              break
            end
            task.wait(0.25 * attempt)
          end
          task.wait(0.05)
        end
      end
    end

    -- Applica subito al personaggio esistente se c'e' un char e toggle ON
    task.spawn(function()
      if not LP.Character then return end
      _acApplyAll(_acGen)
    end)

    -- Applica al respawn
    LP.CharacterAdded:Connect(function()
      _acGen = _acGen + 1          -- invalida gli equip del character precedente
      local gen = _acGen
      task.spawn(function()
        _acApplyAll(gen)
      end)
    end)

    -- ------------------------------------------------------------
    -- WATCHER RE-EQUIP
    -- Gli item dell'Avatar Changer sono locali: quando un altro giocatore
    -- ti colpisce (o il gioco risincronizza il character) il server li
    -- cancella e restavi senza capelli. Qui vengono rimessi subito,
    -- sia per evento (ChildRemoved / HealthChanged) sia con un poll di
    -- sicurezza ogni secondo.
    -- ------------------------------------------------------------
    ;(function()
      local lastTry   = {}
      local fails     = {}
      local charConns = {}
      local pendingCheck = false

      -- Gli eventi (HealthChanged soprattutto) possono arrivare a raffica:
      -- qui vengono compattati in un solo controllo.
      local runCheck
      local function requestCheck(delaySec)
        if pendingCheck then return end
        pendingCheck = true
        task.delay(delaySec or 0.1, function()
          pendingCheck = false
          pcall(runCheck)
        end)
      end

      local function expectedFor(cat, entry)
        local at = cat.AssetTypes[1]
        if at == Enum.AvatarAssetType.Shirt then
          return "ACShirt", "Shirt"
        elseif at == Enum.AvatarAssetType.Pants then
          return "ACPants", "Pants"
        elseif at == Enum.AvatarAssetType.TShirt then
          return "ACTShirt", "ShirtGraphic"
        end
        return "AC"..tostring(entry.savedName or ""), "Accessory"
      end

      local function isPresent(character, cat, entry)
        local nm, cls = expectedFor(cat, entry)
        for _, c in ipairs(character:GetChildren()) do
          if c:IsA(cls) and (c.Name == nm or c.Name == entry.savedName) then
            return true
          end
        end
        return false
      end

      function runCheck()
        local character = LP.Character
        if not character or not character.Parent then return end
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then return end
        local now = tick()
        for _, cat in ipairs(AC_CATEGORIES) do
          local entry = _G._AmbitiousAvatarChanger[cat.Name]
          if entry and entry.enabled and entry.savedId then
            if isPresent(character, cat, entry) then
              fails[cat.Name] = nil
            else
              -- Backoff: se un asset non si applica (id rotto, attachment
              -- assente) non si riprova all'infinito ogni 0.6s.
              local n = fails[cat.Name] or 0
              local wait = math.min(0.6 * (2 ^ math.min(n, 5)), 20)
              if (now - (lastTry[cat.Name] or 0)) > wait then
                lastTry[cat.Name] = now
                local gen = _acGen
                local _cn = cat.Name
                local _id, _at, _nm = entry.savedId, cat.AssetTypes[1], entry.savedName
                task.spawn(function()
                  if gen ~= _acGen then return end
                  if _acEquipItem(_id, _at, _nm, gen) then
                    fails[_cn] = nil
                  else
                    fails[_cn] = (fails[_cn] or 0) + 1
                  end
                end)
              end
            end
          end
        end
      end
      _G._AmbitiousAvatarChangerRecheck = function() fails = {}; pcall(runCheck) end

      local function hookCharacter(character)
        for _, c in ipairs(charConns) do pcall(function() c:Disconnect() end) end
        charConns = {}
        if not character then return end
        table.insert(charConns, character.ChildRemoved:Connect(function(child)
          if child:IsA("Accessory") or child:IsA("Shirt")
          or child:IsA("Pants") or child:IsA("ShirtGraphic") then
            requestCheck(0.05)
          end
        end))
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then
          -- Il caso segnalato: colpito da un altro player -> accessori persi
          table.insert(charConns, hum.HealthChanged:Connect(function()
            requestCheck(0.15)
          end))
        end
      end

      hookCharacter(LP.Character)
      LP.CharacterAdded:Connect(function(c)
        task.delay(0.6, function() hookCharacter(c) end)
      end)

      task.spawn(function()
        while true do
          task.wait(1)
          pcall(runCheck)
        end
      end)
    end)()

    -- ---- Visual callbacks sub-toggle ----
    local _acSubSetVisuals = {}

    -- ---- Unico popup condiviso ----
    local _acPickerGui = nil
    -- Categoria del popup attualmente aperto: serve per il toggle sul riclick
    local _acPickerCat = nil
    -- Il backdrop e' un Frame e non assorbe il click, quindi cliccando un PICK
    -- mentre il popup e' aperto arrivano DUE eventi in quest'ordine:
    --   1) backdrop.InputBegan -> chiude il popup
    --   2) pickBtn.Activated   -> lo trovava gia' chiuso e lo riapriva
    -- Ricordiamo cosa e' stato appena chiuso per ignorare il secondo evento.
    local _acPickerJustClosedCat = nil
    local _acPickerJustClosedAt = 0

    local function _acClosePicker()
      if _acPickerGui and _acPickerGui.Parent then
        _acPickerGui:Destroy()
        _acPickerJustClosedCat = _acPickerCat
        _acPickerJustClosedAt = tick()
      end
      _acPickerGui = nil
      _acPickerCat = nil
    end

    local function _acOpenPicker(catName, assetTypes)
      -- Riclick sullo stesso PICK: chiude, come fanno gli altri picker.
      -- Click su un PICK diverso: passa a quella categoria.
      if _acPickerGui and _acPickerGui.Parent and _acPickerCat == catName then
        _acClosePicker()
        return
      end
      -- Il backdrop ha appena chiuso questo stesso popup: non riaprirlo.
      if _acPickerJustClosedCat == catName and (tick() - _acPickerJustClosedAt) < 0.25 then
        _acPickerJustClosedCat = nil
        return
      end
      _acClosePicker()
      _acPickerJustClosedCat = nil
      _acPickerCat = catName

      _acPickerGui=Instance.new("ScreenGui")
      _acPickerGui.Name="AmbitiousHubAVChanger"
      _acPickerGui.ResetOnSpawn=false
      _acPickerGui.IgnoreGuiInset=true
      _acPickerGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
      _acPickerGui.DisplayOrder=9998
      _acPickerGui.Parent=gui

      -- Frame (non TextButton) come tutti gli altri picker: un TextButton
      -- catturerebbe l'input e i bottoni sotto smetterebbero di ricevere
      -- MouseLeave, restando bloccati nello stato hover.
      local backdrop=Instance.new("Frame")
      backdrop.Name="Backdrop"
      backdrop.Size=UDim2.new(1,0,1,0)
      backdrop.BackgroundColor3=Color3.fromRGB(0,0,0)
      backdrop.BackgroundTransparency=0.45
      backdrop.BorderSizePixel=0
      backdrop.ZIndex=1
      backdrop.Parent=_acPickerGui

      local pickerFrame=Instance.new("Frame")
      pickerFrame.Name="Frame"
      pickerFrame.Size=UDim2.new(0,370,0,510)
      pickerFrame.Position=UDim2.new(0.5,-185,0.5,-255)
      pickerFrame.BackgroundColor3=COLORS.panel
      pickerFrame.BorderSizePixel=0
      pickerFrame.ZIndex=2
      pickerFrame.Parent=_acPickerGui
      corner(pickerFrame,16)
      stroke(pickerFrame,COLORS.stroke,1.2,0.3)

      -- Title bar
      local titleBar=Instance.new("Frame")
      titleBar.Size=UDim2.new(1,0,0,48)
      titleBar.BackgroundColor3=COLORS.panelSoft
      titleBar.BackgroundTransparency=0.15
      titleBar.BorderSizePixel=0
      titleBar.ZIndex=3
      titleBar.Parent=pickerFrame
      corner(titleBar,16)

      local titleLabel=Instance.new("TextLabel")
      titleLabel.Size=UDim2.new(1,-60,1,0)
      titleLabel.Position=UDim2.new(0,18,0,0)
      titleLabel.BackgroundTransparency=1
      titleLabel.Text=catName.." Changer"
      titleLabel.TextColor3=Color3.fromRGB(255,255,255)
      titleLabel.Font=Enum.Font.GothamBlack
      titleLabel.TextSize=15
      titleLabel.TextXAlignment=Enum.TextXAlignment.Left
      titleLabel.ZIndex=4
      titleLabel.Parent=titleBar

      local closeBtn=Instance.new("TextButton")
      closeBtn.Size=UDim2.new(0,36,0,36)
      closeBtn.Position=UDim2.new(1,-44,0,6)
      closeBtn.BackgroundColor3=COLORS.toggleOff
      closeBtn.BackgroundTransparency=0.1
      closeBtn.BorderSizePixel=0
      closeBtn.Text="X"
      closeBtn.TextColor3=Color3.fromRGB(255,255,255)
      closeBtn.Font=Enum.Font.GothamBlack
      closeBtn.TextSize=14
      closeBtn.AutoButtonColor=false
      closeBtn.ZIndex=4
      closeBtn.Parent=titleBar
      corner(closeBtn,10)
      stroke(closeBtn,Color3.fromRGB(90,90,105),1,0.4)
      closeBtn.MouseEnter:Connect(function() tween(closeBtn,{BackgroundColor3=Color3.fromRGB(180,50,50)},0.12) end)
      closeBtn.MouseLeave:Connect(function() tween(closeBtn,{BackgroundColor3=COLORS.toggleOff},0.12) end)
      closeBtn.Activated:Connect(_acClosePicker)

      -- Search bar
      local searchBar=Instance.new("TextBox")
      searchBar.Size=UDim2.new(1,-24,0,30)
      searchBar.Position=UDim2.new(0,12,0,55)
      searchBar.BackgroundColor3=COLORS.panelSoft
      searchBar.BackgroundTransparency=0.1
      searchBar.BorderSizePixel=0
      searchBar.PlaceholderText="Search..."
      searchBar.PlaceholderColor3=Color3.fromRGB(110,110,120)
      searchBar.Text=""
      searchBar.TextColor3=Color3.fromRGB(245,245,255)
      searchBar.Font=Enum.Font.GothamSemibold
      searchBar.TextSize=12
      searchBar.ClearTextOnFocus=false
      searchBar.ZIndex=4
      searchBar.Parent=pickerFrame
      corner(searchBar,8)
      stroke(searchBar,Color3.fromRGB(70,70,85),1,0.4)

      -- Status label
      local statusLabel=Instance.new("TextLabel")
      statusLabel.Size=UDim2.new(1,-24,0,22)
      statusLabel.Position=UDim2.new(0,12,0,92)
      statusLabel.BackgroundTransparency=1
      statusLabel.Text="Loading..."
      statusLabel.TextColor3=Color3.fromRGB(150,150,160)
      statusLabel.Font=Enum.Font.GothamSemibold
      statusLabel.TextSize=11
      statusLabel.ZIndex=4
      statusLabel.Parent=pickerFrame

      -- Scroll con thumbnails a griglia
      local scrollFrame=Instance.new("ScrollingFrame")
      scrollFrame.Size=UDim2.new(1,-12,1,-100)
      scrollFrame.Position=UDim2.new(0,6,0,96)
      scrollFrame.BackgroundTransparency=1
      scrollFrame.BorderSizePixel=0
      scrollFrame.ScrollBarThickness=4
      scrollFrame.ScrollBarImageColor3=Color3.fromRGB(80,80,90)
      scrollFrame.CanvasSize=UDim2.new(0,0,0,0)
      scrollFrame.AutomaticCanvasSize=Enum.AutomaticSize.Y
      scrollFrame.ZIndex=3
      scrollFrame.Parent=pickerFrame

      local gridLayout=Instance.new("UIGridLayout")
      gridLayout.CellSize=UDim2.new(0,100,0,120)
      gridLayout.CellPadding=UDim2.new(0,8,0,8)
      gridLayout.FillDirection=Enum.FillDirection.Horizontal
      gridLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
      gridLayout.SortOrder=Enum.SortOrder.LayoutOrder
      gridLayout.Parent=scrollFrame

      local gridPad=Instance.new("UIPadding")
      gridPad.PaddingTop=UDim.new(0,8)
      gridPad.PaddingBottom=UDim.new(0,8)
      gridPad.PaddingLeft=UDim.new(0,6)
      gridPad.PaddingRight=UDim.new(0,6)
      gridPad.Parent=scrollFrame

      local itemOrder=0
      local currentCatalogPage=nil
      local loadingMore=false

      local function makeItemCard(item)
        itemOrder=itemOrder+1
        local card=Instance.new("TextButton")
        card.Name="AC_Item_"..tostring(item.Id)
        card.BackgroundColor3=Color3.fromRGB(16,16,20)
        card.BackgroundTransparency=0.05
        card.BorderSizePixel=0
        card.Text=""
        card.AutoButtonColor=false
        card.LayoutOrder=itemOrder
        card.ZIndex=4
        card.Parent=scrollFrame
        corner(card,10)
        local cardStroke=Instance.new("UIStroke")
        cardStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
        cardStroke.Color=Color3.fromRGB(50,50,62)
        cardStroke.Thickness=1
        cardStroke.Transparency=0.5
        cardStroke.Parent=card

        -- Thumbnail immagine
        local thumb=Instance.new("ImageLabel")
        thumb.Size=UDim2.new(1,-8,0,72)
        thumb.Position=UDim2.new(0,4,0,4)
        thumb.BackgroundColor3=Color3.fromRGB(22,22,28)
        thumb.BorderSizePixel=0
        thumb.ZIndex=5
        thumb.Image="rbxthumb://type=Asset&id="..tostring(item.Id).."&w=150&h=150"
        thumb.ScaleType=Enum.ScaleType.Fit
        thumb.Parent=card
        corner(thumb,7)

        -- Nome item (sotto thumbnail, troncato)
        local nameLabel=Instance.new("TextLabel")
        nameLabel.Size=UDim2.new(1,-6,0,30)
        nameLabel.Position=UDim2.new(0,3,0,78)
        nameLabel.BackgroundTransparency=1
        nameLabel.Text=item.Name or "?"
        nameLabel.TextColor3=Color3.fromRGB(225,225,235)
        nameLabel.Font=Enum.Font.GothamSemibold
        nameLabel.TextSize=9
        nameLabel.TextWrapped=true
        nameLabel.TextXAlignment=Enum.TextXAlignment.Center
        nameLabel.TextYAlignment=Enum.TextYAlignment.Top
        nameLabel.ZIndex=5
        nameLabel.Parent=card

        card.MouseEnter:Connect(function()
          tween(card,{BackgroundColor3=Color3.fromRGB(30,30,38)},0.1)
          tween(cardStroke,{Color=Color3.fromRGB(200,200,210),Transparency=0.15},0.1)
        end)
        card.MouseLeave:Connect(function()
          -- ripristina colore normale (verde=selezionato gia' equipaggiato)
          local entry=_G._AmbitiousAvatarChanger[catName]
          local isSaved = entry and entry.savedId == item.Id
          tween(card,{BackgroundColor3=isSaved and Color3.fromRGB(20,36,20) or Color3.fromRGB(16,16,20)},0.1)
          tween(cardStroke,{Color=isSaved and Color3.fromRGB(120,220,120) or Color3.fromRGB(50,50,62),Transparency=isSaved and 0.15 or 0.5},0.1)
        end)

        -- Evidenzia se gia' salvato
        local entry=_G._AmbitiousAvatarChanger[catName]
        if entry and entry.savedId == item.Id then
          card.BackgroundColor3=Color3.fromRGB(20,36,20)
          cardStroke.Color=Color3.fromRGB(120,220,120)
          cardStroke.Transparency=0.15
        end

        card.Activated:Connect(function()
          local ent=_G._AmbitiousAvatarChanger[catName]
          if not ent then return end
          -- Se toggle ON e c'era un vecchio item, rimuovilo prima
          if ent.enabled and ent.savedId and ent.savedName ~= "" then
            _acRemoveItem(assetTypes[1], ent.savedName)
          end
          ent.savedId=item.Id
          ent.savedName=item.Name or ""
          if ent.enabled then
            local _id, _at, _nm = item.Id, assetTypes[1], item.Name or ""
            task.spawn(function() _acEquipItem(_id,_at,_nm) end)
          end
          _acSaveConfig()
          -- Aggiorna highlight su tutte le card
          for _,ch in ipairs(scrollFrame:GetChildren()) do
            if ch:IsA("TextButton") then
              local st2=ch:FindFirstChildOfClass("UIStroke")
              local isThis=(ch.Name=="AC_Item_"..tostring(item.Id))
              tween(ch,{BackgroundColor3=isThis and Color3.fromRGB(20,36,20) or Color3.fromRGB(16,16,20)},0.14)
              if st2 then tween(st2,{Color=isThis and Color3.fromRGB(120,220,120) or Color3.fromRGB(50,50,62),Transparency=isThis and 0.15 or 0.5},0.14) end
            end
          end
        end)
      end

      local function loadItems(keyword)
        for _,c in ipairs(scrollFrame:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        itemOrder=0
        currentCatalogPage=nil
        loadingMore=false
        statusLabel.Text="Loading..."
        statusLabel.Visible=true
        task.spawn(function()
          local ok,pages2=pcall(function()
            local params=CatalogSearchParams.new()
            params.AssetTypes=assetTypes
            if keyword and keyword~="" then params.SearchKeyword=keyword end
            return game:GetService("AvatarEditorService"):SearchCatalog(params)
          end)
          if not ok or not pages2 then statusLabel.Text="Error loading."; return end
          currentCatalogPage=pages2
          local firstPage=pages2:GetCurrentPage()
          statusLabel.Visible=#firstPage==0
          statusLabel.Text=#firstPage==0 and "No results." or ""
          for _,item in ipairs(firstPage) do makeItemCard(item) end
        end)
      end

      scrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if loadingMore or not currentCatalogPage then return end
        local posY=scrollFrame.CanvasPosition.Y
        local canvasH=scrollFrame.CanvasSize.Y.Offset
        local viewH=scrollFrame.AbsoluteSize.Y
        if canvasH>0 and posY+viewH>=canvasH-100 and not currentCatalogPage.IsFinished then
          loadingMore=true
          task.spawn(function()
            local ok2=pcall(function() currentCatalogPage:AdvanceToNextPageAsync() end)
            if ok2 then
              for _,item in ipairs(currentCatalogPage:GetCurrentPage()) do makeItemCard(item) end
            end
            loadingMore=false
          end)
        end
      end)

      local searchDebounce=nil
      searchBar:GetPropertyChangedSignal("Text"):Connect(function()
        if searchDebounce then task.cancel(searchDebounce) end
        searchDebounce=task.delay(0.5,function() loadItems(searchBar.Text) end)
      end)

      backdrop.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
          _acClosePicker()
        end
      end)

      pickerFrame.Size=UDim2.new(0,0,0,0)
      pickerFrame.Position=UDim2.new(0.5,0,0.5,0)
      TweenService:Create(pickerFrame,TweenInfo.new(0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{
        Size=UDim2.new(0,370,0,510),
        Position=UDim2.new(0.5,-185,0.5,-255)
      }):Play()

      loadItems("")
    end

    -- ---- Riga principale "Avatar Changer" con freccia stile Infinite Jump ----
    local acMainRow=baseRow(Utility,"Avatar Changer",1)
    acMainRow.LayoutOrder=1

    local acArrowBtn=Instance.new("TextButton")
    acArrowBtn.Name="AvatarChangerArrow"
    acArrowBtn.BackgroundColor3=COLORS.panel
    acArrowBtn.BackgroundTransparency=0.18
    acArrowBtn.BorderSizePixel=0
    acArrowBtn.Size=UDim2.new(0,28,0,24)
    acArrowBtn.Position=UDim2.new(1,-38,0.5,-12)
    acArrowBtn.Text="▲"
    acArrowBtn.TextColor3=COLORS.white
    acArrowBtn.TextStrokeColor3=Color3.fromRGB(0,0,0)
    acArrowBtn.TextStrokeTransparency=0.3
    acArrowBtn.TextSize=15
    acArrowBtn.Font=Enum.Font.GothamBold
    acArrowBtn.AutoButtonColor=false
    acArrowBtn.ZIndex=8
    acArrowBtn.Parent=acMainRow
    corner(acArrowBtn,7)
    stroke(acArrowBtn,COLORS.strokeSoft,1,0.45)

    -- ---- SubHolder (auto-size, lista) ----
    local acSubHolder=Instance.new("Frame")
    acSubHolder.Name="AvatarChangerSubHolder"
    acSubHolder.BackgroundTransparency=1
    acSubHolder.BorderSizePixel=0
    acSubHolder.Size=UDim2.new(1,-4,0,0)
    acSubHolder.LayoutOrder=2
    acSubHolder.ZIndex=4
    acSubHolder.Visible=false
    acSubHolder.AutomaticSize=Enum.AutomaticSize.Y
    acSubHolder.Parent=Utility

    local acSubLayout=Instance.new("UIListLayout")
    acSubLayout.Padding=UDim.new(0,5)
    acSubLayout.SortOrder=Enum.SortOrder.LayoutOrder
    acSubLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    acSubLayout.Parent=acSubHolder

    -- 2px sopra/sotto: gli UIStroke delle righe sono disegnati FUORI dai bounds,
    -- quindi senza questo margine il clipping della tendina taglia il bordo
    -- superiore della prima riga e quello inferiore dell'ultima.
    local acSubPad=Instance.new("UIPadding")
    acSubPad.PaddingTop=UDim.new(0,2)
    acSubPad.PaddingBottom=UDim.new(0,2)
    acSubPad.Parent=acSubHolder

    -- ---- 14 sub-righe ----
    for i,cat in ipairs(AC_CATEGORIES) do
      local catName=cat.Name
      local catAssetTypes=cat.AssetTypes
      local entry=_G._AmbitiousAvatarChanger[catName]

      -- Usa baseRow identico a toggleRow, poi aggiungi manualmente toggle+PICK
      local subRow=Instance.new("Frame")
      subRow.Name="AC_Sub_"..catName
      subRow.BackgroundColor3=COLORS.row
      subRow.BackgroundTransparency=0.3
      subRow.Size=UDim2.new(1,-8,0,34)
      subRow.BorderSizePixel=0
      subRow.LayoutOrder=i
      subRow.ZIndex=4
      subRow.Parent=acSubHolder
      corner(subRow,9)
      local subRowStroke=stroke(subRow,COLORS.strokeSoft,1.15,0.38)
      subRow.MouseEnter:Connect(function() tween(subRow,{BackgroundTransparency=0.22}) end)
      subRow.MouseLeave:Connect(function() tween(subRow,{BackgroundTransparency=0.3}) end)

      -- Label
      local subLabel=Instance.new("TextLabel")
      subLabel.BackgroundTransparency=1
      subLabel.Text=catName
      subLabel.TextColor3=Color3.fromRGB(245,245,255)
      subLabel.TextStrokeColor3=Color3.fromRGB(0,0,0)
      subLabel.TextStrokeTransparency=0.25
      subLabel.TextSize=12
      subLabel.Font=Enum.Font.GothamSemibold
      subLabel.TextXAlignment=Enum.TextXAlignment.Left
      subLabel.Position=UDim2.new(0,12,0,0)
      subLabel.Size=UDim2.new(1,-132,1,0)
      subLabel.ZIndex=5
      subLabel.Parent=subRow

      -- Toggle track (identico a toggleRow)
      local track=Instance.new("Frame")
      track.Name="Track"
      track.BackgroundColor3=entry.enabled and COLORS.toggleOn or COLORS.toggleOff
      track.BackgroundTransparency=0.12
      track.Size=UDim2.new(0,44,0,22)
      track.Position=UDim2.new(1,-52,0.5,-11)
      track.BorderSizePixel=0
      track.ZIndex=5
      track.Parent=subRow
      corner(track,11)
      local trackStroke=stroke(track,COLORS.strokeSoft,1.3,0.4)

      local fill=Instance.new("Frame")
      fill.Name="Fill"
      fill.BackgroundColor3=COLORS.toggleOn
      fill.BackgroundTransparency=entry.enabled and 0 or 1
      fill.Size=UDim2.new(1,0,1,0)
      fill.BorderSizePixel=0
      fill.ZIndex=5
      fill.Parent=track
      corner(fill,11)
      local acFillGrad=Instance.new("UIGradient")
      acFillGrad.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.toggleOn),
        ColorSequenceKeypoint.new(0.5, COLORS.toggleOn),
        ColorSequenceKeypoint.new(1, COLORS.toggleOn),
      })
      acFillGrad.Rotation=18
      acFillGrad.Parent=fill

      local knob=Instance.new("Frame")
      knob.Name="Knob"
      knob.BackgroundColor3=entry.enabled and COLORS.knobOn or COLORS.knobOff
      knob.Size=UDim2.new(0,16,0,16)
      knob.Position=entry.enabled and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
      knob.BorderSizePixel=0
      knob.ZIndex=7
      knob.Parent=track
      corner(knob,999)
      local knobStroke=Instance.new("UIStroke")
      knobStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
      knobStroke.Color=COLORS.white
      knobStroke.Thickness=1.4
      knobStroke.Transparency=0.15
      knobStroke.Parent=knob

      local shine=Instance.new("Frame")
      shine.BackgroundColor3=COLORS.white
      shine.BackgroundTransparency=0
      shine.Size=UDim2.new(1,-5,0,5)
      shine.Position=UDim2.new(0,2.5,0,2.5)
      shine.BorderSizePixel=0
      shine.ZIndex=8
      shine.Parent=knob
      corner(shine,5)
      _G._AmbitiousRegAccent(fill, acFillGrad, "toggle", track, knob, subRow)

      -- setVisual identico a toggleRow
      local function subSetVisual(on)
        tween(knob,{Position=on and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)})
        local _onBg, _onEdge = _G._AmbitiousToggleOnColor()
        tween(track,{
          BackgroundTransparency=on and 0 or 0.12,
          BackgroundColor3=on and _onBg or COLORS.toggleOff
        })
        tween(fill,{BackgroundTransparency=on and 0 or 1})
        tween(knob,{BackgroundColor3=on and COLORS.knobOn or COLORS.knobOff})
        tween(knobStroke,{Color=COLORS.white,Transparency=0})
        tween(trackStroke,{
          Color=on and _onEdge or COLORS.strokeSoft,
          Transparency=on and 0 or 0.4,
          Thickness=1.4
        })
        subRow:SetAttribute("ActiveState",on==true)
        tween(subRowStroke,{
          Color=COLORS.strokeSoft,
          Transparency=on and 0.08 or 0.38,
          Thickness=1.25
        })
      end
      _acSubSetVisuals[catName]=subSetVisual
      -- Permite ao loadConfig restaurar imediatamente o visual ON/OFF salvo.
      toggleSetters["avatar_"..catName]=subSetVisual
      subRow:SetAttribute("ActiveState",entry.enabled==true)
      subSetVisual(entry.enabled)

      -- ToggleButton invisibile sopra la track (esattamente come toggleRow)
      local toggleBtn=Instance.new("TextButton")
      toggleBtn.Name="ToggleButton"
      toggleBtn.BackgroundTransparency=1
      toggleBtn.Text=""
      toggleBtn.Size=UDim2.new(1,0,1,0)
      toggleBtn.Position=UDim2.new(0,0,0,0)
      toggleBtn.AutoButtonColor=false
      toggleBtn.ZIndex=7
      toggleBtn.Parent=subRow

      do
        local _cn=catName
        local _cat=catAssetTypes
        toggleBtn.Activated:Connect(function()
          local ent=_G._AmbitiousAvatarChanger[_cn]
          if not ent then return end
          ent.enabled=not ent.enabled
          subSetVisual(ent.enabled)
          if ent.enabled and ent.savedId then
            local _id, _at, _nm = ent.savedId, _cat[1], ent.savedName
            task.spawn(function() _acEquipItem(_id,_at,_nm) end)
          else
            -- Toggle OFF: rimuovi item dal personaggio
            if ent.savedId then
              _acRemoveItem(_cat[1],ent.savedName)
            end
          end
          _acSaveConfig()
        end)
      end

      -- PICK button stile Tracker Color (holder scuro + testo bianco)
      local pickHolder=Instance.new("Frame")
      pickHolder.Name="PickHolder"
      pickHolder.BackgroundColor3=COLORS.toggleOn
      pickHolder.BackgroundTransparency=0.28
      pickHolder.BorderSizePixel=0
      pickHolder.Size=UDim2.new(0,48,0,26)
      pickHolder.Position=UDim2.new(1,-118,0.5,-13)
      pickHolder.ClipsDescendants=true
      pickHolder.ZIndex=8
      pickHolder.Parent=subRow
      corner(pickHolder,13)
      stroke(pickHolder,COLORS.white,1.5,0.15)

      local pickGradAc = Instance.new("UIGradient")
      pickGradAc.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.toggleOn),
        ColorSequenceKeypoint.new(0.5, COLORS.toggleOn),
        ColorSequenceKeypoint.new(1, COLORS.toggleOn),
      })
      pickGradAc.Rotation = 18
      pickGradAc.Parent = pickHolder
      _G._AmbitiousRegAccent(pickHolder, pickGradAc, "pick")

      local pickBtn=Instance.new("TextButton")
      pickBtn.Name="PickBtn"
      pickBtn.BackgroundTransparency=1
      pickBtn.Text="PICK"
      pickBtn.TextColor3=COLORS.white
      pickBtn.TextStrokeColor3=Color3.fromRGB(0,0,0)
      pickBtn.TextStrokeTransparency=0.3
      pickBtn.TextSize=11
      pickBtn.Font=Enum.Font.GothamBlack
      pickBtn.TextXAlignment=Enum.TextXAlignment.Center
      pickBtn.Size=UDim2.new(1,0,1,0)
      pickBtn.Position=UDim2.new(0,0,0,0)
      pickBtn.BorderSizePixel=0
      pickBtn.ZIndex=9
      pickBtn.AutoButtonColor=false
      pickBtn.Parent=pickHolder

      pickBtn.MouseEnter:Connect(function()
        tween(pickHolder, {Size = UDim2.new(0, 54, 0, 28), Position = UDim2.new(1, -121, 0.5, -14)}, 0.12)
      end)
      pickBtn.MouseLeave:Connect(function()
        tween(pickHolder, {Size = UDim2.new(0, 48, 0, 26), Position = UDim2.new(1, -118, 0.5, -13)}, 0.12)
      end)

      do
        local _cn2=catName
        local _cat2=catAssetTypes
        pickBtn.Activated:Connect(function()
          _acOpenPicker(_cn2,_cat2)
        end)
      end
    end

    -- ---- Toggle espansione freccia ----
    local acExpanded=false
    local function acSetExpanded(on)
      acExpanded=on
      -- Animazione a tendina + freccia che ruota, come Infinite Jump / Anti Ragdoll.
      -- Usa la variante Auto perche' il sub holder ha AutomaticSize.Y (14 sub-righe).
      _G._AmbitiousExpandAuto(acSubHolder, on, acSubLayout, acArrowBtn)
      _G._AmbitiousClampCanvas(Utility)
    end
    acArrowBtn.Activated:Connect(function() acSetExpanded(not acExpanded) end)

    -- ---- Hook Reset All Settings ----
    _G._AmbitiousAvatarChangerReset=function()
      for _,cat in ipairs(AC_CATEGORIES) do
        local entry=_G._AmbitiousAvatarChanger[cat.Name]
        if entry then
          -- Rimuovi subito dal personaggio se era attivo
          if entry.enabled and entry.savedId then
            _acRemoveItem(cat.AssetTypes[1], entry.savedName)
          end
          entry.enabled=false; entry.savedId=nil; entry.savedName=""
          if _acSubSetVisuals[cat.Name] then _acSubSetVisuals[cat.Name](false) end
        end
      end
      _acSaveConfig()
    end
    _G._K7AvatarChangerReset = _G._AmbitiousAvatarChangerReset
    _G._K7AvatarChangerReapply = function()
      if _G._AmbitiousAvatarChangerRecheck then pcall(_G._AmbitiousAvatarChangerRecheck) end
      task.spawn(function() _acApplyAll(_acGen) end)
    end
  end -- fine Avatar Changer
            end

            -- ── ESP ────────────────────────────────────────────────
            makeGap(4)
            makeSectionHeader("ESP")
            makeGap(2)

            local espSetter = makeToggleRow("ESP", State.espEnabled == true, function(on)
                State.espEnabled=on
                if on then
                    startPlayerESP()
                    if BoxedESPOptions then BoxedESPOptions.box = true end
                else
                    stopPlayerESP()
                    if BoxedESPOptions then BoxedESPOptions.box = false end
                end
                refreshBoxedESP()
                requestSave()
            end)
            toggleSetters["esp"]=espSetter

            local trackerSetter = makeToggleRow("Trace ESP", State.showTrackerEnabled == true, function(on)
                State.showTrackerEnabled=on; BoxedESPOptions.tracker=on; refreshBoxedESP(); requestSave()
            end)
            toggleSetters["showTracker"]=trackerSetter

            do
                local row=Instance.new("Frame",currentPage); row.Name="Tracker Color"; row.Size=UDim2.new(1,-16,0,40); row.BackgroundColor3=Color3.fromRGB(45,205,255); row.BorderSizePixel=0; row.LayoutOrder=LO(); mkCorner(row,12)
                local st=Instance.new("UIStroke",row); st.Color=Color3.fromRGB(10,85,140); st.Thickness=1.5
                local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-100,1,0); lbl.Position=UDim2.new(0,12,0,0); lbl.BackgroundTransparency=1; lbl.Text="Tracker Color"; lbl.TextColor3=Color3.fromRGB(125,235,255); lbl.Font=Enum.Font.GothamBold; lbl.TextSize=15; lbl.TextXAlignment=Enum.TextXAlignment.Left
                local preview=Instance.new("Frame",row); preview.Name="ColorPreview"; preview.Size=UDim2.fromOffset(24,24); preview.Position=UDim2.new(1,-42,0.5,-12); preview.BorderSizePixel=0; preview.BackgroundColor3=BoxedESPOptions.trackerColor; mkCorner(preview,12)
                local pick=Instance.new("TextButton",row); pick.Size=UDim2.new(1,0,1,0); pick.BackgroundTransparency=1; pick.Text=""; pick.ZIndex=8
                _G._K7SafeClick(pick,function()
                    _G._K7OpenPalette("TRACKER COLOR",function(color)
                        color=color or Color3.fromRGB(230,230,230); BoxedESPOptions.trackerColor=color; State.trackerColor={math.floor(color.R*255+0.5),math.floor(color.G*255+0.5),math.floor(color.B*255+0.5)}; preview.BackgroundColor3=color
                        for _,data in pairs(BoxedESPData) do if data.tracker then pcall(function() data.tracker.Color=color end) end end
                        requestSave()
                    end)
                end)
                _G._K7TrackerColorPreview=preview
            end

            makeGap(8)
            local fw = Instance.new("Frame", currentPage)
            fw.Size = UDim2.new(1,0,0,22)
            fw.BackgroundTransparency = 1
            fw.BorderSizePixel = 0
            fw.LayoutOrder = LO()
            local fl = Instance.new("TextLabel", fw)
            fl.Size = UDim2.new(1,0,1,0)
            fl.BackgroundTransparency = 1
            fl.Text = "Visual Settings"
            fl.TextColor3 = currentColorScheme.subText
            fl.Font = Enum.Font.Gotham
            fl.TextSize = 10
            fl.TextXAlignment = Enum.TextXAlignment.Center
        end)
        page.LayoutOrder = 3
    end

-- STEAL TAB (updated with Soft Steal)
    do
        local page = buildPage("Steal", function()
            makeGap(2)

            local autoStealToggle = makeToggleRow("Auto Steal", Steal.AutoStealEnabled, function(on)
                Steal.AutoStealEnabled = on
                if autoGrabModule then autoGrabModule.setEnabled(on) end
                requestSave()
            end)
            toggleSetters["autoSteal"] = autoStealToggle

            local setRagdollSteal = makeToggleRow("Ragdoll Steal", State.ragdollStealEnabled, function(on)
                State.ragdollStealEnabled = on
                if not on and _G._K7RagdollStealClear then pcall(_G._K7RagdollStealClear) end
                requestSave()
            end)
            toggleSetters["ragdollSteal"] = setRagdollSteal

            makeGap(2)
            do
                local row = Instance.new("Frame", currentPage)
                row:SetAttribute("AlwaysCyanOptionBar", true)
                row.Size = UDim2.new(1,-16,0,42)
                row.BackgroundColor3 = Color3.fromRGB(90,225,255)
                row.BackgroundTransparency = 0.18
                row.BorderSizePixel = 0
                row.LayoutOrder = LO()
                mkCorner(row,12)
                local st = Instance.new("UIStroke", row)
                st.Color = currentColorScheme.mainDark; st.Transparency = 0.72

                local lbl = Instance.new("TextLabel", row)
                lbl.Size = UDim2.new(1,-130,1,0); lbl.Position = UDim2.new(0,10,0,0)
                lbl.BackgroundTransparency = 1
                lbl.Text = "Stretch Auto Grab"
                lbl.TextColor3 = currentColorScheme.rowLabel
                lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 14
                lbl.TextXAlignment = Enum.TextXAlignment.Left

                local function mkArrow(txt, xOff)
                    local b = Instance.new("TextButton", row)
                    b.Size = UDim2.new(0,26,0,26); b.Position = UDim2.new(1,xOff,0.5,-13)
                    b.BackgroundColor3 = Color3.fromRGB(45,205,255)
                    b.BackgroundTransparency = 0
                    b.BorderSizePixel = 0; b.AutoButtonColor = false
                    b.Text = txt; b.TextColor3 = currentColorScheme.inputText
                    b.Font = Enum.Font.GothamBold; b.TextSize = 16
                    mkCorner(b,13)
                    return b
                end
                local leftBtn  = mkArrow("<", -118)
                local valLbl = Instance.new("TextLabel", row)
                valLbl.Size = UDim2.new(0,50,0,26); valLbl.Position = UDim2.new(1,-88,0.5,-13)
                valLbl.BackgroundColor3 = Color3.fromRGB(92,92,92)
                valLbl.BackgroundTransparency = 0
                valLbl.Text = "0"
                valLbl.TextColor3 = currentColorScheme.inputText
                valLbl.Font = Enum.Font.GothamBold; valLbl.TextSize = 15
                mkCorner(valLbl, 13)
                local valStroke = Instance.new("UIStroke", valLbl)
                valStroke.Color = Color3.fromRGB(145,145,145); valStroke.Transparency = 0.25
                local rightBtn = mkArrow(">", -34)

                local function refresh()
                    local v = (autoGrabModule and autoGrabModule.getStretch and autoGrabModule.getStretch()) or 0
                    valLbl.Text = (v > 0) and ("+"..v) or tostring(v)
                end
                _G._K7SyncAutoGrabStretch = refresh
                local function bump(d)
                    if not (autoGrabModule and autoGrabModule.setStretch) then return end
                    local v = (autoGrabModule.getStretch and autoGrabModule.getStretch()) or 0
                    autoGrabModule.setStretch(v + d)
                    refresh()
                    requestSave()
                end
                leftBtn.MouseButton1Click:Connect(function() bump(-1) end)
                rightBtn.MouseButton1Click:Connect(function() bump(1) end)
                refresh()
            end

            makeGap(4)
            makeSectionHeader("Steal Mode")
            makeGap(2)

            do
                local modeHolder = Instance.new("Frame", currentPage)
                modeHolder.Size  = UDim2.new(1,-16,0,46)
                modeHolder.BackgroundTransparency = 1
                modeHolder.BorderSizePixel = 0
                modeHolder.LayoutOrder = LO()

                -- sem bolha em volta: dois botoes lado a lado, texto inteiro,
                -- e uma listra branca circulando a opcao selecionada
                local modeBtns = {}
                local function mkModeBtn(key, label, xScale, xOff)
                    local b = Instance.new("TextButton", modeHolder)
                    b.Size = UDim2.new(0.5, -5, 1, 0)
                    b.Position = UDim2.new(xScale, xOff, 0, 0)
                    b.BackgroundColor3 = Color3.fromRGB(45,205,255)
                    b.BackgroundTransparency = 0
                    b.BorderSizePixel = 0
                    b.AutoButtonColor = false
                    b.Text = label
                    b.TextColor3 = Color3.fromRGB(255,255,255)
                    b.Font = Enum.Font.GothamBold
                    b.TextSize = 14
                    b.TextTruncate = Enum.TextTruncate.None
                    b.TextWrapped = false
                    mkCorner(b, 12)
                    local st = Instance.new("UIStroke", b)
                    st.Name = "SelectRing"
                    st.Color = Color3.fromRGB(255,255,255)
                    st.Thickness = 2
                    st.Transparency = 1
                    modeBtns[key] = {btn = b, stroke = st}
                    return b
                end
                local normalClick = mkModeBtn("Normal", "NORMAL", 0,   0)
                local semiClick   = mkModeBtn("Semi",   "SEMI",   0.5, 5)

                local function paintMode(mode)
                    for key, ref in pairs(modeBtns) do
                        local on = (key == mode)
                        TweenService:Create(ref.stroke, TweenInfo.new(0.14), {
                            Transparency = on and 0 or 1
                        }):Play()
                        TweenService:Create(ref.btn, TweenInfo.new(0.14), {
                            BackgroundTransparency = on and 0.45 or 0.85,
                            TextTransparency = on and 0 or 0.35,
                        }):Play()
                    end
                end

                local function setMode(mode)
                    if mode~="Semi" then mode="Normal" end
                    if autoGrabModule then
                        local oldMode = autoGrabModule.getMode()
                        local oldRadii = autoGrabModule.getRadii()
                        oldRadii[oldMode] = Steal.StealRadius
                    end
                    if autoGrabModule then autoGrabModule.setMode(mode) end
                    local radii = autoGrabModule and autoGrabModule.getRadii() or {Normal=60,Semi=60}
                    Steal.StealRadius = radii[mode] or (mode=="Semi" and 60 or 75)
                    if stealRadBox then stealRadBox.Text = tostring(Steal.StealRadius) end
                    paintMode(mode)
                    requestSave()
                end

                _G._K7SafeClick(normalClick, function() setMode("Normal") end)
                _G._K7SafeClick(semiClick, function() setMode("Semi") end)

                paintMode(autoGrabModule and autoGrabModule.getMode() or "Normal")

                _G._K7StealModeSetUI = setMode
            end

            -- ── SEMI AUTO STEAL V3 (portado do Ambitious) ─────────────
            makeGap(4)
            makeSectionHeader("Semi Auto Steal V3")
            makeGap(2)

            local semiDelayBox = makeInputRow("Delay Radius", State.semiDelayRadius or 8, function(n)
                if n and n > 0 and n <= 500 then
                    State.semiDelayRadius = n
                    if _G.K7SemiSteal then _G.K7SemiSteal.autoGrabSetDelayRadius = n end
                    requestSave()
                end
            end)

            local semiStopPctBox = makeInputRow("Stop Time (%)", State.semiStopPercent or 75, function(n)
                if n and n >= 1 and n <= 100 then
                    State.semiStopPercent = n
                    if _G.K7SemiSteal then _G.K7SemiSteal.autoGrabStopPercent = n end
                    requestSave()
                end
            end)

            _G._K7SyncSemiV3Settings = function()
                if semiDelayBox then semiDelayBox.Text = tostring(State.semiDelayRadius or 8) end
                if semiStopPctBox then semiStopPctBox.Text = tostring(State.semiStopPercent or 75) end
            end



            makeGap(4)
            makeSectionHeader("Grab Config")
            makeGap(2)

            stealRadBox = makeInputRow("Grab Radius", Steal.StealRadius, function(n)
                if n and n >= 1 and n <= 200 then
                    local applied = math.clamp(n,1,200)
                    Steal.StealRadius = applied
                    if stealRadBox then stealRadBox.Text = tostring(applied) end
                    if autoGrabModule then autoGrabModule.setRadius(applied) end
                    requestSave()
                end
            end)
            _G._K7SyncGrabRadiusValue = function(value)
                local radius = tonumber(value)
                if radius and stealRadBox and stealRadBox.Parent then
                    Steal.StealRadius = radius
                    stealRadBox.Text = tostring(math.floor(radius + 0.5))
                end
            end

        end)
        page.LayoutOrder = 4
    end

    -- CONFIG TAB (updated with softSteal added to reset)
    do
        local page = buildPage("Config", function()
            makeGap(2)
            makeSectionHeader("Interface")
            makeGap(2)
            makeKeybindRow("Hide GUI", Keys.guiHide, function(k) Keys.guiHide=k end, "guiHide")
            local menuSizeRow=Instance.new("Frame",currentPage)
            menuSizeRow.Size=UDim2.new(1,-16,0,42)
            menuSizeRow:SetAttribute("AlwaysCyanOptionBar", true)
            menuSizeRow.BackgroundColor3 = Color3.fromRGB(90,225,255)
            menuSizeRow.BackgroundTransparency = 0.18
            menuSizeRow.BorderSizePixel=0
            menuSizeRow.LayoutOrder=LO()
            mkCorner(menuSizeRow,21)
            local menuSizeTitle=Instance.new("TextLabel",menuSizeRow)
            menuSizeTitle.Size=UDim2.new(1,-150,1,0); menuSizeTitle.Position=UDim2.new(0,14,0,0)
            menuSizeTitle.BackgroundTransparency=1; menuSizeTitle.Text="Menu Size"
            menuSizeTitle.TextColor3=currentColorScheme.rowLabel; menuSizeTitle.Font=Enum.Font.GothamBold
            menuSizeTitle.TextSize=11; menuSizeTitle.TextXAlignment=Enum.TextXAlignment.Left
            local menuMinus=Instance.new("TextButton",menuSizeRow)
            menuMinus.Size=UDim2.new(0,34,0,30); menuMinus.Position=UDim2.new(1,-40,0.5,-15)
            menuMinus.BackgroundColor3=Color3.fromRGB(45,205,255); menuMinus.BackgroundTransparency=0
            menuMinus.BorderSizePixel=0; menuMinus.Text="-"; menuMinus.TextColor3=Color3.fromRGB(255,255,255)
            menuMinus.Font=Enum.Font.GothamBold; menuMinus.TextSize=17; mkCorner(menuMinus,6)
            local menuMinusStroke=Instance.new("UIStroke",menuMinus); menuMinusStroke.Color=Color3.fromRGB(255,255,255); menuMinusStroke.Thickness=1.5; menuMinusStroke.Transparency=0
            uiScaleBox=Instance.new("TextLabel",menuSizeRow)
            uiScaleBox.Size=UDim2.new(0,54,0,30); uiScaleBox.Position=UDim2.new(1,-98,0.5,-15)
            uiScaleBox.BackgroundColor3=Color3.fromRGB(45,205,255); uiScaleBox.BackgroundTransparency=0
            uiScaleBox.BorderSizePixel=0
            uiScaleBox.TextColor3=currentColorScheme.rowValue; uiScaleBox.Font=Enum.Font.GothamBold
            uiScaleBox.TextSize=11; mkCorner(uiScaleBox,6)
            local uiScaleBoxStroke=Instance.new("UIStroke",uiScaleBox); uiScaleBoxStroke.Color=Color3.fromRGB(255,255,255); uiScaleBoxStroke.Thickness=1.5; uiScaleBoxStroke.Transparency=0
            local menuPlus=Instance.new("TextButton",menuSizeRow)
            menuPlus.Size=UDim2.new(0,34,0,30); menuPlus.Position=UDim2.new(1,-136,0.5,-15)
            menuPlus.BackgroundColor3=Color3.fromRGB(45,205,255); menuPlus.BackgroundTransparency=0
            menuPlus.BorderSizePixel=0; menuPlus.Text="+"; menuPlus.TextColor3=Color3.fromRGB(255,255,255)
            menuPlus.Font=Enum.Font.GothamBold; menuPlus.TextSize=17; mkCorner(menuPlus,6)
            local menuPlusStroke=Instance.new("UIStroke",menuPlus); menuPlusStroke.Color=Color3.fromRGB(255,255,255); menuPlusStroke.Thickness=1.5; menuPlusStroke.Transparency=0

            -- Menu size: always a clean 1 decimal step (no 0.92782672 junk)
            local MENU_MIN, MENU_MAX = 0.4, 1.5
            local function roundStep(v)
                v = tonumber(v) or 1
                v = math.floor(v * 10 + 0.5) / 10
                return math.clamp(v, MENU_MIN, MENU_MAX)
            end
            local function applyMenuScale(v, save)
                v = roundStep(v)
                _G._K7MenuScaleManual = true
                _G._K7MenuScale = v
                if uiScaleObj then uiScaleObj.Scale = v end
                if uiScaleBox then uiScaleBox.Text = string.format("%.1f", v) end
                if _G._K7FitMenuToScreen then pcall(_G._K7FitMenuToScreen) end
                if save then requestSave() end
            end
            _G._K7ApplyMenuScale = applyMenuScale
            applyMenuScale(_G._K7MenuScale or 1, false)
            _G._K7SafeClick(menuMinus, function() applyMenuScale((_G._K7MenuScale or 1) - 0.1, true) end)
            _G._K7SafeClick(menuPlus, function() applyMenuScale((_G._K7MenuScale or 1) + 0.1, true) end)


            local buttonSizeRow=Instance.new("Frame",currentPage)
            buttonSizeRow.Size=UDim2.new(1,-16,0,42)
            buttonSizeRow:SetAttribute("AlwaysCyanOptionBar", true)
            buttonSizeRow.BackgroundColor3 = Color3.fromRGB(90,225,255)
            buttonSizeRow.BackgroundTransparency = 0.18
            buttonSizeRow.BorderSizePixel=0
            buttonSizeRow.LayoutOrder=LO()
            mkCorner(buttonSizeRow,21)
            local buttonSizeTitle=Instance.new("TextLabel",buttonSizeRow)
            buttonSizeTitle.Size=UDim2.new(1,-150,1,0); buttonSizeTitle.Position=UDim2.new(0,14,0,0)
            buttonSizeTitle.BackgroundTransparency=1; buttonSizeTitle.Text="Mobile Button Size"
            buttonSizeTitle.TextColor3=currentColorScheme.rowLabel; buttonSizeTitle.Font=Enum.Font.GothamBold
            buttonSizeTitle.TextSize=11; buttonSizeTitle.TextXAlignment=Enum.TextXAlignment.Left
            local sizeMinus=Instance.new("TextButton",buttonSizeRow)
            sizeMinus.Size=UDim2.new(0,34,0,30); sizeMinus.Position=UDim2.new(1,-40,0.5,-15)
            sizeMinus.BackgroundColor3=Color3.fromRGB(45,205,255); sizeMinus.BackgroundTransparency=0
            sizeMinus.BorderSizePixel=0; sizeMinus.Text="-"; sizeMinus.TextColor3=Color3.fromRGB(255,255,255)
            sizeMinus.Font=Enum.Font.GothamBold; sizeMinus.TextSize=17; mkCorner(sizeMinus,6)
            local sizeMinusStroke=Instance.new("UIStroke",sizeMinus); sizeMinusStroke.Color=Color3.fromRGB(255,255,255); sizeMinusStroke.Thickness=1.5; sizeMinusStroke.Transparency=0
            buttonScaleBox=Instance.new("TextLabel",buttonSizeRow)
            buttonScaleBox.Size=UDim2.new(0,54,0,30); buttonScaleBox.Position=UDim2.new(1,-98,0.5,-15)
            buttonScaleBox.BackgroundColor3=Color3.fromRGB(45,205,255); buttonScaleBox.BackgroundTransparency=0
            buttonScaleBox.BorderSizePixel=0; buttonScaleBox.Text=string.format("%.1f",stackButtonScale)
            buttonScaleBox.TextColor3=currentColorScheme.rowValue; buttonScaleBox.Font=Enum.Font.GothamBold
            buttonScaleBox.TextSize=11; mkCorner(buttonScaleBox,6)
            local buttonScaleBoxStroke=Instance.new("UIStroke",buttonScaleBox); buttonScaleBoxStroke.Color=Color3.fromRGB(255,255,255); buttonScaleBoxStroke.Thickness=1.5; buttonScaleBoxStroke.Transparency=0
            local sizePlus=Instance.new("TextButton",buttonSizeRow)
            sizePlus.Size=UDim2.new(0,34,0,30); sizePlus.Position=UDim2.new(1,-136,0.5,-15)
            sizePlus.BackgroundColor3=Color3.fromRGB(45,205,255); sizePlus.BackgroundTransparency=0
            sizePlus.BorderSizePixel=0; sizePlus.Text="+"; sizePlus.TextColor3=Color3.fromRGB(255,255,255)
            sizePlus.Font=Enum.Font.GothamBold; sizePlus.TextSize=17; mkCorner(sizePlus,6)
            local sizePlusStroke=Instance.new("UIStroke",sizePlus); sizePlusStroke.Color=Color3.fromRGB(255,255,255); sizePlusStroke.Thickness=1.5; sizePlusStroke.Transparency=0
            local function changeButtonSize(delta)
                local value=applyStackButtonScale(stackButtonScale+delta)
                buttonScaleBox.Text=string.format("%.1f",value)
                requestSave()
            end
            _G._K7SafeClick(sizeMinus, function() changeButtonSize(-0.1) end)
            _G._K7SafeClick(sizePlus, function() changeButtonSize(0.1) end)

            local shapeRow=Instance.new("Frame",currentPage)
            shapeRow.Size=UDim2.new(1,-16,0,44)
            shapeRow:SetAttribute("AlwaysCyanOptionBar", true)
            shapeRow.BackgroundColor3 = Color3.fromRGB(90,225,255)
            shapeRow.BackgroundTransparency = 0.18
            shapeRow.BorderSizePixel=0
            shapeRow.LayoutOrder=LO()
            mkCorner(shapeRow,14)
            local shapeTitle=Instance.new("TextLabel",shapeRow)
            shapeTitle.Size=UDim2.new(0,72,1,0); shapeTitle.Position=UDim2.new(0,10,0,0)
            shapeTitle.BackgroundTransparency=1; shapeTitle.Text="Shape"
            shapeTitle.TextColor3=currentColorScheme.rowLabel; shapeTitle.Font=Enum.Font.GothamBold
            shapeTitle.TextSize=12; shapeTitle.TextXAlignment=Enum.TextXAlignment.Left

            local shapeButtons={}
            local function makeShapeButton(label,shape,xOffset)
                local button=Instance.new("TextButton",shapeRow)
                button.Size=UDim2.new(0,52,0,30); button.Position=UDim2.new(1,xOffset,0.5,-15)
                button.BackgroundColor3=currentColorScheme.modeBtnBg; button.BackgroundTransparency=0.16
                button.BorderSizePixel=0; button.Text=label; button.TextColor3=currentColorScheme.mainLight
                button.Font=Enum.Font.GothamBold; button.TextSize=9; button.AutoButtonColor=false
                mkCorner(button,10)
                shapeButtons[shape]=button
                _G._K7SafeClick(button, function()
                    applyMobileButtonShape(shape)
                    if _G._K7RefreshMobileButtonShape then _G._K7RefreshMobileButtonShape() end
                    requestSave()
                end)
            end
            makeShapeButton("MAY CAN","Can",-170)
            makeShapeButton("CIRCLE","Circle",-114)
            makeShapeButton("SQUARE","Square",-58)
            local function refreshMobileButtonShape()
                for shape,button in pairs(shapeButtons) do
                    local selected=State.mobileButtonShape==shape
                    button.BackgroundColor3=selected and currentColorScheme.main or currentColorScheme.modeBtnBg
                    button.TextColor3=selected and (currentColorScheme.buttonText or currentColorScheme.text) or currentColorScheme.mainLight
                    button.BackgroundTransparency=selected and 0.02 or 0.16
                end
            end
            _G._K7RefreshMobileButtonShape=refreshMobileButtonShape
            refreshMobileButtonShape()

            hideButtonsSetter = makeToggleRow("Hide Buttons", State.stackButtonsHidden, function(on) State.stackButtonsHidden=on; for _,wrapper in pairs(stackWrappers) do wrapper.Visible=not on end end)
            toggleSetters["hideButtons"] = hideButtonsSetter
            lockButtonsSetter = makeToggleRow("Lock Buttons", State.stackButtonsLocked, function(on)
                State.stackButtonsLocked=on
                State.uiLocked=on
                _G._K7UILocked=on
                requestSave()
            end)
            toggleSetters["lockButtons"] = lockButtonsSetter

            makeGap(8)
            makeSectionHeader("Keybinds")
            makeGap(2)
            makeKeybindRow("Speed Toggle", Keys.speed, function(k) Keys.speed=k end, "speed")
            makeKeybindRow("Lagger Toggle", Keys.lagger, function(k) Keys.lagger=k end, "lagger")
            makeKeybindRow("Drop", Keys.drop, function(k) Keys.drop=k end, "drop")
            makeKeybindRow("Auto Left", Keys.autoLeft, function(k) Keys.autoLeft=k end, "autoLeft")
            makeKeybindRow("Auto Right", Keys.autoRight, function(k) Keys.autoRight=k end, "autoRight")
            makeKeybindRow("TP Down", Keys.tpDown, function(k) Keys.tpDown=k end, "tpDown")
            makeKeybindRow("Aimbot", Keys.aimbot, function(k) Keys.aimbot=k end, "aimbot")
            makeKeybindRow("Tp Bat", Keys.antiDesync, function(k) Keys.antiDesync=k end, "antiDesync")
            makeKeybindRow("Bat V2", Keys.batV2, function(k) Keys.batV2=k end, "batV2")
            makeKeybindRow("Anti Tp Bat", Keys.antiBatTp, function(k) Keys.antiBatTp=k end, "antiBatTp")
            makeKeybindRow("Bat Aimbot", Keys.batAimbot, function(k) Keys.batAimbot=k end, "batAimbot")
            makeKeybindRow("Insta Reset", Keys.instaReset, function(k) Keys.instaReset=k end, "instaReset")

            makeGap(8)
            makeSectionHeader("Config Management")
            makeGap(2)
            local saveWrap = Instance.new("Frame", currentPage); saveWrap.Size = UDim2.new(1,0,0,36); saveWrap.BackgroundTransparency=1; saveWrap.BorderSizePixel=0; saveWrap.LayoutOrder=LO()
            local saveBtn = Instance.new("TextButton", saveWrap)
            saveBtn.Size = UDim2.new(1,-28,0,30)
            saveBtn.Position = UDim2.new(0,14,0,3)
            saveBtn.BackgroundColor3 = currentColorScheme.btnBg
            saveBtn.BackgroundTransparency = 0.2
            saveBtn.BorderSizePixel = 0
                        saveBtn.Text = "SAVE CONFIG"
            saveBtn.TextColor3 = currentColorScheme.main
            saveBtn.Font = Enum.Font.GothamBold
            saveBtn.TextSize = 13
            saveBtn.ZIndex = 5
            mkCorner(saveBtn, 16)

            saveBtn.MouseEnter:Connect(function()
                TweenService:Create(saveBtn, TweenInfo.new(0.1), {BackgroundColor3 = currentColorScheme.main, BackgroundTransparency = 0.05, TextColor3 = currentColorScheme.buttonText}):Play()
            end)
            saveBtn.MouseLeave:Connect(function()
                TweenService:Create(saveBtn, TweenInfo.new(0.1), {BackgroundColor3 = currentColorScheme.btnBg, BackgroundTransparency = 0.2, TextColor3 = currentColorScheme.main}):Play()
            end)
            _G._K7SafeClick(saveBtn, function()
                local callOk, saveOk = pcall(saveConfig)
                local success = callOk and saveOk == true
                if success then
                    saveBtn.Text = "SAVED!"
                    saveBtn.BackgroundColor3 = currentColorScheme.main
                    saveBtn.BackgroundTransparency = 0.05
                    saveBtn.TextColor3 = currentColorScheme.buttonText
                else
                    saveBtn.Text = "FAILED"
                    saveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 40)
                    saveBtn.BackgroundTransparency = 0.1
                    saveBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
                end
                task.delay(2.5, function()
                    if saveBtn and saveBtn.Parent then
            saveBtn.Text = "SAVE CONFIG"
                        saveBtn.BackgroundColor3 = currentColorScheme.btnBg
                        saveBtn.BackgroundTransparency = 0.2
                        saveBtn.TextColor3 = currentColorScheme.main
                    end
                end)
            end)

            local resetWrap = Instance.new("Frame", currentPage); resetWrap.Size = UDim2.new(1,0,0,36); resetWrap.BackgroundTransparency=1; resetWrap.BorderSizePixel=0; resetWrap.LayoutOrder=LO()
            local resetAllBtn = Instance.new("TextButton", resetWrap); resetAllBtn.Size = UDim2.new(1,-28,0,26); resetAllBtn.Position = UDim2.new(0,14,0,5); resetAllBtn.BackgroundColor3=currentColorScheme.mainDark; resetAllBtn.BackgroundTransparency=0.2; resetAllBtn.BorderSizePixel=0; resetAllBtn.Text="Reset All Settings"; resetAllBtn.TextColor3=currentColorScheme.buttonText; resetAllBtn.Font=Enum.Font.GothamBold; resetAllBtn.TextSize=11; resetAllBtn.ZIndex=5; mkCorner(resetAllBtn,16)
            resetAllBtn.MouseEnter:Connect(function() TweenService:Create(resetAllBtn,TweenInfo.new(0.1),{BackgroundColor3=currentColorScheme.main,BackgroundTransparency=0.05}):Play() end)
            resetAllBtn.MouseLeave:Connect(function() TweenService:Create(resetAllBtn,TweenInfo.new(0.1),{BackgroundColor3=currentColorScheme.mainDark,BackgroundTransparency=0.2}):Play() end)
            local _resetConfirmStage=0; local _resetConfirmTimer=nil
            _G._K7SafeClick(resetAllBtn, function()
                if _resetConfirmStage==0 then
                    _resetConfirmStage=1; resetAllBtn.Text="Click again to confirm!"; resetAllBtn.BackgroundColor3=currentColorScheme.main; resetAllBtn.BackgroundTransparency=0.05
                    if _resetConfirmTimer then task.cancel(_resetConfirmTimer) end
                    _resetConfirmTimer = task.delay(3,function() if resetAllBtn and resetAllBtn.Parent then _resetConfirmStage=0; resetAllBtn.Text="Reset All Settings"; resetAllBtn.BackgroundColor3=currentColorScheme.mainDark; resetAllBtn.BackgroundTransparency=0.2 end end)
                    return
                end
                _resetConfirmStage=0; if _resetConfirmTimer then task.cancel(_resetConfirmTimer); _resetConfirmTimer=nil end
                pcall(function() if State.batAimbotToggled then stopBatAimbot() end end)
                pcall(function() if State.batCounterEnabled then stopBatCounter() end end)
                pcall(function() if State.medusaCounterEnabled then stopMedusaCounter() end end)
                pcall(function() if State.antiRagdollEnabled then stopAntiRagdollNew() end end)
                pcall(function() if State.antiLagEnabled then disableAntiLag() end end)
                pcall(function() if State.stretchedResEnabled then disableStretchRez() end end)
                pcall(function() if State.autoTPEnabled then stopAutoTP() end end)

                pcall(function() if State.antiDieEnabled then stopAntiDie() end end)
                pcall(function() if State.antiFlingShieldEnabled then stopAntiFlingShield() end end)

                State.normalSpeed=60; State.carrySpeed=30; State.laggerSpeed=15; State.laggerCarrySpeed=24.5
                State.speedToggled=false; State.laggerMode=0; State.infJumpEnabled=true; State.antiRagdollEnabled=false; State.antiRagdollVersion="V1"
                State.antiLagEnabled=false; State.saturatedColorsEnabled=false; State.stretchedResEnabled=false
                State.medusaCounterEnabled=false; State.batCounterEnabled=false; State.ragdollCountdownEnabled=false
                State.batAimbotToggled=false; State.autoSwingEnabled=true; State.informationE01Enabled=true
                State.stackButtonsHidden=false; State.stackButtonsLocked=false; State.mobileButtonShape="Can"; State.introEnabled=false; _introEnabled=false
                State.autoTPEnabled=false; State.autoTPHeight=20; State.removeAcc=false; State.tryardAnimEnabled=false
                if _G._removeAccStop then pcall(_G._removeAccStop) end
                AIMBOT_SPEED=50; LAGGER_AIMBOT_SPEED=40
                if _G.AceRefreshAimbotSpeedBoxes then pcall(_G.AceRefreshAimbotSpeedBoxes) end

                State.espEnabled=false; State.showTrackerEnabled=false; State.skyTheme="Off"
                State.antiDieEnabled=false; State.antiFlingShieldEnabled=false
                BoxedESPOptions.tracker=false
                stopPlayerESP(); refreshBoxedESP(); pcall(applyCustomSky,"Off")
                if toggleSetters["esp"] then pcall(toggleSetters["esp"],false) end
                if toggleSetters["showTracker"] then pcall(toggleSetters["showTracker"],false) end
                if _G.MysteryStopRagdollCountdown then pcall(_G.MysteryStopRagdollCountdown) end
                if toggleSetters["ragdollCountdown"] then pcall(toggleSetters["ragdollCountdown"],false) end
                State.headlessEnabled = false
                State.korbloxEnabled = false
                State.customSkinEnabled = false
                State.customSkinVariant = 1
                syncCustomSkinVariant(1)
                set7UpColorTheme("Green", true)
                State.outfit1Applied = false
                State.outfit3Applied = false
                State.outfit2Applied = false
                pcall(applyCharterToChar, LP.Character)
                if toggleSetters["headless"] then pcall(toggleSetters["headless"], false) end
                if toggleSetters["korblox"] then pcall(toggleSetters["korblox"], false) end
                if toggleSetters["customSkin"] then pcall(toggleSetters["customSkin"], false) end
                if toggleSetters["outfit1"] then pcall(toggleSetters["outfit1"], false) end
                if toggleSetters["outfit2"] then pcall(toggleSetters["outfit2"], false) end
                if toggleSetters["outfit3"] then pcall(toggleSetters["outfit3"], false) end
                Steal.StealRadius=75
                Steal.AutoStealEnabled=true
                if autoGrabModule then
                    local resetRadii = autoGrabModule.getRadii()
                    if resetRadii then resetRadii.Normal=75; resetRadii.Semi=60 end
                    autoGrabModule.setMode("Normal")
                    autoGrabModule.setRadius(75)
                    autoGrabModule.setEnabled(true)
                end
                -- Reset Soft Steal
                State.softStealEnabled = false
                State.softStealLatched = false
                State.semiStopPercent = 75
                State.semiDelayRadius = 8
                if _G.K7SemiSteal then
                    _G.K7SemiSteal.autoGrabStopPercent = 75
                    _G.K7SemiSteal.autoGrabSetDelayRadius = 8
                end
                if _G._K7SyncSemiV3Settings then pcall(_G._K7SyncSemiV3Settings) end
                State.softStealRadius = 10
                State.softStealSpeed = 30
                if softStealRadiusBox then softStealRadiusBox.Text = "10" end
                if softStealSpeedBox then softStealSpeedBox.Text = "30" end
                if autoGrabModule and autoGrabModule.stopSoftStealScanner then
                    autoGrabModule.stopSoftStealScanner()
                end
                if toggleSetters["softSteal"] then pcall(toggleSetters["softSteal"], false) end

                Keys.speed=Enum.KeyCode.Q; Keys.guiHide=Enum.KeyCode.LeftControl
                Keys.lagger=Enum.KeyCode.Unknown; Keys.tpDown=Enum.KeyCode.Unknown; Keys.drop=Enum.KeyCode.H; Keys.aimbot=Enum.KeyCode.Unknown
                Keys.autoLeft=Enum.KeyCode.L; Keys.autoRight=Enum.KeyCode.R
                Keys.antiDesync=Enum.KeyCode.V
                Keys.batV2=Enum.KeyCode.Unknown; Keys.antiBatTp=Enum.KeyCode.Unknown
                Keys.instaReset=Enum.KeyCode.Unknown; Keys.batAimbot=Enum.KeyCode.Unknown
                currentDropType = DROP_TYPES.JUMP
                if normalBox then normalBox.Text=tostring(State.normalSpeed) end; if carryBox then carryBox.Text=tostring(State.carrySpeed) end
                if laggerBox then laggerBox.Text=tostring(State.laggerSpeed) end; if laggerCarryBox then laggerCarryBox.Text=tostring(State.laggerCarrySpeed) end
                if stealRadBox then stealRadBox.Text=tostring(Steal.StealRadius) end
                if _G._K7ApplyMenuScale then pcall(_G._K7ApplyMenuScale, 1, false) else if uiScaleObj then uiScaleObj.Scale=1; _G._K7MenuScale=1 end; if uiScaleBox then uiScaleBox.Text="1.0" end end; if _G._K7FitMenuToScreen then pcall(_G._K7FitMenuToScreen) end
                applyStackButtonScale(1); if buttonScaleBox then buttonScaleBox.Text="1.0" end
                applyMobileButtonShape("Can"); if _G._K7RefreshMobileButtonShape then pcall(_G._K7RefreshMobileButtonShape) end
                if setInfJump then pcall(setInfJump,true) end; if setAntiRag then pcall(setAntiRag,false) end
                if setMedusaCounter then pcall(setMedusaCounter,false) end; if setBatCounter then pcall(setBatCounter,false) end; if setAutoSwing then pcall(setAutoSwing,true) end
                if hideButtonsSetter then pcall(hideButtonsSetter,false) end; if lockButtonsSetter then pcall(lockButtonsSetter,false) end
                if toggleSetters["autoSteal"] then pcall(toggleSetters["autoSteal"], true) end
                if toggleSetters["antiLag"] then pcall(toggleSetters["antiLag"], false) end
                if toggleSetters["stretchedRes"] then pcall(toggleSetters["stretchedRes"], false) end
                if toggleSetters["removeAcc"] then pcall(toggleSetters["removeAcc"], false) end
                if toggleSetters["tryardAnim"] then pcall(toggleSetters["tryardAnim"], false) end

                if toggleSetters["antiDie"] then pcall(toggleSetters["antiDie"], false) end
                if toggleSetters["antiFlingShield"] then pcall(toggleSetters["antiFlingShield"], false) end
                if _G._K7RefreshRagdollVersionButtons then pcall(_G._K7RefreshRagdollVersionButtons) end
                if stackBtnRefs then for key,ref in pairs(stackBtnRefs) do if ref and ref.setOn then pcall(ref.setOn,false) end end end
                if keybindBtnRefs then refreshAllKeybindButtons() end
                for i,def in ipairs(stackDefs) do local wrapper=stackWrappers[def.key]; if wrapper then TweenService:Create(wrapper,TweenInfo.new(0.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=getDefaultStackPos(i)}):Play() end end
                resetAllBtn.Text="All Settings Reset!"; resetAllBtn.BackgroundColor3=currentColorScheme.main; resetAllBtn.BackgroundTransparency=0.05
                task.delay(2,function() if resetAllBtn and resetAllBtn.Parent then resetAllBtn.Text="Reset All Settings"; resetAllBtn.BackgroundColor3=currentColorScheme.mainDark; resetAllBtn.BackgroundTransparency=0.2 end end)
            end)

            makeGap(8)
            makeSectionHeader("Layout")
            makeGap(2)
            local rWrap = Instance.new("Frame", currentPage); rWrap.Size = UDim2.new(1,0,0,36); rWrap.BackgroundTransparency=1; rWrap.BorderSizePixel=0; rWrap.LayoutOrder=LO()
            local resetBtn = Instance.new("TextButton", rWrap); resetBtn.Size = UDim2.new(1,-28,0,26); resetBtn.Position = UDim2.new(0,14,0,5); resetBtn.BackgroundColor3=currentColorScheme.btnBg; resetBtn.BackgroundTransparency=0.3; resetBtn.BorderSizePixel=0; resetBtn.Text="Reset Button Positions"; resetBtn.TextColor3=currentColorScheme.btnTxt; resetBtn.Font=Enum.Font.GothamBold; resetBtn.TextSize=11; resetBtn.ZIndex=5; mkCorner(resetBtn,16)
            resetBtn.MouseEnter:Connect(function() TweenService:Create(resetBtn,TweenInfo.new(0.1),{BackgroundColor3=currentColorScheme.btnHov,BackgroundTransparency=0.1}):Play() end)
            resetBtn.MouseLeave:Connect(function() TweenService:Create(resetBtn,TweenInfo.new(0.1),{BackgroundColor3=currentColorScheme.btnBg,BackgroundTransparency=0.3}):Play() end)
            _G._K7SafeClick(resetBtn, function()
                for i,def in ipairs(stackDefs) do local wrapper=stackWrappers[def.key]; if wrapper then TweenService:Create(wrapper,TweenInfo.new(0.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=getDefaultStackPos(i)}):Play() end end
                resetBtn.Text="Positions Reset!"; task.delay(1.8,function() if resetBtn and resetBtn.Parent then resetBtn.Text="Reset Button Positions" end end)
            end)

            makeGap(10)
            local fw = Instance.new("Frame", currentPage); fw.Size = UDim2.new(1,0,0,22); fw.BackgroundTransparency=1; fw.BorderSizePixel=0; fw.LayoutOrder=LO()
            local fl = Instance.new("TextLabel", fw); fl.Size = UDim2.new(1,0,1,0); fl.BackgroundTransparency=1; fl.Text="discord.gg/GvBQmT7Xj"; fl.TextColor3=Color3.fromRGB(131, 131, 131); fl.Font=Enum.Font.GothamBold; fl.TextSize=10; fl.TextXAlignment=Enum.TextXAlignment.Center
            _G._VezySaveStatusLbl = fl
            _G._VezyFlashSave = function(success)
                if not _G._VezySaveStatusLbl or not _G._VezySaveStatusLbl.Parent then return end
                local lbl = _G._VezySaveStatusLbl
                if success then lbl.Text="Auto-saved"; lbl.TextColor3=currentColorScheme.main
                else lbl.Text="Save failed"; lbl.TextColor3=currentColorScheme.mainLight end
                task.delay(1.5,function() if lbl and lbl.Parent then lbl.Text="discord.gg/GvBQmT7Xj"; lbl.TextColor3=Color3.fromRGB(131, 131, 131) end end)
            end
        end)
        page.LayoutOrder = 5
    end

    -- ============================================================
    -- SELECT FIRST TAB
    -- ============================================================
    selectTab(1)
    pcall(_G._K7ApplyOpaqueMenuStyle)

    -- ============================================================
    -- STACK BUTTONS (green theme)
    -- ============================================================
    updateLaggerButtons = function()
        if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(State.laggerMode==1) end
        if stackBtnRefs.laggerCarry then stackBtnRefs.laggerCarry.setOn(State.laggerMode==2) end
    end

    setLaggerMode = function(mode)
        if mode == State.laggerMode then return end
        State.laggerMode = mode
        -- Turning ANY Lagger mode on always disables Carry Mode automatically.
        if mode ~= 0 and State.speedToggled then
            State.speedToggled = false
            if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(false) end
            if toggleSetters["carryMode"] then pcall(toggleSetters["carryMode"], false) end
        end
        if carryBox then carryBox.Text = tostring(State.carrySpeed) end
        updateLaggerButtons()
        if _G.__K7SpeedFlush then pcall(_G.__K7SpeedFlush) end
        if toggleSetters["laggerMode"] then
            pcall(toggleSetters["laggerMode"], State.laggerMode ~= 0)
        end
        requestSave()
    end

    -- Ciclo do Adapt: desligado -> Lagger Carry -> Lagger -> Lagger Carry
    local function toggleLaggerMode()
        if State.laggerMode == 0 then setLaggerMode(2)
        elseif State.laggerMode == 2 then setLaggerMode(1)
        else setLaggerMode(2) end
    end

    local function toggleSpeed()
        State.speedToggled = not State.speedToggled
        -- Turning Carry Mode on always disables any Lagger mode automatically.
        if State.speedToggled and State.laggerMode ~= 0 then
            State.laggerMode = 0
            if updateLaggerButtons then updateLaggerButtons() end
            if toggleSetters["laggerMode"] then pcall(toggleSetters["laggerMode"], false) end
        end
        if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(State.speedToggled) end
        if _G.__K7SpeedFlush then pcall(_G.__K7SpeedFlush) end
        if toggleSetters["carryMode"] then
            pcall(toggleSetters["carryMode"], State.speedToggled == true)
        end
        if carryBox then carryBox.Text = tostring(State.carrySpeed) end
        requestSave()
    end

    for i,def in ipairs(stackDefs) do
        local btnFrame = Instance.new("TextButton", stackGui)
        btnFrame.Name = "StackBtn_"..def.key
        btnFrame.Size = UDim2.new(0,BTN_W,0,BTN_H)
        btnFrame.Position = getDefaultStackPos(i)
        btnFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
        btnFrame.BackgroundTransparency = 0
        btnFrame.BorderSizePixel=0
        btnFrame.AutoButtonColor = false
        btnFrame.Text = ""
        btnFrame.TextColor3 = Color3.fromRGB(255,255,255)
        btnFrame.TextScaled = false
        btnFrame.TextSize = 16
        btnFrame.Font = Enum.Font.GothamBold
        btnFrame.TextWrapped = true
        btnFrame.LineHeight = 1.2
        btnFrame.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        btnFrame.TextStrokeTransparency = 1
        btnFrame.ZIndex=15
        btnFrame.Visible = false
        mkCorner(btnFrame,16)
        local mobileScale=Instance.new("UIScale",btnFrame)
        mobileScale.Name="MobileButtonOnlyScale"
        mobileScale.Scale=stackButtonScale

        local stackSurface = Instance.new("Frame",btnFrame)
        stackSurface.Name="SodaCanSurface"
        stackSurface.Size=UDim2.new(1,0,1,-10)
        stackSurface.Position=UDim2.new(0,0,0,10)
        stackSurface.BackgroundColor3=Color3.fromRGB(0,0,0)
        stackSurface.BackgroundTransparency=0.08
        stackSurface.BorderSizePixel=0
        stackSurface.ClipsDescendants=true
        stackSurface.Active=false
        stackSurface.ZIndex=14
        mkCorner(stackSurface,14)
        local stackGradient=Instance.new("UIGradient",stackSurface)
        stackGradient.Name="AdaptiveCanBlend"
        stackGradient.Color=adaptiveCanColorSequence(currentColorScheme,false)
        stackGradient.Rotation=8
        local topNeck=Instance.new("Frame",btnFrame)
        topNeck.Name="IndentedCanTop"
        -- Wide, shallow indented cap: it overlaps the body as one can instead
        -- of reading as a separate circle.
        topNeck.Size=UDim2.new(1,-8,0,26); topNeck.Position=UDim2.new(0,4,0,0)
        topNeck.BackgroundColor3=Color3.fromRGB(0,0,0); topNeck.BackgroundTransparency=0
        topNeck.BorderSizePixel=0; topNeck.ClipsDescendants=true; topNeck.Active=false; topNeck.ZIndex=17
        mkCorner(topNeck,9)
        local topNeckGradient=Instance.new("UIGradient",topNeck)
        topNeckGradient.Name="AdaptiveCanBlend"
        topNeckGradient.Color=adaptiveCanColorSequence(currentColorScheme,false)
        topNeckGradient.Transparency=NumberSequence.new(0)
        topNeckGradient.Rotation=8
        local stackOutline=Instance.new("UIStroke",btnFrame)
        stackOutline.Name="StackMainStroke"
        stackOutline.Color=Color3.fromRGB(55, 55, 55)
        stackOutline.Transparency=0.25
        stackOutline.Thickness=1.8
        stackOutline.Enabled=true
        -- Sem efeito 3D / camada cinza: so o contorno principal
        local stackShadow=Instance.new("UIStroke",btnFrame)
        stackShadow.Name="StackSoftShadow"
        stackShadow.Color=Color3.fromRGB(0,0,0)
        stackShadow.Transparency=1
        stackShadow.Thickness=1
        stackShadow.Enabled=false
        local stackGlow=Instance.new("UIStroke",btnFrame)
        stackGlow.Name="StackActiveGlow"
        stackGlow.Color=Color3.fromRGB(120, 235, 255)
        stackGlow.Transparency=1
        stackGlow.Thickness=1
        stackGlow.Enabled=false


        -- Aluminum rims and vertical shine make each mobile control read as a soda can.
        for _,rimY in ipairs({4,77}) do
            local rim=Instance.new("Frame",stackSurface)
            rim.Size=UDim2.new(1,-14,0,5); rim.Position=UDim2.new(0,7,0,rimY)
            rim.BackgroundColor3=Color3.fromRGB(142,158,148); rim.BackgroundTransparency=0
            rim.BorderSizePixel=0; rim.ZIndex=15; mkCorner(rim,3)
            rim.Visible=false
        end
        local canShine=Instance.new("Frame",stackSurface)
        canShine.Size=UDim2.new(0,3,1,-22); canShine.Position=UDim2.new(0,9,0,11)
        canShine.BackgroundColor3=Color3.fromRGB(255,255,255); canShine.BackgroundTransparency=0.58
        canShine.BorderSizePixel=0; canShine.ZIndex=15; mkCorner(canShine,2)
        canShine.Visible=false
        -- Logo lives on the button root at a higher layer so the indented top can never cover it.
        local logoDisc=Instance.new("Frame",btnFrame)
        logoDisc.Name="FrontSevenDisc"
        logoDisc.Size=UDim2.new(0,28,0,28); logoDisc.Position=UDim2.new(0.5,-24,0,9)
        logoDisc.BackgroundColor3=Color3.fromRGB(40,40,40); logoDisc.BorderSizePixel=0; logoDisc.ZIndex=24; mkCorner(logoDisc,15)
        logoDisc.Visible=false
        local miniSeven=Instance.new("TextLabel",logoDisc)
        miniSeven.Name="MobileSevenLogo"
        miniSeven.Size=UDim2.new(1,0,1,0); miniSeven.BackgroundTransparency=1; miniSeven.Text="7"
        miniSeven.TextColor3=Color3.fromRGB(255,255,255); miniSeven.TextStrokeColor3=currentColorScheme.mainDark
        miniSeven.TextStrokeTransparency=0.35; miniSeven.Font=Enum.Font.GothamBold; miniSeven.TextSize=20
        miniSeven.Rotation=-8; miniSeven.ZIndex=25
        local miniUp=Instance.new("TextLabel",btnFrame)
        miniUp.Name="MiniUp"
        miniUp.Size=UDim2.new(0,30,0,22); miniUp.Position=UDim2.new(0.5,4,0,12)
        miniUp.BackgroundTransparency=1; miniUp.Text="UP"; miniUp.TextColor3=Color3.fromRGB(255,255,255)
        miniUp.Font=Enum.Font.GothamBold; miniUp.TextSize=12; miniUp.TextXAlignment=Enum.TextXAlignment.Left
        miniUp.Rotation=-5; miniUp.ZIndex=25
        miniUp.Visible=false
        local stackLabel=Instance.new("TextLabel",btnFrame)
        stackLabel.Name="StackFeatureLabel"
        stackLabel.Size=UDim2.new(1,-8,0,62); stackLabel.Position=UDim2.new(0,4,0,6)
        stackLabel.BackgroundColor3=Color3.fromRGB(45, 45, 45); stackLabel.BackgroundTransparency=1
        stackLabel.BorderSizePixel=0; stackLabel.Text=def.label; stackLabel.TextColor3=_G._K7StackText(false)
        stackLabel.TextStrokeColor3=Color3.fromRGB(0,0,0); stackLabel.TextStrokeTransparency=1
        stackLabel.TextSize=11; stackLabel.Font=Enum.Font.GothamBold; stackLabel.TextWrapped=true; stackLabel.LineHeight=1.15
        stackLabel.ZIndex=18; mkCorner(stackLabel,11)
        local labelStroke=Instance.new("UIStroke",stackLabel)
        labelStroke.Color=Color3.fromRGB(127, 127, 127); labelStroke.Transparency=1; labelStroke.Thickness=1
        labelStroke.Enabled=false
        local stateDot=Instance.new("Frame",btnFrame)
        stateDot.Size=UDim2.new(0,8,0,8); stateDot.Position=UDim2.new(1,-14,0,8)
        stateDot.BackgroundColor3=Color3.fromRGB(123, 123, 123); stateDot.BorderSizePixel=0; stateDot.ZIndex=19; mkCorner(stateDot,4)
        stateDot.Visible=false
        local stateDotStroke=Instance.new("UIStroke",stateDot); stateDotStroke.Color=Color3.fromRGB(233, 233, 233); stateDotStroke.Transparency=0.45
        stateDotStroke.Enabled=false
        local btnState = false
        -- Animacao de toque e aplicada por makeStackDraggable sem interferir no arraste.
        mobileScale.Scale=stackButtonScale
        stackWrappers[def.key] = btnFrame
        styleSingleMobileButton(btnFrame, State.mobileButtonShape)

        local function setOn(on)
            btnState = on
            btnFrame:SetAttribute("Active",on)
            local live=currentColorScheme
            local userBg = nil
            local stackBgColor = Color3.fromRGB(0, 0, 0)
            local sharedBlend = ColorSequence.new(Color3.fromRGB(0, 0, 0))
            stackGradient.Color=sharedBlend
            topNeckGradient.Color=sharedBlend
            local BLACK = Color3.fromRGB(0, 0, 0)
            local WHITE = Color3.fromRGB(255, 255, 255)
            local CYAN = BLACK
            local CYAN_SOFT = BLACK
            local CYAN_GLOW = Color3.fromRGB(35, 35, 35)
            local OFF_BG = BLACK
            btnFrame.BackgroundColor3 = BLACK
            btnFrame.BackgroundTransparency = 0
            btnFrame.TextColor3 = WHITE
            if on then
                stackGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, CYAN_SOFT),
                    ColorSequenceKeypoint.new(0.45, CYAN),
                    ColorSequenceKeypoint.new(1, CYAN_GLOW),
                })
                topNeckGradient.Color = stackGradient.Color
                -- 3D pop + cyan glow
                pcall(function()
                    stackGlow.Enabled = false
                    stackShadow.Enabled = false

                end)
            else
                stackGradient.Color = ColorSequence.new(OFF_BG)
                topNeckGradient.Color = ColorSequence.new(OFF_BG)
                -- Weak black shadow when off
                pcall(function()
                    stackGlow.Enabled = false
                    stackShadow.Enabled = false

                end)
            end
            stackSurface.BackgroundColor3 = BLACK
            stackSurface.BackgroundTransparency = 0
            topNeck.BackgroundColor3 = BLACK
            topNeck.BackgroundTransparency = 0
            stackOutline.Color = Color3.fromRGB(55, 55, 55)
            stackOutline.Transparency = on and 0.05 or 0.25
            stackOutline.Thickness = on and 2.4 or 1.3
            stateDot.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            stateDot.Size = on and UDim2.new(0,10,0,10) or UDim2.new(0,8,0,8)
            stateDot.Position = on and UDim2.new(1,-15,0,7) or UDim2.new(1,-14,0,8)
            stackLabel.BackgroundTransparency = 1
            stackLabel.TextColor3 = WHITE
            stackLabel.TextStrokeTransparency = on and 0.55 or 1
            stackLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            labelStroke.Transparency = 1
        end
        stackBtnRefs[def.key] = {setOn = setOn, setLabel = function(txt) stackLabel.Text = txt end}
        _G._K7StackRepaint = _G._K7StackRepaint or {}
        _G._K7StackRepaint[def.key] = function() setOn(btnState) end
        _G._K7RefreshStackColors = function()
            for _, fn in pairs(_G._K7StackRepaint or {}) do pcall(fn) end
        end
        setOn(btnState)
        if def.key == "aimbot" then
            stackLabel.Text = "BAT\nAIMBOT"
            setOn((_G.AceNormalAimbotOn == true) and (_G.AceBatAimbotV2On ~= true))
        end
        if def.key == "batV2" then
            stackLabel.Text = "BAT V2"
            setOn(State.batAimbotZombie == true)
        end
        if def.key == "antiBatTp" then
            stackLabel.Text = "ANTI\nBAT TP"
        end
        if def.key == "antiDesync" then
            stackLabel.Text = _G.AceTpBatStackLabel()
        end
        if def.key == "instaReset" then
            stackLabel.Text = "INSTA\nRESET"
        end

        local function onTap()
            if def.key == "tpDown" then
                task.spawn(function() if runTPDown then pcall(runTPDown) end; setOn(true); task.wait(0.12); setOn(false) end)
                return
            end
            if def.key == "drop" then
                task.spawn(function() pcall(runDrop) end)
                return
            end
            if def.key == "autoLeft" then
                if State.autoLeftEnabled then stopAutoLeft() else startAutoLeft() end
                setOn(State.autoLeftEnabled == true)
                requestSave()
                return
            end
            if def.key == "autoRight" then
                if State.autoRightEnabled then stopAutoRight() else startAutoRight() end
                setOn(State.autoRightEnabled == true)
                requestSave()
                return
            end
            if def.key == "carrySpeed" then
                toggleSpeed()
                return
            end
            if def.key == "autoCarry" then
                State.softStealEnabled = not State.softStealEnabled
                setOn(State.softStealEnabled)
                if toggleSetters.softSteal then toggleSetters.softSteal(State.softStealEnabled) end
                if State.softStealEnabled then
                    if autoGrabModule and autoGrabModule.startSoftStealScanner then autoGrabModule.startSoftStealScanner() end
                else
                    if autoGrabModule and autoGrabModule.stopSoftStealScanner then autoGrabModule.stopSoftStealScanner() end
                end
                requestSave()
                return
            end
            if def.key == "lagger" then
                if State.laggerMode==1 then setLaggerMode(0) else setLaggerMode(1) end
                return
            end
            if def.key == "laggerCarry" then
                if State.laggerMode==2 then setLaggerMode(0) else setLaggerMode(2) end
                return
            end
            if def.key == "instaReset" then
                if _G.AceRunInstaReset then task.spawn(_G.AceRunInstaReset) end
                return
            end
            if def.key == "antiBatTp" then
                if _G.AceToggleAntiBatTp then pcall(_G.AceToggleAntiBatTp) end
                setOn(AntiBatTp.enabled == true)
                requestSave()
                return
            end
            if def.key == "antiDesync" then
                if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
                    if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
                    return
                end
                if _G.AceToggleAntiDesyncAimbot then _G.AceToggleAntiDesyncAimbot() end
                setOn((_G.AceAntiDesyncAimbotOn == true) or (_G.AceFlowTpBatOn == true))
                requestSave()
                return
            end
            if def.key == "batV2" then
                if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
                    if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
                    return
                end
                if _G.AceToggleBypassAimbot then pcall(_G.AceToggleBypassAimbot) end
                setOn(State.batAimbotZombie == true)
                requestSave()
                return
            end
            if def.key == "aimbot" then
                if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
                    if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
                    return
                end
                if _G.AceToggleOldAimbot then pcall(_G.AceToggleOldAimbot) end
                local on = (_G.AceNormalAimbotOn == true)
                State.batAimbotToggled = (_G.AceNormalAimbotOn == true)
                setOn(on)
                if stackBtnRefs.aimbot then
                    stackBtnRefs.aimbot.setOn(on)
                    if stackBtnRefs.aimbot.setLabel then
                        stackBtnRefs.aimbot.setLabel("BAT\nAIMBOT")
                    end
                end
                requestSave()
                return
            end
            local ns = not btnState; setOn(ns)
            requestSave()
        end

        _G._K7StackTap = _G._K7StackTap or {}
        _G._K7StackTap[def.key] = onTap

        makeStackDraggable(btnFrame, onTap)
    end

    task.spawn(function()
        local lastAimbot=nil
        local lastBatV2=nil
        local lastAntiDesync=nil
        while gui and gui.Parent do
            local aimbotOn=(_G.AceNormalAimbotOn==true) and (_G.AceBatAimbotV2On~=true)
            local batV2On=(State.batAimbotZombie==true)
            local antiDesyncOn=_G.AceAntiDesyncAimbotOn==true
            if aimbotOn~=lastAimbot then
                lastAimbot=aimbotOn
                if stackBtnRefs.aimbot then
                    stackBtnRefs.aimbot.setOn(aimbotOn)
                    if stackBtnRefs.aimbot.setLabel then
                        stackBtnRefs.aimbot.setLabel("BAT\nAIMBOT")
                    end
                end
            end
            if batV2On~=lastBatV2 then
                lastBatV2=batV2On
                if stackBtnRefs.batV2 then stackBtnRefs.batV2.setOn(batV2On) end
            end
            if antiDesyncOn~=lastAntiDesync then
                lastAntiDesync=antiDesyncOn
                if stackBtnRefs.antiDesync then stackBtnRefs.antiDesync.setOn(antiDesyncOn) end
            end
            task.wait(0.1)
        end
    end)
    pcall(loadStackPositionsNow)
    if stackBtnRefs.autoCarry then stackBtnRefs.autoCarry.setOn(State.softStealEnabled == true) end

    -- ============================================================
    -- SAVE/LOAD CONFIG (updated with softSteal)
    -- ============================================================
    saveConfig = function(silent)
        local success = false
        pcall(function()
            local btnPositions = {}
            for key, wrapper in pairs(stackWrappers) do
                if wrapper and wrapper.Position then
                    btnPositions[key] = { XS = wrapper.Position.X.Scale, X = wrapper.Position.X.Offset, YS = wrapper.Position.Y.Scale, Y = wrapper.Position.Y.Offset }
                end
            end
            pcall(saveStackPositionsNow)
            local cfg = {
                version = CONFIG_VERSION,
                theme = "sevenup_green",
                normalSpeed = State.normalSpeed,
                carrySpeed = State.carrySpeed,
                laggerSpeed = State.laggerSpeed,
                laggerCarrySpeed = State.laggerCarrySpeed,
                speedToggled = State.speedToggled,
                laggerMode = State.laggerMode,
                stealRadius = Steal.StealRadius,
                semiStopPercent = State.semiStopPercent,
                semiDelayRadius = State.semiDelayRadius,
                autoStealEnabled = Steal.AutoStealEnabled,
                selectedStealMode = autoGrabModule and autoGrabModule.getMode() or "Normal",
                stealRadii = (function()
                    if autoGrabModule then
                        local radii = autoGrabModule.getRadii()
                        if type(radii) == "table" then
                            local mode = autoGrabModule.getMode() or "Normal"
                            radii[mode] = tonumber(Steal.StealRadius) or radii[mode]
                            return {
                                Normal = tonumber(radii.Normal) or 60,
                                Semi   = tonumber(radii.Semi) or 60
                            }
                        end
                    end
                    return { Normal = 60, Semi = 60 }
                end)(),
                uiScale = _G._K7MenuScale or (uiScaleObj and uiScaleObj.Scale) or 1,
                buttonScale = stackButtonScale,
                mobileButtonShape = State.mobileButtonShape,
                autoGrabScale = autoGrabModule and autoGrabModule.getScale() or 1,
                autoGrabStretch = autoGrabModule and autoGrabModule.getStretch and autoGrabModule.getStretch() or 0,
                stackButtonsHidden = State.stackButtonsHidden,
                stackButtonsLocked = State.stackButtonsLocked,
                speedKey = Keys.speed and Keys.speed.Name or "Q",
                guiHideKey = Keys.guiHide and Keys.guiHide.Name or "LeftControl",
                dropKey = Keys.drop and Keys.drop.Name or "H",
                laggerKey = Keys.lagger and Keys.lagger.Name or "Unknown",
                tpDownKey = Keys.tpDown and Keys.tpDown.Name or "Unknown",
                aimbotKey = Keys.aimbot and Keys.aimbot.Name or "Unknown",
                autoLeftKey = Keys.autoLeft and Keys.autoLeft.Name or "L",
                autoRightKey = Keys.autoRight and Keys.autoRight.Name or "R",
                antiDesyncKey = Keys.antiDesync and Keys.antiDesync.Name or "V",
                batV2Key = Keys.batV2 and Keys.batV2.Name or "Unknown",
                antiBatTpKey = Keys.antiBatTp and Keys.antiBatTp.Name or "Unknown",
                instaResetKey = Keys.instaReset and Keys.instaReset.Name or "Unknown",
                batAimbotKey = Keys.batAimbot and Keys.batAimbot.Name or "Unknown",
                safeMode = antiKickEnabled,
                normalAimbotSpeed = AIMBOT_SPEED,
                laggerAimbotSpeed = LAGGER_AIMBOT_SPEED,
                selectedAnimationPack = selectedAnimationPack,
                infJump = State.infJumpEnabled,
                antiRagdoll = State.antiRagdollEnabled,
                antiRagdollVersion = State.antiRagdollVersion,
                medusaCounter = State.medusaCounterEnabled,
                batCounter = State.batCounterEnabled,
                ragdollSteal = State.ragdollStealEnabled,
                ragdollCountdown = State.ragdollCountdownEnabled,
                autoSwing = State.autoSwingEnabled,
                informationE01 = State.informationE01Enabled,
                batAimbot = State.batAimbotToggled,
                antiLagEnabled = State.antiLagEnabled,
                saturatedColorsEnabled = State.saturatedColorsEnabled,
                stretchedResEnabled = State.stretchedResEnabled,
                normalFOV = _G._VezyFOV or 70,
                removeAccessories = State.removeAcc,
                tryardAnimEnabled = State.tryardAnimEnabled,
                introEnabled = State.introEnabled,
                guiVisible = State.guiVisible,
                buttonPositions = btnPositions,
                menuButtonPos = (function()
                    local btn = _G._K7ToggleBtn
                    if btn and btn.Position then
                        return { XS = btn.Position.X.Scale, X = btn.Position.X.Offset,
                                 YS = btn.Position.Y.Scale, Y = btn.Position.Y.Offset }
                    end
                    return State.menuButtonPos
                end)(),
                menuPos = (function()
                    local f = _G._K7MainFrame
                    local pos = _G._K7GetMenuRestPosition and _G._K7GetMenuRestPosition() or (f and f.Position)
                    if pos then
                        return { XS = pos.X.Scale, X = pos.X.Offset,
                                 YS = pos.Y.Scale, Y = pos.Y.Offset }
                    end
                    return nil
                end)(),
                autoGrabPos = (function()
                    local f = _G._K7AutoGrabFrame
                    if f and f.Position then
                        return { XS = f.Position.X.Scale, X = f.Position.X.Offset,
                                 YS = f.Position.Y.Scale, Y = f.Position.Y.Offset }
                    end
                    return nil
                end)(),
                autoTPEnabled = State.autoTPEnabled,
                autoTPHeight = State.autoTPHeight,
                dropType = currentDropType,

                stretchValue = State.stretchValue,
                stretchFOV = State.stretchFOV,
                batAimbotZombie = State.batAimbotZombie,
                batV2Bypass = State.batV2Bypass ~= false,
                aimbotV2Speed = State.aimbotV2Speed,
                aimbotV2LaggerSpeed = State.aimbotV2LaggerSpeed,
                aimbotV2TPDistance = _G.AceBatAimbotV2TPDistance,
                autoStealMode = State.autoStealMode,
                aimbotMode = State.aimbotMode,
                tpBatMode = State.tpBatMode,
                instaResetVersion = State.instaResetVersion,
                antiTpBatMode = State.antiTpBatMode,
                antiBatEnabled = State.antiBatEnabled == true,
                bodyLockEnabled = State.bodyLockEnabled == true,
                bodyLockRadius = State.bodyLockRadius,
                bgImage = State.bgImage,
                espEnabled = State.espEnabled,
                showTrackerEnabled = State.showTrackerEnabled,
                trackerColor = State.trackerColor,
                skyTheme = State.skyTheme,
                rainbowToolsEnabled = State.rainbowToolsEnabled == true,
                transparentToolsEnabled = State.transparentToolsEnabled == true,
                customToolsEnabled = State.customToolsEnabled == true,
                customSoundsEnabled = State.customSoundsEnabled == true,
                customToolSkins = State.customToolSkins,
                avatarChanger = State.avatarChanger,
                antiDesyncAimbotEnabled = _G.AceAntiDesyncAimbotOn == true,
                antiDieEnabled = State.antiDieEnabled,
                antiFlingShieldEnabled = State.antiFlingShieldEnabled,
                headlessEnabled = State.headlessEnabled,
                korbloxEnabled = State.korbloxEnabled,
                customSkinEnabled = State.customSkinEnabled,
                customSkinVariant = State.customSkinVariant,
                uiColorTheme = State.uiColorTheme,
                userColors = (function()
                    local t = {}
                    local uc = _G._K7UserColors or {}
                    for _, k in ipairs({"letters","bottom","btnText","btnBg","bar"}) do
                        local c = uc[k]
                        if typeof(c) == "Color3" then
                            t[k] = {math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5)}
                        end
                    end
                    return t
                end)(),
                -- Soft Steal
                softStealEnabled = State.softStealEnabled,
                softStealRadius = State.softStealRadius,
                softStealSpeed = State.softStealSpeed,
            }
            -- skip identical writes (used by the 2s auto save)
            local encodedNow = nil
            pcall(function() encodedNow = HttpService:JSONEncode(cfg) end)
            if silent and encodedNow and encodedNow == _G._K7LastSavedCfg then
                success = true
                return
            end
            success = saveConfigWithRetry(cfg)
            if success and encodedNow then _G._K7LastSavedCfg = encodedNow end
        end)
        if success then
            if not silent then pcall(_G._VezyFlashSave, true) end
        else
            pcall(_G._VezyFlashSave, false)
            warn("[MAY duels] Config save FAILED!")
        end
        return success
    end

    loadConfig = function(importedRaw)
        local raw = importedRaw
        local usedBackup = false
        if not raw and _isfile(CONFIG_FILE) then raw = _readfile(CONFIG_FILE) end
        if not raw or raw == "" then
            if _isfile(CONFIG_BACKUP) then
                raw = _readfile(CONFIG_BACKUP)
                usedBackup = true
                if raw and raw ~= "" then print("[MAY duels] Loaded config from backup") end
            end
        end
        if not raw or raw == "" then
            print("[MAY duels] No valid config file found, using defaults")
            return false
        end
        local ok, decErr = pcall(HttpService.JSONDecode, HttpService, raw)
        if (not ok or not decErr) and not usedBackup and not importedRaw then
            warn("[MAY duels] Main config corrupt, trying backup...")
            local backupRaw = nil
            if _isfile(CONFIG_BACKUP) then backupRaw = _readfile(CONFIG_BACKUP) end
            if backupRaw and backupRaw ~= "" then
                ok, decErr = pcall(HttpService.JSONDecode, HttpService, backupRaw)
                if ok and decErr then
                    print("[MAY duels] Recovered from backup successfully")
                    pcall(function() _delfile(CONFIG_FILE) end)
                end
            end
        end
        if not ok or not decErr then
            if not usedBackup and not importedRaw then pcall(function() _delfile(CONFIG_FILE) end) end
            warn("[MAY duels] Config unrecoverable, using defaults")
            return false
        end
        if decErr.version ~= CONFIG_VERSION then
            warn("[MAY duels] Config version differs — loading tolerantly")
        end

        local function applyNumber(key, targetVar, uiBox)
            if decErr[key] then
                targetVar = decErr[key]
                if uiBox and uiBox.Text then uiBox.Text = tostring(decErr[key]) end
            end
            return targetVar
        end

        local keepLiveSpeedValues = not importedRaw
            and not State._initialConfigSettled
            and (State._speedEditRevision or 0) > 0
        if not keepLiveSpeedValues then
            State.normalSpeed = applyNumber("normalSpeed", State.normalSpeed, normalBox)
            State.carrySpeed = applyNumber("carrySpeed", State.carrySpeed, carryBox)
            State.laggerSpeed = applyNumber("laggerSpeed", State.laggerSpeed, laggerBox)
            State.laggerCarrySpeed = applyNumber("laggerCarrySpeed", State.laggerCarrySpeed, laggerCarryBox)
            State._prevCarry = State.carrySpeed
        end
        Steal.StealRadius = applyNumber("stealRadius", Steal.StealRadius, stealRadBox)
        if decErr.autoStealEnabled ~= nil then
            Steal.AutoStealEnabled = decErr.autoStealEnabled
            if autoGrabModule then autoGrabModule.setEnabled(Steal.AutoStealEnabled) end
            if toggleSetters["autoSteal"] then pcall(toggleSetters["autoSteal"], Steal.AutoStealEnabled) end
        end
        if decErr.stealRadii and type(decErr.stealRadii) == "table" and autoGrabModule then
            local radii = autoGrabModule.getRadii()
            if radii then
                if decErr.stealRadii.Normal ~= nil then
                    radii.Normal = tonumber(decErr.stealRadii.Normal) or radii.Normal or 60
                end
                if decErr.stealRadii.Semi ~= nil then
                    radii.Semi = tonumber(decErr.stealRadii.Semi) or radii.Semi or 10
                end
            end
        end
        if decErr.selectedStealMode then
            local mode = decErr.selectedStealMode
            if mode~="Normal" and mode~="Semi" then mode="Normal" end
            if autoGrabModule then autoGrabModule.setMode(mode) end
            local radii = autoGrabModule and autoGrabModule.getRadii() or {Normal=60, Semi=60}
            Steal.StealRadius = radii[mode] or Steal.StealRadius
            if autoGrabModule then autoGrabModule.setRadius(Steal.StealRadius) end
            if stealRadBox then stealRadBox.Text = tostring(Steal.StealRadius) end
            if _G._K7StealModeSetUI then pcall(_G._K7StealModeSetUI, mode) end
        end
        if decErr.uiScale then
            local v = math.clamp(math.floor((tonumber(decErr.uiScale) or 1)*10+0.5)/10, 0.4, 1.5)
            if _G._K7ApplyMenuScale then
                pcall(_G._K7ApplyMenuScale, v, false)
            else
                _G._K7MenuScale = v
                _G._K7MenuScaleManual = true
                if uiScaleObj then uiScaleObj.Scale = v end
                if uiScaleBox then uiScaleBox.Text = string.format("%.1f", v) end
                if _G._K7FitMenuToScreen then pcall(_G._K7FitMenuToScreen) end
            end
        end
        if decErr.buttonScale ~= nil then
            local loadedButtonScale=applyStackButtonScale(decErr.buttonScale)
            if buttonScaleBox then buttonScaleBox.Text=string.format("%.1f",loadedButtonScale) end
        end
        if decErr.mobileButtonShape == "Can" or decErr.mobileButtonShape == "Circle" or decErr.mobileButtonShape == "Square" then
            applyMobileButtonShape(decErr.mobileButtonShape)
            if _G._K7RefreshMobileButtonShape then pcall(_G._K7RefreshMobileButtonShape) end
        end
        if decErr.autoGrabScale ~= nil and autoGrabModule then
            autoGrabModule.setScale(decErr.autoGrabScale)
        end
        if decErr.autoGrabStretch ~= nil and autoGrabModule and autoGrabModule.setStretch then
            pcall(autoGrabModule.setStretch, decErr.autoGrabStretch)
            if _G._K7SyncAutoGrabStretch then pcall(_G._K7SyncAutoGrabStretch) end
        end
        if decErr.normalFOV then
            _G._VezyFOV = decErr.normalFOV
            pcall(function() workspace.CurrentCamera.FieldOfView = _G._VezyFOV end)
        end
        if decErr.autoTPEnabled ~= nil then State.autoTPEnabled = decErr.autoTPEnabled end
            if decErr.autoTPHeight then
                State.autoTPHeight = decErr.autoTPHeight
                if autoTPHeightBox then autoTPHeightBox.Text = tostring(State.autoTPHeight) end
            end

        if decErr.dropType then
            currentDropType = DROP_TYPES.JUMP
            currentDropType = DROP_TYPES.JUMP
        end

        if decErr.uiColorTheme == "Red" or decErr.uiColorTheme == "Green" then
            State.uiColorTheme = decErr.uiColorTheme
            _G._K7ThemeMode = State.uiColorTheme
        end
        local loadedSkinVariant = tonumber(decErr.customSkinVariant)
        if loadedSkinVariant == 1 or loadedSkinVariant == 2 then
            State.customSkinVariant = loadedSkinVariant
            syncCustomSkinVariant(loadedSkinVariant)
        end
        -- Always use the fixed hub artwork (ignore old saved skins)
        State.bgImage = "rbxassetid://137970714521556"
        changeDuelScriptBackground(State.bgImage)
        if _G._K7RefreshBgPicker then pcall(_G._K7RefreshBgPicker) end
        local function reapplyBg()
            State.bgImage = "rbxassetid://137970714521556"
            changeDuelScriptBackground("rbxassetid://137970714521556")
            pcall(function()
                local bg = mainOuter and mainOuter:FindFirstChild("BgImage")
                if bg then
                    bg.Image = "rbxassetid://137970714521556"
                    bg.ImageTransparency = 0
                    bg.BackgroundTransparency = 1
                    bg.Visible = true
                    local g = bg:FindFirstChildOfClass("UIGradient")
                    if g then g:Destroy() end
                end
            end)
            if _G._K7RefreshBgPicker then pcall(_G._K7RefreshBgPicker) end
        end
        reapplyBg()
        task.delay(1.5, reapplyBg)
        task.delay(3.5, reapplyBg)

        if type(decErr.userColors) == "table" then
            _G._K7UserColors = _G._K7UserColors or {}
            for k, v in pairs(decErr.userColors) do
                if type(v) == "table" and #v == 3 then
                    _G._K7UserColors[k] = Color3.fromRGB(v[1], v[2], v[3])
                end
            end
            pcall(function()
                local base = COLOR_SCHEMES[State.bgImage] or COLOR_SCHEMES["rbxassetid://102557909116203"]
                updateAllColors(get7UpThemeScheme(base, _G._K7ThemeMode))
                if _G._K7RefreshStackColors then _G._K7RefreshStackColors() end
            end)
        end

        local bools = {
            stackButtonsHidden="stackButtonsHidden", stackButtonsLocked="stackButtonsLocked",
            infJump="infJumpEnabled", antiRagdoll="antiRagdollEnabled",
            medusaCounter="medusaCounterEnabled", batCounter="batCounterEnabled",
            ragdollSteal="ragdollStealEnabled", ragdollCountdown="ragdollCountdownEnabled",
            autoSwing="autoSwingEnabled", informationE01="informationE01Enabled",
            batAimbot="batAimbotToggled", antiLagEnabled="antiLagEnabled",
            saturatedColorsEnabled="saturatedColorsEnabled",
            stretchedResEnabled="stretchedResEnabled",
            removeAccessories="removeAcc", tryardAnimEnabled="tryardAnimEnabled",
            introEnabled="introEnabled", guiVisible="guiVisible",
            speedToggled="speedToggled", autoTPEnabled="autoTPEnabled",

            batAimbotZombie="batAimbotZombie",
            batV2Bypass="batV2Bypass",
            headlessEnabled="headlessEnabled",
            korbloxEnabled="korbloxEnabled",
            customSkinEnabled="customSkinEnabled",
            -- Soft Steal
            softStealEnabled="softStealEnabled",
        }
        for cfgKey, stateKey in pairs(bools) do
            if decErr[cfgKey] ~= nil then State[stateKey] = decErr[cfgKey] end
        end
        if tonumber(decErr.aimbotV2Speed) then State.aimbotV2Speed = tonumber(decErr.aimbotV2Speed) end
        if tonumber(decErr.aimbotV2LaggerSpeed) then State.aimbotV2LaggerSpeed = tonumber(decErr.aimbotV2LaggerSpeed) end
        if tonumber(decErr.aimbotV2TPDistance) then _G.AceBatAimbotV2TPDistance = tonumber(decErr.aimbotV2TPDistance) end
        if toggleSetters["informationE01"] then
            pcall(toggleSetters["informationE01"], State.informationE01Enabled ~= false)
        end
        if decErr.antiRagdollVersion == "V1" or decErr.antiRagdollVersion == "V2" then
            State.antiRagdollVersion = decErr.antiRagdollVersion
            if _G._K7RefreshRagdollVersionButtons then pcall(_G._K7RefreshRagdollVersionButtons) end
        end

        if decErr.stretchValue then State.stretchValue = decErr.stretchValue end
        if decErr.stretchFOV then State.stretchFOV = decErr.stretchFOV end
        if decErr.autoStealMode then State.autoStealMode = decErr.autoStealMode end
        if decErr.aimbotMode == "old" or decErr.aimbotMode == "new" then State.aimbotMode = decErr.aimbotMode end
        if decErr.tpBatMode == "v1" or decErr.tpBatMode == "v2" or decErr.tpBatMode == "v3" then State.tpBatMode = decErr.tpBatMode else State.tpBatMode = "v1" end
        if tonumber(decErr.instaResetVersion) then State.instaResetVersion = math.clamp(tonumber(decErr.instaResetVersion), 1, 2) end
        if decErr.antiTpBatMode == "v1" or decErr.antiTpBatMode == "v2" or decErr.antiTpBatMode == "v3" or decErr.antiTpBatMode == "v4" then State.antiTpBatMode = decErr.antiTpBatMode else State.antiTpBatMode = "v1" end
        -- Reaplica modos salvos (save-config + auto-save) nos motores e na UI
        pcall(function()
            if _G.AceSetTpBatMode then _G.AceSetTpBatMode(State.tpBatMode or "v1") end
            if _G.AceSetAntiTpBatMode then _G.AceSetAntiTpBatMode(State.antiTpBatMode or "v1") end
            if _G.AceSetInstaResetVersion then _G.AceSetInstaResetVersion(State.instaResetVersion or 1) end
            if _G._K7SyncAimbotVersionBar then _G._K7SyncAimbotVersionBar() end
            if _G._K7SyncTpBatModeBox then _G._K7SyncTpBatModeBox() end
            if _G._K7SyncAntiTpBatModeBox then _G._K7SyncAntiTpBatModeBox() end
            if _G._K7SyncInstaResetBar then _G._K7SyncInstaResetBar() end
            if _G._K7SyncAimbotModeBox then _G._K7SyncAimbotModeBox() end
        end)
        State.antiBatEnabled = decErr.antiBatEnabled == true
        if _G.AmbitiousAntiBat then pcall(function() _G.AmbitiousAntiBat.setEnabled(State.antiBatEnabled) end) end
        if toggleSetters then
            if toggleSetters["antiBat"] then pcall(toggleSetters["antiBat"], State.antiBatEnabled) end
        end
        if decErr.bodyLockRadius then State.bodyLockRadius = tonumber(decErr.bodyLockRadius) or State.bodyLockRadius end
        if decErr.bodyLockEnabled ~= nil then
            State.bodyLockEnabled = decErr.bodyLockEnabled == true
            if _G.AceSetBodyLock then pcall(_G.AceSetBodyLock, State.bodyLockEnabled) end
        end
        if decErr.laggerMode ~= nil then State.laggerMode = decErr.laggerMode end
        local keyMap = {
            speedKey="speed",
            guiHideKey="guiHide", dropKey="drop", laggerKey="lagger",
            tpDownKey="tpDown", aimbotKey="aimbot",
            autoLeftKey="autoLeft", autoRightKey="autoRight",
            antiDesyncKey="antiDesync",
            batV2Key="batV2", antiBatTpKey="antiBatTp",
            instaResetKey="instaReset", batAimbotKey="batAimbot",
        }
        for cfgKey, stateKey in pairs(keyMap) do
            if decErr[cfgKey] then
                local kc = Enum.KeyCode[decErr[cfgKey]]
                if kc then
                    Keys[stateKey] = kc
                    if keybindBtnRefs[stateKey] then keybindBtnRefs[stateKey].Text = getKeyDisplayName(kc) end
                end
            end
        end

        if type(decErr.menuPos) == "table" then
            pcall(function()
                mainOuter.Position = UDim2.new(decErr.menuPos.XS or 0, decErr.menuPos.X or 0,
                                               decErr.menuPos.YS or 0, decErr.menuPos.Y or 0)
            end)
        end
        if _G._K7SetMenuVisible then
            pcall(_G._K7SetMenuVisible, State.guiVisible)
        else
            mainOuter.Visible = State.guiVisible
        end
        if not _G._K7IntroHidingUI then
            for _, wrapper in pairs(stackWrappers) do wrapper.Visible = not State.stackButtonsHidden end
        end
        if hideButtonsSetter then hideButtonsSetter(State.stackButtonsHidden) end
        if lockButtonsSetter then lockButtonsSetter(State.stackButtonsLocked) end
        State.uiLocked = State.stackButtonsLocked == true
        _G._K7UILocked = State.stackButtonsLocked == true

        if type(decErr.autoGrabPos) == "table" and _G._K7AutoGrabFrame then
            pcall(function()
                _G._K7AutoGrabFrame.Position = UDim2.new(decErr.autoGrabPos.XS or 0, decErr.autoGrabPos.X or 0,
                                                         decErr.autoGrabPos.YS or 0, decErr.autoGrabPos.Y or 0)
            end)
        end

        if State.laggerMode == 0 then
            if carryBox then carryBox.Text = tostring(State.carrySpeed) end
        elseif State.laggerMode == 1 then
            if carryBox then carryBox.Text = tostring(State.carrySpeed) end
        elseif State.laggerMode == 2 then
            if carryBox then carryBox.Text = tostring(State.carrySpeed) end
        end
        if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(State.speedToggled) end
        if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(State.laggerMode == 1) end
        if stackBtnRefs.laggerCarry then stackBtnRefs.laggerCarry.setOn(State.laggerMode == 2) end
        if stackBtnRefs.aimbot then
            stackBtnRefs.aimbot.setOn(State.batAimbotToggled == true)
            if stackBtnRefs.aimbot.setLabel then
                stackBtnRefs.aimbot.setLabel("BAT\nAIMBOT")
            end
        end
        if stackBtnRefs.batV2 then
            stackBtnRefs.batV2.setOn(State.batAimbotZombie == true)
            if stackBtnRefs.batV2.setLabel then stackBtnRefs.batV2.setLabel("BAT V2") end
        end
        if stackBtnRefs.antiDesync and stackBtnRefs.antiDesync.setLabel then
            stackBtnRefs.antiDesync.setLabel(_G.AceTpBatStackLabel())
        end
        if stackBtnRefs.autoCarry then stackBtnRefs.autoCarry.setOn(State.softStealEnabled == true) end

        if decErr.espEnabled ~= nil then
            State.espEnabled=decErr.espEnabled==true
            if State.espEnabled then
                startPlayerESP()
                if BoxedESPOptions then BoxedESPOptions.box = true end
            else
                stopPlayerESP()
                if BoxedESPOptions then BoxedESPOptions.box = false end
            end
            refreshBoxedESP()
            if toggleSetters["esp"] then pcall(toggleSetters["esp"],State.espEnabled) end
        end
        if decErr.showTrackerEnabled ~= nil then State.showTrackerEnabled=decErr.showTrackerEnabled==true end
        BoxedESPOptions.tracker=State.showTrackerEnabled
        if type(decErr.trackerColor)=="table" and #decErr.trackerColor==3 then State.trackerColor=decErr.trackerColor end
        local tc=State.trackerColor or {230,230,230}; BoxedESPOptions.trackerColor=Color3.fromRGB(tc[1] or 230,tc[2] or 230,tc[3] or 230)
        if _G._K7TrackerColorPreview then _G._K7TrackerColorPreview.BackgroundColor3=BoxedESPOptions.trackerColor end
        refreshBoxedESP()
        if type(decErr.customToolSkins)=="table" then
            for cat,key in pairs(decErr.customToolSkins) do State.customToolSkins[cat]=key end
            _G.AmbitiousCustomToolSkins=State.customToolSkins
        end
        if type(decErr.avatarChanger)=="table" then
            State.avatarChanger=State.avatarChanger or {}
            for name,saved in pairs(decErr.avatarChanger) do
                local entry=State.avatarChanger[name] or {}
                entry.enabled=saved.enabled==true
                entry.savedId=tonumber(saved.savedId)
                entry.savedName=tostring(saved.savedName or "")
                State.avatarChanger[name]=entry
                if entry._menuLabel then entry._menuLabel.Text=entry.savedName~="" and (name..": "..entry.savedName) or name end
                if toggleSetters["avatar_"..name] then pcall(toggleSetters["avatar_"..name],entry.enabled) end
            end
            if _G._K7AvatarChangerReapply then pcall(_G._K7AvatarChangerReapply,true) end
        end
        for _,def in ipairs({
            {"rainbowToolsEnabled","rainbowTools","AmbitiousRainbowToolsEnabled","AmbitiousRainbowTools"},
            {"transparentToolsEnabled","transparentTools","AmbitiousTransparentToolsEnabled","AmbitiousTransparentTools"},
            {"customToolsEnabled","customTools","AmbitiousCustomToolsEnabled","AmbitiousCustomTools"},
            {"customSoundsEnabled","customSounds","AmbitiousCustomSoundsEnabled","AmbitiousCustomSounds"},
        }) do
            if decErr[def[1]]~=nil then State[def[1]]=decErr[def[1]]==true end
            _G[def[3]]=State[def[1]]
            local api=_G[def[4]]; if api and api.setEnabled then pcall(api.setEnabled,State[def[1]]) end
            if toggleSetters[def[2]] then pcall(toggleSetters[def[2]],State[def[1]]) end
        end
        if decErr.skyTheme and decErr.skyTheme ~= "" then
            State.skyTheme = decErr.skyTheme; skyTheme = State.skyTheme
            pcall(applyCustomSky, State.skyTheme)
        end
        if decErr.antiDieEnabled ~= nil then
            State.antiDieEnabled = decErr.antiDieEnabled
            if State.antiDieEnabled then
                task.delay(1.0, function() pcall(startAntiDie) end)
            end
            if toggleSetters["antiDie"] then pcall(toggleSetters["antiDie"], State.antiDieEnabled) end
        end
        if decErr.antiFlingShieldEnabled ~= nil then
            State.antiFlingShieldEnabled = decErr.antiFlingShieldEnabled == true
            if State.antiFlingShieldEnabled then
                task.delay(1.0, function() pcall(startAntiFlingShield) end)
            else
                pcall(stopAntiFlingShield)
            end
            if toggleSetters["antiFlingShield"] then pcall(toggleSetters["antiFlingShield"], State.antiFlingShieldEnabled) end
        end
        if decErr.safeMode ~= nil then
            antiKickEnabled = decErr.safeMode == true
            if toggleSetters["safeMode"] then pcall(toggleSetters["safeMode"], antiKickEnabled) end
        end
        if decErr.normalAimbotSpeed then AIMBOT_SPEED = decErr.normalAimbotSpeed end
        if decErr.laggerAimbotSpeed then LAGGER_AIMBOT_SPEED = decErr.laggerAimbotSpeed end
        if _G.AceRefreshAimbotSpeedBoxes then pcall(_G.AceRefreshAimbotSpeedBoxes) end
        do
            local fromCfg = (type(decErr.selectedAnimationPack) == "string") and decErr.selectedAnimationPack or nil
            local fromDisk = _K7LoadAnimPackFile and _K7LoadAnimPackFile() or nil
            local fromMem = _G._K7SelectedAnimationPack or selectedAnimationPack
            local pack = nil
            -- Prefer any non-OFF source; disk is trusted if cfg says OFF but file has a pack
            for _, cand in ipairs({ fromCfg, fromDisk, fromMem }) do
                local r = _K7ResolvePackName and _K7ResolvePackName(cand) or cand
                if r and r ~= "OFF" then pack = r; break end
            end
            if not pack then
                pack = (_K7ResolvePackName and _K7ResolvePackName(fromCfg)) or fromCfg or "OFF"
            end
            if pack and pack ~= "" then
                selectedAnimationPack = pack
                _G._K7SelectedAnimationPack = pack
                State.tryardAnimEnabled = pack ~= "OFF"
                pcall(function() if _K7SaveAnimPackFile then _K7SaveAnimPackFile(pack) end end)
                if _G._K7AnimPackRefreshRow then pcall(_G._K7AnimPackRefreshRow) end
                if pack ~= "OFF" then
                    task.delay(0.5, function()
                        pcall(function()
                            if _G._K7SetAnimationPack then _G._K7SetAnimationPack(pack)
                            else applyAnimationPack(pack) end
                        end)
                    end)
                    task.delay(2.0, function()
                        pcall(applySavedAnimationPackToCharacter, LP.Character)
                    end)
                end
            end
        end
        if decErr.introEnabled ~= nil then
            State.introEnabled = decErr.introEnabled == true
        end
        _introEnabled = State.introEnabled ~= false
        if toggleSetters["introEnabled"] then pcall(toggleSetters["introEnabled"], State.introEnabled ~= false) end
        if decErr.antiDesyncAimbotEnabled == true then
            task.delay(1.5, function() pcall(function() _G.AceStartAntiDesyncAimbot() end) end)
        end

        -- Soft Steal config loading
        if decErr.softStealEnabled ~= nil then
            State.softStealEnabled = decErr.softStealEnabled
            if State.softStealEnabled and autoGrabModule and autoGrabModule.startSoftStealScanner then
                autoGrabModule.startSoftStealScanner()
            elseif not State.softStealEnabled and autoGrabModule and autoGrabModule.stopSoftStealScanner then
                autoGrabModule.stopSoftStealScanner()
            end
            if toggleSetters["softSteal"] then pcall(toggleSetters["softSteal"], State.softStealEnabled) end
        end
        if decErr.softStealSpeed ~= nil and type(decErr.softStealSpeed)=="number" then
            State.softStealSpeed = decErr.softStealSpeed
            if softStealSpeedBox then softStealSpeedBox.Text = tostring(State.softStealSpeed) end
        end
        -- New V3 settings; old semiStealRadius configs are accepted but no longer shown.
        if type(decErr.semiStopPercent)=="number" then
            State.semiStopPercent = math.clamp(decErr.semiStopPercent, 1, 100)
        end
        if type(decErr.semiDelayRadius)=="number" then
            State.semiDelayRadius = math.clamp(decErr.semiDelayRadius, 0.1, 500)
        elseif type(decErr.semiStealRadius)=="number" then
            State.semiDelayRadius = math.clamp(decErr.semiStealRadius, 0.1, 500)
        end
        if _G.K7SemiSteal then
            _G.K7SemiSteal.autoGrabStopPercent = State.semiStopPercent
            _G.K7SemiSteal.autoGrabSetDelayRadius = State.semiDelayRadius
        end
        if _G._K7SyncSemiV3Settings then pcall(_G._K7SyncSemiV3Settings) end
        if decErr.softStealRadius ~= nil and type(decErr.softStealRadius)=="number" then
            State.softStealRadius = math.clamp(decErr.softStealRadius, 1, 200)
            if softStealRadiusBox then softStealRadiusBox.Text = tostring(State.softStealRadius) end
        end

        if State.antiLagEnabled then enableAntiLag() else disableAntiLag() end
        if State.stretchedResEnabled then enableStretchRez() else disableStretchRez() end
        if State.removeAcc then if _G._removeAccStart then _G._removeAccStart() end else if _G._removeAccStop then _G._removeAccStop() end end
        if State.tryardAnimEnabled then startTryardAnim() end
        if State.aimbotMode=="new" then
            if State.batAimbotToggled then State.batAimbotToggled=false end
        elseif State.batAimbotZombie then
            State.batAimbotZombie = false
        end
        if State.batAimbotToggled then startBatAimbot() else stopBatAimbot() end
        if _G._K7SyncAimbotModeBox then pcall(_G._K7SyncAimbotModeBox) end
        task.spawn(function()
            task.wait(0.35)
            if State.batCounterEnabled then
                pcall(stopBatCounter)
                pcall(startBatCounter)
            else
                pcall(stopBatCounter)
            end
            if State.medusaCounterEnabled then
                pcall(stopMedusaCounter)
                pcall(function() setupMedusaCounter(LP.Character) end)
            else
                pcall(stopMedusaCounter)
            end
            if State.antiRagdollEnabled then
                pcall(stopAntiRagdollNew)
                pcall(startAntiRagdollNew)
            else
                pcall(stopAntiRagdollNew)
            end
            if State.antiLagEnabled then
                pcall(disableAntiLag)
                pcall(enableAntiLag)
            else
                pcall(disableAntiLag)
            end

            if State.batAimbotZombie and State.aimbotMode=="new" then pcall(startZombieBatAimbot) end
            if State.stretchedResEnabled then pcall(enableStretchRez) end
            if State.saturatedColorsEnabled then
                pcall(enableSaturatedColors)
            else
                pcall(clearSaturatedColors)
            end
            if toggleSetters["autoSwing"] then pcall(toggleSetters["autoSwing"], State.autoSwingEnabled == true) end
            if toggleSetters["batCounter"] then pcall(toggleSetters["batCounter"], State.batCounterEnabled == true) end
            if toggleSetters["medusaCounter"] then pcall(toggleSetters["medusaCounter"], State.medusaCounterEnabled == true) end
            if toggleSetters["ragdollSteal"] then pcall(toggleSetters["ragdollSteal"], State.ragdollStealEnabled == true) end
            if toggleSetters["ragdollCountdown"] then pcall(toggleSetters["ragdollCountdown"], State.ragdollCountdownEnabled == true) end
            if toggleSetters["antiRagdoll"] then pcall(toggleSetters["antiRagdoll"], State.antiRagdollEnabled == true) end
            if toggleSetters["safeMode"] then pcall(toggleSetters["safeMode"], antiKickEnabled == true) end
            if toggleSetters["infJump"] then pcall(toggleSetters["infJump"], State.infJumpEnabled == true) end
            if toggleSetters["antiLag"] then pcall(toggleSetters["antiLag"], State.antiLagEnabled == true) end
            if toggleSetters["saturatedColors"] then pcall(toggleSetters["saturatedColors"], State.saturatedColorsEnabled == true) end
            if State.headlessEnabled or State.korbloxEnabled or State.customSkinEnabled
                or CustomSkinSnapshots[LP.Character] then
                pcall(applyCharterToChar, LP.Character)
            end
            if toggleSetters["headless"] then pcall(toggleSetters["headless"], State.headlessEnabled) end
            if toggleSetters["korblox"] then pcall(toggleSetters["korblox"], State.korbloxEnabled) end
            if toggleSetters["customSkin"] then pcall(toggleSetters["customSkin"], State.customSkinEnabled) end
            if toggleSetters["changeBat"] then pcall(toggleSetters["changeBat"], State.changeBatEnabled == true) end
        end)
        if State.antiRagdollEnabled then startAntiRagdollNew() else stopAntiRagdollNew() end
        if State.ragdollCountdownEnabled then _G.MysteryStartRagdollCountdown() else _G.MysteryStopRagdollCountdown() end
        if State.autoTPEnabled then startAutoTP() else stopAutoTP() end
        if autoGrabModule then
            autoGrabModule.setRadius(Steal.StealRadius)
            autoGrabModule.setEnabled(Steal.AutoStealEnabled)
        end

        for key, setter in pairs(toggleSetters) do
            local stateValue = nil
            if key=="infJump" then stateValue=State.infJumpEnabled
            elseif key=="antiRagdoll" then stateValue=State.antiRagdollEnabled
            elseif key=="medusaCounter" then stateValue=State.medusaCounterEnabled
            elseif key=="batCounter" then stateValue=State.batCounterEnabled
            elseif key=="ragdollSteal" then stateValue=State.ragdollStealEnabled
            elseif key=="ragdollCountdown" then stateValue=State.ragdollCountdownEnabled
            elseif key=="autoSwing" then stateValue=State.autoSwingEnabled
            elseif key=="antiLag" then stateValue=State.antiLagEnabled
            elseif key=="stretchedRes" then stateValue=State.stretchedResEnabled
            elseif key=="removeAcc" then stateValue=State.removeAcc
            elseif key=="tryardAnim" then stateValue=State.tryardAnimEnabled
            elseif key=="hideButtons" then stateValue=State.stackButtonsHidden
            elseif key=="lockButtons" then stateValue=State.stackButtonsLocked
            elseif key=="autoTP" then stateValue=State.autoTPEnabled
            elseif key=="carryMode" then stateValue=State.speedToggled
            elseif key=="showTracker" then stateValue=State.showTrackerEnabled == true
            elseif key=="laggerMode" then stateValue=State.laggerMode~=0
            elseif key=="autoSteal" then stateValue=Steal.AutoStealEnabled

            elseif key=="antiDesync" then stateValue=_G.AceAntiDesyncAimbotOn == true
            elseif key=="batV2" then stateValue=State.batAimbotZombie == true
            elseif key=="safeMode" then stateValue=antiKickEnabled == true
            elseif key=="headless" then stateValue=State.headlessEnabled
            elseif key=="korblox" then stateValue=State.korbloxEnabled
            elseif key=="customSkin" then stateValue=State.customSkinEnabled
            elseif key=="changeBat" then stateValue=State.changeBatEnabled
            elseif key=="softSteal" then stateValue=State.softStealEnabled
            elseif key=="antiDie" then stateValue=State.antiDieEnabled
            elseif key=="antiFlingShield" then stateValue=State.antiFlingShieldEnabled
            end
            if stateValue ~= nil then pcall(setter, stateValue) end
        end
        refreshAllKeybindButtons()

        local function applyPositions(positions)
            if type(positions) ~= "table" then return end
            for key, posData in pairs(positions) do
                local wrapper = stackWrappers[key]
                if wrapper and type(posData) == "table" and posData.X ~= nil and posData.Y ~= nil then
                    local xs = (posData.XS ~= nil) and posData.XS or 0
                    local ys = (posData.YS ~= nil) and posData.YS or 0
                    wrapper.Position = UDim2.new(xs, posData.X, ys, posData.Y)
                end
            end
        end
        if type(decErr.menuButtonPos) == "table" then
            local mp = decErr.menuButtonPos
            State.menuButtonPos = mp
            local function applyMenuBtnPos()
                local btn = _G._K7ToggleBtn
                if btn and tonumber(mp.X) and tonumber(mp.Y) then
                    btn.Position = UDim2.new(tonumber(mp.XS) or 0, tonumber(mp.X) or 0,
                                             tonumber(mp.YS) or 0, tonumber(mp.Y) or 0)
                end
            end
            applyMenuBtnPos()
            task.delay(1.5, applyMenuBtnPos)
            task.delay(3.0, applyMenuBtnPos)
        end
        if decErr.buttonPositions and type(decErr.buttonPositions) == "table" then
            applyPositions(decErr.buttonPositions)
            task.delay(1.5, function() applyPositions(decErr.buttonPositions) end)
            task.delay(3.0, function() applyPositions(decErr.buttonPositions) end)
        end
        pcall(loadStackPositionsNow)
        task.delay(1.5, function() pcall(loadStackPositionsNow) end)
        task.delay(3.5, function() pcall(loadStackPositionsNow) end)


        print("[MAY duels] Config loaded successfully")
        return true
    end

    local _saveToken = 0
    requestSave = function()
        _saveToken = _saveToken + 1
        local myToken = _saveToken
        task.spawn(function()
            -- short debounce so rapid edits coalesce to latest values
            task.wait(0.12)
            if myToken ~= _saveToken then return end
            -- snapshot current speeds right before write (latest wins)
            local ok = saveConfig()
            if not ok then
                task.wait(0.15)
                if myToken == _saveToken then
                    ok = saveConfig()
                end
            end
            if ok then if _G._VezyFlashSave then _G._VezyFlashSave(true) end
            else if _G._VezyFlashSave then _G._VezyFlashSave(false) end end
        end)
    end
    _G._K7RequestSave = requestSave

    -- Auto Save: silent snapshot every 2s (menu options + floating button positions)
    _G._K7AutoSaveEnabled = true
    task.spawn(function()
        while task.wait(2) do
            if _G._K7AutoSaveEnabled and State._initialConfigSettled then
                pcall(saveStackPositionsNow)
                pcall(saveConfig, true)
            end
        end
    end)

    -- bounded force instead of math.huge: accelerates smoothly so the
    -- server sees a ramp, not an instant snap (kills the lagback)
    local LV_MAX_FORCE = 2200
    local LV_FREE_FORCE = 500

    -- ============================================================
    -- HELPER FUNCTIONS (unchanged)
    -- ============================================================
    local _aimbotTarget=nil
    local function findBat()
        local char=LP.Character; if not char then return nil end
        for _,tool in ipairs(char:GetChildren()) do if tool:IsA("Tool") and (tool.Name:lower():find("bat") or tool.Name:lower():find("slap")) then return tool end end
        local bp=LP:FindFirstChild("Backpack"); if bp then for _,tool in ipairs(bp:GetChildren()) do if tool:IsA("Tool") and (tool.Name:lower():find("bat") or tool.Name:lower():find("slap")) then return tool end end end
        return nil
    end
    local function getClosestTarget()
        local root=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not root then return nil end
        local closest,minDist=nil,math.huge
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr~=LP and plr.Character then
                local tRoot=plr.Character:FindFirstChild("HumanoidRootPart"); local hum=plr.Character:FindFirstChildOfClass("Humanoid")
                if tRoot and hum and hum.Health>0 then
                    local dist=(tRoot.Position-root.Position).Magnitude
                    if dist<minDist then minDist=dist; closest=tRoot end
                end
            end
        end
        return closest
    end
    startBatAimbot = function()
        if antiKickEnabled and _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
            _G.AceSafeModeForceStop("SAFE MODE LOCK")
            return
        end
        if Conns.aimbot then Conns.aimbot:Disconnect() end
        local hum0=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum0 then hum0.AutoRotate=false end
        Conns.aimbot = RunService.RenderStepped:Connect(function()
            if not State.batAimbotToggled then return end
            local char=LP.Character; if not char then return end
            local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end
            local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
            if not char:FindFirstChildOfClass("Tool") then local bat=findBat(); if bat then pcall(function() hum:EquipTool(bat) end) end end
            local target=getClosestTarget(); if not target then return end
            _aimbotTarget=target
            local targetVel=target.AssemblyLinearVelocity
            local myPos=root.Position; local targetPos=target.Position
            local predictPos=targetPos+targetVel*0.14; predictPos=predictPos+target.CFrame.LookVector*0.3
            local direction=predictPos-myPos; local flatDir=Vector3.new(direction.X,0,direction.Z).Unit
            local chaseSpeed = (_G.AceGetActiveAimbotSpeed and _G.AceGetActiveAimbotSpeed()) or (_G.AceGetNormalAimbotSpeed and _G.AceGetNormalAimbotSpeed()) or 50; local desiredHeight=targetPos.Y+3.7
            local yVel=(desiredHeight-myPos.Y)*19.5+targetVel.Y*0.8
            if hum.FloorMaterial~=Enum.Material.Air then yVel=math.max(yVel,13) end
            yVel=math.clamp(yVel,-70,110)
            local desiredVel=Vector3.new(flatDir.X*chaseSpeed,yVel,flatDir.Z*chaseSpeed)
            root.AssemblyLinearVelocity=root.AssemblyLinearVelocity:Lerp(desiredVel,0.8)
            local speed3=targetVel.Magnitude
            local predictTime=math.clamp(speed3/150,0.05,0.2)
            local predictedPos=targetPos+targetVel*predictTime
            local toPredict=predictedPos-myPos
            if toPredict.Magnitude>0.1 then
                local goalCF=CFrame.lookAt(myPos,predictedPos)
                local diffCF=root.CFrame:Inverse()*goalCF
                local rx,ry,rz=diffCF:ToEulerAnglesXYZ()
                rx=math.clamp(rx,-2.5,2.5); ry=math.clamp(ry,-2.5,2.5); rz=math.clamp(rz,-2.5,2.5)
                root.AssemblyAngularVelocity=root.CFrame:VectorToWorldSpace(Vector3.new(rx*42,ry*42,rz*42))
            end
        end)
    end
    stopBatAimbot = function()
        if Conns.aimbot then Conns.aimbot:Disconnect(); Conns.aimbot=nil end
        _aimbotTarget=nil
        local c=LP.Character; local root=c and c:FindFirstChild("HumanoidRootPart")
        if root then root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero end
        local hum2=c and c:FindFirstChildOfClass("Humanoid")
        if hum2 then hum2.AutoRotate=true end
        State.hittingCooldown=false
    end

    local BAT_COUNTER_SLAP_LIST={"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap"}
    local function findBatForCounter()
        local c=LP.Character; if not c then return nil end
        local bp=LP:FindFirstChildOfClass("Backpack")
        for _,name in ipairs(BAT_COUNTER_SLAP_LIST) do
            local t=c:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
            if t then return t end
        end
        for _,ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end
        if bp then for _,ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
        return nil
    end
    local function swingBatForCounter(bat,char)
        if _G.AceBatSwingBlocked and _G.AceBatSwingBlocked() then return end
        local hum2=char:FindFirstChildOfClass("Humanoid")
        if bat.Parent~=char then if hum2 then pcall(function() hum2:EquipTool(bat) end) end; task.wait(0.05) end
        local remote=bat:FindFirstChildOfClass("RemoteEvent") or bat:FindFirstChildOfClass("RemoteFunction")
        if remote and remote:IsA("RemoteEvent") then
            pcall(function() remote:FireServer() end); task.wait(0.15); pcall(function() remote:FireServer() end)
        else pcall(function() bat:Activate() end); task.wait(0.15); pcall(function() bat:Activate() end) end
    end
    startBatCounter = function()
        if Conns.batCounter then return end
        Conns.batCounter = RunService.Heartbeat:Connect(function()
            if not State.batCounterEnabled or State.batCounterDebounce then return end
            local char=LP.Character; if not char then return end
            local hum2=char:FindFirstChildOfClass("Humanoid"); if not hum2 then return end
            local st=hum2:GetState()
            local isRagdolled = st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown
            if isRagdolled then
                State.batCounterDebounce=true
                task.spawn(function()
                    local bat=findBatForCounter()
                    if bat then swingBatForCounter(bat,char) end
                    task.wait(0.5); State.batCounterDebounce=false
                end)
            end
        end)
    end
    stopBatCounter = function()
        if Conns.batCounter then Conns.batCounter:Disconnect(); Conns.batCounter=nil end
        State.batCounterDebounce=false
    end

    local MEDUSA_COOLDOWN=0.5
    local function findMedusa()
        local c=LP.Character; if not c then return nil end
        for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") then local n=t.Name:lower(); if n:find("medusa") or n:find("head") or n:find("stone") then return t end end end
        local bp=LP:FindFirstChildOfClass("Backpack")
        if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then local n=t.Name:lower(); if n:find("medusa") or n:find("head") or n:find("stone") then return t end end end end
        return nil
    end
    local function useMedusaCounter()
        if State.medusaDebounce then return end; if tick()-State.medusaLastUsed<MEDUSA_COOLDOWN then return end
        local c=LP.Character; if not c then return end; State.medusaDebounce=true
        local med=findMedusa(); if not med then State.medusaDebounce=false; return end
        if med.Parent~=c then local hum2=c:FindFirstChildOfClass("Humanoid"); if hum2 then hum2:EquipTool(med) end end
        pcall(function() med:Activate() end); State.medusaLastUsed=tick(); State.medusaDebounce=false
    end
    local function onAnchorChanged(part) return part:GetPropertyChangedSignal("Anchored"):Connect(function() if part.Anchored and part.Transparency==1 then useMedusaCounter() end end) end
    setupMedusaCounter = function(char)
        stopMedusaCounter(); if not char then return end
        for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then table.insert(Conns.anchor,onAnchorChanged(part)) end end
        table.insert(Conns.anchor,char.DescendantAdded:Connect(function(part) if part:IsA("BasePart") then table.insert(Conns.anchor,onAnchorChanged(part)) end end))
    end
    stopMedusaCounter = function() for _,c2 in pairs(Conns.anchor) do pcall(function() c2:Disconnect() end) end; Conns.anchor={} end

    -- ============================================================
    -- RAGDOLL STEAL
    -- Morcego (bat): ragdoll 2.7s -> auto grab volta em 1.5s
    -- Medusa's Head: ragdoll 5.7s; nao altera o Auto Grab
    -- ============================================================
    do
    local _rsWindow = nil        -- {t0=number, reenable=number}
    local _rsPrevAutoGrab = nil
    local _rsWasRagdolled = false
    local _rsConn = nil

    local RAG_CFG = {
        bat    = { reenable = 1.5, timer = 2.8 },
        medusa = { reenable = 4.5, timer = 5.7 },
    }
    -- qualquer ragdoll com duracao >= 4s so pode ser Medusa's Head
    local MEDUSA_MIN_DURATION = 4.0
    local _rsGuard = nil
    local _rsHitKind = nil
    local _rsHitAt = 0
    local _rsLastTrigger = 0     -- cooldown: impede detectar 2x o mesmo golpe
    local _rsClearSince = 0      -- ragdoll precisa sumir por um tempo antes de rearmar
    local RS_COOLDOWN = 1.2
    local _rsLockUntil = 0       -- travamento total: 1 golpe = 1 deteccao


    _G._K7RagdollStealClear = function()
        _rsWindow = nil
    end

    local function _rsIsRagdolled(hum)
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Physics
        or st == Enum.HumanoidStateType.Ragdoll
        or st == Enum.HumanoidStateType.FallingDown then return true end
        local et = LP:GetAttribute("RagdollEndTime")
        if et and (et - workspace:GetServerTimeNow()) > 0 then return true end
        return false
    end

    -- ===== DETECTORES (Medusa's Head x Morcego) =====
    local function _strHasMedusa(n)
        if type(n) ~= "string" then return false end
        n = n:lower()
        return (n:find("medusa") or n:find("petrif") or n:find("stone") or n:find("statue")) and true or false
    end

    local function _strHasBat(n)
        if type(n) ~= "string" then return false end
        n = n:lower()
        return (n:find("bat") or n:find("morcego") or n:find("slap")) and true or false
    end

    -- duracao restante do ragdoll atual (0 se nao houver)
    local function _rsRagdollRemaining()
        local now = workspace:GetServerTimeNow()
        local best = 0
        local et = LP:GetAttribute("RagdollEndTime")
        if type(et) == "number" then
            local rem = et - now
            if rem > best then best = rem end
        end
        for _, obj in ipairs({ LP, LP.Character }) do
            if obj then
                local ok, attrs = pcall(function() return obj:GetAttributes() end)
                if ok and attrs then
                    for k, v in pairs(attrs) do
                        local n = tostring(k):lower()
                        if type(v) == "number" and (n:find("ragdoll") or n:find("stun")
                            or n:find("petrif") or n:find("stone") or n:find("medusa")) then
                            local rem = v - now
                            if rem > 0 and rem < 60 and rem > best then best = rem end
                            if v > 0 and v < 60 and v > best then best = v end
                        end
                    end
                end
            end
        end
        return best
    end

    -- eu estou segurando/portando a Medusa? (para NUNCA disparar quando EU medusar)
    local function _rsIHoldMedusa()
        local c = LP.Character
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and _strHasMedusa(t.Name) then return true end
            end
        end
        return false
    end

    -- o objeto esta dentro de uma Tool? (ignora partes da arma que EU seguro)
    local function _rsInsideTool(d)
        local p = d
        while p and p ~= LP.Character do
            if p:IsA("Tool") then return true end
            p = p.Parent
        end
        return false
    end

    -- marcadores exclusivos da Medusa (pedra/petrificacao), sem falso positivo
    local function _rsMedusaMarker()
        local c = LP.Character
        if not c then return false end

        for _, obj in ipairs({ LP, c }) do
            local ok, attrs = pcall(function() return obj:GetAttributes() end)
            if ok and attrs then
                for k, v in pairs(attrs) do
                    if _strHasMedusa(k) then
                        if v == true then return true end
                        if type(v) == "number" and v > workspace:GetServerTimeNow() then return true end
                        if type(v) == "string" and v ~= "" then return true end
                    end
                end
            end
        end

        for _, d in ipairs(c:GetDescendants()) do
            if not d:IsA("Tool") and not _rsInsideTool(d) and _strHasMedusa(d.Name) then return true end
        end
        return false
    end


    -- alguem por perto segurando Medusa's Head?
    local function _rsToolNearby(matcher)
        local myChar = LP.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local root = plr.Character:FindFirstChild("HumanoidRootPart")
                local near = (not myRoot) or (not root) or (root.Position - myRoot.Position).Magnitude <= 20
                if near then
                    for _, t in ipairs(plr.Character:GetChildren()) do
                        if t:IsA("Tool") and matcher(t.Name) then return true end
                    end
                end
            end
        end
        return false
    end

    -- ===== EU usei a Medusa? (bloqueia o Ragdoll Steal Med) =====
    local _rsSelfMedusaUntil = 0
    local _rsSelfMedusaConns = {}
    local function _rsWatchSelfMedusa(char)
        for _, c in ipairs(_rsSelfMedusaConns) do pcall(function() c:Disconnect() end) end
        _rsSelfMedusaConns = {}
        _rsSelfMedusaUntil = 0
        if not char then return end
        local function hook(tool)
            if not (tool and tool:IsA("Tool") and _strHasMedusa(tool.Name)) then return end
            table.insert(_rsSelfMedusaConns, tool.Activated:Connect(function()
                _rsSelfMedusaUntil = os.clock() + 8
            end))
        end
        for _, t in ipairs(char:GetChildren()) do hook(t) end
        table.insert(_rsSelfMedusaConns, char.ChildAdded:Connect(hook))
    end
    _G._K7WatchSelfMedusa = _rsWatchSelfMedusa

    local function _rsSelfMedusaActive()
        return os.clock() < _rsSelfMedusaUntil
    end

    -- SO conta quando OUTRO jogador me medusou.
    -- Nunca dispara se fui EU quem usou a Medusa.
    local function _rsIsMedusad()
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if not hum or not _rsIsRagdolled(hum) then return false end
        if _rsSelfMedusaActive() then return false end
        if _rsIHoldMedusa() then return false end
        -- exige um OUTRO jogador por perto empunhando a Medusa's Head
        if not _rsToolNearby(_strHasMedusa) then return false end
        if _rsMedusaMarker() then return true end
        if _rsRagdollRemaining() >= MEDUSA_MIN_DURATION then return true end
        return false
    end

    -- SO detecta quando OUTRA pessoa me bateu (morcego) ou me medusou.
    -- Queda, fisica normal ou uso proprio da Medusa nunca contam.
    local function _rsHitDetected(hum)
        if not _rsIsRagdolled(hum) then return false end
        if _rsSelfMedusaActive() then return false end
        -- precisa existir um oponente por perto com morcego (ou medusa)
        local batNear = _rsToolNearby(_strHasBat)
        local medNear = (not _rsIHoldMedusa()) and _rsToolNearby(_strHasMedusa)
        if not (batNear or medNear) then return false end
        if _rsRagdollRemaining() > 0 then return true end
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll then
            return true
        end
        return false
    end

    -- classificacao definitiva do golpe recebido
    local function _rsClassifyHit()
        local rem = _rsRagdollRemaining()
        local medNear = (not _rsIHoldMedusa()) and (not _rsSelfMedusaActive()) and _rsToolNearby(_strHasMedusa)
        if medNear and (rem >= MEDUSA_MIN_DURATION or _rsMedusaMarker()) then return "medusa" end
        if medNear and not _rsToolNearby(_strHasBat) then return "medusa" end
        return "bat"
    end



    -- restaura o Auto Grab SEMPRE (nunca pode ficar desligado por bug)
    local function _rsRestoreAutoGrab()
        _rsWindow = nil
        _G._K7AutoGrabPauseUntil = nil
        if autoGrabModule and _G._K7AutoGrabUserOff ~= true then
            Steal.AutoStealEnabled = true
            pcall(function()
                if autoGrabModule.resumeFromPause then
                    autoGrabModule.resumeFromPause()
                elseif not autoGrabModule.isEnabled() then
                    autoGrabModule.setEnabled(true)
                end
            end)
            if toggleSetters and toggleSetters["autoSteal"] then
                pcall(toggleSetters["autoSteal"], true)
            end
        end
    end

    -- loop unico: roda para sempre; so para de agir se o toggle for desligado
    local function startRagdollSystems(char)
        if _rsConn then pcall(function() _rsConn:Disconnect() end) _rsConn = nil end
        pcall(function() _rsWatchSelfMedusa(char) end)
        _rsWasRagdolled = false
        _rsWindow = nil
        _rsLastTrigger = 0
        _rsClearSince = 0
        _rsLockUntil = 0
        _rsConn = RunService.Heartbeat:Connect(function()
            if _G.AceBrainrotSafe and _G.AceBrainrotSafe() then return end
            if not State.ragdollStealEnabled then
                _rsWasRagdolled = false
                _rsLockUntil = 0
                if _rsWindow then _rsRestoreAutoGrab() end
                return
            end
            local hum = char and char.Parent and char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local med = _rsIsMedusad()
            local rag = med or _rsHitDetected(hum)
            local nowc = os.clock()
            -- debounce: o estado precisa ficar limpo ~0.35s antes de rearmar,
            -- senao um unico golpe seria contado duas vezes.
            if rag then
                _rsClearSince = 0
            else
                if _rsClearSince == 0 then _rsClearSince = nowc end
                if (nowc - _rsClearSince) < 0.6 then
                    rag = _rsWasRagdolled
                end
            end
            -- enquanto o golpe atual esta travado, o estado conta como continuo:
            -- qualquer piscada do ragdoll NAO pode gerar uma segunda deteccao.
            if nowc < _rsLockUntil then
                rag = true
            elseif not rag then
                _rsLockUntil = 0
            end
            if rag and not _rsWasRagdolled and nowc >= _rsLockUntil and (nowc - _rsLastTrigger) >= RS_COOLDOWN then
                _rsLastTrigger = nowc
                local kind = med and "medusa" or _rsClassifyHit()
                local cfg = RAG_CFG[kind]
                -- trava o rearme por toda a duracao do golpe (1 hit = 1 deteccao)
                _rsLockUntil = nowc + math.max(cfg.timer or 0, cfg.reenable or 0) + 0.5
                _rsHitKind = kind
                _rsHitAt = os.clock()
                -- Ragdoll Steal agora SO age no golpe de MORCEGO (medusa removida)
                if State.ragdollStealEnabled and kind == "bat" then
                    if autoGrabModule and _rsWindow == nil then
                        _rsPrevAutoGrab = autoGrabModule.isEnabled()
                        -- Auto Grab PAUSA (nao desliga o toggle do usuario)
                        pcall(function()
                            if autoGrabModule.pauseFor then
                                autoGrabModule.pauseFor(cfg.reenable)
                            else
                                autoGrabModule.setEnabled(false)
                            end
                        end)
                    end
                    _rsWindow = { t0 = os.clock(), reenable = cfg.reenable, kind = kind }
                    -- rede de seguranca: mesmo se o Heartbeat falhar, volta no tempo
                    _rsGuard = (_rsGuard or 0) + 1
                    local g = _rsGuard
                    task.delay(cfg.reenable + 0.05, function()
                        if g == _rsGuard and _rsWindow then _rsRestoreAutoGrab() end
                    end)
                end
            elseif rag and _rsHitKind == "bat" and med and (nowc - (_rsHitAt or 0)) < RS_COOLDOWN then
                -- upgrade: Medusa confirmada logo apos o hit
                local elapsed = os.clock() - (_rsHitAt or os.clock())
                _rsHitKind = "medusa"
                -- Medusa nao pausa mais o Auto Grab: libera a janela na hora
                if _rsWindow then _rsRestoreAutoGrab() end
            end
            _rsWasRagdolled = rag
            if _rsWindow and (os.clock() - _rsWindow.t0) >= _rsWindow.reenable then
                _rsRestoreAutoGrab()
            end
        end)
    end

    -- trava extra: o Semi (Auto Grab V2) tambem respeita a janela de bloqueio.
    -- A janela EXPIRA sozinha: nunca pode deixar o Auto Grab preso em 0%.
    _G.RagdollStealReady = function()
        if not State.ragdollStealEnabled then
            if _rsWindow then _rsRestoreAutoGrab() end
            return true
        end
        if _rsWindow == nil then return true end
        if (os.clock() - _rsWindow.t0) >= (_rsWindow.reenable or 1.5) then
            _rsRestoreAutoGrab()
            return true
        end
        return false
    end

    -- WATCHDOG: destrava o Auto Grab caso a janela fique presa por qualquer bug
    task.spawn(function()
        while true do
            task.wait(0.25)
            pcall(function()
                if _rsWindow and (os.clock() - _rsWindow.t0) >= ((_rsWindow.reenable or 1.5) + 0.3) then
                    _rsRestoreAutoGrab()
                end
                if (not State.ragdollStealEnabled) and _rsWindow then
                    _rsRestoreAutoGrab()
                end
            end)
        end
    end)

    _G._K7StartRagdollSystems = startRagdollSystems
    end

    -- ============================================================
    -- CHARACTER SETUP (unchanged, but now includes charter)
    -- ============================================================
    local function setupChar(char)
        task.wait(0.1)
        h=char:WaitForChild("Humanoid",5)
        hrp=char:WaitForChild("HumanoidRootPart",5)
        if not h or not hrp then return end

        local function ensureLocalSpeedBillboard()
            local currentChar = LP.Character
            local head = currentChar and currentChar:FindFirstChild("Head")
            if not head then return nil end
            local oldSpeedBadge = head:FindFirstChild("SevenUpSpeedBadge")
            if oldSpeedBadge then oldSpeedBadge:Destroy() end
            local bb = head:FindFirstChild("SevenUpDuelsBB")
            local speedBillLbl = bb and bb:FindFirstChild("SpeedBillLbl")
            local discordLbl = bb and bb:FindFirstChild("discordLbl")
            if not bb or not speedBillLbl or not discordLbl then
                if bb then bb:Destroy() end
                bb=Instance.new("BillboardGui", head); bb.Name="SevenUpDuelsBB"; bb.Size=UDim2.new(0,180,0,100); bb.StudsOffset=Vector3.new(0,3,0); bb.AlwaysOnTop=true; bb.AutoLocalize=false
                local list=Instance.new("UIListLayout",bb); list.FillDirection=Enum.FillDirection.Vertical; list.SortOrder=Enum.SortOrder.LayoutOrder; list.VerticalAlignment=Enum.VerticalAlignment.Center; list.Padding=UDim.new(0,2)
                speedBillLbl=Instance.new("TextLabel",bb); speedBillLbl.Name="SpeedBillLbl"; speedBillLbl.Size=UDim2.new(1,0,0,24); speedBillLbl.BackgroundTransparency=1; speedBillLbl.AutoLocalize=false; speedBillLbl.Text="Speed: 0.0"; speedBillLbl.TextColor3=Color3.fromRGB(45,205,255); speedBillLbl.Font=Enum.Font.GothamBold; speedBillLbl.TextScaled=true; speedBillLbl.TextStrokeTransparency=0.1; speedBillLbl.TextStrokeColor3=Color3.new(0,0,0); speedBillLbl.LayoutOrder=1
                discordLbl=Instance.new("TextLabel",bb); discordLbl.Name="discordLbl"; discordLbl.Size=UDim2.new(1,0,0,22); discordLbl.BackgroundTransparency=1; discordLbl.AutoLocalize=false; discordLbl.Visible=true; discordLbl.Text="discord.gg/GvBQmT7Xj"; discordLbl.TextColor3=currentColorScheme.discordText or currentColorScheme.subText; discordLbl.Font=Enum.Font.GothamBold; discordLbl.TextScaled=true; discordLbl.TextStrokeTransparency=0.1; discordLbl.TextStrokeColor3=Color3.new(0,0,0); discordLbl.LayoutOrder=2
            end
            bb.Adornee = head
            bb.Enabled = true
            bb.AlwaysOnTop = true
            return speedBillLbl
        end
        _G._K7EnsureLocalSpeedBillboard = ensureLocalSpeedBillboard
        ensureLocalSpeedBillboard()
        stopAntiRagdollNew()
        if _G._K7StartRagdollSystems then pcall(_G._K7StartRagdollSystems, char) end
        if State.antiRagdollEnabled then task.wait(0.5); startAntiRagdollNew() end
        if State.medusaCounterEnabled then setupMedusaCounter(char) end
        if State.batAimbotToggled then stopBatAimbot(); task.wait(0.2); pcall(startBatAimbot) end
        if State.batCounterEnabled then task.wait(0.3); startBatCounter() end
        task.defer(function()
            task.wait(0.2)
            pcall(applySavedAnimationPackToCharacter, char)
            for _, d in ipairs({0.6, 1.2, 2.5}) do
                task.delay(d, function()
                    if LP.Character == char then
                        pcall(applySavedAnimationPackToCharacter, char)
                    end
                end)
            end
            -- Apply charter
            pcall(applyCharterToChar, char)
        end)
    end
    LP.CharacterAdded:Connect(setupChar)
    if LP.Character then task.spawn(function() setupChar(LP.Character) end) end

    -- ============================================================
    -- RUNTIME LOOPS (updated with Soft Steal integration)
    -- ============================================================
    RunService.Stepped:Connect(function()
        for _,p in ipairs(Players:GetPlayers()) do if p~=LP and p.Character then for _,part in ipairs(p.Character:GetChildren()) do if part:IsA("BasePart") then part.CanCollide=false end end end end
    end)

    local function getActiveMoveSpeed()
        if State.autoLeftEnabled or State.autoRightEnabled then
            return State.normalSpeed or 60
        end
        -- Soft Steal: approach slow, then keep soft steal speed while carrying until the animal is dropped/thrown
        if State.softStealEnabled and autoGrabModule and autoGrabModule.getNearestSoftStealAnimal then
            local _, dist = autoGrabModule.getNearestSoftStealAnimal(State.softStealRadius or 10)
            local inRange = dist and dist <= (State.softStealRadius or 10)
            if inRange then
                State.softStealLatched = true
                return State.softStealSpeed or 30
            end
            if State.softStealLatched then
                if isCurrentlyCarrying() then
                    return State.softStealSpeed or 30
                else
                    State.softStealLatched = false
                end
            end
        end

        -- NightHub speed logic: Lagger Normal, Lagger Carry, Carry Mode, Normal Speed
        if State.laggerMode == 1 then return State.laggerSpeed or 15 end
        if State.laggerMode == 2 then return State.laggerCarrySpeed or 24.5 end
        if State.speedToggled then return State.carrySpeed or 30 end
        return State.normalSpeed or 60
    end

    local function activeSpeedStatus()
        if State.autoLeftEnabled or State.autoRightEnabled then
            return "NORMAL SPEED", State.normalSpeed or 60
        end
        if State.softStealEnabled and autoGrabModule and autoGrabModule.getNearestSoftStealAnimal then
            local _, dist = autoGrabModule.getNearestSoftStealAnimal(State.softStealRadius or 10)
            local inRange = dist and dist <= (State.softStealRadius or 10)
            if inRange or (State.softStealLatched and isCurrentlyCarrying()) then
                return "AUTO SWITCH CARRY", State.softStealSpeed or 30
            end
        end
        if State.laggerMode == 1 then
            return "LAGGER SPEED", State.laggerSpeed or 15
        end
        if State.laggerMode == 2 then
            return "LAGGER CARRY SPEED", State.laggerCarrySpeed or 24.5
        end
        if State.speedToggled then
            return "CARRY SPEED", State.carrySpeed or 30
        end
        return "NORMAL SPEED", State.normalSpeed or 60
    end

    -- ============================================================
    -- SPEED ENGINE (NIGHT HUB V2 MOTOR - RENDERSTEPPED & NO LAG)
    -- Substitui o motor antigo do Mystery pelo motor fluido do NightHub
    -- ============================================================
    local function removeNetworkLimit()
        pcall(function() game:GetService("NetworkClient"):SetOutgoingKBPSLimit(math.huge) end)
    end
    removeNetworkLimit()

    local _cachedChar, _cachedHum, _cachedHrp = nil, nil, nil
    local lastMoveDir = Vector3.new(0, 0, 0)
    local MOVE_KEYS = {
        [Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
        [Enum.KeyCode.Up] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Right] = true
    }

    local _UIS = UIS or UserInputService or game:GetService("UserInputService")

    local function cleanupSpeedPhysics()
        pcall(function()
            local c = LP.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then
                    h.AutoRotate = true
                    if h.WalkSpeed ~= 16 then h.WalkSpeed = 16 end
                end
            end
        end)
    end
    _G.__K7CleanupSpeedPhysics = cleanupSpeedPhysics
    _G.__K7SpeedFlush = function() end

    local function speedEngineBlocked()
        return dropActive or State._dropInProgress or State._tpInProgress
    end

    local function aimbotMovementActive()
        return State.batAimbotToggled == true
            or _G.AceNormalAimbotOn == true
            or _G.AceAntiDesyncAimbotOn == true
            or _G.AceBatV2Active == true
    end

    -- Billboard local de Speed
    RunService.Heartbeat:Connect(function()
        pcall(function()
            local sl = _G._K7EnsureLocalSpeedBillboard and _G._K7EnsureLocalSpeedBillboard()
            if sl then
                local _, value = activeSpeedStatus()
                sl.Text = string.format("Speed: %.1f", tonumber(value) or 0)
                sl.TextColor3 = currentColorScheme.speedText or currentColorScheme.main
            end
        end)
    end)

    -- Motor do NightHub em RenderStepped (ultra fluido, sem tremedeira na camera e sem desync)
    RunService.RenderStepped:Connect(function()
        local char = LP.Character
        if not char then
            _cachedChar = nil
            _G._AmbitiousAntiBatDesiredXZ = nil
            return
        end

        local hum, hrp
        if char == _cachedChar then
            hum = _cachedHum
            hrp = _cachedHrp
        else
            _cachedChar = char
            hum = char:FindFirstChildOfClass("Humanoid")
            hrp = char:FindFirstChild("HumanoidRootPart")
            _cachedHum = hum
            _cachedHrp = hrp
        end

        if not hum or not hrp or hum.Health <= 0 then
            _G._AmbitiousAntiBatDesiredXZ = nil
            return
        end

        if speedEngineBlocked() or aimbotMovementActive() then
            _G._AmbitiousAntiBatDesiredXZ = nil
            return
        end

        local _st = hum:GetState()
        if hum.PlatformStand
            or _st == Enum.HumanoidStateType.Physics
            or _st == Enum.HumanoidStateType.Ragdoll
            or _st == Enum.HumanoidStateType.FallingDown then
            lastMoveDir = Vector3.new(0, 0, 0)
            _G._AmbitiousAntiBatDesiredXZ = nil
            return
        end

        if not State.autoLeftEnabled and not State.autoRightEnabled then
            local md = hum.MoveDirection
            local spd = getActiveMoveSpeed()
            if md.Magnitude > 0 then
                lastMoveDir = md
                _G._AmbitiousAntiBatDesiredXZ = Vector3.new(md.X * spd, 0, md.Z * spd)
                hrp.Velocity = Vector3.new(md.X * spd, hrp.Velocity.Y, md.Z * spd)
            elseif State.antiRagdollEnabled and lastMoveDir.Magnitude > 0 then
                local anyHeld = false
                for key in pairs(MOVE_KEYS) do
                    if _UIS:IsKeyDown(key) then
                        anyHeld = true
                        break
                    end
                end
                if anyHeld then
                    _G._AmbitiousAntiBatDesiredXZ = Vector3.new(lastMoveDir.X * spd, 0, lastMoveDir.Z * spd)
                    hrp.Velocity = Vector3.new(lastMoveDir.X * spd, hrp.Velocity.Y, lastMoveDir.Z * spd)
                else
                    _G._AmbitiousAntiBatDesiredXZ = nil
                end
            else
                _G._AmbitiousAntiBatDesiredXZ = nil
            end
        else
            _G._AmbitiousAntiBatDesiredXZ = nil
        end
    end)

    UIS.InputBegan:Connect(function(inp, gp)
        if UIS:GetFocusedTextBox() then return end
        local isKb = inp.UserInputType == Enum.UserInputType.Keyboard
        local isGp = tostring(inp.UserInputType):find("Gamepad") ~= nil
        if not isKb and not isGp then return end
        local kc = inp.KeyCode
        if kc == Enum.KeyCode.Unknown then return end

        -- Keybinds dedicadas: cada uma aciona exatamente o botao da stack
        do
            local stackKeyMap = {
                { key = Keys.antiBatTp, btn = "antiBatTp" },
                { key = Keys.instaReset, btn = "instaReset" },
            }
            for _, m in ipairs(stackKeyMap) do
                if m.key and m.key ~= Enum.KeyCode.Unknown and kc == m.key then
                    local tap = _G._K7StackTap and _G._K7StackTap[m.btn]
                    if tap then pcall(tap) end
                    return
                end
            end
        end

        if Keys.batV2 and Keys.batV2 ~= Enum.KeyCode.Unknown and kc == Keys.batV2 then
            if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
                if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
                return
            end
            if _G.AceToggleBypassAimbot then pcall(_G.AceToggleBypassAimbot) end
            if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
            requestSave()
            return
        end

        if Keys.batAimbot and Keys.batAimbot ~= Enum.KeyCode.Unknown and kc == Keys.batAimbot then
            if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
                if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
                return
            end
            if _G.AceToggleOldAimbot then pcall(_G.AceToggleOldAimbot) end
            if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
            requestSave()
            return
        end

        if kc == Keys.aimbot then
            if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
                if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
                return
            end
            if _G.AceToggleSelectedAimbot then
                _G.AceToggleSelectedAimbot()
            elseif _G.AceStartNormalAimbot and _G.AceStopNormalAimbot then
                if _G.AceNormalAimbotOn then _G.AceStopNormalAimbot() else _G.AceStartNormalAimbot() end
            end
            if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
            requestSave()
            return
        end

        if Keys.antiDesync and kc == Keys.antiDesync then
            if _G.AceSafeModeIsLocked and _G.AceSafeModeIsLocked() then
                if _G.AceSafeModeForceStop then _G.AceSafeModeForceStop("SAFE MODE LOCK") end
                return
            end
            print("[MAY duels] AntiDesync key pressed:", Keys.antiDesync.Name, "on=", _G.AceAntiDesyncAimbotOn)
            if _G.AceToggleAntiDesyncAimbot then
                _G.AceToggleAntiDesyncAimbot()
            elseif _G.AceStartAntiDesyncAimbot and _G.AceStopAntiDesyncAimbot then
                if _G.AceAntiDesyncAimbotOn then _G.AceStopAntiDesyncAimbot() else _G.AceStartAntiDesyncAimbot() end
            else
                warn("[MAY duels] AntiDesync functions missing")
            end
            return
        end

        -- Keyboard + Controller both fire action keybinds
        if kc == Keys.speed then toggleSpeed()
        elseif Keys.autoLeft and kc == Keys.autoLeft then
            if State.autoLeftEnabled then stopAutoLeft() else startAutoLeft() end
        elseif Keys.autoRight and kc == Keys.autoRight then
            if State.autoRightEnabled then stopAutoRight() else startAutoRight() end
        elseif kc == Keys.drop then if not dropActive then pcall(runDrop) end
        elseif kc == Keys.lagger then toggleLaggerMode()
        elseif kc == Keys.tpDown then if runTPDown then task.spawn(runTPDown) end
        elseif kc == Keys.guiHide then
            -- allow both keyboard and controller for hide
            if _G._K7SetMenuVisible then
                pcall(_G._K7SetMenuVisible, not State.guiVisible)
            else
                State.guiVisible = not State.guiVisible
                mainOuter.Visible = State.guiVisible
            end
            requestSave()
        end
    end)

    -- FOV Lock (unchanged)
    _G._VezyFOV = _G._VezyFOV or 70
    _G._VezyFOVPropConn = nil
    local function _attachFOVLock(cam)
        if not cam then return end
        if _G._VezyFOVPropConn then pcall(function() _G._VezyFOVPropConn:Disconnect() end) end
        local function fovTarget()
            return _G._VezyFOV or 70
        end
        pcall(function() cam.FieldOfView = fovTarget() end)
        _G._VezyFOVPropConn = cam:GetPropertyChangedSignal("FieldOfView"):Connect(function()
            local target = fovTarget()
            if cam.FieldOfView ~= target then pcall(function() cam.FieldOfView = target end) end
        end)
    end
    _attachFOVLock(workspace.CurrentCamera)
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() task.wait(); _attachFOVLock(workspace.CurrentCamera) end)
    LP.CharacterAdded:Connect(function() task.wait(0.3); _attachFOVLock(workspace.CurrentCamera) end)
    RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local target = _G._VezyFOV or 70
        if cam.FieldOfView ~= target then pcall(function() cam.FieldOfView = target end) end
    end)

    -- ============================================================
    -- INIT: CONFIG LOAD
    -- ============================================================
    loadPresetsFile()
    local _lastPresetName = loadLastPresetName()
    if _lastPresetName and _lastPresetName~="" then
        for _,preset in ipairs(Presets) do
            if preset.name==_lastPresetName then
                pcall(function()
                    local d=preset.data or {}
                    if (State._speedEditRevision or 0) == 0 then
                        if d.normalSpeed then State.normalSpeed=d.normalSpeed; if normalBox then normalBox.Text=tostring(d.normalSpeed) end end
                        if d.carrySpeed then State.carrySpeed=d.carrySpeed; State._prevCarry=d.carrySpeed; if carryBox then carryBox.Text=tostring(d.carrySpeed) end end
                        if d.laggerSpeed then State.laggerSpeed=d.laggerSpeed; if laggerBox then laggerBox.Text=tostring(d.laggerSpeed) end end
                        if d.laggerCarrySpeed then State.laggerCarrySpeed=d.laggerCarrySpeed; if laggerCarryBox then laggerCarryBox.Text=tostring(d.laggerCarrySpeed) end end
                    end
                    if d.stealRadius then 
                        Steal.StealRadius=d.stealRadius
                        if autoGrabModule then autoGrabModule.setRadius(d.stealRadius) end
                        if stealRadBox then stealRadBox.Text=tostring(d.stealRadius) end
                    end
                    if d.autoSteal ~= nil then
                        Steal.AutoStealEnabled=d.autoSteal
                        if autoGrabModule then autoGrabModule.setEnabled(d.autoSteal) end
                        if toggleSetters["autoSteal"] then pcall(toggleSetters["autoSteal"], d.autoSteal) end
                    end
                    if d.autoTP ~= nil then State.autoTPEnabled=d.autoTP; if toggleSetters["autoTP"] then toggleSetters["autoTP"](d.autoTP) end end
                    if d.autoTPHeight then State.autoTPHeight=d.autoTPHeight; if autoTPHeightBox then autoTPHeightBox.Text=tostring(d.autoTPHeight) end end
                end)
                break
            end
        end
    end
    
    local configLoaded = false
    for i = 1, 3 do
        if loadConfig() then
            configLoaded = true
            break
        end
        task.wait(0.2)
    end
    State._initialConfigSettled = true
    task.delay(0.5, function()
        if _G._K7SyncTpBatModeBox then pcall(_G._K7SyncTpBatModeBox) end
        if _G._K7SyncAntiTpBatModeBox then pcall(_G._K7SyncAntiTpBatModeBox) end
        if _G._K7SyncAimbotVersionBar then pcall(_G._K7SyncAimbotVersionBar) end
        if _G._K7SyncInstaResetBar then pcall(_G._K7SyncInstaResetBar) end
        if _G.AceSetTpBatMode then pcall(_G.AceSetTpBatMode, State.tpBatMode or "v1") end
        if _G.AceSetAntiTpBatMode then pcall(_G.AceSetAntiTpBatMode, State.antiTpBatMode or "v1") end
        if _G.AceSetInstaResetVersion then pcall(_G.AceSetInstaResetVersion, State.instaResetVersion or 1) end
        if stackBtnRefs and stackBtnRefs.antiBatTp and stackBtnRefs.antiBatTp.setLabel then
            pcall(function() stackBtnRefs.antiBatTp.setLabel("ANTI\nBAT TP") end)
        end
        if stackBtnRefs and stackBtnRefs.antiDesync and stackBtnRefs.antiDesync.setLabel then
            pcall(function() stackBtnRefs.antiDesync.setLabel(_G.AceTpBatStackLabel()) end)
        end
    end)
    task.delay(1.5, function() pcall(_G._K7ApplyDirectUserColors) end)
    task.delay(4.0, function() pcall(_G._K7ApplyDirectUserColors) end)
    task.delay(6.0, function() pcall(saveConfig) end)
    
    if not configLoaded then
        print("[MAY duels] Warning: Could not load config, using defaults")
        pcall(saveConfig)
    end
    
-- Final cyber light-blue pass: vibrant panels, glowing cyan borders, dark ink text.
task.defer(function()
    local root=_G._K7MainFrame
    if not root then return end
    local LB_GLOW  = Color3.fromRGB(230, 250, 255)
    local LB_LIGHT = Color3.fromRGB(120, 220, 255)
    local LB_MID   = Color3.fromRGB(0, 0, 0)
    local LB_PANEL = Color3.fromRGB(175, 220, 250)
    local LB_ROW   = Color3.fromRGB(155, 210, 245)
    local LB_BG    = Color3.fromRGB(190, 230, 255)
    local LB_SOFT  = Color3.fromRGB(160, 220, 255)
    local INK      = Color3.fromRGB(10, 40, 85)
    local function inBlackControlRow(obj)
        local p = obj
        for _=1,8 do
            if not p then return false end
            local ok, v = pcall(function()
                return p:GetAttribute("MysteryToggleRow") == true
                    or p:GetAttribute("AlwaysCyanOptionBar") == true
                    or p:GetAttribute("AlwaysBlackOptionBar") == true
            end)
            if ok and v then return true end
            p = p.Parent
        end
        return false
    end
    for _,obj in ipairs(root:GetDescendants()) do
        pcall(function()
            local blackControl = inBlackControlRow(obj)
            if obj:IsA("GuiObject") then
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    if blackControl then
                        obj.TextColor3 = Color3.fromRGB(255,255,255)
                        obj.TextStrokeTransparency = 1
                    elseif not obj:GetAttribute("MysteryVsGlowText") then
                        obj.TextColor3 = INK
                        obj.TextStrokeColor3 = LB_LIGHT
                        obj.TextStrokeTransparency = 0.85
                    end
                end
                if obj:GetAttribute("AlwaysCyanOptionBar") or obj:GetAttribute("AlwaysBlackOptionBar") or obj:GetAttribute("MysteryToggleRow") then
                    obj.BackgroundColor3 = Color3.fromRGB(0,0,0)
                    obj.BackgroundTransparency = 0
                elseif obj:GetAttribute("AlwaysBlackOptionBar") then
                    obj.BackgroundColor3 = Color3.fromRGB(0,0,0)
                    obj.BackgroundTransparency = 0
                elseif obj.Name=="SevenUpNavTab" or obj.Name=="GradientSurface" then
                    obj.BackgroundColor3 = LB_PANEL
                end
            end
            if obj:IsA("UIStroke") and obj.Name~="MysteryVsGlowStroke" and obj.Name~="K7ToggleWhiteBorder" then
                obj.Color = LB_LIGHT
                if obj.Transparency > 0.5 then obj.Transparency = 0.35 end
            end
            if obj:IsA("UIGradient") and (obj.Parent.Name=="GradientSurface" or obj.Parent:GetAttribute("AlwaysBlackOptionBar")) then
                obj.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, LB_GLOW),
                    ColorSequenceKeypoint.new(0.45, LB_LIGHT),
                    ColorSequenceKeypoint.new(1, LB_MID),
                })
            end
        end)
    end
    local bg=root:FindFirstChild("BgImage")
    if bg then
        bg.Visible = true
        bg.Image = "rbxassetid://137970714521556"
        bg.BackgroundTransparency = 1
        bg.ImageTransparency = 0
        bg.ImageColor3 = Color3.fromRGB(255,255,255)
        bg.ScaleType = Enum.ScaleType.Crop
        local g = bg:FindFirstChild("CyberBgGradient")
        if g then g:Destroy() end
    end
    local atmo = root:FindFirstChild("GradientAtmosphere")
    if atmo then
        atmo.BackgroundTransparency = 0.97
        atmo.BackgroundColor3 = LB_LIGHT
        local ag = atmo:FindFirstChildOfClass("UIGradient")
        if ag then
            ag.Rotation = 90
            ag.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, LB_GLOW),
                ColorSequenceKeypoint.new(0.35, LB_LIGHT),
                ColorSequenceKeypoint.new(0.70, LB_MID),
                ColorSequenceKeypoint.new(1.00, LB_SOFT),
            })
            ag.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0.00, 0.25),
                NumberSequenceKeypoint.new(0.40, 0.50),
                NumberSequenceKeypoint.new(0.75, 0.45),
                NumberSequenceKeypoint.new(1.00, 0.30),
            })
        end
    end
end)

print("[MAY HUB TP BATS] Ready. Left menu: Movement | Combat | Performance | Mechanics | Settings")
print("[MAY HUB] Target HUD loaded with MAY.VS branding.")

print("[MAY HUB] Visuals include Headless, Korblox, and the custom skin preview.")
print("[MAY HUB] Auto Carry Switch: switches to carry speed near an animal.")

    task.spawn(function()
        while task.wait(5) do
            pcall(requestSave)
        end
    end)
end

-- ============================================================
-- NOVA INTRO: card escuro, borda branca arredondada, loading
-- ============================================================
local TweenService = game:GetService("TweenService")

local function playIntro(onDone)
    local pg = LP and (LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 10))
    if not pg then pcall(onDone) return end
    local old = pg:FindFirstChild("MayDuelsIntro")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MayDuelsIntro"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg

    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
    bg.BackgroundTransparency = 1
    bg.BorderSizePixel = 0
    bg.ZIndex = 1
    bg.Parent = gui

    -- Card quadrado com cantos arredondados e contorno branco
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(0, 0)
    card.BackgroundColor3 = Color3.fromRGB(45, 205, 255)
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.ZIndex = 2
    card.ClipsDescendants = true
    card.Parent = bg
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 14)
    cardCorner.Parent = card
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(255, 255, 255)
    cardStroke.Thickness = 1.6
    cardStroke.Transparency = 0.15
    cardStroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.AnchorPoint = Vector2.new(0.5, 0.5)
    title.Position = UDim2.fromScale(0.5, 0.35)
    title.Size = UDim2.new(1, 18, 0, 206)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "Mystery.Vs"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextStrokeColor3 = Color3.fromRGB(150, 150, 150)
    title.TextStrokeTransparency = 0.3
    title:SetAttribute("MysteryVsGlowText", true)
    title.TextScaled = true
    title.TextWrapped = false
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.TextTransparency = 1
    title.ZIndex = 3
    title.Parent = card
    local titleStroke = Instance.new("UIStroke")
    titleStroke.Name = "MysteryVsGlowStroke"
    titleStroke.Color = Color3.fromRGB(160, 160, 160)
    titleStroke.Thickness = 1.8
    titleStroke.Transparency = 0.05
    titleStroke.LineJoinMode = Enum.LineJoinMode.Round
    titleStroke.Parent = title
    local introTitleLimit = Instance.new("UITextSizeConstraint")
    introTitleLimit.MinTextSize = 76
    introTitleLimit.MaxTextSize = 176
    introTitleLimit.Parent = title

    local sub = Instance.new("TextLabel")
    sub.Name = "Subtitle"
    sub.AnchorPoint = Vector2.new(0.5, 0.5)
    sub.Position = UDim2.new(0.5, 0, 0.57, 0)
    sub.Size = UDim2.new(0.9, 0, 0, 16)
    sub.BackgroundTransparency = 1
    sub.Font = Enum.Font.Gotham
    sub.Text = "v2.1.4"
    sub.TextColor3 = Color3.fromRGB(255, 255, 255)
    sub.TextSize = 13
    sub.TextTransparency = 1
    sub.ZIndex = 3
    sub.Parent = card

    -- Barra de carregamento: quadrado com cantos arredondados + contorno branco
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.AnchorPoint = Vector2.new(0.5, 0.5)
    barBg.Position = UDim2.new(0.5, 0, 0.74, 0)
    barBg.Size = UDim2.new(0.72, 0, 0, 10)
    barBg.BackgroundColor3 = Color3.fromRGB(45, 205, 255)
    barBg.BorderSizePixel = 0
    barBg.BackgroundTransparency = 1
    barBg.ZIndex = 3
    barBg.Parent = card
    local barBgCorner = Instance.new("UICorner")
    barBgCorner.CornerRadius = UDim.new(0, 5)
    barBgCorner.Parent = barBg
    local barBgStroke = Instance.new("UIStroke")
    barBgStroke.Color = Color3.fromRGB(255, 255, 255)
    barBgStroke.Thickness = 1
    barBgStroke.Transparency = 1
    barBgStroke.Parent = barBg

    local barFill = Instance.new("Frame")
    barFill.Name = "Fill"
    barFill.AnchorPoint = Vector2.new(0, 0.5)
    barFill.Position = UDim2.new(0, 2, 0.5, 0)
    barFill.Size = UDim2.new(0, 0, 1, -4)
    barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    barFill.BorderSizePixel = 0
    barFill.ZIndex = 4
    barFill.Parent = barBg
    local barFillCorner = Instance.new("UICorner")
    barFillCorner.CornerRadius = UDim.new(0, 4)
    barFillCorner.Parent = barFill

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.AnchorPoint = Vector2.new(0.5, 0.5)
    status.Position = UDim2.new(0.5, 0, 0.86, 0)
    status.Size = UDim2.new(0.9, 0, 0, 14)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.Text = "Carregando..."
    status.TextColor3 = Color3.fromRGB(255, 255, 255)
    status.TextSize = 11
    status.TextTransparency = 1
    status.ZIndex = 3
    status.Parent = card

    task.spawn(function()
        local t = TweenService
        -- fade do fundo + abertura do card
        t:Create(bg, TweenInfo.new(0.35), {BackgroundTransparency = 0.35}):Play()
        t:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(360, 260)}):Play()
        task.wait(0.4)
        t:Create(title, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
        t:Create(sub, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
        t:Create(barBg, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
        t:Create(barBgStroke, TweenInfo.new(0.3), {Transparency = 0.25}):Play()
        t:Create(status, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
        task.wait(0.35)

        local steps = { "Carregando modulos...", "Aplicando config...", "Quase la..." }
        local fill = t:Create(barFill, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            {Size = UDim2.new(1, -4, 1, -4)})
        fill:Play()
        for _, txt in ipairs(steps) do
            status.Text = txt
            task.wait(0.5)
        end
        fill.Completed:Wait()
        task.wait(0.25)

        -- sai: menu aparece, card some
        pcall(onDone)
        t:Create(title, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        t:Create(sub, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        t:Create(status, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        t:Create(barBg, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        t:Create(barBgStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
        t:Create(barFill, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        t:Create(cardStroke, TweenInfo.new(0.35), {Transparency = 1}):Play()
        t:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1}):Play()
        t:Create(bg, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        task.wait(0.45)
        gui:Destroy()
    end)
end
-- ============================================================
-- BOOT: run Main GUI + force Ace-style intro
-- ============================================================
_G._K7Main = Main
if not _G.SevenUpDuelsV2_MainExecuted then
    _G._K7IntroHidingUI = false
    local function boot()
        local ok, err = pcall(function()
            if not LP then LP = Players.LocalPlayer or Players:WaitForChild("LocalPlayer") end
            LP:WaitForChild("PlayerGui", 10)
            Main()
            local pg = LP:FindFirstChild("PlayerGui")
            if _G._K7RemoveUILines and pg then
                for _,guiName in ipairs({"SevenUpDuelsV2","AutoGrab"}) do
                    local ownedGui=pg:FindFirstChild(guiName)
                    if ownedGui then pcall(_G._K7RemoveUILines,ownedGui) end
                end
            end
        end)
        if not ok then
            warn("[MAY duels] Main() error:", err)
        else
            print("[MAY duels] Main GUI loaded")
        end
    end
    boot()

    task.spawn(function()
        task.wait(0.4)
        local tries = 0
        while tries < 50 do
            tries = tries + 1
            local pg = LP and LP:FindFirstChild("PlayerGui")
            local gui = pg and pg:FindFirstChild("SevenUpDuelsV2")
            local mo = gui and gui:FindFirstChild("MainOuter")
            if mo then
                _G._K7MainOuter = mo
                break
            end
            task.wait(0.1)
        end
        local function revealUI()
            _introEnabled = false
            _G._K7IntroHidingUI=false
            local skippedFrame=_G._K7MainOuter
            if skippedFrame then skippedFrame.Visible=not (State and State.guiVisible==false) end
            for _,wrapper in pairs(stackWrappers or {}) do
                if wrapper then wrapper.Visible=not (State and State.stackButtonsHidden) end
            end
            if autoGrabModule and autoGrabModule.showUI then pcall(autoGrabModule.showUI,false) end
        end
        pcall(revealUI)
    end)
end
end)()

-- ============================================================
-- BRAINROT HOLD INTRO: DON'T ENTER -> ENTER (mensagem somente)
-- ============================================================
do
    local introGeneration = 0
    local wasHoldingBrainrot = false
    local activeIntroGui = nil

    local function isHoldingBrainrot()
        if _G.AceSafeModeHoldingBrainrot then
            local ok, carrying = pcall(_G.AceSafeModeHoldingBrainrot)
            if ok and carrying then return true end
        end

        local char = LP and LP.Character
        if not char then return false end
        for _, child in ipairs(char:GetChildren()) do
            local name = tostring(child.Name or ""):lower()
            if (child:IsA("Tool") or child:IsA("Model")) and
               (name:find("brainrot", 1, true) or name:find("animal", 1, true) or
                name:find("carry", 1, true) or name:find("grab", 1, true) or
                name:find("steal", 1, true) or name:find("hold", 1, true)) then
                return true
            end
        end
        return false
    end

    local function playBrainrotIntro(myGeneration)
        -- O aviso não altera a visibilidade nem o estado do menu.
        if activeIntroGui then pcall(function() activeIntroGui:Destroy() end) end

        local playerGui = LP and (LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui", 5))
        if not playerGui or myGeneration ~= introGeneration or not isHoldingBrainrot()
           or (State and State.informationE01Enabled == false) then return end

        local introGui = Instance.new("ScreenGui")
        introGui.Name = "BrainrotEnterIntro"
        introGui.ResetOnSpawn = false
        introGui.IgnoreGuiInset = true
        introGui.DisplayOrder = 1000000
        introGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        introGui.Parent = playerGui
        activeIntroGui = introGui

        local strip = Instance.new("Frame")
        strip.Name = "EnterStrip"
        strip.AnchorPoint = Vector2.new(0.5, 0.5)
        strip.Position = UDim2.new(0.5, 0, -0.18, 0)
        strip.BackgroundColor3 = Color3.fromRGB(55, 205, 230)
        strip.BackgroundTransparency = 0
        strip.BorderSizePixel = 0
        strip.ClipsDescendants = false
        strip.ZIndex = 2
        strip.Parent = introGui
        Instance.new("UICorner", strip).CornerRadius = UDim.new(1, 0)
        local completeBorder = Instance.new("UIStroke", strip)
        completeBorder.Name = "CompleteLoadingBorder"
        completeBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        completeBorder.Color = Color3.fromRGB(4, 85, 110)
        completeBorder.Thickness = 3
        completeBorder.Transparency = 1
        completeBorder.ZIndex = 6

        local scale = Instance.new("UIScale", strip)
        scale.Scale = 0.9

        local stripHeight = 46
        local cornerRadius = 23
        local lineThickness = 3
        local inset = 3

        local function fitStrip()
            local camera = workspace.CurrentCamera
            if not camera or not strip.Parent then return end
            local width = math.floor(camera.ViewportSize.X * 0.33)
            strip.Size = UDim2.fromOffset(width, stripHeight)
        end
        fitStrip()

        local cameraConn
        local function bindCamera(camera)
            if cameraConn then cameraConn:Disconnect(); cameraConn = nil end
            if camera then cameraConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitStrip) end
        end
        bindCamera(workspace.CurrentCamera)

        local label = Instance.new("TextLabel")
        label.Name = "EnterLabel"
        label.Size = UDim2.new(1, -32, 1, -16)
        label.Position = UDim2.fromOffset(16, 8)
        label.BackgroundTransparency = 1
        label.Text = "DON'T ENTER"
        label.TextColor3 = Color3.fromRGB(4, 85, 110)
        label.TextTransparency = 0
        label.Font = Enum.Font.GothamBlack
        label.TextScaled = true
        label.TextWrapped = true
        label.ZIndex = 5
        label.Parent = strip
        local textLimit = Instance.new("UITextSizeConstraint", label)
        textLimit.MinTextSize = 10
        textLimit.MaxTextSize = 16


        local function stillValid()
            return myGeneration == introGeneration and introGui.Parent ~= nil and isHoldingBrainrot()
                and not (State and State.informationE01Enabled == false)
        end
        local function abortIfReleased()
            if stillValid() then return false end
            if cameraConn then cameraConn:Disconnect(); cameraConn = nil end
            if introGui.Parent then introGui:Destroy() end
            if activeIntroGui == introGui then activeIntroGui = nil end
            return true
        end

        local arrival = TweenService:Create(strip, TweenInfo.new(0.52, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.fromScale(0.5, 0.12)
        })
        TweenService:Create(scale, TweenInfo.new(0.52, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        arrival:Play()
        arrival.Completed:Wait()
        if abortIfReleased() then return end

        -- Linha continua de carregamento, preenchida da esquerda para a direita.
        local revealTime = 1.9
        local DARK_CYAN = Color3.fromRGB(4, 85, 110)
        local track = Instance.new("Frame", strip)
        track.Name = "LoadingTrack"
        track.AnchorPoint = Vector2.new(0.5, 1)
        track.Position = UDim2.new(0.5, 0, 1, -6)
        track.Size = UDim2.new(1, -26, 0, lineThickness)
        track.BackgroundColor3 = Color3.fromRGB(95, 225, 240)
        track.BackgroundTransparency = 0.2
        track.BorderSizePixel = 0
        track.ClipsDescendants = true
        track.ZIndex = 6
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local lineFill = Instance.new("Frame", track)
        lineFill.Name = "LoadingLine"
        lineFill.Size = UDim2.new(0, 0, 1, 0)
        lineFill.BackgroundColor3 = DARK_CYAN
        lineFill.BorderSizePixel = 0
        lineFill.ZIndex = 7
        Instance.new("UICorner", lineFill).CornerRadius = UDim.new(1, 0)

        local elapsed = 0
        while elapsed < revealTime do
            lineFill.Size = UDim2.new(math.clamp(elapsed / revealTime, 0, 1), 0, 1, 0)
            elapsed = elapsed + task.wait()
            if abortIfReleased() then return end
        end
        lineFill.Size = UDim2.new(1, 0, 1, 0)
        completeBorder.Transparency = 0



        label.Text = "ENTER"
        label.TextTransparency = 1
        TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        task.wait(0.3)
        if abortIfReleased() then return end

        TweenService:Create(scale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 1.35}):Play()
        TweenService:Create(strip, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
        TweenService:Create(label, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
        TweenService:Create(completeBorder, TweenInfo.new(0.25), {Transparency = 1}):Play()
        task.wait(0.4)

        if cameraConn then cameraConn:Disconnect(); cameraConn = nil end
        if introGui.Parent then introGui:Destroy() end
        if activeIntroGui == introGui then activeIntroGui = nil end
    end

    -- Only starts on the transition from not holding to holding the pet.
    task.spawn(function()
        while _G.SevenUpDuelsV2_Running do
            local holding = isHoldingBrainrot()
            local shouldShow = holding and not (State and State.informationE01Enabled == false)
            if shouldShow and not wasHoldingBrainrot then
                introGeneration = introGeneration + 1
                local thisGeneration = introGeneration
                task.spawn(function() playBrainrotIntro(thisGeneration) end)
            elseif not shouldShow and wasHoldingBrainrot then
                introGeneration = introGeneration + 1
                if activeIntroGui then
                    pcall(function() activeIntroGui:Destroy() end)
                    activeIntroGui = nil
                end
            end
            wasHoldingBrainrot = shouldShow
            task.wait(0.1)
        end
    end)
end

-- ============================================================
-- IMAGE STRIPPER: removes every image from the 7up UI
-- ============================================================
task.spawn(function()
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local pg = lp and (lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 10))
    if not pg then return end

    local function strip(obj)
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            -- Keep the hub background artwork and intentional glow assets
            local n = obj.Name or ""
            if n == "BgImage" or n == "TopBgImage" or n == "SodaGlow" or n == "MusicBackground" then
                if n == "BgImage" then
                    pcall(function()
                        obj.Image = "rbxassetid://137970714521556"
                        obj.ImageTransparency = 0
                        obj.BackgroundTransparency = 1
                        obj.Visible = true
                        obj.ScaleType = Enum.ScaleType.Crop
                    end)
                end
                return
            end
            pcall(function()
                obj.Image = ""
                obj.ImageTransparency = 1
                obj.BackgroundTransparency = 1
                obj.Visible = false
            end)
        elseif obj:IsA("Decal") or obj:IsA("Sky") then
            return
        end
    end

    local function isOurs(gui)
        local n = gui.Name or ""
        return n == "SevenUpDuelsV2" or n:find("K7") or n:find("SevenUp") or n:find("MayDuels")
            or n:find("StealBar") or n:find("Stack")
    end

    local function scan(root)
        strip(root)
        for _, d in ipairs(root:GetDescendants()) do strip(d) end
        root.DescendantAdded:Connect(strip)
    end

    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and isOurs(gui) then pcall(scan, gui) end
    end
    pg.ChildAdded:Connect(function(gui)
        if gui:IsA("ScreenGui") and isOurs(gui) then
            task.defer(function() pcall(scan, gui) end)
        end
    end)
end)

-- === No auto-translate (mantem os textos do Hub em ingles) ===
task.spawn(function()
    local function killLocalize(root)
        if not root then return end
        pcall(function()
            if root:IsA("GuiBase") or root:IsA("LayerCollector") or root:IsA("GuiObject") then
                root.AutoLocalize = false
            end
        end)
        for _, d in ipairs(root:GetDescendants()) do
            pcall(function()
                if d:IsA("GuiObject") or d:IsA("LayerCollector") then d.AutoLocalize = false end
            end)
        end
    end
    while true do
        pcall(function()
            local pg = LP:FindFirstChildOfClass("PlayerGui")
            if pg then
                for _, g in ipairs(pg:GetChildren()) do
                    if g:IsA("LayerCollector") then killLocalize(g) end
                end
            end
            local ok, cg = pcall(function() return game:GetService("CoreGui") end)
            if ok and cg then
                for _, g in ipairs(cg:GetChildren()) do
                    if g:IsA("LayerCollector") then pcall(killLocalize, g) end
                end
            end
            local ch = LP.Character
            if ch then
                for _, d in ipairs(ch:GetDescendants()) do
                    if d:IsA("BillboardGui") then killLocalize(d) end
                end
            end
        end)
        task.wait(3)
    end
end)



-- ============================================================
-- BACKGROUND ENFORCER: keeps the hub artwork fully visible
-- ============================================================
task.spawn(function()
    local FIXED_BG = "rbxassetid://137970714521556"
    while _G.SevenUpDuelsV2_Running do
        pcall(function()
            local pg = LP and LP:FindFirstChild("PlayerGui")
            local gui = pg and pg:FindFirstChild("SevenUpDuelsV2")
            local mo = gui and gui:FindFirstChild("MainOuter")
            if not mo then return end

            local bg = mo:FindFirstChild("BgImage") or mo:FindFirstChild("BgImage", true)
            if bg and bg:IsA("ImageLabel") then
                bg.Image = FIXED_BG
                bg.ImageTransparency = 0
                bg.BackgroundTransparency = 1
                bg.Visible = true
                bg.ImageColor3 = Color3.fromRGB(255,255,255)
                bg.ScaleType = Enum.ScaleType.Crop
                local g = bg:FindFirstChildOfClass("UIGradient")
                if g then g:Destroy() end
            end

            local atmo = mo:FindFirstChild("GradientAtmosphere")
            if atmo then atmo.BackgroundTransparency = 0.97 end

            -- Keep every slider/option row black with white text, after legacy theme updates.
            for _, obj in ipairs(mo:GetDescendants()) do
                if obj:IsA("Frame") and (
                    obj:GetAttribute("AlwaysCyanOptionBar") == true
                    or obj:GetAttribute("AlwaysBlackOptionBar") == true
                    or obj:GetAttribute("MysteryToggleRow") == true
                ) then
                    obj.BackgroundColor3 = Color3.fromRGB(0,0,0)
                    obj.BackgroundTransparency = 0
                    for _, child in ipairs(obj:GetDescendants()) do
                        if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                            child.TextColor3 = Color3.fromRGB(255,255,255)
                            child.TextStrokeTransparency = 1
                        elseif child:IsA("UIStroke") then
                            child.Color = Color3.fromRGB(75,75,75)
                            child.Transparency = 0.15
                        elseif (child:IsA("Frame") or child:IsA("TextButton"))
                            and child.Name ~= "SevenUpActivator"
                            and child.Name ~= "ToggleActiveFill"
                            and child.Name ~= "SodaCap"
                            and child.BackgroundTransparency < 1 then
                            child.BackgroundColor3 = Color3.fromRGB(0,0,0)
                        end
                    end
                end

                -- Feature stack buttons (BAT/TP/etc.) are black with white labels.
                if obj:IsA("TextButton") and string.sub(obj.Name,1,9) == "StackBtn_" then
                    obj.BackgroundColor3 = Color3.fromRGB(0,0,0)
                    obj.BackgroundTransparency = 0
                    obj.TextColor3 = Color3.fromRGB(255,255,255)
                    local featureLabel = obj:FindFirstChild("StackFeatureLabel")
                    if featureLabel and featureLabel:IsA("TextLabel") then
                        featureLabel.TextColor3 = Color3.fromRGB(255,255,255)
                    end
                    for _, child in ipairs(obj:GetChildren()) do
                        if child:IsA("Frame") and (child.Name == "SodaCanSurface" or child.Name == "IndentedCanTop") then
                            child.BackgroundColor3 = Color3.fromRGB(0,0,0)
                            child.BackgroundTransparency = 0
                            local grad = child:FindFirstChildWhichIsA("UIGradient")
                            if grad then grad.Color = ColorSequence.new(Color3.fromRGB(0,0,0)) end
                        end
                    end
                elseif obj:IsA("TextLabel") and obj.Name == "StackFeatureLabel" then
                    obj.TextColor3 = Color3.fromRGB(255,255,255)
                end

                -- Preserve the original white/blue styling of unrelated UI text.
            end
        end)
        task.wait(0.8)
    end
end)

-- GUARDA ANTI-RESET AO SEGURAR O BRAINROT
-- Enquanto o Brainrot estiver na mao, qualquer sequencia de reset
-- (Insta Reset) e cancelada e nunca pode ser armada.
-- ============================================================
task.spawn(function()
    while true do
        local ok, holding = pcall(function()
            return _G.AceSafeModeHoldingBrainrot and _G.AceSafeModeHoldingBrainrot()
        end)
        if ok and holding then
            pcall(function() if _G.AceStopInstantReset then _G.AceStopInstantReset() end end)
            local char = LP and LP.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function()
                    if hum.HipHeight > 100 then hum.HipHeight = 2 end
                end)
            end
        end
        task.wait(0.1)
    end
end)


-- ============================================================
-- FINAL BLACK THEME ENFORCER: navigation tabs + BAT/TP controls
-- Runs after the original hover/selection/theme callbacks so they
-- cannot restore cyan/blue colors.
-- ============================================================
task.spawn(function()
    local BLACK = Color3.fromRGB(0, 0, 0)
    local WHITE = Color3.fromRGB(255, 255, 255)
    local DARK_EDGE = Color3.fromRGB(55, 55, 55)

    local function forceTab(tab)
        if not tab or not tab:IsA("TextButton") then return end
        tab.BackgroundColor3 = BLACK
        tab.BackgroundTransparency = 0
        tab.AutoButtonColor = false
        tab.TextColor3 = WHITE
        for _, child in ipairs(tab:GetDescendants()) do
            if child:IsA("Frame") then
                if child.Name == "GradientSurface" or child.Name == "SelectedSquare" then
                    child.BackgroundColor3 = BLACK
                    child.BackgroundTransparency = 0
                    local grad = child:FindFirstChildWhichIsA("UIGradient")
                    if grad then grad.Color = ColorSequence.new(BLACK) end
                end
            elseif child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                child.TextColor3 = WHITE
            elseif child:IsA("UIStroke") then
                child.Color = DARK_EDGE
            end
        end
    end

    local function scanRoot(root)
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("TextButton") then
                if obj.Name == "SevenUpNavTab" then
                    forceTab(obj)
                elseif string.sub(obj.Name, 1, 9) == "StackBtn_" then
                    obj.BackgroundColor3 = BLACK
                    obj.BackgroundTransparency = 0
                    obj.TextColor3 = WHITE
                    local surface = obj:FindFirstChild("SodaCanSurface")
                    if surface and surface:IsA("Frame") then
                        surface.BackgroundColor3 = BLACK
                        local grad = surface:FindFirstChildWhichIsA("UIGradient")
                        if grad then grad.Color = ColorSequence.new(BLACK) end
                    end
                    local neck = obj:FindFirstChild("IndentedCanTop")
                    if neck and neck:IsA("Frame") then
                        neck.BackgroundColor3 = BLACK
                        local grad = neck:FindFirstChildWhichIsA("UIGradient")
                        if grad then grad.Color = ColorSequence.new(BLACK) end
                    end
                    local label = obj:FindFirstChild("StackFeatureLabel")
                    if label and label:IsA("TextLabel") then label.TextColor3 = WHITE end
                end
            elseif obj:IsA("Frame") and obj.Name == "MechanicsNavigationBar" then
                obj.BackgroundColor3 = BLACK
                obj.BackgroundTransparency = 0
                local grad = obj:FindFirstChildWhichIsA("UIGradient")
                if grad then grad.Color = ColorSequence.new(BLACK) end
            end
        end
    end

    while true do
        pcall(function()
            local playerGui = LP and LP:FindFirstChildOfClass("PlayerGui")
            if playerGui then scanRoot(playerGui) end
            local ok, coreGui = pcall(function() return game:GetService("CoreGui") end)
            if ok and coreGui then scanRoot(coreGui) end
        end)
        RunService.RenderStepped:Wait()
    end
end)
