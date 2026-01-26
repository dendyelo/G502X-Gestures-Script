gestureButtonNumber = 9
minimalHorizontalMovement = 50
minimalVerticalMovement = 50
delay = 10

isDetecting = false
startX, startY = 0, 0
gestureMade = false
checkCount = 0
function OnEvent(event, arg)
    if event == "MOUSE_BUTTON_PRESSED" and arg == gestureButtonNumber then
        isDetecting = true
        gestureMade = false
        checkCount = 0
        startX, startY = GetMousePosition()
        while isDetecting do
            checkCount = checkCount + 1
            local x, y = GetMousePosition()
            local dx = x - startX
            local dy = y - startY
            -- PRIORITAS HORIZONTAL
            if math.abs(dx) > math.abs(dy) then
                if dx > minimalHorizontalMovement then
                    pressTwoKeys("lctrl", "right")
                    gestureMade = true
                    break
                elseif dx < -minimalHorizontalMovement then
                    pressTwoKeys("lctrl", "left")
                    gestureMade = true
                    break
                end
            end
            -- VERTICAL
            if dy < -minimalVerticalMovement then
                pressTwoKeys("lctrl", "down")
                gestureMade = true
                break
            elseif dy > minimalVerticalMovement then
                pressTwoKeys("lctrl", "up")
                gestureMade = true
                break
            end
            if checkCount > 20 then
                break
            end
            Sleep(5)
        end
        isDetecting = false
    end
    if event == "MOUSE_BUTTON_RELEASED" and arg == gestureButtonNumber then
        if not gestureMade then
            pressTwoKeys("lctrl", "up")
        end
    end
end
function pressTwoKeys(k1, k2)
    PressKey(k1)
    Sleep(delay)
    PressKey(k2)
    Sleep(delay)
    ReleaseKey(k2)
    ReleaseKey(k1)
end
