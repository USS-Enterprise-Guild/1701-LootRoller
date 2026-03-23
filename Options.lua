-- Options.lua
-- Settings UI (slash command + Interface panel)

LootRoller.Options = {}

-- Register slash commands
SLASH_LOOTROLLER1 = "/lootroller"
SLASH_LOOTROLLER2 = "/lr"

SlashCmdList["LOOTROLLER"] = function(msg)
    local cmd = string.lower(msg or "")

    if cmd == "" then
        LootRoller.Options:ToggleOptionsPanel()
    elseif cmd == "toggle" then
        local enabled = not LootRoller.Settings:Get("enabled")
        LootRoller.Settings:Set("enabled", enabled)
        LootRoller:Print("Addon " .. (enabled and "enabled" or "disabled"))
    elseif cmd == "test" then
        LootRoller.Options:ShowTestPopup()
    elseif cmd == "debug" then
        local debug = not LootRoller.Settings:Get("debug")
        LootRoller.Settings:Set("debug", debug)
        LootRoller:Print("Debug mode " .. (debug and "enabled" or "disabled"))
    elseif cmd == "reset" then
        LootRoller.Settings:Reset()
        LootRoller:Print("Settings reset to defaults")
    else
        LootRoller:Print("Commands:")
        LootRoller:Print("  /lr - Open settings")
        LootRoller:Print("  /lr toggle - Enable/disable addon")
        LootRoller:Print("  /lr test - Show test popup")
        LootRoller:Print("  /lr debug - Toggle debug mode")
        LootRoller:Print("  /lr reset - Reset to defaults")
    end
end

-- Test items covering various slots and qualities
LootRoller.Options.testItems = {
    "|cffa335ee|Hitem:18816:0:0:0|h[Perdition's Blade]|h|r",       -- Epic dagger (weapon)
    "|cffa335ee|Hitem:16914:0:0:0|h[Netherwind Robes]|h|r",        -- Epic chest (mage)
    "|cffa335ee|Hitem:16922:0:0:0|h[Leggings of Transcendence]|h|r", -- Epic legs (priest)
    "|cffa335ee|Hitem:18564:0:0:0|h[Bindings of the Windseeker]|h|r", -- Epic wrist
    "|cffa335ee|Hitem:17182:0:0:0|h[Sulfuras, Hand of Ragnaros]|h|r", -- Legendary 2H
    "|cffa335ee|Hitem:16961:0:0:0|h[Pauldrons of Might]|h|r",      -- Epic shoulders (warrior)
    "|cffa335ee|Hitem:18203:0:0:0|h[Eskhandar's Right Claw]|h|r",  -- Epic fist weapon
    "|cffa335ee|Hitem:17069:0:0:0|h[Striker's Mark]|h|r",          -- Epic ranged
    "|cffa335ee|Hitem:18821:0:0:0|h[Quick Strike Ring]|h|r",       -- Epic ring
}
LootRoller.Options.testIndex = 0

function LootRoller.Options:ShowTestPopup()
    self.testIndex = self.testIndex + 1
    if self.testIndex > table.getn(self.testItems) then
        self.testIndex = 1
    end

    local testLink = self.testItems[self.testIndex]
    LootRoller:Print("Showing test popup...")
    LootRoller.UI:ShowItem(testLink)
end

local optionsPanel = nil

