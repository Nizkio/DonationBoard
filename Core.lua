--[[
 
	Author @Nizkio 
	Thanks to @VibeNemo & @twinqle for the original model
	Last updated: 01/23/2023

--]]

--> Code is here. Only edit if you're an experienced programmer! Keep going to Configuration to edit the donation ID's!
local Luna = nil
local EssentialsModule

local Works, Failed = pcall(function()
	Luna = require(game:GetService("ServerScriptService").Modules.LunaLoader)
end)

if Works then
	Failed = Works
else
	warn(Failed)
end
-----------------------------------------------------------------------------------------------------------
--> Configuration

local DATA_KEY = "default"
local GUI_FACE = "Front"
local DISPLAY_AMOUNT = 30 -- Recommended maximum is 100, you can risk lagging your game or making the board messy if you exceed this limit
local REFRESH_RATE = 60

local DONATION_OPTIONS = require(script.Parent.Products)
-----------------------------------------------------------------------------------------------------------
--> Code starts here. Only edit if you're an experienced programmer!
script.Parent.DonationBoard.Donations:Destroy()

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local gui = script.Donations
local face = Enum.NormalId[GUI_FACE]
local runService = game:GetService('RunService')
local Player = require(script.Player)

local eve = Instance.new("RemoteEvent")
eve.Name = "DonationEvent"
eve.Parent = ReplicatedStorage

local cache = {}

local tmType = Enum.ThumbnailType.HeadShot
local tmSize = Enum.ThumbnailSize.Size420x420

local donations = DataStoreService:GetOrderedDataStore(DATA_KEY)

if not face then error("Invalid GUI_FACE: " .. GUI_FACE) else gui.Face = face end

local function getName(id)
	for cachedId, name in pairs (cache) do
		if cachedId == id then
			return name
		end
	end
	local success, result = pcall(function()
		return Players:GetNameFromUserIdAsync(id)
	end)
	if success then
		cache[id] = result
		return result
	else
		warn(result .. "\nId: " .. id)
		return "N/A"
	end
end

local function findAmountById(id)
	for _, donationInfo in pairs (DONATION_OPTIONS) do
		if donationInfo.Id == id then
			print(donationInfo.Amount)
			return donationInfo.Amount
		end
	end
	warn("Couldn't find donation amount for product ID " .. id)
	return 0
end

local function clearList(list)
	for _, v in pairs (list:GetChildren()) do
		if v:IsA("Frame") then v:Destroy() end
	end
end

local function updateAllClients(page)
	eve:FireAllClients("update", page)
end

local function updateInternalBoard(updateClientsAfter)
	local sorted = donations:GetSortedAsync(false, math.clamp(DISPLAY_AMOUNT, 0, 250), 1)
	if sorted then
		local page = sorted:GetCurrentPage()
		local clientDataPacket = {}
		clearList(gui.Main.Leaderboard.List)
		for rank, data in ipairs(page) do
			local userId = data.key
			local username = getName(data.key)
			local icon, isReady = Players:GetUserThumbnailAsync(userId, tmType, tmSize)
			local amountDonated = data.value .. "  Robux (R$)"

			local clone = gui.Main.Leaderboard.Template:Clone()
			clone.Icon.Image = icon
			clone.Rank.Text = "#" .. rank
			clone.Robux.Text = amountDonated
			clone.Username.Text = username
			clone.LayoutOrder = rank
			clone.Visible = true
			clone.Parent = gui.Main.Leaderboard.List

			table.insert(clientDataPacket, {
				["name"] = username,
				["icon"] = icon,
				["amount"] = amountDonated,
				["rank"] = rank
			})

			spawn(function()
				local Works, Failed = pcall(function()
					if rank == 1 then
						clone.Rank.Text = '<font color="#ffd600">' .. "#" .. rank .. '</font>'
						script.Parent.Top.Humanoid:ApplyDescription(game.Players:GetHumanoidDescriptionFromUserId(userId))
						script.Parent.Top.Tags.Container.pName.Text = username
					elseif rank == 2 then
						clone.Rank.Text = '<font color="#C0C0C0">' .. "#" .. rank .. '</font>'
					elseif rank == 3 then
						clone.Rank.Text = '<font color="#8c7854">' .. "#" .. rank .. '</font>'
					end
				end)

				if Works then
					Failed = Works
				else
					warn(script:GetFullName().." Errored: ", tostring(Failed))
				end
			end)
		end

		if updateClientsAfter then
			updateAllClients(clientDataPacket)
		end
	else
		warn("No data available for leaderboard refresh!")
	end
end

local function createButtonsInternal()
	for pos, donationInfo in pairs (DONATION_OPTIONS) do
		local clone = gui.Main.Donate.Template:Clone()

		clone.Id.Value = donationInfo.Id
		clone.Info.Text = "<b>" .. donationInfo.Amount .. "</b> Robux (R$)"

		clone.Visible = true
		clone.LayoutOrder = pos

		clone.Parent = gui.Main.Donate.List
	end
end

local NotificationModule = require(script:WaitForChild("NotificationModule"))

local function processReceipt(receiptInfo) 
	local donatedAmount = findAmountById(receiptInfo.ProductId)
	local id = receiptInfo.PlayerId

	local TotaldonatedAmount

	local success, err = pcall(function()
		donations:UpdateAsync(id, function(previousData)
			if previousData then
				TotaldonatedAmount = (previousData + donatedAmount)
				return previousData + donatedAmount
			else
				return donatedAmount
			end
		end)
	end)

	local player = Players:GetPlayerByUserId(id)

	if not success then
		if player then
			eve:FireClient(player, "Error", "There was an error processing your purchase. You have not been charged. Error: " .. err)
		end
		warn("Error handling " .. id .. "'s purchase: " .. err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if player then
		eve:FireClient(player, "Success", "Thanks for your generous donation!")
		local success, err = pcall(function()
			updateInternalBoard(true)
		end)
		if success then
			NotificationModule.NotifyAll(player.DisplayName.." Just Donated!", player.DisplayName.." (@"..player.Name..") Just Donated: "..donatedAmount.."! | ("..player.DisplayName.."'s Total Amount: "..TotaldonatedAmount..")")
		else
			warn("Failed To Update Donation Board Due To Error: "..err)
			NotificationModule.NotifyAll(player.DisplayName.." Just Donated!", player.DisplayName.." (@"..player.Name..") Just Donated: "..donatedAmount.." But The Board Failed To Update Don't Worry Your Amount Will Be Added To The Database! | ("..player.DisplayName.."'s Total Amount: "..TotaldonatedAmount..")")
		end
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onPlayerAdded(plr)
	local pGui = plr:WaitForChild("PlayerGui", 5)
	if pGui then
		for _, board in pairs (script.Parent:GetChildren()) do
			if board.Name == "DonationBoard" then
				local clone = gui:Clone()
				clone.Adornee = board
				clone.Parent = pGui
			end
		end 
		return true
	end
	warn("Couldn't find PlayerGui for " .. plr.Name .. ":" .. plr.UserId)
end

createButtonsInternal()
updateInternalBoard(false)

spawn(function()
	local Works, Error = pcall(function()
		spawn(function()
			MarketplaceService.ProcessReceipt = processReceipt
		end)
	end)

	if Works then
		Error = Works
	else
		warn(script:GetFullName(), Error)
		wait()
		MarketplaceService.ProcessReceipt = processReceipt
	end
end)

for _, plr in pairs (Players:GetPlayers()) do
	onPlayerAdded(plr)
end
Players.PlayerAdded:Connect(onPlayerAdded)