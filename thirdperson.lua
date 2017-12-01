if not ThirdPerson then

  _G.ThirdPerson = {}
  ThirdPerson.mod_path = ModPath
  ThirdPerson.save_path = SavePath
  ThirdPerson.unit = nil
  ThirdPerson.delayed_events = {}
  ThirdPerson.settings = {
    cam_x = 80,
    cam_y = 120,
    cam_z = 15,
    first_person_on_steelsight = true,
    immersive_first_person = false
  }
  
  function ThirdPerson:log(...)
    if DebugConsole and con then
      con:print(...)
    else
      local str = ""
      table.for_each_value({ ... }, function (v)
        str = str .. tostring(v) .. "  "
      end)
      log(str)
    end
  end
  
  function ThirdPerson:setup_unit()
    local player = managers.player:local_player()
    local player_peer = player:network():peer()
    local player_movement = player:movement()
    local pos = player_movement:m_pos()
    local rot = player_movement:m_head_rot()
    local unit_name = Idstring(tweak_data.blackmarket.characters[player_peer:character_id()].npc_unit:gsub("(.+)/npc_", "%1/player_") .. "_husk")
    
    self.unit = alive(self.unit) and self.unit or World:spawn_unit(unit_name, pos, rot)
    
    self.unit:base()._first_person_unit = player
    player:base().pre_destroy = function (self, ...)
      if alive(ThirdPerson.unit) then
        World:delete_unit(ThirdPerson.unit)
      end
      PlayerBase.pre_destroy(self, ...)
    end

    -- Hook some functions
    self.unit:base().pre_destroy = function (self, unit)
      self._unit:movement():pre_destroy(unit)
      self._unit:inventory():pre_destroy(self._unit)
      UnitBase.pre_destroy(self, unit)
    end
    local look_vec_modified = Vector3()
    self.unit:movement().update = function (self, ...)
      HuskPlayerMovement.update(self, ...)
      local fp_unit = self._unit:base()._first_person_unit
      if alive(fp_unit) then
        -- correct aiming direction so that lasers are approximately the same in first and third person
        mvector3.set(look_vec_modified, fp_unit:camera():forward())
        mvector3.rotate_with(look_vec_modified, Rotation(fp_unit:camera():rotation():z(), 1) * Rotation(fp_unit:camera():rotation():x(), -0.5))
        self:set_look_dir_instant(look_vec_modified)
      end
    end
    self.unit:movement().set_position = function (self, pos)
      local fp_unit = self._unit:base()._first_person_unit
      if alive(fp_unit) and fp_unit:camera():first_person() then
        self._unit:set_position(Vector3(0, 0, -10000))
      else
        HuskPlayerMovement.set_position(self, alive(fp_unit) and fp_unit:movement():m_pos() or pos)
      end
    end
    self.unit:movement().set_need_assistance = function (self) end
    self.unit:movement().set_need_revive = function (self) end
    self.unit:movement().set_head_visibility = function (self, visible)
      if not self._plr_head_mesh_obj then
        local char_name = managers.criminals.convert_old_to_new_character_workname(managers.criminals:character_name_by_unit(self._unit))
        self._plr_head_mesh_obj = char_name and self._unit:get_object(Idstring("g_head_" .. char_name))
      end
      if self._plr_head_mesh_obj then
        self._plr_head_mesh_obj:set_visibility(visible)
      end
      self._unit:inventory():set_mask_visibility(visible and self._unit:inventory()._mask_visibility)
    end
    self.unit:inventory().set_mask_visibility = function (self, state)
      HuskPlayerInventory.set_mask_visibility(self, not ThirdPerson.settings.immersive_first_person and state)
    end
    self.unit:sound().say = function () end
    self.unit:sound().play = function () end
    self.unit:sound()._play = function () end
    
    -- Set some stuff
    self.unit:inventory():set_melee_weapon(player_peer:melee_id(), true)
    self.unit:damage():run_sequence_simple(managers.blackmarket:character_sequence_by_character_id(player_peer:character_id(), player_peer:id()))
    self.unit:movement():set_character_anim_variables()
    self.unit:movement():set_head_visibility(not ThirdPerson.settings.immersive_first_person)
    self.unit:contour():remove("teammate")
    self.unit:movement():set_attention_updator(function () end)
    
    -- Call delayed events
    local handler = managers.network and managers.network._handlers and managers.network._handlers.unit
    if handler then
      for _, v in ipairs(self.delayed_events) do
        if handler[v.func] then
          handler[v.func](handler, self.unit, unpack(v.params))
        end
      end
      delayed_events = {}
    end
    
    local current_level = managers.job and managers.job:current_level_id()
    if current_level then
      local sequence = tweak_data.levels[current_level] and tweak_data.levels[current_level].player_sequence
      if sequence then
        self.unit:damage():run_sequence_simple(sequence)
      end
    end
    
    player_peer._unit = self.unit
    player_peer._equipped_armor_id = "level_1"
    player_peer:_update_equipped_armor()
    player_peer._unit = player
    
    player:camera():set_third_person()
    
    -- Unregister from groupai manager so it doesnt count as an actual criminal
    managers.groupai:state():unregister_criminal(self.unit)
  end
  
  function ThirdPerson:save()
    local file = io.open(self.save_path .. "third_person.txt", "w+")
    if file then
      file:write(json.encode(self.settings))
      file:close()
    end
  end

  function ThirdPerson:load()
    local file = io.open(self.save_path .. "third_person.txt", "r")
    if file then
      local data = json.decode(file:read("*all")) or {}
      file:close()
      for k, v in pairs(data) do
        self.settings[k] = v
      end
    end
  end

