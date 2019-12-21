if not ThirdPerson.settings.enabled then
  return
end

local enter_original = PlayerStandard.enter
function PlayerStandard:enter(state_data, enter_data, ...)
  if self._unit == ThirdPerson.fp_unit and state_data._was_in_tp then
    self._unit:camera():set_third_person()
    state_data._was_in_tp = nil
  end
  enter_original(self, state_data, enter_data, ...)
end

local _start_action_steelsight_original = PlayerStandard._start_action_steelsight
function PlayerStandard:_start_action_steelsight(...)
  _start_action_steelsight_original(self, ...)
  if self._unit == ThirdPerson.fp_unit and self._state_data.in_steelsight and ThirdPerson.settings.first_person_on_steelsight then
    self._unit:camera():set_first_person()
  end
end

local _end_action_steelsight_original = PlayerStandard._end_action_steelsight
function PlayerStandard:_end_action_steelsight(...)
  _end_action_steelsight_original(self, ...)
  if self._unit == ThirdPerson.fp_unit and ThirdPerson.settings.first_person_on_steelsight then
    self._unit:camera():set_third_person()
  end
end