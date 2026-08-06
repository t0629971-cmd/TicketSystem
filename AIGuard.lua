-- ==========================
-- AI Guard System
-- ComputerCraft: Tweaked + Advanced Peripherals
-- Full implementation with Groq API
-- ==========================

-- ==========================
-- НАСТРОЙКИ
-- ==========================
local API_KEY = ""
local MODEL = "llama-3.3-70b-versatile"
local PLAYER_NAME = "dio_brando3"
local RELAY_SIDE = "back"
local MONITOR_SCALE = 0.5
local DOOR_OPEN_TIME = 1
local TEMPERATURE = 0.7
local MAX_HISTORY = 20

-- ==========================
-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
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
local statusMessage = "Инициализация..."

-- ==========================
-- СИСТЕМНЫЙ ПРОМПТ
-- ==========================
local SYSTEM_PROMPT = [[Ты - охранник секретной лаборатории. Твоя задача - контролировать доступ в охраняемую зону.

ВАЖНЫЕ ПРАВИЛА:
1. Отвечай ТОЛЬКО на русском языке.
2. Используй UTF-8 кодировку.
3. НЕ используй английские слова, кроме OPEN и DENY.
4. В конце каждого ответа ОБЯЗАТЕЛЬНО добавь одно из двух слов: OPEN (открыть дверь) или DENY (отказать).

ХАРАКТЕР:
- Умный и спокойный
- Немного подозрительный
- Можешь шутить, но в меру
- Не открываешь дверь сразу
- Оцениваешь аргументы посетителя
- Помнишь предыдущие разговоры

ПРИМЕРЫ ОТВЕТОВ:
"Хорошо, проходите. OPEN"
"Извините, но я не могу вас пропустить без разрешения. DENY"
"Интересное предложение, но нет. DENY"
"Ваши аргументы убедительны. Добро пожаловать! OPEN"

Помни: ты строгий охранник, но справедливый. Твоя задача - защищать лабораторию.]]

-- ==========================
-- УТИЛИТЫ
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
                log("Загружено " .. #conversationHistory .. " сообщений из истории")
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
-- ПЕРИФЕРИЯ
-- ==========================

local function initializePeripherals()
    log("Инициализация периферии...")
    
    -- Поиск Chat Box
    chatBox = peripheral.find("chatBox")
    if not chatBox then
        error("ChatBox не найден! Подключите Advanced Peripherals Chat Box.")
    end
    log("ChatBox найден")
    
    -- Поиск монитора
    monitor = peripheral.find("monitor")
    if not monitor then
        log("ВНИМАНИЕ: Монитор не найден")
    else
        monitor.setTextScale(MONITOR_SCALE)
        monitor.clear()
        log("Монитор найден и настроен")
    end
    
    -- Проверка Redstone Relay
    if not redstone.getOutput(RELAY_SIDE) == false and not redstone.getOutput(RELAY_SIDE) == true then
        log("ВНИМАНИЕ: Redstone на стороне " .. RELAY_SIDE .. " может быть недоступен")
    else
        log("Redstone Relay готов на стороне " .. RELAY_SIDE)
    end
end

-- ==========================
-- МОНИТОР
-- ==========================

local function updateMonitor()
    if not monitor then return end
    
    monitor.clear()
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.black)
    
    local w, h = monitor.getSize()
    
    -- Заголовок
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.yellow)
    monitor.write(string.rep("=", w))
    monitor.setCursorPos(math.floor((w - 8) / 2), 2)
    monitor.write("AI GUARD")
    monitor.setCursorPos(1, 3)
    monitor.write(string.rep("=", w))
    
    -- Статус
    monitor.setCursorPos(1, 5)
    monitor.setTextColor(colors.lime)
    monitor.write("Status: ")
    monitor.setTextColor(colors.white)
    monitor.write(statusMessage)
    
    -- Игрок
    monitor.setCursorPos(1, 7)
    monitor.setTextColor(colors.cyan)
    monitor.write("Player: ")
    monitor.setTextColor(colors.white)
    if lastPlayer ~= "" then
        monitor.write(lastPlayer)
    else
        monitor.write("---")
    end
    
    -- Последний запрос
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
    
    -- Ответ ИИ
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
    
    -- Решение
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
    
    -- Статистика
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
-- ДВЕРЬ
-- ==========================

local function openDoor()
    log("Открытие двери...")
    redstone.setOutput(RELAY_SIDE, true)
    sleep(DOOR_OPEN_TIME)
    redstone.setOutput(RELAY_SIDE, false)
    log("Дверь закрыта")
end

-- ==========================
-- GROQ API
-- ==========================

