---- MOD SETTINGS ----
local Enabled = settings.global["Noxys_Multidirectional_Trains-enabled"].value
local Nth_tick = settings.global["Noxys_Multidirectional_Trains-on_nth_tick"].value

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "Noxys_Multidirectional_Trains-enabled" then
    Enabled = settings.global["Noxys_Multidirectional_Trains-enabled"].value
    if not Enabled then
			-- revert rotated trains
      for _, surface in pairs(game.surfaces) do
        local trains = surface.get_trains()
        for _,train in pairs(trains) do
          UnrotateTrain(train)
        end
      end
		end
  end
  if event.setting == "Noxys_Multidirectional_Trains-on_nth_tick" then
    Nth_tick = settings.global["Noxys_Multidirectional_Trains-on_nth_tick"].value
    script.on_nth_tick(nil)
    if next(global.trains_to_rotate) then
      script.on_nth_tick(Nth_tick, OnNthTick)
    end
  end
end)

---- ROTATE LOGIC ----
do
local function rotate(loco)
  -- log("DEBUG: rotating "..tostring(loco.backer_name) )
  local disconnected_back = loco.disconnect_rolling_stock(defines.rail_direction.back)
  local disconnected_front = loco.disconnect_rolling_stock(defines.rail_direction.front)
  loco.rotate()
  -- Only reconnect the side that was disconnected
  local reconnected_front = disconnected_front
  local reconnected_back = disconnected_back
  if disconnected_back then
    reconnected_back = loco.connect_rolling_stock(defines.rail_direction.front)
  end
  if disconnected_front then
    reconnected_front= loco.connect_rolling_stock(defines.rail_direction.back)
  end
  -- TODO: reconnect Error handling
  if disconnected_front and not reconnected_front then
    log("Error: Failed to reconnect front.")
  end
  if disconnected_back and not reconnected_back then
    log("Error: Failed to reconnect back.")
  end
end

-- rotate all locomotives to face driving direction
-- rotated locomotives are added to global.rotated_locos
function RotateTrain(train)
  local manual_mode = train.manual_mode

  if manual_mode then return end -- never rotate manual mode trains

  -- train becomes invalid when rotating carriages, updating to loco.train inside the loops allows working with the updated reference
  for _, movers in pairs(train.locomotives) do
    for _, loco in pairs(movers) do
      if not global.rotated_locos[loco.unit_number] and loco.speed < 0 then
        -- rotate_locos[#rotate_locos+1] = loco
        global.rotated_locos[loco.unit_number] = true
        rotate(loco)
        train = loco.train
      end
    end
  end

  -- setting train back to previous mode without check causes train to bounce between states
  if train.manual_mode ~= manual_mode then
    train.manual_mode = manual_mode
  end
end

-- rotate locomotives listed in global.rotated_locos
function UnrotateTrain(train)
  local manual_mode = train.manual_mode
  -- train becomes invalid when rotating carriages, updating to loco.train inside the loops allows working with the updated reference
  for _, movers in pairs(train.locomotives) do
    for _, loco in pairs(movers) do
      if global.rotated_locos[loco.unit_number] then
        rotate(loco)
        global.rotated_locos[loco.unit_number] = nil
        train = loco.train
      end
    end
  end

  -- setting train back to previous mode without check causes train to bounce between states
  if train.manual_mode ~= manual_mode then
    train.manual_mode = manual_mode
  end
end

end

---- TRAIN STATE CHANGED ----
do
function OnTrainStateChanged(event)
  local train = event.train
  if train.state == defines.train_state.wait_station or (train.manual_mode and event.old_state <= 8) then -- wait or automatic > manual
    -- players can hop into waiting trains, switch to manual and start driving
    -- without clearing global.trains_to_rotate nth_rick would incorrectly rotate shortly afterwards
    global.trains_to_rotate[train.id] = nil
    if not next(global.trains_to_rotate) then
      script.on_nth_tick(nil)
    end

    UnrotateTrain(train)

  elseif not train.manual_mode and (event.old_state == defines.train_state.wait_station or event.old_state == defines.train_state.manual_control) then -- wait > automatic or manual > automatic
    -- train left station > check multi loco train in n ticks for rotation
    if (#train.locomotives.front_movers + #train.locomotives.back_movers) > 1 then
      global.trains_to_rotate[train.id] = train
      script.on_nth_tick(Nth_tick, OnNthTick)
    end
  end
end

end

-- dirty hack to get locomotive orientation through speed some ticks after it started moving
function OnNthTick(NthTickEvent)
  for trainID, train in pairs(global.trains_to_rotate) do
    if train.valid then
      if train.speed ~= 0 then
        RotateTrain(train)
        global.trains_to_rotate[trainID] = nil
      end
    else
      -- remove invalid train
      global.trains_to_rotate[trainID] = nil
      -- log("DEBUG: removed invalid train "..trainID)
    end
  end

  -- unsubscribe once all trains are rotated
  if not next(global.trains_to_rotate) then
    script.on_nth_tick(nil)
  end
end

---- INIT ----
do
local function init_events()
  script.on_event(defines.events.on_train_changed_state, OnTrainStateChanged)
  if next(global.trains_to_rotate) then
    script.on_nth_tick(Nth_tick, OnNthTick)
  end
end

script.on_load(function()
  init_events()
end)

script.on_init(function()
  global.rotated_locos = global.rotated_locos or {}
  global.trains_to_rotate = global.trains_to_rotate or {}
  init_events()
end)

script.on_configuration_changed(function(data)
  global.rotated_locos = global.rotated_locos or {}
  global.trains_to_rotate = global.trains_to_rotate or {}
  init_events()
end)

end


