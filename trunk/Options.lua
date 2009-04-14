--
-- $Id$
--

-- locale setup
--local L = LibStub("AceLocale-3.0"):GetLocale("RRL", true)

RRL.optionsSlash = {
    name = "rrl",
    handler = RRL,
    type = 'group',
    args = {
        config = {
            type = 'execute',
            name = 'config',
            desc = 'open configuration pane',
            func = function(info) InterfaceOptionsFrame_OpenToCategory(RRL.optionsFrames.RRL) end,
            guiHidden = true,
        },
    },
}

RRL.options = {
    name = "rrl",
    handler = RRL,
    type = 'group',
    args = {
        Options = {
            type = 'group',
            name = 'General Options',
            desc = 'General Options',
            args = {
                readycheck = {
                    type = 'toggle',
                    name = 'Readycheck Reply',
                    desc = 'auto-respond to ready checks',
                    get  = function(info) return RRL.db.readycheck_respond end,
                    set  = 'ToggleReadyCheck',
                    order = 100,
                    cmdHidden = true,
                },
                minion = {
                    type = 'toggle',
                    name = 'Minion',
                    desc = 'toggle the RRL minion on/off',
                    get  = function(info) return RRL.db.minion end,
                    set  = 'ToggleMinion',
                    order = 110,
                    cmdHidden = true,
                },
                extendedtooltip = {
                    type = 'toggle',
                    name = 'Extended Tooltip',
                    desc = 'toggle the extended tooltip on/off',
                    get  = function(info) return RRL.db.exttooltip end,
                    set  = function(info) RRL.db.exttooltip = not RRL.db.exttooltip end,
                    order = 120,
                    cmdHidden = true,
                },
                divider1 = {
                    type = 'header',
                    name = 'Scales',
                    order = 130,
                },
                minionscale = {
                    type = 'range',
                    name = 'Minion Scale',
                    desc = 'set the scale of the minion frame',
                    min  = 0.5,
                    max  = 2,
                    step = 0.1,
                    set  = function(info,scale)
                        RRL.db.minionscale = scale
                        if RRL.minion then
                            RRL.minion:SetScale(scale)
                        end
                    end,
                    get  = function(info) return RRL.db.minionscale end,
                    order = 140,
                    cmdHidden = true,
                },
                minionalpha = {
                    type = 'range',
                    name = 'Minion Alpha',
                    desc = 'set the transparency of the minion frame',
                    min  = 0.1,
                    max  = 1,
                    step = 0.1,
                    set  = function(info,scale)
                        RRL.db.minionalpha = scale
                        if RRL.minion then
                            RRL.minion:SetAlpha(scale)
                        end
                    end,
                    get  = function(info) return RRL.db.minionalpha end,
                    order = 145,
                    cmdHidden = true,
                },
                tooltipscale = {
                    type = 'range',
                    name = 'Tooltip Scale',
                    desc = 'set the scale of the tooltip',
                    min  = 0.5,
                    max  = 2,
                    step = 0.1,
                    set  = function(info,scale) RRL.db.tooltipscale = scale end,
                    get  = function(info) return RRL.db.tooltipscale end,
                    order = 150,
                    cmdHidden = true,
                },
                divider2 = {
                    type = 'header',
                    name = 'Max Not Ready',
                    order = 180,
                },
                maxnotready_normal = {
                    type = 'range',
                    name = 'Normal Raids',
                    desc = 'maximum not ready members',
                    min  = 0,
                    max  = 10,
                    step = 1,
                    set  = function(info, value) RRL.db.maxnotready[1] = value end,
                    get  = function(info) return RRL.db.maxnotready[1] end,
                    order = 190,
                    cmdHidden = true,
                },
                maxnotready_heroic = {
                    type = 'range',
                    name = 'Heroic Raids',
                    desc = 'maximum not ready members',
                    min  = 0,
                    max  = 25,
                    step = 1,
                    set  = function(info, value) RRL.db.maxnotready[2] = value end,
                    get  = function(info) return RRL.db.maxnotready[2] end,
                    order = 200,
                    cmdHidden = true,
                },
            },
        },
        Critical = {
            type = 'group',
            name = 'Critical Members',
            desc = 'Critical Members',
            args = {
                add = {
                    type = 'input',
                    name = 'Add',
                    desc = 'add a member who must be ready',
                    set = 'AddCritical',
                    order = 220,
                    cmdHidden = true,
                },
                add_fromtarget = {
                    type = 'execute',
                    name = 'Add Target',
                    desc = 'adds your current target to the critical list',
                    func = function(info)
                        if UnitIsPlayer("target") and UnitFactionGroup("target") == UnitFactionGroup("player") then
                            RRL:AddCritical(info, UnitName("target"))
                        end
                    end,
                    order = 230,
                    cmdHidden = true,
                },
                show = {
                    type = 'select',
                    name = 'List',
                    desc = 'shows critical members',
                    get = false,
                    set = false,
                    values = function(info) return RRL.db.critical end,
                    disabled = function(info) return ((not next(RRL.db.critical)) and true or false) end,
                    order = 240,
                    cmdHidden = true,
                },
                delete = {
                    type = 'select',
                    name = 'Delete',
                    desc = 'delete a member who must be ready',
                    get = false,
                    set = "DelCritical",
                    values = function(info) return RRL.db.critical end,
                    disabled = function(info) return ((not next(RRL.db.critical)) and true or false) end,
                    confirm = function(info, value) return 'Remove '..value..' from the critical list?' end,
                    order = 250,
                    cmdHidden = true,
                },
                clear = {
                    type = 'execute',
                    name = 'Clear',
                    desc = 'clears members who must be ready',
                    func  = 'ClearCritical',
                    disabled = function(info) return ((not next(RRL.db.critical)) and true or false) end,
                    confirm = true,
                    confirmText = 'Clear the critical list?',
                    order = 260,
                    cmdHidden = true,
                },
            },
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
        minion = true,
        minionscale = 0.8,
        tooltipscale = 0.8,
        minionalpha = 1.0,
        output = {
          sink20OutputSink = "Default"
        },
	},
}

-- init options frames
function RRL:InitOptions()
    -- profiles
    self.options.args.Profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.database)
    -- output
    self.options.args.Output = RRL:GetSinkAce3OptionsDataTable()
    -- tell sink where to store its settings
    self:SetSinkStorage(self.db.output)
	-- slash commands
	LibStub("AceConfig-3.0"):RegisterOptionsTable("RRLSlashCommand", self.optionsSlash, "rrl")
    self.optionsSlash.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.database)
    -- GUI config
    local ACD3 = LibStub("AceConfigDialog-3.0")
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("RRL", self.options)
    self.optionsFrames = {}
    self.optionsFrames.RRL = LibStub("tekKonfig-AboutPanel").new(nil, "RRL")
    self.optionsFrames.Options = ACD3:AddToBlizOptions("RRL", "Options", "RRL", "Options")
    self.optionsFrames.Output = ACD3:AddToBlizOptions("RRL", "Output", "RRL", "Output")
    self.optionsFrames.Critical = ACD3:AddToBlizOptions("RRL", "Critical", "RRL", "Critical")
    self.optionsFrames.Profiles = ACD3:AddToBlizOptions("RRL", "Profiles", "RRL", "Profiles")
