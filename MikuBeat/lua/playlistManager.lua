--网易云歌单管理模块
--官方接口获取歌单数据，播放由 GDStudio 免费接口兜底（见 music163.lua / gdstudio.lua）

local bindClass = luajava.bindClass
local require = require
local activity = activity
local io = io
local pcall = pcall
local table = table
local string = string
local tostring = tostring
local Http = Http

--控件类：本模块头部统一声明，供 showAddDialog 使用
local LinearLayoutCompat = bindClass "androidx.appcompat.widget.LinearLayoutCompat"
local AppCompatTextView = bindClass "androidx.appcompat.widget.AppCompatTextView"
local MaterialAlertDialogBuilder = bindClass "com.google.android.material.dialog.MaterialAlertDialogBuilder"
local MaterialButton = bindClass "com.google.android.material.button.MaterialButton"
local TextInputLayout = bindClass "com.google.android.material.textfield.TextInputLayout"
local TextInputEditText = bindClass "com.google.android.material.textfield.TextInputEditText"
local ColorStateList = bindClass "android.content.res.ColorStateList"
local File = bindClass "java.io.File"

local cjson = require "cjson"

--★关键：dp2px 必须是【全局函数】
--（之前是 local，导致在部分作用域/打包版本里被当成 nil 调用而崩溃）
function dp2px(dpValue)
  local scale = activity.getResources().getDisplayMetrics().density
  return dpValue * scale + 0.5
end

local _M = {}
local view = {}

local jsonPath = activity.getExternalFilesDir(nil).getPath() .. "/music/playlists.json"

--==================== 本地存储 ====================

local function loadPlaylists()
  local list = {}
  local f = File(jsonPath)
  if not f.isFile() then return list end
  local ok, content = pcall(function()
    local reader = java.io.BufferedReader(java.io.InputStreamReader(java.io.FileInputStream(f), "UTF-8"))
    local sb = java.lang.StringBuilder()
    while true do
      local line = reader.readLine()
      if line == nil then break end
      sb.append(line)
    end
    reader.close()
    return sb.toString()
  end)
  if not ok or not content or content == "" then return list end
  local ok2, data = pcall(cjson.decode, content)
  if ok2 and type(data) == "table" then return data end
  return list
end

local function savePlaylists(list)
  local ok, content = pcall(cjson.encode, list)
  if not ok then return end
  pcall(function()
    local writer = java.io.BufferedWriter(java.io.OutputStreamWriter(java.io.FileOutputStream(jsonPath), "UTF-8"))
    writer.write(content)
    writer.close()
  end)
end

--==================== 对外数据接口 ====================

function _M.getPlaylists()
  return loadPlaylists()
end

function _M.addPlaylist(pl)
  local list = loadPlaylists()
  local found = false
  for i = 1, #list do
    if tostring(list[i]["id"]) == tostring(pl["id"]) then
      list[i] = pl
      found = true
      break
    end
  end
  if not found then list[#list + 1] = pl end
  savePlaylists(list)
  if _M.onChanged then pcall(_M.onChanged) end
  return pl
end

function _M.subPlaylist(id)
  local list = loadPlaylists()
  for i = #list, 1, -1 do
    if tostring(list[i]["id"]) == tostring(id) then
      table.remove(list, i)
    end
  end
  savePlaylists(list)
  if _M.onChanged then pcall(_M.onChanged) end
end

function _M.removeByIndex(index)
  local list = loadPlaylists()
  if list[index] then
    table.remove(list, index)
    savePlaylists(list)
    if _M.onChanged then pcall(_M.onChanged) end
  end
end

function _M.getPlaylistById(id)
  local list = loadPlaylists()
  for i = 1, #list do
    if tostring(list[i]["id"]) == tostring(id) then return list[i] end
  end
  return nil
end

--解析歌单链接/ID
function _M.parsePlaylistId(text)
  if not text then return nil, nil end
  text = tostring(text)
  local pure = string.match(text, "^%s*(%d+)%s*$")
  if pure then return pure, nil end
  local id = string.match(text, "playlist%?id=(%d+)")
    or string.match(text, "playlist/(%d+)")
    or string.match(text, "[?&]id=(%d+)")
  if id then return id, nil end
  local link = string.match(text, "(https?://[%w%._%-%?%=&/:#]+)")
  if link then return nil, link end
  return nil, nil
end

--获取歌单详情（官方接口）
function _M.fetchPlaylist(id, func)
  if not func then func = function() end end
  if not id then func(false, "歌单ID无效") return end
  local neteaseApi = require "neteaseApi"
  if type(neteaseApi) ~= "table" or type(neteaseApi.getPlaylist) ~= "function" then
    func(false, "歌单模块未加载，请重装应用")
    return
  end
  neteaseApi.getPlaylist(tostring(id), func)
end

--通过链接文本获取歌单（含短链解析）
function _M.fetchByText(text, func)
  if not func then func = function() end end
  local id, link = _M.parsePlaylistId(text)
  if id then
    _M.fetchPlaylist(id, func)
    return
  end
  if link then
    local ua = "Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36"
    Http.get(link, { ["User-Agent"] = ua }, function(code, content, _, header)
      local h = tostring(header)
      local realId = string.match(h, "playlist[^%d]-id=(%d+)") or string.match(h, "id=(%d+)")
      if realId then _M.fetchPlaylist(realId, func) return end
      local bodyId = string.match(tostring(content), "playlist[^%d]-id=(%d+)")
        or string.match(tostring(content), "[?&]id=(%d+)")
      if bodyId then
        _M.fetchPlaylist(bodyId, func)
      else
        func(false, "无法从链接中解析出歌单ID，请直接粘贴歌单ID")
      end
    end)
    return
  end
  func(false, "无法识别歌单链接，请检查后重试")
end

--==================== UI：粘贴链接添加歌单 ====================

function _M.showAddDialog()
  local myToast = require "myToast"
  local loadlayout = require "loadlayout2"
  local Colors = require "Colors"
  local MDC_R = luajava.bindClass "com.google.android.material.R"

  local layout = {
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
    },
  }

  local dlg = MaterialAlertDialogBuilder(activity)
  dlg.setTitle("添加网易云歌单")
  dlg.setView(loadlayout(layout, view))
  dlg.setNegativeButton("取消", nil)
  local dialog = dlg.create()

  view.confirmPlaylist.onClick = function()
    local text = view.playlistInput.text
    text = text and tostring(text) or ""
    if text == "" then
      myToast.toast("还没有粘贴链接哦(ó﹏ò｡)")
      return
    end
    view.confirmPlaylist.clickable = false
    myToast.toast("正在获取歌单，请稍候...")
    _M.fetchByText(text, function(ok, res)
      view.confirmPlaylist.clickable = true
      if ok and res then
        _M.addPlaylist(res)
        myToast.toast("歌单已添加：" .. tostring(res["name"]) .. "\n共" .. tostring(res["trackCount"]) .. "首")
        pcall(function() dialog.dismiss() end)
      else
        myToast.toast("获取失败：" .. tostring(res))
      end
    end)
  end

  dialog.show()
end

return _M
