data:extend({
	-- Startup

	-- Global
	{
		type = "bool-setting",
		name = "Noxys_Multidirectional_Trains-enabled",
		setting_type = "runtime-global",
		default_value = true,
		order = "a",
	},
	{
		type = "int-setting",
		name = "Noxys_Multidirectional_Trains-on_nth_tick",
		setting_type = "runtime-global",
		minimum_value = 1,
		default_value = 8,
		maximum_value = 600,
		order = "b",
	},

	-- Per user

})
