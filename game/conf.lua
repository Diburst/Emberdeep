function love.conf(t)
  t.identity = "emberdeep"
  t.appendidentity = false
  t.version = "11.5"
  t.console = false
  t.window.title = "EMBERDEEP"
  t.window.width = 960
  t.window.height = 540
  t.window.minwidth = 480
  t.window.minheight = 270
  t.window.resizable = true
  t.window.vsync = 1
  t.window.fullscreen = false
  t.window.fullscreentype = "desktop"
  t.modules.physics = false
  t.modules.video = false
  t.modules.touch = false
end
