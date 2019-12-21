if not ThirdPerson.settings.enabled then
  return
end

local set_visibility_state_original = NewRaycastWeaponBase.set_visibility_state
function NewRaycastWeaponBase:set_visibility_state(state, ...)
  self._invisible = not state
  return set_visibility_state_original(self, state, ...)
end

local _spawn_muzzle_effect_original = NewRaycastWeaponBase._spawn_muzzle_effect
function NewRaycastWeaponBase:_spawn_muzzle_effect(...)
  if self._invisible then
    return
  end
  return _spawn_muzzle_effect_original(self, ...)
end

local _spawn_shell_eject_effect_original = NewRaycastWeaponBase._spawn_shell_eject_effect
function NewRaycastWeaponBase:_spawn_shell_eject_effect(...)
  if self._invisible then
    return
  end
  return _spawn_shell_eject_effect_original(self, ...)
end

local _spawn_tweak_data_effect_original = NewRaycastWeaponBase._spawn_tweak_data_effect
function NewRaycastWeaponBase:_spawn_tweak_data_effect(...)
  if self._invisible then
    return
  end
  return _spawn_tweak_data_effect_original(self, ...)
end

function NewRaycastWeaponBase:set_gadget_silent(state)
  if not self._enabled or not self._assembly_complete then
    return
  end

  local gadget = self._parts[self._gadgets[self._gadget_on]]

  if gadget and alive(gadget.unit) then
    gadget.unit:base():set_state(state, nil, nil)
  end
end

local set_gadget_on_original = NewRaycastWeaponBase.set_gadget_on
function NewRaycastWeaponBase:set_gadget_on(...)
  set_gadget_on_original(self, ...)
  if self._setup and self._setup.user_unit == ThirdPerson.fp_unit and ThirdPerson.fp_unit:camera():third_person() then
    self:set_gadget_silent(false)
  end
end