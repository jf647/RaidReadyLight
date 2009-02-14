--
-- $Id$
--

-- module setup
RRL = LibStub("AceAddon-3.0"):NewAddon(
    "RRL",
    "AceConsole-3.0",
    "AceComm-3.0",
    "AceEvent-3.0",
	"AceTimer-3.0",
	"AceHook-3.0"
)

-- external libs
local crayon = LibStub("LibCrayon-3.0")

-- locale setup
-- local L = LibStub("AceLocale-3.0"):GetLocale("RRL", true)

-- frame setup
local ldb_tip
local frame	= CreateFrame("Button", "RRL")
local active = 0

-- LDB setup
local ldb_obj = LibStub("LibDataBroker-1.1"):NewDataObject("RRL", {
	text = "Not Active",
	icon = "Interface\\RAIDFRAME\\ReadyCheck-Ready.png",
	ready = 0,
	notready = 0,
	critnotready = 0,
	rostersize = 40,
	notreadymembers = {},
	status = false,
})
function ldb_obj.OnClick(_, which)
	if 1 == active then
		if "LeftButton" == which then
			RRL:ToggleReady()
		else if "RightButton" == which then
			DoReadyCheck()
		end
		end
	end
end

-- local variables
local send_timer
local process_timer
local readystate = false
local roster = {}
local inraid = false
local lightstatus = false

-- slash commands
RRL.options = {
    name = "rrl",
    handler = RRL,
    type = 'group',
    args = {
        max = {
            type = 'range',
            name = 'get/set max not ready',
            desc = 'get or set the maximum number of not ready members',
			min  = 0,
			max  = 40,
			step = 1,
            set  = 'SetMax',
            get  = 'GetMax',
        },
        interval = {
            type = 'range',
            name = 'get/set update interval',
            desc = 'get or set the raid update interval',
			min  = 1,
			max  = 3600,
			step = 1,
            set  = 'SetInterval',
            get  = 'GetInterval',
        },
		readycheck = {
			type = 'toggle',
			name = 'toggle readycheck',
			desc = 'toggle auto-response to ready checks',
			get  = 'GetReadyCheck',
			set  = 'ToggleReadyCheck',
		},
        r = {
            type = 'toggle',
            name = 'toggle ready',
            desc = 'toggle your ready state',
            get  = 'GetReady',
			set  = 'ToggleReady',
        },
        critical = {
		    name = 'critical',
			desc = 'manipulate list of members who must be ready',
            type = 'group',
            args = {
                add = {
                    type = 'input',
                    name = 'add a critical member',
                    desc = 'add a member who must be ready',
                    set = 'AddCritical',
                },
                del = {
                    type = 'input',
                    name = 'delete a critical member',
                    desc = 'delete a member who must be ready',
                    set = 'DelCritical',
                },
                list = {
                    type = 'execute',
                    name = 'lists critical members',
                    desc = 'lists members who must be ready',
                    func  = 'ListCritical',
                },
                clear = {
                    type = 'execute',
                    name = 'clears critical members',
                    desc = 'clears members who must be ready',
                    func  = 'ClearCritical',
                },
            },
        },
    },
}

-- default profile
RRL.defaults = {
    profile = {
	    updateinterval = 30,
		maxnotready = 1,
		readycheck_respond = 1,
		critical = {},
	},
}

-- init
function RRL:OnInitialize()
    -- load saved variables
    self.db = LibStub("AceDB-3.0"):New("RRLDB", self.defaults)
	-- add AceDB profile handler
	self.options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	self.options.args.profile.order = 200
	-- register options
	LibStub("AceConfig-3.0"):RegisterOptionsTable("rrl", self.options, {"rrl"})
end

