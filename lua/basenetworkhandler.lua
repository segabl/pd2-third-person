-- ugly hack, pls don't look at it :(
local _verify_sender_original = BaseNetworkHandler._verify_sender
function BaseNetworkHandler._verify_sender(rpc)
  return rpc and _verify_sender_original(rpc) or managers.network:session():local_peer()
end