-- Алмазный таймер защиты
-- ComputerCraft + Advanced Peripherals

local dfpwm = require("cc.audio.dfpwm")

local speaker = peripheral.find("speaker")
local chat = peripheral.find("chatBox")
local monitor = peripheral.find("monitor")

local chest = peripheral.wrap("back")

local decoder = dfpwm.make_decoder()

local AUDIO = "alarm.dfpwm"

local running = true
local playing = false

local lastDiamonds = 0
local remaining = 0


-- вывод на монитор
local function updateMonitor(diamonds, time)
    if not monitor then return end

    monitor.clear()
    monitor.setCursorPos(1,1)

    monitor.write("АЛМАЗНАЯ ЗАЩИТА")
    
    monitor.setCursorPos(1,3)
    monitor.write("Алмазов: "..diamonds)

    monitor.setCursorPos(1,4)
    monitor.write(
        string.format(
            "Время: %.1f сек",
            time
        )
    )

    if time <= 0 then
        monitor.setCursorPos(1,6)
        monitor.write("!!! ТРЕВОГА !!!")
    else
        monitor.setCursorPos(1,6)
        monitor.write("Система активна")
    end
end


local function sendChat(msg)
    if chat then
        chat.sendMessage(msg)
    end
end


-- запуск звука
local function playAlarm()

    if playing then return end

    playing = true

    sendChat(
        "§c[ТРЕВОГА] Закончились алмазы!"
    )

    while playing do

        if not fs.exists(AUDIO) then
            print("Нет файла "..AUDIO)
            break
        end


        local file = fs.open(AUDIO,"rb")

        while playing do

            local chunk = file.read(16 * 1024)

            if not chunk then
                break
            end

            local buffer = decoder(chunk)

            while not speaker.playAudio(buffer) do
                os.pullEvent("speaker_audio_empty")
            end

        end

        file.close()
    end
end



-- остановка звука
local function stopAlarm()

    if playing then
        playing = false

        if speaker then
            speaker.stop()
        end

        sendChat(
            "§a[СИСТЕМА] Алмаз обнаружен. Тревога отключена."
        )
    end

end



while running do

    local diamonds = 0


    -- считаем алмазы в сундуке
    if chest then

        for slot,item in pairs(chest.list()) do

            if item.name ==
            "minecraft:diamond" then

                diamonds = diamonds + item.count

            end

        end

    end


    -- 1 алмаз = 0.2 секунды
    remaining = diamonds * 0.2


    -- новый алмаз появился
    if diamonds > lastDiamonds then

        stopAlarm()

        sendChat(
            "§a+ Алмаз добавлен. Время восстановлено."
        )

    end


    lastDiamonds = diamonds



    updateMonitor(
        diamonds,
        remaining
    )



    if remaining <= 0 then

        if not playing then
            parallel.waitForAny(
                playAlarm,
                function()
                    while true do
                        sleep(1)
                    end
                end
            )
        end

    end



    sleep(0.2)

end
