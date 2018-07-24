local _G = _G
local _, RE = ...
_G.REHack = RE
local COMM = LibStub('AceComm-3.0')

-- UIDropDownMenu taint workaround by foxlit
if (UIDROPDOWNMENU_VALUE_PATCH_VERSION or 0) < 2 then
	UIDROPDOWNMENU_VALUE_PATCH_VERSION = 2
	hooksecurefunc('UIDropDownMenu_InitializeHelper', function()
		if UIDROPDOWNMENU_VALUE_PATCH_VERSION ~= 2 then
			return
		end
		for i=1, UIDROPDOWNMENU_MAXLEVELS do
			for j=1, UIDROPDOWNMENU_MAXBUTTONS do
				local b = _G['DropDownList' .. i .. 'Button' .. j]
				if not (issecurevariable(b, 'value') or b:IsShown()) then
					b.value = nil
					repeat
						j, b['fx' .. j] = j+1
					until issecurevariable(b, 'value')
				end
			end
		end
	end)
end
if (UIDROPDOWNMENU_OPEN_PATCH_VERSION or 0) < 1 then
	UIDROPDOWNMENU_OPEN_PATCH_VERSION = 1
	hooksecurefunc('UIDropDownMenu_InitializeHelper', function(frame)
		if UIDROPDOWNMENU_OPEN_PATCH_VERSION ~= 1 then
			return
		end
		if UIDROPDOWNMENU_OPEN_MENU and UIDROPDOWNMENU_OPEN_MENU ~= frame
		   and not issecurevariable(UIDROPDOWNMENU_OPEN_MENU, 'displayMode') then
			UIDROPDOWNMENU_OPEN_MENU = nil
			local t, f, prefix, i = _G, issecurevariable, ' \0', 1
			repeat
				i, t[prefix .. i] = i + 1
			until f('UIDROPDOWNMENU_OPEN_MENU')
		end
	end)
end

-- GLOBALS: LE_PARTY_CATEGORY_HOME, UIDROPDOWNMENU_VALUE_PATCH_VERSION, UIDROPDOWNMENU_MAXLEVELS, UIDROPDOWNMENU_MAXBUTTONS, UIDROPDOWNMENU_OPEN_PATCH_VERSION, UIDROPDOWNMENU_OPEN_MENU, issecurevariable, hooksecurefunc
local select, pairs, format, getglobal, loadstring, type, pcall, gsub, unpack, strsplit = _G.select, _G.pairs, _G.format, _G.getglobal, _G.loadstring, _G.type, _G.pcall, _G.gsub, _G.unpack, _G.strsplit
local mmin, mfloor = _G.math.min, _G.math.floor
local tinsert, tremove = _G.table.insert, _G.table.remove
local CreateFrame = _G.CreateFrame
local EasyMenu = _G.EasyMenu
local StaticPopup_Show = _G.StaticPopup_Show
local PlaySound = _G.PlaySound
local IsAddOnLoaded = _G.IsAddOnLoaded
local IsShiftKeyDown = _G.IsShiftKeyDown
local IsInGuild = _G.IsInGuild
local UnitName = _G.UnitName
local UnitInRaid = _G.UnitInRaid
local GetNumGroupMembers = _G.GetNumGroupMembers
local FauxScrollFrame_Update = _G.FauxScrollFrame_Update
local FauxScrollFrame_GetOffset = _G.FauxScrollFrame_GetOffset
local FauxScrollFrame_SetOffset = _G.FauxScrollFrame_SetOffset

_G.REHackDB = { -- default settings saved variables
	font = 1,
	fontsize = 16,
	snap = 1,
	book = 1,
	books = {{name = 'Default', data = {}}},
}

RE.Tooltips = {
	HackNew         = 'Create new %s',
	HackDelete      = 'Delete this %s\nSHIFT to skip confirmation prompt',
	HackRename      = 'Rename this %s',
	HackMoveUp      = 'Move this %s up in the list\nSHIFT to move in increments of 5',
	HackMoveDown    = 'Move this %s down in the list\nSHIFT to move in increments of 5',
	HackAutorun     = 'Run this page automatically when REHack loads',
	HackRun         = 'Run this page',
	HackSend        = 'Send this page to another REHack user',
	HackSnap        = 'Attach editor to list window',
	HackEditClose   = 'Close editor for this page',
	HackFontCycle   = 'Cycle through available fonts',
	HackFontBigger  = 'Increase font size',
	HackFontSmaller = 'Decrease font size',
	HackRevert      = 'Revert to saved version of this page',
	HackColorize    = 'Enable Lua syntax highlighting for this page',
	HackSearchEdit  = 'Find %ss matching this text\nENTER to search forward\nSHIFT+ENTER to search backwards',
	HackSearchName  = 'Search %s name',
	HackSearchBody  = 'Search page text',
}
RE.fonts = {
	'Interface\\AddOns\\REHack\\Media\\VeraMono.ttf',
	'Interface\\AddOns\\REHack\\Media\\SourceCodePro.ttf',
}
RE.Tab						=	'     '
RE.Indent         =	{}
RE.ListItemHeight =	17 -- used in the XML, too
RE.ListVOffset    =	37 -- vertical space not available for list items
RE.MinHeight      =	141 -- scroll bar gets wonky if we let the window get too short
RE.MinWidth       =	296 -- keep buttons from crowding/overlapping
RE.MaxWidth       =	572 -- tune to match size of 200 character page name
RE.MaxVisible     =	50 -- num visible without scrolling; limits num HackListItems we must create
RE.NumVisible     =	0 -- calculated during list resize
RE.PlayerName 		=	UnitName('PLAYER')

