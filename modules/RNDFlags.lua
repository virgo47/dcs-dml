rndFlags = {}
rndFlags.version = "1.1.0"
rndFlags.verbose = false 
rndFlags.requiredLibs = {
	"dcsCommon", -- always
	"cfxZones", -- Zones, of course 
}
--[[
	Random Flags: DML module to select flags at random
	and then change them
	
	Copyright 2022 by Christian Franz and cf/x 
	
	Version History
	1.0.0 - Initial Version 
	1.1.0 - DML flag conversion:
				flagArrayFromString: strings OK, trim 
				remove pollFlag
				pollFlag from cfxZones, include zone 
				randomBetween for pollSize
				pollFlag to bang done with inc
				getFlagValue in update 
				some code clean-up
				rndMethod synonym 
--]]
rndFlags.rndGen = {}

function rndFlags.addRNDZone(aZone)
	table.insert(rndFlags.rndGen, aZone)
end

function rndFlags.flagArrayFromString(inString)
	if string.len(inString) < 1 then 
		trigger.action.outText("+++RND: empty flags", 30)
		return {} 
	end
	if rndFlags.verbose then 
		trigger.action.outText("+++RND: processing <" .. inString .. ">", 30)
	end 
	
	local flags = {}
	local rawElements = dcsCommon.splitString(inString, ",")
	-- go over all elements 
	for idx, anElement in pairs(rawElements) do 
		if dcsCommon.stringStartsWithDigit(anElement) and  dcsCommon.containsString(anElement, "-") then 
			-- interpret this as a range
			local theRange = dcsCommon.splitString(anElement, "-")
			local lowerBound = theRange[1]
			lowerBound = tonumber(lowerBound)
			local upperBound = theRange[2]
			upperBound = tonumber(upperBound)
			if lowerBound and upperBound then
				-- swap if wrong order
				if lowerBound > upperBound then 
					local temp = upperBound
					upperBound = lowerBound
					lowerBound = temp 
				end
				-- now add add numbers to flags
				for f=lowerBound, upperBound do 
					table.insert(flags, f)

				end
			else
				-- bounds illegal
				trigger.action.outText("+++RND: ignored range <" .. anElement .. "> (range)", 30)
			end
		else
			-- single number
			f = dcsCommon.trim(anElement) -- DML flag upgrade: accept strings tonumber(anElement)
			if f then 
				table.insert(flags, f)

			else 
				trigger.action.outText("+++RND: ignored element <" .. anElement .. "> (single)", 30)
			end
		end
	end
	if rndFlags.verbose then 
		trigger.action.outText("+++RND: <" .. #flags .. "> flags total", 30)
	end 
	return flags
end

--
-- create rnd gen from zone 
--
function rndFlags.createRNDWithZone(theZone)
	local flags = cfxZones.getStringFromZoneProperty(theZone, "flags!", "")
	if flags == "" then 
		-- let's try alternate spelling without "!"
		flags = cfxZones.getStringFromZoneProperty(theZone, "flags", "") 
	end 
	-- now build the flag array from strings
	local theFlags = rndFlags.flagArrayFromString(flags)
	theZone.myFlags = theFlags


	theZone.pollSizeMin, theZone.pollSize = cfxZones.getPositiveRangeFromZoneProperty(theZone, "pollSize", 1)
	if rndFlags.verbose then 
		trigger.action.outText("+++RND: pollSize is <" .. theZone.pollSizeMin .. ", " .. theZone.pollSize .. ">", 30)
	end
			 
	
	theZone.remove = cfxZones.getBoolFromZoneProperty(theZone, "remove", false)

	-- trigger flag 
	if cfxZones.hasProperty(theZone, "f?") then 
		theZone.triggerFlag = cfxZones.getStringFromZoneProperty(theZone, "f?", "none")
	end
	
	if cfxZones.hasProperty(theZone, "in?") then 
		theZone.triggerFlag = cfxZones.getStringFromZoneProperty(theZone, "in?", "none")
	end
	
	if cfxZones.hasProperty(theZone, "rndPoll?") then 
		theZone.triggerFlag = cfxZones.getStringFromZoneProperty(theZone, "rndPoll?", "none")
	end
	
	if theZone.triggerFlag then 
		theZone.lastTriggerValue = cfxZones.getFlagValue(theZone.triggerFlag, theZone) --trigger.misc.getUserFlag(theZone.triggerFlag) -- save last value
	end
	
	theZone.onStart = cfxZones.getBoolFromZoneProperty(theZone, "onStart", false)
	
	if not theZone.onStart and not theZone.triggerFlag then 
		theZone.onStart = true 
	end
	
	theZone.rndMethod = cfxZones.getStringFromZoneProperty(theZone, "method", "on")
	if cfxZones.hasProperty(theZone, "rndMethod") then 
		theZone.rndMethod = cfxZones.getStringFromZoneProperty(theZone, "rndMethod", "on")
	end
	
	theZone.reshuffle = cfxZones.getBoolFromZoneProperty(theZone, "reshuffle", false)
	if theZone.reshuffle then 
		-- create a backup copy we can reshuffle from 
		theZone.flagStore = dcsCommon.copyArray(theFlags)
	end
	
	-- done flag 
	if cfxZones.hasProperty(theZone, "done+1") then 
		theZone.doneFlag = cfxZones.getStringFromZoneProperty(theZone, "done+1", "none")
	end
end

function rndFlags.reshuffle(theZone)
	if rndFlags.verbose then 
		trigger.action.outText("+++RND: reshuffling zone " .. theZone.name, 30)
	end
	theZone.myFlags = dcsCommon.copyArray(theZone.flagStore)
end

--
-- fire RND
-- 

function rndFlags.fire(theZone) 
	-- fire this rnd 
	-- create a local copy of all flags 
	if theZone.reshuffle and #theZone.myFlags < 1 then 
		rndFlags.reshuffle(theZone)
	end
	
	local availableFlags = dcsCommon.copyArray(theZone.myFlags) 
	
	-- do this pollSize times 
	local pollSize = dcsCommon.randomBetween(theZone.pollSizeMin, theZone.pollSize)

	
	if #availableFlags < 1 then 
		if rndFlags.verbose then 
			trigger.action.outText("+++RND: RND " .. theZone.name .. " ran out of flags. aborting fire", 30)
		end
		
		if theZone.doneFlag then
			cfxZones.pollFlag(theZone.doneFlag, "inc", theZone)
		end
		
		return 
	end
	
	if rndFlags.verbose then 
		trigger.action.outText("+++RND: firing RND " .. theZone.name .. " with pollsize " .. pollSize .. " on " .. #availableFlags .. " set size", 30)
	end
	
	for i=1, pollSize do 
		-- check there are still flags left 
		if #availableFlags < 1 then 
			trigger.action.outText("+++RND: no flags left in " .. theZone.name .. " in index " .. i, 30)
			theZone.myFlags = {} 
			if theZone.reshuffle then 
				rndFlags.reshuffle(theZone)
			end
			return 
		end
		
		-- select a flag, enforce uniqueness
		local theFlagIndex = dcsCommon.smallRandom(#availableFlags)
		
		-- poll this flag and remove from available
		local theFlag = table.remove(availableFlags,theFlagIndex)
		
		--rndFlags.pollFlag(theFlag, theZone.rndMethod)
		cfxZones.pollFlag(theFlag, theZone.rndMethod, theZone) 
	end
	
	-- remove if requested
	if theZone.remove then 
		theZone.myFlags = availableFlags
	end
end

--
-- update 
--
function rndFlags.update()
	-- call me in a second to poll triggers
	timer.scheduleFunction(rndFlags.update, {}, timer.getTime() + 1)
	
	for idx, aZone in pairs(rndFlags.rndGen) do
		if aZone.triggerFlag then 
			local currTriggerVal = cfxZones.getFlagValue(aZone.triggerFlag, aZone) -- trigger.misc.getUserFlag(aZone.triggerFlag)
			if currTriggerVal ~= aZone.lastTriggerValue
			then 
				if rndFlags.verbose then 
					trigger.action.outText("+++RND: triggering " .. aZone.name, 30)
				end 
				rndFlags.fire(aZone)
				aZone.lastTriggerValue = currTriggerVal
			end

		end
	end
end

--
-- start cycle: force all onStart to fire 
--
function rndFlags.startCycle()
	for idx, theZone in pairs(rndFlags.rndGen) do
		if theZone.onStart then 
			if rndFlags.verbose then 
				trigger.action.outText("+++RND: starting " .. theZone.name, 30)
			end 
			rndFlags.fire(theZone)
		end
	end
end


--
-- start module and read config 
--
function rndFlags.readConfigZone()
	-- note: must match exactly!!!!
	local theZone = cfxZones.getZoneByName("rndFlagsConfig") 
	if not theZone then 
		if rndFlags.verbose then 
			trigger.action.outText("***RND: NO config zone!", 30)
		end 
		return 
	end 
	
	rndFlags.verbose = cfxZones.getBoolFromZoneProperty(theZone, "verbose", false)
	
	if rndFlags.verbose then 
		trigger.action.outText("***RND: read config", 30)
	end 
end

function rndFlags.start()
	-- lib check
	if not dcsCommon.libCheck then 
		trigger.action.outText("RNDFlags requires dcsCommon", 30)
		return false 
	end 
	if not dcsCommon.libCheck("cfx Random Flags", 
		rndFlags.requiredLibs) then
		return false 
	end
	
	-- read config 
	rndFlags.readConfigZone()
	
	-- process RND Zones 
	local attrZones = cfxZones.getZonesWithAttributeNamed("RND")
	
	-- now create an rnd gen for each one and add them
	-- to our watchlist 
	for k, aZone in pairs(attrZones) do 
		rndFlags.createRNDWithZone(aZone) -- process attribute and add to zone
		rndFlags.addRNDZone(aZone) -- remember it so we can smoke it
	end
	
	-- start cycle 
	timer.scheduleFunction(rndFlags.startCycle, {}, timer.getTime() + 0.25)
	
	-- start update 
	timer.scheduleFunction(rndFlags.update, {}, timer.getTime() + 1)
	
	trigger.action.outText("cfx random Flags v" .. rndFlags.version .. " started.", 30)
	return true 
end

-- let's go!
if not rndFlags.start() then 
	trigger.action.outText("cf/x RND Flags aborted: missing libraries", 30)
	rndFlags = nil 
end

