local set_position_original = FPCameraPlayerBase.set_position
function FPCameraPlayerBase:set_position(...)
  local cam = alive(self._parent_unit) and self._parent_unit == ThirdPerson.fp_unit and ThirdPerson.fp_unit:camera()
  if cam and cam:third_person() then
    self._unit:set_position(Vector3(0, 0, -100000))
  else
    set_position_original(self, ...)
  end
end