end


if RequiredScript == "lib/units/beings/player/playercamera" then

  local init_original = PlayerCamera.init
  function PlayerCamera:init(...)
    init_original(self, ...)
    self._tp_camera_object = World:create_camera()
    self._tp_camera_object:set_near_range(3)
    self._tp_camera_object:set_far_range(250000)
    self._tp_camera_object:set_fov(75)
    self._tp_camera_object:link(self._camera_object)
    self:set_third_person_position(ThirdPerson.settings.cam_x, -ThirdPerson.settings.cam_y, ThirdPerson.settings.cam_z)
  end

  function PlayerCamera:set_FOV(fov_value)
    self._camera_object:set_fov(fov_value)
    self._tp_camera_object:set_fov(fov_value)
  end
  
  --[[
  local set_position_original = PlayerCamera.set_position
  function PlayerCamera:set_position(pos)
    set_position_original(self, pos)
    Application:draw_line(self:position(), self:position() + self:forward() * 10000, 1, 0, 0)
  end
  ]]
  
  if ThirdPerson.settings.immersive_first_person then
  
    local set_position_original = PlayerCamera.set_position
    function PlayerCamera:set_position(pos)
      set_position_original(self, pos)
      if alive(ThirdPerson.unit) then
        local pos = ThirdPerson.unit:movement():m_head_pos()
        local rot = ThirdPerson.unit:movement():m_head_rot()
        self._tp_camera_object:set_position(pos + rot:z() * 10)
      end
    end
    
    local set_rotation_original = PlayerCamera.set_rotation
    function PlayerCamera:set_rotation(rot)
      set_rotation_original(self, rot)
      if alive(ThirdPerson.unit) then
        self._tp_camera_object:set_rotation(ThirdPerson.unit:movement():m_head_rot())
      end
    end
    
  end
  
  function PlayerCamera:set_third_person_position(x, y, z)
    local pos = self._camera_object:position()
    local rot = self._camera_object:rotation()
    self._tp_camera_object:set_position(pos + rot:x() * x + rot:y() * y + rot:z() * z)
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
    ThirdPerson.unit:movement():set_position()
  end
  
  function PlayerCamera:set_third_person()
    self:camera_unit():base():set_target_tilt(0)
    self._vp:set_camera(self._tp_camera_object)
    ThirdPerson.unit:movement():set_position()
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
    _start_action_steelsight_original(self, ...)
    if self._state_data.in_steelsight and ThirdPerson.settings.first_person_on_steelsight then
      self._unit:camera():set_first_person()
    end
  end

  local _end_action_steelsight_original = PlayerStandard._end_action_steelsight
  function PlayerStandard:_end_action_steelsight(...)
    _end_action_steelsight_original(self, ...)
    if ThirdPerson.settings.first_person_on_steelsight then
      self._unit:camera():set_third_person()
    end
  end

