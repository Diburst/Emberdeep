-- Table serializer for save files. Handles nested tables of
-- numbers, strings, and booleans with string or number keys.
local S = {}

local function serValue(v, out, indent)
  local tv = type(v)
  if tv == "number" then
    if v ~= v then out[#out + 1] = "0" -- NaN guard
    elseif v == math.huge then out[#out + 1] = "math.huge"
    elseif v == -math.huge then out[#out + 1] = "-math.huge"
    else out[#out + 1] = string.format("%.14g", v) end
  elseif tv == "string" then
    out[#out + 1] = string.format("%q", v)
  elseif tv == "boolean" then
    out[#out + 1] = tostring(v)
  elseif tv == "table" then
    out[#out + 1] = "{"
    -- array part
    local n = #v
    for i = 1, n do
      serValue(v[i], out, indent)
      out[#out + 1] = ","
    end
    -- hash part
    for k, val in pairs(v) do
      local isArrayIdx = type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)
      if not isArrayIdx then
        local tk = type(k)
        if tk == "string" then
          if k:match("^[%a_][%w_]*$") then
            out[#out + 1] = k .. "="
          else
            out[#out + 1] = "[" .. string.format("%q", k) .. "]="
          end
        elseif tk == "number" then
          out[#out + 1] = "[" .. string.format("%.14g", k) .. "]="
        else
          error("unserializable key type: " .. tk)
        end
        serValue(val, out, indent)
        out[#out + 1] = ","
      end
    end
    out[#out + 1] = "}"
  else
    error("unserializable value type: " .. tv)
  end
end

function S.pack(t)
  local out = { "return " }
  serValue(t, out, 0)
  return table.concat(out)
end

function S.unpack(str)
  if type(str) ~= "string" or #str == 0 then return nil end
  local chunk, err = loadstring and loadstring(str) or load(str)
  if not chunk then return nil, err end
  -- sandbox: no environment access
  if setfenv then
    setfenv(chunk, { math = { huge = math.huge } })
  end
  local ok, result = pcall(chunk)
  if not ok then return nil, result end
  if type(result) ~= "table" then return nil, "not a table" end
  return result
end

return S
