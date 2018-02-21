-- If only you could rotate locomotives that where connected this mod would be so much easier.

local movingstate = {
	[defines.train_state.on_the_path] = true,
	[defines.train_state.path_lost] = true,
	[defines.train_state.no_schedule] = false,
	[defines.train_state.no_path] = false,
	[defines.train_state.arrive_signal] = true,
	[defines.train_state.wait_signal] = false,
	[defines.train_state.arrive_station] = true,
	[defines.train_state.wait_station] = false,
	[defines.train_state.manual_control_stop] = false,
	[defines.train_state.manual_control] = false,
}

local function rotate(loco)
	loco.disconnect_rolling_stock(defines.rail_direction.back)
	loco.disconnect_rolling_stock(defines.rail_direction.front)
	local ret = loco.rotate()
	loco.connect_rolling_stock(defines.rail_direction.back)
	loco.connect_rolling_stock(defines.rail_direction.front)
	return ret
end

script.on_init(function()
	global.movingstate = global.movingstate or {}
	global.lastmode = global.lastmode or {}
end)

script.on_event(defines.events.on_train_created, function (event)
	global.movingstate = global.movingstate or {}
	global.lastmode = global.lastmode or {}
	if event.old_train_id_1 then -- We can ignore the second one since the first old id is the one that gets its stuff copied.
		-- Train changed
		global.movingstate[event.train.id] = global.movingstate[event.old_train_id_1]
		global.movingstate[event.old_train_id_1] = nil
		global.lastmode[event.train.id] = global.lastmode[event.old_train_id_1]
		global.lastmode[event.old_train_id_1] = nil
		--@todo: current schedule id too?
	else
		-- Train created
		global.movingstate[event.train.id] = false
		global.lastmode[event.train.id] = true
	end
end)

script.on_event(defines.events.on_train_changed_state, function(event)
	local train = event.train
	if train.state == defines.train_state.manual_control or train.state == defines.train_state.manual_control_stop then
		return
	end
	if event.old_state == defines.train_state.manual_control or event.old_state == defines.train_state.manual_control_stop then
		return
	end
	if movingstate[train.state] ~= global.movingstate[train.id] then
		global.movingstate[train.id] = movingstate[train.state]
		global.lastmode[train.id] = train.manual_mode
		if movingstate[train.state] then
			for _, loco in pairs(train.locomotives.back_movers) do
				global[loco.unit_number] = rotate(loco)
				train = loco.train
			end
			train.manual_mode = global.lastmode[train.id]
		else
			for _, loco in pairs(train.locomotives.back_movers) do
				if global[loco.unit_number] then
					rotate(loco)
					global[loco.unit_number] = nil
					train = loco.train
				end
			end
			for _, loco in pairs(train.locomotives.front_movers) do
				if global[loco.unit_number] then
					rotate(loco)
					global[loco.unit_number] = nil
					train = loco.train
				end
			end
			train.manual_mode = global.lastmode[train.id]
		end
	end
end)