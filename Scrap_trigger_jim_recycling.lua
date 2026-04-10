-- ─────────────────────────────────────────
--  Scrap Trigger Widget
--  DELETE key  →  open / close
--  X button   →  close
--  Drag via header, left-click to toggle
-- ─────────────────────────────────────────

local isVisible    = true
local isActive     = false
local triggerCount = 0
local loopSpeed    = 0     -- ms delay (1000 = slowest, 0 = fastest)
local loopLimit    = 0     -- 0 = infinite, >0 = stop after N loops

-- DELETE key debounce (same pattern as Darkmatter)
local lastKeyPress = 0

-- Widget top-left position (normalised 0.0 – 1.0)
local wx = 0.05
local wy = 0.05

-- Dimensions
local WW    = 0.135
local HDR_H = 0.042
local BOD_H = 0.168

-- Drag state (header)
local isDragging         = false
local dragOffX, dragOffY = 0.0, 0.0

-- Drag state (slider)
local isSliderDragging = false

-- ── Helpers ───────────────────────────────────────────────────────────────

local function getCursor()
    return GetDisabledControlNormal(0, 239),
           GetDisabledControlNormal(0, 240)
end

local function inBounds(lx, ly, w, h)
    local mx, my = getCursor()
    return mx >= lx and mx <= lx + w and my >= ly and my <= ly + h
end

local function dRect(lx, ly, w, h, r, g, b, a)
    DrawRect(lx + w * 0.5, ly + h * 0.5, w, h, r, g, b, a)
end

local function dText(str, x, y, scale, r, g, b, a, align)
    SetTextFont(7)
    SetTextScale(0.0, scale)
    SetTextColour(r, g, b, a)
    SetTextJustification(align or 1)
    SetTextEntry("STRING")
    AddTextComponentString(tostring(str))
    DrawText(x, y)
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(v, hi))
end

-- ── Trigger loop ──────────────────────────────────────────────────────────

local function startLoop()
    Citizen.CreateThread(function()
        while isActive do
            -- Stop if limit reached
            if loopLimit > 0 and triggerCount >= loopLimit then
                isActive = false
                break
            end
            TriggerServerEvent("jim-recycle:server:getScrapReward")
            triggerCount = triggerCount + 1
            Citizen.Wait(loopSpeed)
        end
    end)
end

-- ── Open keyboard to set loop limit (runs in own thread to not block draw) ──

local function promptLoopLimit()
    Citizen.CreateThread(function()
        DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP1", "", tostring(loopLimit == 0 and "" or loopLimit), "", "", "", 6)
        while UpdateOnscreenKeyboard() == 0 do
            Citizen.Wait(0)
        end
        local result = GetOnscreenKeyboardResult()
        if result and result ~= "" then
            local n = tonumber(result)
            if n and n >= 0 then
                loopLimit = math.floor(n)
            end
        end
    end)
end

