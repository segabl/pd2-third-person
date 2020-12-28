local set_position_original = FPCameraPlayerBase.set_position
function FPCameraPlayerBase:set_position(...)
	local cam = alive(self._parent_unit) and self._parent_unit == ThirdPerson.fp_unit and ThirdPerson.fp_unit:camera()
	if cam and cam:third_person() then
		self._unit:set_position(Vector3(0, 0, -100000))
	else
		set_position_original(self, ...)
	end
end

Hooks:PostHook(FPCameraPlayerBase, "_update_stance", "_update_stance_third_person", function (self)
	if self._wants_fp ~= nil then
		local cam = alive(self._parent_unit) and self._parent_unit == ThirdPerson.fp_unit and ThirdPerson.fp_unit:camera()
		if not cam then
			return
		end
		if self._wants_fp and not self._shoulder_stance.transition then
			cam:set_first_person()
		elseif not self._wants_fp then
			cam:set_third_person()
		end
	end
end)
