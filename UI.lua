-- UI.lua
-- Popup frame with side-by-side item comparison

LootRoller.UI = {}

local activePopups = {}
local MAX_STACKED_POPUPS = 4

local COLOR_BETTER = {0.1, 1, 0.1}
local COLOR_WORSE = {1, 0.1, 0.1}
local COLOR_NEUTRAL = {1, 1, 1}
local COLOR_HEADER = {1, 0.82, 0}

local QUALITY_COLORS = {
    [0] = {0.6, 0.6, 0.6},
    [1] = {1, 1, 1},
    [2] = {0.12, 1, 0},
    [3] = {0, 0.44, 0.87},
    [4] = {0.64, 0.21, 0.93},
    [5] = {1, 0.5, 0},
}

-- Stat patterns for line classification (matches Comparison.lua)
local STAT_PATTERNS = {
    {pattern = "%+(%d+) Strength", stat = "Strength"},
    {pattern = "%+(%d+) Agility", stat = "Agility"},
    {pattern = "%+(%d+) Stamina", stat = "Stamina"},
    {pattern = "%+(%d+) Intellect", stat = "Intellect"},
    {pattern = "%+(%d+) Spirit", stat = "Spirit"},
    {pattern = "%+(%d+) Attack Power", stat = "Attack Power"},
    {pattern = "%+(%d+) Spell Damage", stat = "Spell Damage"},
    {pattern = "Increases damage and healing done by magical spells and effects by up to (%d+)", stat = "Spell Power"},
    {pattern = "%+(%d+) Healing Spells", stat = "Healing"},
    {pattern = "Increases healing done by spells and effects by up to (%d+)", stat = "Healing"},
    {pattern = "%+(%d+)%% Critical Strike", stat = "Crit"},
    {pattern = "Improves your chance to get a critical strike by (%d+)%%", stat = "Crit"},
    {pattern = "Improves your chance to hit by (%d+)%%", stat = "Hit"},
    {pattern = "%+(%d+) Defense", stat = "Defense"},
    {pattern = "Increased Defense %+(%d+)", stat = "Defense"},
    {pattern = "%+(%d+) Fire Resistance", stat = "Fire Resist"},
    {pattern = "%+(%d+) Nature Resistance", stat = "Nature Resist"},
    {pattern = "%+(%d+) Frost Resistance", stat = "Frost Resist"},
    {pattern = "%+(%d+) Shadow Resistance", stat = "Shadow Resist"},
    {pattern = "%+(%d+) Arcane Resistance", stat = "Arcane Resist"},
    {pattern = "(%d+) Armor", stat = "Armor"},
}

-- Classify a tooltip line: identify stat type and value if applicable
local function ClassifyLine(lineData)
    local text = lineData.text or ""
    for _, patternInfo in ipairs(STAT_PATTERNS) do
        local _, _, value = string.find(text, patternInfo.pattern)
        if value then
            return {
                text = text,
                rightText = lineData.rightText,
                r = lineData.r,
                g = lineData.g,
                b = lineData.b,
                statType = patternInfo.stat,
                value = tonumber(value)
            }
        end
    end
    -- Non-stat line
    return {
        text = text,
        rightText = lineData.rightText,
        r = lineData.r,
        g = lineData.g,
        b = lineData.b,
        statType = nil,
        value = nil
    }
end

-- Align two tooltip line lists by stat type, inserting blanks as needed
local function AlignTooltipLines(leftLines, rightLines)
    local result = {}
    local leftClassified = {}
    local rightClassified = {}

    -- Classify all lines
    for _, line in ipairs(leftLines) do
        table.insert(leftClassified, ClassifyLine(line))
    end
    for _, line in ipairs(rightLines) do
        table.insert(rightClassified, ClassifyLine(line))
    end

    -- Track which right lines have been matched
    local rightUsed = {}

    -- Process left lines, finding matches in right
    for i, leftLine in ipairs(leftClassified) do
        local matched = false
        if leftLine.statType then
            -- Look for matching stat in right (unused)
            for j, rightLine in ipairs(rightClassified) do
                if not rightUsed[j] and rightLine.statType == leftLine.statType then
                    table.insert(result, {left = leftLine, right = rightLine})
                    rightUsed[j] = true
                    matched = true
                    break
                end
            end
            if not matched then
                -- Left has stat, right doesn't
                table.insert(result, {left = leftLine, right = nil})
            end
        else
            -- Non-stat line: pair with corresponding position if exists and not a stat
            local rightLine = rightClassified[i]
            if rightLine and not rightLine.statType and not rightUsed[i] then
                table.insert(result, {left = leftLine, right = rightLine})
                rightUsed[i] = true
            else
                table.insert(result, {left = leftLine, right = nil})
            end
        end
    end

    -- Add any unmatched right lines
    for j, rightLine in ipairs(rightClassified) do
        if not rightUsed[j] then
            table.insert(result, {left = nil, right = rightLine})
        end
    end

    return result
