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

-- constants
local RRL_STATE_OK = 0
local RRL_STATE_UNKNOWN = 1
local RRL_STATE_PINGED = 2
local RRL_STATE_NORRL = 3

-- external libs
local c = LibStub("LibCrayon-3.0")

-- locale setup
local L = LibStub("AceLocale-3.0"):GetLocale("RRL", true)

-- local variables
local send_timer
local process_timer
local ldb_tip

-- state variables
RRL.active = false
RRL.inraid  = false
RRL.raidready = false
RRL.selfready = false
RRL.count = {
	ready = 0,
	notready = 0,
	notready_crit = 0,
	total = 40,
	unknown = 0,
}
RRL.members = {}

-- LDB setup
local ldb_obj = LibStub("LibDataBroker-1.1"):NewDataObject("RRL", {
	text = "Not Active",
	icon = "Interface\\RAIDFRAME\\ReadyCheck-Ready.png",
})
function ldb_obj.OnClick(_, which)
	if true == RRL.active then
		if "LeftButton" == which then
			RRL:ToggleReady(false)
		else if "RightButton" == which then
			DoReadyCheck()
		end
		end
	end
end

-- slash commands
RRL.options = {
    name = "rrl",
    handler = RRL,
    type = 'group',
    args = {
        max = {
			name = 'maxnotready',
			desc = 'set maximum not ready members',
			type = 'group',
			args = {
				normal = {
					type = 'range',
					name = 'get/set max not ready (normal)',
					desc = 'get or set the maximum number of not ready members (normal raids)',
					min  = 0,
					max  = 10,
					step = 1,
					set  = function(info, value) RRL:SetMax('normal', 0, 10, value) end,
					get  = function(info) RRL:GetMax('normal') end,
				},
				heroic = {
					type = 'range',
					name = 'get/set max not ready (heroic)',
					desc = 'get or set the maximum number of not ready members (heroic raids)',
					min  = 0,
					max  = 25,
					step = 1,
					set  = function(info, value) RRL:SetMax('heroic', 0, 25, value) end,
					get  = function(info) RRL:GetMax('heroic') end,
				},
			},
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
			set  = function(info) RRL:ToggleReady(true) end,
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
		maxnotready = {
			normal = 1,
			heroic = 3,
		},
		readycheck_respond = 1,
		critical = {},
	},
}

-- init
function RRL:OnInitialize()
    -- load saved variables
    self.db = LibStub("AceDB-3.0"):New("RRLDB", self.defaults, 'Default')
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
	-- are we in a raid?
	self:RRL_CHECK_RAID()
end

-- disable
function RRL:OnDisable()
	RRL:UnegisterAllEvents()
end

-- start doing what we need to do in a raid
function RRL:RRL_JOIN_RAID()
	self.active = true
	-- register our events
    RRL:RegisterEvent("RRL_SEND_UPDATE")
    RRL:RegisterEvent("RRL_PROCESS_UPDATE")
    RRL:RegisterEvent("RRL_UPDATE_ROSTER")
    RRL:RegisterEvent("RRL_UPDATE_STATUS")
	RRL:RegisterEvent("RRL_SEND_PING")
	RRL:RegisterEvent("RRL_MARK_NORRL")
	-- register to receive addon messages
    RRL:RegisterComm("RRL1")
	-- start firing RRL_SEND_UPDATE
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
	self.active = false
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
		if not self.inraid then
			self.inraid = true
			self:RRL_JOIN_RAID()
		end
		self:RRL_UPDATE_ROSTER()
	else
		if self.inraid then
			self.inraid = false
			self:RRL_LEAVE_RAID()
		end
	end
end

-- process a received addon message
function RRL:OnCommReceived(prefix, message, distribution, sender)
    -- split the message into msgtype, data
	local msgtype, data = ...
	-- switch based on msgtype
	if 'READY' == msgtype or 'PONG' == msgtype then
		local senderready = true
		if '0' == data then
			senderready = false
		end
		local oldready = self.members[sender].ready,
		self.members[sender] = {
			state = RRL_STATE_OK,
			ready = senderready,
			last = GetTime(),
		}
		if oldready ~= ready then
			self:CancelTimer(process_timer, true)
			process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
		end
	else if 'PING' == msgtype then
		local message = "PONG 1"
		if false == self.selfready then
			message = "PONG 0"
		end
		RRL:SendCommMessage("RRL1", message, "WHISPER", sender) -- XXX check params
	else
		RRL:Print("ERROR: received unknown addon message type '"..msgtype.."' from", sender)
	end
end

-- process a RRL_SEND_UPDATE event
function RRL:RRL_SEND_UPDATE(msgtype)
	local message = "READY 1"
	if false == self.selfready then
		message = "READY 0"
	end
    RRL:SendCommMessage("RRL1", message, "RAID")
end

-- process a RRL_UPDATE_ROSTER event
function RRL:RRL_UPDATE_ROSTER()
	local newmembers = {}
	for i = 1, 40, 1
	do
		local name, rank, subgroup, level, class, fileName,
			zone, online, isDead, role, isML = GetRaidRosterInfo(i)
		if name then
			if self.members[name] then
				newmembers[name] = self.members[name]
			else
				self.members[name] = {
					state = RRL_STATE_UNKNOWN,
					last = GetTime(),
				}
			end
		end
	end
	self.members = newmembers
	self:RRL_UPDATE_STATUS()
end

-- process an UPDATE_STATUS event
function RRL:RRL_UPDATE_STATUS()
	for k,v in pairs(self.members) do
	    self.count.total = self.count.total + 1
		if RRL_STATUS_OK = v.state then
			if true == v.ready then
				self.count.ready = self.count.ready + 1
			else
				self.count.notready = self.count.notready + 1
				self.members[k].critical = false
				if self.db.profile.critical[k] then
					self.count.notready_crit = self.count.notready_crit + 1
					self.members[k].critical = true
				end
			end
		else
			self.count.unknown = self.count.unknown + 1
		end
	end
	if self.count.notready_crit > 0 then
		self.raidready = false
	else
		local type = GetDungeonDifficulty() -- XXX
		if self.count.notready > self.db.profile.maxnotready[type] then
			self.raidready = false
		end
	end
	local youstring
	local raidstring
	local countstring
	if true == self.selfready then
		youstring = c:Green("YOU")
	else
		youstring = c:Red("YOU")
	end
	if true == self.raidready then
		ldb_obj.status = true
		ldb_obj.icon = "Interface\\RAIDFRAME\\ReadyCheck-Ready.png"
		raidstring = c:Green("RAID")
	else
		ldb_obj.status = false
		ldb_obj.icon = "Interface\\RAIDFRAME\\ReadyCheck-NotReady.png"
		raidstring = c:Red("RAID")
	end
	countstring = (self.count.numready+self.count.unknown).."/"..self.count.total.." ("..self.count.unknown..")"
	if self.count.notready_crit > 0 then
		countstring = countstring .. "*"
	end
	ldb_obj.text = youstring .. "/" .. raidstring .. " " .. c:White(countstring)
end

-- display the LDB tooltip
function ldb_obj.OnTooltipShow(tip)
	if not ldb_tip then
		ldb_tip = tip
	end
	tip:ClearLines()
	tip:AddLine(c:White("RRL: Raid Ready Light"))
	tip:AddLine(" ")
	if false == RRL.active then
		tip:AddLine(c:White("Only active when in a raid"))
	else
		if true == RRL.raidready then
			tip:AddDoubleLine(c:White("Raid:"), c:Green("READY"))
		else
			tip:AddDoubleLine(c:White("Raid:"), c:Red("NOT READY"))
		end
		if true == RRL.selfready then
			tip:AddDoubleLine(c:White("You:"), c:Green("READY"))
		else
			tip:AddDoubleLine(c:White("You:"), c:Red("NOT READY"))
		end
		tip:AddDoubleLine(c:White("Ready:"), c:Colorize(c:GetThresholdHexColor(RRL.count.ready,RRL.count.total), RRL.count.ready)
			.. "/"..c:Green(RRL.count.total))
		local type = GetDungeonDifficulty() -- XXX	
		tip:AddDoubleLine(c:White("Not Ready:"), c:Red(RRL.count.notready) .. "/".. c:Green(RRL.db.profile.maxnotready[type]))
		tip:AddDoubleLine(c:White("Critical: "), c:Red(RRL.count.notready_crit))
		tip:AddDoubleLine(c:White("Unknown: "), c:Yellow(RRL.count.unknown))
		if RRL.count.notready then
			tip:AddLine(" ")
			tip:AddLine(c:White("Not Ready:"))
			for k,v in pairs(RRL.members)
			do
				if RRL_STATE_OK == v.state and true = v.critical then
					tip:AddLine(c:Red(k))
				else
					tip:AddLine(c:Yellow(k))
				end
			end
		end
		if RRL.count.unknown then
			tip:AddLine(" ")
			tip:AddLine(c:White("Unknown:"))
			for k,v in pairs(RRL.members)
			do
				if RRL_STATE_UNKNOWN == v.state then
					tip:AddLine(c:Yellow(k))
				end
			end
		end
		tip:AddLine(" ")
		tip:AddLine(c:White("Left-click to change your status"))
		tip:AddLine(c:White("Right-click to do a ready check"))
	end
	tip:Show()
end

-- get the max number of not ready members
function RRL:GetMax(type)
    return self.db.profile.maxnotready[type]
end

-- set the max number of not ready members
function RRL:SetMax(type, min, max, value)
	if value < min or value > max then
		RRL:Print("max not ready members for", type, "is", min .. '-' .. max)
	else
		self.db.profile.maxnotready[type] = value
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
	return self.selfready
end

-- toggle ready state
function RRL:ToggleReady(toconsole)
    readystate = not readystate
	if toconsole then
		if readystate then
			RRL:Print("setting your state to", c:Green("READY"))
		else
			RRL:Print("setting your state to", c:Red("NOT READY"))
		end
	end
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
	if true == self.selfready then
		ConfirmReadyCheck(true)
		RRL:Print("responded", c:Green('READY'), "to a ready check for you")
	else
		RRL:Print("responded", c:Red('NOT READY'), "to a ready check for you")
		ConfirmReadyCheck(false)
	end
end

-- play the ready check sound but do not show the dialog
function RRL:ShowReadyCheck()
	PlaySound("ReadyCheck")
end

--
-- EOF
