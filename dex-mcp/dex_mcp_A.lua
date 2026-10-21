--[[
================================================================
  DEX x MCP Bridge  ——  方案 A（完整双向同步）
================================================================
  用法：把本文件全部内容追加到 dex.lua 最后一行（Main.Init()）之后。

  效果：
    · getgenv().DEX  = 完整读写 API
    · AI 用 MCP 的 get-data-by-code 拉快照
    · AI 用 MCP 的 execute 反向控制 DEX 界面
    · 若设了 getgenv().BridgeURL，你每次点选对象会自动 POST
      到 <BridgeURL>/dex/event（需要服务端有该路由）

  拉取：
    return game:GetService("HttpService"):JSONEncode(getgenv().DEX.Snapshot())
  控制：
    getgenv().DEX.Select({"game.Workspace.Map.NPC"})
================================================================
]]

do

local Bridge = {}
local startedAt = tick()
local Pending = { items = {} }
local MAX_PENDING = 100
local DEBUG = false

local function log(...)
	if DEBUG then print("[DEX-MCP]", ...) end
end

local HttpService = game:GetService("HttpService")

-- ============================================================
--  1. 路径解析（兼容 GetInstancePath 的所有输出格式）
-- ============================================================
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

-- ============================================================
--  2. 节点信息
-- ============================================================
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
	if par then
		info.parent = { name = par.Name, class = par.ClassName }
	else
		info.nilParent = true
	end

	local ok3, pos = pcall(function() return obj.Position end)
	if ok3 and typeof(pos) == "Vector3" then
		info.position = { math.floor(pos.X * 100) / 100, math.floor(pos.Y * 100) / 100, math.floor(pos.Z * 100) / 100 }
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


