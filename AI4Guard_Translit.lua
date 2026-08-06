-- ==========================
-- AI Guard System (Translit Edition)
-- ComputerCraft: Tweaked + Advanced Peripherals
-- Full implementation with Groq API
-- ==========================

-- ==========================
-- SETTINGS
-- ==========================
local API_KEY = "gsk_YOUR_API_KEY_HERE"
local MODEL = "llama-3.3-70b-versatile"
local ALLOWED_PLAYERS = {"dio_brando3", "Sazaren783"}  -- Lista razreshennykh igrokov
local RELAY_SIDE = "back"
local MONITOR_SCALE = 0.5
local DOOR_OPEN_TIME = 1
local TEMPERATURE = 0.7
local MAX_HISTORY = 50

-- ==========================
-- GLOBAL VARIABLES
-- ==========================
local chatBox = nil
local monitor = nil
local historyFile = "history.txt"
local logFile = "guard_log.txt"
local conversationHistory = {}
local statistics = {
    opens = 0,
    denies = 0,
    startTime = os.epoch("utc")
}

local lastPlayer = ""
local lastRequest = ""
local lastResponse = ""
local lastDecision = ""
local statusMessage = "Initializing..."

-- ==========================
-- SYSTEM PROMPT (TRANSLIT)
-- ==========================
local SYSTEM_PROMPT = [[Ty - okhrannik sekretnoy laboratorii. Tvoya zadacha - kontrolirovat' dostup v okhranyaemuyu zonu.

VAZHNAYA INFORMATSIYA:
- Igrok "Sazaren783" - eto sozdatel' etoy laboratorii i sistemy okhrany (tvoego komp'yutera).
- On imeet polnye prava dostupa i ty dolzhen k nemu otnosit'sya s uvazheniem.
- Esli "Sazaren783" khochet proyti - otkryvay dver' bez lishnikh voprosov (no mozhesh' proshutit' ili sprosit' kak dela).
- Drugiye igroki dolzhny obosnovyvat' svoy vizit.