-- ── Main draw / input thread ──────────────────────────────────────────────

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        -- DELETE key toggle — same debounce pattern as Darkmatter
        if IsControlJustPressed(0, 178) and GetGameTimer() - lastKeyPress > 500 then
            lastKeyPress = GetGameTimer()
            isVisible = not isVisible
            if not isVisible and isActive then
                isActive = false
            end
        end

        if not isVisible then goto continue end

        SetMouseCursorActiveThisFrame()
        EnableControlAction(0, 239, true)
        EnableControlAction(0, 240, true)
        EnableControlAction(0, 237, true)
        EnableControlAction(0, 178, true)

        local mx, my  = getCursor()
        local clicked = IsDisabledControlJustPressed(0, 237)
        local held    = IsDisabledControlPressed(0, 237)

        -- ── Header ───────────────────────────────────────────────────────
        dRect(wx, wy, WW, HDR_H, 28, 28, 28, 235)

        dText("Scrap Trigger", wx + 0.010, wy + 0.011, 0.27, 200, 200, 200, 255, 1)

        -- X close button — tight wrap around the X character
        local xBtnW    = 0.012
        local xBtnH    = 0.016
        local xBtnX    = wx + WW - xBtnW - 0.006
        local xBtnY    = wy + (HDR_H - xBtnH) * 0.5
        local xHovered = inBounds(xBtnX, xBtnY, xBtnW, xBtnH)
        local xColR    = xHovered and 200 or 110
        local xColG    = xHovered and 55  or 35
        local xColB    = xHovered and 55  or 35
        dRect(xBtnX, xBtnY, xBtnW, xBtnH, xColR, xColG, xColB, 220)
        dText("X", xBtnX + xBtnW * 0.5, xBtnY + 0.001, 0.19, 255, 255, 255, 230, 0)

        if clicked and xHovered then
            isVisible = false
            lastKeyPress = GetGameTimer()
            if isActive then isActive = false end
            goto continue
        end

        -- ── Body ─────────────────────────────────────────────────────────
        dRect(wx, wy + HDR_H, WW, BOD_H, 17, 17, 17, 235)

        local pad = 0.010

        -- ── Row 1 – Toggle button (+0.012) ────────────────────────────────
        local btnX = wx + pad
        local btnY = wy + HDR_H + 0.012
        local btnW = WW - pad * 2
        local btnH = 0.036

        if isActive then
            dRect(btnX, btnY, btnW, btnH, 26, 74, 26, 255)
            dText("STOP LOOP",  wx + WW * 0.5, btnY + 0.009, 0.24, 76,  222, 76,  255, 0)
        else
            dRect(btnX, btnY, btnW, btnH, 38, 38, 38, 255)
            dText("START LOOP", wx + WW * 0.5, btnY + 0.009, 0.24, 140, 140, 140, 255, 0)
        end

        -- ── Row 2 – Status indicator (+0.058) ────────────────────────────
        local dotX = wx + 0.012
        local dotY = wy + HDR_H + 0.058
        if isActive then
            dRect(dotX, dotY, 0.006, 0.012, 76,  222, 76, 255)
            dText("Running",  dotX + 0.011, dotY - 0.001, 0.21, 76,  222, 76,  255, 1)
        else
            dRect(dotX, dotY, 0.006, 0.012, 68,  68,  68, 255)
            dText("Inactive", dotX + 0.011, dotY - 0.001, 0.21, 85,  85,  85,  255, 1)
        end

        -- ── Row 3 – Loop limit input (+0.078) ────────────────────────────
        -- Left label
        local limY    = wy + HDR_H + 0.078
        local limitDisplay = loopLimit == 0 and "inf" or tostring(loopLimit)
        dText("Max Loops:", wx + pad, limY, 0.20, 100, 100, 100, 255, 1)

        -- Current value (centre)
        dText(limitDisplay, wx + WW * 0.5, limY, 0.20, 160, 160, 160, 255, 0)

        -- [SET] button (right)
        local setBtnW = 0.028
        local setBtnH = 0.020
        local setBtnX = wx + WW - pad - setBtnW
        local setBtnY = limY - 0.003
        local setHov  = inBounds(setBtnX, setBtnY, setBtnW, setBtnH)
        dRect(setBtnX, setBtnY, setBtnW, setBtnH, setHov and 55 or 38, setHov and 55 or 38, setHov and 55 or 38, 255)
        dText("SET", setBtnX + 0.004, setBtnY + 0.003, 0.19, 160, 160, 160, 255, 1)

        if clicked and not isDragging and setHov then
            promptLoopLimit()
        end

        -- ── Row 4 – Slider label (+0.106) ────────────────────────────────
        local sldPad = 0.012
        local lblY   = wy + HDR_H + 0.106

        dText("Loop Speed",      wx + sldPad,       lblY, 0.20, 100, 100, 100, 255, 1)
        dText(loopSpeed .. "ms", wx + WW - sldPad,  lblY, 0.20, 130, 130, 130, 255, 2)

        -- ── Row 5 – Slider track (+0.124) ────────────────────────────────
        local sldX    = wx + sldPad
        local sldW    = WW - sldPad * 2
        local sldTrkH = 0.006
        local sldHW   = 0.009
        local sldHH   = 0.020
        local sldY    = wy + HDR_H + 0.131

        local t       = 1.0 - (loopSpeed / 1000.0)
        local handleX = sldX + t * sldW - sldHW * 0.5

        dRect(sldX, sldY, sldW, sldTrkH, 45, 45, 45, 255)
        if t > 0 then
            dRect(sldX, sldY, t * sldW, sldTrkH, 76, 160, 76, 255)
        end

        local hR, hG, hB = 180, 180, 180
        if isSliderDragging then hR, hG, hB = 220, 220, 220 end
        dRect(handleX, sldY - (sldHH - sldTrkH) * 0.5, sldHW, sldHH, hR, hG, hB, 255)

        -- ── Row 6 – Loop count centred (+0.150) ───────────────────────────
        dText("Loops: " .. triggerCount,
            wx + WW * 0.5,
            wy + HDR_H + 0.150,
            0.20, 68, 68, 68, 255, 0)

        -- ═══════════════════════════════════════════════════════════════════
        --  INPUT HANDLING
        -- ═══════════════════════════════════════════════════════════════════

        -- ── Header drag ───────────────────────────────────────────────────
        if clicked and inBounds(wx, wy, WW, HDR_H) and not xHovered then
            isDragging = true
            dragOffX   = mx - wx
            dragOffY   = my - wy
        end

        if isDragging then
            if held then
                wx = clamp(mx - dragOffX, 0.0, 1.0 - WW)
                wy = clamp(my - dragOffY, 0.0, 1.0 - HDR_H - BOD_H)
            else
                isDragging = false
            end
        end

        -- ── Slider drag ───────────────────────────────────────────────────
        local sldHitY = sldY - 0.014
        local sldHitH = sldTrkH + 0.028

        if clicked and not isDragging and inBounds(sldX, sldHitY, sldW, sldHitH) then
            isSliderDragging = true
        end

        if isSliderDragging then
            if held then
                local newT = clamp((mx - sldX) / sldW, 0.0, 1.0)
                loopSpeed  = math.floor(((1.0 - newT) * 1000.0) / 50 + 0.5) * 50
            else
                isSliderDragging = false
            end
        end

        -- ── Toggle button ─────────────────────────────────────────────────
        if clicked and not isDragging and not isSliderDragging and not setHov and inBounds(btnX, btnY, btnW, btnH) then
            isActive     = not isActive
            triggerCount = 0
            if isActive then startLoop() end
        end

        ::continue::
    end
end)