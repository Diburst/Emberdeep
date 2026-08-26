-- Game state stack. States are tables with optional callbacks:
-- enter(prev, ...), leave(), resume(...), update(dt), draw(),
-- pressed(player, action), released(player, action), keypressed(key),
-- textinput(t), rawpressed(device, id)  -- rawpressed used by remap UI
-- If state.translucent is true, the state below it is drawn first.
local State = {
  stack = {},
}

function State.top()
  return State.stack[#State.stack]
end

-- Any state transition consumes this frame's pressed/released edges so
-- the keypress that opened/closed a screen can't be double-handled by
-- the state underneath (e.g. TAB closing the map, then reopening it).
local function consumeInput()
  local ok, Input = pcall(require, "src.input")
  if ok and Input.players then
    for slot = 1, 2 do
      if Input.players[slot] then
        Input.players[slot].pressed = {}
        Input.players[slot].released = {}
      end
    end
    Input.queue = {}
    Input.menuQueue = {}
  end
end

function State.push(s, ...)
  State.stack[#State.stack + 1] = s
  consumeInput()
  if s.enter then s:enter(State.stack[#State.stack - 1], ...) end
end

function State.pop(...)
  local s = table.remove(State.stack)
  consumeInput()
  if s and s.leave then s:leave() end
  local top = State.top()
  if top and top.resume then top:resume(...) end
  return s
end

function State.switch(s, ...)
  while #State.stack > 0 do
    local old = table.remove(State.stack)
    if old.leave then old:leave() end
  end
  State.push(s, ...)
end

-- Replace only the top state.
function State.replace(s, ...)
  local old = table.remove(State.stack)
  if old and old.leave then old:leave() end
  State.push(s, ...)
end

function State.update(dt)
  local top = State.top()
  if top and top.update then top:update(dt) end
end

function State.draw()
  -- find lowest state we need to draw (translucent states show below)
  local first = #State.stack
  while first > 1 and State.stack[first].translucent do
    first = first - 1
  end
  for i = first, #State.stack do
    local s = State.stack[i]
    if s.draw then s:draw() end
  end
end

function State.event(name, ...)
  local top = State.top()
  if top and top[name] then top[name](top, ...) end
end

-- ONE PHYSICAL PRESS, ONE STATE.
--
-- main.lua drains a frame's input into three lists and hands them to the
-- stack. The lists are built BEFORE any of them is delivered, so a state
-- that pushes or pops partway through used to hand the REST of that
-- frame's events to whatever was underneath it -- and `consumeInput`
-- above cannot help, because those events have already left the queue.
--
-- That is how the map screen broke. TAB is bound to the `map` action AND
-- to the menu action `backbtn`; J is the FIRE key AND the menu action
-- `cancel`. Pressing J with the map up fired `cancel` at the map, which
-- popped it, and the same frame's held FIRE then reached the game
-- underneath -- reported exactly as "if I hit J the bot shoots, which
-- closes the map".
--
-- So dispatch stops at a transition. The remaining events were addressed
-- to a state that is no longer there.
function State.dispatch(presses, raws, menus)
  local top = State.top()
  local function changed() return State.top() ~= top end
  for _, ev in ipairs(raws or {}) do
    if changed() then return end
    State.event("raw", ev)
  end
  for _, ev in ipairs(menus or {}) do
    if changed() then return end
    State.event("menu", ev.action, ev)
  end
  for _, ev in ipairs(presses or {}) do
    if changed() then return end
    State.event("pressed", ev.player, ev.action)
  end
end

return State
