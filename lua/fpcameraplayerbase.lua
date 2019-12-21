if not ThirdPerson.settings.enabled then
  return
end

local prevent = { "spawn_mask", "spawn_melee_item", "spawn_grenade" }
for _, v in pairs(prevent) do
  local orig = FPCameraPlayerBase[v]
  FPCameraPlayerBase[v] = function (self, ...)
    if alive(self._parent_unit) and self._parent_unit == ThirdPerson.fp_unit and ThirdPerson.fp_unit:camera():third_person() then
      return
    end
    return orig(self, ...)
  end
end