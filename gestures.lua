--[[
G502 X Gestures v3 - real-time version for Logitech G HUB

Hold G9 and flick the mouse within the initial detection window:
  Right -> Ctrl+Right (right desktop)
  Left  -> Ctrl+Left  (left desktop)
  Up    -> Ctrl+Up    (Mission Control)
  Down  -> Ctrl+Down  (Application Windows)
  Release without a detected gesture -> Ctrl+Up (Mission Control)

This restores the original script's real-time detection: sample every
5 ms for up to 100 ms after G9 is pressed. Fire as soon as a movement
threshold is exceeded, then ignore further movement until G9 is released.
G9 cannot be queried using the documented IsMouseButtonPressed API,
so polling is bounded and there is no loop waiting indefinitely for release.
Gesture state resets on profile changes and errors.
Cleanup attempts to release only keys this script attempted to press.
If a release call fails, the key stays tracked for a later cleanup retry.
Shortcut delivery separates the arrow key-up from the Ctrl key-up and
repeats key-up once after a short delay. No second shortcut is sent.
Optional debug logging records gesture events and shortcut delivery.
]]--

------------------------------- SETTINGS --------------------------------
local gestureButtonNumber = 9
local minimalHorizontalMovement = 50
local minimalVerticalMovement = 50
local gestureChecks = 20
local sampleIntervalMs = 5
local modifierLeadMs = 15
local keyHoldMs = 25
local keyReleaseGapMs = 10
local keyUpRetryMs = 40
local debugLogging = false -- Set true to log events and shortcut delivery.
-------------------------------------------------------------------------

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
    -- Logging must not interrupt key cleanup.
    pcall(OutputLogMessage, "[gesture] %s\n", tostring(message))
end

local function resetGestureState()
    gestureActive = false
    gestureFired = false
    startX, startY = 0, 0
end

local function releasePressedKeys()
    -- Release the shortcut key before its modifier. A failed release
    -- must not prevent attempts to release the remaining keys.
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
            -- Even a Sleep error must not skip the modifier's key-up.
            local waited, sleepError = pcall(Sleep, keyReleaseGapMs)
            if not waited then reportError(sleepError) end
        end
    end
    return #pressedKeys == 0
end

local function pressTrackedKey(key)
    -- Track before calling the API, in case it sends input then errors.
    pressedKeys[#pressedKeys + 1] = key
    PressKey(key)
end

local function pressTwoKeys(k1, k2)
    pressTrackedKey(k1)
    Sleep(modifierLeadMs)
    pressTrackedKey(k2)
    Sleep(keyHoldMs)
    releasePressedKeys()

    -- An API call returning normally does not prove macOS has processed
    -- key-up. Repeat only this chord's key-up, without pressing any key.
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
    -- Match the original 100 ms window. A bounded loop avoids waiting
    -- forever for a release event that this handler cannot process yet.
    for _ = 1, gestureChecks do
        Sleep(sampleIntervalMs)
        local x, y = GetMousePosition()
        local dx, dy = x - startX, y - startY
        local key = classifyGesture(dx, dy)
        if key then
            gestureFired = true -- Set before keyboard calls, not on release.
            sendGesture(key, dx, dy, "while held")
            return -- Never sample again after firing this gesture.
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

    -- Retry any failed cleanup before allowing another shortcut.
    if not releasePressedKeys() then
        resetGestureState()
        return
    end

    if event == "MOUSE_BUTTON_PRESSED" then
        if gestureActive then return end -- Ignore a duplicate press.
        local x, y = GetMousePosition()
        startX, startY = x, y
        gestureActive = true
        gestureFired = false
        watchGesture()
        return
    end

    if not gestureActive then return end
    local alreadyFired = gestureFired
    resetGestureState() -- End this gesture before calling keyboard APIs.
    if not alreadyFired then
        -- Match the original click action. Do not classify late movement
        -- on release or replay a gesture that already fired while held.
        sendGesture("up", 0, 0, "click on release")
    end
end

function OnEvent(event, arg, family)
    local ok, err = pcall(handleEvent, event, arg)
    if not ok then
        resetGestureState()
    end
    -- Always finish with cleanup, including a retry if normal key release
    -- failed. Keys that still fail remain tracked for the next event.
    releasePressedKeys()
    if not ok then
        reportError(err)
    end
end
