function setup_third_person_unit(player_peer)

  local player = managers.player:local_player()
  local player_movement = player:movement()
  local pos = player_movement:m_pos()
  local rot = player_movement:m_head_rot()
  local unit_name = Idstring(tweak_data.blackmarket.characters[player_peer:character_id()].npc_unit:gsub("(.+)/npc_", "%1/player_") .. "_husk")
  
  local unit = alive(player:base()._third_person_unit) and player:base()._third_person_unit or World:spawn_unit(unit_name, pos, rot)

  player:base()._third_person_unit = unit
  unit:base()._first_person_unit = player

  -- Hook some functions
  unit:movement().update = function (self, ...)
    HuskPlayerMovement.update(self, ...)
    local fp_unit = self._unit:base()._first_person_unit
    if alive(fp_unit) then
      self:set_look_dir_instant(fp_unit:camera():forward())
    end
  end
  unit:movement().set_position = function (self, pos)
    local fp_unit = self._unit:base()._first_person_unit
    if alive(fp_unit) and fp_unit:camera():first_person() then
      self._unit:set_position(Vector3(0, 0, -10000))
    else
      HuskPlayerMovement.set_position(self, alive(fp_unit) and fp_unit:movement():m_pos() or pos)
    end
  end
  unit:movement().set_need_assistance = function (self) end
  unit:movement().set_need_revive = function (self) end
  
  unit:inventory():set_melee_weapon(player_peer:melee_id(), true)
  local weapon = player:inventory():equipped_unit():base()
  unit:inventory():add_unit_by_factory_blueprint(weapon._factory_id .. "_npc", true, true, weapon._blueprint, weapon._cosmetics_data)

  local sequence = managers.blackmarket:character_sequence_by_character_id(player_peer:character_id(), player_peer:id())
  unit:damage():run_sequence_simple(sequence)
  
  unit:movement():set_character_anim_variables()
  unit:contour():remove("teammate")
  unit:movement():set_team(managers.groupai:state():team_data(tweak_data.levels:get_default_team_ID("player")))
  unit:movement():set_attention_updator(function () end)
  
  unit:movement():sync_movement_state(player_movement._current_state_name, player:character_damage():down_time())
  unit:movement():sync_action_change_speed(player_movement:current_state()._cached_final_speed or 0)
  
  unit:movement():set_position()
  
  unit:sound().say = function () end
  unit:sound().play = function () end
  unit:sound()._play = function () end
  
  player_peer._unit = unit
  player_peer._equipped_armor_id = "level_1"
  player_peer:_update_equipped_armor()
  player_peer._unit = player
  
  --unit:set_slot(0)
  
  player:camera():set_third_person()
  
end

if RequiredScript == "lib/units/beings/player/playercamera" then

  local init_original = PlayerCamera.init
  function PlayerCamera:init(...)
    init_original(self, ...)
    self._tp_camera_object = World:create_camera()
    self._tp_camera_object:set_near_range(3)
    self._tp_camera_object:set_far_range(250000)
    self._tp_camera_object:set_fov(75)
    self._tp_camera_object:set_position(self._camera_object:position() + Vector3(80, -150, 20))
    self._tp_camera_object:link(self._camera_object)
  end

  function PlayerCamera:set_FOV(fov_value)
    self._camera_object:set_fov(fov_value)
    self._tp_camera_object:set_fov(fov_value)
  end
  
  function PlayerCamera:toggle_third_person()
    if self:first_person() then
      self:set_third_person()
    else
      self:set_first_person()
    end
  end
  
  function PlayerCamera:set_first_person()
    self:camera_unit():base():set_target_tilt(self:camera_unit():base()._fp_target_tilt or 0)
    self._vp:set_camera(self._camera_object)
    self._unit:base()._third_person_unit:movement():set_position()
  end
  
  function PlayerCamera:set_third_person()
    self:camera_unit():base():set_target_tilt(0)
    self._vp:set_camera(self._tp_camera_object)
    self._unit:base()._third_person_unit:movement():set_position()
  end
  
  function PlayerCamera:first_person()
    return self._vp:camera() == self._camera_object
  end
  
  function PlayerCamera:third_person()
    return self._vp:camera() == self._tp_camera_object
  end

end


