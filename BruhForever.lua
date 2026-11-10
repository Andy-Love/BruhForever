local PREFIX = "|cff0cd29fBruh Forever|r: "
local COOLDOWN = 5 -- seconds between replies per channel; stops two users looping forever

-- shortcut: only channels Blizzard lets addons send to without a key press.
-- SAY/YELL/CHANNEL outdoors need a hardware event, so they are not supported yet.
local CHANNELS = {
    PARTY = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" },
    RAID = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER" },
    INSTANCE_CHAT = { "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" },
    GUILD = { "CHAT_MSG_GUILD" },
}
local ALIAS = { INSTANCE = "INSTANCE_CHAT" }

local eventToChannel, lastSent, lastSound = {}, {}, {}
local f = CreateFrame("Frame")
for channel, events in pairs(CHANNELS) do
    for _, event in ipairs(events) do
        eventToChannel[event] = channel
        pcall(f.RegisterEvent, f, event) -- older clients lack some chat events (e.g. instance chat)
    end
end
f:RegisterEvent("PLAYER_LOGIN")

local function isBruh(msg)
    return msg:lower():find("%f[%a]bruh%f[%A]") ~= nil
end

local SOUND_COUNT = 5 -- sounds/bruh1.ogg .. bruh5.ogg

local function playBruh()
    local pick = BruhForeverDB.soundPick -- 1..SOUND_COUNT, or nil for a random one each time
    if not pick or pick < 1 or pick > SOUND_COUNT then pick = math.random(SOUND_COUNT) end
    local file = "Interface\\AddOns\\BruhForever\\sounds\\bruh" .. pick .. ".ogg"
    if not PlaySoundFile(file, "Master") and SOUNDKIT then
        PlaySound(SOUNDKIT.TELL_MESSAGE, "Master")
    end
end

-- True when the user chose to pause in this content. Paused means no replies and no counting.
local function paused()
    local db = BruhForeverDB
    if db.pauseRaid and select(2, IsInInstance()) == "raid" then return true end
    return db.pauseMythic and C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive()
end

local chainMine = {} -- true while the current chain in a channel was started by us
local chain = {} -- current run of consecutive bruh messages per channel, any speaker, including ours

local function statsFor(channel)
    local s = BruhForeverDB.stats[channel]
    if not s then s = { heard = 0, sent = 0, chain = 0 }; BruhForeverDB.stats[channel] = s end
    return s
end

local function count(channel, key)
    local s = statsFor(channel)
    s[key] = s[key] + 1
end

local function onChat(event, msg, _, _, _, _, _, _, _, _, _, _, guid)
    local channel = eventToChannel[event]
    if not BruhForeverDB.channels[channel] or paused() then return end
    -- Midnight hides chat text during encounters; we cannot read or reply then.
    -- An unreadable message ends the chain: we can't tell whether it was a bruh.
    if issecretvalue and (issecretvalue(msg) or issecretvalue(guid)) then chain[channel] = 0; return end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        chain[channel] = 0
        return
    end
    local bruh = isBruh(msg)
    if bruh then
        chain[channel] = (chain[channel] or 0) + 1
        if chain[channel] == 1 then chainMine[channel] = guid == UnitGUID("player") end
        local s = statsFor(channel)
        if chain[channel] > (s.chain or 0) then s.chain = chain[channel] end
    else
        chain[channel] = 0
    end
    if guid == UnitGUID("player") or not bruh then return end
    count(channel, "heard")
    local now = GetTime()
    if BruhForeverDB.sound then
        local gap = BruhForeverDB.soundCooldown or 0 -- seconds; 0 plays every bruh
        if gap == 0 or not lastSound[channel] or now - lastSound[channel] >= gap then
            lastSound[channel] = now
            playBruh()
        end
    end
    -- Someone answering our own bruh does not get a reply; we started it.
    if chainMine[channel] then return end
    -- The reply cooldown is fixed, or two users would reply to each other forever.
    if lastSent[channel] and now - lastSent[channel] < COOLDOWN then return end
    lastSent[channel] = now
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    pcall(send, "bruh", channel)
    count(channel, "sent")
end

local function printStats()
    local heard, sent, best = 0, 0, 0
    for channel, s in pairs(BruhForeverDB.stats) do
        local c = s.chain or 0
        heard, sent, best = heard + s.heard, sent + s.sent, math.max(best, c)
        print(PREFIX .. channel .. ": heard " .. s.heard .. ", said " .. s.sent .. ", longest chain " .. c)
    end
    print(PREFIX .. "total: heard " .. heard .. " bruhs, said " .. sent .. ", longest chain " .. best
        .. ". (/bruh reset clears this)")
end

local function status()
    for channel in pairs(CHANNELS) do
        print(PREFIX .. channel .. ": " .. (BruhForeverDB.channels[channel] and "on" or "off"))
    end
end

local OPTION_LABELS = {
    PARTY = { "Party chat", true },
    RAID = { "Raid chat", true },
    GUILD = { "Guild chat", true },
    INSTANCE_CHAT = { "Instance chat", false },
}
local OPTION_ORDER = { "PARTY", "RAID", "GUILD", "INSTANCE_CHAT" }

-- Adds a page to the game's AddOns settings list. Wrapped in pcall at the call site:
-- older clients use a different Settings API and must not break the slash commands.
-- Runs fn; a failure prints which settings control is missing instead of vanishing silently.
local function try(label, fn)
    local ok, err = pcall(fn)
    if not ok then print(PREFIX .. "settings: " .. label .. " unavailable: " .. tostring(err)) end
end

