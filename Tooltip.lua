--
-- $Id$
--

local LibQTip = LibStub('LibQTip-1.0')

function RRL:DisplayTooltip()

    -- acquire
    local tip = LibQTip:Acquire("RRLMinionTooltip", 2, "LEFT", "RIGHT")
    frame.tooltip = tip

	-- populate
    tip:AddHeader("RRL: Raid Ready Light")
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
        tip:AddHeader(c:White("Left-click to change your status"))
        tip:AddHeader(c:White("Right-click to do a ready check"))
    end
	tip:AddHeader(c:White("Control-Right-click to configure"))
    
    -- anchor and display
    tip:SmartAnchorTo(frame)
    tip:Show()

end

function RRL:DestroyTooltip(frame)
    LibQTip:Release(frame.tooltip)
    frame.tooltip = nil
end

--
-- EOF