-- enable
function RRL:OnEnable()
    -- register our events
	RRL:RegisterEvent("PARTY_MEMBERS_CHANGED", "RRL_CHECK_RAID")
	RRL:RegisterEvent("RAID_ROSTER_UPDATE", "RRL_CHECK_RAID")
	RRL:RegisterEvent("RRL_JOIN_RAID")
	RRL:RegisterEvent("RRL_LEAVE_RAID")
	-- are we in a raid
	if GetNumRaidMembers() > 0 then
		inraid = true
		self:RRL_JOIN_RAID()
	end
end

-- disable
function RRL:OnDisable()
	RRL:UnegisterAllEvents()
end

-- start doing what we need to do in a raid
function RRL:RRL_JOIN_RAID()
	active = 1
	-- register our events
    RRL:RegisterEvent("RRL_SEND_UPDATE")
    RRL:RegisterEvent("RRL_PROCESS_UPDATE")
    RRL:RegisterEvent("RRL_UPDATE_ROSTER")
    RRL:RegisterEvent("RRL_UPDATE_STATUS")
	-- register to receive addon messages
    RRL:RegisterComm("RRL1")
	-- start firing RRL_SEND_UPDATE every x seconds
    send_timer = self:ScheduleRepeatingTimer('RRL_SEND_UPDATE', self.db.profile.updateinterval)
	-- update the roster
	self:RRL_UPDATE_ROSTER()
	-- hook ready checks if requested to
	if self.db.profile.readycheck_respond then
		if not self:IsHooked("ShowReadyCheck") then
			self:RawHook("ShowReadyCheck", true)
		end
		RRL:RegisterEvent("READY_CHECK")
	else
		if self:IsHooked("ShowReadyCheck") then
			self:Unhook("ShowReadyCheck")
		end
		RRL:UnregisterEvent("READY_CHECK")
	end
end

-- stop doing what we do in a raid
function RRL:RRL_LEAVE_RAID()
	active = 0
	ldb_obj.text = "Not Active"
	-- stop sending updates
	self:CancelTimer(send_timer, true)
	-- unregister receiving messages
	self:UnregisterComm("RRL1")
	-- unhook ready checks
	if self:IsHooked("ShowReadyCheck") then
		self:Unhook("ShowReadyCheck")
	end
	RRL:UnregisterEvent("READY_CHECK")
end

-- check our raid status and raid roster
function RRL:RRL_CHECK_RAID()
	if GetNumRaidMembers() > 0 then
		if not inraid then
			inraid = true
			self:RRL_JOIN_RAID()
		end
		self:RRL_UPDATE_ROSTER()
	else
		if inraid then
			inraid = false
			self:RRL_LEAVE_RAID()
		end
	end
end

-- process a received addon message
function RRL:OnCommReceived(prefix, message, distribution, sender)
    -- process the incoming message
    local update = {}
	update.sender = sender
	update.message = message
    self:RRL_PROCESS_UPDATE(update)
end

-- process a RRL_SEND_UPDATE event
function RRL:RRL_SEND_UPDATE()
	local message = "1"
	if not readystate then
		message = "0"
	end
    RRL:SendCommMessage("RRL1", message, "RAID")
end

-- process a RRL_PROCESS_UPDATE event
function RRL:RRL_PROCESS_UPDATE(update)
	local senderstate = true
	if "0" == update.message then
		senderstate = false
	end
	oldstate = roster[update.member]
	roster[update.sender] = senderstate
	if nil ~= oldstate then
		if oldstate ~= senderstate then
			self:CancelTimer(process_timer, true)
			process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
		end
	else
		self:CancelTimer(process_timer, true)
		process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
	end
end

-- process a RRL_UPDATE_ROSTER event
function RRL:RRL_UPDATE_ROSTER()
	local newroster = {}
	for i = 1, 40, 1
	do
		local name, rank, subgroup, level, class, fileName, 
			zone, online, isDead, role, isML = GetRaidRosterInfo(i)
		if name then
			if online and roster[name] and true == roster[name] then
				newroster[name] = true
			else
				newroster[name] = false
			end
		end
	end
	roster = newroster
	self:RRL_UPDATE_STATUS()
end

