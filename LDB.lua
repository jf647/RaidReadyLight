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
	if "LeftButton" == which and true == RRL.inraid then
		RRL:ToggleReady(false)
	elseif "RightButton" == which then
		if IsControlKeyDown() then
			InterfaceOptionsFrame_OpenToCategory(RRL.optionsFrames.rrl)
		elseif true == RRL.inraid then
			DoReadyCheck()
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
		if true == RRL.db.exttooltip then
			if true == RRL.raidready then
				tip:AddDoubleLine(c:White("Raid"), c:Green("READY"))
			else
				tip:AddDoubleLine(c:White("Raid"), c:Red("NOT READY"))
			end
			if true == RRL.selfready then
				tip:AddDoubleLine(c:White("You"), c:Green("READY"))
			else
				tip:AddDoubleLine(c:White("You"), c:Red("NOT READY"))
			end
			tip:AddDoubleLine(
				c:White("Ready"),
				c:Colorize(c:GetThresholdHexColor(RRL.count.rrl_ready,RRL.count.total), RRL.count.rrl_ready)
				.. "/"..c:Green(RRL.count.total)
			)
			tip:AddDoubleLine(c:White("Not Ready"), c:Red(RRL.count.rrl_notready))
			tip:AddDoubleLine(c:White("Max Not Ready"), c:Yellow(RRL.count.max_notready))
			tip:AddDoubleLine(c:White("Critical"), c:Red(RRL.count.rrl_notready_crit))
			tip:AddDoubleLine(c:White("Offline"), c:Yellow(RRL.count.offline))
			tip:AddDoubleLine(c:White("New"), c:Yellow(RRL.count.new))
			tip:AddDoubleLine(c:White("Pinged"), c:Yellow(RRL.count.pinged))
			tip:AddDoubleLine(c:White("No Addon"), c:Yellow(RRL.count.norrl))
			tip:AddLine(" ")
		end
		for k,v in pairs(RRL.members)
		do
			if RRL.STATE_OK == v.state then
				if false == v.ready then
					local critsuffix = ''
					if true == v.critical then
						critsuffix = '*'
					end
					tip:AddDoubleLine(c:White(k), c:Red('Not Ready'..critsuffix))
				end
			elseif RRL.STATE_OFFLINE == v.state then
				tip:AddDoubleLine(c:White(k), c:Yellow('Offline'))
			elseif RRL.STATE_PINGED == v.state then
				tip:AddDoubleLine(c:White(k), c:Yellow('Pinged'))
			elseif RRL.STATE_NEW == v.state then
				tip:AddDoubleLine(c:White(k), c:Yellow('New'))
			elseif RRL.STATE_NORRL == v.state then
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
	tip:Show()
end

-- update the LDB text
function RRL:UpdateLDBText()
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
--
-- EOF