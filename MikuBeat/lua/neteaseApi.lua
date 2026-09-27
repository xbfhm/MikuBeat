--[[
  网易云官方接口封装（歌曲信息 / 歌单）
  ------------------------------------------------------------
  · 歌曲信息：https://music.163.com/api/song/detail/?ids=[id]
  · 歌单信息：https://music.163.com/api/v6/playlist/detail?id=<id>
  · 播放直链：交由 gdstudio.lua（GDStudio 免费聚合接口，复用网易云歌曲ID）
  ------------------------------------------------------------
  说明：官方接口仅用于「获取歌曲/歌单的详细信息」，播放统一走免费接口。
--]]

local bindClass = luajava.bindClass
local string = string
local tostring = tostring
local tonumber = tonumber
local table = table
local type = type
local pcall = pcall
local Http = Http
local cjson = require "cjson"
local _M = {}

local UA = "Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.93 Mobile Safari/537.36"
local HEADER = {
  ["User-Agent"] = UA,
  ["Referer"] = "https://music.163.com/",
  ["Cookie"] = "appver=8.7.01;",
}

--html 实体解码（&amp; &#39; 等）
local function htmlDecode(s)
  if not s then return s end
  s = tostring(s)
  s = string.gsub(s, "&amp;", "&")
  s = string.gsub(s, "&lt;", "<")
  s = string.gsub(s, "&gt;", ">")
  s = string.gsub(s, "&quot;", "\"")
  s = string.gsub(s, "&#39;", "'")
  s = string.gsub(s, "&apos;", "'")
  s = string.gsub(s, "&#(%d+);", function(n)
    local c = tonumber(n)
    if c and c > 0 then return string.char(c) end
    return ""
  end)
  return s
end

_M.htmlDecode = htmlDecode

--统一解析歌曲对象（song/detail 的单条 song）
local function parseSong(song)
  if type(song) ~= "table" then return nil end
  local artists = {}
  if type(song["ar"]) == "table" then
    for i = 1, #song["ar"] do
      artists[#artists + 1] = song["ar"][i]["name"]
    end
  elseif type(song["artists"]) == "table" then
    for i = 1, #song["artists"] do
      artists[#artists + 1] = song["artists"][i]["name"]
    end
  end
  local pic = ""
  if type(song["al"]) == "table" then pic = song["al"]["picUrl"] or ""
  elseif type(song["album"]) == "table" then pic = song["album"]["picUrl"] or "" end
  return {
    ["id"] = tostring(song["id"]),
    ["name"] = htmlDecode(song["name"]),
    ["artist"] = table.concat(artists, "/"),
    ["pic"] = pic,
    ["album"] = (type(song["al"]) == "table" and song["al"]["name"]) or (type(song["album"]) == "table" and song["album"]["name"]) or "",
    ["duration"] = song["dt"] or song["duration"] or 0,
    ["fee"] = song["fee"] or 0,
    ["code"] = 200,
  }
end

_M.parseSong = parseSong

--获取单曲详情（官方接口）
--@param id 歌曲id
--@param func 回调 func(ok, msgOrErr)  msg = {id,name,artist,pic,album,duration,fee,code}
function _M.getSong(id, func)
  func = func or function() end
  local url = "https://music.163.com/api/song/detail/?ids=[" .. tostring(id) .. "]&csrf_token="
  Http.get(url, HEADER, function(code, content)
    if code ~= 200 or not content or content == "" then
      func(false, "网络请求失败(" .. tostring(code) .. ")")
      return
    end
    local ok, data = pcall(cjson.decode, content)
    if not ok or type(data) ~= "table" then
      func(false, "数据解析失败")
      return
    end
    local song = data["songs"] and data["songs"][1]
    if not song then
      func(false, "未找到该歌曲")
      return
    end
    func(true, parseSong(song))
  end)
end

--获取歌单详情（官方接口）
--@param id 歌单id
--@param func 回调 func(ok, playlistOrErr)  playlist = {id,name,cover,creator,description,trackCount,tracks}
function _M.getPlaylist(id, func)
  func = func or function() end
  local url = "https://music.163.com/api/v6/playlist/detail?id=" .. tostring(id) .. "&n=100000&s=0"
  Http.get(url, HEADER, function(code, content)
    if code ~= 200 or not content or content == "" then
      func(false, "网络请求失败(" .. tostring(code) .. ")")
      return
    end
    local ok, data = pcall(cjson.decode, content)
    if not ok or type(data) ~= "table" then
      func(false, "数据解析失败")
      return
    end
    local pl = data["playlist"] or (data["result"] and data["result"]["playlist"])
    if not pl then
      func(false, "未找到该歌单（可能为私密歌单或ID有误）")
      return
    end
    local tracks = {}
    local rawTracks = pl["tracks"] or {}
    if #rawTracks == 0 and type(pl["trackIds"]) == "table" then
      --部分歌单只返回 trackIds，则仅记录数量（详情需另取）
      rawTracks = {}
    end
    for i = 1, #rawTracks do
      local t = rawTracks[i]
      local msg = parseSong(t)
      if msg then tracks[#tracks + 1] = msg end
    end
    local playlist = {
      ["id"] = tostring(pl["id"]),
      ["name"] = htmlDecode(pl["name"]),
      ["cover"] = pl["coverImgUrl"] or "",
      ["creator"] = (type(pl["creator"]) == "table" and pl["creator"]["nickname"]) or "",
      ["description"] = htmlDecode(pl["description"]) or "",
      ["trackCount"] = #tracks > 0 and #tracks or (pl["trackCount"] or 0),
      ["tracks"] = tracks,
    }
    func(true, playlist)
  end)
end

--从文本解析歌单ID / 链接
--@return id(字符串或nil), link(需要跟随的链接或nil)
function _M.parsePlaylistId(text)
  if not text then return nil, nil end
  text = tostring(text)
  --纯数字
  local pure = string.match(text, "^%s*(%d+)%s*$")
  if pure then return pure, nil end
  --标准链接 .../playlist?id=xxx
  local id = string.match(text, "playlist[^%d]-id=(%d+)") or string.match(text, "[?&]id=(%d+)")
  if id then return id, nil end
  --短链/其他链接
  local link = string.match(text, "https?://[%w_/&=%.%?#%%%-]+")
  if link then return nil, link end
  return nil, nil
end

return _M
