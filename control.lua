-- If only you could rotate locomotives that where connected this mod would be so much easier.

local movingstate = {
	[defines.train_state.on_the_path] = true,
	[defines.train_state.path_lost] = false,
	[defines.train_state.no_schedule] = false,
	[defines.train_state.no_path] = false,
	[defines.train_state.arrive_signal] = true,
	[defines.train_state.wait_signal] = true,
	[defines.train_state.arrive_station] = true,
	[defines.train_state.wait_station] = false,
	[defines.train_state.manual_control_stop] = false,
	[defines.train_state.manual_control] = false,
}

local function rotate(loco)
	local back = loco.disconnect_rolling_stock(defines.rail_direction.back)
	local front = loco.disconnect_rolling_stock(defines.rail_direction.front)
	local ret = loco.rotate()
	-- @todo: Check if this needs to be inversed due to rotate or not?
	if back then loco.connect_rolling_stock(defines.rail_direction.back) end
	if front then loco.connect_rolling_stock(defines.rail_direction.front) end
	return ret
end

script.on_init(function()
	global.movingstate = global.movingstate or {}
	global.lastmode = global.lastmode or {}
end)

script.on_event(defines.events.on_train_created, function (event)
	if event.old_train_id_1 then -- We can ignore old_train_id_2 since the first old id is the one that gets its stuff copied.
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

script.on_nth_tick(10, function()
	local trains = game.surfaces[1].get_trains()
	for _,train in pairs(trains) do
		local moving = train.speed ~= 0 --@todo: Maybe see slow moving as stopped as well?
		if moving ~= global.movingstate[train.id] then
			global.movingstate[train.id] = moving
			global.lastmode[train.id] = train.manual_mode
			if moving then
				-- figure out which locos are facing the wrong way
				-- I currently know of no way to reliably tell which locomotives are moving forward and visa versa.
				game.print("f: " .. train.front_stock.unit_number .. " b: " .. train.back_stock.unit_number)
				for _,w in pairs(train.locomotives) do
					for k,v in pairs(w) do
						game.print(k .. ":" .. v.unit_number .. ": " .. v.orientation)
					end
				end
				for _,v in pairs(train.carriages) do
					if v.type == "locomotive" then
						game.print(v.unit_number .. ": " .. v.orientation)
					end
				end
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
	end
end)

-- @todo: I may have to do this stuff in on-tick and just check train speed/direction then
--[[
script.on_event(defines.events.on_train_changed_state, function(event)
	local train = event.train
	if train.state == defines.train_state.manual_control or train.state == defines.train_state.manual_control_stop then
		return
	end
	if event.old_state == defines.train_state.manual_control or event.old_state == defines.train_state.manual_control_stop then
		return
	end
	game.print("f:" .. train.front_stock.unit_number)
	game.print("b:" .. train.back_stock.unit_number)
	if movingstate[train.state] ~= global.movingstate[train.id] then
		global.movingstate[train.id] = movingstate[train.state]
		global.lastmode[train.id] = train.manual_mode
		if movingstate[train.state] then
			for _, loco in pairs(train.locomotives.back_movers) do
				game.print("l" .. loco.unit_number .. ":" .. serpent.line(loco.train.riding_state))
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
--]]