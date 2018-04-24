local function rotate(loco)
	-- @todo: This is a hack since you can't rotate stock when it is connected.
	loco.disconnect_rolling_stock(defines.rail_direction.back)
	loco.disconnect_rolling_stock(defines.rail_direction.front)
	loco.rotate()
	-- Try to reconnect
	loco.connect_rolling_stock(defines.rail_direction.back)
	loco.connect_rolling_stock(defines.rail_direction.front)
end

script.on_init(function()
	global.movingstate = {}
end)

script.on_event(defines.events.on_train_created, function (event)
	if event.old_train_id_1 then -- We can ignore old_train_id_2 since the first old id is the one that gets its stuff copied.
		-- Train changed
		global.movingstate[event.train.id] = global.movingstate[event.old_train_id_1]
		global.movingstate[event.old_train_id_1] = nil
	else
		-- Train created
		global.movingstate[event.train.id] = false
	end
end)

local config = {}

local function cache_settings()
	config.enabled     = settings.global["Noxys_Multidirectional_Trains-enabled"].value
	config.on_nth_tick = settings.global["Noxys_Multidirectional_Trains-on_nth_tick"].value
end

cache_settings()

local function train_rotate(train)
	local rotated = false
	local manual_mode = train.manual_mode
	for _,locos in pairs(train.locomotives) do
		for _,loco in pairs(locos) do
			if loco.speed < 0 then
				if not global[loco.unit_number] then -- prevent double rotates
					global[loco.unit_number] = true
					rotate(loco)
					rotated = true
					train = loco.train
				end
			end
		end
	end
	if rotated then
		train.manual_mode = manual_mode
	end
end

local function train_unrotate(train)
	local rotated = false
	local manual_mode = train.manual_mode
	for _, locos in pairs(train.locomotives) do
		for _, loco in pairs(locos) do
			if global[loco.unit_number] then
				rotate(loco)
				rotated = true
				global[loco.unit_number] = nil
				train = loco.train
			end
		end
	end
	if rotated then
		train.manual_mode = manual_mode
	end
end

local function update_settings(event)
	if event.setting == "Noxys_Multidirectional_Trains-enabled" then
		config.enabled     = settings.global["Noxys_Multidirectional_Trains-enabled"].value
		if config.enabled == false then
			-- revert rotated trains
			local trains = game.surfaces[1].get_trains()
			for _,train in pairs(trains) do
				train_unrotate(train)
			end
		end
	end
	if event.setting == "Noxys_Multidirectional_Trains-on_nth_tick" then
		config.on_nth_tick = settings.global["Noxys_Multidirectional_Trains-on_nth_tick"].value
	end
end

script.on_event({defines.events.on_runtime_mod_setting_changed}, update_settings)

script.on_event(defines.events.on_tick, function(event)
	if not config.enabled then return end
	if event.tick % config.on_nth_tick ~= 0 then return end
	local trains = game.surfaces[1].get_trains()
	for _,train in pairs(trains) do
		if not train or not train.valid then return end
		local id = train.id
		local moving = train.speed ~= 0
		if moving ~= global.movingstate[id] then
			local global = global
			global.movingstate[id] = moving
			if moving then -- Started moving: figure out which locos are facing the wrong way.
				if not train.manual_mode then
					train_rotate(train)
				end
			else -- No longer moving. Revert the train to its neutral state.
				train_unrotate(train)
			end
		end
	end
end)