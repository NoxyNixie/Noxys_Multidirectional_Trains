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

script.on_nth_tick(15, function()
	local trains = game.surfaces[1].get_trains()
	for _,train in pairs(trains) do
		local id = train.id
		local rotated = false
		local moving = train.speed ~= 0
		if moving ~= global.movingstate[id] then
			local global = global
			global.movingstate[id] = moving
			local manual_mode = train.manual_mode
			if moving then -- Started moving: figure out which locos are facing the wrong way.
				if not manual_mode then
					for _,w in pairs(train.locomotives) do
						for _,loco in pairs(w) do
							if loco.speed < 0 then
								global[loco.unit_number] = true
								rotate(loco)
								rotated = true
								train = loco.train
							end
						end
					end
				end
			else -- No longer moving. Revert the train to its neutral state.
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
			end
			if rotated then
				train.manual_mode = manual_mode
			end
		end
	end
end)