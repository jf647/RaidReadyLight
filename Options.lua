--
-- $Id$
--

-- locale setup
--local L = LibStub("AceLocale-3.0"):GetLocale("RRL", true)

RRL.options = {
    name = "rrl",
    handler = RRL,
    type = 'group',
    args = {
        max = {
			name = 'Max Not Ready',
			desc = 'set maximum not ready members',
			type = 'group',
			args = {
				normal = {
					type = 'range',
					name = 'Normal Raids',
					desc = 'maximum not ready members',
					min  = 0,
					max  = 10,
					step = 1,
					set  = function(info, value) RRL:SetMax(1, 0, 10, value) end,
					get  = function(info) return RRL.db.maxnotready[1] end,
					order = 100,
				},
				heroic = {
					type = 'range',
					name = 'Heroic Raids',
					desc = 'maximum not ready members',
					min  = 0,
					max  = 25,
					step = 1,
					set  = function(info, value) RRL:SetMax(2, 0, 25, value) end,
					get  = function(info) return RRL.db.maxnotready[2] end,
					order = 110,
				},
			},
        },
        critical = {
		    name = 'Critical Members',
			desc = 'manipulate list of members who must be ready',
            type = 'group',
            args = {
                add = {
                    type = 'input',
                    name = 'Add',
                    desc = 'add a member who must be ready',
                    set = 'AddCritical',
					order = 100,
                },
                del = {
                    type = 'input',
                    name = 'Delete',
                    desc = 'delete a member who must be ready',
                    set = 'DelCritical',
					order = 110,
                },
                list = {
                    type = 'execute',
                    name = 'List',
                    desc = 'lists members who must be ready',
                    func  = 'ListCritical',
					order = 200,
                },
                clear = {
                    type = 'execute',
                    name = 'Clear',
                    desc = 'clears members who must be ready',
                    func  = 'ClearCritical',
					order = 210,
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
			bigStep = 30,
            set  = 'SetInterval',
            get  = function(info) return RRL.db.updateinterval end,
			disabled = true,
			order = 100,
        },
		readycheck = {
			type = 'toggle',
			name = 'Readycheck Reply',
			desc = 'auto-respond to ready checks',
			get  = function(info) return RRL.db.readycheck_respond end,
			set  = 'ToggleReadyCheck',
			order = 120,
		},
        debug = LibStub('LibDebugLog-1.0'):GetAce3OptionTable(self, 130),
        dump = {
            type = 'execute',
            name = 'Dump State',
            desc = 'dump the member state and counts',
			func = 'Dump',
			guiHidden = true,
        },
		extendedtooltip = {
			type = 'toggle',
			name = 'Extended Tooltip',
			desc = 'toggle the extended tooltip on/off',
			get  = function(info) return RRL.db.exttooltip end,
			set  = function(info) RRL.db.exttooltip = not RRL.db.exttooltip end,
			order = 110,
		},
    },
}

-- default profile
RRL.defaults = {
    profile = {
	    updateinterval = 30,
		maxnotready = { 1, 3 },
		readycheck_respond = 1,
		critical = {},
		exttooltip = false,
	},
}

-- set the max number of not ready members
function RRL:SetMax(instancetype, min, max, value)
	if value < min or value > max then
		self:Print("max not ready members for", instancetype, "is", min .. '-' .. max)
	else
		RRL.db.maxnotready[instancetype] = value
	end
end

-- set the update interval
function RRL:SetInterval(info, interval)
	if interval < 1 or interval > 600 then
		self:Print("interval range: 1-600")
	else
		RRL.db.updateinterval = interval
		self:CancelTimer(self.send_timer, true)
		self.send_timer = self:ScheduleRepeatingTimer('RRL_SEND_UPDATE', interval)
	end
end

-- lists critical members
function RRL:ListCritical()
	self:Print("Members who must be ready:")
    for k,v in pairs(RRL.db.critical)
	do
		self:Print(k)
	end
end

-- clears critical members
function RRL:ClearCritical()
	self:Print("critical members list has been cleared")
	RRL.db.critical = {}
    self:BuildRoster()
end

-- adds a critical member
function RRL:AddCritical(info, member)
	if "" ~= member then
		if RRL.db.critical[member] then
			self:Print("'"..member.."' was already on the critical list")
		else
			RRL.db.critical[member] = 1
			self:Print("added '"..member.."' to the critical list")
            self:BuildRoster()
		end
	else
		member = UnitName('target')
		if nil ~= member then
			if RRL.db.critical[member] then
				self:Print("'"..member.."' was already on the critical list")
			else
				RRL.db.critical[member] = 1
				self:Print("added '"..member.."' to the critical list")
                self:BuildRoster()
			end
		else
			self:Print("usage: /rrl critical add name (uses target if no name)")
		end
	end
end

-- deletes a critical member
function RRL:DelCritical(info, member)
	if "" ~= member then
		if RRL.db.critical[member] then
			RRL.db.critical[member] = nil
			self:Print("removed '"..member.."' from the critical list")
            self:BuildRoster()
		else
			self:Print("'"..member.."' is not on the critical list")
		end
	else
		member = UnitName('target')
		if nil ~= member then
			if RRL.db.critical[member] then
				RRL.db.critical[member] = nil
				self:Print("removed '"..member.."' from the critical list")
                self:BuildRoster()
			else
				self:Print("'"..member.."' is not on the critical list")
			end
		else
			self:Print("usage: /rrl critical del name (uses target if no name)")
		end
	end
end

-- toggle auto-responding to ready checks
function RRL:ToggleReadyCheck()
    RRL.db.readycheck_respond = not RRL.db.readycheck_respond
	if RRL.db.readycheck_respond then
		if 1 == self.state.inraid then
			if not self:IsHooked("ShowReadyCheck") then
				self:RawHook("ShowReadyCheck", true)
			end
			RRL:RegisterEvent("READY_CHECK")
		end
	else
		self:Print("will not auto-respond to ready checks")
		if self:IsHooked("ShowReadyCheck") then
			self:Unhook("ShowReadyCheck")
		end
		RRL:UnregisterEvent("READY_CHECK")
	end
end

--
-- EOF
