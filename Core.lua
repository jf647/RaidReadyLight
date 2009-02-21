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
RRL.debug = true
RRL.count = {
	ready = 0,
	notready = 0,
	notready_crit = 0,
	total = 40,
	unknown = 0,
	norrl = 0,
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
		elseif "RightButton" == which then
			DoReadyCheck()
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
		debug = {
			type = 'toggle',
			name = 'toggle debug',
			desc = 'toggle debug on/off',
			get  = function(info) return RRL.debug end,
			set  = function(info) RRL.debug = not RRL.debug end,
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
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "RRL_CHECK_RAID")
	self:RegisterEvent("RAID_ROSTER_UPDATE", "RRL_CHECK_RAID")
	-- are we in a raid?
	self:RRL_CHECK_RAID()
end

-- disable
function RRL:OnDisable()
	self:UnegisterAllEvents()
	self:UnhookAll()
end

-- start doing what we need to do in a raid
function RRL:JoinRaid()
	self.active = true
	-- register our events
	self:RegisterEvent("RRL_SEND_UPDATE")
    self:RegisterEvent("RRL_UPDATE_STATUS")
	self:RegisterEvent("RRL_SEND_PING")
	self:RegisterEvent("RRL_MARK_NORRL")
	-- register to receive addon messages
    self:RegisterComm("RRL1")
	-- send an update, then start firing them on a timer
	self:RRL_SEND_UPDATE()
    send_timer = self:ScheduleRepeatingTimer('RRL_SEND_UPDATE', self.db.profile.updateinterval)
	-- hook ready checks if requested to
	if self.db.profile.readycheck_respond then
		if not self:IsHooked("ShowReadyCheck") then
			self:RawHook("ShowReadyCheck", true)
		end
		self:RegisterEvent("READY_CHECK")
	else
		if self:IsHooked("ShowReadyCheck") then
			self:Unhook("ShowReadyCheck")
		end
		self:UnregisterEvent("READY_CHECK")
	end
end

-- stop doing what we do in a raid
function RRL:LeaveRaid()
	self.active = false
	ldb_obj.text = "Not Active"
	-- unhook ready checks
	if self:IsHooked("ShowReadyCheck") then
		self:Unhook("ShowReadyCheck")
	end
	self:UnregisterEvent("READY_CHECK")
	-- stop sending updates
	self:CancelTimer(send_timer, true)
	-- unregister receiving messages
	self:UnregisterComm("RRL1")
	-- unregister events
	self:UnregisterEvent("RRL_MARK_NORRL")
	self:UnregisterEvent("RRL_SEND_PING")
	self:UnregisterEvent("RRL_UPDATE_STATUS")
	self:UnregisterEvent("RRL_SEND_UPDATE")
end

-- check our raid status and raid roster
function RRL:RRL_CHECK_RAID()
	if GetNumRaidMembers() > 0 then
		if not self.inraid then
			self.inraid = true
			self:JoinRaid()
		end
		self:UpdateRoster()
	else
		if self.inraid then
			self.inraid = false
			self:LeaveRaid()
		end
	end
end

-- process a received addon message
function RRL:OnCommReceived(prefix, message, distribution, sender)
    -- split the message into msgtype, data
	local _, _, msgtype, data = string.find(message, "(%a+)%s(%d)")
	if self.debug then
		self:Print("received",msgtype,"from",sender,"with value",data)
	end
	-- switch based on msgtype
	if 'READY' == msgtype or 'PONG' == msgtype then
		local senderready = true
		if '0' == data then
			senderready = false
		end
		local oldready = self.members[sender].ready
		self.members[sender] = {
			state = RRL_STATE_OK,
			ready = senderready,
			last = time(),
		}
		if oldready ~= senderready then
			self:CancelTimer(process_timer, true)
			process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
		end
	elseif 'PING' == msgtype then
		local message = "PONG 1"
		if false == self.selfready then
			message = "PONG 0"
		end
		self:SendCommMessage("RRL1", message, "WHISPER", sender)
		if self.debug then
			self:Print("responded to ping from",sender)
		end
	else
		self:Print("ERROR: received unknown addon message type '"..msgtype.."' from", sender)
	end
end

-- process a RRL_SEND_UPDATE event
function RRL:RRL_SEND_UPDATE(msgtype)
	local message = "READY 1"
	if false == self.selfready then
		message = "READY 0"
	end
    self:SendCommMessage("RRL1", message, "RAID")
	if self.debug then
		self:Print("sent update message",message)
	end
end

-- update the roster
function RRL:UpdateRoster()
	if self.debug then
		self:Print("updating roster")
	end
	local newmembers = {}
	for i = 1, 40, 1
	do
		local name, rank, subgroup, level, class, fileName,
			zone, online, isDead, role, isML = GetRaidRosterInfo(i)
		if name then
			if nil ~= self.members[name] then
				if self.debug then
					self:Print("found",name,"in the member list")
				end
				newmembers[name] = self.members[name]
			else
				if self.debug then
					self:Print("did not find",name,"in the member list")
				end
				newmembers[name] = {
					state = RRL_STATE_UNKNOWN,
					last = time(),
				}
				self:ScheduleTimer('RRL_SEND_PING', 3 * self.db.profile.updateinterval, name)
				if self.debug then
					self:Print("scheduling ping for",name,"in",3 * self.db.profile.updateinterval,"seconds")
				end
			end
		end
	end
	self.members = newmembers
	self:RRL_UPDATE_STATUS()
end

-- dump the member list
function RRL:Dump(msg)
	self:Print("dumping:",msg)
	for k,v in pairs(self.members)
	do
		self:Print("member",k)
		self:Print("   state",v.state)
		self:Print("   last",v.last)
		self:Print("   ready",v.ready)
	end
end

-- process an UPDATE_STATUS event
function RRL:RRL_UPDATE_STATUS()
	self.count = {
		ready = 0,
		notready = 0,
		notready_crit = 0,
		total = 0,
		unknown = 0,
		norrl = 0,
	}
	-- iterate over members to build counts
	for k,v in pairs(self.members)
	do
	    self.count.total = self.count.total + 1
		if RRL_STATE_OK == v.state then
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
		elseif RRL_STATE_NORRL == v.state then
			self.count.norrl = self.count.norrl + 1
		else
			self.count.unknown = self.count.unknown + 1
		end
	end
	
	-- determine if the raid is ready
	self.raidready = true
	if self.count.notready_crit > 0 then
		self.raidready = false
		if self.debug then
			self:Print("raid not ready because 1 or more critical members are not ready")
		end
	else
		local difficulty = GetInstanceDifficulty()
		local type = 'normal'
		if 2 == difficulty then
			type = 'heroic'
		end
		if self.count.notready > self.db.profile.maxnotready[type] then
			self.raidready = false
			if self.debug then
				self:Print("raid not ready because more than",self.db.profile.maxnotready[type],"members are not ready")
			end
		else
			if self.debug then
				self:Print("raid is ready")
			end
		end
	end
	
	-- build the LDB text
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
	countstring = (self.count.ready+self.count.unknown+self.count.norrl).."/"..self.count.total.." ("..self.count.unknown+self.count.norrl..")"
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
		local difficulty = GetInstanceDifficulty()
		local type = 'normal'
		if 2 == difficulty then
			type = 'heroic'
		end
		tip:AddDoubleLine(c:White("Not Ready:"), c:Red(RRL.count.notready) .. "/".. c:Green(RRL.db.profile.maxnotready[type]))
		tip:AddDoubleLine(c:White("Critical: "), c:Red(RRL.count.notready_crit))
		tip:AddDoubleLine(c:White("Unknown: "), c:Yellow(RRL.count.unknown))
		tip:AddDoubleLine(c:White("No Addon: "), c:Yellow(RRL.count.norrl))
		if RRL.count.notready > 0 then
			tip:AddLine(" ")
			tip:AddLine(c:White("Not Ready:"))
			for k,v in pairs(RRL.members)
			do
				if RRL_STATE_OK == v.state then
					if false == v.ready then
						if true == v.critical then
							tip:AddLine(c:Red(k))
						else
							tip:AddLine(c:Yellow(k))
						end
					end
				end
			end
		end
		if RRL.count.unknown > 0 then
			tip:AddLine(" ")
			tip:AddLine(c:White("Unknown:"))
			for k,v in pairs(RRL.members)
			do
				if RRL_STATE_UNKNOWN == v.state or RRL_STATE_PINGED == v.state then
					tip:AddLine(c:Yellow(k))
				end
			end
		end
		if RRL.count.norrl > 0 then
			tip:AddLine(" ")
			tip:AddLine(c:White("No Addon:"))
			for k,v in pairs(RRL.members)
			do
				if RRL_STATE_NORRL == v.state then
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
		self:Print("max not ready members for", type, "is", min .. '-' .. max)
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
		self:Print("interval range: 1-600")
	else
		self.db.profile.updateinterval = interval
		self:CancelTimer(send_timer, true)
		send_timer = self:ScheduleRepeatingTimer('RRL_SEND_UPDATE', interval)
	end
end

-- lists critical members
function RRL:ListCritical()
	self:Print("Members who must be ready:")
    for k,v in pairs(self.db.profile.critical)
	do
		self:Print(k)
	end
end

-- clears critical members
function RRL:ClearCritical()
	self:Print("critical members list has been cleared")
	self.db.profile.critical = {}
	self:CancelTimer(process_timer, true)
	process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
end

-- adds a critical member
function RRL:AddCritical(info, member)
	if "" ~= member then
		if self.db.profile.critical[member] then
			self:Print("'"..member.."' was already on the critical list")
		else
			self.db.profile.critical[member] = 1
			self:Print("added '"..member.."' to the critical list")
		end
	else
		member = UnitName('target')
		if nil ~= member then
			if self.db.profile.critical[member] then
				self:Print("'"..member.."' was already on the critical list")
			else
				self.db.profile.critical[member] = 1
				self:Print("added '"..member.."' to the critical list")
			end
		else
			self:Print("usage: /rrl critical add name (uses target if no name)")
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
			self:Print("removed '"..member.."' from the critical list")
		else
			self:Print("'"..member.."' is not on the critical list")
		end
	else
		member = UnitName('target')
		if nil ~= member then
			if self.db.profile.critical[member] then
				self.db.profile.critical[member] = nil
				self:Print("removed '"..member.."' from the critical list")
			else
				self:Print("'"..member.."' is not on the critical list")
			end
		else
			self:Print("usage: /rrl critical del name (uses target if no name)")
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
    self.selfready = not self.selfready
	if toconsole then
		if self.selfready then
			self:Print("setting your state to", c:Green("READY"))
		else
			self:Print("setting your state to", c:Red("NOT READY"))
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
		self:Print("will auto-respond to ready checks")
		if inraid then
			if not self:IsHooked("ShowReadyCheck") then
				self:RawHook("ShowReadyCheck", true)
			end
			RRL:RegisterEvent("READY_CHECK")
		end
	else
		self:Print("will not auto-respond to ready checks")
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
		self:Print("responded", c:Green('READY'), "to a ready check for you")
	else
		self:Print("responded", c:Red('NOT READY'), "to a ready check for you")
		ConfirmReadyCheck(false)
	end
end

-- play the ready check sound but do not show the dialog
function RRL:ShowReadyCheck()
	PlaySound("ReadyCheck")
end

-- send a ping message to a member if they are in unknown state
function RRL:RRL_SEND_PING(member)
	if RRL_STATE_UNKNOWN == self.members[member].state then
		self:SendCommMessage("RRL1", "PING 0", "WHISPER", member)
		self:ScheduleTimer('RRL_MARK_NORRL', 2 * self.db.profile.updateinterval, member)
		self.members[member].state = RRL_STATE_PINGED
		self.members[member].last = time()
		if self.debug then
			self:Print("sent ping to",member)
		end
	else
		if self.debug then
			self:Print("member",member,"was not unknown when send ping fired")
		end
	end
end

function RRL:RRL_MARK_NORRL(member)
	if RRL_STATE_PINGED == self.members[member].state then
		self.members[member].state = RRL_STATE_NORRL
		self.members[member].last = time()
		if self.debug then
			self:Print("marked",member," as not having the addon")
		end
		self:RRL_UPDATE_STATUS()
	else
		if self.debug then
			self:Print("member",member,"was not pinged when mark norrl fired")
		end
	end
end

--
-- EOF
