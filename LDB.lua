--
-- $Id$
--

-- external libs
local c = LibStub("LibCrayon-3.0")

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
function RRL.ldb_obj.OnClick(_, which)
	if true == RRL.inraid then
		if "LeftButton" == which then
			RRL:ToggleReady(false)
		elseif "RightButton" == which then
			if IsControlKeyDown() then
				InterfaceOptionsFrame_OpenToCategory(RRL.optionsFrames.rrl)
			else
				DoReadyCheck()
			end
		end
	end
end

-- display the LDB tooltip
local ldb_tip
function RRL.ldb_obj.OnTooltipShow(tip)
	if not ldb_tip then
		ldb_tip = tip
	end
	tip:ClearLines()
	tip:AddLine(c:White("RRL: Raid Ready Light"))
	tip:AddLine(" ")
	if false == RRL.inraid then
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
		tip:AddDoubleLine(
			c:White("Ready:"),
			c:Colorize(c:GetThresholdHexColor(RRL.count.rrl_ready,RRL.count.total), RRL.count.rrl_ready)
			.. "/"..c:Green(RRL.count.total)
		)
		tip:AddDoubleLine(c:White("Not Ready:"), c:Red(RRL.count.rrl_notready) .. "/".. c:Red(RRL.count.max_notready))
		tip:AddDoubleLine(c:White("Critical: "), c:Red(RRL.count.rrl_notready_crit))
		tip:AddDoubleLine(c:White("Offline: "), c:Yellow(RRL.count.offline))
		tip:AddDoubleLine(c:White("Unknown: "), c:Yellow(RRL.count.meta_unknown))
		tip:AddDoubleLine(c:White("No Addon: "), c:Yellow(RRL.count.norrl))
		if false == RRL.db.simpletooltip then
			tip:AddLine(" ")
			for k,v in pairs(RRL.members)
			do
				if RRL_STATE_OK == v.state then
					if false == v.ready then
						local critsuffix = ''
						if true == v.critical then
							critsuffix = '*'
						end
						tip:AddDoubleLine(c:White(k), c:Red('Not Ready'..critsuffix))
					end
				elseif RRL_STATE_OFFLINE == v.state then
					tip:AddDoubleLine(c:White(k), c:Yellow('Offline'))
				elseif RRL_STATE_PINGED == v.state then
					tip:AddDoubleLine(c:White(k), c:Yellow('Pinged'))
				elseif RRL_STATE_NEW == v.state then
					tip:AddDoubleLine(c:White(k), c:Yellow('New'))
				elseif RRL_STATE_NORRL == v.state then
					if false == v.ready then
						tip:AddDoubleLine(c:White(k), c:Red('Not Ready'))
					else
						tip:AddDoubleLine(c:White(k), c:Yellow('No Addon'))
					end
				end
			end
		end
		tip:AddLine(" ")
		tip:AddLine(c:White("Left-click to change your status"))
		tip:AddLine(c:White("Right-click to do a ready check"))
		tip:AddLine(c:White("Control-Right-click to configure"))
	end
	tip:Show()
end

--
-- EOF