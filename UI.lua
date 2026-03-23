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

    self:UpdateButtonTooltips(frame)

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

function LootRoller.UI:ShowItem(itemLink)
    if not LootRoller.Settings:Get("enabled") then return end

    local itemString = LootRoller:ItemStringFromLink(itemLink)
    if not itemString then
        LootRoller:Debug("ShowItem: could not extract item string from link")
        return
    end

    -- TurtleWoW GetItemInfo returns: name, link, quality, minLevel, type, subType, stackCount, equipLoc, texture
    local name, link, quality, _, itemType, itemSubType, _, equipLoc, texture = GetItemInfo(itemString)

    -- Handle item not cached
    if not name then
        LootRoller:Debug("Item not cached, retrying...")
        -- Retry after short delay
        local retryFrame = CreateFrame("Frame")
        retryFrame.elapsed = 0
        retryFrame.itemLink = itemLink
        retryFrame:SetScript("OnUpdate", function()
            this.elapsed = this.elapsed + arg1
            if this.elapsed > 1.5 then
                LootRoller.UI:ShowItem(this.itemLink)
                this:SetScript("OnUpdate", nil)
            end
        end)
        return
    end

    -- Handle multi-item mode
    local mode = LootRoller.Settings:Get("multiItemMode")
    local popup

    if mode == "replace" then
        -- Close existing popups
        for _, p in ipairs(activePopups) do
            p:Hide()
        end
        activePopups = {}
        popup = self:GetOrCreatePopup()
    else -- stack
        if table.getn(activePopups) >= MAX_STACKED_POPUPS then
            -- Remove oldest
            local oldest = table.remove(activePopups, 1)
            oldest:Hide()
        end
        popup = self:GetOrCreatePopup()
    end

    -- Store item data on frame
    popup.itemLink = itemLink
    popup.itemName:SetText(name)

    -- Set quality color
    local qc = QUALITY_COLORS[quality] or QUALITY_COLORS[1]
    popup.itemName:SetTextColor(qc[1], qc[2], qc[3])

    -- Set icon
    popup.icon:SetTexture(texture)

    -- Set subtext
    popup.itemSubtext:SetText((itemType or "") .. " - " .. (itemSubType or ""))

    -- Calculate and display stat comparisons
    local comparisons = LootRoller.Comparison:CompareItems(itemLink)
    self:DisplayStats(popup, comparisons)

    -- Position for stacking
    self:PositionPopup(popup)

    -- Restore saved position (only first popup)
    if table.getn(activePopups) == 0 then
        self:RestoreFramePosition(popup)
    end

    table.insert(activePopups, popup)
    popup:Show()

    -- Play sound if enabled
    if LootRoller.Settings:Get("soundEnabled") then
        PlaySound("igMainMenuOpen")
    end

    -- Start auto-hide timer if configured
    local timeout = LootRoller.Settings:Get("autoHideTimeout")
    if timeout and timeout > 0 then
        self:StartAutoHideTimer(popup, timeout)
    end
end

function LootRoller.UI:GetOrCreatePopup()
    -- Reuse hidden popup or create new
    for _, popup in ipairs(activePopups) do
        if not popup:IsShown() then
            return popup
        end
    end
    return self:CreatePopupFrame()
end

function LootRoller.UI:PositionPopup(popup)
    local numActive = table.getn(activePopups)
    if numActive > 0 then
        local lastPopup = activePopups[numActive]
        popup:ClearAllPoints()
        popup:SetPoint("TOP", lastPopup, "BOTTOM", 0, -10)
    end
end