end

local scanTooltip = CreateFrame("GameTooltip", "LootRollerScanTooltip2", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function GetItemId(itemLink)
    if not itemLink then return nil end
    local _, _, id = string.find(itemLink, "item:(%d+)")
    return id and tonumber(id) or nil
end

local function ExtractHyperlink(itemLink)
    if not itemLink then return nil end
    local _, _, hyperlink = string.find(itemLink, "|H(item:%d+[^|]*)|h")
    return hyperlink or itemLink
end

local function GetTooltipLines(itemLink)
    if not itemLink then return {} end
    local hyperlink = ExtractHyperlink(itemLink)
    if not hyperlink then return {} end
    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(hyperlink)
    local lines = {}
    local numLines = scanTooltip:NumLines()
    for i = 1, numLines do
        local leftText = getglobal("LootRollerScanTooltip2TextLeft" .. i)
        local rightText = getglobal("LootRollerScanTooltip2TextRight" .. i)
        local left = leftText and leftText:GetText() or ""
        local right = rightText and rightText:GetText() or ""
        local r, g, b = 1, 1, 1
        if leftText then r, g, b = leftText:GetTextColor() end
        if left and left ~= "" then
            table.insert(lines, {text = left, rightText = right, r = r, g = g, b = b})
        end
    end
    return lines
end

local function ParseStatValue(text)
    if not text then return nil end
    local _, _, value = string.find(text, "%+(%d+)")
    if value then return tonumber(value) end
    local _, _, value2 = string.find(text, "(%d+)%%")
    if value2 then return tonumber(value2) end
    local _, _, value3 = string.find(text, "by (%d+)")
    if value3 then return tonumber(value3) end
    return nil
end

local function CompareStatLines(line1, line2)
    local val1 = ParseStatValue(line1 or "")
    local val2 = ParseStatValue(line2 or "")
    if val1 and val2 then
        if val1 > val2 then return COLOR_BETTER, COLOR_WORSE
        elseif val1 < val2 then return COLOR_WORSE, COLOR_BETTER end
    end
    return COLOR_NEUTRAL, COLOR_NEUTRAL
end

function LootRoller.UI:CreatePopupFrame()
    local frame = CreateFrame("Frame", "LootRollerPopup" .. (table.getn(activePopups) + 1), UIParent)
    frame:SetWidth(520)
    frame:SetHeight(380)
    frame:SetPoint("CENTER", 0, 100)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\DialogFrame\UI-DialogBox-Background",
        edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        LootRoller.UI:SaveFramePosition(this)
    end)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() LootRoller.UI:HidePopup(frame) end)

    local leftHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftHeader:SetPoint("TOPLEFT", 20, -15)
    leftHeader:SetText("Rolling For")
    leftHeader:SetTextColor(COLOR_HEADER[1], COLOR_HEADER[2], COLOR_HEADER[3])

    local rightHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightHeader:SetPoint("TOPRIGHT", -40, -15)
    rightHeader:SetText("Currently Equipped")
    rightHeader:SetTextColor(COLOR_HEADER[1], COLOR_HEADER[2], COLOR_HEADER[3])

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(1, 1, 1, 0.3)
    divider:SetWidth(2)
    divider:SetHeight(300)
    divider:SetPoint("TOP", 0, -35)
    frame.divider = divider

    local leftIcon = frame:CreateTexture(nil, "ARTWORK")
    leftIcon:SetWidth(37)
    leftIcon:SetHeight(37)
    leftIcon:SetPoint("TOPLEFT", 20, -35)
    frame.leftIcon = leftIcon

    local leftName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftName:SetPoint("TOPLEFT", leftIcon, "TOPRIGHT", 8, -2)
    leftName:SetWidth(180)
    leftName:SetJustifyH("LEFT")
    frame.leftName = leftName

    local rightIcon = frame:CreateTexture(nil, "ARTWORK")
    rightIcon:SetWidth(37)
    rightIcon:SetHeight(37)
    rightIcon:SetPoint("TOPLEFT", divider, "TOPRIGHT", 15, 0)
    frame.rightIcon = rightIcon

    local rightName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightName:SetPoint("TOPLEFT", rightIcon, "TOPRIGHT", 8, -2)
    rightName:SetWidth(180)
    rightName:SetJustifyH("LEFT")
    frame.rightName = rightName

    local leftStats = CreateFrame("Frame", nil, frame)
    leftStats:SetPoint("TOPLEFT", 20, -80)
    leftStats:SetWidth(230)
    leftStats:SetHeight(250)
    frame.leftStats = leftStats

    local rightStats = CreateFrame("Frame", nil, frame)
    rightStats:SetPoint("TOPLEFT", divider, "TOPRIGHT", 15, -45)
    rightStats:SetWidth(230)
    rightStats:SetHeight(250)
    frame.rightStats = rightStats

    local buttonFrame = CreateFrame("Frame", nil, frame)
    buttonFrame:SetPoint("BOTTOMLEFT", 15, 15)
    buttonFrame:SetPoint("BOTTOMRIGHT", -15, 15)
    buttonFrame:SetHeight(30)

    local msBtn = self:CreateRollButton(buttonFrame, "MS", function() LootRoller.UI:DoRoll(frame, "ms") end)
    msBtn:SetPoint("LEFT", 50, 0)
    frame.msBtn = msBtn

    local osBtn = self:CreateRollButton(buttonFrame, "OS", function() LootRoller.UI:DoRoll(frame, "os") end)
    osBtn:SetPoint("CENTER", 0, 0)
    frame.osBtn = osBtn

    local tmogBtn = self:CreateRollButton(buttonFrame, "TMOG", function() LootRoller.UI:DoRoll(frame, "tmog") end)
    tmogBtn:SetPoint("RIGHT", -50, 0)
    frame.tmogBtn = tmogBtn

    frame.leftLines = {}
    frame.rightLines = {}
    frame:Hide()
    return frame