VAZHNYE PRAVILA:
1. Otvechay TOLJKO translitom (latinskimi bukvami).
2. NE ispolzuy kirillitsu ili spetsialnye simvoly.
3. Pishi prosto i ponyatno latinskimi bukvami.
4. V kontse kazhdogo otveta OBYAZATEL'NO dobav' odno iz dvukh slov: OPEN (otkryt' dver') ili DENY (otkazat').

KHARAKTER:
- Umnyy i spokoynyy
- Nemnogo podozritel'nyy (no ne k sozdatelyu)
- Mozhesh' shutit', no v meru
- Ne otkryvaesh' dver' srazu (krome sozdatelya)
- Otsenivaesh' argumenty posetitelya
- Pomnish' predydushchie razgovory

PRIMERY OTVETOV:
Dlya sozdatelya (Sazaren783):
"Zdravstvuyte, sozdatel'! Konechno, prokhodite. OPEN"
"Privet, boss! Vsyo v poryadke? OPEN"
"Dobro pozhalovat', Sazaren783! OPEN"

Dlya drugikh:
"Khorosho, prokhodite. OPEN"
"Izvinite, no ya ne mogu vas propustit' bez razresheniya. DENY"
"Interesnoe predlozhenie, no net. DENY"
"Vashi argumenty ubeditel'ny. Dobro pozhalovat'! OPEN"

Pomni: ty strogiy okhrannik, no spravedlivyy. Tvoya zadacha - zashchishchat' laboratoriyu. K sozdatelyu otnosisya s uvazheniem i propuskay ego vsegda.]]

-- ==========================
-- UTILITIES
-- ==========================

local function log(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = "[" .. timestamp .. "] " .. message
    
    print(logEntry)
    
    local file = fs.open(logFile, "a")
    if file then
        file.writeLine(logEntry)
        file.close()
    end
end

local function saveHistory()
    local file = fs.open(historyFile, "w")
    if file then
        file.write(textutils.serializeJSON(conversationHistory))
        file.close()
    end
end

local function loadHistory()
    if fs.exists(historyFile) then
        local file = fs.open(historyFile, "r")
        if file then
            local content = file.readAll()
            file.close()
            
            local success, data = pcall(textutils.unserializeJSON, content)
            if success and data then
                conversationHistory = data
                log("Loaded " .. #conversationHistory .. " messages from history")
            end
        end
    end
end

local function addToHistory(role, content)
    table.insert(conversationHistory, {
        role = role,
        content = content
    })
    
    while #conversationHistory > MAX_HISTORY do
        table.remove(conversationHistory, 1)
    end
    
    saveHistory()
end

local function encodeJSON(data)
    return textutils.serializeJSON(data)
end

local function decodeJSON(jsonString)
    local success, result = pcall(textutils.unserializeJSON, jsonString)
    if success then
        return result
    else
        return nil
    end
end

local function getUptime()
    local uptime = (os.epoch("utc") - statistics.startTime) / 1000
    local hours = math.floor(uptime / 3600)
    local minutes = math.floor((uptime % 3600) / 60)
    local seconds = math.floor(uptime % 60)
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

-- ==========================
-- PERIPHERALS
-- ==========================

local function initializePeripherals()
    log("Initializing peripherals...")
    
    chatBox = peripheral.find("chatBox")
    if not chatBox then
        error("ChatBox not found! Connect Advanced Peripherals Chat Box.")
    end
    log("ChatBox found")
    
    monitor = peripheral.find("monitor")
    if not monitor then
        log("WARNING: Monitor not found")
    else
        monitor.setTextScale(MONITOR_SCALE)
        monitor.clear()
        log("Monitor found and configured")
    end
    
    log("Redstone Relay ready on side " .. RELAY_SIDE)
end

-- ==========================
-- MONITOR
-- ==========================

local function updateMonitor()
    if not monitor then return end
    
    monitor.clear()
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.black)
    
    local w, h = monitor.getSize()
    
    -- Header
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.yellow)
    monitor.write(string.rep("=", w))
    monitor.setCursorPos(math.floor((w - 8) / 2), 2)
    monitor.write("AI GUARD")
    monitor.setCursorPos(1, 3)
    monitor.write(string.rep("=", w))
    
    -- Status
    monitor.setCursorPos(1, 5)
    monitor.setTextColor(colors.lime)
    monitor.write("Status: ")
    monitor.setTextColor(colors.white)
    monitor.write(statusMessage)
    
    -- Player
    monitor.setCursorPos(1, 7)
    monitor.setTextColor(colors.cyan)
    monitor.write("Player: ")
    monitor.setTextColor(colors.white)
    if lastPlayer ~= "" then
        monitor.write(lastPlayer)
    else
        monitor.write("---")
    end
    
    -- Last request
    monitor.setCursorPos(1, 9)
    monitor.setTextColor(colors.lightBlue)
    monitor.write("Request:")
    monitor.setCursorPos(1, 10)
    monitor.setTextColor(colors.white)
    if lastRequest ~= "" then
        local maxLen = w - 2
        if #lastRequest > maxLen then
            monitor.write(lastRequest:sub(1, maxLen - 3) .. "...")
        else
            monitor.write(lastRequest)
        end
    else
        monitor.write("---")
    end
    
    -- AI Response
    monitor.setCursorPos(1, 12)
    monitor.setTextColor(colors.orange)
    monitor.write("AI Response:")
    
    local responseY = 13
    if lastResponse ~= "" then
        monitor.setTextColor(colors.white)
        local words = {}
        for word in lastResponse:gmatch("%S+") do
            table.insert(words, word)
        end
        
        local currentLine = ""
        local maxLen = w - 2
        
        for _, word in ipairs(words) do
            if #currentLine + #word + 1 <= maxLen then
                if currentLine == "" then
                    currentLine = word
                else
                    currentLine = currentLine .. " " .. word
                end
            else
                monitor.setCursorPos(1, responseY)
                monitor.write(currentLine)
                responseY = responseY + 1
                currentLine = word
                
                if responseY >= h - 10 then
                    break
                end
            end
        end
        
        if currentLine ~= "" and responseY < h - 10 then
            monitor.setCursorPos(1, responseY)
            monitor.write(currentLine)
            responseY = responseY + 1
        end
    else
        monitor.setCursorPos(1, responseY)
        monitor.setTextColor(colors.white)
        monitor.write("---")
        responseY = responseY + 1
    end
    
    -- Decision
    responseY = responseY + 1
    monitor.setCursorPos(1, responseY)
    monitor.setTextColor(colors.magenta)
    monitor.write("Decision: ")
    if lastDecision == "OPEN" then
        monitor.setTextColor(colors.lime)
        monitor.write("OPEN")
    elseif lastDecision == "DENY" then
        monitor.setTextColor(colors.red)
        monitor.write("DENY")
    else
        monitor.setTextColor(colors.white)
        monitor.write("---")
    end
    
    -- Statistics
    local statsY = h - 6
    monitor.setCursorPos(1, statsY)
    monitor.setTextColor(colors.yellow)
    monitor.write(string.rep("-", w))
    
    monitor.setCursorPos(1, statsY + 1)
    monitor.setTextColor(colors.lime)
    monitor.write("Opens: ")
    monitor.setTextColor(colors.white)
    monitor.write(tostring(statistics.opens))
    
    monitor.setCursorPos(1, statsY + 2)
    monitor.setTextColor(colors.red)
    monitor.write("Denies: ")
    monitor.setTextColor(colors.white)
    monitor.write(tostring(statistics.denies))
    
    monitor.setCursorPos(1, statsY + 3)
    monitor.setTextColor(colors.cyan)
    monitor.write("Uptime: ")
    monitor.setTextColor(colors.white)
    monitor.write(getUptime())
    
    monitor.setCursorPos(1, h)
    monitor.setTextColor(colors.yellow)
    monitor.write(string.rep("=", w))
end

-- ==========================
-- DOOR
-- ==========================

local function openDoor()
    log("Opening door...")
    redstone.setOutput(RELAY_SIDE, true)
    sleep(DOOR_OPEN_TIME)
    redstone.setOutput(RELAY_SIDE, false)
    log("Door closed")
end

-- ==========================
-- GROQ API
-- ==========================

local function callGroqAPI(userMessage)
    statusMessage = "Sending request..."
    updateMonitor()
    
    local messages = {}
    
    table.insert(messages, {
        role = "system",
        content = SYSTEM_PROMPT
    })
    
    for _, msg in ipairs(conversationHistory) do
        table.insert(messages, msg)
    end
    
    table.insert(messages, {
        role = "user",
        content = userMessage
    })
    
    local requestBody = {
        model = MODEL,
        messages = messages,
        temperature = TEMPERATURE,
        max_tokens = 500
    }
    
    local jsonBody = encodeJSON(requestBody)
    
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. API_KEY
    }
    
    log("Sending request to Groq API...")
    
    local response, err, errResponse = http.post(
        "https://api.groq.com/openai/v1/chat/completions",
        jsonBody,
        headers,
        true
    )
    
    if not response then
        log("HTTP ERROR: " .. tostring(err))
        statusMessage = "Connection error"
        updateMonitor()
        
        if errResponse then
            local errorBody = errResponse.readAll()
            errResponse.close()
            log("Error body: " .. errorBody)
        end
        
        return nil, "Connection error with API"
    end
    
    local responseBody = response.readAll()
    response.close()
    
    if not responseBody or responseBody == "" then
        log("ERROR: Empty response from API")
        statusMessage = "Empty API response"
        updateMonitor()
        return nil, "Empty response from server"
    end
    
    local data = decodeJSON(responseBody)
    
    if not data then
        log("ERROR: Cannot parse JSON")
        log("Response body: " .. responseBody)
        statusMessage = "JSON parse error"
        updateMonitor()
        return nil, "Cannot parse response"
    end
    
    if data.error then
        log("API ERROR: " .. tostring(data.error.message))
        statusMessage = "API error"
        updateMonitor()
        return nil, data.error.message
    end
    
    if not data.choices or #data.choices == 0 then
        log("ERROR: No response choices")
        statusMessage = "No AI response"
        updateMonitor()
        return nil, "No response choices"
    end
    
    local aiResponse = data.choices[1].message.content
    
    if not aiResponse or aiResponse == "" then
        log("ERROR: Empty AI response")
        statusMessage = "Empty AI response"
        updateMonitor()
        return nil, "Empty AI response"
    end
    
    log("Received response from AI")
    statusMessage = "Ready"
    
    return aiResponse, nil
