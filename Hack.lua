local _, RE = ...
REHack = RE
local COMM = LibStub('AceComm-3.0')

local strsplit, strrep = string.split, string.rep
local mmin, mfloor, mround = math.min, math.floor, Round
local tinsert, tremove = table.insert, table.remove
local ReloadUI = ReloadUI
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local DisableAddOn = C_AddOns.DisableAddOn
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local IsShiftKeyDown = IsShiftKeyDown
local UnitName = UnitName
local StaticPopup_Show = StaticPopup_Show
local FauxScrollFrame_Update = FauxScrollFrame_Update
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FauxScrollFrame_SetOffset = FauxScrollFrame_SetOffset

-- default settings saved variables
REHackSV = {}
REHackDB = {
	font = 1,
	fontsize = 16,
	snap = 1,
	book = 1,
	books = {
		{name = 'Default',
		 data = {
			{
				['data'] = 'Welcome to REHack, a notebook and/or UI tweaking tool.\n\nThe UI is mostly self-explanatory; mouse over buttons to see what they do. A few things deserve special mention:\n\n  1. Run the selected page as Lua code by clicking the \'play\' button at the top of the edit window (this one) or by pressing SHIFT+TAB from within the editor.\n\n  2. You can make a page run automatically when REHack loads by clicking the \'play\' button next to its name in the list window. This makes REHack useful for little UI tweaks that don\'t warrant a full-blown addon. For example, I hate the mail font. It\'s easy to fix, but I don\'t want to write a whole addon for two lines of code. I type the lines into a REHack page and flag it to execute. Done.\n\nNOTES:\n\n  * Pages are saved as you type and there is no undo, so be careful. If you really screw up a page, you can hit the Revert button, which will give you back the page as it was when you first opened it.\n   \n  * The list frame and edit frame are resizable. Just grab the little handle in the bottom right corner.\n   \n  * Page search is case-insensitive. You can use regex (Lua patterns) with the exception of [] or ().\n   \n  * You can double-click a page name to rename it (in addition to using the rename button).\n   \n  * Autorun pages run in the order they appear, so you can control their execution order by moving them up and down the list.\n\n  * REHack:Require("PageName") function can be used to load other pages before executing the current one.\n\n  * REHack:SV() function can be used to get the table which contents will be saved between sessions.',
				['name'] = '|cff7cb8c7Welcome to REHack!  |cffff0000READ ME FIRST!!',
				['colorize'] = false,
			},
		 }
	  }
	},
	imported = false,
	reload = false,
}

