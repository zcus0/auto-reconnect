-- Pastikan layanan yang dibutuhkan siap
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

local OnlineRewardRemotes = ReplicatedStorage:WaitForChild("OnlineRewardRemotes")
local rewardRequest = OnlineRewardRemotes:WaitForChild("OnlineRewardRequest")
local rewardStateEvent = OnlineRewardRemotes:WaitForChild("OnlineRewardState")

-- 1. BAGIAN ANTI-AFK
LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    print("[Anti-AFK] Mencegah kick karena idle.")
end)

-- 2. FUNGSI UNTUK MENGECEK DAN MENGKLAIM REWARD
local function checkAndClaim(stateType, rewardData)
    if not rewardData or not rewardData.Rewards then return end
    
    for _, reward in ipairs(rewardData.Rewards) do
        if reward.Unlocked == true and reward.Claimed == false then
            print("[AutoClaim] Mengklaim Reward ID: " .. tostring(reward.RewardId))
            pcall(function()
                rewardRequest:FireServer("Claim", {
                    RewardId = tostring(reward.RewardId)
                })
            end)
            task.wait(0.5)
        end
    end
end

-- 3. TANGKAP RESPON DARI SERVER (Menyimak data State)
rewardStateEvent.OnClientEvent:Connect(function(stateType, rewardData)
    if stateType == "State" then
        checkAndClaim(stateType, rewardData)
    end
end)

-- 4. LOOP UTAMA (Meminta state berkala ke server)
task.spawn(function()
    while true do
        pcall(function()
            rewardRequest:FireServer("RequestState")
        end)
        -- Interval pengecekan setiap 30 detik
        task.wait(30)
    end
end)

print("Script Anti-AFK & Auto-Claim (Event-Based) Berhasil Dijalankan!")
