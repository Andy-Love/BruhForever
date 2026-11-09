# Changelog

## v1.0.0

- Replies "bruh" when someone says "bruh" in party, raid, instance or guild chat.
- On by default in party, raid and guild chat; instance chat is off. Change any channel with `/bruh <party|raid|instance|guild> <on|off>`.
- 5 second cooldown per channel, never answers itself, stays quiet while the game locks chat during encounters.
- Supports Retail, MoP Classic, Cataclysm Classic, Wrath Classic, TBC Classic and Classic Era.
- Settings page under Options > AddOns with a checkbox per channel.
- Optional sound (one of five random bruhs) on each bruh heard in an enabled channel: `/bruh sound on` or the settings page. Off by default.
- Sound cooldown is adjustable (0-30 seconds, default 5; 0 plays every bruh): `/bruh soundcooldown <seconds>` or the settings page slider.
- Bruh counter: `/bruh stats` shows bruhs heard and said and the longest bruh chain per channel, `/bruh reset` clears it.
- Options to pause in raids and in Mythic+ (no replies, no counting): settings page, `/bruh pauseraid` and `/bruh pausemythic`.
