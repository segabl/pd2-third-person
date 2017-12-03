if not ThirdPerson then

  _G.ThirdPerson = {}
  ThirdPerson.mod_path = ModPath
  ThirdPerson.save_path = SavePath
  ThirdPerson.unit = nil
  ThirdPerson.fp_unit = nil
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
    
    self.fp_unit = player
    self.unit = alive(self.unit) and self.unit or World:spawn_unit(unit_name, pos, rot)
    
    -- The third person unit should be destroyed whenever the first person unit is destroyed
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
      if alive(ThirdPerson.fp_unit) then
        -- correct aiming direction so that lasers are approximately the same in first and third person
        mvector3.set(look_vec_modified, ThirdPerson.fp_unit:camera():forward())
        mvector3.rotate_with(look_vec_modified, Rotation(ThirdPerson.fp_unit:camera():rotation():z(), 1) * Rotation(ThirdPerson.fp_unit:camera():rotation():x(), -0.5))
        self:set_look_dir_instant(look_vec_modified)
      end
    end
    self.unit:movement().set_position = function (self, pos)
      if alive(ThirdPerson.fp_unit) and ThirdPerson.fp_unit:camera():first_person() then
        self._unit:set_position(Vector3(0, 0, -10000))
      else
        HuskPlayerMovement.set_position(self, alive(ThirdPerson.fp_unit) and ThirdPerson.fp_unit:movement():m_pos() or pos)
      end
    end
    self.unit:movement().set_need_assistance = function (self) end
    self.unit:movement().set_need_revive = function (self) end
    self.unit:movement().set_head_visibility = function (self, visible)
      -- needs work, doesnt get all criminals heads
      local char_name = managers.criminals.convert_old_to_new_character_workname(managers.criminals:character_name_by_unit(self._unit))
      local head_obj = char_name and self._unit:get_object(Idstring("g_head_" .. char_name))
      if head_obj then
        head_obj:set_visibility(visible)
      end
      local neck_armor_obj = self._unit:get_object(Idstring("g_vest_neck"))
      if neck_armor_obj then
        neck_armor_obj:set_visibility(visible and neck_armor_obj:visibility())
      end
      self._unit:inventory():set_mask_visibility(visible and self._unit:inventory()._mask_visibility)
    end
    self.unit:movement().update_armor = function (self)
      if alive(ThirdPerson.fp_unit) then
        local player_peer = ThirdPerson.fp_unit:network():peer()
        player_peer._unit = self._unit
        player_peer._equipped_armor_id = "level_1"
        player_peer:_update_equipped_armor()
        player_peer._unit = ThirdPerson.fp_unit
      end
    end
    self.unit:inventory().set_mask_visibility = function (self, state)
      HuskPlayerInventory.set_mask_visibility(self, not ThirdPerson.settings.immersive_first_person and state)
    end
    -- We don't want our third person unit to make any sound, so we're plugging empty functions here
    self.unit:sound().say = function () end
    self.unit:sound().play = function () end
    self.unit:sound()._play = function () end
    
    -- Setup some stuff
    self.unit:inventory():set_melee_weapon(player_peer:melee_id(), true)
    
    self.unit:damage():run_sequence_simple(managers.blackmarket:character_sequence_by_character_id(player_peer:character_id(), player_peer:id()))
    local level_data = managers.job and managers.job:current_level_data()
    if level_data and level_data.player_sequence then
      self.unit:damage():run_sequence_simple(level_data.player_sequence)
    end
    
    self.unit:movement():set_character_anim_variables()
    self.unit:movement():update_armor()
    self.unit:movement():set_head_visibility(not ThirdPerson.settings.immersive_first_person)
    
    self.unit:contour():remove("teammate")
    
    -- Call missed events
    local handler = managers.network and managers.network._handlers and managers.network._handlers.unit
    if handler then
      for _, v in ipairs(self.delayed_events) do
        if handler[v.func] then
          handler[v.func](handler, self.unit, unpack(v.params))
        end
      end
      self.delayed_events = {}
    end
    
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
    self._third_person = false
    self._slot_mask = managers.slot:get_mask("world_geometry")
  end
  
  local mvec_pos = Vector3()
  function PlayerCamera:check_set_third_person_position(pos, rot)
    if self:third_person() then
      local dir = Vector3(ThirdPerson.settings.cam_x, -ThirdPerson.settings.cam_y, ThirdPerson.settings.cam_z)
      local dis = mvector3.length(dir)
      mvector3.normalize(dir)
      mvector3.rotate_with(dir, rot)
      mvector3.set(mvec_pos, dir)
      mvector3.multiply(mvec_pos, dis)
      mvector3.add(mvec_pos, pos)
      local ray = World:raycast("ray", pos, pos + dir * (dis + 20), "slot_mask", self._slot_mask)
      if ray then
        mvector3.set(mvec_pos, dir)
        mvector3.multiply(mvec_pos, ray.distance - 20)
        mvector3.add(mvec_pos, pos)
      end
      self._camera_controller:set_camera(mvec_pos)
    end
    if ThirdPerson.settings.immersive_first_person and alive(ThirdPerson.unit) then
      local pos = ThirdPerson.unit:movement():m_head_pos()
      local rot = ThirdPerson.unit:movement():m_head_rot()
      self._camera_controller:set_camera(pos + rot:y() * 10 + rot:z() * 10)
    end
  end
  
  local set_position_original = PlayerCamera.set_position
  function PlayerCamera:set_position(pos)
    set_position_original(self, pos)
    self:check_set_third_person_position(pos, self:rotation())
  end
  
  local set_rotation_original = PlayerCamera.set_rotation
  function PlayerCamera:set_rotation(rot)
    set_rotation_original(self, rot)
    self:check_set_third_person_position(self:position(), rot)
  end
  
  function PlayerCamera:toggle_third_person()
    if self:first_person() then
      self:set_third_person()
    else
      self:set_first_person()
    end
  end
  
  function PlayerCamera:set_first_person()
    self._third_person = false
    ThirdPerson.unit:movement():set_position(Vector3())
  end
  
  function PlayerCamera:set_third_person()
    self._third_person = true
    ThirdPerson.unit:movement():set_position(Vector3())
  end
  
  function PlayerCamera:first_person()
    return not self._third_person
  end
  
  function PlayerCamera:third_person()
    return self._third_person
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

  -- we need to adapt this to get our local peer whenever it is called with the third person unit
  local peer_by_unit_key_original = BaseNetworkSession.peer_by_unit_key
  function BaseNetworkSession:peer_by_unit_key(wanted_key)
    local player = managers.player:local_player()
    if alive(player) and alive(ThirdPerson.unit) and ThirdPerson.unit:key() == wanted_key then
      return peer_by_unit_key_original(self, player:key())
    end
    return peer_by_unit_key_original(self, wanted_key)
  end
  
  -- everything that the local player sends to clients we will copy, change the unit to the third person unit and then send back to ourself
  -- so it properly syncs the third person unit with the local players actions
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
      -- everything that is sent to peers before the third person unit is spawned (= everything that happens during NetworkPeer:spawn_unit)
      -- is collected to a table so it can be executed on the third person unit as soon as it's created
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

  -- we need to change the *_by_unit functions of CriminalsManager to return the data of the first person unit
  -- when called with the third person unit so it can get data like mask id or character name without problem
  for func_name, orig_func in pairs(CriminalsManager) do
    if func_name:find("_by_unit") then
      CriminalsManager[func_name] = function (self, unit)
        return orig_func(self, unit == ThirdPerson.unit and alive(ThirdPerson.unit) and alive(ThirdPerson.fp_unit) and ThirdPerson.fp_unit or unit)
      end
    end
  end

