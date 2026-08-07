-- ==========================
-- Redstone Relay Test Script
-- ==========================

local RELAY_SIDE = "back"  -- Izmeni esli nado
local PULSE_DURATION = 2   -- Dlitel'nost' impulsa v sekundakh

print("==========================")
print("  REDSTONE RELAY TEST")
print("==========================")
print("")
print("Testing relay on side: " .. RELAY_SIDE)
print("Pulse duration: " .. PULSE_DURATION .. " seconds")
print("")

-- Proverka tekushchego sostoyaniya
print("Current state: " .. tostring(redstone.getOutput(RELAY_SIDE)))
print("")

-- Test 1: Odin impuls
print("[TEST 1] Sending single pulse...")
redstone.setOutput(RELAY_SIDE, true)
print("  Redstone ON: " .. tostring(redstone.getOutput(RELAY_SIDE)))
sleep(PULSE_DURATION)
redstone.setOutput(RELAY_SIDE, false)
print("  Redstone OFF: " .. tostring(redstone.getOutput(RELAY_SIDE)))
print("")

sleep(1)

-- Test 2: Tri korotkikh impulsa
print("[TEST 2] Sending 3 short pulses...")
for i = 1, 3 do
    print("  Pulse " .. i .. "...")
    redstone.setOutput(RELAY_SIDE, true)
    sleep(0.5)
    redstone.setOutput(RELAY_SIDE, false)
    sleep(0.5)
end
print("")

-- Test 3: Dlitel'nyy signal
print("[TEST 3] Long signal (5 seconds)...")
redstone.setOutput(RELAY_SIDE, true)
print("  Redstone ON")
sleep(5)
redstone.setOutput(RELAY_SIDE, false)
print("  Redstone OFF")
print("")

-- Proverka vsekh storon
print("[TEST 4] Checking all sides...")
local sides = {"top", "bottom", "left", "right", "front", "back"}
for _, side in ipairs(sides) do
    local output = redstone.getOutput(side)
    print("  " .. side .. ": " .. tostring(output))
end
print("")

-- Final check
print("==========================")
print("TEST COMPLETE!")
print("==========================")
print("")
print("If door didn't open, check:")
print("1. Relay configured correctly (Input/Output mode)")
print("2. Redstone wires connected")
print("3. Door mechanism working")
print("4. Correct side (" .. RELAY_SIDE .. ")")
