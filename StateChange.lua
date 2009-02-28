--
-- $Id$
--

-- update the counts based upon a given state change
function RRL:StateChange(member, newstate, isready)
    self:DumpCounts()
    local wasready = member.ready
    if self.STATE_OK == member.state then
        if self.STATE_OK == newstate then
            if wasready and not isready then
                member.ready = false
                self.state.count.rrl.ready = self.state.count.total.ready - 1
                self.state.count.rrl.notready = self.state.count.total.notready + 1
                self.state.count.total.ready = self.state.count.total.ready - 1
                self.state.count.total.notready = self.state.count.total.notready + 1
                if self.db.critical[k] then
                    self.state.count.rrl.crit_notready = self.state.count.total.crit_notready + 1
                end
            elseif not wasready and isready then
                member.ready = true
                self.state.count.rrl.ready = self.state.count.total.ready + 1
                self.state.count.rrl.notready = self.state.count.total.notready - 1
                self.state.count.total.ready = self.state.count.total.ready + 1
                self.state.count.total.notready = self.state.count.total.notready - 1               
                if self.db.critical[k] then
                    self.state.count.rrl.crit_notready = self.state.count.total.crit_notready - 1
                end
            end
        elseif self.STATE_OFFLINE == newstate then
            member.ready = false
            self.state.count.other.offline = self.state.count.other.offline + 1
            if wasready then
                self.state.count.total.ready = self.state.count.total.ready - 1
                self.state.count.total.notready = self.state.count.total.notready + 1
                self.state.count.rrl.ready = self.state.count.rrl.ready - 1
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready - 1
            end
        elseif self.STATE_PINGED == newstate then
            member.ready = true
            self.state.count.other.pinged = self.state.count.other.pinged + 1
            if wasready then
                self.state.count.rrl.ready = self.state.count.rrl.ready - 1
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready - 1
                self.state.count.total.ready = self.state.count.total.ready + 1
                self.state.count.total.notready = self.state.count.total.notready - 1
            end
        elseif nil == newstate then
            self.roster[k] = nil
            self.state.count.total.all = self.state.count.total.all - 1
            if wasready then
                self.state.count.total.ready = self.state.count.total.ready - 1
                self.state.count.rrl.ready = self.state.count.rrl.ready - 1
            else
                self.state.count.total.notready = self.state.count.total.notready - 1
                self.state.count.rrl.notready = self.state.count.rrl.notready - 1
            end
        else
            self:Print('unhandled state change from',member.state,'to',newstate)
        end
    elseif self.STATE_NEW == member.state then 
        if self.STATE_OFFLINE == newstate then
            member.ready = false
            self.state.count.other.new = self.state.count.other.new - 1
            self.state.count.other.offline = self.state.count.other.offline + 1
            self.state.count.total.ready = self.state.count.total.ready - 1
            self.state.count.total.notready = self.state.count.total.notready + 1
        elseif self.STATE_PINGED == newstate then
            member.ready = true
            self.state.count.other.new = self.state.count.other.new - 1
            self.state.count.other.pinged = self.state.count.other.pinged + 1
        elseif self.STATE_OK == newstate then
            self.state.count.other.new = self.state.count.other.new - 1
            if isready then
                self.state.count.rrl.ready = self.state.count.rrl.ready + 1
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready + 1
                self.state.count.total.ready = self.state.count.total.ready - 1
                self.state.count.total.notready = self.state.count.total.notready + 1
            end
        elseif nil == newstate then
            self.roster[k] = nil
            self.state.count.other.new = self.state.count.other.new - 1
            self.state.count.total.all = self.state.count.total.all - 1
            self.state.count.total.ready = self.state.count.total.ready - 1
        else
            self:Print('unhandled state change from',member.state,'to',newstate)
        end
    elseif self.STATE_PINGED == member.state then 
        if self.STATE_OFFLINE == newstate then
            member.ready = false
            self.state.count.other.pinged = self.state.count.other.pinged - 1
            self.state.count.other.offline = self.state.count.other.offline + 1
            self.state.count.total.ready = self.state.count.total.ready - 1
            self.state.count.total.notready = self.state.count.total.notready + 1
        elseif self.STATE_NORRL == newstate then
            member.ready = true
            self.state.count.other.pinged = self.state.count.other.pinged - 1
            self.state.count.other.noaddon = self.state.count.other.noaddon + 1
        elseif self.STATE_OK == newstate then
            self.state.count.other.pinged = self.state.count.other.pinged - 1
            if isready then
                self.state.count.rrl.ready = self.state.count.rrl.ready + 1
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready + 1
                self.state.count.total.ready = self.state.count.total.ready - 1
                self.state.count.total.notready = self.state.count.total.notready + 1
            end
        elseif nil == newstate then
            self.roster[k] = nil
            self.state.count.other.pinged = self.state.count.other.pinged - 1
            self.state.count.total.all = self.state.count.total.all - 1
            self.state.count.total.ready = self.state.count.total.ready - 1
        else
            self:Print('unhandled state change from',member.state,'to',newstate)
        end
    elseif self.STATE_OFFLINE == member.state then
        if self.STATE_NEW == newstate then
            member.ready = true
            self.state.count.other.offline = self.state.count.other.offline - 1
            self.state.count.other.new = self.state.count.other.new + 1
            self.state.count.total.ready = self.state.count.total.ready + 1
            self.state.count.total.notready = self.state.count.total.notready - 1
        elseif self.STATE_OK == newstate then
            self.state.count.other.offline = self.state.count.other.offline - 1
            if isready then
                self.state.count.rrl.ready = self.state.count.rrl.ready + 1
                self.state.count.total.ready = self.state.count.total.ready + 1
                self.state.count.total.notready = self.state.count.total.notready - 1
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready + 1
            end
        elseif nil == newstate then
            self.roster[k] = nil
            self.state.count.other.offline = self.state.count.other.offline - 1
            self.state.count.total.all = self.state.count.total.all - 1
            self.state.count.total.notready = self.state.count.total.notready - 1
        else
            self:Print('unhandled state change from',member.state,'to',newstate)
        end
    elseif self.STATE_NORRL == member.state then
        if self.STATE_OFFLINE == newstate then
            member.ready = false
            self.state.count.total.ready = self.state.count.total.ready - 1
            self.state.count.total.notready = self.state.count.total.notready + 1
            self.state.count.other.noaddon = self.state.count.other.noaddon - 1
            self.state.count.other.offline = self.state.count.other.offline + 1
        elseif self.STATE_AFK == newstate then
            member.ready = false
            self.state.count.total.ready = self.state.count.total.ready - 1
            self.state.count.total.notready = self.state.count.total.notready + 1
            self.state.count.other.noaddon = self.state.count.other.noaddon - 1
            self.state.count.other.afk = self.state.count.other.afk + 1
        elseif self.STATE_OK == newstate then
            self.state.count.other.noaddon = self.state.count.other.noaddon - 1
            if isready then
                self.state.count.rrl.ready = self.state.count.rrl.ready + 1
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready + 1
                self.state.count.total.ready = self.state.count.total.ready - 1
                self.state.count.total.notready = self.state.count.total.notready + 1
            end
        elseif nil == newstate then
            self.roster[k] = nil
            self.state.count.other.noaddon = self.state.count.other.noaddon - 1
            self.state.count.total.all = self.state.count.total.all - 1
            self.state.count.total.ready = self.state.count.total.ready - 1
        else
            self:Print('unhandled state change from',member.state,'to',newstate)
        end
    elseif self.STATE_AFK == member.state then
        if self.STATE_OFFLINE == newstate then
            member.ready = false
            self.state.count.other.afk = self.state.count.other.afk - 1
            self.state.count.other.offline = self.state.count.other.offline + 1
        elseif self.STATE_NEW == newstate then
            member.ready = true
            self.state.count.other.afk = self.state.count.other.afk - 1
            self.state.count.other.new = self.state.count.other.new + 1
        elseif self.STATE_OK == newstate then
            self.state.count.other.afk = self.state.count.other.afk - 1
            if isready then
                self.state.count.rrl.ready = self.state.count.rrl.ready + 1
                self.state.count.total.ready = self.state.count.total.ready + 1
                self.state.count.total.notready = self.state.count.total.notready - 1
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready + 1
            end
        elseif nil == newstate then
            self.roster[k] = nil
            self.state.count.other.afk = self.state.count.other.noaddon - 1
            self.state.count.total.all = self.state.count.total.all - 1
            self.state.count.total.notready = self.state.count.total.notready - 1
        else
            self:Print('unhandled state change from',member.state,'to',newstate)
        end
    else
        self:Print('unhandled old state', member.state)
        return
    end
    member.state = newstate
    member.last = time()
    self:DumpCounts()
end

-- determine if the raid is ready
function RRL:CalcRaidReady()
    
    -- determine our max not ready number
    self.state.count.max_notready = self.db.maxnotready[GetCurrentDungeonDifficulty()]

	-- determine if the raid is ready
	self.state.ready.raid = 1
	if self.state.count.rrl.crit_notready > 0 then
		self.state.ready.raid = 0
		if self.debug then
			self:Print("raid not ready because 1 or more critical members are not ready")
		end
	else
		if self.state.count.total.notready > self.state.max_notready then
			self.state.ready.raid = 0
			if self.debug then
				self:Print("raid not ready because more than",self.state.max_notready,"members are not ready")
			end
		else
			if self.debug then
				self:Print("raid is ready")
			end
		end
	end
    
	-- update our LDB text
    self:UpdateLDBText()
    
end

--
-- EOF