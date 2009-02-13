--
-- $Id$
--

RRL = LibStub("AceAddon-3.0"):NewAddon(
    "RRL",
    "AceConsole-3.0",
    "AceComm-3.0",
    "AceEvent-3.0",
	"AceTimer-3.0"
)
local L = LibStub("AceLocale-3.0"):GetLocale("RRL", true)

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
        r = {
            type = 'toggle',
            name = 'toggle ready',
            desc = 'toggle your ready state',
            get  = 'GetReady',
			set  = 'ToggleReady',
        },
		dump = {
			type = 'execute',
			name = 'dump',
			desc = 'dump',
			func = 'DumpRoster',
		},
        critical = {
		    name = 'critical',
			desc = 'manipulate list of members who must be ready',
            type = 'group',
            args = {
                add = {
                    type = 'execute',
                    name = 'add a critical member',
                    desc = 'add a member who must be ready',
                    func = 'AddCritical',
                },
                del = {
                    type = 'execute',
                    name = 'delete a critical member',
                    desc = 'delete a member who must be ready',
                    func = 'DelCritical',
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
	    updateinterval = 10,
		maxnotready = 1,
		critical = {},
	},
}

-- init
function RRL:OnInitialize()
    RRL:Print("initializing")
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
    RRL:Print("enabling")
    -- register our events
	RRL:Print("registering event PARTY_MEMBERS_CHANGED")
	RRL:RegisterEvent("PARTY_MEMBERS_CHANGED", "RRL_CHECK_RAID")
	RRL:Print("registering event RAID_ROSTER_UPDATE")
	RRL:RegisterEvent("RAID_ROSTER_UPDATE", "RRL_CHECK_RAID")
	RRL:Print("registering event RRL_JOIN_RAID")
	RRL:RegisterEvent("RRL_JOIN_RAID")
	RRL:Print("registering event RRL_LEAVE_RAID")
	RRL:RegisterEvent("RRL_LEAVE_RAID")
	-- are we in a raid
	if GetNumRaidMembers() > 0 then
		inraid = true
		self:ScheduleTimer("RRL_JOIN_RAID", 0)
	end
end

-- disable
function RRL:OnDisable()
    RRL:Print("disabling")
	RRL:UnRegisterAllEvents()
end

-- start doing what we need to do in a raid
function RRL:RRL_JOIN_RAID()
	RRL:Print("joining raid")
	-- register our events
	RRL:Print("registering event RRL_SEND_UPDATE")
    RRL:RegisterEvent("RRL_SEND_UPDATE")
    RRL:Print("registering event RRL_PROCESS_UPDATE")
    RRL:RegisterEvent("RRL_PROCESS_UPDATE")
	RRL:Print("registering event RRL_UPDATE_ROSTER")
    RRL:RegisterEvent("RRL_UPDATE_ROSTER")
	RRL:Print("registering event RRL_UPDATE_STATUS")
    RRL:RegisterEvent("RRL_UPDATE_STATUS")
	-- register to receive addon messages
    RRL:Print("registering to receive RRL1 prefix addon messages")
    RRL:RegisterComm("RRL1")
	-- start firing RRL_SEND_UPDATE every x seconds
    RRL:Print("starting event timer")
    send_timer = self:ScheduleRepeatingTimer('RRL_SEND_UPDATE', self.db.profile.updateinterval)
	-- update the roster
	self:ScheduleTimer("RRL_UPDATE_ROSTER", 0)
end

-- stop doing what we do in a raid
function RRL:RRL_LEAVE_RAID()
	RRL:Print("leaving raid")
	-- stop sending updates
	self:CancelTimer(send_timer, true)
	-- unregister receiving messages
	self:UnRegiseterComm("RRL1")
end

-- check our raid status and raid roster
function RRL:RRL_CHECK_RAID()
	RRL:Print("processing RRL_CHECK_RAID event")
	if GetNumRaidMembers() > 0 then
		if not inraid then
			inraid = true
			self:Scheduletimer('RRL_JOIN_RAID')
		end
		self:ScheduleTimer("RRL_UPDATE_ROSTER", 0)
	else
		if inraid then
			inraid = false
			self:ScheduleTimer('RRL_LEAVE_RAID')
		end
	end
end

-- process a received addon message
function RRL:OnCommReceived(prefix, message, distribution, sender)
    -- process the incoming message
    local update = {}
	update.sender = sender
	update.message = message
    self:ScheduleTimer('RRL_PROCESS_UPDATE', 0, update)
end

-- process a RRL_SEND_UPDATE event
function RRL:RRL_SEND_UPDATE()
    RRL:Print("processing RRL_SEND_UPDATE event")
	local message = "1"
	if not readystate then
		message = "0"
	end
	RRL:Print("sending message '"..message.."'")
    RRL:SendCommMessage("RRL1", message, "RAID")
end

-- process a RRL_PROCESS_UPDATE event
function RRL:RRL_PROCESS_UPDATE(update)
    RRL:Print("processing RRL_PROCESS_UPDATE event")
	RRL:Print("received msg = '"..update.message.."' from '"..update.sender.."'");
	local senderstate = true
	if "0" == update.message then
		senderstate = false
	end
	if roster[update.member] then
		local oldstate = roster[update.sender]
		roster[update.sender] = senderstate
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
	RRL:Print("processing RRL_UPDATE_ROSTER event")
	local newroster = {}
	for i = 1, 40, 1
	do
		local name, rank, subgroup, level, class, fileName, 
			zone, online, isDead, role, isML = GetRaidRosterInfo(i)
		if name then
			RRL:Print("name",name,"online",online)
			if online and roster[name] and true == roster[name] then
				newroster[name] = true
			else
				newroster[name] = false
			end
		end
	end
	roster = newroster
end

-- process an UPDATE_STATUS event
function RRL:RRL_UPDATE_STATUS()
	RRL:Print("updating status")
	local numnotready = 0
	lightstatus = true
	for k,v in pairs(roster) do
		if not v then
			numnotready = numnotready + 1
			if self.db.profile.critical.k then
				RRL:Print("critical member "..k.." not ready, lightstatus now false")
				lightstatus = false
			end
		end
	end
	if numnotready > self.db.profile.maxnotready then
		RRL:Print("notready ("..numnotready..") exceeds maxnotready ("..self.db.profile.maxnotready.."), lightstatus now false")
		lightstatus = false
	end
	RRL:Print("lightstatus is",lightstatus)
end

-- dump the roster
function RRL:DumpRoster()
	for k,v in pairs(roster) do
		RRL:Print(k,v)
	end
end

-- get the max number of not ready members
function RRL:GetMax()
    RRL:Print("GetMax called")
    return self.db.profile.maxnotready
end

-- set the max number of not ready members
function RRL:SetMax(info, max)
    RRL:Print("SetMax called")
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
    RRL:Print("GetInterval called")
    return self.db.profile.updateinterval
end

-- set the update interval
function RRL:SetInterval(info, interval)
    RRL:Print("SetInterval called")
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
    RRL:Print("ListCritical called")
    --- XXX list members
end

-- clears critical members
function RRL:ClearCritical()
    RRL:Print("ClearCritical called")
    --- XXX clear members
	self:CancelTimer(process_timer, true)
	process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
end

-- adds a critical member
function RRL:AddCritical(member)
    RRL:Print("AddCritical called")
    --- XXX add member
	self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
	self:CancelTimer(process_timer, true)
	process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
end

-- deletes a critical member
function RRL:DelCritical(member)
    RRL:Print("DelCritical called")
    --- XXX delete member
	self:CancelTimer(process_timer, true)
	process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
end

-- get ready state
function RRL:GetReady()
	RRL:Print("GetReady called")
	return readystate
end

-- toggle ready state
function RRL:ToggleReady()
    RRL:Print("ToggleReady called");
    readystate = not readystate
	RRL:Print("ready state is now", readystate)
	self:ScheduleTimer('RRL_SEND_UPDATE', 0)
end

--
-- EOF
