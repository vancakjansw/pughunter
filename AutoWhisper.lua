-- Create a frame for initialization and event handling
local initFrame = CreateFrame("Frame")
local configFrame = nil  -- Store the config frame globally
local minimapButton = nil  -- Store the minimap button globally
AutoWhisperConfig = AutoWhisperConfig or {}

-- Variables for cooldown tracking
local lastWhisperTime = 0

-- Define raid list globally
local raidList = {
    {
        name = "Molten Core",
        abbreviation = "MC"
    },
    {
        name = "Onyxia's Lair",
        abbreviation = "Ony"
    },
    {
        name = "Blackwing Lair",
        abbreviation = "BWL"
    },
    {
        name = "Zul'Gurub",
        abbreviation = "ZG"
    },
    {
        name = "Ruins of Ahn'Qiraj",
        abbreviation = "AQ20"
    },
    {
        name = "Temple of Ahn'Qiraj",
        abbreviation = "AQ40"
    },
    {
        name = "Karazhan",
        abbreviation = "KARA"
    },
    {
        name = "Upper Blackrock Spire",
        abbreviation = "UBRS"
    },
    {
        name = "Emerald Dream",
        abbreviation = "ES"
    }
}

function table.contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

-- Create raid checkboxes
local function CreateRaidCheckboxes(frame)
    -- Debug output
    DEFAULT_CHAT_FRAME:AddMessage("Creating raid checkboxes", 1, 1, 0)
    for i, raid in pairs(raidList) do
        DEFAULT_CHAT_FRAME:AddMessage("Raid " .. i .. ": " .. (raid and raid.name or "nil"), 1, 1, 0)
    end

    local checkboxGroup = CreateFrame("Frame", nil, frame)
    checkboxGroup:SetPoint("TOPLEFT", 20, -50)
    checkboxGroup:SetWidth(460)  -- Made wider to accommodate two columns
    checkboxGroup:SetHeight(200)

    -- Create label
    local label = checkboxGroup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 20)
    label:SetText("Select Raids:")

    local col1X = 0
    local col2X = 230  -- Start of second column
    local startY = 0
    local yOffset = -25  -- Space between checkboxes

    for i = 1, table.getn(raidList) do
        local raid = raidList[i]
        if raid then
            local xPos = col1X
            local yPos = startY
            
            if i > 4 then
                xPos = col2X
                yPos = startY + ((i-5) * yOffset)
            else
                yPos = startY + ((i-1) * yOffset)
            end
            
            local checkbox = CreateFrame("CheckButton", "AutoWhisperRaid"..i, checkboxGroup, "UICheckButtonTemplate")
            checkbox:SetPoint("TOPLEFT", xPos, yPos)
            
            local text = getglobal(checkbox:GetName().."Text")
            text:SetText(raid.name)
            
            -- Set initial state
            if AutoWhisperConfig.selectedRaids then
                for _, selectedRaid in pairs(AutoWhisperConfig.selectedRaids) do
                    if selectedRaid == raid.abbreviation then
                        checkbox:SetChecked(true)
                        break
                    end
                end
            end
            
            -- Handle checkbox clicks
            checkbox:SetScript("OnClick", function()
                local isChecked = checkbox:GetChecked()
                
                -- Ensure selectedRaids exists
                AutoWhisperConfig.selectedRaids = AutoWhisperConfig.selectedRaids or {}
                
                if isChecked then
                    table.insert(AutoWhisperConfig.selectedRaids, raid.abbreviation)
                    DEFAULT_CHAT_FRAME:AddMessage("AutoWhisper: Added raid - " .. raid.name, 0, 1, 0)
                else
                    for k, v in pairs(AutoWhisperConfig.selectedRaids) do
                        if v == raid.abbreviation then
                            table.remove(AutoWhisperConfig.selectedRaids, k)
                            break
                        end
                    end
                    DEFAULT_CHAT_FRAME:AddMessage("AutoWhisper: Removed raid - " .. raid.name, 1, 0, 0)
                end
                
                -- Debug output for selected raids
                local selectedRaidsDebug = ""
                for _, selectedRaid in pairs(AutoWhisperConfig.selectedRaids) do
                    selectedRaidsDebug = selectedRaidsDebug .. selectedRaid .. ", "
                end
                DEFAULT_CHAT_FRAME:AddMessage("AutoWhisper: Current raids - " .. selectedRaidsDebug, 0, 1, 1)
            end)
        end
    end
    
    return checkboxGroup