function LootRoller.UI:DisplayStats(popup, comparisons)
    -- Clear existing stat lines
    if popup.statLines then
        for _, line in ipairs(popup.statLines) do
            line:Hide()
        end
    end
    popup.statLines = {}

    local yOffset = 0
    local columnWidth = 130

    for i, comparison in ipairs(comparisons) do
        -- Column header (vs Equipped 1, vs Equipped 2, or vs Empty)
        local headerText
        if comparison.isEmpty then
            headerText = "vs Empty Slot"
        elseif table.getn(comparisons) > 1 then
            headerText = "vs Slot " .. i
        else
            headerText = "vs Equipped"
        end

        local xOffset = (i - 1) * columnWidth

        local header = popup.statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetPoint("TOPLEFT", xOffset, yOffset)
        header:SetText(headerText)
        header:SetTextColor(1, 0.82, 0)
        table.insert(popup.statLines, header)

        yOffset = yOffset - 14

        -- Stat diff lines
        for _, statDiff in ipairs(comparison.diff) do
            local line = popup.statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            line:SetPoint("TOPLEFT", xOffset, yOffset)

            local prefix = statDiff.value > 0 and "+" or ""
            line:SetText(prefix .. statDiff.value .. " " .. statDiff.stat)

            if statDiff.isGain then
                line:SetTextColor(COLOR_GAIN[1], COLOR_GAIN[2], COLOR_GAIN[3])
            else
                line:SetTextColor(COLOR_LOSS[1], COLOR_LOSS[2], COLOR_LOSS[3])
            end

            table.insert(popup.statLines, line)
            yOffset = yOffset - 12
        end

        -- Reset yOffset for next column
        if i < table.getn(comparisons) then
            yOffset = 0
        end
    end

    -- Adjust frame height based on content
    local contentHeight = math.max(80, -yOffset + 20)
    popup:SetHeight(contentHeight + 110)  -- add space for header and buttons
end

function LootRoller.UI:StartAutoHideTimer(popup, seconds)
    if popup.autoHideTimer then
        popup.autoHideTimer:SetScript("OnUpdate", nil)
    end

    local timer = CreateFrame("Frame")
    timer.elapsed = 0
    timer.duration = seconds
    timer.popup = popup
    timer:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= this.duration then
            LootRoller.UI:HidePopup(this.popup)
            this:SetScript("OnUpdate", nil)
        end
    end)
    popup.autoHideTimer = timer
end

function LootRoller.UI:HidePopup(popup)
    popup:Hide()

    -- Remove from active list
    for i, p in ipairs(activePopups) do
        if p == popup then
            table.remove(activePopups, i)
            break
        end
    end

    -- Cancel auto-hide timer
    if popup.autoHideTimer then
        popup.autoHideTimer:SetScript("OnUpdate", nil)
        popup.autoHideTimer = nil
    end
end

function LootRoller.UI:HideAllPopups()
    for _, popup in ipairs(activePopups) do
        popup:Hide()
        if popup.autoHideTimer then
            popup.autoHideTimer:SetScript("OnUpdate", nil)
        end
    end
    activePopups = {}
end

function LootRoller.UI:DoRoll(popup, rollType)
    local rollValue

    if rollType == "ms" then
        rollValue = LootRoller.Settings:Get("msRoll")
    elseif rollType == "os" then
        rollValue = LootRoller.Settings:Get("osRoll")
    elseif rollType == "tmog" then
        rollValue = LootRoller.Settings:Get("tmogRoll")
    end

    if rollValue then
        RandomRoll(1, rollValue)
        LootRoller:Debug("Rolling 1-" .. rollValue .. " for " .. rollType)
    end

    -- Hide popup after rolling
    self:HidePopup(popup)
end

-- Update button tooltips with current roll values
function LootRoller.UI:UpdateButtonTooltips(popup)
    local function SetTooltip(btn, rollType, rollValue)
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(rollType .. " Roll")
            GameTooltip:AddLine("Roll 1-" .. rollValue, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    SetTooltip(popup.msBtn, "Main Spec", LootRoller.Settings:Get("msRoll"))
    SetTooltip(popup.osBtn, "Off Spec", LootRoller.Settings:Get("osRoll"))
    SetTooltip(popup.tmogBtn, "Transmog", LootRoller.Settings:Get("tmogRoll"))
end