_G.BINDING_HEADER_HACK = 'REHack'

StaticPopupDialogs.HackAccept = {
	text = 'Accept new REHack page from %s?', button1 = 'Yes', button2 = 'No',
	timeout = 0, whileDead = 1, hideOnEscape = 1,
	OnAccept = function(self)
		RE:New(self.page)
		COMM:SendCommMessage('REHack', '1ź', 'WHISPER', self.sender, 'BULK')
	end,
	OnCancel = function(self)
		COMM:SendCommMessage('REHack', '0ź', 'WHISPER', self.sender, 'BULK')
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
local items -- alias for REHackDB.books[REHackDB.book].data
local mode = 'page' -- 'page' or 'book'
local selected = nil -- index of selected list item

local function printf(...)
	_G.DEFAULT_CHAT_FRAME:AddMessage('|cffff6600<|r|cFF74D06CRE|r|cffff6600Hack>: '..format(...))
end
local function getobj(...)
	return getglobal(format(...))
end
local function enableButton(b,e)
	if e then
		_G.HackNew.Enable(b)
	else _G.HackNew.Disable(b)
	end
end
local function ElvUISwag(sender)
	if sender == 'Livarax-BurningLegion' then
		return [[|TInterface\PvPRankBadges\PvPRank09:0|t ]]
	end
	return nil
end

function RE:Find(pattern) -- search books for a page by name
	for _, book in pairs(_G.REHackDB.books) do
		for _, page in pairs(book.data) do
			if page.name:match(pattern) then
				return page
			end
		end
	end
end

-- Exec functions

function RE:ScriptError(type, err)
	local name, line, msg = err:match('%[string (".-")%]:(%d+): (.*)')
	printf('%s error%s:\n %s', type, name and format(' in %s at line %d', name, line, msg) or '', err)
end

function RE:Compile(page)
	local func, err = loadstring(page.data:gsub('||','|'), page.name)
	if not func then
		RE:ScriptError('syntax', err)
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
	RE:ScriptError('runtime', select(2, ...))
end

function RE:Execute(func, ...)
	if func then return CheckResult(pcall(func, ...)) end
end

function RE:Run(index, ...)
	return RE:Execute(RE:Get(index or selected), ...)
end

function RE:DoAutorun()
	for _, book in pairs(_G.REHackDB.books) do
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
		local li = CreateFrame('Button', name..i, _G.HackListFrame, 'T_HackListItem')
		li:SetPoint('TOP', name..(i-1), 'BOTTOM')
		li:SetID(i)
	end

	self:RegisterEvent('ADDON_LOADED')

	_G.SLASH_HACKSLASH1 = '/hack'
	_G.SlashCmdList['HACKSLASH'] =
	function(name)
		if name == '' then
			RE:Toggle()
		else
			RE:Run(name)
		end
	end
end

function RE:OnAddonMessage(message, _, sender)
	local signal, _, name, _, payload = strsplit('ź', message)
	if signal == '0' then
		printf('%s rejected your page.', sender)
	elseif signal == '1' then
		printf('%s accepted your page.', sender)
	elseif signal == '2' then
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
		db = _G.REHackDB
		items = db.books[db.book].data
		RE:UpdateFont()
		RE:UpdateButtons()
		RE:UpdateSearchContext()
		_G.HackSnap:SetChecked(_G.REHackDB.snap)
		RE:Snap()
		_G.HackListFrame:SetMaxResize(RE.MaxWidth, (RE.MaxVisible * RE.ListItemHeight) + RE.ListVOffset + 5)
		_G.HackListFrame:SetMinResize(RE.MinWidth, RE.MinHeight)
		_G.HackListFrame:SetScript('OnSizeChanged', RE.UpdateNumListItemsVisible)
		RE:UpdateNumListItemsVisible()
		RE:DoAutorun()

		COMM:RegisterComm('REHack', RE.OnAddonMessage)

		if IsAddOnLoaded('ElvUI') and IsAddOnLoaded('AddOnSkins') then
			local AS = unpack(_G.AddOnSkins)
			_G.ElvUI[1]:GetModule('Chat'):AddPluginIcons(ElvUISwag)

			AS:SkinFrame(_G.HackListFrame)
			AS:SkinFrame(_G.HackEditFrame)
			AS:SkinCloseButton(_G.HackListFrameClose)
			AS:SkinCloseButton(_G.HackEditFrameClose)
			AS:SkinCheckBox(_G.HackSearchName)
			AS:SkinCheckBox(_G.HackSearchBody)
			AS:SkinEditBox(_G.HackSearchEdit)
			AS:SkinScrollBar(_G.HackEditScrollFrameScrollBar)
			AS:SkinTab(_G.HackListFrameTab1)
			AS:SkinTab(_G.HackListFrameTab2)
		end

		_G.HackListFrame:UnregisterEvent('ADDON_LOADED')
	end
end

-- GUI functions

function RE:SetMode(newmode)
	mode = newmode
	if mode == 'page' then
		db.book = mmin(db.book, #db.books)
		items = db.books[db.book].data
		selected = nil
		_G.HackSearchBody:Show()
		_G.HackSend:Show()
	else -- 'book'
		items = db.books
		selected = db.book
		_G.HackSearchBody:Hide()
		_G.HackEditFrame:Hide()
		_G.HackSend:Hide()
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
	PlaySound(_G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	op(nil, id + FauxScrollFrame_GetOffset(_G.HackListScrollFrame))
	RE:UpdateListItems()
end

function RE:OnListItemClicked(id)
	ListItemClickCommon(id, RE.SelectListItem)
end

function RE:OnListItemAutorunClicked(id, enable)
	ListItemClickCommon(id, function(_, selected) items[selected].autorun = enable end)
end

function RE:UpdateNumListItemsVisible()
	local visible = mfloor((_G.HackListFrame:GetHeight()-RE.ListVOffset) / RE.ListItemHeight)
	RE.NumVisible = mmin(RE.MaxVisible, visible)
	RE:UpdateListItems()
end

function RE:UpdateListItems()
	local scrollFrameWidth = _G.HackListFrame:GetWidth() - 18 -- N = inset from right edge
	FauxScrollFrame_Update(_G.HackListScrollFrame, #items, RE.NumVisible, RE.ListItemHeight, nil, nil, nil, _G.HackListScrollFrame, scrollFrameWidth - 17, scrollFrameWidth) -- N = room for scrollbar
	local offset = FauxScrollFrame_GetOffset(_G.HackListScrollFrame)
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
	enableButton(_G.HackDelete, selected)
	enableButton(_G.HackRename, selected)
	enableButton(_G.HackSend, selected)
	enableButton(_G.HackMoveUp, selected and selected > 1)
	enableButton(_G.HackMoveDown, selected and selected < #items)
end

function RE:UpdateSearchContext()
  local pattern = _G.HackSearchEdit:GetText():gsub('[%[%]%%()]', '%%%1'):gsub('%a', function(c) return format('[%s%s]', c:lower(), c:upper()) end)
  local nx, bx = _G.HackSearchName:GetChecked(), _G.HackSearchBody:GetChecked()
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
	    _G.HackSearchEdit:SetFocus()
	    break
	  end
	until it == start
end

function RE:ScrollSelectedIntoView()
	local offset = FauxScrollFrame_GetOffset(_G.HackListScrollFrame)
	local id = selected - offset
	if id >  RE.NumVisible then
		offset = selected - RE.NumVisible
	elseif
		id <= 0 then offset = selected-1
	end
	FauxScrollFrame_SetOffset(_G.HackListScrollFrame, offset)
	_G.HackListScrollFrameScrollBar:SetValue(offset * RE.ListItemHeight)
	RE:UpdateListItems()
end

function RE:Toggle(_)
	if _G.HackListFrame:IsVisible() then
	  _G.HackListFrame:Hide()
	else
	  _G.HackListFrame:Show()
	end
end

function RE:Tooltip(self)
	local which = self:GetName()
	local tip = which:match('Autorun') and 'Automatically run this page when Hack loads' or format(RE.Tooltips[which], mode)
	_G.GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	_G.GameTooltip:AddLine(tip)
	_G.GameTooltip:Show()
end

function RE:Rename()
	local id = selected - FauxScrollFrame_GetOffset(_G.HackListScrollFrame)
	local name = getobj('HackListItem%dName', id)
	local edit = getobj('HackListItem%dEdit', id)
	edit:SetText(items[selected].name)
	edit:Show()
	edit:SetCursorPosition(0)
	edit:SetFocus()
	name:Hide()
end

function RE:FinishRename(name, _)
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
	if _G.HackListFrame:IsShown() then RE:Rename() end
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
	_G.HackEditFrame:Hide()
	tremove(items,selected)
	if #items == 0 then selected = nil
	elseif selected > #items then selected = #items end
	RE:UpdateButtons()
	RE:UpdateListItems()
end

function RE:Revert()
	_G.HackEditBox:SetText(RE.revert)
	_G.HackEditBox:SetCursorPosition(0)
	_G.HackRevert:Disable()
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

function RE:FontBigger()
	db.fontsize = db.fontsize + 1
	RE:UpdateFont()
end

function RE:FontSmaller()
	db.fontsize = db.fontsize - 1
	RE:UpdateFont()
end

function RE:FontCycle()
	db.font = (db.font < #RE.fonts) and (db.font + 1) or (1)
	RE:UpdateFont()
end

function RE:UpdateFont()
	_G.HackEditBox:SetFont(RE.fonts[db.font], db.fontsize)
end

function RE:OnButtonClick(name)
	RE[gsub(name, 'Hack', '')]()
end

function RE:ApplyColor(colorize)
	if colorize then
	  RE.Indent.enable(_G.HackEditBox, 3)
	  RE.Indent.colorCodeEditbox(_G.HackEditBox)
	else
	  RE.Indent.disable(_G.HackEditBox, 3)
	end
end

function RE:EditPage()
	local page = items[selected]
	RE.revert = page.data
	_G._G.HackEditBox:SetText(page.data)
	_G.HackRevert:Disable()
	_G.HackEditFrame:Show()
	_G.HackEditBox:SetCursorPosition(0)
	_G.HackColorize:SetChecked(page.colorize)
	RE:ApplyColor(page.colorize)
end

function RE:OnEditorTextChanged(self)
	local page = items[selected]
	page.data = self:GetText()
	enableButton(_G.HackRevert, page.data ~= RE.revert)
	if not _G.HackEditScrollFrameScrollBarThumbTexture:IsVisible() then
	  _G.HackEditScrollFrameScrollBar:Hide()
	end
end

function RE:OnEditorShow()
	RE:MakeESCable('HackListFrame', false)
	PlaySound(_G.SOUNDKIT.IG_QUEST_LIST_OPEN)
end

function RE:OnEditorHide()
	RE:MakeESCable('HackListFrame', true)
	PlaySound(_G.SOUNDKIT.IG_QUEST_LIST_CLOSE)
end

function RE:OnEditorLoad(self)
	tinsert(_G.UISpecialFrames, 'HackEditFrame')
	self:SetMinResize(RE.MinWidth,RE.MinHeight)
end

function RE:Snap()
	_G.REHackDB.snap = _G.HackSnap:GetChecked()
	if _G.REHackDB.snap then
	  _G.HackEditFrame:ClearAllPoints()
	  _G.HackEditFrame:SetPoint('TOPLEFT', _G.HackListFrame, 'TOPRIGHT', -2, 0)
	end
end

function RE:Colorize()
	local page = items[selected]
	page.colorize = _G.HackColorize:GetChecked()
	RE:ApplyColor(page.colorize)
end

do
	local menu = {
		{text = 'Player', func = function()
			local dialog = StaticPopup_Show('HackSendTo')
			if dialog then
				dialog.page = items[selected]
				dialog.editBox:SetScript('OnEnterPressed', function(_) dialog.button1:Click() end)
			end
		end
		},
		{text = 'Party', func = function(self) RE:SendPage(items[selected], self.value) end},
		{text = 'Raid',  func = function(self) RE:SendPage(items[selected], self.value) end},
		{text = 'Guild', func = function(self) RE:SendPage(items[selected], self.value) end},
		{text = 'Cancel'},
	}
	CreateFrame('Frame', 'HackSendMenu', HackListFrame, 'UIDropDownMenuTemplate')
	function RE:Send()
		menu[2].disabled = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) == 0
		menu[3].disabled = not UnitInRaid('player')
		menu[4].disabled = not IsInGuild()
		EasyMenu(menu, _G.HackSendMenu, 'cursor', nil, nil, 'MENU')
	end
end

function RE:SendPage(page, channel, name)
	COMM:SendCommMessage('REHack', '2ź'..page.name..'ź'..page.data, channel, name, 'BULK')
end

function RE:MakeESCable(frame, enable)
	local index
	for i=1,#_G.UISpecialFrames do
		if _G.UISpecialFrames[i] == frame then
			index = i
			break
		end
	end
	if index and not enable then
		tremove(_G.UISpecialFrames, index)
	elseif not index and enable then
		tinsert(_G.UISpecialFrames, 1, frame)
	end
end
