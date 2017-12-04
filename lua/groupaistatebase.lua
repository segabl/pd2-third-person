-- we need to block on_criminal_* function calls from GroupAIStateBase when called with the third person unit
-- since it would try to access data of the third person unit, which isn't there since we unregistered it when we created it
-- it's not the best solution but it's easier than preventing any calls to any of the functions by the third person unit
for func_name, orig_func in pairs(GroupAIStateBase) do
  if func_name:find("^on_criminal_") then
    GroupAIStateBase[func_name] = function (self, unit, ...)
      if alive(ThirdPerson.unit) and unit == ThirdPerson.unit then
        return
      end
      return orig_func(self, unit, ...)
    end
  end
end