end

function LootRoller.UI:CreateRollButton(parent, text, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetWidth(80)
    btn:SetHeight(25)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

function LootRoller.UI:ClearStatLines(frame)
    for _, line in ipairs(frame.leftLines or {}) do line:Hide() end
    for _, line in ipairs(frame.rightLines or {}) do line:Hide() end
    frame.leftLines = {}
    frame.rightLines = {}
end

function LootRoller.UI:AddStatLine(container, lines, text, yOffset, color)
    local line = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line:SetPoint("TOPLEFT", 0, yOffset)
    line:SetWidth(220)
    line:SetJustifyH("LEFT")
    line:SetText(text)
    if color then line:SetTextColor(color[1], color[2], color[3]) end
    table.insert(lines, line)
    return line
end

function LootRoller.UI:DisplayItemComparison(popup, newItemLink, equippedItemLink)
    self:ClearStatLines(popup)
    local newId = GetItemId(newItemLink)
    local newName, _, newQuality, _, _, _, _, _, _, newTexture
    if newId then newName, _, newQuality, _, _, _, _, _, _, newTexture = GetItemInfo(newId) end

    local eqId = GetItemId(equippedItemLink)
    local eqName, _, eqQuality, _, _, _, _, _, _, eqTexture
    if eqId then eqName, _, eqQuality, _, _, _, _, _, _, eqTexture = GetItemInfo(eqId) end

    if newTexture then popup.leftIcon:SetTexture(newTexture); popup.leftIcon:Show()
    else popup.leftIcon:Hide() end
    popup.leftName:SetText(newName or "Unknown Item")
    local newQC = QUALITY_COLORS[newQuality or 1] or QUALITY_COLORS[1]
    popup.leftName:SetTextColor(newQC[1], newQC[2], newQC[3])

    if eqTexture then popup.rightIcon:SetTexture(eqTexture); popup.rightIcon:Show()
    else popup.rightIcon:Hide() end
    if equippedItemLink then
        popup.rightName:SetText(eqName or "Unknown")
        local eqQC = QUALITY_COLORS[eqQuality or 1] or QUALITY_COLORS[1]
        popup.rightName:SetTextColor(eqQC[1], eqQC[2], eqQC[3])
    else
        popup.rightName:SetText("(Empty Slot)")
        popup.rightName:SetTextColor(0.5, 0.5, 0.5)
    end

    local newLines = GetTooltipLines(newItemLink)
    local eqLines = GetTooltipLines(equippedItemLink)

    local yOffset = 0
    for i = 2, table.getn(newLines) do
        local lineData = newLines[i]
        local text = lineData.text
        if lineData.rightText and lineData.rightText ~= "" then text = text .. "  " .. lineData.rightText end
        local color = {lineData.r, lineData.g, lineData.b}
        local eqLine = eqLines[i]
        if eqLine then
            local c1, c2 = CompareStatLines(lineData.text, eqLine.text)
            color = c1
        elseif ParseStatValue(lineData.text) then
            color = COLOR_BETTER
        end
        self:AddStatLine(popup.leftStats, popup.leftLines, text, yOffset, color)
        yOffset = yOffset - 13
    end

    yOffset = 0
    for i = 2, table.getn(eqLines) do
        local lineData = eqLines[i]
        local text = lineData.text
        if lineData.rightText and lineData.rightText ~= "" then text = text .. "  " .. lineData.rightText end
        local color = {lineData.r, lineData.g, lineData.b}
        local newLine = newLines[i]
        if newLine then
            local c1, c2 = CompareStatLines(newLine.text, lineData.text)
            color = c2
        elseif ParseStatValue(lineData.text) then
            color = COLOR_BETTER
        end
        self:AddStatLine(popup.rightStats, popup.rightLines, text, yOffset, color)
        yOffset = yOffset - 13
    end
end

function LootRoller.UI:SaveFramePosition(frame)
    local point, _, _, x, y = frame:GetPoint()
    LootRoller.Settings:Set("framePosition", {point = point, x = x, y = y})
end

function LootRoller.UI:RestoreFramePosition(frame)
    local pos = LootRoller.Settings:Get("framePosition")
    if pos then frame:ClearAllPoints(); frame:SetPoint(pos.point, pos.x, pos.y) end
end

function LootRoller.UI:ShowItem(itemLink)
    if not LootRoller.Settings:Get("enabled") then return end
    local itemId = GetItemId(itemLink)
    if not itemId then LootRoller:Print("Could not parse item link"); return end
    local name = GetItemInfo(itemId)
    if not name then
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
    local equippedLink = nil
    local slots = LootRoller.Comparison:GetSlotsForItem(itemLink)
    if slots and slots[1] then equippedLink = GetInventoryItemLink("player", slots[1]) end
    local mode = LootRoller.Settings:Get("multiItemMode")
    local popup
    if mode == "replace" then
        for _, p in ipairs(activePopups) do p:Hide() end
        activePopups = {}
        popup = self:GetOrCreatePopup()
    else
        if table.getn(activePopups) >= MAX_STACKED_POPUPS then
            local oldest = table.remove(activePopups, 1)
            oldest:Hide()
        end
        popup = self:GetOrCreatePopup()
    end
    popup.itemLink = itemLink
    self:DisplayItemComparison(popup, itemLink, equippedLink)
    self:PositionPopup(popup)
    if table.getn(activePopups) == 0 then self:RestoreFramePosition(popup) end
    table.insert(activePopups, popup)
    popup:Show()
    if LootRoller.Settings:Get("soundEnabled") then PlaySound("igMainMenuOpen") end
    local timeout = LootRoller.Settings:Get("autoHideTimeout")
    if timeout and timeout > 0 then self:StartAutoHideTimer(popup, timeout) end
end

function LootRoller.UI:GetOrCreatePopup()
    for _, popup in ipairs(activePopups) do
        if not popup:IsShown() then return popup end
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

function LootRoller.UI:StartAutoHideTimer(popup, seconds)
    if popup.autoHideTimer then popup.autoHideTimer:SetScript("OnUpdate", nil) end
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
    for i, p in ipairs(activePopups) do
        if p == popup then table.remove(activePopups, i); break end
    end
    if popup.autoHideTimer then popup.autoHideTimer:SetScript("OnUpdate", nil); popup.autoHideTimer = nil end
end

function LootRoller.UI:HideAllPopups()
    for _, popup in ipairs(activePopups) do
        popup:Hide()
        if popup.autoHideTimer then popup.autoHideTimer:SetScript("OnUpdate", nil) end
    end
    activePopups = {}
end

function LootRoller.UI:DoRoll(popup, rollType)
    local rollValue
    if rollType == "ms" then rollValue = LootRoller.Settings:Get("msRoll")
    elseif rollType == "os" then rollValue = LootRoller.Settings:Get("osRoll")
    elseif rollType == "tmog" then rollValue = LootRoller.Settings:Get("tmogRoll") end
    if rollValue then RandomRoll(1, rollValue) end
    self:HidePopup(popup)
end

function LootRoller.UI:ShowTestItem()
    if not LootRoller.Settings:Get("enabled") then LootRoller:Print("Addon disabled"); return end
    local testLink = nil
    local slots = {"HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
        "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
        "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
        "MainHandSlot", "SecondaryHandSlot", "RangedSlot"}
    for _, slotName in ipairs(slots) do
        local slotId = GetInventorySlotInfo(slotName)
        if slotId then
            local link = GetInventoryItemLink("player", slotId)
            if link then testLink = link; break end
        end
    end
    if not testLink then
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                local link = GetContainerItemLink(bag, slot)
                if link then testLink = link; break end
            end
            if testLink then break end
        end
    end
    if not testLink then LootRoller:Print("No items found to test with"); return end
    LootRoller:Print("Testing with: " .. testLink)
    self:ShowItem(testLink)
end
