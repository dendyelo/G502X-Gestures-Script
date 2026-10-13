-- Run from the repository root: lua tests/gestures_test.lua
-- All G HUB APIs are mocked; this never sends real keyboard or mouse input.
local scriptFile = assert(io.open("gestures.lua", "r"))
local scriptSource = scriptFile:read("*a")
scriptFile:close()
local passed = 0

local function test(name, run)
    local ok, err = pcall(run)
    assert(ok, name .. ": " .. tostring(err))
    passed = passed + 1
    print("PASS " .. name)
end

local function setup()
    local s = {
        x = 1000, y = 1000, time = 0, phase = "idle",
        down = {}, presses = {}, releases = {}, logs = {}, calls = {},
    }
    local function call(api, argument)
        s.calls[api] = (s.calls[api] or 0) + 1
        if s.fail and s.fail(api, argument, s.calls[api]) then
            error("simulated " .. api .. " failure")
        end
    end
    local env = setmetatable({
        GetMousePosition = function()
            call("GetMousePosition")
            if s.positionAt then return s.positionAt(s.time) end
            return s.x, s.y
        end,
        PressKey = function(key)
            s.presses[#s.presses + 1] = { key = key, phase = s.phase, time = s.time }
            s.down[key] = true -- Model input emitted before a possible error.
            call("PressKey", key)
        end,
        ReleaseKey = function(key)
            s.releases[#s.releases + 1] = key
            call("ReleaseKey", key)
            s.down[key] = nil
        end,
        Sleep = function(ms)
            call("Sleep", ms)
            s.time = s.time + ms
        end,
        OutputLogMessage = function(format, ...)
            call("OutputLogMessage")
            s.logs[#s.logs + 1] = string.format(format, ...)
        end,
    }, { __index = _G })
    assert(load(scriptSource, "@gestures.lua", "t", env))()
    function s.event(event, arg)
        s.phase = event
        env.OnEvent(event, arg, "mouse")
        s.phase = "idle"
    end
    function s.flick(dx, dy)
        local x0, y0, t0 = s.x, s.y, s.time
        s.positionAt = function(time)
            if time > t0 then return x0 + dx, y0 + dy end
            return x0, y0
        end
        s.event("MOUSE_BUTTON_PRESSED", 9)
        s.positionAt = nil
        s.x, s.y = x0 + dx, y0 + dy
    end
    return s
end

local function released(s)
    assert(next(s.down) == nil, "a simulated key remains held")
end

local function chord(s, key, phase)
    assert(#s.presses == 2, "expected exactly one shortcut")
    assert(s.presses[1].key == "lctrl", "wrong modifier")
    assert(s.presses[2].key == key, "wrong arrow")
    assert(s.presses[2].phase == phase, "shortcut fired in the wrong event")
    released(s)
end

test("all four gestures fire before G9 release", function()
    local cases = {
        { 100, 0, "right" }, { -100, 0, "left" },
        { 0, 100, "up" }, { 0, -100, "down" },
    }
    for _, movement in ipairs(cases) do
        local s = setup()
        s.flick(movement[1], movement[2])
        chord(s, movement[3], "MOUSE_BUTTON_PRESSED")
        assert(s.presses[2].time == 20, "unexpected key-down timing")
        assert(table.concat(s.releases, ",") == movement[3] .. ",lctrl," .. movement[3] .. ",lctrl",
            "key-up order or retry changed")
        s.event("MOUSE_BUTTON_RELEASED", 9)
        chord(s, movement[3], "MOUSE_BUTTON_PRESSED")
    end
end)

test("swipe down followed by upward or sideways motion cannot fire again", function()
    local s = setup()
    s.flick(0, -100)
    chord(s, "down", "MOUSE_BUTTON_PRESSED")
    local reads = s.calls.GetMousePosition
    s.x, s.y = 2000, 2000
    s.event("MOUSE_MOVE", 9)
    s.event("MOUSE_BUTTON_PRESSED", 9) -- Duplicate while still held.
    s.event("MOUSE_BUTTON_PRESSED", 5)
    s.event("MOUSE_BUTTON_RELEASED", 5)
    s.event("MOUSE_BUTTON_RELEASED", 9)
    s.event("MOUSE_BUTTON_RELEASED", 9) -- Duplicate release.
    chord(s, "down", "MOUSE_BUTTON_PRESSED")
    assert(s.calls.GetMousePosition == reads, "cursor sampled after the first gesture")
end)

test("threshold boundaries and diagonal directions preserve the original mapping", function()
    local values = { -100, -50, -49, 0, 49, 50, 100 }
    for _, dx in ipairs(values) do
        for _, dy in ipairs(values) do
            local expected
            if math.abs(dx) > math.abs(dy) and math.abs(dx) > 50 then
                expected = dx < 0 and "left" or "right"
            elseif math.abs(dy) > 50 then
                expected = dy < 0 and "down" or "up"
            end
            local s = setup()
            s.flick(dx, dy)
            if expected then
                chord(s, expected, "MOUSE_BUTTON_PRESSED")
            else
                assert(#s.presses == 0, "sub-threshold motion fired")
            end
            s.event("MOUSE_BUTTON_RELEASED", 9)
            chord(s, expected or "up", expected and "MOUSE_BUTTON_PRESSED" or "MOUSE_BUTTON_RELEASED")
        end
    end
end)

test("idle polling ends at 100 ms and the click runs only on release", function()
    local s = setup()
    s.event("MOUSE_BUTTON_PRESSED", 9)
    assert(s.time == 100, "polling did not end at its deadline")
    assert(s.calls.GetMousePosition == 21, "unexpected sample count")
    assert(#s.presses == 0, "click fired before release")
    s.event("MOUSE_BUTTON_RELEASED", 9)
    chord(s, "up", "MOUSE_BUTTON_RELEASED")
    assert(#s.logs == 0, "debug output is enabled by default")
end)

test("late motion preserves the original Mission Control fallback", function()
    local s = setup()
    s.event("MOUSE_BUTTON_PRESSED", 9)
    s.x, s.y = 2000, 1000
    s.event("MOUSE_BUTTON_RELEASED", 9)
    chord(s, "up", "MOUSE_BUTTON_RELEASED")
end)

test("a gesture at the final sample still fires before release", function()
    local s = setup()
    s.positionAt = function(time)
        return time >= 100 and 1100 or 1000, 1000
    end
    s.event("MOUSE_BUTTON_PRESSED", 9)
    chord(s, "right", "MOUSE_BUTTON_PRESSED")
    s.event("MOUSE_BUTTON_RELEASED", 9)
    chord(s, "right", "MOUSE_BUTTON_PRESSED")
end)

test("profile changes cancel pending clicks and allow a new gesture", function()
    for _, event in ipairs({ "PROFILE_ACTIVATED", "PROFILE_DEACTIVATED" }) do
        local s = setup()
        s.event("MOUSE_BUTTON_PRESSED", 9)
        s.event(event)
        s.event("MOUSE_BUTTON_RELEASED", 9)
        assert(#s.presses == 0, "cancelled click fired")
        s.flick(100, 0)
        chord(s, "right", "MOUSE_BUTTON_PRESSED")
    end
end)

test("unrelated buttons and unmatched releases do nothing", function()
    local s = setup()
    s.event("MOUSE_BUTTON_RELEASED", 9)
    s.event("MOUSE_BUTTON_PRESSED", 5)
    s.event("MOUSE_BUTTON_RELEASED", 5)
    s.event("G_PRESSED", 9)
    assert(#s.presses == 0 and s.calls.GetMousePosition == nil, "unrelated event handled")
end)

test("press and sleep errors release keys and do not replay on release", function()
    local failures = {
        { "PressKey", 1 }, { "PressKey", 2 },
        { "Sleep", 1 }, { "Sleep", 2 }, { "Sleep", 3 },
        { "Sleep", 4 }, { "Sleep", 5 }, { "Sleep", 6 },
    }
    for _, failure in ipairs(failures) do
        local s = setup()
        s.fail = function(api, _, n) return api == failure[1] and n == failure[2] end
        s.flick(0, -100)
        released(s)
        local presses = #s.presses
        s.event("MOUSE_BUTTON_RELEASED", 9)
        assert(#s.presses == presses, "failed shortcut replayed")
        s.fail = nil
        s.presses = {}
        s.flick(100, 0)
        chord(s, "right", "MOUSE_BUTTON_PRESSED")
    end
end)

test("position errors cancel the press without creating a click", function()
    for _, failingRead in ipairs({ 1, 2 }) do
        local s = setup()
        s.fail = function(api, _, n) return api == "GetMousePosition" and n == failingRead end
        s.flick(100, 0)
        s.event("MOUSE_BUTTON_RELEASED", 9)
        assert(#s.presses == 0, "position error caused a shortcut")
    end
end)

test("transient key-up failures retry without another shortcut", function()
    for _, failedKey in ipairs({ "down", "lctrl" }) do
        local s = setup()
        local failed = false
        s.fail = function(api, key)
            if api == "ReleaseKey" and key == failedKey and not failed then
                failed = true
                return true
            end
        end
        s.flick(0, -100)
        chord(s, "down", "MOUSE_BUTTON_PRESSED")
        s.event("MOUSE_BUTTON_RELEASED", 9)
        chord(s, "down", "MOUSE_BUTTON_PRESSED")
    end
end)

test("pending key-up failure blocks new shortcuts until cleanup succeeds", function()
    local s = setup()
    s.fail = function(api, key) return api == "ReleaseKey" and key == "down" end
    s.flick(0, -100)
    assert(s.down.lctrl == nil, "modifier cleanup was skipped")
    s.event("MOUSE_BUTTON_RELEASED", 9)
    local presses = #s.presses
    s.flick(100, 0)
    s.event("MOUSE_BUTTON_RELEASED", 9)
    assert(#s.presses == presses, "shortcut sent with failed cleanup pending")
    s.fail = nil
    s.event("PROFILE_DEACTIVATED")
    released(s)
    s.presses = {}
    s.flick(100, 0)
    chord(s, "right", "MOUSE_BUTTON_PRESSED")
end)

print(string.format("%d scenarios passed; all G HUB input APIs were mocked.", passed))