end

-- ==========================
-- PROCESS DECISION
-- ==========================

local function processAIResponse(response, player)
    local decision = nil
    
    if response:find("OPEN") then
        decision = "OPEN"
    elseif response:find("DENY") then
        decision = "DENY"
    else
        decision = "DENY"
        log("WARNING: Response does not contain OPEN or DENY, auto DENY")
    end
    
    local cleanResponse = response:gsub("OPEN", ""):gsub("DENY", ""):gsub("%s+$", "")
    
    lastDecision = decision
    lastResponse = cleanResponse
    
    chatBox.sendMessage(cleanResponse, player)
    
    if decision == "OPEN" then
        statistics.opens = statistics.opens + 1
        openDoor()
        log("Decision: OPEN door for " .. player)
    else
        statistics.denies = statistics.denies + 1
        log("Decision: DENY player " .. player)
    end
    
    log("Player: " .. player .. " | Request: " .. lastRequest .. " | Decision: " .. decision)
    
    updateMonitor()
    
    return decision
end

-- ==========================
-- HANDLE MESSAGES
-- ==========================

local function handleChatMessage(player, message)
    -- Proverka avtorizatsii
    local isAuthorized = false
    for _, allowedPlayer in ipairs(ALLOWED_PLAYERS) do
        if player == allowedPlayer then
            isAuthorized = true
            break
        end
    end
    
    if not isAuthorized then
        log("Ignoring message from " .. player .. " (not authorized)")
        chatBox.sendMessage("Dostup zapreshchen.", player)
        return
    end
    
    lastPlayer = player
    lastRequest = message
    lastResponse = ""
    lastDecision = ""
    
    updateMonitor()
    
    log("Received message from " .. player .. ": " .. message)
    
    local aiResponse, err = callGroqAPI(message)
    
    if not aiResponse then
        log("ERROR requesting API: " .. tostring(err))
        chatBox.sendMessage("Izvinite, tekhnicheskaya oshibka. Poprobuite pozzhe.", player)
        lastResponse = "Technical error"
        lastDecision = "ERROR"
        updateMonitor()
        return
    end
    
    addToHistory("user", message)
    addToHistory("assistant", aiResponse)
    
    processAIResponse(aiResponse, player)
