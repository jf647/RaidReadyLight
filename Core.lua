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
local RRL_STATE_NEW = 1
local RRL_STATE_PINGED = 2
local RRL_STATE_NORRL = 3
local RRL_STATE_OFFLINE = 4

-- external libs
local c = LibStub("LibCrayon-3.0")

-- locale setup
--local L = LibStub("AceLocale-3.0"):GetLocale("RRL", true)

-- local variables
local send_timer
local process_timer
local updateroster_timer
local updateroster_recur_timer
local db

-- state variables
RRL.inraid  = false
RRL.raidready = false
RRL.selfready = false
RRL.debug = false
RRL.lastrosterupdate = 0
RRL.rosterupdatemin = 5
RRL.count = {
	rrl_ready = 0,
	rrl_notready = 0,
	rrl_notready_crit = 0,
	afk_notready = 0,
	offline = 0,
	new = 0,
	pinged = 0,
	norrl = 0,
	total = 0,
	meta_ready = 0,
	meta_notready = 0,
	meta_unknown = 0,
	max_notready = 0,
}
RRL.members = {}
RRL.optionsFrames = {}

-- init
function RRL:OnInitialize()
    -- load saved variables
    self.database = LibStub("AceDB-3.0"):New("RRLDB", self.defaults, 'Default')
	-- register to be told when our profile changes
	self.database.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.database.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.database.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	-- get a local reference to our profile
	db = self.database.profile
	self.db = db
	-- add AceDB profile handler (broken, gives error in library when standalone)
	--self.options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	--self.options.args.profile.order = 200
	-- register options
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Raid Ready Light", self.options)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("Raid Ready Light", self.options, "rrl")
	self.optionsFrames.rrl = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Raid Ready Light")
end

-- our profile has changed, get a new local reference
function RRL:OnProfileChanged(event, database, newProfileKey)
	db = database.profile
	self.db = db
end

-- enable
function RRL:OnEnable()
    -- register our events
	self:RegisterEvent("RAID_ROSTER_UPDATE", "RRL_CHECK_RAID")
	-- check if we're in a raid
	self:RRL_CHECK_RAID()
end

-- disable
function RRL:OnDisable()
	self:UnegisterAllEvents()
	self:UnhookAll()
end

-- start doing what we need to do in a raid
function RRL:JoinRaid()
	if self.debug then
		self:Print("joining a raid")
	end
	-- register our events
	self:RegisterEvent("RRL_SEND_UPDATE")
	self:RegisterEvent("RRL_UPDATE_ROSTER", "UpdateRoster")
    self:RegisterEvent("RRL_UPDATE_STATUS")
	self:RegisterEvent("RRL_SEND_PING")
	self:RegisterEvent("RRL_MARK_NORRL")
	-- register WoW events
	self:RegisterEvent("PLAYER_DEAD")
	self:RegisterEvent("PLAYER_FLAGS_CHANGED")
	-- register to receive addon messages
    self:RegisterComm("RRL1")
	-- send an update, then start firing them on a timer
	self:RRL_SEND_UPDATE()
    send_timer = self:ScheduleRepeatingTimer('RRL_SEND_UPDATE', db.updateinterval)
	-- check our roster, then start firing at 3 times the update interval
	self:UpdateRoster(false)
	updateroster_recur_timer = self:ScheduleRepeatingTimer('UpdateRoster', (3*db.updateinterval), true)
	-- hook ready checks if requested to
	if db.readycheck_respond then
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
	if self.debug then
		self:Print("leaving a raid")
	end
	self.ldb_obj.text = "Not Active"
	-- unhook ready checks
	if self:IsHooked("ShowReadyCheck") then
		self:Unhook("ShowReadyCheck")
	end
	self:UnregisterEvent("READY_CHECK")
	-- stop sending updates
	self:CancelTimer(send_timer, true)
	-- stop checking the roster
	self:CancelTimer(updateroster_recur_timer, true)
	-- unregister receiving messages
	self:UnregisterComm("RRL1")
	-- unregister WoW events
	self:UnregisterEvent("PLAYER_FLAGS_CHANGED")
	self:UnregisterEvent("PLAYER_DEAD")
	-- unregister events
	self:UnregisterEvent("RRL_MARK_NORRL")
	self:UnregisterEvent("RRL_SEND_PING")
	self:UnregisterEvent("RRL_UPDATE_STATUS")
	self:UnregisterEvent("RRL_UPDATE_ROSTER")
	self:UnregisterEvent("RRL_SEND_UPDATE")