end

-- set the update interval
function RRL:SetInterval(info, interval)
  RRL.db.updateinterval = interval
  self:CancelTimer(self.send_timer, true)
  self:CancelTimer(self.maint_timer, true)
  self.send_timer = self:ScheduleRepeatingTimer('SendStatus', interval)
  self.maint_timer = self:ScheduleRepeatingTimer('MaintRoster', interval)
end

-- clears critical members
function RRL:ClearCritical()
	RRL.db.critical = {}
    self:BuildRoster()
end

-- adds a critical member
function RRL:AddCritical(info, member)
	if "" ~= member then
        if not RRL.db.critical[member] then
            RRL.db.critical[member] = member
            self:BuildRoster()
        end
	end
end

-- deletes a critical member
function RRL:DelCritical(info, member)
	if "" ~= member then
		if RRL.db.critical[member] then
			RRL.db.critical[member] = nil
            self:BuildRoster()
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
		if self:IsHooked("ShowReadyCheck") then
			self:Unhook("ShowReadyCheck")
		end
		RRL:UnregisterEvent("READY_CHECK")
	end
end

-- toggle the minion on/off
function RRL:ToggleMinion(info)
    RRL.db.minion = not RRL.db.minion
    self:Debug("RRL.db.minion is",RRL.db.minion)
    self:Debug("RRL.minion is",RRL.minion)
    if RRL.db.minion and not RRL.minion and 1 == self.state.inraid then
        self:Debug('minion enabled but not active; creating it')
        self:CreateMinion()
    elseif not RRL.db.minion and RRL.minion then
        self:Debug('minion disabled but active; destroying it')
        self:DestroyMinion()
    end
end

--
-- EOF
