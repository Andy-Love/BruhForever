local ADDON = ...

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    BruhForeverDB = BruhForeverDB or {}
    print("|cff0cd29fBruh Forever|r loaded. Bruh.")
end)

SLASH_BRUHFOREVER1 = "/bruh"
SlashCmdList.BRUHFOREVER = function()
    print("|cff0cd29fBruh Forever|r: bruh.")
end
