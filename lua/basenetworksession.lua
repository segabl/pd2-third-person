function BaseNetworkSession:peer_by_unit(unit)
  return self:peer_by_unit_key(unit:key())
end

-- we need to adapt this to get our local peer whenever it is called with the third person unit
local peer_by_unit_key_original = BaseNetworkSession.peer_by_unit_key
function BaseNetworkSession:peer_by_unit_key(wanted_key)
  if alive(ThirdPerson.fp_unit) and alive(ThirdPerson.unit) and ThirdPerson.unit:key() == wanted_key then
    return peer_by_unit_key_original(self, ThirdPerson.fp_unit:key())
  end
  return peer_by_unit_key_original(self, wanted_key)
end

-- we will copy everything that the local player sends to clients, change the unit to the third person unit and then
-- send it back to ourself so it properly syncs the third person unit with the local players actions
local blocked_network_events = {
  say = true,
  unit_sound_play = true,
  set_health = true,
  set_armor = true,
  criminal_hurt = true,
  set_look_dir = true,
  set_unit = true,
  sync_unit_event_id_16 = true
}
local send_to_peers_synched_original = BaseNetworkSession.send_to_peers_synched
function BaseNetworkSession:send_to_peers_synched(...)
  if alive(ThirdPerson.fp_unit) then
    local params = { ... }
    local func = params[1]
    if alive(ThirdPerson.unit) then
      if func == "sync_carry" or func == "sync_remove_carry" then
        --ThirdPerson:log(...)
        ThirdPerson.unit:movement():set_visual_carry(func == "sync_carry" and params[2])
      elseif func == "sync_deployable_equipment" then
        --ThirdPerson:log(...)
        ThirdPerson.unit:movement():set_visual_deployable_equipment(params[2], params[3])
      elseif not blocked_network_events[func] and params[2] == ThirdPerson.fp_unit then
        if type(func) == "string" and not func:find("walk") then
          --ThirdPerson:log(...)
        end

        table.remove(params, 1)
        params[1] = ThirdPerson.unit

        local handler = managers.network and managers.network._handlers and managers.network._handlers.unit
        if handler and handler[func] then
          handler[func](handler, unpack(params))
        end

      end
    elseif not blocked_network_events[func] and ThirdPerson.fp_unit == params[2] then
      -- everything that is sent to peers before the third person unit is spawned (= everything that happens during NetworkPeer:spawn_unit)
      -- is collected to a table so it can be executed on the third person unit as soon as it's created
      table.remove(params, 1)
      table.remove(params, 1)
      table.insert(ThirdPerson.delayed_events, { func = func, params = params })
      --ThirdPerson:log("DELAYED", ...)
    end
  end
  return send_to_peers_synched_original(self, ...)
end