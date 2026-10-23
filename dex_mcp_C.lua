--[[
================================================================
  DEX x MCP Bridge  ——  方案 C（DEX 界面加「发送到 MCP」按钮）
================================================================
  用法：把本文件全部内容追加到 dex.lua 最后一行（Main.Init()）之后。

  效果：
    1. DEX 右下角出现一个可拖动的【MCP】按钮
    2. 右键菜单多一项【发送到 MCP】（在资源管理器里右键对象）
    3. 点一下 → 当前选中对象的路径进入队列 + 复制到剪贴板
    4. AI 侧用 get-data-by-code 拉取：
         return game:GetService("HttpService"):JSONEncode(getgenv().DEX_QUEUE.Take())
    5. 设了 getgenv().BridgeURL 还会自动 POST 到 /dex/event

  快捷键：Ctrl+Shift+M = 发送当前选中
================================================================
]]

do

local g = getgenv and getgenv() or _G
local HttpService = game:GetService("HttpService")

-- 兼容旧执行器（无 task 库）
local TASK = (getfenv and rawget(getfenv(), "task")) or _G.task
if not TASK then
	TASK = {
		wait = function(s) if wait then return wait(s) end end,
		spawn = function(f, ...) return coroutine.wrap(f)(...) end,
		defer = function(f, ...)
			local a = table.pack and table.pack(...) or { n = select("#", ...), ... }
			coroutine.wrap(function() f(table.unpack(a, 1, a.n or #a)) end)()
		end,
	}
end
local task = TASK
local Queue = { items = {} }
local MAX = 100
local VERSION = "mcp-C-1.0"
local cooldown = -1e9
local function nowTick()
	if type(tick) == "function" then return tick() end
	return os.clock()
end

-- ============================================================
--  1. 路径解析 + 取路径
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

local function objPath(obj)
	if not obj then return nil end
	local ok, p = pcall(function() return Explorer.GetInstancePath(obj) end)
	if ok and type(p) == "string" and p ~= "" then return p end
	local ok2, fn = pcall(function() return obj:GetFullName() end)
	if ok2 and type(fn) == "string" then return (fn:gsub("^[^%.]+", "game")) end
	return nil
end

local function selectedPaths()
	local out = {}
	if selection and selection.List then
		for _, nd in ipairs(selection.List) do
			local p = nd and nd.Obj and objPath(nd.Obj)
			if p then out[#out + 1] = p end
		end
	end
	return out
end


-- ============================================================
--  2. 队列 + 推送
-- ============================================================
local pushFails = 0

local function bridgeBase()
	local raw = getgenv().BridgeURL
	if type(raw) ~= "string" or raw == "" then return nil end
	raw = raw:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
	raw = raw:gsub("^https://", "http://"):gsub("^wss?://", "http://")
	return raw
end

local function post(payload)
	local base = bridgeBase()
	if not base then return false, "no BridgeURL" end
	if pushFails >= 3 then return false, "push disabled" end
	if not (env and env.request) then return false, "no request()" end

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
		return true
	end
	pushFails = pushFails + 1
	return false, "push failed"
end

local function send(reason)
	local now = nowTick()
	if now - cooldown < 0.2 then return false, "too fast (wait 0.2s)" end
	cooldown = now

	local paths = selectedPaths()
	if #paths == 0 then
		print("[DEX-MCP] 没有选中任何对象")
		return false, "nothing selected"
	end

	local entry = {
		time = os.date("%H:%M:%S"),
		reason = reason or "button",
		paths = paths,
	}
	Queue.items[#Queue.items + 1] = entry
	while #Queue.items > MAX do table.remove(Queue.items, 1) end

	if env and env.setclipboard then
		pcall(env.setclipboard, table.concat(paths, "\n"))
	end

	print("[DEX->MCP] " .. #paths .. " object(s):\n" .. table.concat(paths, "\n"))

	post({ type = "selection", reason = entry.reason, paths = paths, time = entry.time })

	return true, #paths
end

local function take()
	local out = Queue.items
	Queue.items = {}
	return out
end

local function peek()
	local out = {}
	for i, v in ipairs(Queue.items) do out[i] = v end
	return out
end

-- ============================================================
--  3. 浮动按钮 UI
-- ============================================================
local function buildButton()
	if g.DEX_MCP_BUTTON then
		pcall(function() g.DEX_MCP_BUTTON:Destroy() end)
		g.DEX_MCP_BUTTON = nil
	end

	local Theme = Settings and Settings.Theme or {}
	local colMain = Theme.Main1 or Color3.fromRGB(52, 52, 52)
	local colOutline = Theme.Outline1 or Color3.fromRGB(33, 33, 33)
	local colText = Theme.Text or Color3.fromRGB(255, 255, 255)
	local colHover = Theme.ButtonHover or Color3.fromRGB(68, 68, 68)

	local gui = Instance.new("ScreenGui")
	gui.Name = "DEX_MCP_Button"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999999

	local btn = Instance.new("TextButton")
	btn.Name = "MCPButton"
	btn.Size = UDim2.new(0, 78, 0, 26)
	btn.Position = UDim2.new(1, -96, 1, -46)
	btn.BackgroundColor3 = colMain
	btn.BackgroundTransparency = 0.05
	btn.BorderSizePixel = 0
	btn.Text = "→ MCP"
	btn.TextColor3 = colText
	btn.TextSize = 13
	btn.Font = Enum.Font.SourceSansBold
	btn.AutoButtonColor = false
	btn.Draggable = true
	btn.Active = true
	btn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = colOutline
	stroke.Parent = btn

	local countBadge = Instance.new("TextLabel")
	countBadge.Name = "Count"
	countBadge.Size = UDim2.new(0, 16, 0, 14)
	countBadge.Position = UDim2.new(1, 2, 0, -6)
	countBadge.BackgroundColor3 = Color3.fromRGB(11, 90, 175)
	countBadge.BorderSizePixel = 0
	countBadge.Text = ""
	countBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	countBadge.TextSize = 10
	countBadge.Font = Enum.Font.SourceSansBold
	countBadge.Visible = false
	countBadge.Parent = btn

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(1, 0)
	cCorner.Parent = countBadge

	local function refreshBadge()
		local n = #selectedPaths()
		if n > 0 then
			countBadge.Text = tostring(n)
			countBadge.Visible = true
		else
			countBadge.Visible = false
		end
	end

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = colHover
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = colMain
	end)

	btn.MouseButton1Click:Connect(function()
		local ok, n = send("button")
		if ok then
			btn.Text = "✓ " .. n
			task.wait(0.8)
			btn.Text = "→ MCP"
		end
		refreshBadge()
	end)

	btn.MouseButton2Click:Connect(function()
		local items = peek()
		print("[DEX-MCP] 队列 " .. #items .. " 条:")
		for i, it in ipairs(items) do
			print("  " .. i .. ". [" .. it.time .. "] " .. table.concat(it.paths, ", "))
		end
		if env and env.setclipboard and #items > 0 then
			local lines = {}
			for _, it in ipairs(items) do
				for _, p in ipairs(it.paths) do lines[#lines + 1] = p end
			end
			pcall(env.setclipboard, table.concat(lines, "\n"))
			print("[DEX-MCP] 已全部复制到剪贴板")
		end
	end)

	if Main and Main.ShowGui then
		pcall(Main.ShowGui, gui)
	else
		gui.Parent = (plr and plr:FindFirstChildWhichIsA("PlayerGui")) or game:GetService("CoreGui")
	end

	g.DEX_MCP_BUTTON = gui

	if selection and selection.Changed then
		selection.Changed:Connect(function()
			task.defer(refreshBadge)
		end)
	end
	refreshBadge()

	return gui
end


-- ============================================================
--  4. 右键菜单项
-- ============================================================
local function hookContextMenu()
	local ctx = Explorer and Explorer.RightClickContext
	if not ctx then return false end
	if ctx.Registered and ctx.Registered["SEND_TO_MCP"] then return true end

	ctx:Register("SEND_TO_MCP", {
		Name = "发送到 MCP",
		IconMap = Main and Main.MiscIcons,
		Icon = "Reference",
		Shortcut = "Ctrl+Shift+M",
		OnClick = function()
			send("context-menu")
		end,
	})

	-- 关键：DEX 每次右键都先 Clear() 再重建菜单，
	-- 所以必须 hook ShowRightClick，在它构建完后再插进去。
	local origShow = Explorer.ShowRightClick
	if type(origShow) == "function" and not Explorer.__mcpHooked then
		Explorer.__mcpHooked = true
		Explorer.ShowRightClick = function(...)
			local r = origShow(...)
			local c = Explorer.RightClickContext
			if c and c.Registered and c.Registered["SEND_TO_MCP"] then
				pcall(function() c:AddDivider() end)
				pcall(function() c:AddRegistered("SEND_TO_MCP") end)
			end
			return r
		end
	end

	return true
end

-- ============================================================
--  5. 快捷键
-- ============================================================
local function hookShortcut()
	local UIS = game:GetService("UserInputService")
	if not UIS then return end
	UIS.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.M
			and UIS:IsKeyDown(Enum.KeyCode.LeftControl)
			and UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
			send("hotkey")
		end
	end)
end

-- ============================================================
--  6. 对外 API
-- ============================================================
-- 注意：DEX 自己的 API dump 是全局 API，不能被覆盖
local DexAPI = API
local API = {
	Version = VERSION,
	Send = send,
	Take = take,
	Peek = peek,
	Selected = selectedPaths,
	Resolve = resolvePath,
	Button = buildButton,
	Count = function() return #Queue.items end,
}

-- 顺便把 A/B 的只读能力也挂上，方便直接用
API.Snapshot = function()
	return {
		version = VERSION,
		selectionPaths = selectedPaths(),
		queued = #Queue.items,
		placeId = game.PlaceId,
	}
end

API.Select = function(paths, additive)
	if type(paths) == "string" then paths = { paths } end
	if type(paths) ~= "table" then return false, "paths must be table" end
	if not selection then return false, "not ready" end
	local found = {}
	for _, p in ipairs(paths) do
		local obj = resolvePath(p)
		if obj then found[#found + 1] = (nodes and nodes[obj]) or { Obj = obj } end
	end
	if #found == 0 then return false, "no match" end
	if additive then selection:AddTable(found) else selection:SetTable(found) end
	if found[1] and Explorer and Explorer.ViewNode then
		pcall(function() Explorer.ViewNode(found[1]) end)
	end
	return true, #found
end

API.Info = function(node)
	if not node or not node.Obj then return nil end
	local obj = node.Obj
	if typeof(obj) ~= "Instance" then return nil end
	local info = { name = obj.Name, class = obj.ClassName }
	local p = objPath(obj)
	if p then info.path = p end
	local par = obj.Parent
	if par then info.parent = { name = par.Name, class = par.ClassName } end
	return info
end

API.Tree = function(path, depth, limit)
	local root = resolvePath(path or "game")
	if not root then return nil, "root not found" end
	depth = math.clamp(tonumber(depth) or 2, 1, 8)
	limit = math.clamp(tonumber(limit) or 300, 1, 3000)
	local count = 0
	local function walk(obj, d)
		if count >= limit then return nil end
		count = count + 1
		local e = { name = obj.Name, class = obj.ClassName }
		local ch = obj:GetChildren()
		if d < depth then
			local kids = {}
			for i = 1, #ch do
				if count >= limit then break end
				kids[#kids + 1] = walk(ch[i], d + 1)
			end
			if #kids > 0 then e.children = kids end
		elseif #ch > 0 then e.childCount = #ch end
		return e
	end
	return walk(root, 1)
end

API.Props = function(path)
	local obj = resolvePath(path)
	if not obj then return nil, "not found" end
	local out = { name = obj.Name, class = obj.ClassName }
	local props = {}
	if DexAPI and DexAPI.Classes and DexAPI.GetMember then
		local ok, list = pcall(DexAPI.GetMember, obj.ClassName, "Properties")
		if ok and type(list) == "table" then
			for _, m in ipairs(list) do
				local okv, v = pcall(function() return obj[m.Name] end)
				if okv then props[m.Name] = tostring(v) end
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
	return out
end

API.Run = function(code)
	local fn, err = loadstring(tostring(code))
	if not fn then return { ok = false, error = tostring(err) } end
	local ok, res = pcall(fn)
	if not ok then return { ok = false, error = tostring(res) } end
	return { ok = true, result = tostring(res) }
end

API.Push = post

-- ============================================================
--  7. 挂载 + 初始化
-- ============================================================
local gg = getgenv and getgenv() or _G
gg.DEX_QUEUE = API
gg.DEX_MCP = API

-- 如果 A/B 已挂载，把队列接进去
if gg.DEX and gg.DEX.TakePending then
	gg.DEX.QueueSend = send
end

local okBtn, btnErr = xpcall(buildButton, function(e)
	return tostring(e) .. "\n" .. debug.traceback("", 2)
end)
if not okBtn then
	warn("[DEX-MCP] 按钮创建失败: " .. tostring(btnErr))
end

if not hookContextMenu() then
	-- 右键菜单可能还没初始化，稍后重试
	task.spawn(function()
		for _ = 1, 10 do
			task.wait(0.5)
			if hookContextMenu() then break end
		end
	end)
end

pcall(hookShortcut)

print("[DEX-MCP] 方案C 已注入 | version=" .. VERSION)
print("[DEX-MCP] 点【→ MCP】按钮 或 Ctrl+Shift+M 发送选中对象")
print("[DEX-MCP] 拉取队列: getgenv().DEX_QUEUE.Take()")

end
