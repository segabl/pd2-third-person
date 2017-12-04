local init_original = PlayerCamera.init
function PlayerCamera:init(...)
  init_original(self, ...)
  self._third_person = false
  self._tp_forward = Vector3()
  self._slot_mask = managers.slot:get_mask("world_geometry")
  self._slot_mask_all = managers.slot:get_mask("bullet_impact_targets")
  local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
  self._crosshair = hud.panel:bitmap({
    name = "third_person_crosshair",
    texture = "units/pd2_dlc1/weapons/wpn_effects_textures/wpn_sight_reticle_l_1_green_il",
    blend_mode = "add",
    w = 24,
    h = 24,
    visible = ThirdPerson.settings.third_person_crosshair
  })
  self:refresh_tp_cam_settings()
end

function PlayerCamera:refresh_tp_cam_settings()
  self._tp_cam_dir = Vector3(ThirdPerson.settings.cam_x, -ThirdPerson.settings.cam_y, ThirdPerson.settings.cam_z)
  self._tp_cam_dis = mvector3.length(self._tp_cam_dir)
  if self._tp_cam_dis > 0 then
    mvector3.multiply(self._tp_cam_dir, 1 / self._tp_cam_dis)
  end
  self._crosshair:set_visible(self:third_person() and ThirdPerson.settings.third_person_crosshair)
end

local mvec = Vector3()
function PlayerCamera:check_set_third_person_position(pos, rot)
  if self:third_person() then
    -- set cam position
    mvector3.set(mvec, self._tp_cam_dir)
    mvector3.rotate_with(mvec, rot)
    local ray = World:raycast("ray", pos, pos + mvec * (self._tp_cam_dis + 20), "slot_mask", self._slot_mask)
    mvector3.multiply(mvec, ray and ray.distance - 20 or self._tp_cam_dis)
    mvector3.add(mvec, pos)
    self._camera_controller:set_camera(mvec)
    -- set crosshair
    if self._crosshair:visible() then
      mvector3.set(mvec, self:forward())
      ray = World:raycast("ray", self:position(), self:position() + mvec * 10000, "slot_mask", self._slot_mask_all)
      mvector3.multiply(mvec, ray and ray.distance or 10000)
      mvector3.add(mvec, self:position())
      mvector3.set(mvec, managers.hud._workspace:world_to_screen(self._camera_object, mvec))
      self._crosshair:set_center(mvec.x, mvec.y)
      if ray and ray.unit and managers.enemy:is_enemy(ray.unit) then
        self._crosshair:set_image("units/pd2_dlc1/weapons/wpn_effects_textures/wpn_sight_reticle_l_1_yellow_il")
      else
        self._crosshair:set_image("units/pd2_dlc1/weapons/wpn_effects_textures/wpn_sight_reticle_l_1_green_il")
      end
    end
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
  ThirdPerson.unit:movement():set_position(Vector3())
end

function PlayerCamera:set_third_person()
  if not self._toggled_fp then
    self._third_person = true
    self._crosshair:set_visible(ThirdPerson.settings.third_person_crosshair)
    ThirdPerson.unit:movement():set_position(Vector3())
  end
end

function PlayerCamera:first_person()
  return not self._third_person
end

function PlayerCamera:third_person()
  return self._third_person
end