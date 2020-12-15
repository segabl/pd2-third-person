-- check if we need to switch to first person on downed
Hooks:PreHook(PlayerBleedOut, "enter", "enter_third_person", function (self)
	if self._unit == ThirdPerson.fp_unit and ThirdPerson.settings.first_person_on_downed and self._unit:camera():third_person() then
		self._was_in_tp = true
		self._unit:camera():toggle_third_person()
	end
end)

-- check if we need to switch back to third person
Hooks:PreHook(PlayerBleedOut, "exit", "exit_third_person", function (self)
	if self._unit == ThirdPerson.fp_unit and self._was_in_tp and self._unit:camera():first_person() then
		self._was_in_tp = nil
		self._unit:camera():toggle_third_person()
	end
end)
