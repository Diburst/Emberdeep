-- Controller / keyboard remapping for both players.
local P = require "src.assets.palette"
local Input = require "src.input"

local S = { name = "controls", translucent = true }

local REMAP_ACTIONS = { "left", "right", "up", "down", "jump", "fire",
  "special", "util", "interact", "partner", "warp", "pause", "map" }

function S:enter()
  self.player = 1
  self.device = G.anyPad() and "pad" or "kb"
  self.sel = 1
  self.capturing = false
  self.captureIgnore = 0
end

function S:menu(action, ev)
  if self.capturing then return end
  if action == "cancel" then
    G.settings.bindings = Input.bindings
    G.Save.saveSettings()
    G.State.pop()
    if G.Audio then G.Audio.sfx("menuback") end
    return
  end
  local n = #REMAP_ACTIONS + 2 -- + reset row + back row
  if action == "up" then
    self.sel = ((self.sel - 2) % n) + 1
    if G.Audio then G.Audio.sfx("menumove") end
  elseif action == "down" then
    self.sel = (self.sel % n) + 1
    if G.Audio then G.Audio.sfx("menumove") end
  elseif action == "left" or action == "right" then
    if self.sel <= #REMAP_ACTIONS then
      -- toggle device
      self.device = self.device == "pad" and "kb" or "pad"
    else
      self.player = self.player == 1 and 2 or 1
    end
    if G.Audio then G.Audio.sfx("menumove") end
  elseif action == "alt" then
    self.player = self.player == 1 and 2 or 1
    if G.Audio then G.Audio.sfx("menumove") end
  elseif action == "confirm" then
    if self.sel <= #REMAP_ACTIONS then
      self.capturing = true
      self.captureIgnore = 0.25 -- ignore the confirm press itself
      if G.Audio then G.Audio.sfx("menusel") end
    elseif self.sel == #REMAP_ACTIONS + 1 then
      -- reset defaults
      Input.bindings = Input.defaultBindings()
      G.settings.bindings = Input.bindings
      G.Save.saveSettings()
      if G.Audio then G.Audio.sfx("break") end
    else
      G.settings.bindings = Input.bindings
      G.Save.saveSettings()
      G.State.pop()
    end
  end
end

function S:raw(ev)
  if not self.capturing or self.captureIgnore > 0 then return end
  local action = REMAP_ACTIONS[self.sel]
  if ev.kind == "rawpad" and self.device == "pad" then
    Input.rebind(self.player, "pad", action, { type = "button", id = ev.id })
    self.capturing = false
    if G.Audio then G.Audio.sfx("menusel") end
  elseif ev.kind == "rawkey" and self.device == "kb" then
    if ev.id == "escape" then
      self.capturing = false
      return
    end
    Input.rebind(self.player, "kb", action, { type = "key", id = ev.id })
    self.capturing = false
    if G.Audio then G.Audio.sfx("menusel") end
  end
end

function S:update(dt)
  if self.capturing then
    self.captureIgnore = math.max(0, self.captureIgnore - dt)
    -- axis capture (triggers, sticks)
    if self.device == "pad" and self.captureIgnore <= 0 then
      local joy = Input.pads[self.player]
      if joy then
        for _, axis in ipairs({ "leftx", "lefty", "rightx", "righty",
          "triggerleft", "triggerright" }) do
          local v = joy:getGamepadAxis(axis)
          if math.abs(v) > 0.6 then
            Input.rebind(self.player, "pad", REMAP_ACTIONS[self.sel],
              { type = "axis", id = axis, dir = v > 0 and 1 or -1 })
            self.capturing = false
            if G.Audio then G.Audio.sfx("menusel") end
            break
          end
        end
      end
    end
  end
end

function S:draw()
  local g = love.graphics
  g.setColor(P.black[1], P.black[2], P.black[3], 0.92)
  g.rectangle("fill", 0, 0, G.VW, G.VH)
  g.setFont(G.fonts.main)

  g.setColor(P.ember)
  g.printf("CONTROLS", 0, 14, G.VW, "center")
  g.setColor(self.player == 1 and P.vessred or P.lublue)
  g.printf("PLAYER " .. self.player .. (self.player == 1 and " (VESS)" or " (LU)")
    .. "   [X or L/R: switch player]", 0, 28, G.VW, "center")
  g.setColor(P.silver)
  g.printf("device: " .. (self.device == "pad" and "GAMEPAD" or "KEYBOARD")
    .. " (L/R to switch)", 0, 40, G.VW, "center")

  local y0 = 56
  for i, action in ipairs(REMAP_ACTIONS) do
    local y = y0 + (i - 1) * 12
    if i == self.sel then
      g.setColor(P.gold)
      g.print(">", 96, y)
    end
    g.setColor(i == self.sel and P.white or P.silver)
    g.print(Input.ACTION_LABELS[action] or action, 108, y)
    g.setColor(P.cyan)
    g.print(Input.bindingLabel(self.player, self.device, action), 280, y)
  end
  local yReset = y0 + #REMAP_ACTIONS * 12
  if self.sel == #REMAP_ACTIONS + 1 then
    g.setColor(P.gold)
    g.print(">", 96, yReset)
  end
  g.setColor(self.sel == #REMAP_ACTIONS + 1 and P.white or P.silver)
  g.print("RESET ALL TO DEFAULTS", 108, yReset)
  if self.sel == #REMAP_ACTIONS + 2 then
    g.setColor(P.gold)
    g.print(">", 96, yReset + 12)
  end
  g.setColor(self.sel == #REMAP_ACTIONS + 2 and P.white or P.silver)
  g.print("DONE", 108, yReset + 12)

  if self.capturing then
    g.setColor(P.black[1], P.black[2], P.black[3], 0.85)
    g.rectangle("fill", 90, 100, G.VW - 180, 60, 4, 4)
    g.setColor(P.gold)
    g.rectangle("line", 90, 100, G.VW - 180, 60, 4, 4)
    g.printf("Press the new " .. (self.device == "pad" and "button/trigger" or "key")
      .. " for:\n" .. (Input.ACTION_LABELS[REMAP_ACTIONS[self.sel]] or ""),
      100, 116, G.VW - 200, "center")
    g.setColor(P.slate)
    g.printf(self.device == "kb" and "(ESC cancels)" or "", 100, 146, G.VW - 200, "center")
  end
  g.setColor(1, 1, 1, 1)
end

return S
