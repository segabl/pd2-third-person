-- setup the third person unit whenever the local player is set
local set_unit_original = NetworkPeer.set_unit
function NetworkPeer:set_unit(unit, ...)
  if unit and self == managers.network:session():local_peer() then
    ThirdPerson.fp_unit = unit
  end
  set_unit_original(self, unit, ...)
  if ThirdPerson.fp_unit == unit and Utils:IsInGameState() then
    ThirdPerson:setup_unit(unit)
  end
end