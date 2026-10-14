-- Live Robux prices for the shop. Config holds the planned price; once a pass or product exists, Roblox's
-- price for this player (regional pricing, price experiments) comes from GetProductInfoAsync. Prices.sync
-- writes it into the catalog tables in place, so shop code that reads item.price shows the real number.
local MarketplaceService = game:GetService("MarketplaceService")

local Prices = {}

local listeners: { () -> () } = {}

-- passes / products: the game's Config.Passes / Config.Products (items with `id` and `price`).
function Prices.sync(passes: { [string]: any }, products: { [string]: any })
	task.spawn(function()
		local changed = false
		for _, set in ipairs({ { passes, Enum.InfoType.GamePass }, { products, Enum.InfoType.Product } }) do
			for _, item in pairs(set[1]) do
				if type(item) == "table" and type(item.id) == "number" and item.id ~= 0 then
					local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, item.id, set[2])
					if ok and type(info) == "table" and type(info.PriceInRobux) == "number" and info.PriceInRobux ~= item.price then
						item.price = info.PriceInRobux
						changed = true
					end
				end
			end
		end
		if changed then
			for _, fn in ipairs(listeners) do
				task.spawn(fn)
			end
		end
	end)
end

-- fn() after live prices replaced any planned ones (rebuild open shop pages).
function Prices.onChange(fn: () -> ())
	table.insert(listeners, fn)
end

return Prices