-- process an UPDATE_STATUS event
function RRL:RRL_UPDATE_STATUS()
	local numready = 0
	local numnotready = 0
	local rostersize = 0
	local numcriticalnotready = 0
	ldb_obj.notreadymembers = {}
	lightstatus = true
	for k,v in pairs(roster) do
	    rostersize = rostersize + 1
		if not v then
			numnotready = numnotready + 1
			ldb_obj.notreadymembers[k] = 1
			if self.db.profile.critical[k] then
				ldb_obj.notreadymembers[k] = 2
				numcriticalnotready = numcriticalnotready + 1
				lightstatus = false
			end
		else
			numready = numready + 1
		end
	end
	if numnotready > self.db.profile.maxnotready then
		lightstatus = false
	end
	ldb_obj.ready = numready
	ldb_obj.notready = numnotready
	ldb_obj.critnotready = numcriticalnotready
	ldb_obj.rostersize = rostersize
	local youstring
	local raidstring
	local countstring
	if readystate then
		youstring = crayon:Green("YOU")
	else
		youstring = crayon:Red("YOU")
	end
	if lightstatus then
		ldb_obj.status = true
		ldb_obj.icon = "Interface\\RAIDFRAME\\ReadyCheck-Ready.png"
		raidstring = crayon:Green("RAID")
	else
		ldb_obj.status = false
		ldb_obj.icon = "Interface\\RAIDFRAME\\ReadyCheck-NotReady.png"
		raidstring = crayon:Red("RAID")
	end
	countstring = numready.."/"..rostersize
	if numcriticalnotready > 0 then
		countstring = countstring .. "*"
	end
	ldb_obj.text = youstring .. "/" .. raidstring .. " " .. crayon:White(countstring)
end

-- display the LDB tooltip
function ldb_obj.OnTooltipShow(tip)
	if not ldb_tip then
		ldb_tip = tip
	end
	tip:ClearLines()
	tip:AddLine(crayon:White("RRL: Raid Ready Light"))
	tip:AddLine(" ")
	if 0 == active then
		tip:AddLine(crayon:White("Only active when in a raid"))
	else
		if ldb_obj.status then
			tip:AddDoubleLine(crayon:White("Raid:"), crayon:Green("READY"))
		else
			tip:AddDoubleLine(crayon:White("Raid:"), crayon:Red("NOT READY"))
		end
		if readystate then
			tip:AddDoubleLine(crayon:White("You:"), crayon:Green("READY"))
		else
			tip:AddDoubleLine(crayon:White("You:"), crayon:Red("NOT READY"))
		end
		tip:AddDoubleLine(crayon:White("Ready:"), crayon:Colorize(crayon:GetThresholdHexColor(ldb_obj.ready,ldb_obj.rostersize), ldb_obj.ready)
			.. "/"..crayon:Colorize(crayon:GetThresholdHexColor(ldb_obj.rostersize,ldb_obj.rostersize), ldb_obj.rostersize))
		tip:AddDoubleLine(crayon:White("Not Ready:"), crayon:Red(ldb_obj.notready) .. "/".. crayon:Green(RRL.db.profile.maxnotready))
		tip:AddDoubleLine(crayon:White("Critical: "), crayon:Red(ldb_obj.critnotready))
		if ldb_obj.notready then
			tip:AddLine(" ")
			tip:AddLine(crayon:White("Not Ready:"))
			for k,v in pairs(ldb_obj.notreadymembers)
			do
				if 2 == v then
					tip:AddLine(crayon:Red(k))
				else
					tip:AddLine(crayon:Yellow(k))
				end
			end
		end
		tip:AddLine(" ")
		tip:AddLine(crayon:White("Left-click to change your status"))
		tip:AddLine(crayon:White("Right-click to do a ready check"))
	end
	tip:Show()
end

-- get the max number of not ready members
function RRL:GetMax()
    return self.db.profile.maxnotready
end

