ThirdPerson:load()

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInitThirdPerson", function(loc)
  local custom_language
  for _, mod in pairs(BLT and BLT.Mods:Mods() or {}) do
		if mod:GetName() == "PAYDAY 2 THAI LANGUAGE Mod" and mod:IsEnabled() then
            custom_language = "thai"
            break
        end  
  end
  if custom_language then
    loc:load_localization_file(ThirdPerson.mod_path .. "loc/" .. custom_language ..".txt")
  elseif PD2KR then
    loc:load_localization_file(ThirdPerson.mod_path .. "loc/korean.txt")
  else
    local loaded = false
    if Idstring("english"):key() ~= SystemInfo:language():key() then
      for _, filename in pairs(file.GetFiles(ThirdPerson.mod_path .. "loc/") or {}) do
        local str = filename:match("^(.*).txt$")
        if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
          loc:load_localization_file(ThirdPerson.mod_path .. "loc/" .. filename)
          loaded = true
          break
        end
      end
    end
    if not loaded then
      local file = ThirdPerson.mod_path .. "loc/" .. BLT.Localization:get_language().language .. ".txt"
      if io.file_is_readable(file) then
        loc:load_localization_file(file)
      end
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
    if alive(ThirdPerson.fp_unit) then
      ThirdPerson.fp_unit:camera():refresh_tp_cam_settings()
    end
  end
  
  MenuCallbackHandler.ThirdPerson_toggle = function(self, item)
    ThirdPerson.settings[item:name()] = item:value() == "on"
    ThirdPerson:save()
    if alive(ThirdPerson.fp_unit) then
      ThirdPerson.fp_unit:camera():refresh_tp_cam_settings()
    end
  end
  
  MenuHelper:AddToggle({
    id = "enabled",
    title = "ThirdPerson_menu_third_person_enabled",
    desc = "ThirdPerson_menu_third_person_enabled_desc",
    callback = "ThirdPerson_toggle",
    value = ThirdPerson.settings.enabled,
    menu_id = menu_id_main,
    priority = 111
  })

  MenuHelper:AddToggle({
    id = "start_in_tp",
    title = "ThirdPerson_menu_third_person_start_in_tp",
    desc = "ThirdPerson_menu_third_person_start_in_tp_desc",
    callback = "ThirdPerson_toggle",
    value = ThirdPerson.settings.start_in_tp,
    menu_id = menu_id_main,
    priority = 101
  })
  
  MenuHelper:AddToggle({
    id = "immersive_first_person",
    title = "ThirdPerson_menu_third_person_immersive_first_person",
    desc = "ThirdPerson_menu_third_person_immersive_first_person_desc",
    callback = "ThirdPerson_toggle",
    value = ThirdPerson.settings.immersive_first_person,
    menu_id = menu_id_main,
    priority = 99
  })
  
  MenuHelper:AddDivider({
    id = "divider2",
    size = 24,
    menu_id = menu_id_main,
    priority = 98
  })
  
  MenuHelper:AddSlider({
    id = "cam_x",
    title = "ThirdPerson_menu_cam_x",
    callback = "ThirdPerson_value",
    value = ThirdPerson.settings.cam_x,
    min = -200,
    max = 200,
    step = 1,
    show_value = true,
    menu_id = menu_id_main,
    priority = 97
  })
  MenuHelper:AddSlider({
    id = "cam_y",
    title = "ThirdPerson_menu_cam_y",
    callback = "ThirdPerson_value",
    value = ThirdPerson.settings.cam_y,
    min = 30,
    max = 300,
    step = 1,
    show_value = true,
    menu_id = menu_id_main,
    priority = 96
  })
  MenuHelper:AddSlider({
    id = "cam_z",
    title = "ThirdPerson_menu_cam_z",
    callback = "ThirdPerson_value",
    value = ThirdPerson.settings.cam_z,
    min = -60,
    max = 60,
    step = 1,
    show_value = true,
    menu_id = menu_id_main,
    priority = 95
  })
  
  MenuHelper:AddDivider({
    id = "divider3",
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
  MenuHelper:AddToggle({
    id = "third_person_crosshair",
    title = "ThirdPerson_menu_third_person_crosshair",
    callback = "ThirdPerson_toggle",
    value = ThirdPerson.settings.third_person_crosshair,
    menu_id = menu_id_main,
    priority = 88
  })
  
  MenuHelper:AddDivider({
    id = "divider3",
    size = 24,
    menu_id = menu_id_main,
    priority = 80
  })
  
  local mod = BLT.Mods.GetModOwnerOfFile and BLT.Mods:GetModOwnerOfFile(ThirdPerson.mod_path) or BLT.Mods.GetMod and BLT.Mods:GetMod("Third Person")
  if not mod then
    ThirdPerson:log("ERROR: Could not get mod data, keybinds can not be added!")
    return
  end
  
  BLT.Keybinds:register_keybind(mod, { id = "toggle_cam_mode", allow_game = true, show_in_menu = false, callback = function()
    if alive(ThirdPerson.unit) and alive(ThirdPerson.fp_unit) then
      ThirdPerson.fp_unit:camera():toggle_third_person()
    end
  end })
  local bind = BLT.Keybinds:get_keybind("toggle_cam_mode")
  local key = bind and bind:Key() or ""
  
  MenuHelper:AddKeybinding({
    id = "toggle_cam_mode",
    title = "ThirdPerson_menu_toggle_cam_mode",
    desc= "ThirdPerson_menu_toggle_cam_mode_desc",
    connection_name = "toggle_cam_mode",
    binding = key,
    button = key,
    menu_id = menu_id_main,
    priority = 79
  })
  
  BLT.Keybinds:register_keybind(mod, { id = "flip_camera_side", allow_game = true, show_in_menu = false, callback = function()
    if alive(ThirdPerson.unit) and alive(ThirdPerson.fp_unit) then
      ThirdPerson.settings.cam_x = -ThirdPerson.settings.cam_x
      ThirdPerson.fp_unit:camera():refresh_tp_cam_settings()
    end
  end })
  local bind = BLT.Keybinds:get_keybind("flip_camera_side")
  local key = bind and bind:Key() or ""
  
  MenuHelper:AddKeybinding({
    id = "flip_camera_side",
    title = "ThirdPerson_menu_flip_camera_side",
    desc= "ThirdPerson_menu_flip_camera_side_desc",
    connection_name = "flip_camera_side",
    binding = key,
    button = key,
    menu_id = menu_id_main,
    priority = 78
  })
  
end)

Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenusPlayerThirdPerson", function(menu_manager, nodes)
  nodes[menu_id_main] = MenuHelper:BuildMenu(menu_id_main, { area_bg = "half" })
  MenuHelper:AddMenuItem(nodes["blt_options"], menu_id_main, "ThirdPerson_menu_main_name", "ThirdPerson_menu_main_desc")
end)