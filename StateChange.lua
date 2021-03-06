--
-- $Date$ $Revision$
--

-- update the counts based upon a given state change
function RRL:StateChange(member, newstate, isready, name)

    local wasready
    local oldstate
    
    self:Debug('member newstate isready name', member, newstate, isready, name)
    
    -- handle new members
    local new = nil == member
    if new then
        self:Debug('member is new')
        oldstate = nil
    else
        oldstate = member.state
        wasready = member.ready
        if not name then
            name = member.name
        end
    end
    
    self:Debug('name oldstate newstate wasready isready', name, oldstate, newstate, wasready, isready)
    
    -- update counts
    if self.STATE_OK == oldstate then
        if self.STATE_OK == newstate then
            if wasready and not isready then
                member.ready = false
                self.state.count.rrl.ready = self.state.count.rrl.ready - 1
                self.state.count.rrl.notready = self.state.count.rrl.notready + 1
                self.state.count.total.ready = self.state.count.total.ready - 1
                self.state.count.total.notready = self.state.count.total.notready + 1
            elseif not wasready and isready then
                member.ready = true
                self.state.count.rrl.ready = self.state.count.rrl.ready + 1
                self.state.count.rrl.notready = self.state.count.rrl.notready - 1
                self.state.count.total.ready = self.state.count.total.ready + 1
                self.state.count.total.notready = self.state.count.total.notready - 1               
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
            self.roster[name] = nil
            self.state.count.total.all = self.state.count.total.all - 1
            if wasready then
                self.state.count.total.ready = self.state.count.total.ready - 1
                self.state.count.rrl.ready = self.state.count.rrl.ready - 1
            else
                self.state.count.total.notready = self.state.count.total.notready - 1
                self.state.count.rrl.notready = self.state.count.rrl.notready - 1
            end
        else
            self:Print(c:Red('ERROR'),'unhandled state change from',oldstate,'to',newstate)
        end
    elseif self.STATE_NEW == oldstate then 
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
            member.ready = isready
            self.state.count.other.new = self.state.count.other.new - 1
            if isready then
                self.state.count.rrl.ready = self.state.count.rrl.ready + 1
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready + 1
                self.state.count.total.ready = self.state.count.total.ready - 1
                self.state.count.total.notready = self.state.count.total.notready + 1
            end
        elseif self.STATE_AFK == newstate then
            member.ready = false
            self.state.count.total.ready = self.state.count.total.ready - 1
            self.state.count.total.notready = self.state.count.total.notready + 1
            self.state.count.other.new = self.state.count.other.new - 1
            self.state.count.other.afk = self.state.count.other.afk + 1
        elseif nil == newstate then
            self.roster[name] = nil
            self.state.count.other.new = self.state.count.other.new - 1
            self.state.count.total.all = self.state.count.total.all - 1
            self.state.count.total.ready = self.state.count.total.ready - 1
        else
            self:Print(c:Red('ERROR'),'unhandled state change from',oldstate,'to',newstate)
        end
    elseif self.STATE_PINGED == oldstate then 
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
            member.ready = isready
            self.state.count.other.pinged = self.state.count.other.pinged - 1
            if isready then
                self.state.count.rrl.ready = self.state.count.rrl.ready + 1
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready + 1
                self.state.count.total.ready = self.state.count.total.ready - 1
                self.state.count.total.notready = self.state.count.total.notready + 1
            end
        elseif self.STATE_AFK == newstate then
            member.ready = false
            self.state.count.total.ready = self.state.count.total.ready - 1
            self.state.count.total.notready = self.state.count.total.notready + 1
            self.state.count.other.pinged = self.state.count.other.pinged - 1
            self.state.count.other.afk = self.state.count.other.afk + 1
        elseif nil == newstate then
            self.roster[name] = nil
            self.state.count.other.pinged = self.state.count.other.pinged - 1
            self.state.count.total.all = self.state.count.total.all - 1
            self.state.count.total.ready = self.state.count.total.ready - 1
        else
            self:Print(c:Red('ERROR'),'unhandled state change from',oldstate,'to',newstate)
        end
    elseif self.STATE_OFFLINE == oldstate then
        if self.STATE_NEW == newstate then
            member.ready = true
            self.state.count.other.offline = self.state.count.other.offline - 1
            self.state.count.other.new = self.state.count.other.new + 1
            self.state.count.total.ready = self.state.count.total.ready + 1
            self.state.count.total.notready = self.state.count.total.notready - 1
        elseif self.STATE_OK == newstate then
            member.ready = isready
            self.state.count.other.offline = self.state.count.other.offline - 1
            if isready then
                self.state.count.rrl.ready = self.state.count.rrl.ready + 1
                self.state.count.total.ready = self.state.count.total.ready + 1
                self.state.count.total.notready = self.state.count.total.notready - 1
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready + 1
            end
        elseif nil == newstate then
            self.roster[name] = nil
            self.state.count.other.offline = self.state.count.other.offline - 1
            self.state.count.total.all = self.state.count.total.all - 1
            self.state.count.total.notready = self.state.count.total.notready - 1
        else
            self:Print(c:Red('ERROR'),'unhandled state change from',oldstate,'to',newstate)
        end
    elseif self.STATE_NORRL == oldstate then
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
            member.ready = isready
            self.state.count.other.noaddon = self.state.count.other.noaddon - 1
            if isready then
                self.state.count.rrl.ready = self.state.count.rrl.ready + 1
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready + 1
                self.state.count.total.ready = self.state.count.total.ready - 1
                self.state.count.total.notready = self.state.count.total.notready + 1
            end
        elseif nil == newstate then
            self.roster[name] = nil
            self.state.count.other.noaddon = self.state.count.other.noaddon - 1
            self.state.count.total.all = self.state.count.total.all - 1
            self.state.count.total.ready = self.state.count.total.ready - 1
        else
            self:Print(c:Red('ERROR'),'unhandled state change from',oldstate,'to',newstate)
        end
    elseif self.STATE_AFK == oldstate then
        if self.STATE_OFFLINE == newstate then
            member.ready = false
            self.state.count.other.afk = self.state.count.other.afk - 1
            self.state.count.other.offline = self.state.count.other.offline + 1
        elseif self.STATE_NORRL == newstate then
            member.ready = true
            self.state.count.other.afk = self.state.count.other.afk - 1
            self.state.count.other.noaddon = self.state.count.other.noaddon + 1
            self.state.count.total.ready = self.state.count.total.ready + 1
            self.state.count.total.notready = self.state.count.total.notready - 1
        elseif self.STATE_OK == newstate then
            member.ready = isready
            self.state.count.other.afk = self.state.count.other.afk - 1
            if isready then
                self.state.count.rrl.ready = self.state.count.rrl.ready + 1
                self.state.count.total.ready = self.state.count.total.ready + 1
                self.state.count.total.notready = self.state.count.total.notready - 1
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready + 1
            end
        elseif nil == newstate then
            self.roster[name] = nil
            self.state.count.other.afk = self.state.count.other.afk - 1
            self.state.count.total.all = self.state.count.total.all - 1
            self.state.count.total.notready = self.state.count.total.notready - 1
        else
            self:Print(c:Red('ERROR'),'unhandled state change from',oldstate,'to',newstate)
        end
    elseif nil == oldstate then
        if self.STATE_NEW == newstate then
            self.state.count.other.new = self.state.count.other.new + 1
            self.state.count.total.ready = self.state.count.total.ready + 1
            self.state.count.total.all = self.state.count.total.all + 1
            self.roster[name] = {
                name = name,
                ready = true,
            }
            member = self.roster[name]
        elseif self.STATE_OK == newstate then
            self.state.count.total.all = self.state.count.total.all + 1
            if isready then
                self.state.count.rrl.ready = self.state.count.rrl.ready + 1
                self.state.count.total.ready = self.state.count.total.ready + 1
                self.roster[name] = {
                    name = name,
                    ready = true,
                }
            else
                self.state.count.rrl.notready = self.state.count.rrl.notready + 1
                self.state.count.total.notready = self.state.count.total.notready + 1
                self.roster[name] = {
                    name = name,
                    ready = false,
                }
            end
            member = self.roster[name]
        elseif self.STATE_OFFLINE == newstate then
            self.state.count.other.offline = self.state.count.other.offline + 1
            self.state.count.total.notready = self.state.count.total.notready + 1
            self.state.count.total.all = self.state.count.total.all + 1
            self.roster[name] = {
                name = name,
                ready = false,
            }
            member = self.roster[name]
        else
            self:Print(c:Red('ERROR'),'unhandled state change from',oldstate,'to',newstate)
        end
    else
        self:Print(c:Red('ERROR'),'unhandled old state', oldstate)
        return
    end
    
    -- did a critical member's state change?
    if self.db.critical[name] then
        if new then
            if not member.ready then
                self.state.count.rrl.crit_notready = self.state.count.rrl.crit_notready + 1
            end
        else
            if wasready and not member.ready then
                self.state.count.rrl.crit_notready = self.state.count.rrl.crit_notready + 1
            elseif not wasready and member.ready then
                self.state.count.rrl.crit_notready = self.state.count.rrl.crit_notready - 1
            end
        end
    end
    
    member.state = newstate
    member.last = time()
end

-- determine if the raid is ready
function RRL:CalcRaidReady()
    
    -- determine our max not ready number
    self.state.maxnotready = self.db.maxnotready[GetCurrentDungeonDifficulty()]

    -- remember our existing state
    local oldraidstate = self.state.ready.raid
    
	-- determine if the raid is ready
	self.state.ready.raid = 1
	if self.state.count.rrl.crit_notready > 0 then
		self.state.ready.raid = 0
        self:Debug("raid not ready because 1 or more critical members are not ready")
	else
		if self.state.count.total.notready > self.state.maxnotready then
			self.state.ready.raid = 0
            self:Debug("raid not ready because more than",self.state.maxnotready,"members are not ready")
		else
            self:Debug("raid is ready")
		end
	end
    
	-- update our LDB text
    self:UpdateLDBText()
    if self.minion then self:UpdateMinion() end
    
    -- notify if the raid state has changed
    if 0 == oldraidstate and 1 == self.state.ready.raid then
        self:Pour("raid is READY", 0, 1, 0, nil, 24, "OUTLINE")
    elseif 1 == oldraidstate and 0 == self.state.ready.raid then
        self:Pour("raid is NOT READY", 1, 0, 0, nil, 24, "OUTLINE")
    end
    
end

--
-- EOF