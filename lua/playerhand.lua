-- Sync arm movements if for whatever reason the player is using Third Person in VR
Hooks:PostHook(PlayerHand, "send_filtered", "send_filtered_third_person", function (self, func, ...)
	if not alive(ThirdPerson.unit) then
		return
	end

	local handler = managers.network and managers.network._handlers and managers.network._handlers.unit
	if handler and handler[func] then
		handler[func](handler, ThirdPerson.unit, ...)
	end
end)
