--
-- $Id$
--

-- external libs
local c = LibStub("LibCrayon-3.0")
local LibQTip = LibStub('LibQTip-1.0')

-- locale setup
--local L = LibStub("AceLocale-3.0"):GetLocale("RRL", true)

-- create LDB object
RRL.ldb_obj = LibStub("LibDataBroker-1.1"):NewDataObject("RRL", {
	type  = "data source",
	label = 'RRL',
	text  = "Not Active",
	icon  = "Interface\\RAIDFRAME\\ReadyCheck-Ready.png",
})

-- onclick handler
function RRL.ldb_obj.OnClick(self, which)
	if "LeftButton" == which and 1 == RRL.state.inraid then
		RRL:ToggleReady()
	elseif "RightButton" == which then
		if IsControlKeyDown() then
			InterfaceOptionsFrame_OpenToCategory(RRL.optionsFrames.rrl)
		elseif 1 == RRL.state.inraid then
			DoReadyCheck()
		end
	end
end

-- on entering the LDB or minion frame
function RRL.ldb_obj.OnEnter(self)
    local tip = LibQTip:Acquire("RRLTooltip", 2, "LEFT", "RIGHT")
    self.tooltip = tip
	tip:AddHeader('RRL: Raid Ready Light')
	tip:AddLine(" ")
	if 0 == RRL.state.inraid then
		tip:AddLine(c:White("Only active when in a raid"))
	else
		if true == RRL.db.exttooltip then
			if 1 == RRL.state.ready.raid then
				tip:AddLine(c:White("Raid"), c:Green("READY"))
			else
				tip:AddLine(c:White("Raid"), c:Red("NOT READY"))
			end
			if 1 == RRL.state.ready.self then
				tip:AddLine(c:White("You"), c:Green("READY"))
			else
				tip:AddLine(c:White("You"), c:Red("NOT READY"))
			end
            tip:AddLine(c:White("Raid Size:"), c:Green(RRL.state.count.total.all))
			tip:AddLine(
				c:White("RRL Ready"),
				c:Colorize(c:GetThresholdHexColor(RRL.state.count.rrl.ready,RRL.state.count.total.all), RRL.state.count.rrl.ready)
			)
			tip:AddLine(c:White("RRL Not Ready"), c:Red(RRL.state.count.rrl.notready))
			tip:AddLine(c:White("Max Not Ready"), c:Yellow(RRL.state.maxnotready))
			tip:AddLine(c:White("Critical"), c:Red(RRL.state.count.rrl.crit_notready))
			tip:AddLine(c:White("Offline"), c:Yellow(RRL.state.count.other.offline))
			tip:AddLine(c:White("New"), c:Yellow(RRL.state.count.other.new))
			tip:AddLine(c:White("Pinged"), c:Yellow(RRL.state.count.other.pinged))
			tip:AddLine(c:White("No Addon"), c:Yellow(RRL.state.count.other.noaddon))
            tip:AddLine(c:White("AFK"), c:Yellow(RRL.state.count.other.afk))
			tip:AddLine(" ")
		end
		for k,v in pairs(RRL.roster)
		do
			if RRL.STATE_OK == v.state then
				if false == v.ready then
					local critsuffix = ''
					if true == v.critical then
						critsuffix = '*'
					end
					tip:AddLine(c:White(k), c:Red('Not Ready'..critsuffix))
				end
			elseif RRL.STATE_OFFLINE == v.state then
				tip:AddLine(c:White(k), c:Yellow('Offline'))
			elseif RRL.STATE_PINGED == v.state then
				tip:AddLine(c:White(k), c:Yellow('Pinged'))
			elseif RRL.STATE_NEW == v.state then
				tip:AddLine(c:White(k), c:Yellow('New'))
			elseif RRL.STATE_NORRL == v.state then
				if false == v.ready then
					tip:AddLine(c:White(k), c:Red('Not Ready'))
				else
					tip:AddLine(c:White(k), c:Yellow('No Addon'))
				end
			elseif RRL.STATE_AFK == v.state then
                tip:AddLine(c:White(k), c:Red('AFK'))
            end
		end
	end
	tip:AddLine(" ")
	if 1 == RRL.state.inraid then
        tip:AddHeader("Left-click to change your status")
        tip:AddHeader("Right-click to do a ready check")
    end
	tip:AddHeader("Control-Right-click to configure")
    tip:SmartAnchorTo(self)
	tip:Show()
end

-- on leaving the LDB object or minion frame
function RRL.ldb_obj.OnLeave(self)
    LibQTip:Release(self.tooltip)
    self.tooltip = nil
end

-- update the LDB text
function RRL:UpdateLDBText()
    if 1 == self.state.inraid then
        -- build the LDB text
        local youstring
        local raidstring
        local countstring
        if 1 == self.state.ready.self then
            youstring = c:Green("YOU")
        else
            youstring = c:Red("YOU")
        end
        if 1 == self.state.ready.raid then
            self.ldb_obj.status = true
            self.ldb_obj.icon = "Interface\\RAIDFRAME\\ReadyCheck-Ready.png"
            raidstring = c:Green("RAID")
        else
            self.ldb_obj.status = false
            self.ldb_obj.icon = "Interface\\RAIDFRAME\\ReadyCheck-NotReady.png"
            raidstring = c:Red("RAID")
        end
        countstring = self.state.count.total.ready.."/"..self.state.count.total.all
        if self.state.count.rrl.crit_notready > 0 then
            countstring = countstring .. "*"
        end
        self.ldb_obj.text = youstring .. "/" .. raidstring .. " " .. c:White(countstring)
    else
        self:Debug("updating LDB to show not active")
      	self.ldb_obj.text = "Not Active"
        self.ldb_obj.icon = "Interface\\RAIDFRAME\\ReadyCheck-Ready.png"
    end
end

--
-- EOF