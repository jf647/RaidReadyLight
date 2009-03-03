--
-- $Id$
--

local f
local t
local ismoving = false

function RRL:CreateMinion()
    f = CreateFrame("Button", nil, UIParent)
    t = f:CreateTexture(nil, "ARTWORK")
    f:SetFrameStrata("LOW")
    f:SetHeight(128)
    f:SetWidth(64)
    f:SetScale(self.db.minionscale)
    t:SetTexture("Interface\\Addons\\RRL\\Images\\trafficlight_red.tga")
    t:SetAllPoints(f)
    f.texture = t
    if self.db.statusframex then
        f:SetPoint('BOTTOMLEFT', self.db.statusframex, self.db.statusframey)
    else
        f:SetPoint('CENTER', -100, 0)
        self.db.statusframex, self.db.statusframey = f:GetCenter()
    end
    f:SetScript('OnDragStart', function() RRL.Minion_OnDragStart() end)
    f:SetScript('OnDragStop', function() RRL.Minion_OnDragStop() end)
    f:SetScript('OnClick', RRL.Minion_OnClick)
    f:SetScript('OnEnter', function(frame) self:Debug('frame is',frame) self:Debug('f is',f) RRL.DisplayTooltip(f) end)
    f:SetScript('OnLeave', function(frame) RRL.DestroyTooltip(f) end)
    f:RegisterForDrag("LeftButton")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:Show()
    RRL.minion = f
end

function RRL:UpdateMinion()
    if 1 == self.state.inraid then
        if 1 == self.state.ready.self then
            if 1 == self.state.ready.raid then
                t:SetTexture("Interface\\Addons\\RRL\\Images\\trafficlight_green.tga")
            else
                t:SetTexture("Interface\\Addons\\RRL\\Images\\trafficlight_red.tga")
            end
        else
            if 1 == self.state.ready.raid then
                t:SetTexture("Interface\\Addons\\RRL\\Images\\trafficlight_yellow.tga")
            else
                t:SetTexture("Interface\\Addons\\RRL\\Images\\trafficlight_red.tga")
            end
        end
    end
end

function RRL:DestroyMinion()
    f:Hide()
    f = nil
end

function RRL:Minion_OnDragStart()
    if IsAltKeyDown() then
        ismoving = true
        f:StartMoving()
    end
end

function RRL:Minion_OnDragStop()
    if ismoving then
        f:StopMovingOrSizing()
        ismoving = false
        RRL.db.statusframex, RRL.db.statusframey = f:GetCenter()
    end
end

function RRL:Minion_OnClick(_, which)
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

--
-- EOF