function LootRoller.Options:CreateOptionsPanel()
    if optionsPanel then return optionsPanel end

    local panel = CreateFrame("Frame", "LootRollerOptionsPanel", UIParent)
    panel:SetWidth(350)
    panel:SetHeight(400)
    panel:SetPoint("CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)

    -- Background
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })

    -- Make draggable
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function() this:StartMoving() end)
    panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("LootRoller Settings")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    local yOffset = -50

    -- Enable checkbox
    local enableCB = self:CreateCheckbox(panel, "Enable LootRoller", 20, yOffset,
        function() return LootRoller.Settings:Get("enabled") end,
        function(value) LootRoller.Settings:Set("enabled", value) end
    )
    yOffset = yOffset - 30

    -- Sound checkbox
    local soundCB = self:CreateCheckbox(panel, "Play sound on item announce", 20, yOffset,
        function() return LootRoller.Settings:Get("soundEnabled") end,
        function(value) LootRoller.Settings:Set("soundEnabled", value) end
    )
    yOffset = yOffset - 40

    -- Roll values section
    local rollLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rollLabel:SetPoint("TOPLEFT", 20, yOffset)
    rollLabel:SetText("Roll Values:")
    yOffset = yOffset - 25

    -- MS Roll
    local msSlider = self:CreateSlider(panel, "Main Spec (MS)", 30, yOffset, 1, 100,
        function() return LootRoller.Settings:Get("msRoll") end,
        function(value) LootRoller.Settings:Set("msRoll", value) end
    )
    yOffset = yOffset - 50

    -- OS Roll
    local osSlider = self:CreateSlider(panel, "Off Spec (OS)", 30, yOffset, 1, 100,
        function() return LootRoller.Settings:Get("osRoll") end,
        function(value) LootRoller.Settings:Set("osRoll", value) end
    )
    yOffset = yOffset - 50

    -- TMOG Roll
    local tmogSlider = self:CreateSlider(panel, "Transmog (TMOG)", 30, yOffset, 1, 100,
        function() return LootRoller.Settings:Get("tmogRoll") end,
        function(value) LootRoller.Settings:Set("tmogRoll", value) end
    )
    yOffset = yOffset - 50

    -- Auto-hide timeout
    local timeoutSlider = self:CreateSlider(panel, "Auto-hide timeout (0 = disabled)", 30, yOffset, 0, 120,
        function() return LootRoller.Settings:Get("autoHideTimeout") end,
        function(value) LootRoller.Settings:Set("autoHideTimeout", value) end
    )
    yOffset = yOffset - 50

    -- Multi-item mode dropdown
    local modeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("TOPLEFT", 20, yOffset)
    modeLabel:SetText("Multiple Items:")

    local modeDropdown = self:CreateDropdown(panel, 150, yOffset - 5,
        {
            {text = "Replace previous", value = "replace"},
            {text = "Stack popups", value = "stack"},
        },
        function() return LootRoller.Settings:Get("multiItemMode") end,
        function(value) LootRoller.Settings:Set("multiItemMode", value) end
    )

    panel:Hide()
    optionsPanel = panel

    -- Register with Interface Options
    self:RegisterInterfaceOptions()

    return panel
end

function LootRoller.Options:CreateCheckbox(parent, label, x, y, getValue, setValue)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetWidth(24)
    cb:SetHeight(24)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    text:SetText(label)

    cb:SetScript("OnShow", function()
        this:SetChecked(getValue())
    end)

    cb:SetScript("OnClick", function()
        setValue(this:GetChecked() == 1)
    end)

    return cb
end

function LootRoller.Options:CreateSlider(parent, label, x, y, minVal, maxVal, getValue, setValue)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetWidth(200)
    slider:SetHeight(17)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(1)

    local labelText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("BOTTOM", slider, "TOP", 0, 3)
    labelText:SetText(label)

    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)

    slider:SetScript("OnShow", function()
        local val = getValue()
        this:SetValue(val)
        valueText:SetText(val)
    end)

    slider:SetScript("OnValueChanged", function()
        local val = math.floor(this:GetValue())
        setValue(val)
        valueText:SetText(val)
    end)

    return slider
end

function LootRoller.Options:CreateDropdown(parent, x, y, options, getValue, setValue)
    local dropdown = CreateFrame("Frame", "LootRollerModeDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", x, y)

    local function Initialize()
        local currentValue = getValue()
        for _, option in ipairs(options) do
            local info = {}
            info.text = option.text
            info.value = option.value
            info.checked = (currentValue == option.value)
            info.func = function()
                setValue(this.value)
                UIDropDownMenu_SetText(option.text, dropdown)
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)
    UIDropDownMenu_SetWidth(120, dropdown)

    -- Set initial text
    local currentValue = getValue()
    for _, option in ipairs(options) do
        if option.value == currentValue then
            UIDropDownMenu_SetText(option.text, dropdown)
            break
        end
    end

    return dropdown
end

function LootRoller.Options:ToggleOptionsPanel()
    local panel = self:CreateOptionsPanel()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

function LootRoller.Options:RegisterInterfaceOptions()
    -- Create a simple panel for Interface Options
    local interfacePanel = CreateFrame("Frame", "LootRollerInterfacePanel")
    interfacePanel.name = "LootRoller"

    local text = interfacePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("TOPLEFT", 16, -16)
    text:SetText("LootRoller")

    local desc = interfacePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -10)
    desc:SetText("Type /lr or /lootroller to open settings.")

    local openBtn = CreateFrame("Button", nil, interfacePanel, "UIPanelButtonTemplate")
    openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    openBtn:SetWidth(120)
    openBtn:SetHeight(25)
    openBtn:SetText("Open Settings")
    openBtn:SetScript("OnClick", function()
        LootRoller.Options:ToggleOptionsPanel()
    end)

    -- WoW 1.12.1 way to add to interface options
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(interfacePanel)
    end
end
