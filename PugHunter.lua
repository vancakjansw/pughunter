-- Create a frame for initialization and event handling
local initFrame = CreateFrame("Frame")
local configFrame = nil
local minimapButton = nil
local ignoredMessages = {}
local ignoredAuthors = {}
local pendingMessages = {}
local debugMessages = {}
local debugFrame = nil
PugHunterConfig = PugHunterConfig or {}

-- Debug message function
local function AddDebugMessage(message, r, g, b)
    if not PugHunterConfig.debug then return end
    
    -- Add timestamp to message
    local timestamp = date("%H:%M:%S")
    local coloredMessage = string.format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, message)
    table.insert(debugMessages, "[" .. timestamp .. "] " .. coloredMessage)
    
    -- Keep only last 100 messages
    while table.getn(debugMessages) > 100 do
        table.remove(debugMessages, 1)
    end
    
    -- Update debug frame if it exists
    if debugFrame and debugFrame:IsVisible() then
        debugFrame.messageText:SetText(table.concat(debugMessages, "\n"))
    end
end

-- Create slash command to show/hide the config
SLASH_PUGHUNTER1 = "/pg"
SLASH_PUGHUNTER2 = "/pughunter"

-- Add this near the top of the file, after the initial variable declarations
local function GetDefaultReplyMessage()
    -- Set default whisper reply message
    return "Hi! I'm interested in joining. Please invite."
end

-- Add at the top with other local variables and utility functions
local function trim(s)
    if not s then return "" end
    s = string.gsub(s, "^%s+", "")
    return string.gsub(s, "%s+$", "")
end

-- Update the raid list to support multiple abbreviations
local raidList = {
    {
        name = "Upper Blackrock Spire",
        abbreviation = {"UBRS"}
    },
    {
        name = "Zul'Gurub",
        abbreviation = {"ZG", "ZG15", "ZG20"}
    },
    {
        name = "Ruins of Ahn'Qiraj",
        abbreviation = {"AQ20", "AQ15"}
    },
    {
        name = "Molten Core",
        abbreviation = {"MC"}
    },
    {
        name = "Onyxia's Lair",
        abbreviation = {"ONY", "ONY15"}
    },
    {
        name = "Blackwing Lair",
        abbreviation = {"BWL", "BWL25"}
    },
    {
        name = "Temple of Ahn'Qiraj",
        abbreviation = {"AQ40", "AQ35"}
    },
    {
        name = "Karazhan 10 + 40",
        abbreviation = {"KARA", " KZ "}
    },
    {
        name = "Emerald Dream",
        abbreviation = {" ES"}
    },
    {
        name = "Naxxramas",
        abbreviation = {"NAXX"}
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
    local checkboxGroup = CreateFrame("Frame", nil, frame)
    checkboxGroup:SetPoint("TOPLEFT", 20, -50)  
    checkboxGroup:SetWidth(460)
    checkboxGroup:SetHeight(150)  

    -- Create label
    local label = checkboxGroup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 20)
    label:SetText("Select Raids:")

    local col1X = 0
    local col2X = 230
    local startY = 0
    local yOffset = -20  

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
            
            local checkbox = CreateFrame("CheckButton", "PugHunterRaid"..i, checkboxGroup, "UICheckButtonTemplate")
            checkbox:SetPoint("TOPLEFT", xPos, yPos)
            
            local text = getglobal(checkbox:GetName().."Text")
            text:SetText(raid.name)
            
            -- Set initial state
            if PugHunterConfig.selectedRaids then
                for _, selectedRaid in pairs(PugHunterConfig.selectedRaids) do
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
                PugHunterConfig.selectedRaids = PugHunterConfig.selectedRaids or {}
                
                if isChecked then
                    -- Always use first abbreviation when saving
                    local mainAbbrev = type(raid.abbreviation) == "table" and raid.abbreviation[1] or raid.abbreviation
                    table.insert(PugHunterConfig.selectedRaids, mainAbbrev)
                    DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Added raid - " .. raid.name, 0, 1, 0)
                else
                    for k, v in pairs(PugHunterConfig.selectedRaids) do
                        -- Check against all possible abbreviations when removing
                        if type(raid.abbreviation) == "table" then
                            for _, abbrev in ipairs(raid.abbreviation) do
                                if v == abbrev then
                                    table.remove(PugHunterConfig.selectedRaids, k)
                                    break
                                end
                            end
                        elseif v == raid.abbreviation then
                            table.remove(PugHunterConfig.selectedRaids, k)
                            break
                        end
                    end
                    DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Removed raid - " .. raid.name, 1, 0, 0)
                end
                
                -- Debug output for selected raids
                local selectedRaidsDebug = ""
                for _, selectedRaid in pairs(PugHunterConfig.selectedRaids) do
                    selectedRaidsDebug = selectedRaidsDebug .. selectedRaid .. ", "
                end
                DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Current raids - " .. selectedRaidsDebug, 0, 1, 1)
            end)
        end
    end
    
    return checkboxGroup