end


if RequiredScript == "lib/network/base/basenetworksession" then

  function BaseNetworkSession:peer_by_unit(unit)
    return self:peer_by_unit_key(unit:key())
  end

  local peer_by_unit_key_original = BaseNetworkSession.peer_by_unit_key
  function BaseNetworkSession:peer_by_unit_key(wanted_key)
    local player = managers.player:local_player()
    if alive(player) and alive(ThirdPerson.unit) and ThirdPerson.unit:key() == wanted_key then
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
    if alive(ThirdPerson.unit) then
      if func == "sync_carry" or func == "sync_remove_carry" then
        ThirdPerson:log(...)
        ThirdPerson.unit:movement():set_visual_carry(func == "sync_carry" and params[2])
      elseif func == "sync_deployable_equipment" then
        ThirdPerson:log(...)
        ThirdPerson.unit:movement():set_visual_deployable_equipment(params[2], params[3])
      elseif not blocked_network_events[func] and params[2] == player then
        if type(func) == "string" and not func:find("walk") then
          ThirdPerson:log(...)
        end
      
        table.remove(params, 1)
        params[1] = ThirdPerson.unit
        table.insert(params, player:network():peer():rpc())
        
        local handler = managers.network and managers.network._handlers and managers.network._handlers.unit
        if handler and handler[func] then
          handler[func](handler, unpack(params))
        end
        
      end
    elseif not blocked_network_events[func] and alive(player) and player == params[2] then
      table.remove(params, 1)
      table.remove(params, 1)
      table.insert(params, player:network():peer():rpc())
      table.insert(ThirdPerson.delayed_events, { func = func, params = params })
      ThirdPerson:log("DELAYED", ...)
    end
    return send_to_peers_synched_original(self, ...)
  end

end


if RequiredScript == "lib/managers/criminalsmanager" then

  for k, v in pairs(CriminalsManager) do
    if k:find("_by_unit") then
      local orig = v
      CriminalsManager[k] = function (self, unit)
        if alive(ThirdPerson.unit) and unit == ThirdPerson.unit and alive(unit:base()._first_person_unit) then
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
    if alive(self._setup.user_unit) and self._setup.user_unit == ThirdPerson.unit then
      return fire_blank_original(self, direction, false, ...)
    end
    return fire_blank_original(self, direction, impact, ...)
  end
  
  local auto_fire_blank_original = NewNPCRaycastWeaponBase.auto_fire_blank
  function NewNPCRaycastWeaponBase:auto_fire_blank(direction, impact, ...)
    if alive(self._setup.user_unit) and self._setup.user_unit == ThirdPerson.unit then
      return auto_fire_blank_original(self, direction, false, ...)
    end
    return auto_fire_blank_original(self, direction, impact, ...)
  end

end


if RequiredScript == "lib/network/base/networkpeer" then

  local spawn_unit_original = NetworkPeer.spawn_unit
  function NetworkPeer:spawn_unit(...)
    local unit = spawn_unit_original(self, ...)
    if self == managers.network:session():local_peer() then
      ThirdPerson:setup_unit()
    end
  end

end


