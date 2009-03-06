--
-- $Id$
--

local mf
local ys
local yst
local tl
local tlt
local ismoving = false

function RRL:CreateMinion()

    -- the main containing frame
    mf = CreateFrame("Button", nil, UIParent)
    mf:Hide()
    mf:SetFrameStrata("LOW")
    mf:SetHeight(68)
    mf:SetWidth(46)
    mf:SetScale(self.db.minionscale)
    if self.db.statusframex then
        mf:SetPoint('BOTTOMLEFT', self.db.statusframex, self.db.statusframey)
    else
        mf:SetPoint('CENTER', -100, 0)
        self.db.statusframex, self.db.statusframey = f:GetCenter()
    end

    -- your state icon
    ys = CreateFrame("Frame", nil, mf)
    ys:SetHeight(8)
    ys:SetWidth(8)
    ys:SetPoint('TOPLEFT', mf, 'TOPLEFT', 2, -2)
    yst = ys:CreateTexture(nil, "ARTWORK")
    yst:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Waiting.png")
    ys.texture = yst
    
    -- traffic light and texture
    tl = CreateFrame("Frame", nil, mf)
    tl:SetHeight(64)
    tl:SetWidth(32)
    tl:SetPoint('TOPRIGHT', mf, 'TOPRIGHT', -2, -2)
    tlt = tl:CreateTexture(nil, "ARTWORK")   
    tlt:SetTexture("Interface\\Addons\\RRL\\Images\\rrl_trafficlight_red_low_green_low.tga")
    tl.texture = tlt
    
    -- frame event handlers
    mf:SetScript("OnDragStart", RRL.Minion_OnDragStart)
    mf:SetScript("OnDragStop", RRL.Minion_OnDragStop)
    mf:SetScript("OnClick", RRL.ldb_obj.OnClick)
    mf:SetScript("OnLeave", RRL.ldb_obj.OnLeave)
    mf:SetScript("OnEnter", RRL.ldb_obj.OnEnter)    
    mf:RegisterForDrag("LeftButton")
    mf:SetMovable(true)
    mf:SetClampedToScreen(true)
    mf:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- show the minion
    mf:Show()
    RRL.minion = mf
end

function RRL:UpdateMinion()
    if 1 == self.state.inraid then
        if 1 == self.state.ready.self then
            yst:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready.png")
        else
            yst:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady.png")
        end
        if 1 == self.state.ready.raid then
            tlt:SetTexture("Interface\\Addons\\RRL\\Images\\rrl_trafficlight_red_low_green_high.tga")
        else
            tlt:SetTexture("Interface\\Addons\\RRL\\Images\\rrl_trafficlight_red_high_green_low.tga")
        end
    else
        yst:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Waiting.png")
        tlt:SetTexture("Interface\\Addons\\RRL\\Images\\rrl_trafficlight_red_low_green_low.tga")
    end
end

function RRL:DestroyMinion()
    mf:Hide()
    tlt = nil
    tl = nil
    yst = nil
    ys = nil
    mf = nil
    RRL.minion = nil
end

function RRL.Minion_OnDragStart(frame)
    if IsAltKeyDown() then
        ismoving = true
        RRL.ldb_obj.OnLeave(frame)
        frame:StartMoving()
    end
end

function RRL.Minion_OnDragStop(frame)
    if ismoving then
        frame:StopMovingOrSizing()
        ismoving = false
        RRL.db.statusframex, RRL.db.statusframey = frame:GetCenter()
        RRL.ldb_obj.OnEnter(frame)
    end
end

--
-- EOF