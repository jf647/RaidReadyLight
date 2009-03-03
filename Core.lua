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
	"AceHook-3.0",
    "LibDebugLog-1.0"
)

-- XXX development mode, force debug on
RRL:ToggleDebugLog(true)

-- constants
RRL.STATE_OK = 0
RRL.STATE_NEW = 1
RRL.STATE_PINGED = 2
RRL.STATE_NORRL = 3
RRL.STATE_OFFLINE = 4
RRL.STATE_AFK = 5

-- external libs
local c = LibStub("LibCrayon-3.0")

-- local vars
local myname

-- locale setup
--local L = LibStub("AceLocale-3.0"):GetLocale("RRL", true)

-- state variables
RRL.state = {
    inraid = 0,
    maxnotready = 0,
    ready = {
        raid = 0,
        self = 0,
    },
    count = {}
}

-- init
function RRL:OnInitialize()
    -- load saved variables
    self.database = LibStub("AceDB-3.0"):New("RRLDB", self.defaults, 'Default')
	-- register to be told when our profile changes
	self.database.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.database.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.database.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	-- get a local reference to our profile
	self.db = self.database.profile
	-- add AceDB profile handler (broken, gives error in library when standalone)
	--self.options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	--self.options.args.profile.order = 200
	-- register options
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Raid Ready Light", self.options)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("Raid Ready Light", self.options, "rrl")
    self.optionsFrames = {}
	self.optionsFrames.rrl = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Raid Ready Light")
end

-- our profile has changed, get a new local reference
function RRL:OnProfileChanged(event, database, newProfileKey)
	self.db = database.profile
end

-- enable
function RRL:OnEnable()
    -- register our events
	self:RegisterEvent("RAID_ROSTER_UPDATE", "CheckRaid")
	-- check if we're in a raid
	self:CheckRaid()
    -- cache our name
    myname = UnitName("player")
end

-- disable
function RRL:OnDisable()
	self:CancelAllTimers()
	self:UnhookAll()
end

-- check our raid status and raid roster
function RRL:CheckRaid()
	if GetNumRaidMembers() > 0 then
		local ininstance, instancetype = IsInInstance()
        if ininstance and 'pvp' == instancetype then
            if 1 == self.state.inraid then
                self.state.inraid = 0
                self:LeaveRaid()
            end
            return
		elseif 0 == self.state.inraid then
			self.state.inraid = 1
			self:JoinRaid()
        elseif 1 == self.state.inraid then
            self:CheckRoster()
		end
	else
		if 1 == self.state.inraid then
			self.state.inraid = 0
			self:LeaveRaid()
		end
	end
end

-- start doing what we need to do in a raid
function RRL:JoinRaid()
	self:Debug('joining a raid')
	-- register WoW events
	self:RegisterEvent("PLAYER_DEAD")
	self:RegisterEvent("PLAYER_FLAGS_CHANGED")
	-- build our initial roster
	self:BuildRoster()
	-- register to receive addon messages
    self:RegisterComm("RRL1")
    -- start firing our maint roster event every interval
    self.maint_timer = self:ScheduleRepeatingTimer('MaintRoster', self.db.updateinterval)
	-- send a status msg, then start firing them on a timer
	self:SendStatus()
    self.send_timer = self:ScheduleRepeatingTimer('SendStatus', self.db.updateinterval)
	-- hook ready checks if requested to
	if self.db.readycheck_respond then
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
    -- create our traffic light frame if enabled
    if self.db.minion then
        self:CreateMinion()
    end
end

-- stop doing what we do in a raid
function RRL:LeaveRaid()
	self:Debug('leaving a raid')
	-- unhook ready checks
	if self:IsHooked("ShowReadyCheck") then
		self:Unhook("ShowReadyCheck")
	end
	self:UnregisterEvent("READY_CHECK")
	-- cancel pending timers
	self:CancelAllTimers()
	-- unregister receiving messages
	self:UnregisterComm("RRL1")
	-- unregister WoW events
	self:UnregisterEvent("PLAYER_FLAGS_CHANGED")
	self:UnregisterEvent("PLAYER_DEAD")
	-- reset LDB object to out of raid status
    self:UpdateLDBText()
    if self.minion then self:UpdateMinion() end
    -- destroy our minion if it exists
    if RRL.minion then
        self:DestroyMinion()
    end
end