RE.Tooltips = {
	HackNew = 'Create new %s',
	HackDelete = 'Delete this %s\nSHIFT to skip confirmation prompt',
	HackRename = 'Rename this %s',
	HackMoveUp = 'Move this %s up in the list\nSHIFT to move in increments of 5',
	HackMoveDown = 'Move this %s down in the list\nSHIFT to move in increments of 5',
	HackAutorun = 'Run this page automatically when REHack loads',
	HackRun = 'Run this page',
	HackSend = 'Send this page to another REHack user',
	HackSnap = 'Attach editor to list window',
	HackEditClose = 'Close editor for this page',
	HackFontCycle = 'Cycle through available fonts',
	HackFontBigger = 'Increase font size',
	HackFontSmaller = 'Decrease font size',
	HackRevert = 'Revert to saved version of this page',
	HackColorize = 'Enable Lua syntax highlighting for this page',
	HackSearchEdit = 'Find %ss matching this text\nENTER to search forward\nSHIFT+ENTER to search backwards',
	HackSearchName = 'Search %s name',
	HackSearchBody = 'Search page text',
	HackReloadUI = 'Reload UI'
}
RE.Fonts = {
	'Interface\\AddOns\\REHack\\Media\\VeraMono.ttf',
	'Interface\\AddOns\\REHack\\Media\\SourceCodePro.ttf',
}
RE.Backdrop = {
	edgeFile = 'Interface\\AddOns\\REHack\\Media\\Border',
	tile = true,
	tileSize = 128,
	edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
RE.Tab = '   '
RE.PlayerName =	UnitName('PLAYER')
RE.ListItemHeight = 17 -- used in the XML, too
RE.ListVOffset = 37 -- vertical space not available for list items
RE.MinHeight = 141 -- scroll bar gets wonky if we let the window get too short
RE.MinWidth = 296 -- keep buttons from crowding/overlapping
RE.MaxWidth = 572 -- tune to match size of 200 character page name
RE.MaxVisible = 50 -- num visible without scrolling; limits num HackListItems we must create
RE.NumVisible = 0 -- calculated during list resize
RE.LineProcessing = {}
RE.ErrorOverride = 0
RE.CurrentlyRunning = ''

StaticPopupDialogs.HackAccept = {
	text = 'Accept new REHack page from %s?', button1 = 'Yes', button2 = 'No',
	timeout = 0, whileDead = 1, hideOnEscape = 1,
	OnAccept = function(self)
		RE:New(self.page)
		COMM:SendCommMessage('REHack', '1', 'WHISPER', self.sender, 'BULK')
	end,
	OnCancel = function(self)
		COMM:SendCommMessage('REHack', '0', 'WHISPER', self.sender, 'BULK')
	end,
}
StaticPopupDialogs.HackSendTo = {
	text = 'Send selected page to', button1 = 'OK', button2 = 'CANCEL',
	hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
	OnAccept = function(self)
		local name = self.editBox:GetText()
		if name == '' then return true end
		RE:SendPage(self.page, 'WHISPER', name)
	end
}
StaticPopupDialogs.REHackDelete = {
	text = 'Delete selected %s?', button1 = 'Yes', button2 = 'No',
	timeout = 0, whileDead = 1, hideOnEscape = 1,
	OnAccept = function()
		RE:DeleteSelected()
	end
}

local db -- alias for REHackDB
local sv -- alias for REHackSV
local items -- alias for REHackDB.books[REHackDB.book].data
local mode = 'page' -- 'page' or 'book'
local selected = nil -- index of selected list item

local function printf(...)
	DEFAULT_CHAT_FRAME:AddMessage('|cffff6600<|r|cFF74D06CRE|r|cffff6600Hack>: '..format(...)..'|r')
end
local function getobj(...)
	return getglobal(format(...))
end
local function enableButton(b, e)
	if e then
		HackNew.Enable(b)
	else
		HackNew.Disable(b)
	end
end

function RE:Find(pattern) -- search books for a page by name
	for _, book in pairs(REHackDB.books) do
		for _, page in pairs(book.data) do
			if page.name:match(pattern) then
				return page
			end
		end
	end
end

-- Exec functions

function RE:ScriptError(aspect, err)
	local name, line, msg = err:match('%[string (".-")%]:(%d+): (.*)')
	printf('%s error%s:|cFFFFFFFF\n %s', aspect, name and format(' in |cFFFFFFFF%s|r|cffff6600 at line |cFFFFFFFF%d|r|cffff6600', name, line, msg) or '', err)
	RE.ErrorOverride = tonumber(line)
	RE:OnUpdateLines()
end

function RE:Compile(page)
	RE.CurrentlyRunning = page.name
	local func, err = loadstring(page.data:gsub('||','|'), page.name)
	if not func then
		RE:ScriptError('Syntax', err)
		return
	end
	return func
end

function RE:Get(index)
	local page = type(index) == 'string' and RE:Find(index) or items[index]
	if not page then
		printf('Attempt to get an invalid page')
		return
	end
	return RE:Compile(page)
end

local function CheckResult(...)
	if ... then return select(2, ...) end
	RE:ScriptError('Runtime', select(2, ...))
end

function RE:Execute(func, ...)
	if func then return CheckResult(pcall(func, ...)) end
end

function RE:Run(index, ...)
	RE.ErrorOverride = 0
	return RE:Execute(RE:Get(index or selected), ...)
end

do
	local loaded = {}
	function RE:Require(name)
		if not loaded[name] then
			loaded[name] = true
			RE:Run(name)
		end
	end
end

function RE:SV()
	if RE.CurrentlyRunning == "" then return end
	if not sv[RE.CurrentlyRunning] or type(sv[RE.CurrentlyRunning]) ~= 'table' then sv[RE.CurrentlyRunning] = {} end
	return sv[RE.CurrentlyRunning]
end

function RE:DoAutorun()
	for _, book in pairs(REHackDB.books) do
		for _, page in pairs(book.data) do
			if page.autorun then
				RE:Execute(RE:Compile(page))
			end
		end
	end
end

-- Event functions

function RE:OnLoad(self)
	local name = 'HackListItem'
	for i=2, RE.MaxVisible do
		local li = CreateFrame('Button', name..i, HackListFrame, 'T_HackListItem')
		li:SetPoint('TOP', name..(i-1), 'BOTTOM')
		li:SetID(i)
	end

	self:RegisterEvent('ADDON_LOADED')
	self:RegisterEvent('PLAYER_ENTERING_WORLD')

	SLASH_HACKSLASH1 = '/hack'
	SlashCmdList['HACKSLASH'] =
	function(n)
		if n == '' then
			REHack_Toggle()
		else
			RE:Run(n)
		end
	end
end

function RE:OnAddonMessage(message, _, sender)
	if message == '0' then
		printf('%s rejected your page.', sender)
	elseif message == '1' then
		printf('%s accepted your page.', sender)
	else
		local name, _, _, payload = strsplit('：', message)
		if sender == RE.PlayerName then return end
		local page = {name = name, data = payload}
		local dialog = StaticPopup_Show('HackAccept', sender)
		if dialog then
			dialog.page = page
			dialog.sender = sender
		end
	end
end

function RE:ADDON_LOADED(_, addon)
	if addon == 'REHack' then
		sv = REHackSV
		db = REHackDB
		items = db.books[db.book].data
		RE:UpdateFont()
		RE:UpdateButtons()
		RE:UpdateSearchContext()
		HackSnap:SetChecked(REHackDB.snap)
		RE:Snap()
		HackEditBoxLineTest:SetNonSpaceWrap(true)
		HackEditBoxLineBG:SetColorTexture(0, 0, 0, 0.50)
		HackListFrame:SetResizeBounds(RE.MinWidth, RE.MinHeight, RE.MaxWidth, (RE.MaxVisible * RE.ListItemHeight) + RE.ListVOffset + 5)
		HackListFrame:SetScript('OnSizeChanged', RE.UpdateNumListItemsVisible)
		RE:UpdateNumListItemsVisible()
		RE:DoAutorun()

		COMM:RegisterComm('REHack', RE.OnAddonMessage)

		if IsAddOnLoaded('Hack') and not db.imported then
			DisableAddOn('Hack')
			for _, book in pairs(HackDB.books) do
				for _, page in pairs(book.data) do
					RE:New(page)
				end
			end
			db.imported = true
			printf('Import from Hack complete. Reload your UI.')
		end

		HackListFrame:UnregisterEvent('ADDON_LOADED')
	end
end

function RE:PLAYER_ENTERING_WORLD(_)
	if db.reload then
		REHack_Toggle()
		RE:OnListItemClicked(db.reload)
		db.reload = false
	end
end

-- GUI functions

function RE:SetMode(newmode)
	mode = newmode
	if mode == 'page' then
		db.book = mmin(db.book, #db.books)
		items = db.books[db.book].data
		selected = nil
		HackSearchBody:Show()
		HackSend:Show()
	else -- 'book'
		items = db.books
		selected = db.book
		HackSearchBody:Hide()
		HackEditFrame:Hide()
		HackSend:Hide()
	end
	RE:UpdateButtons()
	RE:UpdateListItems()
end

function RE:SelectListItem(index)
	selected = index
	RE:UpdateButtons()
	if mode == 'page' then
		RE:EditPage()
	else -- 'book'
		db.book = index
	end
end

local function ListItemClickCommon(id, op)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	op(nil, id + FauxScrollFrame_GetOffset(HackListScrollFrame))
	RE:UpdateListItems()
end

function RE:OnListItemClicked(id)
	ListItemClickCommon(id, RE.SelectListItem)
end

function RE:OnListItemAutorunClicked(id, enable)
	ListItemClickCommon(id, function(_, s) items[s].autorun = enable end)
end

function RE:UpdateNumListItemsVisible()
	local visible = mfloor((HackListFrame:GetHeight()-RE.ListVOffset) / RE.ListItemHeight)
	RE.NumVisible = mmin(RE.MaxVisible, visible)
	RE:UpdateListItems()
end

function RE:UpdateListItems()
	local scrollFrameWidth = HackListFrame:GetWidth() - 18 -- N = inset from right edge
	FauxScrollFrame_Update(HackListScrollFrame, #items, RE.NumVisible, RE.ListItemHeight, nil, nil, nil, HackListScrollFrame, scrollFrameWidth - 17, scrollFrameWidth) -- N = room for scrollbar
	local offset = FauxScrollFrame_GetOffset(HackListScrollFrame)
	for widgetIndex=1, RE.MaxVisible do
		local itemIndex = offset + widgetIndex
		local item = items[itemIndex]
		local widget = getobj('HackListItem%d', widgetIndex)
		if not item or widgetIndex > RE.NumVisible then
			widget:Hide()
		else
			widget:Show()
			local name = getobj('HackListItem%dName', widgetIndex)
			local edit = getobj('HackListItem%dEdit', widgetIndex)
			local auto = getobj('HackListItem%dAutorun', widgetIndex)
			edit:ClearFocus() -- in case someone tries to scroll while renaming
			if RE:SearchMatch(item) then
				name:SetTextColor(1, 1, 1)
			else
				name:SetTextColor(.3, .3, .3)
			end
			if itemIndex == selected then
				widget:LockHighlight()
			else
				widget:UnlockHighlight()
			end
			if mode == 'page' then
				auto:Show()
				name:SetText(item.name)
				auto:SetChecked(item.autorun)
			else
				auto:Hide()
				name:SetText(format('%s |cFF888888(%d pages)', item.name, #item.data))
			end
		end
	end
end

function RE:UpdateButtons()
	enableButton(HackDelete, selected)
	enableButton(HackRename, selected)
	enableButton(HackSend, selected)
	enableButton(HackMoveUp, selected and selected > 1)
	enableButton(HackMoveDown, selected and selected < #items)
end

function RE:UpdateSearchContext()
  local pattern = HackSearchEdit:GetText():gsub('[%[%]%%()]', '%%%1'):gsub('%a', function(c) return format('[%s%s]', c:lower(), c:upper()) end)
  local nx, bx = HackSearchName:GetChecked(), HackSearchBody:GetChecked()
  function RE:SearchMatch(item)
    return not (nx or bx) or (nx and item.name:match(pattern)) or (mode == 'page' and bx and item.data:match(pattern))
  end
  RE:UpdateListItems()
end

function RE:DoSearch(direction) -- 1=down, -1=up
  if #items == 0 then return end
  local start = selected or 1
  local it = start
  repeat
    it = it + direction
    if it > #items then
			it = 1 -- wrap at..
    elseif it < 1 then
			it = #items -- ..either end
    end
	  if RE:SearchMatch(items[it]) then
	    RE:SelectListItem(it)
	    RE:ScrollSelectedIntoView()
	    HackSearchEdit:SetFocus()
	    break
	  end
	until it == start
end

function RE:ScrollSelectedIntoView()
	local offset = FauxScrollFrame_GetOffset(HackListScrollFrame)
	local id = selected - offset
	if id >  RE.NumVisible then
		offset = selected - RE.NumVisible
	elseif
		id <= 0 then offset = selected-1
	end
	FauxScrollFrame_SetOffset(HackListScrollFrame, offset)
	HackListScrollFrameScrollBar:SetValue(offset * RE.ListItemHeight)
	RE:UpdateListItems()
end

function REHack_Toggle(_)
	if HackListFrame:IsVisible() then
	  HackListFrame:Hide()
	else
	  HackListFrame:Show()
	end
end

function RE:Tooltip(self)
	local which = self:GetName()
	local tip = which:match('Autorun') and 'Automatically run this page when REHack loads' or format(RE.Tooltips[which], mode)
	GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	GameTooltip:AddLine(tip)
	GameTooltip:Show()
end

function RE:Rename()
	local id = selected - FauxScrollFrame_GetOffset(HackListScrollFrame)
	local name = getobj('HackListItem%dName', id)
	local edit = getobj('HackListItem%dEdit', id)
	edit:SetText(items[selected].name)
	edit:Show()
	edit:SetCursorPosition(0)
	edit:SetFocus()
	name:Hide()
end

function RE:FinishRename(name, _)
	sv[name] = sv[items[selected].name]
	sv[items[selected].name] = nil
	items[selected].name = name
	RE:UpdateListItems()
end

function RE:New(page)
	local index = selected or #items+1
	local data = (mode == 'page') and '' or {}
	page = page or { name='', data=data }
	tinsert(items, index, page)
	RE:SelectListItem(index)
	RE:UpdateListItems()
	RE:ScrollSelectedIntoView()
	if HackListFrame:IsShown() then RE:Rename() end
end

function RE:Delete()
	if mode == 'book' and #items == 1 then
		printf('You cannot delete the last %s!', mode)
	elseif IsShiftKeyDown() or #items[selected].data == 0 then
		RE:DeleteSelected()
	else
		StaticPopup_Show('REHackDelete', mode)
	end
end

function RE:DeleteSelected()
	HackEditFrame:Hide()
	sv[items[selected].name] = nil
	tremove(items,selected)
	if #items == 0 then selected = nil
	elseif selected > #items then selected = #items end
	RE:UpdateButtons()
	RE:UpdateListItems()
end

function RE:Revert()
	HackEditBox:SetText(RE.revert)
	HackEditBox:SetCursorPosition(0)
	HackRevert:Disable()
end

function RE:MoveItem(direction)
	local to = selected + direction * (IsShiftKeyDown() and 5 or 1)
	if to > #items then
		to = #items
	elseif to < 1 then
		to = 1
	end
	while selected ~= to do
	  items[selected], items[selected + direction] = items[selected + direction], items[selected]
	  selected = selected + direction
	end
	RE:ScrollSelectedIntoView()
	RE:UpdateButtons()
end

function RE:MoveUp()
	RE:MoveItem(-1)
end

function RE:MoveDown()
	RE:MoveItem(1)
end

function RE:ReloadUI()
	if mode == 'page' then
		db.reload = selected
	end
	ReloadUI()
end

function RE:FontBigger()
	db.fontsize = db.fontsize + 1
	RE:UpdateFont()
end

function RE:FontSmaller()
	if db.fontsize > 1 then
		db.fontsize = db.fontsize - 1
	else
		db.fontsize = 1
	end
	RE:UpdateFont()
end

function RE:FontCycle()
	db.font = (db.font < #RE.Fonts) and (db.font + 1) or (1)
	RE:UpdateFont()
end

function RE:UpdateFont()
	HackEditBox:SetFont(RE.Fonts[db.font], db.fontsize, '')
	HackEditBox:SetTextInsets(24 + db.fontsize, 40, 4, 9)
	HackEditBoxLine:ClearAllPoints()
	HackEditBoxLine:SetFont(RE.Fonts[db.font], db.fontsize, '')
	HackEditBoxLine:SetPoint('TOPRIGHT', HackEditBox, 'TOPLEFT', 14 + db.fontsize, -4)
	HackEditBoxLine:SetPoint('BOTTOMRIGHT', HackEditBox, 'BOTTOMLEFT', 14 + db.fontsize, 9)
	HackEditBoxLineBG:ClearAllPoints()
	HackEditBoxLineBG:SetPoint('TOPLEFT', HackEditBox, 'TOPLEFT')
	HackEditBoxLineBG:SetPoint('BOTTOMRIGHT', HackEditBox, 'BOTTOMLEFT', 20 + db.fontsize, 5)
	HackEditBoxLineTest:SetFont(RE.Fonts[db.font], db.fontsize, '')
end

function RE:OnButtonClick(name)
	RE[gsub(name, 'Hack', '')]()
end

function RE:ApplyColor(colorize)
	local page = items[selected]
	HackEditBox:SetText(page.data)
	if colorize then
		IndentationLib.enable(HackEditBox, REHackDB.customcolor, 3)
		IndentationLib.colorCodeEditbox(HackEditBox)
		HackEditBox:SetText(page.data:gsub('\124\124', '\124'))
	else
		IndentationLib.disable(HackEditBox)
		HackEditBox:SetText(page.data:gsub('\124', '\124\124'))
	end
end

function RE:EditPage()
	local page = items[selected]
	RE.revert = page.data
	HackRevert:Disable()
	HackEditFrame:Show()
	HackEditBox:SetCursorPosition(0)
	HackColorize:SetChecked(page.colorize)
	RE:ApplyColor(page.colorize)
end

function RE:OnEditorTextChanged()
	local page = items[selected]
	page.data = HackEditBox:GetText()
	enableButton(HackRevert, page.data ~= RE.revert)
	if not HackEditScrollFrameScrollBarThumbTexture:IsVisible() then
		HackEditScrollFrameScrollBar:Hide()
	end
end

function RE:OnUpdateLines()
	local content = ''
	local color = false
	local targetWidth = HackEditBox:GetWidth() - (64 + db.fontsize)
	wipe(RE.LineProcessing)
	RE.LineProcessing = {strsplit('\n', HackEditBox:GetText(true))}
	for i, line in pairs(RE.LineProcessing) do
		HackEditBoxLineTest:SetWidth(targetWidth)
		HackEditBoxLineTest:SetText(line:gsub('|', '||'))
		local linesNum = mround(HackEditBoxLineTest:GetStringHeight() / db.fontsize)
		if linesNum == 0 then
			if #RE.LineProcessing == i then
				break
			end
			linesNum = 1
		end
		if RE.ErrorOverride == i then
			content = content..'|cFFFF0000 '..i..'|r'..strrep('\n', linesNum)
		elseif color then
			content = content..'|cFFD3D3D3 '..i..'|r'..strrep('\n', linesNum)
		else
			content = content..i..strrep('\n', linesNum)
		end
		color = not color
	end
	RE.ErrorOverride = 0
	HackEditBoxLine:SetText(content)
end

function RE:OnEditorShow()
	RE:MakeESCable('HackListFrame', false)
	PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
end

function RE:OnEditorHide()
	RE:MakeESCable('HackListFrame', true)
	PlaySound(SOUNDKIT.IG_QUEST_LIST_CLOSE)
end

function RE:OnEditorLoad(self)
	tinsert(UISpecialFrames, 'HackEditFrame')
	self:SetResizeBounds(RE.MinWidth, RE.MinHeight)
end

function RE:Snap()
	REHackDB.snap = HackSnap:GetChecked()
	if REHackDB.snap then
	  HackEditFrame:ClearAllPoints()
	  HackEditFrame:SetPoint('TOPLEFT', HackListFrame, 'TOPRIGHT', -2, 0)
	end
end

function RE:Colorize()
	local page = items[selected]
	page.colorize = HackColorize:GetChecked()
	RE:ApplyColor(page.colorize)
end


function RE:Send()
	MenuUtil.CreateButtonMenu(_G['HackSend'],
		{'Player', function()
			local dialog = StaticPopup_Show('HackSendTo')
			if dialog then
				dialog.page = items[selected]
				dialog.editBox:SetScript('OnEnterPressed', function(_) dialog.button1:Click() end)
			end
		end, 'PLAYER'},
		{'Party', function(value) RE:SendPage(items[selected], value) end, 'PARTY'},
		{'Raid', function(value) RE:SendPage(items[selected], value) end, 'RAID'},
		{'Guild', function(value) RE:SendPage(items[selected], value) end, 'GUILD'},
		{'CopyPasta', function() RE:PastePage(items[selected]) end, 'PASTE'}
	);
end

function RE:SendPage(page, channel, name)
	COMM:SendCommMessage('REHack', page.name..'：'..page.data, channel, name, 'BULK')
end

function RE:PastePage(page)
	local lines = {strsplit('\n', page.data)}
	for _, line in ipairs(lines) do
		if line ~= '' and line:match('%S') ~= nil and line:match('^%s--') == nil then
			ChatFrame_OpenChat('')
			local ChatFrame = ChatEdit_GetActiveWindow()
			ChatFrame:SetText(line)
			ChatEdit_SendText(ChatFrame, false)
			ChatEdit_DeactivateChat(ChatFrame)
		end
	end
end

function RE:MakeESCable(frame, enable)
	local index
	for i=1,#UISpecialFrames do
		if UISpecialFrames[i] == frame then
			index = i
			break
		end
	end
	if index and not enable then
		tremove(UISpecialFrames, index)
	elseif not index and enable then
		tinsert(UISpecialFrames, 1, frame)
	end
end
