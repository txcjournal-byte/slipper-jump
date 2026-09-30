--!strict
-- Tutoriál pro nové hráče (5 kroků).

return {
	Steps = {
		{ Text = "Walk to the pier!", Target = "Pier" },
		{ Text = "Hold JUMP and let go in the green zone!", Target = "Pier" },
		{ Text = "You found an item! Go to your house.", Target = "House" },
		{ Text = "Collect your money!", Target = "PiggyBank" },
		{ Text = "Buy better slippers at the SHOP!", Target = "Shop" },
	},
	FirstItemRarity = "Uncommon",
	ShopMoney = 100, -- dostane před krokem 5, aby si hned koupil Beach Blue Slippers
}
