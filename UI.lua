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
    {pattern = "Improves your chance to get a critical strike with spells by (%d+)%%", stat = "Spell Crit"},
    {pattern = "Improves your chance to hit by (%d+)%%", stat = "Hit"},
    {pattern = "Improves your chance to hit with spells by (%d+)%%", stat = "Spell Hit"},
    {pattern = "%+(%d+) Defense", stat = "Defense"},
    {pattern = "Increased Defense %+(%d+)", stat = "Defense"},
    {pattern = "%+(%d+) Fire Resistance", stat = "Fire Resist"},
    {pattern = "%+(%d+) Nature Resistance", stat = "Nature Resist"},
    {pattern = "%+(%d+) Frost Resistance", stat = "Frost Resist"},
    {pattern = "%+(%d+) Shadow Resistance", stat = "Shadow Resist"},
    {pattern = "%+(%d+) Arcane Resistance", stat = "Arcane Resist"},
    {pattern = "(%d+) Armor", stat = "Armor"},
    {pattern = "Restores (%d+) mana per 5 sec", stat = "MP5"},
    {pattern = "Restores (%d+) health per 5 sec", stat = "HP5"},
}

-- Check if a line is an enchant (green color but NOT other green effects)
local function IsEnchantLine(r, g, b, text)
    if not r or not g or not b then return false end
    -- Must be green colored
    local isGreen = g > 0.9 and r < 0.2 and b < 0.2
    if not isGreen then return false end
    if not text then return false end
    -- Exclude other green effects that aren't enchants
    if string.find(text, "^Equip:") then return false end        -- Equip effects
    if string.find(text, "^Chance on hit:") then return false end -- Proc effects
    if string.find(text, "^Use:") then return false end          -- Use effects
    if string.find(text, "^%(") then return false end            -- Set bonuses like "(2) Set:"
    if string.find(text, "Set:") then return false end           -- Set bonuses
    return true
end

-- Classify a tooltip line: identify stat type and value if applicable
local function ClassifyLine(lineData)
    local text = lineData.text or ""

    -- Check if this is an enchant line (green colored)
    local isEnchant = IsEnchantLine(lineData.r, lineData.g, lineData.b, text)

    for _, patternInfo in ipairs(STAT_PATTERNS) do
        local _, _, value = string.find(text, patternInfo.pattern)
        if value then
            return {
                text = text,
                rightText = lineData.rightText,
                r = lineData.r,
                g = lineData.g,
                b = lineData.b,
                statType = isEnchant and "Enchant" or patternInfo.stat,
                value = tonumber(value),
                isEnchant = isEnchant
            }
        end
    end
    -- Non-stat line (could still be an enchant like "Lifestealing" or "Spell Damage +30")
    -- If it's an enchant, give it statType "Enchant" so it pairs with blank, not other non-stats
    return {
        text = text,
        rightText = lineData.rightText,
        r = lineData.r,
        g = lineData.g,
        b = lineData.b,
        statType = isEnchant and "Enchant" or nil,
        value = nil,
        isEnchant = isEnchant
    }
end

-- Align two tooltip line lists by stat type, inserting blanks as needed
-- Check if a stat type exists in list starting from index
local function HasStatTypeAfter(list, startIndex, statType)
    for i = startIndex, table.getn(list) do
        if list[i].statType == statType then
            return true
        end
    end
    return false
end

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

    -- Walk both lists simultaneously
    local li, ri = 1, 1
    local leftLen = table.getn(leftClassified)
    local rightLen = table.getn(rightClassified)

    while li <= leftLen or ri <= rightLen do
        local leftLine = leftClassified[li]
        local rightLine = rightClassified[ri]

        if not leftLine and not rightLine then
            break
        elseif not leftLine then
            -- Left exhausted, output remaining right
            table.insert(result, {left = nil, right = rightLine})
            ri = ri + 1
        elseif not rightLine then
            -- Right exhausted, output remaining left
            table.insert(result, {left = leftLine, right = nil})
            li = li + 1
        elseif not leftLine.statType and not rightLine.statType then
            -- Both non-stat: pair together, advance both
            table.insert(result, {left = leftLine, right = rightLine})
            li = li + 1
            ri = ri + 1
        elseif leftLine.statType and rightLine.statType and leftLine.statType == rightLine.statType then
            -- Same stat type: pair together, advance both
            table.insert(result, {left = leftLine, right = rightLine})
            li = li + 1
            ri = ri + 1
        elseif leftLine.statType and not rightLine.statType then
            -- Left has stat, right has non-stat
            -- Check if left's stat type exists later in right - if so, save it for matching
            if HasStatTypeAfter(rightClassified, ri + 1, leftLine.statType) then
                table.insert(result, {left = nil, right = rightLine})
                ri = ri + 1
            else
                table.insert(result, {left = leftLine, right = nil})
                li = li + 1
            end
        elseif not leftLine.statType and rightLine.statType then
            -- Left has non-stat, right has stat
            -- Check if right's stat type exists later in left - if so, save it for matching
            if HasStatTypeAfter(leftClassified, li + 1, rightLine.statType) then
                table.insert(result, {left = leftLine, right = nil})
                li = li + 1
            else
                table.insert(result, {left = nil, right = rightLine})
                ri = ri + 1
            end
        else
            -- Both stats but different types
            -- Check if either stat exists on the other side later
            local leftExistsInRight = HasStatTypeAfter(rightClassified, ri + 1, leftLine.statType)
            local rightExistsInLeft = HasStatTypeAfter(leftClassified, li + 1, rightLine.statType)
            if leftExistsInRight and not rightExistsInLeft then
                -- Right's stat won't match, output it
                table.insert(result, {left = nil, right = rightLine})
                ri = ri + 1
            elseif rightExistsInLeft and not leftExistsInRight then
                -- Left's stat won't match, output it
                table.insert(result, {left = leftLine, right = nil})
                li = li + 1
            else
                -- Either both will match later or neither will - output left first
                table.insert(result, {left = leftLine, right = nil})
                li = li + 1
            end
        end
    end

    return result
