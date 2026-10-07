-- VuhDo KickFix 1.1
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
--   2. marks vanished units as offline during combat instead of leaving frozen "ghost" bars;
--   3. watchdog: if VUHDO_IS_RELOADING is stuck for >1s it is reset and a reload is queued.
-- Errors that get caught are printed once to the chat frame (useful for bug reports).

local pcall, pairs, type, GetTime = pcall, pairs, type, GetTime
local UnitExists, InCombatLockdown = UnitExists, InCombatLockdown
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

-- Units that no longer exist: show them as offline instead of leaving a frozen bar.
local function markVanishedUnits()
	local raid = _G.VUHDO_RAID
	if type(raid) ~= "table" or not InCombatLockdown() then return end
	for unit, info in pairs(raid) do
		if unit ~= "focus" and unit ~= "target" and unit ~= "player" and unit ~= "pet"
			and type(info) == "table" and info.connected ~= false and not UnitExists(unit) then
			info.connected = false
			info.range = false
			if _G.VUHDO_updateBouquetsForEvent then
				local ok, err = pcall(_G.VUHDO_updateBouquetsForEvent, unit, 19) -- VUHDO_UPDATE_DC
				if not ok then report("markVanishedUnits", err) end
			end
		end
	end
end

local function install()
	safeWrap("VUHDO_refreshRaidMembers", markVanishedUnits)
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
