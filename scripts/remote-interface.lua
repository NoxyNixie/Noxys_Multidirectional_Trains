-- NOTE: Events are only raised after a mod has called the associated "get" method.

local on_train_rotating = nil
local on_train_locomotive_rotated = nil
local on_train_rotated = nil
local on_train_unrotating = nil

local interface = {}

function interface.get_on_train_rotating()
    if not on_train_rotating then on_train_rotating = script.generate_event_name() end
    return on_train_rotating
end
function interface.get_on_train_locomotive_rotated()
    if not on_train_locomotive_rotated then on_train_locomotive_rotated = script.generate_event_name() end
    return on_train_locomotive_rotated
end
function interface.get_on_train_rotated()
    if not on_train_rotated then on_train_rotated = script.generate_event_name() end
    return on_train_rotated
end
function interface.get_on_train_unrotating()
    if not on_train_unrotating then on_train_unrotating = script.generate_event_name() end
    return on_train_unrotating
end

remote.add_interface("Noxys_Multidirectional_Trains", interface)

---Raises the `on_train_rotating` event, if the event has been subscribed.
---
---This event is raised when a train has one-or-more locomotives that will be rotated, prior to rotating any locomotive.
---@param train LuaTrain The train entity to be rotated.
function raise_train_rotating(train)
    if on_train_rotating then
        script.raise_event(on_train_rotating, {
            train = train,
        })
    end
end

---Raises the `on_train_locomotive_rotated` event, if the event has been subscribed.
---
---This event is raised for each locomotive that is rotated
---@param train LuaTrain The new Train entity created after rotating a single locomotive.
---@param old_train_id uint The unique ID of the train that was destroyed by rotating a single locomotive.
function raise_train_locomotive_rotated(train, old_train_id)
    if on_train_locomotive_rotated then
        script.raise_event(on_train_locomotive_rotated, {
            train = train,
            old_train_id_1 = old_train_id,
        })
    end
end

---Raises the `on_train_rotated` event, if the event has been subscribed.
---
---This event is raised after all locomotives have been rotated.
---@param train LuaTrain The train entity for the rotated train.
---@param old_train_id uint The unique ID of the train prior to rotating locomotives.
function raise_on_train_rotated(train, old_train_id)
    if on_train_rotated then
        script.raise_event(on_train_rotated, {
            train = train,
            old_train_id_1 = old_train_id,
        })
    end
end

---Raises the `on_train_unrotating` event, if the event has been subscribed. Shares
---event parameters with `EventData.on_train_changed_state`.
---
---This event is raised during `on_train_changed_state` when a train is at a station, has no path, or is 
---switch to manual and will be checked for locomotives to be unrotated.
---@param train LuaTrain The train entity to be checked for locomotives to be unrotated.
---@param old_state defines.train_state The old state of the train.
function raise_train_unrotating(train, old_state)
    if on_train_unrotating then
        script.raise_event(on_train_unrotating, {
            train = train,
            old_state = old_state,
        })
    end
end