-- process a received addon message
function RRL:OnCommReceived(prefix, message, distribution, sender)

    -- split the message into msgtype, data
	local _, _, msgtype, data = string.find(message, "(%a+)%s(%d)")
	self:Debug('received',msgtype,"from",sender,"with value",data)

	-- switch based on msgtype
	if 'STATUS' == msgtype then
		local senderready = true
		if '0' == data then
			senderready = false
		end
        
        local count_changed = false
        
        -- is this someone we've never seen before?
        if nil == self.roster[sender] then
            self:StateChange(nil, self.STATE_NEW, senderready, sender)
            count_changed = true
        else
            -- existing member, check for state change
            if self.roster[sender].state ~= self.STATE_OK or
               self.roster[sender].ready ~= senderready
            then
                self:Debug("state or ready changed for",sender,"- calling StateChange")
                self:StateChange(self.roster[sender], self.STATE_OK, senderready)
                count_changed = true
            else
                self.roster[sender].last = time()
            end
        end      
        
        -- if anything changed, determine if the raid is ready
        if count_changed then
            self:CalcRaidReady()
        end
	elseif 'PING' == msgtype then
		self:SendStatus()
        self:Debug("responded to ping from",sender)
	else
		self:Print("ERROR: received unknown addon message type '"..msgtype.."' from", sender)
	end

end

-- send out our status to the raid
function RRL:SendStatus()
	-- construct the message and send it
	local message = 'STATUS ' .. tostring(self.state.ready.self)
	self:SendCommMessage("RRL1", message, "RAID")
    self:Debug("sent update message",message)
end

-- build our internal roster
function RRL:BuildRoster()
    self:Debug("building roster")
    self.roster = {}
    self.state.count = {
        rrl = {
            ready = 0,
            notready = 0,
            crit_notready = 0,
        },
        other = {
            offline = 0,
            new = 0,
            pinged = 0,
            noaddon = 0,
            afk = 0,
        },
        total = {
            all = 0,
            ready = 0,
            notready = 0,
        },
    }
	for i = 1, 40, 1
	do
		local name, rank, subgroup, level, class, fileName,
			zone, online, isDead, role, isML = GetRaidRosterInfo(i)
		if name then
            if online then
                self:StateChange(nil, self.STATE_NEW, nil, name)
            else
                self:StateChange(nil, self.STATE_OFFLINE, nil, name)
            end
		end
	end
    self:CalcRaidReady()
end

-- maintain our internal roster
function RRL:MaintRoster()

    self:Debug("maintaining roster")

    -- if our total doesn't match the GetNumRaidMembers, something has
    -- gone wrong.  force a roster re-scan
    if GetNumRaidMembers() ~= self.state.count.total.all then
        self:Print(c:Red('ERROR:'), 'raid size count mismatch, re-scanning roster')
        self:BuildRoster()
        return
    end

    -- calculate our cutoff times
    local now = time()
    local five_ago = now - 5 * self.db.updateinterval
	local three_ago = now - 3 * self.db.updateinterval
	local two_ago = now - 2 * self.db.updateinterval
    
    local isoffline
    local count_changed = false

    for k,v in pairs(self.roster)
    do
        isoffline = not UnitIsConnected(k)
        
        if self.STATE_OK == v.state then
            -- ping ok with a heartbeat before three_ago
            if v.last < three_ago then
                self:Debug(k,"heartbeat more than three intervals ago")
                if isoffline then
                    self:StateChange(v, self.STATE_OFFLINE)
                else
                    self:StateChange(v, self.STATE_PINGED)
                    self:SendCommMessage('RRL1', 'PING 0', 'WHISPER', k)
                    self:Debug("pinged",k)
                end
                count_changed = true
            end
        elseif self.STATE_NEW == v.state then
            -- ping new with a heartbeat before three_ago
            if v.last < three_ago then
                self:Debug(k,"heartbeat more than three intervals ago")
                if isoffline then
                    self:StateChange(v, self.STATE_OFFLINE)
                else
                    self:StateChange(v, self.STATE_PINGED)
                    self:SendCommMessage('RRL1', 'PING 0', 'WHISPER', k)
                    self:Debug("pinged",k)
                end
                count_changed = true
            else
                if UnitIsAFK(k) then
                    self:StateChange(v, self.STATE_AFK)
                    count_changed = true
                end
            end
        elseif RRL.STATE_PINGED == v.state then
            -- mark as STATE_NORRL pinged with a heartbeat before two_ago
            if v.last < two_ago then
                self:Debug(k,"heartbeat more than two intervals ago")
                if isoffline then
                    self:StateChange(v, self.STATE_OFFLINE)
                else
                    self:StateChange(v, self.STATE_NORRL)
                end
                count_changed = true
            else
                if UnitIsAFK(k) then
                    self:StateChange(v, self.STATE_AFK)
                    count_changed = true
                end
            end
        elseif RRL.STATE_NORRL == v.state then
            -- check if NORRL is afk
            if offline then
                self:StateChange(v, self.STATE_OFFLINE)
                count_changed = true
            else
                if v.last < five_ago then
                    self:Debug(k,"heartbeat more than five intervals ago")
                    if not UnitInRaid(k) then
                        self:StateChange(v, nil)
                        count_changed = true
                    end
                end
                if UnitIsAFK(k) then
                    self:StateChange(v, self.STATE_AFK)
                    count_changed = true
                end
            end
        elseif RRL.STATE_OFFLINE == v.state then
            -- check if OFFLINE is still offline
            if not isoffline then
                self:StateChange(v, self.STATE_NEW)
                count_changed = true
            end
        elseif RRL.STATE_AFK == v.state then
            -- check if afk is still afk
            if isoffline then
                self:StateChange(v, self.STATE_OFFLINE)
                count_changed = true
            else
                if not UnitIsAFK(k) then
                    self:StateChange(v, self.STATE_NORRL)
                    count_changed = true
                end
            end
        else
            self:Print(c:Red('ERROR: ') ..'unexpected state',v.state,'for',k)
        end
    end
    
    -- if anything changed, determine if the raid is ready
    if count_changed then
        self:CalcRaidReady()
    end
    
    self:Debug("finished maintaining roster")
    
