--网易云歌单管理模块
--数据来源：网易云官方接口（playlist/detail、song/detail）
--播放来源：GDStudio 免费接口（复用网易云歌曲ID）

local bindClass = luajava.bindClass
local activity = activity
local io = io
local pcall = pcall
local string = string
local tostring = tostring
local tonumber = tonumber
local table = table
local type = type
local Http = Http
local cjson = require "cjson"
local File = bindClass "java.io.File"
local LinearLayoutCompat = bindClass "androidx.appcompat.widget.LinearLayoutCompat"
local AppCompatTextView = bindClass "androidx.appcompat.widget.AppCompatTextView"
local RecyclerView = bindClass "androidx.recyclerview.widget.RecyclerView"
local LinearLayoutManager = bindClass "androidx.recyclerview.widget.LinearLayoutManager"
local MaterialAlertDialogBuilder = bindClass "com.google.android.material.dialog.MaterialAlertDialogBuilder"
local MaterialButton = bindClass "com.google.android.material.button.MaterialButton"
local MaterialCardView = bindClass "com.google.android.material.card.MaterialCardView"
local TextInputLayout = bindClass "com.google.android.material.textfield.TextInputLayout"
local TextInputEditText = bindClass "com.google.android.material.textfield.TextInputEditText"
local ColorStateList = bindClass "android.content.res.ColorStateList"
local LayoutTransition = bindClass "android.animation.LayoutTransition"
local Glide = bindClass "com.bumptech.glide.Glide"

local _M = {}

local dataDir = activity.getLuaDir() .. "/playlists.json"

--==================== 本地存储 ====================

function _M.getPlaylists()
  local f = File(dataDir)
  if not f.isFile() then return {} end
  local ok, data = pcall(function()
    return cjson.decode(io.open(dataDir, "r"):read("*a"))
  end)
  if ok and type(data) == "table" then return data end
  return {}
end

local function savePlaylists(list)
  local f = io.open(dataDir, "w")
  if f then
    f:write(cjson.encode(list))
    f:close()
  end
end

--添加或更新歌单，返回 true 表示新增
function _M.addPlaylist(pl)
  local list = _M.getPlaylists()
  for i = 1, #list do
    if tostring(list[i]["id"]) == tostring(pl["id"]) then
      list[i] = pl
      savePlaylists(list)
      return false
    end
  end
  table.insert(list, 1, pl)
  savePlaylists(list)
  return true
end

function _M.subPlaylist(id)
  local list = _M.getPlaylists()
  for i = 1, #list do
    if tostring(list[i]["id"]) == tostring(id) then
      table.remove(list, i)
      break
    end
  end
  savePlaylists(list)
end

function _M.getPlaylistById(id)
  local list = _M.getPlaylists()
  for i = 1, #list do
    if tostring(list[i]["id"]) == tostring(id) then return list[i], i end
  end
  return nil
end

--==================== 链接解析 ====================

--从文本中解析歌单ID；返回 id, link
function _M.parsePlaylistId(text)
  if not text then return nil, nil end
  text = tostring(text)
  --纯数字
  local pure = string.match(text, "^%s*(%d+)%s*$")
  if pure then return pure, nil end
  --常见歌单链接
  local id = string.match(text, "playlist%?id=(%d+)")
    or string.match(text, "playlist/(%d+)")
    or string.match(text, "[?&]id=(%d+)")
  if id then return id, nil end
  --短链（music.163.com/xxx 或 163cn.tv/xxx）
  local link = string.match(text, "(https?://[%w%._%-%?%=&/:#]+)")
  if link then return nil, link end
  return nil, nil
end

--==================== 网易云官方接口 ====================
--统一走 neteaseApi（官方接口）；播放直链由 gdstudio 提供
local neteaseApi = require "neteaseApi"

local ua = "Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.93 Mobile Safari/537.36"

--把官方接口返回的歌曲对象转成 App 内部曲目结构
local function toTrack(msg)
  return {
    ["info"] = tostring(msg["id"]),
    ["from"] = "wyy",
    ["name"] = msg["name"],
    ["artist"] = msg["artist"],
    ["album"] = msg["album"],
    ["pic"] = msg["pic"],
    ["fee"] = msg["fee"],
  }
end

