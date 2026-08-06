-- ==========================
-- Alarm System
-- CCTweaked + Advanced Peripherals
-- ==========================

local PLAYER = "Sazaren783"      -- Ник игрока
local RADIUS = 6                 -- Радиус обнаружения

-- Поиск детектора
local detector
for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    if t == "playerDetector" or t == "player_detector" then
        detector = peripheral.wrap(name)
        break
    end
end

if not detector then
    error("Player Detector не найден!")
end

-- Подключение монитора
local monitor = peripheral.wrap("monitor_2")

if not monitor then
    print("WARNING: Monitor not found!")
end

-- Поиск всех колонок
local speakers = {}

for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "speaker" then
        table.insert(speakers, peripheral.wrap(name))
    end
end

if #speakers == 0 then
    error("Колонки не найдены!")
end

-- Загружаем аудио
local decoder = require("cc.audio.dfpwm").make_decoder()

-- Функция для обновления монитора
local function updateMonitor(playerInfo, isAlarm)
    if not monitor then return end
    
    monitor.clear()
    monitor.setTextScale(0.5)
    
    local w, h = monitor.getSize()
    
    -- Заголовок
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.yellow)
    monitor.write("=== SECURITY SYSTEM ===")
    
    -- Время
    monitor.setCursorPos(1, 2)
    monitor.setTextColor(colors.white)
    monitor.write("Time: " .. textutils.formatTime(os.time(), true))
    
    monitor.setCursorPos(1, 3)
    monitor.write("Radius: " .. RADIUS .. " blocks")
    
    -- Статус
    monitor.setCursorPos(1, 5)
    if isAlarm then
        monitor.setTextColor(colors.red)
        monitor.write("!!! ALARM !!!")
    else
        monitor.setTextColor(colors.green)
        monitor.write("System Active")
    end
    
    -- Информация об игроке
    if playerInfo then
        monitor.setCursorPos(1, 7)
        monitor.setTextColor(colors.orange)
        monitor.write("Detected: " .. playerInfo.name)
        
        monitor.setCursorPos(1, 9)
        monitor.setTextColor(colors.white)
        monitor.write("Position:")
        monitor.setCursorPos(1, 10)
        monitor.write(string.format("  X: %.1f", playerInfo.x))
        monitor.setCursorPos(1, 11)
        monitor.write(string.format("  Y: %.1f", playerInfo.y))
        monitor.setCursorPos(1, 12)
        monitor.write(string.format("  Z: %.1f", playerInfo.z))
        
        monitor.setCursorPos(1, 14)
        monitor.write(string.format("Health: %.1f / %.1f", playerInfo.health or 0, playerInfo.maxHealth or 20))
        
        monitor.setCursorPos(1, 15)
        monitor.write(string.format("Hunger: %.1f / 20", playerInfo.food or 0))
        
        -- Измерение
        if playerInfo.dimension then
            monitor.setCursorPos(1, 17)
            monitor.write("Dimension:")
            monitor.setCursorPos(1, 18)
            local dim = playerInfo.dimension:match("([^:]+)$") or playerInfo.dimension
            monitor.write("  " .. dim)
        end
        
        -- Активный предмет
        if playerInfo.heldItem then
            monitor.setCursorPos(1, 20)
            monitor.setTextColor(colors.cyan)
            monitor.write("Holding: " .. playerInfo.heldItem)
        end
        
        -- Броня
        if playerInfo.armor then
            monitor.setCursorPos(1, 22)
            monitor.setTextColor(colors.lightBlue)
            monitor.write("Armor:")
            local armorY = 23
            for slot, item in pairs(playerInfo.armor) do
                monitor.setCursorPos(1, armorY)
                monitor.write("  " .. slot .. ": " .. item)
                armorY = armorY + 1
            end
        end
    else
        monitor.setCursorPos(1, 7)
        monitor.setTextColor(colors.gray)
        monitor.write("No players detected")
    end
    
    -- Последнее обновление
    monitor.setCursorPos(1, h)
    monitor.setTextColor(colors.gray)
    monitor.write("Updated: " .. os.date("%H:%M:%S"))
end

local function playAlarm()
    local file = fs.open("ALARM.dfpwm", "rb")
    if not file then return end

    while true do
        local chunk = file.read(16 * 1024)

        if not chunk then
            file.close()
            return
        end

        local buffer = decoder(chunk)

        for _, speaker in ipairs(speakers) do
            while not speaker.playAudio(buffer, 1.0) do
                os.pullEvent("speaker_audio_empty")
            end
        end
    end
end

-- Функция для получения детальной информации об игроке
local function getPlayerDetails(playerName)
    if not detector.getPlayerPos then
        return {name = playerName}
    end
    
    local pos = detector.getPlayerPos(playerName)
    if not pos then return {name = playerName} end
    
    local info = {
        name = playerName,
        x = pos.x,
        y = pos.y,
        z = pos.z
    }
    
    -- Получаем дополнительную информацию если доступно
    if detector.getPlayer then
        local details = detector.getPlayer(playerName)
        if details then
            info.health = details.health
            info.maxHealth = details.maxHealth
            info.food = details.food
            info.dimension = details.dimension
            
            -- Активный предмет
            if details.heldItem and details.heldItem.name then
                info.heldItem = details.heldItem.displayName or details.heldItem.name
            end
            
            -- Броня
            if details.armor then
                info.armor = {}
                for _, piece in ipairs(details.armor) do
                    if piece and piece.name then
                        local slot = piece.slot or "unknown"
                        info.armor[slot] = piece.displayName or piece.name
                    end
                end
            end
        end
    end
    
    return info
end

while true do
    local players = detector.getPlayersInRange(RADIUS)

    local found = false
    local targetPlayer = nil

    for _, p in ipairs(players) do
        if p == PLAYER then
            found = true
            targetPlayer = getPlayerDetails(p)
            break
        end
    end

    if found then
        updateMonitor(targetPlayer, true)
        
        repeat
            playAlarm()

            players = detector.getPlayersInRange(RADIUS)
            found = false

            for _, p in ipairs(players) do
                if p == PLAYER then
                    found = true
                    targetPlayer = getPlayerDetails(p)
                    break
                end
            end
            
            updateMonitor(targetPlayer, true)
        until not found
        
        updateMonitor(nil, false)
    else
        updateMonitor(nil, false)
    end

    sleep(0.2)
end