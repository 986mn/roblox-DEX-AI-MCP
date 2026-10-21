--[[
================================================================
  DEX x MCP Bridge  ——  方案 B（适配层，不改 DEX 源文件）
================================================================
  与 A 的区别：
    A = 把 API 代码永久追加进 dex.lua
    B = 保持 dex.lua 原版不动，运行时下载+拼接+执行

  好处：
    · 仓库里的 dex.lua 永远是官方原版，升级不会冲突
    · 只维护这一个 wrapper 文件
    · 同一个 wrapper 可加载任意 DEX 地址（含汉化版）

  用法（执行器里直接跑）：
    loadstring(game:HttpGet("https://raw.githubusercontent.com/986mn/wg/main/dex_mcp_B.lua"))()

  或手动指定 DEX 地址：
    getgenv().DEX_URL = "https://raw.githubusercontent.com/986mn/wg/main/dex.lua"
    getgenv().DEX_MCP_DEBUG = false
================================================================
]]

do

-- ============================================================
--  0. 配置
-- ============================================================
local g = getgenv and getgenv() or _G

local DEX_URL = g.DEX_URL
	or "https://raw.githubusercontent.com/986mn/wg/main/dex.lua"

local DEBUG = g.DEX_MCP_DEBUG == true
local MARK = "[DEX-MCP-CORE]"

local function log(...)
	if DEBUG then print(MARK, ...) end
end

-- ============================================================
--  1. 防重复
-- ============================================================
if g.DEX and g.DEX.Version and g.DEX.Version:find("mcp") then
	print("[DEX-MCP] 已加载过 (" .. g.DEX.Version .. ")，跳过")
	return
end

-- ============================================================
--  2. 下载 DEX
-- ============================================================
print("[DEX-MCP] 拉取 DEX: " .. DEX_URL)

local okHttp, src = pcall(function()
	return game:HttpGet(DEX_URL)
end)

if not okHttp or type(src) ~= "string" or #src < 1000 then
	error("[DEX-MCP] DEX 下载失败: " .. tostring(src))
end