end

-- check our raid status and raid roster
function RRL:RRL_CHECK_RAID()
	if GetNumRaidMembers() > 0 then
		if not self.inraid then
			self.inraid = true
			self:JoinRaid()
		end
		self:UpdateRoster(false)
	else
		if self.inraid then
			self.inraid = false
			self:LeaveRaid()
		end
	end
end

-- check if we've died
function RRL:PLAYER_DEAD()
	if( UnitIsDeadOrGhost("player") ) then
		if self.selfready then
			self:ToggleReady(false)
			if self.debug then
				self:Print("you died; marking you as", c:Red("NOT READY"))
			end
		end
	end
end

-- check if someone has gone AFK on us
function RRL:PLAYER_FLAGS_CHANGED(event, member)
	if UnitIsUnit(member, "player") then
		if true == self.selfready and UnitIsAFK("player") then
			self:Print("AFK: setting you", c:Red("NOT READY"))
			self.selfready = false
			self:CancelTimer(process_timer, true)
			process_timer = self:ScheduleTimer('RRL_UPDATE_STATUS', 1)
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
		local oldcritical = self.members[sender].critical
		self.members[sender] = {
			state = RRL_STATE_OK,
			ready = senderready,
			last = time(),
			critical = oldcritical,
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
	-- construct the message and send it
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
function RRL:UpdateRoster(periodic)
	-- prevent roster update spam
	if not periodic then
		if time() < self.lastrosterupdate + self.rosterupdatemin then
			if self:TimeLeft(updateroster_timer) then
				if self.debug then
					self:Print('raidcheck timer pending; doing nothing')
				end
			else
				updateroster_timer = self:ScheduleTimer('UpdateRoster', self.rosterupdatemin, false)
				if self.debug then
					self:Print("prevented roster update spam; rescheduling")
				end
			end
			return
		end
	end
	self.lastrosterupdate = time()
	if self.debug then
		self:Print("updating roster")
	end
	local newmembers = {}
	for i = 1, 40, 1
	do
		local name, rank, subgroup, level, class, fileName,
			zone, online, isDead, role, isML = GetRaidRosterInfo(i)
		if name then
			if not online then
				newmembers[name] = {
					state = RRL_STATE_OFFLINE,
					ready = false,
					last = time(),
				}
			else
				if nil ~= self.members[name] then
					if self.debug then
						self:Print("found",name,"in the member list")
					end
					newmembers[name] = self.members[name]
					-- if they don't have the addon, do an AFK check
					if RRL_STATE_NORRL == newmembers[name].state then
						if UnitIsAFK(name) then
							newmembers[name].ready = false
						else
							newmembers[name].ready = true
						end
					end
				else
					if self.debug then
						self:Print("did not find",name,"in the member list")
					end
					newmembers[name] = {
						state = RRL_STATE_NEW,
						ready = true,
						last = time(),
					}
					self:ScheduleTimer('RRL_SEND_PING', 3 * db.updateinterval, name)
					if self.debug then
						self:Print("scheduling ping for",name,"in",3 * db.updateinterval,"seconds")
					end
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
		rrl_ready = 0,
		rrl_notready = 0,
		rrl_notready_crit = 0,
		afk_notready = 0,
		offline = 0,
		new = 0,
		pinged = 0,
		norrl = 0,
		total = 0,
		meta_ready = 0,
		meta_notready = 0,
		meta_unknown = 0,
		max_notready = 0,
	}
	
	-- calc heartbeat cutoff
	cutoff = time () - 3 * db.updateinterval
	
	-- iterate over members to build counts
	for k,v in pairs(self.members)
	do
	    self.count.total = self.count.total + 1
		if RRL_STATE_OK == v.state then
			-- check for recent heartbeat
			if v.last < cutoff then
				self:RRL_SEND_PING(k)
				self.count.pinged = self.count.pinged + 1
				if self.debug then
					self:Print("old heartbeat for",k,"- pinging")
				end
			else
				if true == v.ready then
					self.count.rrl_ready = self.count.rrl_ready + 1
				else
					self.count.rrl_notready = self.count.rrl_notready + 1
					self.members[k].critical = false
					if db.critical[k] then
						self.count.rrl_notready_crit = self.count.rrl_notready_crit + 1
						self.members[k].critical = true
					end
				end
			end
		elseif RRL_STATE_NEW == v.state then
			self.count.new = self.count.new + 1
		elseif RRL_STATE_PINGED == v.state then
			self.count.pinged = self.count.pinged + 1
		elseif RRL_STATE_OFFLINE == v.state then
			self.count.offline = self.count.offline + 1
		elseif RRL_STATE_NORRL == v.state then
			if false == v.ready then
				self.count.afk_notready = self.count.afk_notready + 1
			else
				self.count.norrl = self.count.norrl + 1
			end
		end
	end
	
	-- calc meta counts
	self.count.meta_ready = self.count.rrl_ready + self.count.new + self.count.pinged + self.count.norrl
	self.count.meta_notready = self.count.rrl_notready + self.count.afk_notready + self.count.offline
	self.count.meta_unknown = self.count.new + self.count.pinged
	local instancetype = GetCurrentDungeonDifficulty()
	self.count.max_notready = db.maxnotready[instancetype]

	-- determine if the raid is ready
	self.raidready = true
	if self.count.rrl_notready_crit > 0 then
		self.raidready = false
		if self.debug then
			self:Print("raid not ready because 1 or more critical members are not ready")
		end
	else
		if self.count.meta_notready > self.count.max_notready then
			self.raidready = false
			if self.debug then
				self:Print("raid not ready because more than",self.count.max_notready,"members are not ready")
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
		self.ldb_obj.status = true
		self.ldb_obj.icon = "Interface\\RAIDFRAME\\ReadyCheck-Ready.png"
		raidstring = c:Green("RAID")
	else
		self.ldb_obj.status = false
		self.ldb_obj.icon = "Interface\\RAIDFRAME\\ReadyCheck-NotReady.png"
		raidstring = c:Red("RAID")
	end
	countstring = self.count.meta_ready.."/"..self.count.total
	if self.count.rrl_notready_crit > 0 then
		countstring = countstring .. "*"
	end
	self.ldb_obj.text = youstring .. "/" .. raidstring .. " " .. c:White(countstring)
