local settings_enabled = settings.global["Noxys_Multidirectional_Trains-enabled"].value
local settings_nth_tick = settings.global["Noxys_Multidirectional_Trains-on_nth_tick"].value
local settings_station_limits = settings.global["Noxys_Multidirectional_Trains-station_limits"].value

local function rotate(loco)
	-- todo: This is a hack since you can't rotate stock when it is connected.
	local disconnected_back = loco.disconnect_rolling_stock(defines.rail_direction.back)
	local disconnected_front = loco.disconnect_rolling_stock(defines.rail_direction.front)
	loco.rotate()
	if disconnected_back then
		loco.connect_rolling_stock(defines.rail_direction.front)
	end
	if disconnected_front then
		loco.connect_rolling_stock(defines.rail_direction.back)
	end
	-- Error handling removed since a meaningfull error message is difficult (or too noisy) to produce.
end

-- Rotate all locomotives to face driving direction, rotated locomotives are added to global.rotated_locos.
local function train_rotate(train)
	local manual_mode = train.manual_mode
	if manual_mode then return end -- never rotate manual mode trains
	for _,locos in pairs(train.locomotives) do
		for _,loco in pairs(locos) do
			if not global.rotated_locos[loco.unit_number] and loco.speed < 0 then -- prevent double rotates
				global.rotated_locos[loco.unit_number] = true
				rotate(loco)
				train = loco.train -- Ensure that this reference is valid for restoring manual mode.
			end
		end
	end
	if train.manual_mode ~= manual_mode then
		train.manual_mode = manual_mode
	end
end

-- Hack to get locomotive orientation through speed some ticks after it started moving.
local function on_nth_tick()
	for trainID, train in pairs(global.trains_to_rotate) do
		if train.valid then
			if train.speed ~= 0 then
				train_rotate(train)
				global.trains_to_rotate[trainID] = nil
			end
		else
			global.trains_to_rotate[trainID] = nil
		end
	end
	for stationID, station in pairs(global.station_limits) do
		if station.valid then
			station.trains_limit = 1
		end
		global.station_limits[stationID] = nil
	end
	-- Unsubscribe once all trains are rotated.
	if not next(global.trains_to_rotate) and not next(global.station_limits) then
		script.on_nth_tick(nil)
	end
end

-- Revert the rotated locomotives listed in global.rotated_locos.
local function train_unrotate(train)
	local manual_mode = train.manual_mode
	local station = train.station
	if settings_station_limits and station and station.trains_limit == 1 then
		station.trains_limit = 2
		global.station_limits[station.unit_number] = station
		script.on_nth_tick(settings_nth_tick, on_nth_tick)
	end
	for _, locos in pairs(train.locomotives) do
		for _, loco in pairs(locos) do
			if global.rotated_locos[loco.unit_number] then
				rotate(loco)
				global.rotated_locos[loco.unit_number] = nil
				train = loco.train -- Ensure that this reference is valid for restoring manual mode.
			end
		end
	end
	if train.manual_mode ~= manual_mode then
		train.manual_mode = manual_mode
	end
end

local function on_train_changed_state(event)
	local train = event.train
	if train.state == defines.train_state.wait_station or
		train.state == defines.train_state.no_path or
		train.state == defines.train_state.path_lost or
		(train.manual_mode and event.old_state ~= defines.train_state.manual_control_stop and
		event.old_state ~= defines.train_state.manual_control)
	then
		global.trains_to_rotate[train.id] = nil
		if not next(global.trains_to_rotate) and not next(global.station_limits) then
			script.on_nth_tick(nil)
		end
		train_unrotate(train)
	elseif not train.manual_mode and
		(event.old_state == defines.train_state.wait_station or
		event.old_state == defines.train_state.manual_control)
	then
		if (#train.locomotives.front_movers + #train.locomotives.back_movers) > 1 then
			global.trains_to_rotate[train.id] = train
			script.on_nth_tick(settings_nth_tick, on_nth_tick)
		end
	end
end

local function init_events()
	if settings_enabled then
		script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
	else
		script.on_event(defines.events.on_train_changed_state, nil)
	end
	if global.trains_to_rotate and next(global.trains_to_rotate) then
		script.on_nth_tick(settings_nth_tick, on_nth_tick)
	end
	if global.station_limits and next(global.station_limits) then
		script.on_nth_tick(settings_nth_tick, on_nth_tick)
	end
end

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
	if event.setting == "Noxys_Multidirectional_Trains-enabled" then
		settings_enabled = settings.global["Noxys_Multidirectional_Trains-enabled"].value
		if settings_enabled then
			script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
			script.on_nth_tick(settings_nth_tick, on_nth_tick)
		else
			script.on_event(defines.events.on_train_changed_state, nil)
			script.on_nth_tick(nil)
			-- Revert the rotated trains.
			for _, surface in pairs(game.surfaces) do
				local trains = surface.get_trains()
				for _,train in pairs(trains) do
				train_unrotate(train)
				end
			end
			-- Clean globals.
			global.rotated_locos = {}
			global.trains_to_rotate = {}
		end
	end
	if event.setting == "Noxys_Multidirectional_Trains-on_nth_tick" then
		settings_nth_tick = settings.global["Noxys_Multidirectional_Trains-on_nth_tick"].value
		script.on_nth_tick(nil)
		if next(global.trains_to_rotate) or next(global.station_limits) then
			script.on_nth_tick(settings_nth_tick, on_nth_tick)
		end
	end
	if event.setting == "Noxys_Multidirectional_Trains-station_limits" then
		settings_station_limits = settings.global["Noxys_Multidirectional_Trains-station_limits"].value
	end
end)

script.on_load(function()
	init_events()
end)

script.on_init(function()
	global.rotated_locos = global.rotated_locos or {}
	global.trains_to_rotate = global.trains_to_rotate or {}
	global.station_limits = global.station_limits or {}
	init_events()
end)

script.on_configuration_changed(function()
	global.rotated_locos = global.rotated_locos or {}
	global.trains_to_rotate = global.trains_to_rotate or {}
	global.station_limits = global.station_limits or {}
	init_events()
end)