end

-- Create configuration GUI
local function CreateConfigUI()
    -- Create the main frame
    local frame = CreateFrame("Frame", "PugHunterConfigFrame", UIParent)
    frame:SetWidth(500)
    frame:SetHeight(440)
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
    title:SetText("PugHunter")
    
    -- Create raid checkboxes
    local raidCheckboxes = CreateRaidCheckboxes(frame)
    
    -- Create input field function
    local function CreateInputField(label, yOffset, defaultText, configKey)
        -- Create label text
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("TOPLEFT", 20, yOffset)
        text:SetWidth(200)
        text:SetJustifyH("LEFT")
        text:SetText(label)
        
        -- Create edit box with right alignment
        local editBox = CreateFrame("EditBox", nil, frame)
        editBox:SetPoint("TOPRIGHT", -20, yOffset)  -- Align to right side
        editBox:SetWidth(250)  -- Width for input field
        editBox:SetHeight(26)
        editBox:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            tile = true, 
            edgeSize = 1, 
            tileSize = 5,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }  -- Added insets
        })
        editBox:SetBackdropColor(0, 0, 0, 0.5)
        editBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("GameFontHighlight")
        editBox:SetText(tostring(defaultText or ""))
        editBox:SetJustifyH("LEFT")
        editBox:SetTextInsets(6, 6, 3, 3)  -- Add text padding (left, right, top, bottom)
        
        editBox:SetScript("OnEnterPressed", function()
            this:ClearFocus()
        end)
        
        -- Add tooltip for Channel Names and Blacklist Words
        if string.find(label, "Channel Names") or string.find(label, "Blacklist Words") then
            editBox:SetScript("OnEnter", function()
                GameTooltip:SetOwner(this, "ANCHOR_TOPRIGHT")
                GameTooltip:AddLine(label, 1, 1, 1)
                GameTooltip:AddLine("Separate multiple entries with commas", 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end)
            editBox:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
        
        return editBox
    end
    
    -- Adjust toolsOffset to start below raid checkboxes
    local toolsOffset = -220

    -- Create input fields for each setting
    local replyMessageEdit = CreateInputField("Reply Message", toolsOffset, PugHunterConfig.replyMessage or "", "replyMessage")
    local channelNamesEdit = CreateInputField("Channel Names", toolsOffset-30,
        PugHunterConfig.targetChannelNames and table.concat(PugHunterConfig.targetChannelNames, ",") or "World,LookingForGroup", 
        "targetChannelNames")
    local blacklistEdit = CreateInputField("Blacklist Words", toolsOffset-60,
        PugHunterConfig.blacklistWords and table.concat(PugHunterConfig.blacklistWords, ",") or "lfr,lfg,guild,raids,recruit,igrokov,nabor, ru ,wts, 'recluta",
        "blacklistWords")
    
    -- Create auto join checkbox
    local autoJoinCheckbox = CreateFrame("CheckButton", "PugHunterAutoJoinCheckbox", frame, "UICheckButtonTemplate")
    autoJoinCheckbox:SetPoint("TOPLEFT", 20, toolsOffset-90)
    autoJoinCheckbox:SetChecked(PugHunterConfig.autoJoin)
    
    local autoJoinText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoJoinText:SetPoint("LEFT", autoJoinCheckbox, "RIGHT", 5, 0)
    autoJoinText:SetText("Auto accept group invites")
    
    -- Add debug checkbox
    local debugCheckbox = CreateFrame("CheckButton", "PugHunterDebugCheckbox", frame, "UICheckButtonTemplate")
    debugCheckbox:SetPoint("TOPLEFT", autoJoinCheckbox, "BOTTOMLEFT", 0, -5)
    debugCheckbox:SetChecked(PugHunterConfig.debug)
    
    local debugText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugText:SetPoint("LEFT", debugCheckbox, "RIGHT", 5, 0)
    debugText:SetText("Enable Debug Mode")
    
    -- Create save button
    local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveButton:SetWidth(80)
    saveButton:SetHeight(20)
    saveButton:SetPoint("BOTTOMLEFT", 20, 15)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        -- Save reply message with default
        PugHunterConfig.replyMessage = replyMessageEdit:GetText() or GetDefaultReplyMessage()

        -- Save channel names
        local channelNames = {}
        local channelText = channelNamesEdit:GetText() or ""
        for channel in string.gfind(channelText, "[^,]+") do
            local trimmedChannel = trim(channel)
            if trimmedChannel ~= "" then
                table.insert(channelNames, trimmedChannel)
            end
        end
        if table.getn(channelNames) == 0 then
            channelNames = {"World", "LookingForGroup"}
        end
        PugHunterConfig.targetChannelNames = channelNames

        -- Save blacklist words
        local blacklist = {}
        local blacklistText = blacklistEdit:GetText() or ""
        for word in string.gfind(blacklistText, "[^,]+") do
            local trimmedWord = string.lower(trim(word))
            if trimmedWord ~= "" then
                table.insert(blacklist, trimmedWord)
            end
        end
        if table.getn(blacklist) == 0 then
            blacklist = {"lfr", "lfg", "guild", "raids", "recruit", "igrokov", "nabor", " ru ", "wts", "recluta"}
        end
        PugHunterConfig.blacklistWords = blacklist

        -- Save checkbox states
        PugHunterConfig.autoJoin = autoJoinCheckbox:GetChecked()
        PugHunterConfig.debug = debugCheckbox:GetChecked()

        DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Settings saved!", 0, 1, 0)
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

-- First declare both functions
local dialogFrame = nil
local ShowNextPendingMessage
local CreateDialogFrame

-- Define CreateDialogFrame first
CreateDialogFrame = function()
    local frame = CreateFrame("Frame", "PugHunterDialogFrame", UIParent)
    frame:SetWidth(300)
    frame:SetHeight(200)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    
    -- Add background
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Message text
    local messageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    messageText:SetPoint("TOP", 0, -20)
    messageText:SetWidth(260)
    messageText:SetJustifyH("CENTER")
    frame.messageText = messageText

    -- Author text
    local authorText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    authorText:SetPoint("TOP", messageText, "BOTTOM", 0, -10)
    authorText:SetWidth(260)
    authorText:SetJustifyH("CENTER")
    frame.authorText = authorText

    -- Adjust button widths and positions for 3 buttons
    local buttonWidth = 90  -- Slightly smaller width
    local buttonSpacing = 10  -- Space between buttons
    local bottomMargin = 20  -- Space from bottom of frame
    
    -- Send button (left)
    local sendButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sendButton:SetWidth(buttonWidth)
    sendButton:SetHeight(25)
    sendButton:SetPoint("BOTTOMLEFT", buttonSpacing, bottomMargin)
    sendButton:SetText("Send")
    frame.sendButton = sendButton
    -- Add tooltip
    sendButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine("Send reply message", 1, 1, 1)
        GameTooltip:Show()
    end)
    sendButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local ignoreButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    ignoreButton:SetWidth(buttonWidth)
    ignoreButton:SetHeight(25)
    ignoreButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, bottomMargin)
    ignoreButton:SetText("Skip")
    frame.ignoreButton = ignoreButton
    ignoreButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine("Skip current message", 1, 1, 1)
        GameTooltip:AddLine("If author changes message it will be displayed again", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    ignoreButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local ignoreAuthorButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    ignoreAuthorButton:SetWidth(buttonWidth)
    ignoreAuthorButton:SetHeight(25)
    ignoreAuthorButton:SetPoint("BOTTOMRIGHT", -buttonSpacing, bottomMargin)
    ignoreAuthorButton:SetText("Skip Author")
    frame.ignoreAuthorButton = ignoreAuthorButton
    -- Update tooltip text
    ignoreAuthorButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine("Skip all further messages from this author", 1, 1, 1)
        GameTooltip:Show()
    end)
    ignoreAuthorButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
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