end

-- Get color for a line based on stat comparison
-- side: "left" (loot item) or "right" (equipped item)
local function GetComparisonColor(leftLine, rightLine, side)
    -- Enchants keep their original color (green) - don't apply comparison coloring
    if side == "left" and leftLine and leftLine.isEnchant then
        return {leftLine.r or 0, leftLine.g or 1, leftLine.b or 0}
    elseif side == "right" and rightLine and rightLine.isEnchant then
        return {rightLine.r or 0, rightLine.g or 1, rightLine.b or 0}
    end

    -- Both have same stat type - compare values
    if leftLine and rightLine and leftLine.statType and rightLine.statType then
        if leftLine.statType == rightLine.statType and leftLine.value and rightLine.value then
            if side == "left" then
                if leftLine.value > rightLine.value then return COLOR_BETTER
                elseif leftLine.value < rightLine.value then return COLOR_WORSE
                else return COLOR_NEUTRAL end
            else -- right side
                if rightLine.value > leftLine.value then return COLOR_BETTER
                elseif rightLine.value < leftLine.value then return COLOR_WORSE
                else return COLOR_NEUTRAL end
            end
        end
    end

    -- Left has stat, right is blank (gaining stat)
    if leftLine and leftLine.statType and not rightLine then
        if side == "left" then return COLOR_BETTER end
    end

    -- Right has stat, left is blank (equipped has stat loot lacks)
    if rightLine and rightLine.statType and not leftLine then
        if side == "right" then return COLOR_BETTER end
    end

    -- Both non-stat lines exist: use neutral color (not original tooltip green)
    if leftLine and rightLine and not leftLine.statType and not rightLine.statType then
        return COLOR_NEUTRAL
    end

    -- Only one side has a line (unmatched): use original tooltip color
    if side == "left" and leftLine then
        return {leftLine.r or 1, leftLine.g or 1, leftLine.b or 1}
    elseif side == "right" and rightLine then
        return {rightLine.r or 1, rightLine.g or 1, rightLine.b or 1}
    end

    return COLOR_NEUTRAL
end

