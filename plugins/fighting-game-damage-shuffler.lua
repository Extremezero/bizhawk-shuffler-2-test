local plugin = {}

plugin.name = "Fighting Game Hit Shuffler"
plugin.author = "authorblues, kalimag, Extreme0"
plugin.settings = {}
plugin.description =
[[
	Automatically swaps games any time Player 1 gets hit before & after a combo. Checks hashes of different rom versions, so if you use a version of the rom that isn't recognized, nothing special will happen in that game (no swap on hit).

	Supports:
	-Street Fighter Alpha 3 (USA)(PSX)
	-Street Fighter EX2+ (JP)(PSX)
]]

local NO_MATCH = 'NONE'

local prevdata
local swap_scheduled
local shouldSwap

-- optionally load BizHawk 2.9 compat helper to get rid of bit operator warnings
local bit = bit
if compare_version("2.9") >= 0 then
	local success, migration_helpers = pcall(require, "migration_helpers")
	bit = success and migration_helpers.EmuHawk_pre_2_9_bit and migration_helpers.EmuHawk_pre_2_9_bit() or bit
end


-- update value in prevdata and return whether the value has changed, new value, and old value
-- value is only considered changed if it wasn't nil before
local function update_prev(key, value)
	local prev_value = prevdata[key]
	prevdata[key] = value
	local changed = prev_value ~= nil and value ~= prev_value
	return changed, value, prev_value
end

local function hitstun_swap(gamemeta)
	return function(data)
	-- To be used when address value registers a single hit example: value of 1 = 1 hit ingame. Best used for games without proper combos or combo counter

		local hitindicator = hitstun
		local previoushit = data

		local previoushit = data.hitstun
		data.hitstun = hitindicator

		if hitindicator = 1 then
			return true 
			else
			return false
			end
		end

--local function combo_swap(gamemeta)
	--return function(data)
	-- To be used when address value registers hits more than 1 and value resets to 0 after combo finishes. Best used for games with combo counters
	
	--local comboindicator = combo
	--local prevcombo = data

	--if comboindicator = 1 then
		--return true
		--else
		--comboindicator => 2
		--return false
	--end
--end-

local backupchecks = {
}

local gamedata = {
	[SFA3]={ 
		hitstun=function() return memory.read(0x19D0CD, "MainRAM") end,
	}
	[SFEX2+]={
		hitstun=function() return memory.read(0x1EAA8C, "MainRAM") end,
	}
		}
}

local function get_game_tag()
	-- try to just match the rom hash first
	local tag = get_tag_from_hash_db(gameinfo.getromhash(), 'plugins/fighting-hashes.dat')
	if tag ~= nil and gamedata[tag] ~= nil then return tag end

	-- check to see if any of the rom name samples match
	local name = gameinfo.getromname()
	for _,check in pairs(backupchecks) do
		if check.test() then return check.tag end
	end

	return nil
end

function plugin.on_setup(data, settings)
	data.tags = data.tags or {}
end

function plugin.on_game_load(data, settings)
	prevdata = {}
	swap_scheduled = false
	shouldSwap = function() return false end

	local tag = data.tags[gameinfo.getromhash()] or get_game_tag()
	data.tags[gameinfo.getromhash()] = tag or NO_MATCH

	-- first time through with a bad match, tag will be nil
	-- can use this to print a debug message only the first time
	if tag ~= nil and tag ~= NO_MATCH then
		log_message('game match: ' .. tag)
		local gamemeta = gamedata[tag]
		local func = gamemeta.func or generic_swap
		shouldSwap = func(gamemeta)
	elseif tag == nil then
		log_message(string.format('unrecognized? %s (%s)',
			gameinfo.getromname(), gameinfo.getromhash()))
	end
end

function plugin.on_frame(data, settings)
	-- run the check method for each individual game
	if swap_scheduled then return end

	local schedule_swap, delay = shouldSwap(prevdata)
	if schedule_swap and frames_since_restart > 10 then
		swap_game_delay(delay or 3)
		swap_scheduled = true
	end
end

return plugin