ShowNextPendingMessage = function()
    if table.getn(pendingMessages) == 0 then return end
    
    -- Create dialog frame if it doesn't exist
    if not dialogFrame then
        dialogFrame = CreateDialogFrame()
    end

    local currentMsg = pendingMessages[1]
    
    dialogFrame.messageText:SetText(currentMsg.message)
    dialogFrame.authorText:SetText("From: " .. currentMsg.author)

    dialogFrame.sendButton:SetScript("OnClick", function()
        SendChatMessage(PugHunterConfig.replyMessage, "WHISPER", nil, currentMsg.author)
        table.remove(pendingMessages, 1)
        dialogFrame:Hide()
        
        -- Show next message if available
        if table.getn(pendingMessages) > 0 then
            ShowNextPendingMessage()
        end
    end)

    dialogFrame.ignoreButton:SetScript("OnClick", function()
        local currentMsg = pendingMessages[1]
        if currentMsg then
            -- Add to ignored messages
            table.insert(ignoredMessages, string.lower(currentMsg.message))
            
            -- Remove current and all similar messages from queue
            local i = 1
            while i <= table.getn(pendingMessages) do
                if string.lower(pendingMessages[i].message) == string.lower(currentMsg.message) then
                    table.remove(pendingMessages, i)
                else
                    i = i + 1
                end
            end
            
            if PugHunterConfig.debug then
                AddDebugMessage("Message skipped", 1, 0.5, 0)
            end
            
            dialogFrame:Hide()
            
            -- Show next message if available
            if table.getn(pendingMessages) > 0 then
                ShowNextPendingMessage()
            end
        end
    end)

    -- Skip Author button action
    dialogFrame.ignoreAuthorButton:SetScript("OnClick", function()
        local currentMsg = pendingMessages[1]
        if currentMsg then
            -- Add to ignored authors
            table.insert(ignoredAuthors, currentMsg.author)
            
            -- Remove all messages from this author from queue
            local i = 1
            while i <= table.getn(pendingMessages) do
                if pendingMessages[i].author == currentMsg.author then
                    table.remove(pendingMessages, i)
                else
                    i = i + 1
                end
            end
            
            if PugHunterConfig.debug then
                AddDebugMessage("Author " .. currentMsg.author .. " skipped", 1, 0.5, 0)
            end
            
            dialogFrame:Hide()
            
            -- Show next message if available
            if table.getn(pendingMessages) > 0 then
                ShowNextPendingMessage()
            end
        end
    end)

    dialogFrame:Show()