local scanTooltip = CreateFrame("GameTooltip", "LootRollerScanTooltip2", nil, "GameTooltipTemplate")

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
    -- SetOwner must be called before SetHyperlink for tooltip to populate
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
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
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
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
    divider:SetHeight(40)  -- Just for header area now
    divider:SetPoint("TOP", -10, -35)  -- Align with scroll divider (250 vs 260)
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

    -- Scroll frame for stat comparison
    local scrollFrame = CreateFrame("ScrollFrame", frame:GetName() .. "ScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 50)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function()
        local scroll = this:GetVerticalScroll()
        local maxScroll = this:GetVerticalScrollRange()
        local delta = arg1 * 20  -- 20 pixels per scroll tick
        scroll = scroll - delta
        if scroll < 0 then scroll = 0 end
        if scroll > maxScroll then scroll = maxScroll end
        this:SetVerticalScroll(scroll)
    end)
    frame.scrollFrame = scrollFrame

    -- Scroll child (content container)
    -- Note: Use explicit width because GetWidth() returns 0 before anchors resolve
    local scrollChild = CreateFrame("Frame", frame:GetName() .. "ScrollChild", scrollFrame)
    scrollChild:SetWidth(470) -- 520 (frame) - 15 (left) - 35 (right)
    scrollChild:SetHeight(1) -- Will be set dynamically
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild

    -- Left column container
    local leftStats = CreateFrame("Frame", nil, scrollChild)
    leftStats:SetPoint("TOPLEFT", 5, 0)
    leftStats:SetWidth(220)
    leftStats:SetHeight(1)
    frame.leftStats = leftStats

    -- Right column container
    local rightStats = CreateFrame("Frame", nil, scrollChild)
    rightStats:SetPoint("TOPLEFT", 245, 0)
    rightStats:SetWidth(220)
    rightStats:SetHeight(1)
    frame.rightStats = rightStats

    -- Divider in scroll child
    local scrollDivider = scrollChild:CreateTexture(nil, "ARTWORK")
    scrollDivider:SetTexture(1, 1, 1, 0.3)
    scrollDivider:SetWidth(1)
    scrollDivider:SetPoint("TOPLEFT", 235, 0)
    scrollDivider:SetPoint("BOTTOMLEFT", 235, 0)
    frame.scrollDivider = scrollDivider

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

    -- FontString pools for reuse (prevents memory accumulation)
    frame.leftLinesPool = {}
    frame.rightLinesPool = {}
    frame.leftLineCount = 0
    frame.rightLineCount = 0
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
    -- Hide all FontStrings but keep them in pools for reuse
    for _, line in ipairs(frame.leftLinesPool or {}) do
        line:Hide()
        line:SetText("")
    end
    for _, line in ipairs(frame.rightLinesPool or {}) do
        line:Hide()
        line:SetText("")
    end
    -- Reset active line counts
    frame.leftLineCount = 0
    frame.rightLineCount = 0

    -- Reset scroll child height
    if frame.scrollChild then
        frame.scrollChild:SetHeight(1)
    end
end

function LootRoller.UI:AddStatLine(container, pool, count, text, yOffset, color)
    local line
    -- Reuse existing FontString from pool if available
    if pool[count + 1] then
        line = pool[count + 1]
    else
        -- Create new FontString and add to pool
        line = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line:SetWidth(220)
        line:SetJustifyH("LEFT")
        table.insert(pool, line)
    end
    -- Configure the line
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", 0, yOffset)
    line:SetText(text or "")
    if color then line:SetTextColor(color[1], color[2], color[3]) end
    line:Show()
    -- Return actual rendered height (accounts for text wrapping)
    return line:GetHeight()
end

function LootRoller.UI:DisplayItemComparison(popup, newItemLink, equippedItemLink)
    self:ClearStatLines(popup)

    -- Get item info for headers
    local newId = GetItemId(newItemLink)
    local newInfo = newId and LootRoller.Comparison:GetItemInfoTurtle(newId) or {}

    local eqId = GetItemId(equippedItemLink)
    local eqInfo = eqId and LootRoller.Comparison:GetItemInfoTurtle(eqId) or {}

    -- Set icons and names
    if newInfo.texture then popup.leftIcon:SetTexture(newInfo.texture); popup.leftIcon:Show()
    else popup.leftIcon:Hide() end
    popup.leftName:SetText(newInfo.name or "Unknown Item")
    local newQC = QUALITY_COLORS[newInfo.quality or 1] or QUALITY_COLORS[1]
    popup.leftName:SetTextColor(newQC[1], newQC[2], newQC[3])

    if eqInfo.texture then popup.rightIcon:SetTexture(eqInfo.texture); popup.rightIcon:Show()
    else popup.rightIcon:Hide() end
    if equippedItemLink then
        popup.rightName:SetText(eqInfo.name or "Unknown")
        local eqQC = QUALITY_COLORS[eqInfo.quality or 1] or QUALITY_COLORS[1]
        popup.rightName:SetTextColor(eqQC[1], eqQC[2], eqQC[3])
    else
        popup.rightName:SetText("(Empty Slot)")
        popup.rightName:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Get and align tooltip lines
    local newLines = GetTooltipLines(newItemLink)
    local eqLines = GetTooltipLines(equippedItemLink)

    -- Skip first line (item name) for comparison
    local newLinesNoName = {}
    local eqLinesNoName = {}
    for i = 2, table.getn(newLines) do table.insert(newLinesNoName, newLines[i]) end
    for i = 2, table.getn(eqLines) do table.insert(eqLinesNoName, eqLines[i]) end

    local alignedPairs = AlignTooltipLines(newLinesNoName, eqLinesNoName)

    -- Render aligned lines
    local yOffset = 0
    local lineGap = 2  -- Small gap between rows

    for _, pair in ipairs(alignedPairs) do
        local leftLine = pair.left
        local rightLine = pair.right

        -- Left side (new item - never has enchants)
        local leftText = ""
        if leftLine then
            leftText = leftLine.text or ""
            if leftLine.rightText and leftLine.rightText ~= "" then
                leftText = leftText .. "  " .. leftLine.rightText
            end
        end
        local leftColor = GetComparisonColor(leftLine, rightLine, "left")
        local leftHeight = self:AddStatLine(popup.leftStats, popup.leftLinesPool, popup.leftLineCount, leftText, yOffset, leftColor)
        popup.leftLineCount = popup.leftLineCount + 1

        -- Right side
        local rightText = ""
        if rightLine then
            rightText = rightLine.text or ""
            if rightLine.isEnchant then
                rightText = "Enchant: " .. rightText
            end
            if rightLine.rightText and rightLine.rightText ~= "" then
                rightText = rightText .. "  " .. rightLine.rightText
            end
        end
        local rightColor = GetComparisonColor(leftLine, rightLine, "right")
        local rightHeight = self:AddStatLine(popup.rightStats, popup.rightLinesPool, popup.rightLineCount, rightText, yOffset, rightColor)
        popup.rightLineCount = popup.rightLineCount + 1

        -- Use the taller of the two lines for row height
        local rowHeight = math.max(leftHeight or 13, rightHeight or 13)
        yOffset = yOffset - rowHeight - lineGap
    end

    -- Update scroll child height
    local contentHeight = math.abs(yOffset) + 20
    popup.scrollChild:SetHeight(contentHeight)
    popup.leftStats:SetHeight(contentHeight)
    popup.rightStats:SetHeight(contentHeight)
    if popup.scrollDivider then
        popup.scrollDivider:SetHeight(contentHeight)
    end

    -- Update scroll bar range
    local scrollFrame = popup.scrollFrame
    if scrollFrame then
        local scrollBar = getglobal(scrollFrame:GetName() .. "ScrollBar")
        if scrollBar then
            local visibleHeight = scrollFrame:GetHeight()
            local maxScroll = contentHeight - visibleHeight
            if maxScroll < 0 then maxScroll = 0 end
            scrollBar:SetMinMaxValues(0, maxScroll)
            scrollBar:SetValue(0)
        end
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
    if slots and slots[1] then
        equippedLink = GetInventoryItemLink("player", slots[1])
    end
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