-- ============================================================
--  3. 读：快照
-- ============================================================
local function snapshot()
	local sel, selPaths = {}, {}

	if selection and selection.List then
		for i = 1, #selection.List do
			if i > 50 then break end
			local info = nodeInfo(selection.List[i])
			if info then
				sel[#sel + 1] = info
				local p = infoToPath(info)
				if p then selPaths[#selPaths + 1] = p end
			end
		end
	end

	local appNames = {}
	if Main and Main.MenuApps then
		for name in pairs(Main.MenuApps) do appNames[#appNames + 1] = name end
		table.sort(appNames)
	end

	return {
		version = Bridge.Version,
		placeId = game.PlaceId,
		jobId = game.JobId,
		selection = sel,
		selectionPaths = selPaths,
		selectionCount = #sel,
		apps = appNames,
		pendingCount = #Pending.items,
		uptime = math.floor(tick() - startedAt),
		pushEnabled = Bridge.PushEnabled and true or false,
	}
end

-- ============================================================
--  4. 写：选中
-- ============================================================
local function selectPaths(paths, additive)
	if type(paths) == "string" then paths = { paths } end
	if type(paths) ~= "table" then return false, "paths must be table or string" end
	if not selection then return false, "DEX selection not ready" end

	local found = {}
	for _, p in ipairs(paths) do
		local obj = resolvePath(p)
		if obj then
			found[#found + 1] = (nodes and nodes[obj]) or { Obj = obj }
		end
	end

	if #found == 0 then return false, "no object matched" end

	if additive then
		selection:AddTable(found)
	else
		selection:SetTable(found)
	end

	if found[1] and Explorer and Explorer.ViewNode then
		pcall(function() Explorer.ViewNode(found[1]) end)
	end

	return true, #found
end

-- ============================================================
--  5. 读：实例树
-- ============================================================
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
				kids[#kids + 1] = walk(children[i], d + 1)
			end
			if #kids > 0 then entry.children = kids end
		elseif #children > 0 then
			entry.childCount = #children
		end
		return entry
	end

	return walk(root, 1)
end

-- ============================================================
--  6. 读：属性 / Attributes / 标签
-- ============================================================
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
	local okT, t = pcall(function()
		return game:GetService("CollectionService"):GetTags(obj)
	end)
	if okT and type(t) == "table" then
		for _, tag in ipairs(t) do tags[#tags + 1] = tag end
	end
	out.tags = tags

	return out
end

-- ============================================================
--  7. 读：脚本源码
-- ============================================================
local function readSource(path)
	local obj = resolvePath(path)
	if not obj then return nil, "object not found: " .. tostring(path) end
	if not obj:IsA("LuaSourceContainer") then
		return nil, "not a script (class=" .. obj.ClassName .. ")"
	end

	if env and env.decompile then
		local ok, src = pcall(env.decompile, obj)
		if ok and type(src) == "string" and src ~= "" then
			return { path = path, class = obj.ClassName, source = src, length = #src }
		end
	end

	local ok2, src2 = pcall(function() return obj.Source end)
	if ok2 and type(src2) == "string" and src2 ~= "" then
		return { path = path, class = obj.ClassName, source = src2, length = #src2 }
	end

	return nil, "decompile unavailable (executor lacks decompile)"
end


-- ============================================================
--  8. 写：设属性
-- ============================================================
local function coerce(value, currentValue)
	if type(value) ~= "string" then return value, nil end

	local expr = value:match("^lua:(.+)$")
	if expr then
		local fn = loadstring("return " .. expr)
		if not fn then return nil, "loadstring failed: " .. expr end
		local ok, v = pcall(fn)
		if ok then return v, nil end
		return nil, "eval failed: " .. expr
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
	if not obj then return false, "object not found: " .. tostring(path) end
	if type(propName) ~= "string" then return false, "propName required" end

	local okCur, current = pcall(function() return obj[propName] end)
	if not okCur then
		local okA, okS, err = pcall(function()
			return obj:SetAttribute(propName, value)
		end)
		if okA and okS then return true, "attribute set" end
		return false, "property not readable: " .. propName .. (err and (" / " .. tostring(err)) or "")
	end

	local newVal, cerr = coerce(value, current)
	if cerr then return false, cerr end

	local ok, err = pcall(function() obj[propName] = newVal end)
	if not ok then return false, "set failed: " .. tostring(err) end

	if Properties and Properties.Refresh then
		pcall(function() Properties.Refresh() end)
	end

	return true, tostring(newVal)
end

-- ============================================================
--  9. 执行 Luau
-- ============================================================
local function runCode(code)
	local fn, err = loadstring(tostring(code))
	if not fn then return { ok = false, error = tostring(err) } end

	local pack = table.pack or function(...) return { n = select("#", ...), ... } end
	local res = pack(pcall(fn))
	if not res[1] then
		return { ok = false, error = tostring(res[2]) }
	end

	local out = {}
	for i = 2, res.n do
		local v = res[i]
		local tv = type(v)
		if tv == "string" or tv == "number" or tv == "boolean" then
			out[#out + 1] = v
		elseif v == nil then
			out[#out + 1] = "nil"
		else
			local okJ, s = pcall(function() return HttpService:JSONEncode(v) end)
			out[#out + 1] = okJ and s or tostring(v)
		end
	end

	return { ok = true, results = out }
end

-- ============================================================
-- 10. App 面板 / 刷新
-- ============================================================
local function appControl(name, open)
	if not Main or not Main.MenuApps then return false, "menu not ready" end
	local ctrl = Main.MenuApps[name]
	if not ctrl then
		local avail = {}
		for n in pairs(Main.MenuApps) do avail[#avail + 1] = n end
		return false, "no app named '" .. tostring(name) .. "'; available: " .. table.concat(avail, ", ")
	end
	if open == false then
		pcall(function() ctrl.Disable() end)
	else
		pcall(function() ctrl.Enable() end)
	end
	return true
end

local function refreshAll()
	if Explorer and Explorer.Update then pcall(function() Explorer.Update() end) end
	if Explorer and Explorer.Refresh then pcall(function() Explorer.Refresh() end) end
	if Properties and Properties.Refresh then pcall(function() Properties.Refresh() end) end
	return true
end

-- ============================================================
-- 11. 待处理队列
-- ============================================================
local function pushPending(reason)
	local paths = {}
	if selection and selection.List then
		for _, nd in ipairs(selection.List) do
			local info = nodeInfo(nd)
			local p = info and infoToPath(info)
			if p then paths[#paths + 1] = p end
		end
	end
	if #paths == 0 then return false, "nothing selected" end

	Pending.items[#Pending.items + 1] = {
		time = os.date("%H:%M:%S"),
		reason = reason or "manual",
		paths = paths,
	}
	while #Pending.items > MAX_PENDING do table.remove(Pending.items, 1) end

	if env and env.setclipboard then
		pcall(env.setclipboard, table.concat(paths, "\n"))
	end
	print("[DEX->MCP] " .. #paths .. " object(s) queued:\n" .. table.concat(paths, "\n"))
	return true, #paths
end

local function takePending()
	local out = Pending.items
	Pending.items = {}
	return out
end

-- ============================================================
-- 12. 可选 push
-- ============================================================
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
		if pushFails >= 3 then
			Bridge.PushEnabled = false
			log("push disabled after 3 failures")
		end
	end
end

-- ============================================================
-- 13. 对外 API
-- ============================================================
Bridge.Version = "mcp-A-1.0"
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

-- ============================================================
-- 14. 选中变化 -> push
-- ============================================================
if selection and selection.Changed then
	selection.Changed:Connect(function()
		if not bridgeBase() then return end
		postEvent({ type = "selection", data = snapshot() })
	end)
end

-- ============================================================
-- 15. 挂载
-- ============================================================
local g = getgenv and getgenv() or _G
g.DEX = Bridge
g.DEX_MCP = Bridge

print("[DEX-MCP] 方案A 已注入 | version=" .. Bridge.Version)
print("[DEX-MCP] 拉取: getgenv().DEX.Snapshot()")
print("[DEX-MCP] 控制: getgenv().DEX.Select({...})")
if bridgeBase() then
	print("[DEX-MCP] push 目标: " .. bridgeBase() .. "/dex/event")
else
	print("[DEX-MCP] 未设 getgenv().BridgeURL，仅拉取模式")
end

end
