local mvec_set = mvector3.set
local mvec_add = mvector3.add
local mvec_mul = mvector3.multiply
local mvec_rot_with = mvector3.rotate_with
local mvec_len = mvector3.length

Hooks:PostHook(PlayerCamera, "init", "init_third_person", function (self)
	self._third_person = false
	self._tp_forward = Vector3()
	self._slot_mask = managers.slot:get_mask("world_geometry")
	self._slot_mask_all = managers.slot:get_mask("bullet_impact_targets_no_criminals")
	local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
	self._crosshair = hud.panel:bitmap({
		name = "third_person_crosshair",
		texture = "units/pd2_dlc1/weapons/wpn_effects_textures/wpn_sight_reticle_l_1_green_il",
		blend_mode = "add",
		w = ThirdPerson.settings.third_person_crosshair_size,
		h = ThirdPerson.settings.third_person_crosshair_size,
		visible = ThirdPerson.settings.third_person_crosshair
	})
	self:refresh_tp_cam_settings()
end)

function PlayerCamera:refresh_tp_cam_settings()
	if not ThirdPerson.settings.immersive_first_person then
		self._tp_cam_dir = Vector3(ThirdPerson.settings.cam_x, -ThirdPerson.settings.cam_y, ThirdPerson.settings.cam_z)
		self._tp_cam_dis = mvec_len(self._tp_cam_dir)
		if self._tp_cam_dis > 0 then
			mvec_mul(self._tp_cam_dir, 1 / self._tp_cam_dis)
		end
	end
	local data = tweak_data.gui.weapon_texture_switches.types.sight[ThirdPerson.settings.third_person_crosshair_style] or tweak_data.gui.weapon_texture_switches.types.sight[1]
	local suffix = tweak_data.gui.weapon_texture_switches.types.sight.suffix
	self._crosshair_path_1 = data.texture_path:gsub(suffix .. "$", "_green" .. suffix)
	self._crosshair_path_2 = data.texture_path:gsub(suffix .. "$", "_yellow" .. suffix)
	self._crosshair:set_image(self._crosshair_path_1)
	self._crosshair:set_size(ThirdPerson.settings.third_person_crosshair_size, ThirdPerson.settings.third_person_crosshair_size)
	self._crosshair:set_visible(self:third_person() and ThirdPerson.settings.third_person_crosshair)
end

local mvec = Vector3()
function PlayerCamera:check_set_third_person_position(pos, rot)
	if self:first_person() or _G.IS_VR then
		return
	end
	if not ThirdPerson.settings.immersive_first_person then
		-- set cam position
		mvec_set(mvec, self._tp_cam_dir)
		mvec_rot_with(mvec, rot)
		local ray = World:raycast("ray", pos, pos + mvec * (self._tp_cam_dis + 20), "slot_mask", self._slot_mask)
		mvec_mul(mvec, ray and ray.distance - 20 or self._tp_cam_dis)
		mvec_add(mvec, pos)
		self._camera_controller:set_camera(mvec)
	elseif alive(ThirdPerson.unit) then
		if not self._skip_frames then
			local pos = ThirdPerson.head_obj:position()
			local rot = ThirdPerson.head_obj:rotation()
			mvec_set(mvec, rot:y())
			mvec_mul(mvec, 10)
			mvec_add(mvec, pos)
		else
			local rot = self:rotation()
			mvec_set(mvec, rot:x() * 10 + rot:y() * 20 + rot:z() * 20)
			mvec_add(mvec, self:position())
			self._skip_frames = self._skip_frames > 1 and self._skip_frames - 1 or nil
		end
		self._camera_controller:set_camera(mvec)
	end
	-- set crosshair
	if self._crosshair:visible() then
		mvec_set(mvec, self:forward())
		local ray = World:raycast("ray", self:position(), self:position() + mvec * 10000, "slot_mask", self._slot_mask_all)
		mvec_mul(mvec, ray and ray.distance or 10000)
		mvec_add(mvec, self:position())
		mvec_set(mvec, managers.hud._workspace:world_to_screen(self._camera_object, mvec))
		self._crosshair:set_center(mvec.x, mvec.y)
		if ray and ray.unit and managers.enemy:is_enemy(ray.unit) then
			self._crosshair:set_image(self._crosshair_path_2)
		else
			self._crosshair:set_image(self._crosshair_path_1)
		end
	end
end

Hooks:PostHook(PlayerCamera, "set_position", "set_position_third_person", function (self, pos)
	self:check_set_third_person_position(pos, self:rotation())
end)

Hooks:PostHook(PlayerCamera, "set_rotation", "set_rotation_third_person", function (self, rot)
	self:check_set_third_person_position(self:position(), rot)
end)

Hooks:PreHook(PlayerCamera, "destroy", "destroy_third_person", function (self)
	if self._crosshair then
		local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
		hud.panel:remove(self._crosshair)
	end
end)

function PlayerCamera:toggle_third_person(force)
	if self._mode_locked and not force then
		return
	end
	self._mode_locked = not self._mode_locked and force
	if self:first_person() then
		self._toggled_fp = false
		self:set_third_person()
	else
		self._toggled_fp = true
		self:set_first_person()
	end
end

function PlayerCamera:set_first_person()
	self._third_person = false
	self._crosshair:set_visible(false)
	if alive(ThirdPerson.unit) then
		ThirdPerson.unit:movement():set_position(Vector3())
	end
	self._camera_unit:base()._wants_fp = nil
end

function PlayerCamera:set_third_person()
	if alive(ThirdPerson.unit) and not self._toggled_fp then
		self._third_person = true
		self._crosshair:set_visible(ThirdPerson.settings.third_person_crosshair)
		ThirdPerson.unit:movement():set_position(Vector3())
	end
	self._camera_unit:base()._wants_fp = nil
	self._skip_frames = 4
end

function PlayerCamera:first_person()
	return not self._third_person
end

function PlayerCamera:third_person()
	return self._third_person
end