if RequiredScript == "lib/units/cameras/fpcameraplayerbase" then

  local set_position_original = FPCameraPlayerBase.set_position
  function FPCameraPlayerBase:set_position(...)
    local cam = alive(self._parent_unit) and self._parent_unit:camera()
    if cam and cam:third_person() then
      self._unit:set_position(Vector3(0, 0, -100000))
    else
      set_position_original(self, ...)
    end
  end
  
  local set_target_tilt_original = FPCameraPlayerBase.set_target_tilt
  function FPCameraPlayerBase:set_target_tilt(tilt)
    if not alive(self._parent_unit) or self._parent_unit:camera():first_person() then
      set_target_tilt_original(self, tilt)
    end
    self._fp_target_tilt = tilt
  end

end


if RequiredScript == "lib/units/beings/player/states/playerstandard" then

  local _start_action_steelsight_original = PlayerStandard._start_action_steelsight
  function PlayerStandard:_start_action_steelsight(...)
     self._unit:camera():set_first_person()
    return _start_action_steelsight_original(self, ...)
  end

  local _end_action_steelsight_original = PlayerStandard._end_action_steelsight
  function PlayerStandard:_end_action_steelsight(...)
     self._unit:camera():set_third_person()
    return _end_action_steelsight_original(self, ...)
  end

end


if RequiredScript == "lib/network/base/basenetworksession" then

  function BaseNetworkSession:peer_by_unit(unit)
    return self:peer_by_unit_key(unit:key())
  end

  local peer_by_unit_key_original = BaseNetworkSession.peer_by_unit_key
  function BaseNetworkSession:peer_by_unit_key(wanted_key)
    local player = managers.player:local_player()
    if alive(player) and alive(player:base()._third_person_unit) and player:base()._third_person_unit:key() == wanted_key then
      return peer_by_unit_key_original(self, player:key())
    end
    return peer_by_unit_key_original(self, wanted_key)
  end
  
  local blocked_network_events = {
    say = true,
    unit_sound_play = true,
    set_health = true,
    set_armor = true,
    criminal_hurt = true,
    set_look_dir = true,
    set_unit = true,
  }
  local send_to_peers_synched_original = BaseNetworkSession.send_to_peers_synched
  function BaseNetworkSession:send_to_peers_synched(...)
    local params = { ... }
    local func = params[1]
    local player = managers.player:local_player()
    local tp_unit = alive(player) and player:base()._third_person_unit
    if alive(tp_unit) then
      if func == "sync_carry" or func == "sync_remove_carry" or func == "server_drop_carry" then
        con:print(...)
        tp_unit:movement():set_visual_carry(func == "sync_carry" and params[2])
      elseif func == "sync_deployable_equipment" then
        con:print(...)
        tp_unit:movement():set_visual_deployable_equipment(params[2], params[3])
      elseif not blocked_network_events[func] and params[2] == player then
        if type(func) == "string" and not func:find("walk") then
          con:print(...)
        end
      
        table.remove(params, 1)
        params[1] = tp_unit
        table.insert(params, player:network():peer():rpc())
        
        local handler = managers.network and managers.network._handlers and managers.network._handlers.unit
        if handler and handler[func] then
          handler[func](handler, unpack(params))
        end
        
      end
    end
    return send_to_peers_synched_original(self, ...)
  end

end


if RequiredScript == "lib/managers/criminalsmanager" then

  for k, v in pairs(CriminalsManager) do
    if k:find("_by_unit") then
      local orig = v
      CriminalsManager[k] = function (self, unit)
        if alive(unit) and unit.base and unit:base() and alive(unit:base()._first_person_unit) then
          return orig(self, unit:base()._first_person_unit)
        end
        return orig(self, unit)
      end
    end
  end

end


if RequiredScript == "lib/units/weapons/newnpcraycastweaponbase" then

  local fire_blank_original = NewNPCRaycastWeaponBase.fire_blank
  function NewNPCRaycastWeaponBase:fire_blank(direction, impact, ...)
    if alive(self._setup.user_unit) and self._setup.user_unit:base()._first_person_unit then
      return fire_blank_original(self, direction, false, ...)
    end
    return fire_blank_original(self, direction, impact, ...)
  end
  
  local auto_fire_blank_original = NewNPCRaycastWeaponBase.auto_fire_blank
  function NewNPCRaycastWeaponBase:auto_fire_blank(direction, impact, ...)
    if alive(self._setup.user_unit) and self._setup.user_unit:base()._first_person_unit then
      return auto_fire_blank_original(self, direction, false, ...)
    end
    return auto_fire_blank_original(self, direction, impact, ...)
  end

end


if RequiredScript == "lib/network/base/networkpeer" then

  local spawn_unit_original = NetworkPeer.spawn_unit
  function NetworkPeer:spawn_unit(...)
    local unit = spawn_unit_original(self, ...)
    if unit == managers.player:local_player() then
      setup_third_person_unit(self)
    end
  end

end