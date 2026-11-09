-- Run from the repo root: lua tests/run.lua  (Lua 5.1, same as the game)
local failed = 0

-- Loads a fresh copy of the addon against stubbed WoW globals. Returns a small driver.
local function load(db, settings)
    local w = { clock = 100, sent = {}, sounds = {}, instance = "none", mythic = false, printed = {} }
    local onEvent
    _G.BruhForeverDB = db
    _G.SlashCmdList = {}
    _G.CreateFrame = function()
        return { RegisterEvent = function() end, SetScript = function(_, _, fn) onEvent = fn end }
    end
    _G.UnitGUID = function() return "me" end
    _G.GetTime = function() return w.clock end
    _G.IsInInstance = function() return true, w.instance end
    _G.C_ChallengeMode = { IsChallengeModeActive = function() return w.mythic end }
    _G.SendChatMessage = function(msg, channel) w.sent[#w.sent + 1] = channel .. ":" .. msg end
    _G.PlaySoundFile = function(file) w.sounds[#w.sounds + 1] = file; return true end
    _G.print = function(s) w.printed[#w.printed + 1] = s end
    _G.Settings, _G.C_ChatInfo, _G.issecretvalue = settings, nil, nil
    assert(loadfile("BruhForever.lua"))()
    onEvent(nil, "PLAYER_LOGIN")
    function w.say(text, guid, event) onEvent(nil, event or "CHAT_MSG_PARTY", text, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, guid or "other") end
    function w.slash(s) SlashCmdList.BRUHFOREVER(s) end
    return w
end

local function test(name, fn)
    local ok, err = pcall(fn)
    io.write((ok and "ok   " or "FAIL ") .. name .. (ok and "" or ("\n     " .. tostring(err))) .. "\n")
    if not ok then failed = failed + 1 end
end

local function eq(a, b) assert(a == b, "expected " .. tostring(b) .. ", got " .. tostring(a)) end

test("matches whole word bruh only", function()
    local w = load({})
    w.say("BRUH!"); eq(#w.sent, 1)
    w.clock = 200; w.say("bruhaha"); w.say("nobruh"); eq(#w.sent, 1)
end)

test("replies bruh to the same channel", function()
    local w = load({})
    w.say("bruh", nil, "CHAT_MSG_GUILD"); eq(w.sent[1], "GUILD:bruh")
end)

test("reply cooldown holds for 5 seconds", function()
    local w = load({})
    w.say("bruh"); w.clock = 104; w.say("bruh"); eq(#w.sent, 1)
    w.clock = 105; w.say("bruh"); eq(#w.sent, 2)
end)

test("ignores its own messages", function()
    local w = load({})
    w.say("bruh", "me"); eq(#w.sent, 0)
end)

test("instance chat is off by default, party is on", function()
    local w = load({})
    w.say("bruh", nil, "CHAT_MSG_INSTANCE_CHAT"); eq(#w.sent, 0)
    w.say("bruh"); eq(#w.sent, 1)
end)

test("explicit off survives login defaults", function()
    local w = load({ channels = { PARTY = false } })
    w.say("bruh"); eq(#w.sent, 0)
end)

test("slash toggles a channel", function()
    local w = load({})
    w.slash("party off"); w.say("bruh"); eq(#w.sent, 0)
    w.slash("party on"); w.say("bruh"); eq(#w.sent, 1)
end)

test("pause in raids stops replies and counting", function()
    local w = load({})
    w.slash("pauseraid on"); w.instance = "raid"
    w.say("bruh"); eq(#w.sent, 0); eq(next(BruhForeverDB.stats), nil)
    w.instance = "party"; w.say("bruh"); eq(#w.sent, 1)
end)

test("pause in Mythic+", function()
    local w = load({})
    w.slash("pausemythic on"); w.mythic = true
    w.say("bruh"); eq(#w.sent, 0)
    w.mythic = false; w.say("bruh"); eq(#w.sent, 1)
end)

test("counts heard and sent, reset clears", function()
    local w = load({})
    w.say("bruh"); w.clock = 101; w.say("bruh")
    eq(BruhForeverDB.stats.PARTY.heard, 2); eq(BruhForeverDB.stats.PARTY.sent, 1)
    w.slash("reset"); eq(next(BruhForeverDB.stats), nil)
end)

test("longest chain counts consecutive bruhs from anyone, resets on other text", function()
    local w = load({})
    w.say("bruh"); w.say("bruh", "me"); w.say("bruh"); eq(BruhForeverDB.stats.PARTY.chain, 3)
    w.say("hello"); w.say("bruh"); w.say("bruh")
    eq(BruhForeverDB.stats.PARTY.chain, 3)
    w.say("bruh"); w.say("bruh"); eq(BruhForeverDB.stats.PARTY.chain, 4)
end)

test("secret values end the chain and are not read", function()
    local w = load({})
    _G.issecretvalue = function(v) return v == "secret" end
    w.say("bruh"); w.say("secret"); w.say("bruh")
    eq(BruhForeverDB.stats.PARTY.chain, 1)
end)

test("no sound by default, sound plays when on", function()
    local w = load({})
    w.say("bruh"); eq(#w.sounds, 0)
    w.slash("sound on"); w.clock = 200; w.say("bruh"); eq(#w.sounds, 1)
end)

test("sound cooldown 5s, 0 plays every bruh", function()
    local w = load({})
    w.slash("sound on"); w.say("bruh"); w.clock = 102; w.say("bruh"); eq(#w.sounds, 1)
    w.clock = 105; w.say("bruh"); eq(#w.sounds, 2)
    w.slash("soundcooldown 0"); w.say("bruh"); w.say("bruh"); eq(#w.sounds, 4)
end)

test("soundpick picks a file, random stays within 1-5, bad input rejected", function()
    local w = load({})
    w.slash("sound on"); w.slash("soundcooldown 0"); w.slash("soundpick 3")
    w.say("bruh"); assert(w.sounds[1]:find("bruh3.ogg", 1, true), w.sounds[1])
    w.slash("soundpick 9"); eq(BruhForeverDB.soundPick, 3)
    w.slash("soundpick random")
    for _ = 1, 20 do w.say("bruh") end
    for i = 2, #w.sounds do assert(w.sounds[i]:find("bruh[1-5]%.ogg"), w.sounds[i]) end
end)

test("a broken Settings API does not break login or slash commands", function()
    local w = load({}, { RegisterVerticalLayoutCategory = function() error("boom") end })
    eq(w.printed[#w.printed]:find("loaded. Bruh.", 1, true) ~= nil, true)
    eq(w.printed[1]:find("settings: page unavailable", 1, true) ~= nil, true)
    w.say("bruh"); eq(#w.sent, 1)
end)

io.write((failed == 0 and "all passed" or (failed .. " failed")) .. "\n")
os.exit(failed == 0 and 0 or 1)