local function callGroqAPI(userMessage)
    statusMessage = "Отправка запроса..."
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
    
    log("Отправка запроса к Groq API...")
    
    local response, err, errResponse = http.post(
        "https://api.groq.com/openai/v1/chat/completions",
        jsonBody,
        headers,
        true
    )
    
    if not response then
        log("ОШИБКА HTTP: " .. tostring(err))
        statusMessage = "Ошибка соединения"
        updateMonitor()
        
        if errResponse then
            local errorBody = errResponse.readAll()
            errResponse.close()
            log("Тело ошибки: " .. errorBody)
        end
        
        return nil, "Ошибка соединения с API"
    end
    
    local responseBody = response.readAll()
    response.close()
    
    if not responseBody or responseBody == "" then
        log("ОШИБКА: Пустой ответ от API")
        statusMessage = "Пустой ответ от API"
        updateMonitor()
        return nil, "Пустой ответ от сервера"
    end
    
    local data = decodeJSON(responseBody)
    
    if not data then
        log("ОШИБКА: Невозможно распарсить JSON")
        log("Тело ответа: " .. responseBody)
        statusMessage = "Ошибка парсинга JSON"
        updateMonitor()
        return nil, "Невозможно распарсить ответ"
    end
    
    if data.error then
        log("ОШИБКА API: " .. tostring(data.error.message))
        statusMessage = "Ошибка API"
        updateMonitor()
        return nil, data.error.message
    end
    
    if not data.choices or #data.choices == 0 then
        log("ОШИБКА: Нет вариантов ответа")
        statusMessage = "Нет ответа от ИИ"
        updateMonitor()
        return nil, "Нет вариантов ответа"
    end
    
    local aiResponse = data.choices[1].message.content
    
    if not aiResponse or aiResponse == "" then
        log("ОШИБКА: Пустой ответ от ИИ")
        statusMessage = "Пустой ответ от ИИ"
        updateMonitor()
        return nil, "Пустой ответ от ИИ"
    end
    
    log("Получен ответ от ИИ")
    statusMessage = "Готов"
    
    return aiResponse, nil
end

-- ==========================
-- ОБРАБОТКА РЕШЕНИЯ
-- ==========================

local function processAIResponse(response, player)
    local decision = nil
    
    if response:find("OPEN") then
        decision = "OPEN"
    elseif response:find("DENY") then
        decision = "DENY"
    else
        decision = "DENY"
        log("ВНИМАНИЕ: Ответ не содержит OPEN или DENY, автоматически DENY")
    end
    
    local cleanResponse = response:gsub("OPEN", ""):gsub("DENY", ""):gsub("%s+$", "")
    
    lastDecision = decision
    lastResponse = cleanResponse
    
    chatBox.sendMessage(cleanResponse, player)
    
    if decision == "OPEN" then
        statistics.opens = statistics.opens + 1
        openDoor()
        log("Решение: ОТКРЫТЬ дверь для " .. player)
    else
        statistics.denies = statistics.denies + 1
        log("Решение: ОТКАЗАТЬ игроку " .. player)
    end
    
    log("Игрок: " .. player .. " | Запрос: " .. lastRequest .. " | Решение: " .. decision)
    
    updateMonitor()
    
    return decision
end

-- ==========================
-- ОБРАБОТКА СООБЩЕНИЙ
-- ==========================

local function handleChatMessage(player, message)
    if player ~= PLAYER_NAME then
        log("Игнорируем сообщение от " .. player .. " (не авторизован)")
        chatBox.sendMessage("Доступ запрещён.", player)
        return
    end
    
    lastPlayer = player
    lastRequest = message
    lastResponse = ""
    lastDecision = ""
    
    updateMonitor()
    
    log("Получено сообщение от " .. player .. ": " .. message)
    
    local aiResponse, err = callGroqAPI(message)
    
    if not aiResponse then
        log("ОШИБКА при запросе к API: " .. tostring(err))
        chatBox.sendMessage("Извините, произошла техническая ошибка. Попробуйте позже.", player)
        lastResponse = "Техническая ошибка"
        lastDecision = "ERROR"
        updateMonitor()
        return
    end
    
    addToHistory("user", message)
    addToHistory("assistant", aiResponse)
    
    processAIResponse(aiResponse, player)
end

-- ==========================
-- ГЛАВНЫЙ ЦИКЛ
-- ==========================

local function mainLoop()
    log("Запуск главного цикла...")
    statusMessage = "Готов"
    updateMonitor()
    
    while true do
        local event, player, message = os.pullEvent("chat")
        
        if event == "chat" and player and message then
            local success, err = pcall(handleChatMessage, player, message)
            
            if not success then
                log("КРИТИЧЕСКАЯ ОШИБКА в handleChatMessage: " .. tostring(err))
                statusMessage = "Ошибка обработки"
                updateMonitor()
            end
        end
    end
end

-- ==========================
-- ЗАПУСК СИСТЕМЫ
-- ==========================

local function main()
    term.clear()
    term.setCursorPos(1, 1)
    
    print("==========================")
    print("     AI GUARD SYSTEM      ")
    print("==========================")
    print("")
    
    log("AI Guard запущен")
    
    local success, err = pcall(initializePeripherals)
    if not success then
        log("ОШИБКА инициализации: " .. tostring(err))
        error(err)
    end
    
    loadHistory()
    
    updateMonitor()
    
    log("Система готова к работе")
    log("Авторизованный игрок: " .. PLAYER_NAME)
    
    local success, err = pcall(mainLoop)
    
    if not success then
        log("КРИТИЧЕСКАЯ ОШИБКА: " .. tostring(err))
        statusMessage = "Критическая ошибка"
        updateMonitor()
        error(err)
    end
end

-- ==========================
-- ТОЧКА ВХОДА
-- ==========================

local success, err = pcall(main)

if not success then
    term.clear()
    term.setCursorPos(1, 1)
    print("КРИТИЧЕСКАЯ ОШИБКА:")
    print(err)
    log("Программа аварийно завершена: " .. tostring(err))
end
