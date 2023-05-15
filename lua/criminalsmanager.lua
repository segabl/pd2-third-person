-- we need to change the *_by_unit functions of CriminalsManager to return the data of the first person unit
-- when called with the third person unit so it can get data like mask id or character name without problem
for func_name, orig_func in pairs(CriminalsManager) do
	if func_name:find("_by_unit") then
		CriminalsManager[func_name] = function (self, unit)
			return orig_func(self, unit == ThirdPerson.unit and alive(ThirdPerson.unit) and alive(ThirdPerson.fp_unit) and ThirdPerson.fp_unit or unit)
		end
	end
end


local update_character_visual_state_original = CriminalsManager.update_character_visual_state
function CriminalsManager:update_character_visual_state(character_name, visual_state, ...)
	update_character_visual_state_original(self, character_name, visual_state, ...)

	local character = alive(ThirdPerson.unit) and self:character_by_name(character_name)
	if not character or not character.visual_state or not character.visual_state.is_local_peer then
		return
	end

	local visual_state_tp = deep_clone(character.visual_state)
	visual_state_tp.is_local_peer = false
	visual_state_tp.deployable_id = visual_state and visual_state.deployable_id or managers.player:selected_equipment_id() -- deployable is not saved in character state for local peer

	if visual_state_tp.player_style then
		local unit_name = tweak_data.blackmarket:get_player_style_value(visual_state_tp.player_style, character_name, "third_unit")
		if unit_name then
			self:safe_load_asset(character, unit_name, "player_style_third")
		end
	end

	if visual_state_tp.glove_id then
		local unit_name = tweak_data.blackmarket:get_glove_value(visual_state_tp.glove_id, character_name, "unit", visual_state_tp.player_style, visual_state_tp.suit_variation)
		if unit_name then
			self:safe_load_asset(character, unit_name, "glove_id_third")
		end
	end

	if visual_state_tp.deployable_id then
		local style_name = tweak_data.equipments[visual_state_tp.deployable_id] and tweak_data.equipments[visual_state_tp.deployable_id].visual_style
		if style_name then
			local unit_name = tweak_data.blackmarket:get_player_style_value(style_name, character_name, "third_unit")
			if unit_name then
				self:safe_load_asset(character, unit_name, "deployable_id_third")
			end
		end
	end

	CriminalsManager.set_character_visual_state(ThirdPerson.unit, character_name, visual_state_tp)
end