end

-- toggle ready state
function RRL:ToggleReady(toconsole)
    self.selfready = not self.selfready
	if toconsole or self.debug then
		if self.selfready then
			self:Print("setting your state to", c:Green("READY"))
		else
			self:Print("setting your state to", c:Red("NOT READY"))
		end
	end
	self:RRL_SEND_UPDATE()
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

-- play the ready check sound
function RRL:ShowReadyCheck()
	PlaySound("ReadyCheck")
end

-- send a ping message to a member if they are in unknown state
function RRL:RRL_SEND_PING(member)
	-- skip out of they've sent a ready in 3 * updateinterval
	if RRL_STATE_OK == self.members[member].state and self.members[member].last > time() - (3*db.updateinterval) then
		if self.debug then
			self:Print(member,"was current when a ping was to be sent; skipped")
		end
		return
	end
	-- make sure they're online
	if nil == UnitIsConnected(member) then
		self.members[member] = {
			state = RRL_STATE_OFFLINE,
			ready = false,
			last = time(),
		}
		if self.debug then
			self:Print("marked",member,"offline")
		end
	else
		self:SendCommMessage("RRL1", "PING 0", "WHISPER", member)
		self:ScheduleTimer('RRL_MARK_NORRL', 2 * db.updateinterval, member)
		self.members[member] = {
			state = RRL_STATE_PINGED,
			last = time(),
			ready = true,
		}
		if self.debug then
			self:Print("sent ping to",member)
		end
	end
end

function RRL:RRL_MARK_NORRL(member)
	-- skip out of they've sent a ready in 3 * updateinterval
	if RRL_STATE_OK == self.members[member].state and self.members[member].last > time() - (3*db.updateinterval) then
		if self.debug then
			self:Print(member,"was current when marknorrl was to be set; skipped")
		end
		return
	end
	-- make sure they're online
	if nil == UnitIsConnected(member) then
		self.members[member] = {
			state = RRL_STATE_OFFLINE,
			last = time(),
			ready = false,
		}
		if self.debug then
			self:Print("marked",member,"offline")
		end
	else
		self.members[member] = {
			state = RRL_STATE_NORRL,
			last = time(),
			ready = true,
		}
		if self.debug then
			self:Print("marked",member," as not having the addon")
		end
		self:RRL_UPDATE_STATUS()
	end
end

--
-- EOF
