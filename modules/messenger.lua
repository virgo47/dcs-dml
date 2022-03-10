messenger = {}
messenger.version = "1.1.1"
messenger.verbose = false 
messenger.requiredLibs = {
	"dcsCommon", -- always
	"cfxZones", -- Zones, of course 
}
messenger.messengers = {} 
--[[--
	Version History
	1.0.0 - initial version 
	1.0.1 - messageOut? synonym
	      - spelling types in about 
	1.1.0 - DML flag support 
		  - clearScreen option
		  - inValue?
		  - message preprocessor 
	1.1.1 - firewalled coalition to msgCoalition
		  - messageOn?
		  - messageOff?
--]]--

function messenger.addMessenger(theZone)
	table.insert(messenger.messengers, theZone)
end

function messenger.getMessengerByName(aName) 
	for idx, aZone in pairs(messenger.messengers) do 
		if aName == aZone.name then return aZone end 
	end
	if messenger.verbose then 
		trigger.action.outText("+++msgr: no messenger with name <" .. aName ..">", 30)
	end 
	
	return nil 
end

--
-- read attributes
--
function messenger.createMessengerWithZone(theZone)
	-- start val - a range
	theZone.message = cfxZones.getStringFromZoneProperty(theZone, "message", "") 

	theZone.spaceBefore = cfxZones.getBoolFromZoneProperty(theZone, "spaceBefore", false)
	theZone.spaceAfter = cfxZones.getBoolFromZoneProperty(theZone, "spaceAfter", false)

	theZone.soundFile = cfxZones.getStringFromZoneProperty(theZone, "soundFile", "<none>") 

	theZone.clearScreen = cfxZones.getBoolFromZoneProperty(theZone, "clearScreen", false)
	
	-- alternate version: messages: list of messages, need string parser first
	
	theZone.duration = cfxZones.getNumberFromZoneProperty(theZone, "duration", 30)
	
	-- trigger flag f? in? messageOut?
	if cfxZones.hasProperty(theZone, "f?") then 
		theZone.triggerMessagerFlag = cfxZones.getStringFromZoneProperty(theZone, "f?", "none")
	end
	
	-- can also use in? for counting. we always use triggerMessagerFlag 
	if cfxZones.hasProperty(theZone, "in?") then 
		theZone.triggerMessagerFlag = cfxZones.getStringFromZoneProperty(theZone, "in?", "none")
	end
	
	if cfxZones.hasProperty(theZone, "messageOut?") then 
		theZone.triggerMessagerFlag = cfxZones.getStringFromZoneProperty(theZone, "messageOut?", "none")
	end
	
	if theZone.triggerMessagerFlag then 
		theZone.lastMessageTriggerValue = cfxZones.getFlagValue(theZone.triggerMessagerFlag, theZone)-- trigger.misc.getUserFlag(theZone.triggerMessagerFlag) -- save last value
	end

	theZone.messageOff = false 
	if cfxZones.hasProperty(theZone, "messageOff?") then 
		theZone.messageOffFlag = cfxZones.getStringFromZoneProperty(theZone, "messageOff?", "*none")
		theZone.lastMessageOff = cfxZones.getFlagValue(theZone.messageOffFlag, theZone)
	end
	
	if cfxZones.hasProperty(theZone, "messageOn?") then 
		theZone.messageOnFlag = cfxZones.getStringFromZoneProperty(theZone, "messageOn?", "*none")
		theZone.lastMessageOn = cfxZones.getFlagValue(theZone.messageOnFlag, theZone)
	end
	
	if cfxZones.hasProperty(theZone, "coalition") then 
		theZone.msgCoalition = cfxZones.getCoalitionFromZoneProperty(theZone, "coalition", 0)
	end 
	
	if cfxZones.hasProperty(theZone, "msgCoalition") then 
		theZone.msgCoalition = cfxZones.getCoalitionFromZoneProperty(theZone, "msgCoalition", 0)
	end 
	
	-- flag whose value can be read 
	if cfxZones.hasProperty(theZone, "messageValue?") then 
		theZone.messageValue = cfxZones.getStringFromZoneProperty(theZone, "messageValue?", "<none>") 
	end
	
	if messenger.verbose then 
		trigger.action.outText("+++Msg: new zone <".. theZone.name .."> will say <".. theZone.message .. ">", 30)
	end
end

--
-- Update 
--
function messenger.getMessage(theZone)
	local msg = theZone.message
	-- see if it has a "$val" in there 
	local zName = theZone.name 
	if not zName then zName = "<strange!>" end 
	local zVal = "<n/a>"
	if theZone.messageValue then 
		zVal = cfxZones.getFlagValue(theZone.messageValue, theZone)
		zVal = tostring(zVal)
		if not zVal then zVal = "<err>" end 
	end 
	
	
	-- replace *zone and *value wildcards 
	msg = string.gsub(msg, "*name", zName)
	msg = string.gsub(msg, "*value", zVal)
	
	return msg 
