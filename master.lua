local detector = peripheral.find("playerDetector")
local chatbox = peripheral.find("chatBox")

if not detector then
    error("Player Detector не найден!")
end

if not chatbox then
    error("Chat Box не найден!")
end

local target = "dio_brando3"
local radius = 4
local alerted = false

while true do
    local players = detector.getPlayersInRange(radius)

    local found = false

    for _, player in ipairs(players) do
        if player == target then
            found = true
            break
        end
    end

    if found and not alerted then
        chatbox.sendMessage("alert")
        alerted = true
    elseif not found then
        alerted = false
    end

    sleep(0.2)
end