end

-- Create Minimap Button
local function CreateMinimapButton()
    local button = CreateFrame("Button", "PugHunterMinimapButton", Minimap)
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    
    button:SetNormalTexture("Interface\\Icons\\Inv_letter_15")
    button:SetPushedTexture("Interface\\Icons\\Inv_letter_15")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Round")
    
    -- Position button on minimap
    local function UpdatePosition()
        local angle = math.rad(PugHunterConfig.minimapPos or 45)
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
        PugHunterConfig.minimapPos = angle
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
        GameTooltip:AddLine("PugHunter")
        GameTooltip:AddLine("Click to toggle config", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Add debug frame toggle to minimap button right click
    button:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            if configFrame:IsVisible() then
                configFrame:Hide()
            else
                configFrame:Show()
            end
        elseif button == "RightButton" and PugHunterConfig.debug then
            if not debugFrame then
                debugFrame = CreateDebugFrame()
            end
            
            if debugFrame:IsVisible() then
                debugFrame:Hide()
            else
                debugFrame.messageText:SetText(table.concat(debugMessages, "\n"))
                debugFrame:Show()
            end
        end
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
        -- Ensure PugHunterConfig exists and has default values
        if not PugHunterConfig then
            PugHunterConfig = {}
        end
        
        -- Set default values for any missing config options
        PugHunterConfig.targetChannelNames = PugHunterConfig.targetChannelNames or {"World", "LookingForGroup"}
        PugHunterConfig.replyMessage = PugHunterConfig.replyMessage or GetDefaultReplyMessage()
        PugHunterConfig.minimapPos = PugHunterConfig.minimapPos or 45
        PugHunterConfig.autoJoin = PugHunterConfig.autoJoin or false
        PugHunterConfig.debug = PugHunterConfig.debug or false
        PugHunterConfig.enabled = PugHunterConfig.enabled or false
        PugHunterConfig.selectedRaids = PugHunterConfig.selectedRaids or {"MC"}
        PugHunterConfig.blacklistWords = PugHunterConfig.blacklistWords or {"lfr", "lfg", "guild", "raids", "recruit", "igrokov", "nabor", " ru ", "wts", "recluta"}
        
        -- Create config UI only once
        if not configFrame then
            configFrame = CreateConfigUI()
        end
        
        -- Create minimap button only once
        if not minimapButton then
            minimapButton = CreateMinimapButton()
        end
        
    elseif event == "CHAT_MSG_CHANNEL" then
        -- if not PugHunterConfig.enabled then return end
        
        local message = string.lower(arg1)
        local author = arg2
        local channelName = arg9
        local currentTime = GetTime()

        -- Check if the channel is in our list of target channels
        local isTargetChannel = false
        for _, targetChannel in ipairs(PugHunterConfig.targetChannelNames or {}) do
            if channelName == targetChannel then
                isTargetChannel = true
                break
            end
        end

        if isTargetChannel then
            if PugHunterConfig.debug then
                AddDebugMessage("Message received in target channel: " .. channelName, 0, 1, 1)
            end

            -- Check if author is ignored
            local isAuthorIgnored = false
            for _, ignoredAuthor in ipairs(ignoredAuthors) do
                if author == ignoredAuthor then
                    isAuthorIgnored = true
                    if PugHunterConfig.debug then
                        AddDebugMessage("Author " .. author .. " is ignored", 1, 0.5, 0)
                    end
                    break
                end
            end

            if not isAuthorIgnored then
                local message = string.lower(arg1)
                
                -- Check if message is ignored
                local isIgnored = false
                for _, ignoredMsg in ipairs(ignoredMessages) do
                    if message == ignoredMsg then
                        isIgnored = true
                        if PugHunterConfig.debug then
                            AddDebugMessage("Message is in ignore list", 1, 0.5, 0)
                        end
                        break
                    end
                end

                -- Only proceed if message is not ignored
                if not isIgnored then
                    -- Check blacklist
                    local containsBlacklist = false
                    for _, word in ipairs(PugHunterConfig.blacklistWords or {}) do
                        if string.find(message, string.lower(word)) then
                            containsBlacklist = true
                            if PugHunterConfig.debug then
                                AddDebugMessage("Message contains blacklisted word: " .. word, 1, 0.5, 0)
                            end
                            break
                        end
                    end
                    
                    -- Check raids
                    local containsRaid = false
                    local foundRaid = ""
                    for _, selectedRaidAbbrev in ipairs(PugHunterConfig.selectedRaids or {}) do
                        for _, raid in ipairs(raidList) do
                            if type(raid.abbreviation) == "table" then
                                for _, abbrev in ipairs(raid.abbreviation) do
                                    if string.find(message, string.lower(abbrev)) then
                                        containsRaid = true
                                        foundRaid = raid.name
                                        break
                                    end
                                end
                            elseif string.find(message, string.lower(raid.abbreviation)) then
                                containsRaid = true
                                foundRaid = raid.name
                            end
                            if containsRaid then break end
                        end
                        if containsRaid then break end
                    end
                    
                    if not containsBlacklist and containsRaid then
                        if PugHunterConfig.debug then
                            AddDebugMessage("Message accepted - Author: " .. author .. ", Raid: " .. foundRaid, 0, 1, 0)
                        end
                        -- Add message to pending queue instead of showing immediately
                        table.insert(pendingMessages, {
                            message = arg1,
                            author = author,
                            time = currentTime
                        })
                        
                        -- Only show dialog if it's not already visible
                        if not dialogFrame or not dialogFrame:IsVisible() then
                            ShowNextPendingMessage()
                        end
                    end
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
DEFAULT_CHAT_FRAME:AddMessage("PugHunter: selectedRaids = " .. tostring(PugHunterConfig.selectedRaids), 1, 1, 0)



SlashCmdList["PUGHUNTER"] = function(msg)
    if configFrame and configFrame:IsVisible() then
        configFrame:Hide()
    elseif configFrame then
        configFrame:Show()
    end
end

-- Add this function after other frame creation functions
local function CreateDebugFrame()
    local frame = CreateFrame("Frame", "PugHunterDebugFrame", UIParent)
    frame:SetWidth(400)
    frame:SetHeight(300)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    
    -- Add background
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Add title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Debug Messages")

    -- Create scrollframe for messages
    local scrollFrame = CreateFrame("ScrollFrame", "PugHunterDebugScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 40)

    -- Create content frame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth())
    content:SetHeight(scrollFrame:GetHeight())
    scrollFrame:SetScrollChild(content)
    
    -- Message text
    local messageText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    messageText:SetPoint("TOPLEFT", 0, 0)
    messageText:SetWidth(scrollFrame:GetWidth() - 20)
    messageText:SetJustifyH("LEFT")
    frame.messageText = messageText

    -- Close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetWidth(80)
    closeButton:SetHeight(25)
    closeButton:SetPoint("BOTTOM", 0, 15)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Clear button
    local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearButton:SetWidth(80)
    clearButton:SetHeight(25)
    clearButton:SetPoint("BOTTOMLEFT", 20, 15)
    clearButton:SetText("Clear")
    clearButton:SetScript("OnClick", function()
        debugMessages = {}
        frame.messageText:SetText("")
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