end

-- Create configuration GUI
local function CreateConfigUI()
    -- Create the main frame
    local frame = CreateFrame("Frame", "AutoWhisperConfigFrame", UIParent)
    frame:SetWidth(500)  -- Increased from 300 to 500
    frame:SetHeight(400)  -- Increased from 250 to 400
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    
    -- Add a background texture
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    -- Add title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -15)
    title:SetText("AutoWhisper Configuration")
    
    -- Create raid checkboxes
    local raidCheckboxes = CreateRaidCheckboxes(frame)
    
    -- Create input field function
    local function CreateInputField(label, yOffset, defaultText, configKey)
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("TOPLEFT", 20, yOffset)
        text:SetText(label)
        
        local editBox = CreateFrame("EditBox", nil, frame)
        editBox:SetPoint("TOPLEFT", text, "TOPRIGHT", 10, 0)
        editBox:SetWidth(150)
        editBox:SetHeight(20)
        editBox:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            tile = true, edgeSize = 1, tileSize = 5,
        })
        editBox:SetBackdropColor(0, 0, 0, 0.5)
        editBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("GameFontHighlight")
        editBox:SetText(tostring(defaultText or ""))
        
        editBox:SetScript("OnEnterPressed", function()
            this:ClearFocus()
        end)
        
        return editBox
    end
    
    local toolsOffset = -100
    -- Create input fields for each setting and store them
    local replyMessageEdit = CreateInputField("Reply Message:", toolsOffset-80, AutoWhisperConfig.replyMessage or "", "replyMessage")
    local channelNamesEdit = CreateInputField("Channel Names (comma-separated):", toolsOffset-110, 
        AutoWhisperConfig.targetChannelNames and table.concat(AutoWhisperConfig.targetChannelNames, ",") or "World,LookingForGroup", 
        "targetChannelNames")
    local cooldownEdit = CreateInputField("Cooldown (seconds):", toolsOffset-140, AutoWhisperConfig.cooldown or 100, "cooldown")
    local blacklistEdit = CreateInputField("Blacklist Words (comma-separated):", toolsOffset-170,
        AutoWhisperConfig.blacklistWords and table.concat(AutoWhisperConfig.blacklistWords, ",") or "lfr,lfg,guild",
        "blacklistWords")
    
    -- Create auto join checkbox
    local autoJoinCheckbox = CreateFrame("CheckButton", "AutoWhisperAutoJoinCheckbox", frame, "UICheckButtonTemplate")
    autoJoinCheckbox:SetPoint("TOPLEFT", 20, toolsOffset-170)
    autoJoinCheckbox:SetChecked(AutoWhisperConfig.autoJoin)
    
    local autoJoinText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoJoinText:SetPoint("LEFT", autoJoinCheckbox, "RIGHT", 5, 0)
    autoJoinText:SetText("Auto accept group invites")
    
    -- Create anti AFK checkbox
    local antiAfkCheckbox = CreateFrame("CheckButton", "AutoWhisperAntiAfkCheckbox", frame, "UICheckButtonTemplate")
    antiAfkCheckbox:SetPoint("TOPLEFT", autoJoinCheckbox, "BOTTOMLEFT", 0, -5)
    antiAfkCheckbox:SetChecked(AutoWhisperConfig.antiAfk)
    
    local antiAfkText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    antiAfkText:SetPoint("LEFT", antiAfkCheckbox, "RIGHT", 5, 0)
    antiAfkText:SetText("Anti AFK")
    
    -- Create save button
    local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveButton:SetWidth(80)
    saveButton:SetHeight(20)
    saveButton:SetPoint("BOTTOMLEFT", 20, 15)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        AutoWhisperConfig.replyMessage = replyMessageEdit:GetText()
        -- Split channel names by comma and trim whitespace
        local channelNames = {}
        for channel in string.gmatch(channelNamesEdit:GetText(), "[^,]+") do
            table.insert(channelNames, string.trim(channel))
        end
        AutoWhisperConfig.targetChannelNames = channelNames
        
        -- Split and save blacklist words
        local blacklist = {}
        for word in string.gmatch(blacklistEdit:GetText(), "[^,]+") do
            table.insert(blacklist, string.lower(string.trim(word)))
        end
        AutoWhisperConfig.blacklistWords = blacklist
        
        AutoWhisperConfig.cooldown = tonumber(cooldownEdit:GetText()) or 100
        AutoWhisperConfig.autoJoin = autoJoinCheckbox:GetChecked()
        AutoWhisperConfig.antiAfk = antiAfkCheckbox:GetChecked()
        DEFAULT_CHAT_FRAME:AddMessage("AutoWhisper: Settings saved!", 0, 1, 0)
    end)
    
    -- Create close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetWidth(80)
    closeButton:SetHeight(20)
    closeButton:SetPoint("BOTTOMRIGHT", -20, 15)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Make frame draggable
    frame:SetScript("OnMouseDown", function()
        this:StartMoving()
    end)
    frame:SetScript("OnMouseUp", function()
        this:StopMovingOrSizing()
    end)
    
    frame:Hide()
    return frame