-- set the max number of not ready members
function RRL:SetMax(info, max)
	if max < 0 or max > 40 then
		RRL:Print("max ready members range: 0-40")
	else
		self.db.profile.maxnotready = max
		self:CancelTimer(process_timer, true)
		process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
	end
end

-- get the update interval
function RRL:GetInterval()
    return self.db.profile.updateinterval
end

-- set the update interval
function RRL:SetInterval(info, interval)
	if interval < 1 or interval > 600 then
		RRL:Print("interval range: 1-600")
	else
		self.db.profile.updateinterval = interval
		self:CancelTimer(send_timer, true)
		send_timer = self:ScheduleRepeatingTimer('RRL_SEND_UPDATE', interval)
	end
end

-- lists critical members
function RRL:ListCritical()
	RRL:Print("Members who must be ready:")
    for k,v in pairs(self.db.profile.critical)
	do
		RRL:Print(k)
	end
end

-- clears critical members
function RRL:ClearCritical()
	RRL:Print("critical members list has been cleared")
	self.db.profile.critical = {}
	self:CancelTimer(process_timer, true)
	process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
end

-- adds a critical member
function RRL:AddCritical(info, member)
	if "" ~= member then
		if self.db.profile.critical[member] then
			RRL:Print("'"..member.."' was already on the critical list")
		else
			self.db.profile.critical[member] = 1
			RRL:Print("added '"..member.."' to the critical list")
		end
	else
		member = UnitName('target')
		if nil ~= member then
			if self.db.profile.critical[member] then
				RRL:Print("'"..member.."' was already on the critical list")
			else
				self.db.profile.critical[member] = 1
				RRL:Print("added '"..member.."' to the critical list")
			end
		else
			RRL:Print("usage: /rrl critical add name (uses target if no name)")
		end
	end
	self:CancelTimer(process_timer, true)
	process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
end

-- deletes a critical member
function RRL:DelCritical(info, member)
	if "" ~= member then
		if self.db.profile.critical[member] then
			self.db.profile.critical[member] = nil
			RRL:Print("removed '"..member.."' from the critical list")
		else
			RRL:Print("'"..member.."' is not on the critical list")
		end
	else
		member = UnitName('target')
		if nil ~= member then
			if self.db.profile.critical[member] then
				self.db.profile.critical[member] = nil
				RRL:Print("removed '"..member.."' from the critical list")
			else
				RRL:Print("'"..member.."' is not on the critical list")
			end
		else
			RRL:Print("usage: /rrl critical del name (uses target if no name)")
		end
	end
	self:CancelTimer(process_timer, true)
	process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
end

-- get ready state
function RRL:GetReady()
	return readystate
end

-- toggle ready state
function RRL:ToggleReady()
    readystate = not readystate
	self:RRL_SEND_UPDATE()
end

-- get readycheck auto-response
function RRL:GetReadyCheck()
	return self.db.profile.readycheck_respond
end

-- toggle ready state
function RRL:ToggleReadyCheck()
    self.db.profile.readycheck_respond = not self.db.profile.readycheck_respond
	if self.db.profile.readycheck_respond then
		RRL:Print("will auto-respond to ready checks")
		if inraid then
			if not self:IsHooked("ShowReadyCheck") then
				self:RawHook("ShowReadyCheck", true)
			end
			RRL:RegisterEvent("READY_CHECK")
		end
	else
		RRL:Print("will not auto-respond to ready checks")
		if inraid then
			if self:IsHooked("ShowReadyCheck") then
				self:Unhook("ShowReadyCheck")
			end
			RRL:UnregisterEvent("READY_CHECK")
		end
	end
end

-- respond to a ready check for the user
function RRL:READY_CHECK()
	if readystate then
		ConfirmReadyCheck(true)
	else
		ConfirmReadyCheck(false)
	end
	RRL:Print("responded to a ready check for you")
end

-- play the ready check sound but do not show the dialog
function RRL:ShowReadyCheck()
	PlaySound("ReadyCheck")
end

--
-- EOF