end

-- check our roster, make sure that we don't still have someone who has left
-- the raid
function RRL:CheckRoster()

    -- has someone left?
    for k,v in pairs(self.roster)
    do
        if not UnitInRaid(k) then
            self:StateChange(v, nil)
        end
    end
    
    -- has someone joined?
	for i = 1, 40, 1
	do
		local name, rank, subgroup, level, class, fileName,
			zone, online, isDead, role, isML = GetRaidRosterInfo(i)
		if name then
            if online then
                self:StateChange(nil, self.STATE_NEW, nil, name)
            else
                self:StateChange(nil, self.STATE_OFFLINE, nil, name)
            end
		end
	end

end

-- dump the member list
function RRL:Dump()
	self:Debug("dumping state table at",time())
	for k,v in pairs(self.roster)
	do
		self:Debug("member",k)
		self:Debug("   state",v.state)
		self:Debug("   last",v.last)
		self:Debug("   ready",v.ready)
	end
    self:Debug("rrl")
    self:Debug("   ready", self.state.count.rrl.ready)
    self:Debug("   notready", self.state.count.rrl.notready)
    self:Debug("   crit_notready", self.state.count.rrl.crit_notready)
    self:Debug("other")
    self:Debug("   offline", self.state.count.other.offline)
    self:Debug("   new", self.state.count.other.new)
    self:Debug("   pinged", self.state.count.other.pinged)
    self:Debug("   noaddon", self.state.count.other.noaddon)
    self:Debug("   afk", self.state.count.other.afk)
    self:Debug("   all", self.state.count.total.all)
    self:Debug("total")
    self:Debug("   ready", self.state.count.total.ready)
    self:Debug("   notready", self.state.count.total.notready)
end

-- check if we've died
function RRL:PLAYER_DEAD()
	if( UnitIsDeadOrGhost("player") ) then
		if 1 == self.state.ready.self then
			self:ToggleReady()
			self:Print("you died; marking you as", c:Red("NOT READY"))
		end
	end
end

-- check if we've gone AFK
function RRL:PLAYER_FLAGS_CHANGED(event, member)
    self:Debug("player flags changed for", member)
	if UnitIsUnit(member, "player") then
		if 1 == self.state.ready.self and UnitIsAFK("player") then
			self:Print("AFK: setting you", c:Red("NOT READY"))
            self:ToggleReady()
		end
	end
end

-- toggle our ready state
function RRL:ToggleReady()
    self:Debug("toggling ready state")
    self.state.ready.self = abs(self.state.ready.self-1)
	self:UpdateLDBText()
    if self.minion then self:UpdateMinion() end
	self:SendStatus()
end

-- respond to a ready check for the user
function RRL:READY_CHECK()
	if 1 == self.state.ready.self then
		ConfirmReadyCheck(true)
		self:Print("responded", c:Green('READY'), "to a ready check for you")
	else
		ConfirmReadyCheck(false)
        self:Print("responded", c:Red('NOT READY'), "to a ready check for you")
	end
end

-- play the ready check sound
function RRL:ShowReadyCheck()
	PlaySound("ReadyCheck")
end

--
-- EOF