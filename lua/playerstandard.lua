local _start_action_steelsight_original = PlayerStandard._start_action_steelsight
function PlayerStandard:_start_action_steelsight(...)
  _start_action_steelsight_original(self, ...)
  if self._state_data.in_steelsight and ThirdPerson.settings.first_person_on_steelsight then
    self._unit:camera():set_first_person()
  end
end

local _end_action_steelsight_original = PlayerStandard._end_action_steelsight
function PlayerStandard:_end_action_steelsight(...)
  _end_action_steelsight_original(self, ...)
  if ThirdPerson.settings.first_person_on_steelsight then
    self._unit:camera():set_third_person()
  end
end