-- ==========================
-- Alarm System
-- CC:Tweaked + Advanced Peripherals
-- ==========================

local PLAYER = "Sazaren783"      -- Ник игрока
local RADIUS = 6              -- Радиус обнаружения

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

local function playAlarm()
    local file = fs.open("ALARM.dfpwm", "rb")

    while file do
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

while true do
    local players = detector.getPlayersInRange(RADIUS)

    local found = false

    for _, p in ipairs(players) do
        if p == PLAYER then
            found = true
            break
        end
    end

    if found then
        repeat
            playAlarm()

            players = detector.getPlayersInRange(RADIUS)
            found = false

            for _, p in ipairs(players) do
                if p == PLAYER then
                    found = true
                    break
                end
            end
        until not found
    end

    sleep(0.2)
end