--获取歌单详情（网易云官方接口 api/v6/playlist/detail）
--@param string id 歌单ID
--@param function func 回调 func(ok, playlistOrErr)
function _M.fetchPlaylist(id, func)
  neteaseApi.getPlaylist(id, function(ok, res)
    if not ok then
      func(false, res)
      return
    end
    local tracks = {}
    local rawTracks = res["tracks"] or {}
    for i = 1, #rawTracks do
      tracks[#tracks + 1] = toTrack(rawTracks[i])
    end
    res["tracks"] = tracks
    res["trackCount"] = #tracks
    func(true, res)
  end)
end

--通过链接文本获取歌单（含短链解析）
function _M.fetchByText(text, func)
  local id, link = _M.parsePlaylistId(text)
  if id then
    _M.fetchPlaylist(id, func)
    return
  end
  if link then
    --短链：跟随跳转，从 Location/响应体中解析歌单ID
    Http.get(link, { ["User-Agent"] = ua }, function(code, content, _, header)
      local h = tostring(header)
      local realId = string.match(h, "playlist[^%d]-id=(%d+)") or string.match(h, "id=(%d+)")
        or string.match(tostring(content), "playlist[^%d]-id=(%d+)") or string.match(tostring(content), "[?&]id=(%d+)")
      if realId then
        _M.fetchPlaylist(realId, func)
      else
        func(false, "无法从链接中解析出歌单ID，请直接粘贴歌单ID")
      end
    end)
    return
  end
  func(false, "无法识别歌单链接，请检查后重试")
end

--==================== UI：粘贴链接添加歌单 ====================

local view = {}
local dialog
local isInit = false

local layout
layout = {
  LinearLayoutCompat,
  layout_width = -1,
  orientation = 1,
  padding = "8dp",
  {
    AppCompatTextView,
    layout_width = -1,
    layout_height = -2,
    padding = "16dp",
    text = "粘贴网易云歌单链接（支持短链）或歌单ID，即可自动获取整张歌单～",
    textSize = "14sp",
    textColor = Colors.colorOutline,
  },
  {
    TextInputLayout,
    layout_height = -2,
    layout_width = -1,
    layout_marginLeft = "16dp",
    layout_marginRight = "16dp",
    boxStrokeColor = Colors.colorSurfaceVariant,
    boxCornerRadii = { dp2px(20), dp2px(20), dp2px(20), dp2px(20) },
    hint = "粘贴网易云歌单链接或歌单ID",
    hintTextColor = ColorStateList.valueOf(Colors.colorOnBackground),
    boxBackgroundMode = TextInputLayout.BOX_BACKGROUND_OUTLINE,
    {
      TextInputEditText,
      id = "playlistInput",
      maxHeight = "120dp",
      textColor = Colors.colorOnBackground,
      layout_height = -2,
      layout_width = -1,
      theme = MDC_R.style.Widget_MaterialComponents_TextInputLayout_OutlinedBox,
    },
  },
  {
    MaterialButton,
    layout_gravity = "right|bottom",
    text = "获取歌单",
    id = "confirmPlaylist",
    layout_marginRight = "16dp",
    layout_marginTop = "8dp",
    layout_marginBottom = "6dp",
    onClick = function()
      local text = view.playlistInput.text
      if not text or text == "" then
        myToast.toast("还没有粘贴链接哦(ó﹏ò｡)")
        return
      end
      view.confirmPlaylist.clickable = false
      myToast.toast("正在获取歌单，请稍候...")
      _M.fetchByText(text, function(ok, res)
        view.confirmPlaylist.clickable = true
        if ok then
          local isNew = _M.addPlaylist(res)
          myToast.toast((isNew and "歌单已添加：" or "歌单已更新：") .. res["name"] .. "\n共" .. tostring(res["trackCount"]) .. "首")
          view.playlistInput.text = ""
          view.playlistInput.clearFocus()
          if _M.onChanged then _M.onChanged() end
          if isInit and dialog then dialog.dismiss() end
        else
          myToast.toast("获取失败：" .. tostring(res))
        end
      end)
    end,
  },
}

local function initDialog()
  if isInit then return end
  dialog = MaterialAlertDialogBuilder(activity)
  dialog.setTitle("添加网易云歌单")
  dialog.setView(loadlayout(layout, view))
  dialog.setCancelable(true)
  dialog = dialog.create()
  isInit = true
end

--对外：显示添加歌单对话框
function _M.showAddDialog()
  initDialog()
  if dialog then dialog.show() end
end

return _M