local function setupOptions()
    local category = Settings.RegisterVerticalLayoutCategory("Bruh Forever")
    for _, channel in ipairs(OPTION_ORDER) do
        local label, default = unpack(OPTION_LABELS[channel])
        local setting = Settings.RegisterAddOnSetting(category, "BRUHFOREVER_" .. channel, channel,
            BruhForeverDB.channels, Settings.VarType.Boolean, "Reply \"bruh\" in " .. label, default)
        Settings.CreateCheckbox(category, setting, "Say \"bruh\" back when someone says it in " .. label .. ".")
    end
    local sound = Settings.RegisterAddOnSetting(category, "BRUHFOREVER_SOUND", "sound",
        BruhForeverDB, Settings.VarType.Boolean, "Play a sound on bruh", false)
    Settings.CreateCheckbox(category, sound, "Play a sound each time someone says bruh in an enabled channel.")
    -- Own pcall: if the slider API differs, the checkboxes above must still be registered.
    try("sound cooldown slider", function()
        local cd = Settings.RegisterAddOnSetting(category, "BRUHFOREVER_SOUNDCD", "soundCooldown",
            BruhForeverDB, Settings.VarType.Number, "Sound cooldown (seconds)", 5)
        local options = Settings.CreateSliderOptions(0, 30, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, cd, options, "Minimum seconds between sounds. 0 plays the sound for every bruh, even overlapping.")
    end)
    for _, p in ipairs({
        { "pauseRaid", "Pause in raids", "Don't reply or count bruhs while inside a raid instance." },
        { "pauseMythic", "Pause in Mythic+", "Don't reply or count bruhs during a Mythic+ run (Retail)." },
    }) do
        local setting = Settings.RegisterAddOnSetting(category, "BRUHFOREVER_" .. p[1]:upper(), p[1],
            BruhForeverDB, Settings.VarType.Boolean, p[2], false)
        Settings.CreateCheckbox(category, setting, p[3])
    end
    try("sound dropdown", function()
        local pick = Settings.RegisterAddOnSetting(category, "BRUHFOREVER_SOUNDPICK", "soundPick",
            BruhForeverDB, Settings.VarType.Number, "Sound", 0)
        Settings.CreateDropdown(category, pick, function()
            local c = Settings.CreateControlTextContainer()
            c:Add(0, "Random")
            for i = 1, SOUND_COUNT do c:Add(i, "Bruh " .. i) end
            return c:GetData()
        end, "Which bruh to play. Random picks a different one each time.")
    end)
    -- Credit line at the bottom of the page.
    try("credit line", function()
        SettingsPanel:GetLayout(category):AddInitializer(
            CreateSettingsListSectionHeaderInitializer("Bruh voiced by Malexis"))
    end)
    Settings.RegisterAddOnCategory(category)
end

f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        BruhForeverDB = BruhForeverDB or {}
        BruhForeverDB.channels = BruhForeverDB.channels or {}
        -- Fill only unset channels so a user's explicit "off" survives updates.
        for _, channel in ipairs({ "PARTY", "RAID", "GUILD" }) do
            if BruhForeverDB.channels[channel] == nil then BruhForeverDB.channels[channel] = true end
        end
        if type(BruhForeverDB.soundPick) ~= "number" then BruhForeverDB.soundPick = 0 end -- 0 = random
        if type(BruhForeverDB.soundCooldown) ~= "number" then BruhForeverDB.soundCooldown = 5 end
        BruhForeverDB.stats = BruhForeverDB.stats or {}
        for _, key in ipairs({ "pauseRaid", "pauseMythic" }) do
            if BruhForeverDB[key] == nil then BruhForeverDB[key] = false end
        end
        if Settings and Settings.RegisterVerticalLayoutCategory then try("page", setupOptions) end
        print(PREFIX .. "loaded. Bruh.")
    else
        onChat(event, ...)
    end
end)

SLASH_BRUHFOREVER1 = "/bruh"
SlashCmdList.BRUHFOREVER = function(input)
    local name, state = input:upper():match("^(%S*)%s*(%S*)$")
    name = ALIAS[name] or name
    local on = state == "ON"
    if name == "STATS" then
        printStats()
    elseif name == "RESET" then
        BruhForeverDB.stats = {}
        print(PREFIX .. "counter reset")
    elseif name == "SOUND" and (state == "ON" or state == "OFF") then
        BruhForeverDB.sound = on
        print(PREFIX .. "sound " .. state:lower())
    elseif name == "SOUNDPICK" and (state == "RANDOM" or (tonumber(state) and tonumber(state) >= 1 and tonumber(state) <= SOUND_COUNT)) then
        BruhForeverDB.soundPick = tonumber(state) or 0
        print(PREFIX .. "sound " .. state:lower())
    elseif name == "SOUNDCOOLDOWN" and tonumber(state) and tonumber(state) >= 0 then
        BruhForeverDB.soundCooldown = tonumber(state)
        print(PREFIX .. "sound cooldown " .. state .. "s")
    elseif (name == "PAUSERAID" or name == "PAUSEMYTHIC") and (on or state == "OFF") then
        BruhForeverDB[name == "PAUSERAID" and "pauseRaid" or "pauseMythic"] = on
        print(PREFIX .. name:lower() .. " " .. state:lower())
    elseif CHANNELS[name] and (state == "ON" or state == "OFF") then
        BruhForeverDB.channels[name] = state == "ON"
        print(PREFIX .. name .. " " .. state:lower())
    else
        print(PREFIX .. "usage: /bruh <party|raid|instance|guild|pauseraid|pausemythic|sound> <on|off>, /bruh stats, /bruh reset")
        print(PREFIX .. "sound: " .. (BruhForeverDB.sound and "on" or "off")
            .. ", sound cooldown: " .. BruhForeverDB.soundCooldown .. "s (/bruh soundcooldown <seconds>, 0 = none), /bruh soundpick <random|1-5>")
        status()
    end
end