end

-- Create Minimap Button
local function CreateMinimapButton()
    local button = CreateFrame("Button", "AutoWhisperMinimapButton", Minimap)
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    
    button:SetNormalTexture("Interface\\Icons\\Inv_letter_15")
    button:SetPushedTexture("Interface\\Icons\\Inv_letter_15")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Round")
    
    -- Position button on minimap
    local function UpdatePosition()
        local angle = math.rad(AutoWhisperConfig.minimapPos or 45)
        local x = math.cos(angle) * 80
        local y = math.sin(angle) * 80
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    -- Make button draggable
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    
    button:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        -- Calculate and save position
        local xpos, ypos = this:GetCenter()
        local mapXpos, mapYpos = Minimap:GetCenter()
        local angle = math.deg(math.atan2(ypos - mapYpos, xpos - mapXpos))
        AutoWhisperConfig.minimapPos = angle
        UpdatePosition()
    end)
    
    -- Toggle config window on click
    button:SetScript("OnClick", function()
        if configFrame:IsVisible() then
            configFrame:Hide()
        else
            configFrame:Show()
        end
    end)
    
    -- Show tooltip on hover
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("AutoWhisper")
        GameTooltip:AddLine("Click to toggle config", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    UpdatePosition()
    return button
end

-- Register for events
initFrame:RegisterEvent("VARIABLES_LOADED")
initFrame:RegisterEvent("CHAT_MSG_CHANNEL")

-- Initialize saved variables
initFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        -- Ensure AutoWhisperConfig exists and has default values
        if not AutoWhisperConfig then
            AutoWhisperConfig = {}
        end
        
        -- Set default values for any missing config options
        AutoWhisperConfig.targetChannelNames = AutoWhisperConfig.targetChannelNames or {"World", "LookingForGroup"}
        AutoWhisperConfig.replyMessage = AutoWhisperConfig.replyMessage or "hi, mm hunt?"
        AutoWhisperConfig.cooldown = AutoWhisperConfig.cooldown or 100
        AutoWhisperConfig.minimapPos = AutoWhisperConfig.minimapPos or 45
        AutoWhisperConfig.autoJoin = AutoWhisperConfig.autoJoin or false
        AutoWhisperConfig.antiAfk = AutoWhisperConfig.antiAfk or false
        AutoWhisperConfig.enabled = AutoWhisperConfig.enabled or false
        AutoWhisperConfig.selectedRaids = AutoWhisperConfig.selectedRaids or {"MC"}
        AutoWhisperConfig.blacklistWords = AutoWhisperConfig.blacklistWords or {"lfr", "lfg", "guild"}
        
        -- Create config UI only once
        if not configFrame then
            configFrame = CreateConfigUI()
        end
        
        -- Create minimap button only once
        if not minimapButton then
            minimapButton = CreateMinimapButton()
        end
        
    elseif event == "CHAT_MSG_CHANNEL" then
        -- if not AutoWhisperConfig.enabled then return end
        
        local message = string.lower(arg1)
        local author = arg2
        local channelName = arg9
        local currentTime = GetTime()

        -- Check if the channel is in our list of target channels
        local isTargetChannel = false
        for _, targetChannel in ipairs(AutoWhisperConfig.targetChannelNames or {}) do
            if channelName == targetChannel then
                isTargetChannel = true
                break
            end
        end

        if isTargetChannel then
            -- Check if message contains blacklisted words
            local containsBlacklist = false
            for _, word in ipairs(AutoWhisperConfig.blacklistWords or {}) do
                if string.find(message, string.lower(word)) then
                    containsBlacklist = true
                    break
                end
            end
            
            -- Check if message contains any of the selected raids
            local containsRaid = false
            for _, raid in ipairs(AutoWhisperConfig.selectedRaids or {}) do
                if string.find(message, string.lower(raid)) then
                    containsRaid = true
                    break
                end
            end
            
            if not containsBlacklist and containsRaid then
                -- Check cooldown
                if currentTime - lastWhisperTime >= AutoWhisperConfig.cooldown then
                    SendChatMessage(AutoWhisperConfig.replyMessage, "WHISPER", nil, author)
                    lastWhisperTime = currentTime
                else
                    local remainingTime = math.ceil(AutoWhisperConfig.cooldown - (currentTime - lastWhisperTime))
                    DEFAULT_CHAT_FRAME:AddMessage("AutoWhisper: On cooldown for " .. remainingTime .. " seconds", 1, 0.5, 0)
                end
            end
        end
    end
end)

