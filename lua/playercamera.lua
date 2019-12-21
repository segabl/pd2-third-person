if not ThirdPerson.settings.enabled then
  return
end

local mrot = Rotation()
local mvec1 = Vector3()
local mvec2 = Vector3()
local lookat = Vector3()

local init_original = PlayerCamera.init
function PlayerCamera:init(...)
  self._third_person = false
  self._tp_forward = Vector3()
  self._slot_mask = managers.slot:get_mask("world_geometry")
  self._slot_mask_all = managers.slot:get_mask("bullet_impact_targets")
  local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
  self._crosshair = hud.panel:bitmap({
    name = "third_person_crosshair",
    texture = "units/pd2_dlc1/weapons/wpn_effects_textures/wpn_sight_reticle_l_1_green_il",
    blend_mode = "add",
    w = 32,
    h = 32,
    visible = ThirdPerson.settings.third_person_crosshair
  })
  self._tp_camera_object = World:create_camera()
  self._tp_camera_object:set_near_range(3)
  self._tp_camera_object:set_far_range(250000)
  self._tp_camera_object:set_fov(75)
  self._transition = 1
  self:refresh_tp_cam_settings()

  init_original(self, ...)
end

function PlayerCamera:refresh_tp_cam_settings()
  if not ThirdPerson.settings.immersive_first_person then
    self._tp_cam_dir = Vector3(ThirdPerson.settings.cam_x, -ThirdPerson.settings.cam_y, ThirdPerson.settings.cam_z)
    self._tp_cam_dis = mvector3.length(self._tp_cam_dir)
    if self._tp_cam_dis > 0 then
      mvector3.multiply(self._tp_cam_dir, 1 / self._tp_cam_dis)
    end
  end
  self._crosshair:set_visible(self:third_person() and ThirdPerson.settings.third_person_crosshair)
end

function PlayerCamera:check_set_third_person_position()
  if self._transition >= 1 then
    return
  end
  if not ThirdPerson.settings.immersive_first_person then
    -- set cam position
    mvector3.set(mvec1, self._tp_cam_dir)
    mvector3.rotate_with(mvec1, self._m_cam_rot)
    local ray = World:raycast("ray", self._m_cam_pos, self._m_cam_pos + mvec1 * (self._tp_cam_dis + 20), "slot_mask", self._slot_mask)
    mvector3.multiply(mvec1, ray and ray.distance - 20 or self._tp_cam_dis)
    mvector3.add(mvec1, self._m_cam_pos)
    mvector3.multiply(mvec1, (1 - self._transition))
    mvector3.set(mvec2, self._m_cam_pos)
    mvector3.multiply(mvec2, self._transition)
    mvector3.add(mvec1, mvec2)
    self._tp_camera_object:set_position(mvec1)
    --mvector3.set(mvec2, lookat)
    --mvector3.subtract(mvec2, mvec1)
    --mrotation.set_look_at(mrot, mvec2, math.UP)
    --self._tp_camera_object:set_rotation(self._m_cam_rot)
  elseif alive(ThirdPerson.unit) then
    local hpos = ThirdPerson.unit:movement():m_head_pos()
    local hrot = ThirdPerson.unit:movement():m_head_rot()
    mvector3.set(mvec1, hpos)
    mrotation.y(self._m_cam_rot, mvec2)
    mvector3.multiply(mvec2, 10)
    mvector3.add(mvec1, mvec2)
    mrotation.z(self._m_cam_rot, mvec2)
    mvector3.multiply(mvec2, 10)
    mvector3.add(mvec1, mvec2)
    self._tp_camera_object:set_position(mvec1)
    --mvector3.set(mvec2, lookat)
    --mvector3.subtract(mvec2, mvec1)
    --mrotation.set_look_at(mrot, mvec2, math.UP)
    --self._tp_camera_object:set_rotation(self._m_cam_rot)
  end
  -- set crosshair
  if self._crosshair:visible() then
    mvector3.set(lookat, self._m_cam_fwd)
    mvector3.multiply(lookat, 10000)
    mvector3.add(lookat, self._m_cam_pos)
    local ray = World:raycast("ray", self._m_cam_pos, lookat, "slot_mask", self._slot_mask)
    mvector3.set(lookat, self._m_cam_fwd)
    mvector3.multiply(lookat, ray and ray.distance or 10000)
    mvector3.add(lookat, self._m_cam_pos)
    
    local screen_pos = managers.hud._workspace:world_to_screen(self._tp_camera_object, lookat)
    self._crosshair:set_center(screen_pos.x, screen_pos.y)
  end
end

local set_position_original = PlayerCamera.set_position
function PlayerCamera:set_position(...)
  set_position_original(self, ...)
  self:check_set_third_person_position()
end

local set_rotation_original = PlayerCamera.set_rotation
function PlayerCamera:set_rotation(...)
  set_rotation_original(self, ...)
  self._tp_camera_object:set_rotation(self._m_cam_rot)
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
end

function PlayerCamera:set_third_person()
  if alive(ThirdPerson.unit) and not self._toggled_fp then
    self._third_person = true
    self._crosshair:set_visible(ThirdPerson.settings.third_person_crosshair)
  end
end

local update_original = PlayerCamera.update
function PlayerCamera:update(unit, t, dt, ...)
  update_original(self, unit, t, dt, ...)

  if not self._third_person and self._transition < 1 then
    self._transition = self._transition + 10 * dt
    if self._transition >= 1 then
      self._transition = 1
      self._camera_unit:set_visible(true)
      self._vp:set_camera(self._camera_object)
      local wbase = ThirdPerson.fp_unit:inventory():equipped_unit():base()
      wbase:set_visibility_state(true)
      wbase:set_gadget_silent(true)
    end
  end
  if self._third_person then
    local wbase = ThirdPerson.fp_unit:inventory():equipped_unit():base()
    if not wbase._invisible then
      wbase:set_visibility_state(false)
      wbase:set_gadget_silent(false)
      self._camera_unit:set_visible(false)
    end
    if self._transition > 0 then
      self._transition = self._transition - 10 * dt
      if self._transition <= 0 then
        self._transition = 0
        self._vp:set_camera(self._tp_camera_object)
      end
    end
  end
end

function PlayerCamera:first_person()
  return not self._third_person
end

function PlayerCamera:third_person()
  return self._third_person
end