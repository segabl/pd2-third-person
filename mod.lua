TheFixesPreventer = TheFixesPreventer or {}
TheFixesPreventer.crash_ver_char_send_basenetwork = true

if not ThirdPerson then

	ThirdPerson = {}
	ThirdPerson.mod_path = ModPath
	ThirdPerson.save_path = SavePath
	ThirdPerson.mod_instance = ModInstance
	ThirdPerson.unit = nil
	ThirdPerson.fp_unit = nil
	ThirdPerson.delayed_events = {}
	ThirdPerson.settings = {
		start_in_tp = true,
		cam_x = 80,
		cam_y = 120,
		cam_z = 15,
		first_person_on_steelsight = true,
		first_person_on_downed = false,
		third_person_crosshair = true,
		third_person_crosshair_style = 1,
		third_person_crosshair_size = 32,
		immersive_first_person = false
	}

	function ThirdPerson:log(...)
		local str = "[ThirdPerson] "
		table.for_each_value({ ... }, function (v)
			str = str .. tostring(v) .. "  "
		end)
		log(str)
		print(str)
	end

	local unit_ids = Idstring("unit")
	local husk_names = {
		wild = "units/pd2_dlc_wild/characters/npc_criminals_wild_1/player_criminal_wild_husk",
		joy = "units/pd2_dlc_joy/characters/npc_criminals_joy_1/player_criminal_joy_husk"
	} -- thanks Overkill >.<
	function ThirdPerson:setup_unit(unit)
		local player = unit or managers.player:local_player()
		if not player then
			ThirdPerson:log("ERROR: Could not find player unit!")
			return
		end
		local player_peer = player:network():peer()
		local player_movement = player:movement()
		local pos = player_movement:m_pos()
		local rot = player_movement:m_head_rot()
		local char_id = player_peer:character_id()
		local unit_name = husk_names[char_id] or tweak_data.blackmarket.characters[char_id].npc_unit:gsub("(.+)/npc_", "%1/player_") .. "_husk"
		local unit_name_ids = Idstring(unit_name)

		if not DB:has(unit_ids, unit_name_ids) then
			ThirdPerson:log("ERROR: Could not find player husk unit for " .. char_id .. "! Assumed " .. unit_name)
			self.fp_unit = nil
			self.unit = nil
			return
		end

		self.fp_unit = player
		self.unit = alive(self.unit) and self.unit or World:spawn_unit(unit_name_ids, pos, rot)
		Network:detach_unit(self.unit)

		-- The third person unit should be destroyed whenever the first person unit is destroyed
		player:base().pre_destroy = function (self, ...)
			if alive(ThirdPerson.unit) then
				World:delete_unit(ThirdPerson.unit)
			end
			PlayerBase.pre_destroy(self, ...)
		end

		local unit_base = self.unit:base()
		local unit_movement = self.unit:movement()
		local unit_inventory = self.unit:inventory()
		local unit_sound = self.unit:sound()

		-- Hook some functions
		unit_base.pre_destroy = function (self, unit)
			self._unit:movement():pre_destroy(unit)
			self._unit:inventory():pre_destroy(self._unit)
			UnitBase.pre_destroy(self, unit)
		end

		-- No contours
		self.unit:contour().add = function () end

		-- No revive SO
		unit_movement._register_revive_SO = function () end
		unit_movement.set_need_assistance = function (self, need_assistance) self._need_assistance = need_assistance end
		unit_movement.set_need_revive = function (self, need_revive) self._need_revive = need_revive end

		local look_vec_modified = Vector3()
		unit_movement.update = function (self, ...)
			HuskPlayerMovement.update(self, ...)
			if alive(ThirdPerson.fp_unit) then
				-- correct aiming direction so that lasers are approximately the same in first and third person
				mvector3.set(look_vec_modified, ThirdPerson.fp_unit:camera():forward())
				mvector3.rotate_with(look_vec_modified, Rotation(ThirdPerson.fp_unit:camera():rotation():z(), 1))
				self:set_look_dir_instant(look_vec_modified)
			end
		end

		unit_movement.sync_action_walk_nav_point = function (self, pos, speed, action)
			speed = speed or 1
			self._movement_path = self._movement_path or {}
			self._movement_history = self._movement_history or {}
			local path_len = #self._movement_path
			pos = pos or path_len > 0 and self._movement_path[path_len].pos or mvector3.copy(self:m_pos())
			local on_ground = self:_chk_ground_ray(pos)
			local type = "ground"
			if self._zipline and self._zipline.enabled then
				type = "zipline"
			elseif not on_ground then
				type = "air"
			end
			local prev_node = self._movement_history[#self._movement_history]
			if type == "ground" and prev_node and self:action_is(prev_node.action, "jump") then
				type = "air"
			end
			local node = {
				pos = pos,
				speed = speed,
				type = type,
				action = {action}
			}
			table.insert(self._movement_path, node)
			table.insert(self._movement_history, node)
			local len = #self._movement_history
			if len > 1 then
				self:_determine_node_action(#self._movement_history, node)
			end
			for i = 1, #self._movement_history - tweak_data.network.player_path_history, 1 do
				table.remove(self._movement_history, 1)
			end
		end

		unit_movement.set_position = function (self, pos)
			if alive(ThirdPerson.fp_unit) and ThirdPerson.fp_unit:camera():first_person() then
				self._unit:set_position(Vector3(0, 0, -10000))
			else
				-- partial fix for movement sync, not perfect as it overrides some movement animations like jumping
				HuskPlayerMovement.set_position(self, alive(ThirdPerson.fp_unit) and ThirdPerson.fp_unit:movement():m_pos() or pos)
			end
		end

		unit_movement.set_head_visibility = function (self, visible)
			self._obj_visibilities = self._obj_visibilities or {}
			local char_name = managers.criminals:character_name_by_unit(self._unit)
			local new_char_name = managers.criminals.convert_old_to_new_character_workname(char_name)
			-- Disable head and hair objects - many thanks for being inconsistent with naming your objects, Overkill
			local try_names = { "g_vest_neck", "g_head", "g_head_%s", "g_%s_mask_off", "g_%s_mask_on", "g_hair", "g_%s_hair", "g_hair_mask_on", "g_hair_mask_off" }
			local obj, key
			for _, v in ipairs(try_names) do
				obj = char_name and self._unit:get_object(Idstring(v:format(char_name))) or new_char_name and self._unit:get_object(Idstring(v:format(new_char_name)))
				if obj then
					key = obj:name():key()
					self._obj_visibilities[key] = self._obj_visibilities[key] or obj:visibility()
					obj:set_visibility(visible and self._obj_visibilities[key])
				end
			end
			self._mask_visibility = self._mask_visibility or self._unit:inventory()._mask_visibility
			self._unit:inventory():set_mask_visibility(visible and self._mask_visibility)
		end

		unit_movement.update_visual_state = function (self)
			local player_peer = managers.network:session():local_peer()
			local complete_outfit = player_peer:blackmarket_outfit()
			local character = player_peer:character()
			local player_style_u_name = tweak_data.blackmarket:get_player_style_value(complete_outfit.player_style, character, "third_unit")
			if player_style_u_name then
				managers.dyn_resource:load(unit_ids, Idstring(player_style_u_name), DynamicResourceManager.DYN_RESOURCES_PACKAGE)
			end
			local gloves_u_name = tweak_data.blackmarket:get_glove_value(complete_outfit.glove_id, character, "third_unit", complete_outfit.player_style, complete_outfit.suit_variation)
			if gloves_u_name then
				managers.dyn_resource:load(unit_ids, Idstring(gloves_u_name), DynamicResourceManager.DYN_RESOURCES_PACKAGE)
			end
			complete_outfit.is_local_peer = false
			complete_outfit.visual_seed = player_peer._visual_seed
			complete_outfit.armor_id = player_peer._equipped_armor_id
			complete_outfit.mask_id = complete_outfit.mask.mask_id
			managers.criminals.set_character_visual_state(self._unit, player_peer:character(), complete_outfit)
		end

		unit_inventory.set_mask_visibility = function (self, state) HuskPlayerInventory.set_mask_visibility(self, not ThirdPerson.settings.immersive_first_person and state) end

		-- adjust weapon switch to support custom weapons
		unit_inventory._perform_switch_equipped_weapon = function (self, weap_index, blueprint_string, cosmetics_string, peer)
			self._checked_weapons = self._checked_weapons or {}
			if not self._checked_weapons[weap_index] then
				local equipped = ThirdPerson.fp_unit:inventory():equipped_unit()
				local checked_weap = {
					name = equipped:base()._factory_id and equipped:base()._factory_id .. "_npc" or "wpn_fps_ass_amcar_npc",
					cosmetics_string = cosmetics_string or self:cosmetics_string_from_peer(peer, checked_weap.name),
					blueprint_string = blueprint_string or equipped:blueprint_to_string()
				}

				local factory_weapon = tweak_data.weapon.factory[checked_weap.name]
				if not factory_weapon or factory_weapon.custom then
					local weapon = tweak_data.weapon[managers.weapon_factory:get_weapon_id_by_factory_id(equipped:base()._factory_id or "wpn_fps_ass_amcar_npc")]
					local based_on = weapon and weapon.based_on and tweak_data.weapon[weapon.based_on]
					local based_on_name = based_on and tweak_data.upgrades.definitions[weapon.based_on] and tweak_data.upgrades.definitions[weapon.based_on].factory_id
					local default = { "wpn_fps_pis_g17_npc", "wpn_fps_ass_amcar_npc" }
					local new_name = based_on_name and based_on.use_data.selection_index == weapon.use_data.selection_index and (based_on_name .. "_npc") or weapon and default[weapon.use_data.selection_index] or default[1]

					ThirdPerson:log("WARNING: Replaced custom weapon " .. checked_weap.name .. " with " .. new_name)

					checked_weap.name = new_name
					checked_weap.blueprint_string = managers.weapon_factory:blueprint_to_string(checked_weap.name, managers.weapon_factory:get_default_blueprint_by_factory_id(checked_weap.name))
					checked_weap.cosmetics_string = "nil-1-0"
				end

				self._checked_weapons[weap_index] = checked_weap
			end

			local checked_weap = self._checked_weapons[weap_index]
			if checked_weap then
				self:add_unit_by_factory_name(checked_weap.name, true, true, checked_weap.blueprint_string, checked_weap.cosmetics_string)
			end
		end

		-- We don't want our third person unit to make any sound, so we're plugging empty functions here
		unit_sound.say = function () end
		unit_sound.play = function () end
		unit_sound._play = function () end

		-- Setup some stuff
		unit_inventory:set_melee_weapon(player_peer:melee_id(), true)

		self.unit:damage():run_sequence_simple(managers.blackmarket:character_sequence_by_character_id(player_peer:character_id(), player_peer:id()))

		unit_movement:set_character_anim_variables()
		unit_movement:update_visual_state()
		if ThirdPerson.settings.immersive_first_person then
			unit_movement:set_head_visibility(false)
		end

		local level_data = managers.job and managers.job:current_level_data()
		if level_data and level_data.player_sequence then
			self.unit:damage():run_sequence_simple(level_data.player_sequence)
		end

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

		if self.settings.start_in_tp then
			player:camera():set_third_person()
		else
			player:camera()._toggled_fp = true
		end

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

if RequiredScript then

	local fname = ThirdPerson.mod_path .. RequiredScript:gsub(".+/(.+)", "lua/%1.lua")
	if io.file_is_readable(fname) then
		dofile(fname)
	end

end
