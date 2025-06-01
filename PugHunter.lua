-- error handling
local function OnError(msg)
    DEFAULT_CHAT_FRAME:AddMessage("PugHunter Error: " .. tostring(msg), 1, 0, 0)
end

local success, err = pcall(function()
    local initFrame = CreateFrame("Frame")
    local configFrame = nil
    local minimapButton = nil
    local ignoredMessages = {}
    local ignoredAuthors = {}
    local pendingMessages = {}
    local debugMessages = {}
    local debugFrame = nil
    PugHunterConfig = PugHunterConfig or {}
    PugHunterConfig.isDisabled = PugHunterConfig.isDisabled or false

    local function AddDebugMessage(message, r, g, b)
        if not PugHunterConfig.debug then return end
        
        -- timestamp to message
        local timestamp = date("%H:%M:%S")
        local coloredMessage = string.format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, message)
        table.insert(debugMessages, "[" .. timestamp .. "] " .. coloredMessage)
        
        while table.getn(debugMessages) > 100 do
            table.remove(debugMessages, 1)
        end
        
        if debugFrame and debugFrame:IsVisible() then
            debugFrame.messageText:SetText(table.concat(debugMessages, "\n"))
        end
    end

    -- slash command to show/hide the config modal
    SLASH_PUGHUNTER1 = "/pg"
    SLASH_PUGHUNTER2 = "/pughunter"

    SlashCmdList["PUGHUNTER"] = function(msg)
        if configFrame then
            if configFrame:IsVisible() then
                configFrame:Hide()
            else
                configFrame:Show()
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Config frame not initialized yet", 1, 0, 0)
        end
    end

    local function GetDefaultReplyMessage()
        return "Hi! I'm interested in joining. Please invite."
    end

    local function trim(s)
        if not s then return "" end
        s = string.gsub(s, "^%s+", "")
        return string.gsub(s, "%s+$", "")
    end

    local raidList = {}
    raidList = {
        {
            id = "UBRS",
            name = "Upper Blackrock Spire",
            abbreviation = {"UBRS"}
        },
        {
            id = "ZG",
            name = "Zul'Gurub",
            abbreviation = {"ZG", "ZG15", "ZG20"}
        },
        {
            id = "AQ20",
            name = "Ruins of Ahn'Qiraj",
            abbreviation = {"AQ20", "AQ15"}
        },
        {
            id = "MC",
            name = "Molten Core",
            abbreviation = {"MC"}
        },
        {
            id = "ONY",
            name = "Onyxia's Lair",
            abbreviation = {"ONY", "ONY15"}
        },
        {
            id = "BWL",
            name = "Blackwing Lair",
            abbreviation = {"BWL", "BWL25"}
        },
        {
            id = "AQ40",
            name = "Temple of Ahn'Qiraj",
            abbreviation = {"AQ40", "AQ35"}
        },
        {
            id = "KARA",
            name = "Karazhan 10 + 40",
            abbreviation = {"KARA", " KZ "}
        },
        {
            id = "ES",
            name = "Emerald Dream",
            abbreviation = {" ES"}
        },
        {
            id = "NAXX",
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
                
                if PugHunterConfig.selectedRaids then
                    for _, selectedRaid in pairs(PugHunterConfig.selectedRaids) do
                        if selectedRaid == raid.id then
                            checkbox:SetChecked(true)
                            break
                        end
                    end
                end
                
                checkbox:SetScript("OnClick", function()
                    local isChecked = checkbox:GetChecked()
                    
                    PugHunterConfig.selectedRaids = PugHunterConfig.selectedRaids or {}
                    
                    if isChecked then
                        table.insert(PugHunterConfig.selectedRaids, raid.id)
                        DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Added raid - " .. raid.name, 0, 1, 0)
                    else
                        for k, v in pairs(PugHunterConfig.selectedRaids) do
                            if v == raid.id then
                                table.remove(PugHunterConfig.selectedRaids, k)
                                break
                            end
                        end
                        DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Removed raid - " .. raid.name, 1, 0, 0)
                    end
                    
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

    -- configuration GUI
    local function CreateConfigUI()
        local frame = CreateFrame("Frame", "PugHunterConfigFrame", UIParent)
        frame:SetWidth(500)
        frame:SetHeight(440)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:EnableMouse(true)
        frame:SetMovable(true)
        
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -15)
        title:SetText("PugHunter")
        
        local raidCheckboxes = CreateRaidCheckboxes(frame)
        
        local function CreateInputField(label, yOffset, defaultText, configKey)
            local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("TOPLEFT", 20, yOffset)
            text:SetWidth(200)
            text:SetJustifyH("LEFT")
            text:SetText(label)
            
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
            editBox:SetTextInsets(6, 6, 3, 3)  -- Add text padding left, right, top, bottom
            
            editBox:SetScript("OnEnterPressed", function()
                this:ClearFocus()
            end)
            
            -- tooltip for Channel Names and Blacklist Words
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
        
        -- toolsOffset to start below raid checkboxes
        local toolsOffset = -220

        -- input fields for each setting
        local replyMessageEdit = CreateInputField("Reply Message", toolsOffset, PugHunterConfig.replyMessage or "", "replyMessage")
        local channelNamesEdit = CreateInputField("Channel Names", toolsOffset-30,
            PugHunterConfig.targetChannelNames and table.concat(PugHunterConfig.targetChannelNames, ",") or "World,LookingForGroup", 
            "targetChannelNames")
        local blacklistEdit = CreateInputField("Blacklist Words", toolsOffset-60,
            PugHunterConfig.blacklistWords and table.concat(PugHunterConfig.blacklistWords, ",") or "lfr,lfg,guild,raids,recruit,igrokov,nabor, ru ,wts,recluta,mechanics,essence,escort",
            "blacklistWords")
        
        -- auto join checkbox
        local autoJoinCheckbox = CreateFrame("CheckButton", "PugHunterAutoJoinCheckbox", frame, "UICheckButtonTemplate")
        autoJoinCheckbox:SetPoint("TOPLEFT", 20, toolsOffset-90)
        autoJoinCheckbox:SetChecked(PugHunterConfig.autoJoin)
        
        local autoJoinText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        autoJoinText:SetPoint("LEFT", autoJoinCheckbox, "RIGHT", 5, 0)
        autoJoinText:SetText("Auto accept group invites")
        
        -- debug checkbox
        local debugCheckbox = CreateFrame("CheckButton", "PugHunterDebugCheckbox", frame, "UICheckButtonTemplate")
        debugCheckbox:SetPoint("TOPLEFT", autoJoinCheckbox, "BOTTOMLEFT", 0, -5)
        debugCheckbox:SetChecked(PugHunterConfig.debug)
        
        local debugText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        debugText:SetPoint("LEFT", debugCheckbox, "RIGHT", 5, 0)
        debugText:SetText("Enable Debug Mode")
        
        -- save button
        local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        saveButton:SetWidth(80)
        saveButton:SetHeight(20)
        saveButton:SetPoint("BOTTOMLEFT", 20, 15)
        saveButton:SetText("Save")
        saveButton:SetScript("OnClick", function()
            -- reply message with default
            PugHunterConfig.replyMessage = replyMessageEdit:GetText() or GetDefaultReplyMessage()

            -- channel names
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

            -- blacklist words
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

            -- checkbox states
            PugHunterConfig.autoJoin = autoJoinCheckbox:GetChecked()
            PugHunterConfig.debug = debugCheckbox:GetChecked()

            DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Settings saved!", 0, 1, 0)
        end)
        
        -- close button
        local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        closeButton:SetWidth(80)
        closeButton:SetHeight(20)
        closeButton:SetPoint("BOTTOMRIGHT", -20, 15)
        closeButton:SetText("Close")
        closeButton:SetScript("OnClick", function()
            frame:Hide()
        end)
        
        -- frame draggable
        frame:SetScript("OnMouseDown", function()
            this:StartMoving()
        end)
        frame:SetScript("OnMouseUp", function()
            this:StopMovingOrSizing()
        end)
        
        frame:Hide()
        return frame
    end

    local dialogFrame = nil
    local ShowNextPendingMessage
    local CreateDialogFrame

    CreateDialogFrame = function()
        local frame = CreateFrame("Frame", "PugHunterDialogFrame", UIParent)
        frame:SetWidth(300)
        frame:SetHeight(200)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:EnableMouse(true)
        frame:SetMovable(true)
        
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

        local raidNameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        raidNameText:SetPoint("TOP", authorText, "BOTTOM", 0, -10)
        raidNameText:SetWidth(260)
        raidNameText:SetJustifyH("CENTER")
        frame.raidNameText = raidNameText

        local buttonWidth = 90  
        local buttonSpacing = 10  
        local bottomMargin = 20  
        
        -- Send button (left)
        local sendButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        sendButton:SetWidth(buttonWidth)
        sendButton:SetHeight(25)
        sendButton:SetPoint("BOTTOMLEFT", buttonSpacing, bottomMargin)
        sendButton:SetText("Send")
        frame.sendButton = sendButton

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

        ignoreAuthorButton:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:AddLine("Skip all further messages from this author", 1, 1, 1)
            GameTooltip:Show()
        end)
        ignoreAuthorButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- frame draggable
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

        -- raid name
        local raidName = ""
        for _, selectedRaidId in ipairs(PugHunterConfig.selectedRaids) do
            for _, raid in ipairs(raidList) do
                if raid.id == selectedRaidId then
                    for _, abbrev in ipairs(raid.abbreviation) do
                        if string.find(string.lower(currentMsg.message), string.lower(abbrev)) then
                            raidName = raid.name
                            break
                        end
                    end
                end
                if raidName ~= "" then break end
            end
            if raidName ~= "" then break end
        end

        -- Add raid name text if found
        if raidName ~= "" then
            dialogFrame.raidNameText:SetText("Raid: " .. raidName)
            dialogFrame.raidNameText:Show()
        else
            dialogFrame.raidNameText:Hide()
        end

        dialogFrame.sendButton:SetScript("OnClick", function()
            SendChatMessage(PugHunterConfig.replyMessage, "WHISPER", nil, currentMsg.author)
            table.remove(pendingMessages, 1)
            dialogFrame:Hide()
            
            if table.getn(pendingMessages) > 0 then
                ShowNextPendingMessage()
            end
        end)

        dialogFrame.ignoreButton:SetScript("OnClick", function()
            local currentMsg = pendingMessages[1]
            if currentMsg then
                table.insert(ignoredMessages, string.lower(currentMsg.message))
                
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
                
                if table.getn(pendingMessages) > 0 then
                    ShowNextPendingMessage()
                end
            end
        end)

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

    -- Minimap Button
    local function CreateMinimapButton()
        local button = CreateFrame("Button", "PugHunterMinimapButton", Minimap)
        button:SetWidth(32)
        button:SetHeight(32)
        button:SetFrameStrata("MEDIUM")
        button:SetMovable(true)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Round")
        
        local ENABLED_TEXTURE = "Interface\\Icons\\Inv_letter_06"
        local DISABLED_TEXTURE = "Interface\\Icons\\Spell_shadow_soothingkiss"

        button:SetNormalTexture(ENABLED_TEXTURE)
        button:SetPushedTexture(ENABLED_TEXTURE)

        button:SetPoint("CENTER", UIParent, "CENTER", 0, 0) 

        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", function()
            this:StartMoving()
        end)
        
        button:SetScript("OnDragStop", function()
            this:StopMovingOrSizing()
            -- Save position
            local xpos, ypos = this:GetCenter()
            local mapxpos, mapypos = Minimap:GetCenter()
            local angle = math.deg(math.atan2(ypos - mapypos, xpos - mapxpos))
            PugHunterConfig.minimapPos = angle
        end)

        local function UpdateButtonTexture()
            if PugHunterConfig.isDisabled then
                button:SetNormalTexture(DISABLED_TEXTURE)
                button:SetPushedTexture(DISABLED_TEXTURE)
                if PugHunterConfig.debug then
                    DEFAULT_CHAT_FRAME:AddMessage("PugHunter Debug: Setting enabled texture", 1, 0, 0)
                end
            else
                button:SetNormalTexture(ENABLED_TEXTURE)
                button:SetPushedTexture(ENABLED_TEXTURE)
                if PugHunterConfig.debug then
                    DEFAULT_CHAT_FRAME:AddMessage("PugHunter Debug: Setting disabled texture", 0, 1, 0)
                end
            end
        end
        
        -- Handle clicks
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function()
            if arg1 == "LeftButton" then
                if configFrame then
                    if configFrame:IsVisible() then
                        configFrame:Hide()
                    else
                        configFrame:Show()
                    end
                else
                    DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Config frame not initialized yet", 1, 0, 0)
                end
            elseif arg1 == "RightButton" then
                PugHunterConfig.isDisabled = not PugHunterConfig.isDisabled
                UpdateButtonTexture()
                if PugHunterConfig.isDisabled then
                    DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Finder enabled", 1, 0, 0)
                else
                    DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Finder disabled", 0, 1, 0)
                end
            end
        end)

        -- Add tooltip handlers
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            GameTooltip:AddLine("PugHunter", 1, 1, 1)
            GameTooltip:AddLine("Left Click: Toggle Config", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Right Click: Toggle Finder", 0.8, 0.8, 0.8)
            if PugHunterConfig.isDisabled then
                GameTooltip:AddLine("Status: Enabled", 1, 0, 0)
            else
                GameTooltip:AddLine("Status: Disabled", 0, 1, 0)
            end
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        UpdateButtonTexture()
        button.UpdateButtonTexture = UpdateButtonTexture
        
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
            PugHunterConfig.selectedRaids = PugHunterConfig.selectedRaids or {"MC"}
            PugHunterConfig.blacklistWords = PugHunterConfig.blacklistWords or {
                "lfr", "lfg", "guild", "raids", "recruit", "igrokov", 
                "nabor", " ru ", "wts", "recluta", "mechanics", "essence", "escort"
            }
            
            if not configFrame then
                configFrame = CreateConfigUI()
                if PugHunterConfig.debug then
                    DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Config frame created", 0, 1, 0)
                end
            end
            
            if not minimapButton then
                minimapButton = CreateMinimapButton()
                if PugHunterConfig.debug then
                    DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Minimap button created", 0, 1, 0)
                end
            end

            if PugHunterConfig.debug then
                DEFAULT_CHAT_FRAME:AddMessage("PugHunter: Initialization complete", 0, 1, 0)
            end
        elseif event == "CHAT_MSG_CHANNEL" then
            if not PugHunterConfig.isDisabled then return end
        
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
                        for _, selectedRaidId in ipairs(PugHunterConfig.selectedRaids or {}) do
                            -- Find the raid definition that matches our selected ID
                            for _, raid in ipairs(raidList) do
                                if raid.id == selectedRaidId then
                                    -- Check all abbreviations for this selected raid
                                    for _, abbrev in ipairs(raid.abbreviation) do
                                        if PugHunterConfig.debug then
                                            AddDebugMessage(string.format("Checking '%s' for '%s' (ID: %s)", 
                                                message, abbrev, selectedRaidId), 1, 1, 0)
                                        end
                                        
                                        if string.find(message, string.lower(abbrev)) then
                                            containsRaid = true
                                            foundRaid = raid.name
                                            if PugHunterConfig.debug then
                                                AddDebugMessage(string.format("Found match: %s", raid.name), 0, 1, 0)
                                            end
                                            break
                                        end
                                    end
                                    if containsRaid then break end
                                end
                            end
                            if containsRaid then break end
                        end
                        
                        if not containsBlacklist and containsRaid then
                            if PugHunterConfig.debug then
                                AddDebugMessage("Message accepted - Author: " .. author .. ", Raid: " .. foundRaid, 0, 1, 0)
                            end
                            table.insert(pendingMessages, {
                                message = arg1,
                                author = author,
                                time = currentTime
                            })
                            
                            if not dialogFrame or not dialogFrame:IsVisible() then
                                ShowNextPendingMessage()
                            end
                        end
                    end
                end
            end
        end
    end)
end)

if not success then
    OnError(err)
end
