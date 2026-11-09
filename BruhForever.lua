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

local eventToChannel, lastSent = {}, {}
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

local SOUND_FILE = "Interface\\AddOns\\BruhForever\\bruh.ogg"

-- shortcut: until bruh.ogg ships, PlaySoundFile fails and we fall back to the whisper ping.
local function playBruh()
    if not PlaySoundFile(SOUND_FILE, "Master") and SOUNDKIT then
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
    local cooling = lastSent[channel] and now - lastSent[channel] < COOLDOWN
    -- The sound cooldown is optional; the reply cooldown is not, or two users would loop forever.
    if BruhForeverDB.sound and (not cooling or not BruhForeverDB.soundCooldown) then playBruh() end
    if cooling then return end
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
    local cd = Settings.RegisterAddOnSetting(category, "BRUHFOREVER_SOUNDCD", "soundCooldown",
        BruhForeverDB, Settings.VarType.Boolean, "Limit the sound to once per 5 seconds", true)
    Settings.CreateCheckbox(category, cd, "Turn off to play the sound for every bruh, even overlapping.")
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
        if BruhForeverDB.soundCooldown == nil then BruhForeverDB.soundCooldown = true end
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
    elseif name == "SOUNDCOOLDOWN" and (state == "ON" or state == "OFF") then
        BruhForeverDB.soundCooldown = state == "ON"
        print(PREFIX .. "sound cooldown " .. state:lower())
    elseif CHANNELS[name] and (state == "ON" or state == "OFF") then
        BruhForeverDB.channels[name] = state == "ON"
        print(PREFIX .. name .. " " .. state:lower())
    else
        print(PREFIX .. "usage: /bruh <party|raid|instance|guild|sound> <on|off>")
        print(PREFIX .. "sound: " .. (BruhForeverDB.sound and "on" or "off")
            .. ", sound cooldown: " .. (BruhForeverDB.soundCooldown and "on" or "off") .. " (/bruh soundcooldown <on|off>)")
        status()
    end
end
