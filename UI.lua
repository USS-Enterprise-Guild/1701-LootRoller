-- UI.lua
-- Popup frame and display

LootRoller.UI = {}

local activePopups = {}  -- track active popups
local MAX_STACKED_POPUPS = 4

-- Colors
local COLOR_GAIN = {0, 1, 0}      -- green
local COLOR_LOSS = {1, 0, 0}      -- red
local COLOR_NEUTRAL = {0.5, 0.5, 0.5}  -- gray

-- Quality colors (same as WoW item quality)
local QUALITY_COLORS = {
    [0] = {0.6, 0.6, 0.6},  -- Poor (gray)
    [1] = {1, 1, 1},        -- Common (white)
    [2] = {0.12, 1, 0},     -- Uncommon (green)
    [3] = {0, 0.44, 0.87},  -- Rare (blue)
    [4] = {0.64, 0.21, 0.93}, -- Epic (purple)
    [5] = {1, 0.5, 0},      -- Legendary (orange)
}

function LootRoller.UI:CreatePopupFrame()
    local frame = CreateFrame("Frame", "LootRollerPopup" .. (table.getn(activePopups) + 1), UIParent)
    frame:SetWidth(280)
    frame:SetHeight(200)
    frame:SetPoint("CENTER", 0, 100)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)

    -- Background
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })

    -- Make draggable
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        LootRoller.UI:SaveFramePosition(this)
    end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        LootRoller.UI:HidePopup(frame)
    end)

    -- Item icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(37)
    icon:SetHeight(37)
    icon:SetPoint("TOPLEFT", 15, -15)
    frame.icon = icon

    -- Item name
    local itemName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    itemName:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
    itemName:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
    itemName:SetJustifyH("LEFT")
    frame.itemName = itemName

    -- Item subtext (type/slot)
    local itemSubtext = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemSubtext:SetPoint("TOPLEFT", itemName, "BOTTOMLEFT", 0, -2)
    itemSubtext:SetTextColor(0.7, 0.7, 0.7)
    frame.itemSubtext = itemSubtext

    -- Stat diff container
    local statFrame = CreateFrame("Frame", nil, frame)
    statFrame:SetPoint("TOPLEFT", 15, -65)
    statFrame:SetPoint("TOPRIGHT", -15, -65)
    statFrame:SetHeight(90)
    frame.statFrame = statFrame

    -- Button container
    local buttonFrame = CreateFrame("Frame", nil, frame)
    buttonFrame:SetPoint("BOTTOMLEFT", 15, 15)
    buttonFrame:SetPoint("BOTTOMRIGHT", -15, 15)
    buttonFrame:SetHeight(30)
    frame.buttonFrame = buttonFrame

    -- MS Button
    local msBtn = self:CreateRollButton(buttonFrame, "MS", function()
        LootRoller.UI:DoRoll(frame, "ms")
    end)
    msBtn:SetPoint("LEFT", 0, 0)
    frame.msBtn = msBtn

    -- OS Button
    local osBtn = self:CreateRollButton(buttonFrame, "OS", function()
        LootRoller.UI:DoRoll(frame, "os")
    end)
    osBtn:SetPoint("CENTER", 0, 0)
    frame.osBtn = osBtn

    -- TMOG Button
    local tmogBtn = self:CreateRollButton(buttonFrame, "TMOG", function()
        LootRoller.UI:DoRoll(frame, "tmog")
    end)
    tmogBtn:SetPoint("RIGHT", 0, 0)
    frame.tmogBtn = tmogBtn

    frame:Hide()
    return frame
end

function LootRoller.UI:CreateRollButton(parent, text, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetWidth(75)
    btn:SetHeight(25)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

function LootRoller.UI:SaveFramePosition(frame)
    local point, _, _, x, y = frame:GetPoint()
    LootRoller.Settings:Set("framePosition", {point = point, x = x, y = y})
end

function LootRoller.UI:RestoreFramePosition(frame)
    local pos = LootRoller.Settings:Get("framePosition")
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, pos.x, pos.y)
    end
end
