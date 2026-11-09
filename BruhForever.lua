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
    local file = "Interface\\AddOns\\BruhForever\\sounds\\bruh" .. math.random(SOUND_COUNT) .. ".ogg"
    if not PlaySoundFile(file, "Master") and SOUNDKIT then
        PlaySound(SOUNDKIT.TELL_MESSAGE, "Master")
    end
end

local function onChat(event, msg, _, _, _, _, _, _, _, _, _, _, guid)
    local channel = eventToChannel[event]
    if not BruhForeverDB.channels[channel] then return end
    -- Midnight hides chat text during encounters; we cannot read or reply then.
    if issecretvalue and (issecretvalue(msg) or issecretvalue(guid)) then return end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return end
    if guid == UnitGUID("player") or not isBruh(msg) then return end
    local now = GetTime()
    if BruhForeverDB.sound then
        local gap = BruhForeverDB.soundCooldown or 0 -- seconds; 0 plays every bruh
        if gap == 0 or not lastSound[channel] or now - lastSound[channel] >= gap then
            lastSound[channel] = now
            playBruh()
        end
    end
    -- The reply cooldown is fixed, or two users would reply to each other forever.
    if lastSent[channel] and now - lastSent[channel] < COOLDOWN then return end
    lastSent[channel] = now
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    pcall(send, "bruh", channel)
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
    pcall(function()
        local cd = Settings.RegisterAddOnSetting(category, "BRUHFOREVER_SOUNDCD", "soundCooldown",
            BruhForeverDB, Settings.VarType.Number, "Sound cooldown (seconds)", 5)
        local options = Settings.CreateSliderOptions(0, 30, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, cd, options, "Minimum seconds between sounds. 0 plays the sound for every bruh, even overlapping.")
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
        if type(BruhForeverDB.soundCooldown) ~= "number" then BruhForeverDB.soundCooldown = 5 end
        if Settings and Settings.RegisterVerticalLayoutCategory then pcall(setupOptions) end
        print(PREFIX .. "loaded. Bruh.")
    else
        onChat(event, ...)
    end
end)

SLASH_BRUHFOREVER1 = "/bruh"
SlashCmdList.BRUHFOREVER = function(input)
    local name, state = input:upper():match("^(%S+)%s+(%S+)$")
    name = ALIAS[name] or name
    if name == "SOUND" and (state == "ON" or state == "OFF") then
        BruhForeverDB.sound = state == "ON"
        print(PREFIX .. "sound " .. state:lower())
    elseif name == "SOUNDCOOLDOWN" and tonumber(state) and tonumber(state) >= 0 then
        BruhForeverDB.soundCooldown = tonumber(state)
        print(PREFIX .. "sound cooldown " .. state .. "s")
    elseif CHANNELS[name] and (state == "ON" or state == "OFF") then
        BruhForeverDB.channels[name] = state == "ON"
        print(PREFIX .. name .. " " .. state:lower())
    else
        print(PREFIX .. "usage: /bruh <party|raid|instance|guild|sound> <on|off>")
        print(PREFIX .. "sound: " .. (BruhForeverDB.sound and "on" or "off")
            .. ", sound cooldown: " .. BruhForeverDB.soundCooldown .. "s (/bruh soundcooldown <seconds>, 0 = none)")
        status()
    end
end
