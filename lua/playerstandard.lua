-- check if we need to switch back to third person
Hooks:PreHook(PlayerStandard, "enter", "enter_third_person", function (self, state_data)
	if self._unit == ThirdPerson.fp_unit and state_data._was_in_tp then
		self._unit:camera():set_third_person()
		state_data._was_in_tp = nil
	end
end)

Hooks:PostHook(PlayerStandard, "_start_action_steelsight", "_start_action_steelsight_third_person", function (self)
	if self._unit == ThirdPerson.fp_unit and self._state_data.in_steelsight and ThirdPerson.settings.first_person_on_steelsight then
		self._unit:camera():set_first_person()
	end
end)

Hooks:PostHook(PlayerStandard, "_end_action_steelsight", "_end_action_steelsight_third_person", function (self)
	if self._unit == ThirdPerson.fp_unit and ThirdPerson.settings.first_person_on_steelsight then
		self._unit:camera():set_third_person()
	end
end)
