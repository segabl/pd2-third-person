-- if the sender isn't set, assume it is sent by the local peer
-- so we can use this to call UnitNetworkHandler methods without a sender
local _verify_sender_original = BaseNetworkHandler._verify_sender
function BaseNetworkHandler._verify_sender(rpc)
  return rpc and _verify_sender_original(rpc) or managers.network:session():local_peer()
end