end

function messenger.isTriggered(theZone)
	-- this module has triggered 
	if theZone.messageOff then 
		if messenger.verbose then 
			trigger.action.outFlag("msg: message for <".. theZone.name .."> is OFF",30)
		end
		return 
	end
	
	local fileName = "l10n/DEFAULT/" .. theZone.soundFile
	local msg = messenger.getMessage(theZone)
	if messenger.verbose then 
		trigger.action.outText("+++Msg: <".. theZone.name .."> will say <".. msg .. ">", 30)
	end
	
	if theZone.spaceBefore then msg = "\n"..msg end 
	if theZone.spaceAfter then msg = msg .. "\n" end 
	
	if theZone.msgCoalition then 
		trigger.action.outTextForCoalition(theZone.msgCoalition, msg, theZone.duration, theZone.clearScreen)
		trigger.action.outSoundForCoalition(theZone.msgCoalition, fileName)
	else 
		-- out to all 
		trigger.action.outText(msg, theZone.duration, theZone.clearScreen)
		trigger.action.outSound(fileName)
	end
end

function messenger.update()
	-- call me in a second to poll triggers
	timer.scheduleFunction(messenger.update, {}, timer.getTime() + 1)
		
	for idx, aZone in pairs(messenger.messengers) do
		-- make sure to re-start before reading time limit
		if aZone.triggerMessagerFlag then 
			local currTriggerVal = cfxZones.getFlagValue(aZone.triggerMessagerFlag, aZone) -- trigger.misc.getUserFlag(aZone.triggerMessagerFlag)
			if currTriggerVal ~= aZone.lastMessageTriggerValue
			then 
				if messenger.verbose then 
					trigger.action.outText("+++msgr: triggered on in? for <".. aZone.name ..">", 30)
				end
				messenger.isTriggered(aZone)
				aZone.lastMessageTriggerValue = cfxZones.getFlagValue(aZone.triggerMessagerFlag, aZone) -- trigger.misc.getUserFlag(aZone.triggerMessagerFlag) -- save last value
			end
		end
		
		if aZone.messageOffFlag then 
			local currVal = cfxZones.getFlagValue(aZone.messageOffFlag, aZone) 
			if currVal ~= aZone.lastMessageOff then
				aZone.messageOff = true 
				aZone.lastMessageOff = currVal
				if messenger.verbose then 
					trigger.action.outText("+++msg: messenger <" .. aZone.name .. "> turned ***OFF***", 30)
				end 
			end
		end
		
		if aZone.messageOnFlag then 
			local currVal = cfxZones.getFlagValue(aZone.messageOnFlag, aZone) 
			if currVal ~= aZone.lastMessageOn then
				aZone.messageOff = false 
				aZone.lastMessageOn = currVal
				if messenger.verbose then 
					trigger.action.outText("+++msg: messenger <" .. aZone.name .. "> turned ON", 30)
				end
			end
		end
	end
end

--
-- Config & Start
--
function messenger.readConfigZone()
	local theZone = cfxZones.getZoneByName("messengerConfig") 
	if not theZone then 
		if messenger.verbose then 
			trigger.action.outText("+++msgr: NO config zone!", 30)
		end 
		return 
	end 
	
	messenger.verbose = cfxZones.getBoolFromZoneProperty(theZone, "verbose", false)
	
	if messenger.verbose then 
		trigger.action.outText("+++msgr: read config", 30)
	end 
end

function messenger.start()
	-- lib check
	if not dcsCommon.libCheck then 
		trigger.action.outText("cfx Messenger requires dcsCommon", 30)
		return false 
	end 
	if not dcsCommon.libCheck("cfx Messenger", messenger.requiredLibs) then
		return false 
	end
	
	-- read config 
	messenger.readConfigZone()
	
	-- process cloner Zones 
	local attrZones = cfxZones.getZonesWithAttributeNamed("messenger")
	for k, aZone in pairs(attrZones) do 
		messenger.createMessengerWithZone(aZone) -- process attributes
		messenger.addMessenger(aZone) -- add to list
	end
	
	-- start update 
	messenger.update()
	
	trigger.action.outText("cfx Messenger v" .. messenger.version .. " started.", 30)
	return true 
end

-- let's go!
if not messenger.start() then 
	trigger.action.outText("cfx Messenger aborted: missing libraries", 30)
	messenger = nil 
end

--[[--
Wildcard extension: 
  messageValue supports multiple flags like 1-3, *hi ther, *bingo and then *value[name] returns that value 	
--]]--