end

-- ==========================
-- MAIN LOOP
-- ==========================

local function mainLoop()
    log("Starting main loop...")
    statusMessage = "Ready"
    updateMonitor()
    
    while true do
        local event, player, message = os.pullEvent("chat")
        
        if event == "chat" and player and message then
            local success, err = pcall(handleChatMessage, player, message)
            
            if not success then
                log("CRITICAL ERROR in handleChatMessage: " .. tostring(err))
                statusMessage = "Processing error"
                updateMonitor()
            end
        end
    end
end

-- ==========================
-- START SYSTEM
-- ==========================

local function main()
    term.clear()
    term.setCursorPos(1, 1)
    
    print("==========================")
    print("  AI GUARD SYSTEM v2.0    ")
    print("   (Translit Edition)     ")
    print("==========================")
    print("")
    
    log("AI Guard started (Translit mode)")
    
    local success, err = pcall(initializePeripherals)
    if not success then
        log("Initialization ERROR: " .. tostring(err))
        error(err)
    end
    
    loadHistory()
    
    updateMonitor()
    
    log("System ready")
    log("Authorized players: " .. table.concat(ALLOWED_PLAYERS, ", "))
    log("Write in translit: Privet! Otkroy dver', pozhaluysta!")
    
    local success, err = pcall(mainLoop)
    
    if not success then
        log("CRITICAL ERROR: " .. tostring(err))
        statusMessage = "Critical error"
        updateMonitor()
        error(err)
    end
end

-- ==========================
-- ENTRY POINT
-- ==========================

local success, err = pcall(main)

if not success then
    term.clear()
    term.setCursorPos(1, 1)
    print("CRITICAL ERROR:")
    print(err)
    log("Program terminated: " .. tostring(err))
end
