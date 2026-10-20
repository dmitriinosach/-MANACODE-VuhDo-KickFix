-- VuhDo KickFix 1.2
-- Fixes VuhDo 2.22 breaking when someone is kicked / leaves the group during combat.
--
-- Cause: during combat VuhDo's reload timer sets VUHDO_IS_RELOADING = true, runs the roster
-- refresh and only then sets it back to false. The refresh walks stale entries of players who
-- no longer exist; if anything in that chain raises a Lua error, the "= false" line is never
-- reached. VUHDO_IS_RELOADING stays true forever, every later reload is postponed endlessly
-- and the panel is stuck/broken until /reload.
--
-- What this patch does:
--   1. runs the roster-refresh steps under pcall, so one error cannot leave VuhDo half-way;
--   2. in combat shows the slot that vanished after renumbering as an empty "left" bar, so the
--      player who moved up is not shown twice (see fixShiftedRoster);
--   3. watchdog: if VUHDO_IS_RELOADING is stuck for >1s it is reset and a reload is queued.
-- Errors that get caught are printed once to the chat frame (useful for bug reports).

local pcall, pairs, type, GetTime = pcall, pairs, type, GetTime
local UnitExists, UnitIsUnit, UnitName, UnitGUID = UnitExists, UnitIsUnit, UnitName, UnitGUID
local InCombatLockdown = InCombatLockdown
local seen = {}

local function report(where, err)
	local msg = tostring(err)
	if seen[msg] then return end
	seen[msg] = true
	DEFAULT_CHAT_FRAME:AddMessage("|cffff8800VuhDo KickFix|r: caught error in " .. where .. ": " .. msg)
end

local function safeWrap(name, after)
	local orig = _G[name]
	if type(orig) ~= "function" then return end
	_G[name] = function(...)
		local ok, err = pcall(orig, ...)
		if not ok then
			report(name, err)
		elseif after then
			after()
		end
	end
end

local LEFT_NAME = GetLocale() == "ruRU" and "вышел" or "left"

local function isGroupUnit(unit)
	return unit ~= "focus" and unit ~= "target" and unit ~= "player" and unit ~= "pet"
end

-- When someone leaves, the game renumbers the group without gaps (raid1..raid4 instead of
-- raid1..raid3, raid5). In combat VuhDo cannot rebind its buttons, so the last raidN no longer
-- exists but keeps the old name, while the same player now also sits on raidN-1: a duplicate.
-- Each button keeps showing whoever its raidN is now (that is who a click heals); the slot that
-- vanished becomes an empty "left" bar. VuhDo re-sorts the panel after combat as usual.
local function fixShiftedRoster()
	local raid = _G.VUHDO_RAID
	if type(raid) ~= "table" or not InCombatLockdown() then return end
	local changed = false
	for unit, info in pairs(raid) do
		if type(info) == "table" and isGroupUnit(unit) then
			if not UnitExists(unit) then
				if not info.kickfixLeft then
					info.kickfixLeft = true
					info.name, info.fullName, info.className = LEFT_NAME, LEFT_NAME, ""
					info.connected, info.range, info.afk, info.dead = false, false, false, false
					info.aggro, info.charmed = false, false
					changed = true
					if _G.VUHDO_updateBouquetsForEvent then
						local ok, err = pcall(_G.VUHDO_updateBouquetsForEvent, unit, 19) -- VUHDO_UPDATE_DC
						if not ok then report("fixShiftedRoster", err) end
					end
				end
			else
				-- a new player took the slot: VuhDo already re-read it into the same table
				info.kickfixLeft = nil
				-- our own raidN moved onto a slot that still shows someone else; VuhDo skips it
				if UnitIsUnit(unit, "player") and info.name ~= UnitName("player") and _G.VUHDO_setHealth then
					local ok, err = pcall(_G.VUHDO_setHealth, unit, 1) -- VUHDO_UPDATE_ALL
					if not ok then report("fixShiftedRoster", err) end
					changed = true
				end
			end
		end
	end
	if not changed then return end

	-- name -> unit lookups (main tanks, heal comm) must not point at vanished or shifted slots
	local names = _G.VUHDO_RAID_NAMES
	if type(names) == "table" then
		for name, unit in pairs(names) do
			local info = raid[unit]
			if not info or info.kickfixLeft or info.name ~= name
				or (unit ~= "player" and UnitIsUnit(unit, "player")) then
				names[name] = nil
			end
		end
		for unit, info in pairs(raid) do
			if type(info) == "table" and unit ~= "focus" and unit ~= "target" and not info.kickfixLeft
				and info.name and not UnitIsUnit(unit, "player") and (names[info.name] == nil or not info.isPet) then
				names[info.name] = unit
			end
		end
		names[UnitName("player")] = "player"
	end
	local guids = _G.VUHDO_RAID_GUIDS
	if type(guids) == "table" and UnitGUID("player") then
		guids[UnitGUID("player")] = "player"
	end
	if type(_G.VUHDO_resetNameTextCache) == "function" then
		_G.VUHDO_resetNameTextCache()
	end
end

local function install()
	safeWrap("VUHDO_refreshRaidMembers", fixShiftedRoster)
	safeWrap("VUHDO_rebuildTargets")
	safeWrap("VUHDO_updateAllRaidBars")
	safeWrap("VUHDO_initAllEventBouquets")
end

-- Install right away: this file loads after VuhDo (## Dependencies), so the globals already exist,
-- but VuhDo has not yet run its init, which copies some of them into file-local caches.
install()

-- Watchdog for a stuck VUHDO_IS_RELOADING flag (reloads are synchronous, so it must never
-- stay true across frames).
local stuckSince
local frame = CreateFrame("Frame")
frame:SetScript("OnUpdate", function()
	if _G.VUHDO_IS_RELOADING then
		local now = GetTime()
		stuckSince = stuckSince or now
		if now - stuckSince > 1 then
			_G.VUHDO_IS_RELOADING = false
			stuckSince = nil
			if _G.VUHDO_quickRaidReload then _G.VUHDO_quickRaidReload() end
			report("watchdog", "VUHDO_IS_RELOADING was stuck, reset")
		end
	else
		stuckSince = nil
	end
end)
