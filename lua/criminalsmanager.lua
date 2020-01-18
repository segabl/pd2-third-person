if not ThirdPerson.settings.enabled then
  return
end

-- we need to change the *_by_unit functions of CriminalsManager to return the data of the first person unit
-- when called with the third person unit so it can get data like mask id or character name without problem
for func_name, orig_func in pairs(CriminalsManager) do
  if func_name:find("_by_unit") then
    CriminalsManager[func_name] = function (self, unit)
      return orig_func(self, unit == ThirdPerson.unit and alive(ThirdPerson.unit) and alive(ThirdPerson.fp_unit) and ThirdPerson.fp_unit or unit)
    end
  end
end

-- we have to hook this function since it's called on player state change for some reason
-- and we need to disable the first person char mesh if we're in third person
local set_character_visual_state_original = CriminalsManager.set_character_visual_state
function CriminalsManager.set_character_visual_state(unit, ...)
  set_character_visual_state_original(unit, ...)
  if unit:camera() and unit:camera():third_person() then
    unit:camera():update_camera_unit_visibility(false)
  end
end