end


if RequiredScript == "lib/units/weapons/newnpcraycastweaponbase" then

  -- Change the fire functions to always fire without impact since we already have bullet impact from the first person unit
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

  -- setup the third person unit whenever the local player is spawned
  local spawn_unit_original = NetworkPeer.spawn_unit
  function NetworkPeer:spawn_unit(...)
    local unit = spawn_unit_original(self, ...)
    if self == managers.network:session():local_peer() then
      ThirdPerson:setup_unit()
    end
    return unit
  end

end


if RequiredScript == "lib/managers/group_ai_states/groupaistatebase" then

  -- we need to block on_criminal_* function calls from GroupAIStateBase when called with the third person unit
  -- since it would try to access data of the third person unit, which isn't there since we unregistered it when we created it
  -- it's not the best solution but it's easier than preventing any calls to any of the functions by the third person unit
  for func_name, orig_func in pairs(GroupAIStateBase) do
    if func_name:find("^on_criminal_") then
      GroupAIStateBase[func_name] = function (self, unit, ...)
        if alive(ThirdPerson.unit) and unit == ThirdPerson.unit then
          return
        end
        return orig_func(self, unit, ...)
      end
    end
  end

end


if RequiredScript == "lib/managers/menumanager" then

  ThirdPerson:load()

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
        local cam =  managers.player:local_player():camera()
        cam:check_set_third_person_position(cam:position(), cam:rotation())
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
  
end