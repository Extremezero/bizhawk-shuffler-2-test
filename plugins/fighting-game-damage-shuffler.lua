local plugin = {}

plugin.name = "Fighting Game Hit Shuffler"
plugin.author = "Extreme0, authorblues, kalimag"
plugin.settings = {}
plugin.description =
[[
	Automatically swaps games any time Player 1 gets hit before & after a combo. Checks hashes of different rom versions, so if you use a version of the rom that isn't recognized, nothing special will happen in that game (no swap on hit).

	Supports:
	-Capcom vs SNK Pro (USA)(PSX)
	-Killer Instinct (USA)(SNES)
	-Killer Instinct Gold (USA)(EU)(v1.00, Rev 1 & Rev 2)
	-Primal Rage (USA)(SNES)
	-Darkstalkers 3 (USA)(PSX)
	-Tekken 3 (USA)(PSX)
	-Tekken 2 (USA)(PSX)
	-JoJo's Bizzare Adventure (USA)(PSX)
	-Psychic Force 2 (JP)(PSX)
	-Street Fighter Alpha (USA)(PSX)
	-Street Fighter Alpha 2 (USA)(PSX)
	-Street Fighter Alpha 2 Gold (USA)(PSX)(%)
	-Street Fighter Alpha 3 (USA)(PSX)
	-Street Fighter EX Plus Alpha (USA)(PSX)
	-Street Fighter EX2+ (JP)(USA)(PSX)
	-Street Fighter III: 4rd Strike Hack (JP)(NO CD)(**)(?)
	-Street Fighter II: The World Warrior (USA)(PSX)($)(*)
	-Street Fighter II': Champion Edition (USA)(PSX)($)(*)
	-Street Fighter II' Turbo: Hyper Fighting (USA)(PSX)($)(*)
	-Super Street Fighter II: The New Challengers (USA)(SNES)(PSX)(£)
	-Super Street Fighter II Turbo (USA)(PSX)(£)
	-Street Fighter - The Movie (USA)(PSX)(Saturn)
	-Star Gladiator - Episode 1 - Final Crusade (USA)(PSX)
	-Guilty Gear (v1.0)(USA)(PSX)(***)
	-Gundam - The Battle Master (Japan)(PSX)(*)
	-Gundam - The Battle Master 2 (Japan)(PSX)
	-Kensei - Sacred Fist (USA)(PSX)
	-The King of Fighters '95 (USA)(PSX)(*)
	-Marvel Super Heroes vs Street Fighter (JP)(Saturn)
	-X-Men vs. Street Fighter (JP)(Saturn)(1M, 2M, 3M)
	-X-Men - Children of the Atom (JP, USA, EU 2S & 3S)(Saturn)
	-Waku Waku 7 (JP)(Saturn)
	-Virtua Fighter (USA)(Saturn)
	-Virtua Fighter Remix (USA)(Saturn)
	-Virtua Fighter 2 (USA)(Saturn)
	-Virtua Fighter Kids (USA)(Saturn)
	-Fighters Destiny (USA)
	-Fighter Destiny 2 (USA)
	-Garou - Mark of the Wolves (Arcade)(NGM-2530)(?)

	(£)Part of Street Fighter Collection Disc 1 PSX
	(%)Part of Street Fighter Collection Disc 2 PSX
	($)Part of Street Fighter Collection 2 PSX
	(?)MAME games take some time to switch depending on the system.
	(*)No Combo Indicator so this will swap with each hit regardless
	(**)CPS3 Arcade Games loading between swaps is too long to be fluid and near instant
	(***)Grabbing does not swap
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
	-- To be used when address value registers a single hit example: value of 1 = 1 hit ingame.

		local hitindicator = gamemeta.hitstun()

		local previoushit = data.hitstun
		data.hitstun = hitindicator

		if hitindicator == 1 and hitindicator ~= previoushit then
			return true 
			else
			return false
		end
	end
end

local function grab_swap(gamemeta)
	return function(data)
	-- To be used when grab needs a seperate address registered to activate the swap

		local hitindicator = gamemeta.hitstun() 
		local previoushit = data.hitstun

		local grabindicator = gamemeta.grabbed()
		local previousgrab = data.grabbed

		data.hitstun = hitindicator
		data.grabbed = grabindicator

		if hitindicator == 1 and hitindicator ~= previoushit then
			return true 
			elseif grabindicator >= 1 and grabindicator ~= previousgrab then
			return true
			else
			return false
		end
	end
end

local function grab_swap_reverse_hit(gamemeta)
	return function(data)
	-- To be used when grab needs a seperate address registered to activate the swap and hit indication is 0 instead of 1

		local hitindicator = gamemeta.hitstun() 
		local previoushit = data.hitstun

		local grabindicator = gamemeta.grabbed()
		local previousgrab = data.grabbed

		data.hitstun = hitindicator
		data.grabbed = grabindicator

		if hitindicator == 0 and hitindicator ~= previoushit then
			return true 
			elseif grabindicator >= 1 and grabindicator ~= previousgrab then
			return true
			else
			return false
		end
	end
end


local function EXgrab_swap(gamemeta)
	return function(data)
	-- To be used when grab needs a seperate address registered to activate the swap

		local hitindicator = gamemeta.hitstun() 
		local previoushit = data.hitstun

		local grabindicator = gamemeta.grabbed()
		local previousgrab = data.grabbed

		data.hitstun = hitindicator
		data.grabbed = grabindicator

		if grabindicator == 0 and hitindicator == 1 and hitindicator ~= previoushit then
			return true 
			elseif grabindicator >= 1 and grabindicator ~= previousgrab then
			return true
			else
			return false
		end
	end
end

local function sf2snes_swap(gamemeta)
	return function(data)

		local hitindicator = gamemeta.hitstun()
		local previoushit = data.hitstun

		local grabindicator = gamemeta.grabbed()
		local previousgrab = data.grabbed

		local blockindicator = gamemeta.block()

		local P1health = gamemeta.health()
		local P1previoushealth = data.health or 0

		local hitbackup = gamemeta.backup() -- Projectiles need an address that is active with a value of 2 when in motion. Most projectiles when hit will revert back to 0 except Ken and Ryu's hadokens which will go up to 4,6 than 0
		local previousbackup = data.backup

		local comboindicator = gamemeta.comboed()
		local previouscombo = data.comboed

		local projectile_changed, projectile_curr = update_prev("projectile", gamemeta.backup())

		data.hitstun = hitindicator
		data.comboed = comboindicator
		data.block = blockindicator
		data.grabbed = grabindicator
		data.health = P1health
		data.backup = hitbackup

				if data.hpcountdown ~= nil and data.hpcountdown > 0 then
					data.hpcountdown = data.hpcountdown - 1
					if data.hpcountdown == 0 and P1health > 0 then
					return true
				end
			end
	
				if comboindicator == 0 and blockindicator == 0 and hitindicator >= 1 and hitindicator ~= previoushit 
				or grabindicator == 1 and grabindicator ~= previousgrab then
				return true
				end
				
				if projectile_changed and projectile_curr == 2 then
					projectile = 1
				end
				if projectile == 1 and P1health < P1previoushealth and blockindicator == 0 and comboindicator == 0 then
					projectile = 0
					return true
		end
	end
end

local function sf2coll_swap(gamemeta)
	return function(data)
		
		local hitindicator = gamemeta.hitstun() 
		local previoushit = data.hitstun

		local grabindicator = gamemeta.grabbed()
		local previousgrab = data.grabbed

		local hitbackup = gamemeta.backup() --Hadokens need a seperate address to indicate a clean hit
		local previousbackup = data.backup

		local P1health = gamemeta.health()
		local previoushealth = data.health
		local blockindicator = gamemeta.block()
		

		data.hitstun = hitindicator
		data.backup = hitbackup
		data.health = P1health
		data.block = blockindicator
		data.grabbed = grabindicator


				if P1health > 0 and blockindicator ~= 3 and blockindicator ~= 4 and hitindicator >= 1 and hitindicator ~= previoushit or P1health > 0 and hitbackup == 1 and hitbackup ~= previousbackup or P1health > 0 and grabindicator == 1 and grabindicator ~= previousgrab then
				return true
				else
				return false
		end
	end
end

local function supersf2coll_swap(gamemeta)
	return function(data)
		
		local hitindicator = gamemeta.hitstun() 
		local previoushit = data.hitstun

		local grabindicator = gamemeta.grabbed()
		local previousgrab = data.grabbed

		local hitbackup = gamemeta.backup() --Hadokens need a seperate address to indicate a clean hit
		local previousbackup = data.backup
		
		local comboindicator = gamemeta.comboed()
		local previouscombo = data.comboed

		local P1health = gamemeta.health()
		local previoushealth = data.health
		local blockindicator = gamemeta.block()
		

		data.hitstun = hitindicator
		data.backup = hitbackup
		data.health = P1health
		data.block = blockindicator
		data.grabbed = grabindicator


				if P1health > 0 and comboindicator == 0 and blockindicator ~= 3 and blockindicator ~= 4 and hitindicator >= 1 and hitindicator ~= previoushit or P1health > 0 and hitbackup == 1 and hitbackup ~= previousbackup and comboindicator == 0 or P1health > 0 and grabindicator == 1 and grabindicator ~= previousgrab then
				return true
				else
				return false
		end
	end
end

local function health_swap_SFTM(gamemeta)
	return function(data)

		local P1health = gamemeta.health()
		local previoushealth = data.health or 0

		local blockindicator = gamemeta.block()

		local roundindicator = gamemeta.round()
		local previousround = data.round

		local comboindicator = gamemeta.comboed()
		local previouscombo = data.comboed

		data.health = P1health
		data.comboed = comboindicator
		data.round = roundindicator
		data.block = blockindicator
	
		if previoushealth < P1health then
			return false 
			elseif comboindicator == 0 and blockindicator == 0 and previoushealth ~= P1health and previousround == roundindicator then
			return true
			else
			return false
		end
	end
end

local function xmen_swap(gamemeta)
	return function(data)

		local hitindicator = gamemeta.hitstun()
		local previoushit = data.hitstun

		local comboindicator = gamemeta.comboed()

		data.comboed = comboindicator
		data.hitstun = hitindicator

		if comboindicator == 1 and hitindicator == 1 and hitindicator ~= previoushit then
			return true
			else
			return false
		end
	end
end

local function KISnes_swap(gamemeta)
	return function(data)

		local hitindicator = gamemeta.hitstun()
		local previoushit = data.hitstun

		local comboindicator = gamemeta.comboed()

		data.comboed = comboindicator
		data.hitstun = hitindicator

		if comboindicator == 1 and hitindicator == 16 and hitindicator ~= previoushit then
			return true
			else
			return false
		end
	end
end

local function star_swap(gamemeta)
	return function(data)

		local hitindicator = gamemeta.hitstun()
		local previoushit = data.hitstun

		local backuphit = gamemeta.backup() --Hits that swap characters around to otherside wasn't triggering the swap, this is a remedy for it. 

		data.backup = backuphit
		data.hitstun = hitindicator

		if hitindicator == 1 and hitindicator ~= previoushit then
			return true
			elseif backup == 2 and hitindicator == 0 then
			return true
			else
			return false
		end
	end
end

local function gundam_battle_swap(gamemeta) -- Making sure this works at least, there is absolutely a better way of doing this but it works for now.
	return function(data)
		
		local hitindicator1 = gamemeta.hitstun1()
		local hitindicator2 = gamemeta.hitstun2()
		local hitindicator3 = gamemeta.hitstun3()
		local hitindicator4 = gamemeta.hitstun4()
		local hitindicator5 = gamemeta.hitstun5()
		local hitindicator6 = gamemeta.hitstun6()
		local hitindicator7 = gamemeta.hitstun7()
		local hitindicator8 = gamemeta.hitstun8()
		local hitindicator9 = gamemeta.hitstun9()
		local hitindicator10 = gamemeta.hitstun10()
		local hitindicator11 = gamemeta.hitstun11()
		local hitindicator12 = gamemeta.hitstun12()
		local hitindicator13 = gamemeta.hitstun13()
		local hitindicator14 = gamemeta.hitstun14()
		local hitindicator15 = gamemeta.hitstun15()
		local hitindicator16 = gamemeta.hitstun16()
		local hitindicator17 = gamemeta.hitstun17()
		local hitindicator18 = gamemeta.hitstun18()
		local hitindicator19 = gamemeta.hitstun19()
		local hitindicator20 = gamemeta.hitstun20()
		local hitindicator21 = gamemeta.hitstun21()
		local hitindicator22 = gamemeta.hitstun22()
		local hitindicator23 = gamemeta.hitstun23()
		local hitindicator24 = gamemeta.hitstun24()
		local hitindicator25 = gamemeta.hitstun25()
		local hitindicator26 = gamemeta.hitstun26()
		local hitindicator27 = gamemeta.hitstun27()
		local hitindicator28 = gamemeta.hitstun28()

		data.hitstun1 = hitindicator1
		data.hitstun2 = hitindicator2
		data.hitstun3 = hitindicator3
		data.hitstun4 = hitindicator4
		data.hitstun5 = hitindicator5
		data.hitstun6 = hitindicator6
		data.hitstun7 = hitindicator7
		data.hitstun8 = hitindicator8
		data.hitstun9 = hitindicator9
		data.hitstun10 = hitindicator10
		data.hitstun11 = hitindicator11
		data.hitstun12 = hitindicator12
		data.hitstun13 = hitindicator13
		data.hitstun14 = hitindicator14
		data.hitstun15 = hitindicator15
		data.hitstun16 = hitindicator16
		data.hitstun17 = hitindicator17
		data.hitstun18 = hitindicator18
		data.hitstun19 = hitindicator19
		data.hitstun20 = hitindicator20
		data.hitstun21 = hitindicator21
		data.hitstun22 = hitindicator22
		data.hitstun23 = hitindicator23
		data.hitstun24 = hitindicator24
		data.hitstun25 = hitindicator25
		data.hitstun26 = hitindicator26
		data.hitstun27 = hitindicator27
		data.hitstun28 = hitindicator28

			if hitindicator1 == 9 then
			return true
			elseif hitindicator2 == 9 then
			return true
			elseif hitindicator3 == 9 then
			return true
			elseif hitindicator4 == 9 then
			return true
			elseif hitindicator5 == 9 then
			return true
			elseif hitindicator6 == 9 then
			return true
			elseif hitindicator7 == 9 then
			return true
			elseif hitindicator8 == 9 then
			return true
			elseif hitindicator9 == 9 then
			return true
			elseif hitindicator10 == 9 then
			return true
			elseif hitindicator11 == 9 then
			return true
			elseif hitindicator12 == 9 then
			return true
			elseif hitindicator13 == 9 then
			return true
			elseif hitindicator14 == 9 then
			return true
			elseif hitindicator15 == 9 then
			return true
			elseif hitindicator16 == 9 then
			return true
			elseif hitindicator17 == 9 then
			return true
			elseif hitindicator18 == 9 then
			return true
			elseif hitindicator19 == 9 then
			return true
			elseif hitindicator20 == 9 then
			return true
			elseif hitindicator21 == 9 then
			return true
			elseif hitindicator22 == 9 then
			return true
			elseif hitindicator23 == 9 then
			return true
			elseif hitindicator24 == 9 then
			return true
			elseif hitindicator25 == 9 then
			return true
			elseif hitindicator26 == 9 then
			return true
			elseif hitindicator27 == 9 then
			return true
			elseif hitindicator28 == 9 then
			return true
			else
			return false
		end
	end
end

local function virtua_fighter2_swap(gamemeta)
	return function(data)

		local hitindicator = gamemeta.hitstun() 
		local previoushit = data.hitstun

		local grabindicator = gamemeta.grabbed()
		local previousgrab = data.grabbed

		local ringoutindicator = gamemeta.ringout()
		local previousringout = data.ringout

		data.hitstun = hitindicator
		data.grabbed = grabindicator
		data.ringout = ringoutindicator

		if hitindicator == 1 and hitindicator ~= previoushit then
			return true 
			elseif grabindicator == 6 and grabindicator ~= previousgrab then
			return true
			elseif ringoutindicator == 1 and ringoutindicator ~= previousringout then
			return true
			else
			return false
		end
	end
end

local function VFR_swap(gamemeta)
	return function(data)

		local hitindicator = gamemeta.hitstun() 
		local previoushit = data.hitstun

		local grabindicator = gamemeta.grabbed()
		local previousgrab = data.grabbed

		data.hitstun = hitindicator
		data.grabbed = grabindicator

		if hitindicator == 4 and hitindicator ~= previoushit then
			return true 
			elseif grabindicator >= 1 and grabindicator ~= previousgrab then
			return true
			else
			return false
		end
	end
end

local function fighters_destiny(gamemeta)
	return function(data)

		local P1health = gamemeta.health()
		local previoushealth = data.health or 24

		local hitindicator = gamemeta.hitstun()
		local previoushit = data.hitstun

		local grabindicator = gamemeta.grabbed()
		local previousgrab = data.grabbed

		data.health = P1health
		data.hitstun = hitindicator
		data.grabbed = grabindicator
	
		if P1health > previoushealth and P1health ~= previoushealth and hitindicator == 128 then
			return true
			elseif P1health > previoushealth and P1health ~= previoushealth and grabindicator == 1 then
			return true
			else
			return false
		end
	end
end

local function fighters_destiny2(gamemeta)
	return function(data)

		local P1health = gamemeta.health()
		local previoushealth = data.health or 0

		local hitindicator = gamemeta.hitstun()
		local previoushit = data.hitstun

		local grabindicator = gamemeta.grabbed()
		local previousgrab = data.grabbed

		data.health = P1health
		data.hitstun = hitindicator
		data.grabbed = grabindicator
	
		if P1health > previoushealth and P1health ~= previoushealth and hitindicator == 128 then
			return true
			elseif P1health > previoushealth and p1health ~= previoushealth and grabindicator == 1 then
			return true
			else
			return false
		end
	end
end

local function garou_MOTW(gamemeta)
	return function(data)

		local hitindicator = gamemeta.hitstun() 
		local previoushit = data.hitstun

		local grabindicator = gamemeta.grabbed()
		local previousgrab = data.grabbed

		data.hitstun = hitindicator
		data.grabbed = grabindicator

		if hitindicator == 1 and grabindicator ~= 3 and hitindicator ~= previoushit then
			return true 
			elseif grabindicator == 3 and grabindicator ~= previousgrab then
			return true
			else
			return false
		end
	end
end


local gamedata = {
	['SSF2Snes']={ -- Super Street Fighter 2 SNES USA
		hitstun=function() return memory.read_u8(0x0594, "WRAM") end,
		comboed=function() return memory.read_u8(0x0681, "WRAM") end,
		block=function() return memory.read_u8(0x0543, "WRAM") end,
		airstate=function() return memory.read_u8(0x053C, "WRAM") end,
		grabbed=function() return memory.read_u8(0x07DC, "WRAM") end,
		health=function() return memory.read_u8(0x0636, "WRAM") end,
		backup=function() return memory.read_u8(0x09D2, "WRAM") end,
		func=sf2snes_swap
	},
	['SFTM']={ -- Street Fighter The Movie PSX USA
		health=function() return memory.read_u8(0x1B759A, "MainRAM") end,
		comboed=function() return memory.read_u8(0x1B7639, "MainRAM") end,
		round=function() return memory.read_u8(0x1E85FC, "MainRAM") end,
		block=function() return memory.read_u8(0x1B75DD, "MainRAM") end,
		func=health_swap_SFTM
	},
	['SFA']={ -- Street Fighter Alpha USA PSX
		hitstun=function() return memory.read_u8(0x187123, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x1873E2, "MainRAM") end,
		func=grab_swap
	},
	['SFA2']={ -- Street Fighter Alpha 2 USA PSX
		hitstun=function() return memory.read_u8(0x1981FE, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x19859B, "MainRAM") end,
		func=grab_swap
	},
	['SFA2Rev1']={ -- Street Fighter Alpha 2 USA PSX Rev 1
		hitstun=function() return memory.read_u8(0x19820A, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x1985A7, "MainRAM") end,
		func=grab_swap
	},
	['SFA2G']={ -- Street Fighter Alpha 2 Gold USA PSX & Rev 1
		hitstun=function() return memory.read_u8(0x197622, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x18F19B, "MainRAM") end,
		func=grab_swap
	},
	['SFA3']={ --Street Fighter Alpha 3 USA PSX
		hitstun=function() return memory.read_u8(0x19D019, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x1944AF, "MainRAM") end,
		func=grab_swap
	},
	['DS3']={ --Darkstalkers 3 USA PSX
		hitstun=function() return memory.read_u8(0x1C0F00, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x1C12C8, "MainRAM") end,
		func=grab_swap
	},
	['Tekken3']={ --Tekken 3 USA PSX
		hitstun=function() return memory.read_u8(0x0A92A8, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x0AAB28, "MainRAM") end,
		func=grab_swap
	},
	['Tekken2']={ --Tekken 2 USA PSX
		hitstun=function() return memory.read_u8(0x0B8894, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x0D1A6C, "MainRAM") end,
		func=grab_swap_reverse_hit
	},
	['JoJo']={ --JoJo's Bizzare Adventure USA PSX
		hitstun=function() return memory.read_u8(0x0CDAC6, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x0CD75A, "MainRAM") end,
		func=grab_swap
	},
	['SFEX+@']={ --Street Fighter EX Plus Alpha USA PSX
		hitstun=function() return memory.read_u8(0x1D63C0, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x1D63BB, "MainRAM") end,
		func=EXgrab_swap
	},
	['PsyForce2']={ --Psychic Force 2 Japan PSX
		hitstun=function() return memory.read_u8(0x0D3EE8, "MainRAM") end,
	},
	['SFEX2PlusJP']={ --Street Fighter EX 2 Plus Japan PSX
		hitstun=function() return memory.read_u8(0x1E9210, "MainRAM") end,
	},
	['SFEX2PlusUSA']={ --Street Fighter EX 2 Plus USA PSX
		hitstun=function() return memory.read_u8(0x1E9788, "MainRAM") end,
	},
	['SFIII:4rdStrike']={ --Street Fighter III: 4rd Strike Hack (Japan)(NO CD)(Arcade)
		hitstun=function() return memory.read_u8(0x06961D, "sh2 : ram : 0x2000000-0x207FFFF") end,
	},
	['KISNES']={ --Killer Instinct SNES USA
		hitstun=function() return memory.read_u8(0x0804, "WRAM") end,
		comboed=function() return memory.read_u8(0x0DE8, "WRAM") end,
		func=KISnes_swap
	},
	['PrimalRageSNES']={ --Primal Rage SNES USA
		hitstun=function() return memory.read_u8(0x1C94, "WRAM") end,
	},
	['CVSProPSX']={ -- Capcom VS SNK Pro USA PSX
		hitstun=function() return memory.read_u8(0x06E6B3, "MainRAM") end,
	},
	['Xmen1']={ -- X-Men Mutant Academy
		hitstun=function() return memory.read_u8(0x0A2472, "MainRAM") end,
		comboed=function() return memory.read_u8(0x0A245A, "MainRAM") end,
		func=xmen_swap
	},
	['Xmen2']={ -- X-Men Mutant Academy 2
		hitstun=function() return memory.read_u8(0x0AE512, "MainRAM") end,
		comboed=function() return memory.read_u8(0x0AE52A, "MainRAM") end,
		func=xmen_swap
	},
	['StarGlad']={ -- Star Gladiator PSX
		hitstun=function() return memory.read_u8(0x1C70D3, "MainRAM") end,
		backup=function() return memory.read_u8(0x1D7E17, "MainRAM") end,
		func=star_swap
	},
	['GGv1']={ --Guilty Gear v1.00 PSX USA
		hitstun=function() return memory.read_u8(0x07C9DE, "MainRAM") end, --While finding addresses to indicate grabbing is easy, getting them to work is a pain since the same address also share the same value for blocking and certain hits. Will require tons of effort to find an address or values that is unique to grabs only for all chars.
	},
	['GundamBattleM1']={ -- Gundam - The Battle Master (Japan)(PSX)
		hitstun1=function() return memory.read_u8(0x11A208, "MainRAM") end,
		hitstun2=function() return memory.read_u8(0x11A230, "MainRAM") end,
		hitstun3=function() return memory.read_u8(0x11A258, "MainRAM") end,
		hitstun4=function() return memory.read_u8(0x11A280, "MainRAM") end,
		hitstun5=function() return memory.read_u8(0x11A2A8, "MainRAM") end,
		hitstun6=function() return memory.read_u8(0x11A2D0, "MainRAM") end,
		hitstun7=function() return memory.read_u8(0x11A2F8, "MainRAM") end,
		hitstun8=function() return memory.read_u8(0x11A320, "MainRAM") end,
		hitstun9=function() return memory.read_u8(0x11A348, "MainRAM") end,
		hitstun10=function() return memory.read_u8(0x11A370, "MainRAM") end,
		hitstun11=function() return memory.read_u8(0x11A398, "MainRAM") end,
		hitstun12=function() return memory.read_u8(0x11A3C0, "MainRAM") end,
		hitstun13=function() return memory.read_u8(0x11A3E8, "MainRAM") end,
		hitstun14=function() return memory.read_u8(0x11A410, "MainRAM") end,
		hitstun15=function() return memory.read_u8(0x11A438, "MainRAM") end,
		hitstun16=function() return memory.read_u8(0x11A460, "MainRAM") end,
		hitstun17=function() return memory.read_u8(0x11A488, "MainRAM") end,
		hitstun18=function() return memory.read_u8(0x11A4B0, "MainRAM") end,
		hitstun19=function() return memory.read_u8(0x11A4D8, "MainRAM") end,
		hitstun20=function() return memory.read_u8(0x11A500, "MainRAM") end,
		hitstun21=function() return memory.read_u8(0x11A528, "MainRAM") end,
		hitstun22=function() return memory.read_u8(0x11A550, "MainRAM") end,
		hitstun23=function() return memory.read_u8(0x11A578, "MainRAM") end,
		hitstun24=function() return memory.read_u8(0x11A5A0, "MainRAM") end,
		hitstun25=function() return memory.read_u8(0x11A5C8, "MainRAM") end,
		hitstun26=function() return memory.read_u8(0x11A5F0, "MainRAM") end,
		hitstun27=function() return memory.read_u8(0x11A618, "MainRAM") end,
		hitstun28=function() return memory.read_u8(0x11A640, "MainRAM") end,
		hitstat=function() return memory.read_u8(0x11A2F3, "MainRAM") end,
		func=gundam_battle_swap
	},
	['GundamBattleM2']={ -- Gundam - The Battle Master 2 (Japan)(PSX)
		hitstun=function() return memory.read_u8(0x175AD2, "MainRAM") end,
	},
	['Kensei']={ -- Kensei - Sacred Fist (USA)(PSX)
		hitstun=function() return memory.read_u8(0x0AE3D0, "MainRAM") end,
	},
	['KOF95PSX']={ -- The King of Fighters '95 (USA)(PSX)
		hitstun=function() return memory.read_u8(0x08871F, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x08B5C0, "MainRAM") end,
		func=grab_swap
	},
	['SF2Coll2PSX']={ -- Street Fighter Collection 2 USA PSX
		hitstun=function() return memory.read_u8(0x16BEC9, "MainRAM") end,
		health=function() return memory.read_u8(0x16BFC0, "MainRAM") end,
		block=function() return memory.read_u8(0x16BECA, "MainRAM") end,
		backup=function() return memory.read_u8(0x1C2605, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x16C1ED, "MainRAM") end,
		func=sf2coll_swap
	},
	['SF2CollPSX']={ -- Street Fighter Collection Disc 1 USA PSX
		hitstun=function() return memory.read_u8(0x175109, "MainRAM") end,
		health=function() return memory.read_u8(0x1751FC, "MainRAM") end,
		block=function() return memory.read_u8(0x17510A, "MainRAM") end,
		backup=function() return memory.read_u8(0x1C0989, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x17548D, "MainRAM") end,
		comboed=function() return memory.read_u8(0x175238, "MainRAM") end,
		func=supersf2coll_swap
	},
	['MSHVSSFSat']={ -- Marvel Super Heroes vs Street Fighter Saturn Japan
		hitstun=function() return memory.read_u8(0x0F3D11, "Work Ram High") end,
	},
	['XMENVSSFSat']={ -- X-Men vs Street Fighter Saturn Japan
		hitstun=function() return memory.read_u8(0x0F4511, "Work Ram High") end,
	},
	['XMENChildrenSat']={ -- X-Men - Children of the Atom Saturn
		hitstun=function() return memory.read_u8(0x0E4511, "Work Ram High") end,
	},
	['VF2Sat']={ -- Virtua Fighter 2 Saturn
		hitstun=function() return memory.read_u8(0x0626E7, "Work Ram High") end,
		grabbed=function() return memory.read_u8(0x0FA1A1, "Work Ram High") end,
		ringout=function() return memory.read_u8(0x06262E, "Work Ram High") end,
		func=virtua_fighter2_swap
	},
	['WakuWaku7']={ -- Waku Waku 7 Saturn
		hitstun=function() return memory.read_u8(0x0A39A0, "Work Ram High") end,
		grabbed=function() return memory.read_u8(0x0A957D, "Work Ram High") end,
		func=grab_swap
	},
	['VFRemix']={ -- Virtua Fighter Remix Saturn
		hitstun=function() return memory.read_u8(0x09207C, "Work Ram High") end,
		grabbed=function() return memory.read_u8(0x091ECF, "Work Ram High") end,
		func=VFR_swap
	},
	['VFKidsSat']={ -- Virtua Fighter Kids
		hitstun=function() return memory.read_u8(0x045EA3, "Work Ram High") end,
		grabbed=function() return memory.read_u8(0x0FA1A1, "Work Ram High") end,
		ringout=function() return memory.read_u8(0x045DEA, "Work Ram High") end,
		func=virtua_fighter2_swap
	},
	['SFTMSat']={ -- Street Fighter The Movie Saturn USA
		health=function() return memory.read_u8(0x050A86, "Work Ram High") end,
		comboed=function() return memory.read_u8(0x050A38, "Work Ram High") end,
		round=function() return memory.read_u8(0x0508BC, "Work Ram High") end,
		block=function() return memory.read_u8(0x0509DC, "Work Ram High") end,
		func=health_swap_SFTM
	},
	['KIGoldRev2']={ -- Killer Instinct Gold Rev 2/B
		hitstun=function() return memory.read_u8(0x1D364D, "RDRAM") end,
	},
	['KIGold&Rev1']={ -- Killer Instinct Gold & Rev 1/A
		hitstun=function() return memory.read_u8(0x1D35BD, "RDRAM") end,
	},
	['KIGoldPAL']={ -- Killer Instinct Gold Europe
		hitstun=function() return memory.read_u8(0x1D36BD, "RDRAM") end,
	},
	['FightersDestiny']={ -- Fighters Destiny USA
		hitstun=function() return memory.read_u8(0x207585, "RDRAM") end,
		health=function() return memory.read_u8(0x2031E5, "RDRAM") end,
		grabbed=function() return memory.read_u8(0x1F7AFA, "RDRAM") end,
		func=fighters_destiny
	},
	['FightersDestiny2']={ -- Fighters Destiny 2 USA
		hitstun=function() return memory.read_u8(0x1F2D19, "RDRAM") end,
		health=function() return memory.read_u8(0x1ED13D, "RDRAM") end,
		grabbed=function() return memory.read_u8(0x1CEC8B, "RDRAM") end,
		func=fighters_destiny2
	},
	['GarouMOTW']={ -- Garou - Mark of the Wolves (Arcade)(NGM-2530)
		hitstun=function() return memory.read_u8(0xA39D, "m68000 : ram : 0x100000-0x10FFFF") end,
		grabbed=function() return memory.read_u8(0x0490, "m68000 : ram : 0x100000-0x10FFFF") end,
		func=garou_MOTW
	},
}

function get_name_from_name_db(target, database)
	local represent = nil
	local findname = io.open(database, 'r')
	
	for file in findname:lines() do
		local name, tag = file:match("^(.+)%s+(%S+)$") --("(.+)%s+(%S+)")
		if name == target then represent = tag; break end
		end
		findname:close()
		return represent
end


local function get_game_tag()
	local tag = get_tag_from_hash_db(gameinfo.getromhash(), 'plugins/fighting-hashes.dat')
	
	if tag ~= nil and gamedata[tag] ~= nil then 
		return tag
		end
		return nil
end

local function get_game_tag_from_name()
	local tag = get_name_from_name_db(gameinfo.getromname(), 'plugins/fighting-names.dat')
	
	if tag ~= nil and gamedata[tag] ~= nil then
		return tag
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

	local tag = data.tags[gameinfo.getromhash()] or data.tags[gameinfo.getromname()] or get_game_tag() or get_game_tag_from_name()
		if get_game_tag() ~= nil then
		data.tags[gameinfo.getromhash()] = tag or NO_MATCH
		elseif get_game_tag_from_name() ~= nil then
		data.tags[gameinfo.getromname()] = tag or NO_MATCH
		end
	-- first time through with a bad match, tag will be nil
	-- can use this to print a debug message only the first time
	if tag ~= nil and tag ~= NO_MATCH then
		log_message('game match: ' .. tag)
		local gamemeta = gamedata[tag]
		local func = gamemeta.func or hitstun_swap
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
	if schedule_swap and frames_since_restart > 20 then
		swap_game_delay(delay or 3)
		swap_scheduled = true
	end
end

return plugin