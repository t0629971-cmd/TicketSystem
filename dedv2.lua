-- Almaznaya zaschita
-- ComputerCraft + Advanced Peripherals

local dfpwm = require("cc.audio.dfpwm")

local speaker = peripheral.find("speaker")
local chat = peripheral.find("chatBox")
local monitor = peripheral.find("monitor")

local chest = peripheral.wrap("back")

local decoder = dfpwm.make_decoder()

local AUDIO = "alarm.dfpwm"

local playing = false

local lastDiamonds = 0
local remaining = 0


local function updateMonitor(diamonds, time)

    if not monitor then return end

    monitor.clear()
    monitor.setCursorPos(1,1)

    monitor.write("ALMAZNAYA ZASCHITA")

    monitor.setCursorPos(1,3)
    monitor.write("Almazov: "..diamonds)

    monitor.setCursorPos(1,4)
    monitor.write(
        string.format(
            "Vremya: %.1f sek",
            time
        )
    )

    monitor.setCursorPos(1,6)

    if time <= 0 then
        monitor.write("!!! TREVOGA !!!")
    else
        monitor.write("Sistema aktivna")
    end

end



local function sendChat(msg)

    if chat then
        chat.sendMessage(msg)
    end

end



local function stopAlarm()

    if playing then

        playing = false

        if speaker then
            speaker.stop()
        end

        sendChat(
            "[SYSTEMA] Almaz nayden. Trevoga otklyuchena."
        )

    end

end




local function playAlarm()

    if playing then return end

    playing = true

    sendChat(
        "[TREVOGA] Zakonchilis almazы!"
    )


    while playing do

        local file = fs.open(AUDIO,"rb")

        if not file then
            print("Net faila "..AUDIO)
            break
        end


        while playing do

            local data = file.read(16384)

            if not data then
                break
            end


            local buffer = decoder(data)


            while not speaker.playAudio(buffer) do

                os.pullEvent("speaker_audio_empty")

            end

        end


        file.close()

    end

end





while true do

    local diamonds = 0


    if chest then

        for slot,item in pairs(chest.list()) do

            if item.name == "minecraft:diamond" then

                diamonds = diamonds + item.count

            end

        end

    end



    -- 1 almaz = 0.2 sekundy

    remaining = diamonds * 0.2



    -- obnaruzhen noviy almaz

    if diamonds > lastDiamonds then

        stopAlarm()

        sendChat(
            "[SYSTEMA] Dobavlen almaz. Vremya vosstanovleno."
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
