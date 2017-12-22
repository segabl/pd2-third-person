if not ThirdPerson.settings.enabled then
  return
end

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