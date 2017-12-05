-- ugly hack, pls don't look at it :(
local _verify_sender_original = BaseNetworkHandler._verify_sender
function BaseNetworkHandler._verify_sender(rpc, ...)
  if not rpc then
    return managers.network:session():local_peer()
  end
  return _verify_sender_original(self, rpc, ...)
end