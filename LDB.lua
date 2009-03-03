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

-- tooltip display functions
function RRL.ldb_obj.OnEnter(frame)
    RRL.DisplayTooltip(frame)
end
function RRL.ldb_obj.OnLeave(frame)
    RRL.DestroyTooltip(frame)
end

-- onclick handler
function RRL.ldb_obj.OnClick(_, which)
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

-- display the LDB tooltip
function RRL.ldb_obj.OnEnter(frame)
    self:Debug('ldb frame onenter is',frame)
    RRL:DisplayTooltip(frame)
end

function RRL.ldb_obj.OnLeave(frame)
    self:Debug('ldb frame onleave is',frame)
    RRL:DestroyTooltip(frame)
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