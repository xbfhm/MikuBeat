--GDStudio 免费音乐接口模块
--通过 music-api.gdstudio.xyz 聚合接口，使用网易云歌曲ID获取免费播放直链
--用于网易云官方接口无法获取（VIP/下架）歌曲时的免费播放兜底
--API: https://music-api.gdstudio.xyz/api.php
--支持 source=netease（网易云）、joox 等；其余平台返回 not supported

local bindClass = luajava.bindClass
local require = require
local activity = activity
local io = io
local pcall = pcall
local string = string
local tonumber = tonumber
local tostring = tostring
local table = table
local Http = Http

local cjson = require "cjson"
local File = bindClass "java.io.File"

local _M = {}

local apiBase = "https://music-api.gdstudio.xyz/api.php"
--音质尝试顺序：优先 320（体积与音质平衡），再降到 192/128，最后才试无损 999(1508，体积大)
local brLevels = {320, 192, 128, 999}

local function encode(str)
  --URL 编码（网易云搜索关键词需要）
  if str == nil then return "" end
  str = tostring(str)
  str = string.gsub(str, "([^%w%-%._~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return str
end

local function decode(str)
  --URL 解码（接口返回的 url 可能带转义）
  if str == nil then return nil end
  str = tostring(str)
  str = string.gsub(str, "+", " ")
  str = string.gsub(str, "%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
  end)
  return str
end

--搜索歌曲（聚合搜索，默认网易云源）
--@param string keyword 关键词
--@param function func 回调，参数为歌曲表数组 {id,name,artist,album,pic_id,...}
--@param string source 可选，默认 netease
function _M.search(keyword, func, source)
  source = source or "netease"
  local url = apiBase.."?types=search&source="..source.."&name="..encode(keyword).."&count=20&pages=1"
  Http.get(url, function(code, content)
    local results = {}
    if code == 200 and content and content ~= "" then
      local ok, data = pcall(cjson.decode, content)
      if ok and type(data) == "table" then
        for i = 1, #data do
          local item = data[i]
          results[#results + 1] = {
            ["id"] = tostring(item["id"]),
            ["name"] = item["name"],
            ["artist"] = (type(item["artist"]) == "table" and table.concat(item["artist"], "/") or item["artist"]),
            ["album"] = item["album"],
            ["pic_id"] = item["pic_id"],
            ["source"] = source,
          }
        end
      end
    end
    func(results, code)
  end)
end

--获取歌曲播放直链（按音质降级尝试）
--@param string/int id 网易云歌曲id
--@param function func 回调，成功 func(url, br)，失败 func(nil)
--@param string source 可选，默认 netease
function _M.getUrl(id, func, source)
  source = source or "netease"
  local index = 1
  local function try()
    local br = brLevels[index]
    if not br then
      func(nil)
      return
    end
    local url = apiBase.."?types=url&source="..source.."&id="..tostring(id).."&br="..tostring(br)
    Http.get(url, function(code, content)
      local got
      if code == 200 and content and content ~= "" then
        local ok, data = pcall(cjson.decode, content)
        if ok and type(data) == "table" and data["url"] and data["url"] ~= "" then
          got = decode(data["url"])
        end
      end
      if got then
        func(got, br)
       else
        index = index + 1
        try()
      end
    end)
  end
  try()
end

--通过 GDStudio 下载歌曲到指定路径
--@param string/int id 歌曲id
--@param string sp 目标文件路径
--@param function func 回调，成功 func(true, br)，失败 func(false)
--@param string source 可选
function _M.download(id, sp, func, source)
  _M.getUrl(id, function(url, br)
    if url then
      Http.download(url, sp, function(code)
        if code == 200 and File(sp).isFile() and File(sp).length() > 0 then
          func(true, br)
         else
          pcall(function() File(sp).delete() end)
          func(false)
        end
      end)
     else
      func(false)
    end
  end, source)
end

return _M