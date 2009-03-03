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
    f:SetScript("OnDragStart", function(frame)
        if IsAltKeyDown() then
            ismoving = true
            frame:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(frame)
        if ismoving then
            frame:StopMovingOrSizing()
            ismoving = false
            RRL.db.statusframex, RRL.db.statusframey = frame:GetCenter()
        end
    end)
    f:SetScript('OnClick', function(_, which)
        if "LeftButton" == which then
            self:ToggleReady()
        elseif "RightButton" == which then
            DoReadyCheck()
        end
    end)
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

--
-- EOF