-- Sample raid/dungeon items for testing (various slots and qualities)
local TEST_ITEM_IDS = {
    16795,  -- Arcanist Crown (Mage T1 Head)
    16802,  -- Arcanist Leggings (Mage T1 Legs)
    16914,  -- Netherwind Crown (Mage T2 Head)
    16922,  -- Leggings of Transcendence (Priest T2 Legs)
    16963,  -- Helm of Wrath (Warrior T2 Head)
    17102,  -- Cloak of the Shrouded Mists (MC)
    17103,  -- Azuresong Mageblade (MC)
    18814,  -- Choker of the Fire Lord (Ragnaros)
    19375,  -- Mish'undare, Circlet of the Mind Flayer (Nef)
    19377,  -- Prestor's Talisman of Connivery (Nef)
    19379,  -- Neltharion's Tear (Nef)
    21134,  -- Dark Storm Gauntlets (AQ40)
    21126,  -- Death's Sting (AQ40)
    22691,  -- Corrupted Ashbringer (Naxx)
}

function LootRoller.UI:ShowTestItem()
    if not LootRoller.Settings:Get("enabled") then LootRoller:Print("Addon disabled"); return end

    -- Pick a random item from the test list
    local itemId = TEST_ITEM_IDS[math.random(1, table.getn(TEST_ITEM_IDS))]

    -- Check if item is cached
    local name, link = GetItemInfo(itemId)

    if not name then
        -- Item not cached - use tooltip query to force cache request
        LootRoller:Print("Loading item " .. itemId .. " into cache...")
        scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
        scanTooltip:SetHyperlink("item:" .. itemId)

        local retryFrame = CreateFrame("Frame")
        retryFrame.elapsed = 0
        retryFrame.itemId = itemId
        retryFrame.attempts = 0
        retryFrame:SetScript("OnUpdate", function()
            this.elapsed = this.elapsed + arg1
            if this.elapsed > 0.5 then
                this.elapsed = 0
                this.attempts = this.attempts + 1
                -- Try tooltip query again each attempt
                scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
                scanTooltip:SetHyperlink("item:" .. this.itemId)
                local n, l = GetItemInfo(this.itemId)
                if n then
                    LootRoller:Print("Testing with: " .. l)
                    LootRoller.UI:ShowItem(l)
                    this:SetScript("OnUpdate", nil)
                elseif this.attempts > 10 then
                    LootRoller:Print("Failed to load item " .. this.itemId .. " after 5 seconds")
                    this:SetScript("OnUpdate", nil)
                end
            end
        end)
        return
    end

    LootRoller:Print("Testing with: " .. link)
    self:ShowItem(link)
end
