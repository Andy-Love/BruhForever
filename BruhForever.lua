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

local function onChat(event, msg, _, _, _, _, _, _, _, _, _, _, guid)
    local channel = eventToChannel[event]
    if not BruhForeverDB.channels[channel] then return end
    -- Midnight hides chat text during encounters; we cannot read or reply then.
    if issecretvalue and (issecretvalue(msg) or issecretvalue(guid)) then return end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return end
    if guid == UnitGUID("player") or not isBruh(msg) then return end
    local now = GetTime()
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

f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        BruhForeverDB = BruhForeverDB or {}
        BruhForeverDB.channels = BruhForeverDB.channels or {}
    else
        onChat(event, ...)
    end
end)

SLASH_BRUHFOREVER1 = "/bruh"
SlashCmdList.BRUHFOREVER = function(input)
    local name, state = input:upper():match("^(%S+)%s+(%S+)$")
    name = ALIAS[name] or name
    if CHANNELS[name] and (state == "ON" or state == "OFF") then
        BruhForeverDB.channels[name] = state == "ON"
        print(PREFIX .. name .. " " .. state:lower())
    else
        print(PREFIX .. "usage: /bruh <party|raid|instance|guild> <on|off>")
        status()
    end
end