print("[DEX-MCP] 下载完成: " .. #src .. " 字符")

-- 已含 A 的补丁就不要再拼
if src:find("mcp-A-", 1, true) then
	print("[DEX-MCP] 检测到 dex.lua 已自带方案A 补丁，直接执行")
	loadstring(src)()
	return
end

-- ============================================================
--  3. 核心 API（运行时拼接，不改源文件）
-- ============================================================
local CORE = [==[

do
local Bridge = {}
local startedAt = tick()
local Pending = { items = {} }
local MAX_PENDING = 100
local HttpService = game:GetService("HttpService")

local function resolvePath(path)
	if type(path) ~= "string" then return nil end
	path = path:gsub("^%s+", ""):gsub("%s+$", "")
	if path == "" then return nil end
	if path:find("getNil", 1, true) then return nil end
	if path:sub(1, 4) ~= "game" then path = "game." .. path end
	local cur = game
	local i, len = 5, #path
	while i <= len do
		local ch = path:sub(i, i)
		if ch == "." then
			local name, nxt = path:match("^%.([%w_]+)()", i)
			if not name then return nil end
			local child = cur:FindFirstChild(name)
			if not child and cur == game then
				local ok, svc = pcall(function() return game:GetService(name) end)
				if ok then child = svc end
			end
			if not child then return nil end
			cur, i = child, nxt
		elseif ch == "[" then
			local _, name, nxt = path:match('^%[%s*(["\'])(.-)%1%s*%]()', i)
			if name then
				local child = cur:FindFirstChild(name)
				if not child then return nil end
				cur, i = child, nxt
			else
				local idx, nxt2 = path:match("^%[(%d+)%]()", i)
				if not idx then return nil end
				local target = cur:GetChildren()[tonumber(idx)]
				if not target then return nil end
				cur, i = target, nxt2
			end
		elseif ch == ":" then
			local svcName, nxt = path:match('^:GetService%(%s*["\'](.-)["\']%s*%)()', i)
			if svcName then
				local ok, svc = pcall(function() return game:GetService(svcName) end)
				if not ok or not svc then return nil end
				cur, i = svc, nxt
			else
				local n, nxt2 = path:match("^:GetChildren%(%)%[(%d+)%]()", i)
				if not n then return nil end
				local target = cur:GetChildren()[tonumber(n)]
				if not target then return nil end
				cur, i = target, nxt2
			end
		else
			return nil
		end
	end
	return cur
end

local function nodeInfo(node)
	if not node or not node.Obj then return nil end
	local obj = node.Obj
	if typeof(obj) ~= "Instance" then return nil end
	local info = { name = obj.Name, class = obj.ClassName }
	local ok, p = pcall(function() return Explorer.GetInstancePath(obj) end)
	if ok and type(p) == "string" and p ~= "" then info.path = p end
	local ok2, fn = pcall(function() return obj:GetFullName() end)
	if ok2 and type(fn) == "string" then info.fullName = fn end
	local par = obj.Parent
	if par then info.parent = { name = par.Name, class = par.ClassName } else info.nilParent = true end
	local ok3, pos = pcall(function() return obj.Position end)
	if ok3 and typeof(pos) == "Vector3" then
		info.position = { math.floor(pos.X*100)/100, math.floor(pos.Y*100)/100, math.floor(pos.Z*100)/100 }
	end
	local ok4, hp = pcall(function() return obj.Health end)
	if ok4 and type(hp) == "number" then info.health = hp end
	local ok5, hum = pcall(function() return obj:FindFirstChildOfClass("Humanoid") end)
	if ok5 and hum then info.hasHumanoid = true end
	return info
end

local function infoToPath(info)
	if not info then return nil end
	if info.path then return info.path end
	if info.fullName then return (info.fullName:gsub("^[^%.]+", "game")) end
	return nil
end

local function snapshot()
	local sel, selPaths = {}, {}
	if selection and selection.List then
		for i = 1, #selection.List do
			if i > 50 then break end
			local info = nodeInfo(selection.List[i])
			if info then
				sel[#sel+1] = info
				local p = infoToPath(info)
				if p then selPaths[#selPaths+1] = p end
			end
		end
	end
	local appNames = {}
	if Main and Main.MenuApps then
		for name in pairs(Main.MenuApps) do appNames[#appNames+1] = name end
		table.sort(appNames)
	end
	return {
		version = Bridge.Version,
		placeId = game.PlaceId, jobId = game.JobId,
		selection = sel, selectionPaths = selPaths, selectionCount = #sel,
		apps = appNames, pendingCount = #Pending.items,
		uptime = math.floor(tick() - startedAt),
		pushEnabled = Bridge.PushEnabled and true or false,
	}
end

local function selectPaths(paths, additive)
	if type(paths) == "string" then paths = { paths } end
	if type(paths) ~= "table" then return false, "paths must be table or string" end
	if not selection then return false, "DEX selection not ready" end
	local found = {}
	for _, p in ipairs(paths) do
		local obj = resolvePath(p)
		if obj then found[#found+1] = (nodes and nodes[obj]) or { Obj = obj } end
	end
	if #found == 0 then return false, "no object matched" end
	if additive then selection:AddTable(found) else selection:SetTable(found) end
	if found[1] and Explorer and Explorer.ViewNode then
		pcall(function() Explorer.ViewNode(found[1]) end)
	end
	return true, #found
end

local function listTree(path, depth, limit)
	local root = resolvePath(path or "game")
	if not root then return nil, "root not found: " .. tostring(path) end
	depth = math.clamp(tonumber(depth) or 2, 1, 8)
	limit = math.clamp(tonumber(limit) or 300, 1, 3000)
	local count = 0
	local function walk(obj, d)
		if count >= limit then return nil end
		count = count + 1
		local entry = { name = obj.Name, class = obj.ClassName }
		local children = obj:GetChildren()
		if d < depth then
			local kids = {}
			for i = 1, #children do
				if count >= limit then break end
				kids[#kids+1] = walk(children[i], d+1)
			end
			if #kids > 0 then entry.children = kids end
		elseif #children > 0 then entry.childCount = #children end
		return entry
	end
	return walk(root, 1)
end

local function readProps(path)
	local obj = resolvePath(path)
	if not obj then return nil, "object not found: " .. tostring(path) end
	local out = { name = obj.Name, class = obj.ClassName }
	local props = {}
	if API and API.Classes and API.GetMember then
		local ok, list = pcall(API.GetMember, obj.ClassName, "Properties")
		if ok and type(list) == "table" then
			for _, m in ipairs(list) do
				local okv, v = pcall(function() return obj[m.Name] end)
				if okv then
					local okS, s = pcall(tostring, v)
					props[m.Name] = okS and s or "?"
				end
			end
		end
	end
	out.properties = props
	local attrs = {}
	local okA, names = pcall(function() return obj:GetAttributes() end)
	if okA and type(names) == "table" then
		for _, n in ipairs(names) do
			local okV, v = pcall(function() return obj:GetAttribute(n) end)
			if okV then attrs[n] = tostring(v) end
		end
	end
	out.attributes = attrs
	local tags = {}
	local okT, t = pcall(function() return game:GetService("CollectionService"):GetTags(obj) end)
	if okT and type(t) == "table" then
		for _, tag in ipairs(t) do tags[#tags+1] = tag end
	end
	out.tags = tags
	return out
end

local function readSource(path)
	local obj = resolvePath(path)
	if not obj then return nil, "object not found: " .. tostring(path) end
	if not obj:IsA("LuaSourceContainer") then
		return nil, "not a script (class=" .. obj.ClassName .. ")"
	end
	if env and env.decompile then
		local ok, s = pcall(env.decompile, obj)
		if ok and type(s) == "string" and s ~= "" then
			return { path = path, class = obj.ClassName, source = s, length = #s }
		end
	end
	local ok2, s2 = pcall(function() return obj.Source end)
	if ok2 and type(s2) == "string" and s2 ~= "" then
		return { path = path, class = obj.ClassName, source = s2, length = #s2 }
	end
	return nil, "decompile unavailable"
end

local function coerce(value, currentValue)
	if type(value) ~= "string" then return value, nil end
	local expr = value:match("^lua:(.+)$")
	if expr then
		local fn = loadstring("return " .. expr)
		if not fn then return nil, "loadstring failed" end
		local ok, v = pcall(fn)
		if ok then return v, nil end
		return nil, "eval failed"
	end
	local t = type(currentValue)
	if t == "number" then
		local n = tonumber(value)
		if n then return n, nil end
		return nil, "not a number"
	elseif t == "boolean" then
		local lv = value:lower()
		if lv == "true" then return true, nil end
		if lv == "false" then return false, nil end
		return nil, "not a boolean"
	end
	return value, nil
end

local function setProp(path, propName, value)
	local obj = resolvePath(path)
	if not obj then return false, "object not found" end
	if type(propName) ~= "string" then return false, "propName required" end
	local okCur, current = pcall(function() return obj[propName] end)
	if not okCur then
		local okA, okS = pcall(function() return obj:SetAttribute(propName, value) end)
		if okA and okS then return true, "attribute set" end
		return false, "property not readable: " .. propName
	end
	local newVal, cerr = coerce(value, current)
	if cerr then return false, cerr end
	local ok, err = pcall(function() obj[propName] = newVal end)
	if not ok then return false, "set failed: " .. tostring(err) end
	if Properties and Properties.Refresh then pcall(function() Properties.Refresh() end) end
	return true, tostring(newVal)
end

local function runCode(code)
	local fn, err = loadstring(tostring(code))
	if not fn then return { ok = false, error = tostring(err) } end
	local pack = table.pack or function(...) return { n = select("#", ...), ... } end
	local res = pack(pcall(fn))
	if not res[1] then return { ok = false, error = tostring(res[2]) } end
	local out = {}
	for i = 2, res.n do
		local v = res[i]
		local tv = type(v)
		if tv == "string" or tv == "number" or tv == "boolean" then out[#out+1] = v
		elseif v == nil then out[#out+1] = "nil"
		else
			local okJ, s = pcall(function() return HttpService:JSONEncode(v) end)
			out[#out+1] = okJ and s or tostring(v)
		end
	end
	return { ok = true, results = out }
end

local function appControl(name, open)
	if not Main or not Main.MenuApps then return false, "menu not ready" end
	local ctrl = Main.MenuApps[name]
	if not ctrl then
		local avail = {}
		for n in pairs(Main.MenuApps) do avail[#avail+1] = n end
		return false, "no app named '" .. tostring(name) .. "'; available: " .. table.concat(avail, ", ")
	end
	if open == false then pcall(function() ctrl.Disable() end)
	else pcall(function() ctrl.Enable() end) end
	return true
end

local function refreshAll()
	if Explorer and Explorer.Update then pcall(function() Explorer.Update() end) end
	if Explorer and Explorer.Refresh then pcall(function() Explorer.Refresh() end) end
	if Properties and Properties.Refresh then pcall(function() Properties.Refresh() end) end
	return true
end

local function pushPending(reason)
	local paths = {}
	if selection and selection.List then
		for _, nd in ipairs(selection.List) do
			local info = nodeInfo(nd)
			local p = info and infoToPath(info)
			if p then paths[#paths+1] = p end
		end
	end
	if #paths == 0 then return false, "nothing selected" end
	Pending.items[#Pending.items+1] = { time = os.date("%H:%M:%S"), reason = reason or "manual", paths = paths }
	while #Pending.items > MAX_PENDING do table.remove(Pending.items, 1) end
	if env and env.setclipboard then pcall(env.setclipboard, table.concat(paths, "\n")) end
	print("[DEX->MCP] " .. #paths .. " object(s) queued:\n" .. table.concat(paths, "\n"))
	return true, #paths
end

local function takePending()
	local out = Pending.items
	Pending.items = {}
	return out
end

local pushFails = 0
local function bridgeBase()
	local raw = getgenv().BridgeURL
	if type(raw) ~= "string" or raw == "" then return nil end
	raw = raw:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
	raw = raw:gsub("^https://", "http://"):gsub("^wss?://", "http://")
	return raw
end

local function postEvent(payload)
	local base = bridgeBase()
	if not base then return end
	if pushFails >= 3 then return end
	if not (env and env.request) then return end
	local ok, res = pcall(function()
		return env.request({
			Url = base .. "/dex/event",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
	end)
	if ok and res and (res.StatusCode == 200 or res.StatusCode == 204) then
		pushFails = 0
		Bridge.PushEnabled = true
	else
		pushFails = pushFails + 1
		if pushFails >= 3 then Bridge.PushEnabled = false end
	end
end

Bridge.Version = "mcp-B-1.0"
Bridge.PushEnabled = false
Bridge.Snapshot = snapshot
Bridge.Info = nodeInfo
Bridge.Resolve = resolvePath
Bridge.Select = selectPaths
Bridge.Tree = listTree
Bridge.Props = readProps
Bridge.Source = readSource
Bridge.SetProp = setProp
Bridge.Run = runCode
Bridge.App = appControl
Bridge.Refresh = refreshAll
Bridge.PushPending = pushPending
Bridge.TakePending = takePending
Bridge.Push = postEvent
Bridge.Main = Main
Bridge.Apps = Apps
Bridge.Explorer = Explorer
Bridge.Properties = Properties
Bridge.ScriptViewer = ScriptViewer
Bridge.Console = Console
Bridge.SaveInstance = SaveInstance
Bridge.nodes = nodes
Bridge.selection = selection
Bridge.env = env
Bridge.API = API
Bridge.RMD = RMD
Bridge.Lib = Lib

if selection and selection.Changed then
	selection.Changed:Connect(function()
		if not bridgeBase() then return end
		postEvent({ type = "selection", data = snapshot() })
	end)
end

local gg = getgenv and getgenv() or _G
gg.DEX = Bridge
gg.DEX_MCP = Bridge

print("[DEX-MCP] 方案B 已注入 | version=" .. Bridge.Version)
print("[DEX-MCP] 拉取: getgenv().DEX.Snapshot()")
end
]==]

-- ============================================================
--  4. 拼接 + 执行
-- ============================================================
local patched = src .. "\n\n" .. CORE

print("[DEX-MCP] 拼接完成: " .. #patched .. " 字符，开始执行")

local okRun, err = pcall(function()
	local fn = loadstring(patched)
	if not fn then error("拼接后 loadstring 失败（DEX 源码被混淆？）") end
	fn()
end)

if not okRun then
	error("[DEX-MCP] 执行失败: " .. tostring(err))
end

-- ============================================================
--  5. 校验
-- ============================================================
if g.DEX and g.DEX.Version then
	print("[DEX-MCP] 就绪: " .. g.DEX.Version)
	print("[DEX-MCP] 试一下: getgenv().DEX.Snapshot()")
else
	warn("[DEX-MCP] 执行完毕但 getgenv().DEX 未挂载，可能 DEX 加载中途出错")
end

end