-- Create a frame to listen for events
local chatFrame = CreateFrame("Frame")
chatFrame:RegisterEvent("CHAT_MSG_CHANNEL")
chatFrame:RegisterEvent("PARTY_INVITE_REQUEST")
chatFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
chatFrame:SetScript("OnEvent", OnEvent) 
DEFAULT_CHAT_FRAME:AddMessage("AutoWhisper: selectedRaids = " .. tostring(AutoWhisperConfig.selectedRaids), 1, 1, 0)

-- Create slash command to show/hide the config
SLASH_AUTOWHISPER1 = "/aw"
SLASH_AUTOWHISPER2 = "/autowhisper"

SlashCmdList["AUTOWHISPER"] = function(msg)
    if configFrame and configFrame:IsVisible() then
        configFrame:Hide()
    elseif configFrame then
        configFrame:Show()
    end
end

-- Anti AFK timer
local antiAfkTimer = CreateFrame("Frame")
antiAfkTimer:Hide()
antiAfkTimer:SetScript("OnUpdate", function()
    DEFAULT_CHAT_FRAME:AddMessage("AutoWhisper: AutoWhisperConfig = " .. tostring(AutoWhisperConfig), 1, 1, 0)
    if not AutoWhisperConfig.antiAfk then
        this:Hide()
        return
    end
    
    this.elapsed = (this.elapsed or 0) + arg1
    if this.elapsed < 60 then return end
    this.elapsed = 0
    
    -- Random movement to prevent AFK
    local movements = {
        JumpOrAscendStart,
        function() 
            TurnLeftStart()
            C_Timer.After(0.1, TurnLeftStop)
        end,
        function()
            TurnRightStart()
            C_Timer.After(0.1, TurnRightStop)
        end
    }
    
    local randomMove = movements[math.random(1, 3)]
    randomMove()
end)