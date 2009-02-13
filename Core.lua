--
-- $Id$
--

RRL = LibStub("AceAddon-3.0"):NewAddon(
    "RRL",
    "AceConsole-3.0",
    "AceDB-3.0",
    "AceComm-3.0",
    "AceEvent-3.0"
)
local L = LibStub("AceLocale-3.0"):GetLocale("RRL", true)

-- locals
local timer
local ready = false

-- slash commands
local options = {
    name = "rrl",
    handler = RRL,
    type = 'group',
    args = {
        max = {
            type = 'input',
            name = 'get/set max not ready',
            desc = 'get or set the maximum number of not ready members',
            set = 'SetMax',
            get = 'GetMax',
        },
        interval = {
            type = 'input',
            name = 'get/set update interval',
            desc = 'get or set the raid update interval',
            set  = 'SetInterval',
            get  = 'GetInterval',
        },
        r = {
            type = 'input',
            name = 'set ready',
            desc = 'mark yourself as ready',
            set  = 'SetReady',
        },
        nr = {
            type = 'input',
            name = 'set not ready',
            desc = 'mark yourself as not ready',
            set  = 'SetNotReady',
        },
        critical {
            type = 'group',
            args = {
                add = {
                    type = 'input',
                    name = 'add a critical member',
                    desc = 'add a member who must be ready',
                    set  = 'AddCritical',
                },
                del = {
                    type = 'input',
                    name = 'delete a critical member',
                    desc = 'delete a member who must be ready',
                    set  = 'DelCritical',
                },
                list = {
                    type = 'input',
                    name = 'lists critical members',
                    desc = 'lists members who must be ready',
                    set  = 'ListCritical',
                },
                clear = {
                    type = 'input',
                    name = 'clears critical members',
                    desc = 'clears members who must be ready',
                    set  = 'ClearCritical',
                },
            },
        },
    },
}
options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(db)
LibStub("AceConfig-3.0"):RegisterOptionsTable("rrl", options, {"rrl"})

-- init
function RRL:OnInitialize()
    RRL:Print("initializing")
    -- load saved variables
    self.db = LibStub("AceDB-3.0"):New("RRLDB")
end

-- enable
function RRL:OnEnable()
    RRL:Print("enabling")
    -- register our events
    RRL:Print("registering event RRL_SEND_UPDATE")
    RRL:RegisterEvent("RRL_SEND_UPDATE")
    RRL:Print("registering event RRL_PROCESS_UPDATE")
    RRL:RegisterEvent("RRL_PROCESS_UPDATE")
    -- register to receive addon messages
    RRL:Print("registering to receive RRL1 prefix addon messages")
    RRL:RegisterComm("RRL1")
    -- start firing RRL_SEND_UPDATE every x seconds
    RRL:Print("starting event timer")
    timer = self:ScheduleRepeatingTimer('RRL_SEND_UPDATE', self.db.profile.updateinterval)
end

-- disable
function RRL:OnDisable()
    RRL:Print("disabling")
    self:CancelTimer(timer, true)
end

-- process a received addon message
function RRL:OnCommReceived(prefix, message, distribution, sender)
    -- process the incoming message
    RRL:Print("received msg = '", message, "' from '", sender, "'");
    local update = { sender, message }
    self:ScheduleTimer('RRL_PROCESS_UPDATE', 0, update)
end

-- process a RRL_SEND_UPDATE event
function RRL:RRL_SEND_UPDATE()
    RRL:Print("processing RRL_SEND_UPDATE event")
end

-- process a RRL_PROCESS_UPDATE event
function RRL:RRL_PROCESS_UPDATE(update)
    local sender = update.0
    local message = update.1
    RRL:Print("processing RRL_PROCESS_UPDATE event")
end

-- get the max number of not ready members
function RRL:GetMax()
    RRL:Print("GetMax called")
    return self.db.profile.maxnotready
end

-- set the max number of not ready members
function RRL:SetMax(max)
    RRL:Print("SetMax called")
    self.db.profile.maxnotready = max
end

-- get the update interval
function RRL:GetInterval()
    RRL:Print("GetInterval called")
    return self.db.profile.updateinterval
end

-- set the update interval
function RRL:SetInterval(interval)
    RRL:Print("SetInterval called")
    self.db.profile.updateinterval = interval 
end

-- lists critical members
function RRL:ListCritical()
    RRL:Print("ListCritical called")
    --- XXX list members
end

-- clears critical members
function RRL:ClearCritical()
    RRL:Print("ClearCritical called")
    --- XXX clear members
end

-- adds a critical member
function RRL:AddCritical(member)
    RRL:Print("AddCritical called")
    --- XXX add member
end

-- deletes a critical member
function RRL:DelCritical(member)
    RRL:Print("DelCritical called")
    --- XXX delete member
end

-- sets yourself as ready
function RRL::SetReady()
    RRL::Print("SetReady called");
    ready = true
end

-- sets yourself as ready
function RRL::SetNotReady()
    RRL::Print("SetNotReady called");
    ready = false
end

--
-- EOF

