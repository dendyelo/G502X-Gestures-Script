local gestureButtonNumber = 9
local minimalHorizontalMovement = 50
local minimalVerticalMovement = 50
local gestureChecks = 20
local sampleIntervalMs = 5
local modifierLeadMs = 15
local keyHoldMs = 25
local keyReleaseGapMs = 10
local keyUpRetryMs = 40
local debugLogging = false

local gestureActive = false
local gestureFired = false
local startX, startY = 0, 0
local pressedKeys = {}

local function debugLog(format, ...)
    if debugLogging then
        pcall(OutputLogMessage, "[gesture] " .. format .. "\n", ...)
    end
end

local function reportError(message)
    pcall(OutputLogMessage, "[gesture] %s\n", tostring(message))
end

local function resetGestureState()
    gestureActive = false
    gestureFired = false
    startX, startY = 0, 0
end

local function releasePressedKeys()
    for i = #pressedKeys, 1, -1 do
        local key = pressedKeys[i]
        local ok, err = pcall(ReleaseKey, key)
        if ok then
            table.remove(pressedKeys, i)
            debugLog("KEY-UP %s (API returned)", key)
        else
            reportError("could not release " .. key .. ": " .. tostring(err))
        end
        if i > 1 then
            local waited, sleepError = pcall(Sleep, keyReleaseGapMs)
            if not waited then reportError(sleepError) end
        end
    end
    return #pressedKeys == 0
end

local function pressTrackedKey(key)
    pressedKeys[#pressedKeys + 1] = key
    PressKey(key)
end

local function pressTwoKeys(k1, k2)
    pressTrackedKey(k1)
    Sleep(modifierLeadMs)
    pressTrackedKey(k2)
    Sleep(keyHoldMs)
    releasePressedKeys()

    Sleep(keyUpRetryMs)
    pressedKeys = { k1, k2 }
    debugLog("RETRY KEY-UP for %s + %s", k1, k2)
    releasePressedKeys()
end

local function classifyGesture(dx, dy)
    if math.abs(dx) > math.abs(dy) then
        if dx > minimalHorizontalMovement then
            return "right"
        elseif dx < -minimalHorizontalMovement then
            return "left"
        end
    end
    if dy < -minimalVerticalMovement then
        return "down"
    elseif dy > minimalVerticalMovement then
        return "up"
    end
    return nil
end

local function sendGesture(key, dx, dy, when)
    debugLog("SEND Ctrl+%s (dx=%.0f, dy=%.0f, %s)", key, dx, dy, when)
    pressTwoKeys("lctrl", key)
    debugLog("FINISHED; pending key-ups=%d", #pressedKeys)
end

local function watchGesture()
    for _ = 1, gestureChecks do
        Sleep(sampleIntervalMs)
        local x, y = GetMousePosition()
        local dx, dy = x - startX, y - startY
        local key = classifyGesture(dx, dy)
        if key then
            gestureFired = true
            sendGesture(key, dx, dy, "while held")
            return
        end
    end
end

local function handleEvent(event, arg)
    if event == "PROFILE_ACTIVATED" or event == "PROFILE_DEACTIVATED" then
        debugLog("%s", event)
        resetGestureState()
        releasePressedKeys()
        return
    end

    if arg ~= gestureButtonNumber then return end
    if event ~= "MOUSE_BUTTON_PRESSED" and event ~= "MOUSE_BUTTON_RELEASED" then
        return
    end
    debugLog("%s G%d; active=%s", event, arg, tostring(gestureActive))

    if not releasePressedKeys() then
        resetGestureState()
        return
    end

    if event == "MOUSE_BUTTON_PRESSED" then
        if gestureActive then return end
        local x, y = GetMousePosition()
        startX, startY = x, y
        gestureActive = true
        gestureFired = false
        watchGesture()
        return
    end

    if not gestureActive then return end
    local alreadyFired = gestureFired
    resetGestureState()
    if not alreadyFired then
        sendGesture("up", 0, 0, "click on release")
    end
end

function OnEvent(event, arg, family)
    local ok, err = pcall(handleEvent, event, arg)
    if not ok then
        resetGestureState()
    end
    releasePressedKeys()
    if not ok then
        reportError(err)
    end
end
