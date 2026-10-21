-- yuyu_demo.lua : corre la DEMO/attract del juego (juego solo, sin input)
-- y busca las variables de combate (HP=223, umbral=111, stun) en el work RAM.
-- Corre hasta 20000 frames o hasta encontrar HP.

local outfile = "C:\\Users\\leand\\Downloads\\emuladores\\yuyu_demo.txt"
local f = assert(io.open(outfile, "w"))
local function log(s) f:write(tostring(s) .. "\n") f:flush() end

local sha = "89A70D374A3F3E2DC5B430E6D444BEA243193B74"
client.openrom("C:\\BizHawk\\Rom\\" .. sha .. ".md")
emu.limitframerate(false)   -- correr lo mas rapido posible

log("=== corrida de demo/attract ===")
log("systemid=" .. tostring(emu.getsystemid()))

local function scan(lo,hi,targets)
  local res={}
  for _,t in ipairs(targets) do res[t]={} end
  local a=lo
  while a<hi do
    local ok,v=pcall(memory.read_u16_be,a,"M68K BUS")
    if ok and type(v)=="number" then
      for _,t in ipairs(targets) do if v==t then table.insert(res[t],a) end end
    end
    a=a+2
  end
  return res
end

local found_df, found_6f = {}, {}
local best_nz, best_frame = 0, 0

for fr = 1, 20000 do
  emu.frameadvance()
  if fr % 200 == 0 then
    local r = scan(0xFF0000, 0xFFFF00, {0x00DF, 0x006F})
    if #r[0x00DF] > 0 and #found_df == 0 then
      for i=1,math.min(#r[0x00DF],30) do table.insert(found_df, r[0x00DF][i]) end
      local l={}
      for i=1,#found_df do l[i]=string.format("0x%X",found_df[i]) end
      log(">>> FRAME " .. fr .. ": aparece HP=223 en " .. #found_df .. " direcciones: " .. table.concat(l,","))
      -- volcar RAM aqui para analisis
      local bf = io.open("C:\\Users\\leand\\Downloads\\emuladores\\workram_combate.bin","wb")
      local a=0xFF0000
      while a<=0xFFFFFF do
        local ok,v=pcall(memory.read_u16_be,a,"M68K BUS")
        if not (ok and type(v)=="number") then v=0 end
        bf:write(string.char(math.floor(v/256)%256, v%256))
        a=a+2
      end
      bf:close()
      log("    workram_combate.bin guardado")
    end
    if #r[0x006F] > 0 and #found_6f == 0 then
      for i=1,math.min(#r[0x006F],30) do table.insert(found_6f, r[0x006F][i]) end
      local l={}
      for i=1,#found_6f do l[i]=string.format("0x%X",found_6f[i]) end
      log("    FRAME " .. fr .. ": aparece 111 en " .. #found_6f .. ": " .. table.concat(l,","))
    end
    if fr % 1000 == 0 then
      -- medir "actividad" de RAM
      local nz = 0
      local a=0xFF0000
      while a<=0xFFFFFF do
        local ok,v=pcall(memory.read_u16_be,a,"M68K BUS")
        if ok and type(v)=="number" and v~=0 then nz=nz+1 end
        a=a+2
      end
      if nz > best_nz then best_nz = nz; best_frame = fr end
      log("f" .. fr .. "  actividad RAM=" .. nz)
    end
    if #found_df > 0 and fr > 0 then
      -- seguir un poco mas para estabilizar, luego salir
      if fr % 200 == 0 and #found_df > 0 then
        for i=1,60 do emu.frameadvance() end
        log("60 frames mas de combate muestreados")
        break
      end
    end
  end
end

log("=== fin ===")
log("mejor actividad=" .. best_nz .. " en frame " .. best_frame)

f:close()
client.exit()