if RequiredScript == "lib/managers/group_ai_states/groupaistatebase" then

  for k, v in pairs(GroupAIStateBase) do
    if k:find("^on_criminal_") then
      local orig = v
      GroupAIStateBase[k] = function (self, unit, ...)
        if alive(ThirdPerson.unit) and unit == ThirdPerson.unit then
          return
        end
        orig(self, unit, ...)
      end
    end
  end

end


if RequiredScript == "lib/managers/menumanager" then

   Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInitThirdPerson", function(loc)
    for _, filename in pairs(file.GetFiles(ThirdPerson.mod_path .. "loc/") or {}) do
      local str = filename:match("^(.*).txt$")
      if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
        loc:load_localization_file(ThirdPerson.mod_path .. "loc/" .. filename)
        loaded = true
        break
      end
    end
    loc:load_localization_file(ThirdPerson.mod_path .. "loc/english.txt", false)
  end)

  local menu_id_main = "ThirdPersonMenu"
  Hooks:Add("MenuManagerSetupCustomMenus", "MenuManagerSetupCustomMenusThirdPerson", function(menu_manager, nodes)
    MenuHelper:NewMenu(menu_id_main)
  end)

  Hooks:Add("MenuManagerPopulateCustomMenus", "MenuManagerPopulateCustomMenusThirdPerson", function(menu_manager, nodes)
    
    MenuCallbackHandler.ThirdPerson_value = function(self, item)
      ThirdPerson.settings[item:name()] = item:value()
      ThirdPerson:save()
    end
    
    MenuCallbackHandler.ThirdPerson_toggle = function(self, item)
      ThirdPerson.settings[item:name()] = item:value() == "on"
      ThirdPerson:save()
    end
    
    MenuCallbackHandler.ThirdPerson_cam_pos = function(self, item)
      MenuCallbackHandler.ThirdPerson_value(self, item)
      if managers.player and managers.player:local_player() then
        managers.player:local_player():camera():set_third_person_position(ThirdPerson.settings.cam_x, -ThirdPerson.settings.cam_y, ThirdPerson.settings.cam_z)
      end
    end
    
    MenuHelper:AddSlider({
      id = "cam_x",
      title = "ThirdPerson_menu_cam_x",
      callback = "ThirdPerson_cam_pos",
      value = ThirdPerson.settings.cam_x,
      min = -200,
      max = 200,
      step = 1,
      show_value = true,
      menu_id = menu_id_main,
      priority = 99
    })
    MenuHelper:AddSlider({
      id = "cam_y",
      title = "ThirdPerson_menu_cam_y",
      callback = "ThirdPerson_cam_pos",
      value = ThirdPerson.settings.cam_y,
      min = 30,
      max = 300,
      step = 1,
      show_value = true,
      menu_id = menu_id_main,
      priority = 98
    })
    MenuHelper:AddSlider({
      id = "cam_z",
      title = "ThirdPerson_menu_cam_z",
      callback = "ThirdPerson_cam_pos",
      value = ThirdPerson.settings.cam_z,
      min = -60,
      max = 60,
      step = 1,
      show_value = true,
      menu_id = menu_id_main,
      priority = 97
    })
    
    MenuHelper:AddDivider({
      id = "divider1",
      size = 24,
      menu_id = menu_id_main,
      priority = 90
    })
    
    MenuHelper:AddToggle({
      id = "first_person_on_steelsight",
      title = "ThirdPerson_menu_first_person_on_steelsight",
      callback = "ThirdPerson_toggle",
      value = ThirdPerson.settings.first_person_on_steelsight,
      menu_id = menu_id_main,
      priority = 89
    })
    
  end)

  Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenusPlayerThirdPerson", function(menu_manager, nodes)
    nodes[menu_id_main] = MenuHelper:BuildMenu(menu_id_main, { area_bg = "half" })
    MenuHelper:AddMenuItem(nodes["blt_options"], menu_id_main, "ThirdPerson_menu_main_name", "ThirdPerson_menu_main_desc")
  end)
  
  ThirdPerson:load()
  
end