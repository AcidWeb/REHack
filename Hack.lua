--------------------------------------------------------------------------------
-- Hack. Notebook addon. Eric Tetz <erictetz@gmail.com> 2008
--------------------------------------------------------------------------------

HackDB = { -- default settings saved variables
   font = 2,
   fontsize = 11,
   snap = 1,
   book = 1,
   books = { { name = 'empty book', data = { } }, },
}

Hack = {
   tooltips = {
      HackNew         = 'Create new %s',
      HackDelete      = 'Delete this %s\nSHIFT to skip confirmation prompt',
      HackRename      = 'Rename this %s',
      HackMoveUp      = 'Move this %s up in the list\nSHIFT to move in increments of 5',
      HackMoveDown    = 'Move this %s down in the list\nSHIFT to move in increments of 5',
      HackAutorun     = 'Run this page automatically when Hack loads',
      HackRun         = 'Run this page',
      HackSend        = 'Send this page to another Hack user',
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
   },
   fonts = {
      'Interface\\AddOns\\Hack\\Media\\VeraMono.ttf',
      'Fonts\\FRIZQT__.TTF',
      'Fonts\\ARIALN.TTF',
   },
   tab = '    ',
   ListItemHeight =  17, -- used in the XML, too
   ListVOffset    =  37, -- vertical space not available for list items
   MinHeight      = 141, -- scroll bar gets wonky if we let the window get too short
   MinWidth       = 296, -- keep buttons from crowding/overlapping
   MaxWidth       = 572, -- tune to match size of 200 character page name
   MaxVisible     =  50, -- num visible without scrolling; limits num HackListItems we must create
   NumVisible     =   0, -- calculated during list resize
}

BINDING_HEADER_HACK = 'Hack'  -- used by binding system

local PLAYERNAME = UnitName('player')

StaticPopupDialogs.HackAccept = {
   text = 'Accept new Hack page from %s?', button1 = 'Yes', button2 = 'No',
   timeout = 0, whileDead = 1, hideOnEscape = 1,
   OnAccept = function(self)
      Hack.New(self.page)
      SendAddonMessage('HackAck', PLAYERNAME, 'WHISPER', self.sender)
   end,
   OnCancel = function(self)
      SendAddonMessage('HackNack', PLAYERNAME, 'WHISPER', self.sender)
   end,
}

StaticPopupDialogs.HackSendTo = {
   text = 'Send selected page to', button1 = 'OK', button2 = 'CANCEL',
   hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
   OnAccept = function(self)
      --XXX local name = getglobal(this:GetParent():GetName()..'EditBox'):GetText()
      local name = self.editBox:GetText()
      if name == '' then return true end
      Hack.SendPage(self.page, 'WHISPER', name)
   end
}

StaticPopupDialogs.HackDelete = {
   text = 'Delete selected %s?', button1 = 'Yes', button2 = 'No',
   timeout = 0, whileDead = 1, hideOnEscape = 1,
   OnAccept = function()
      Hack.DeleteSelected()
   end
}

local db -- alias for HackDB
local items -- alias for HackDB.books[HackDB.book].data
local mode = 'page' -- 'page' or 'book'
local selected = nil -- index of selected list item

local function printf(...) DEFAULT_CHAT_FRAME:AddMessage('|cffff6600<Hack>: '..format(...)) end
local function getobj(...) return getglobal(format(...)) end
local function enableButton(b,e) if e then HackNew.Enable(b) else HackNew.Disable(b) end end

function Hack.Find(pattern) -- search books for a page by name
   for _,book in pairs(HackDB.books) do
      for _,page in pairs(book.data) do
         if page.name:match(pattern) then
            return page
         end
      end
   end
end

function Hack.ScriptError(type, err)
   local name, line, msg = err:match('%[string (".-")%]:(%d+): (.*)')
   printf( '%s error%s:\n %s', type,
          name and format(' in %s at line %d', name, line, msg) or '',
          err )
end

function Hack.Compile(page)
   local func, err = loadstring(page.data:gsub('||','|'), page.name)
   if not func then Hack.ScriptError('syntax', err) return end
   return func
end

-- find page by index or name and return it as a compiled function
function Hack.Get(index)
   local page = type(index)=='string' and Hack.Find(index) or items[index]
   if not page then printf('attempt to get an invalid page') return end
   return Hack.Compile(page)
end

-- avoids need to create a table to capture return values in Hack.Execute
local function CheckResult(...)
   if ... then return select(2,...) end
   Hack.ScriptError('runtime', select(2,...))
end

function Hack.Execute(func, ...)
   if func then return CheckResult( pcall(func, ...) ) end
end

function Hack.Run(index, ...)
   return Hack.Execute( Hack.Get(index or selected), ... )
end

do
   local loaded = {}
   -- similar to Lua 'require': loads a page if not already loaded
   function Hack.Require(name)
      if not loaded[name] then
         loaded[name] = true
         Hack.Run(name)
      end
   end
end

function Hack.DoAutorun()
   for i,book in pairs(HackDB.books) do
      for i,page in pairs(book.data) do
         if page.autorun then
            Hack.Execute( Hack.Compile(page) )
         end
      end
   end
end

function Hack.OnLoad(self)
   -- instantiate list items
   local name = 'HackListItem'
   for i=2,Hack.MaxVisible do
      local li = CreateFrame('Button', name..i, HackListFrame, 'T_HackListItem')
      li:SetPoint('TOP', name..(i-1), 'BOTTOM')
      li:SetID(i)
   end

   -- users can delete HackExamples.lua to avoid loading them
   if HackExamples then
      table.insert( HackDB.books, 1, HackExamples.examplebook )
      setmetatable( HackExamples, { __mode='kv' } ) -- let examplebook be collected
   end

   self:RegisterEvent('VARIABLES_LOADED')
   self:RegisterEvent('CHAT_MSG_ADDON')

   -- Addon message prefixes
   RegisterAddonMessagePrefix("Hack1")
   RegisterAddonMessagePrefix("Hack2")
   RegisterAddonMessagePrefix("HackAck")
   RegisterAddonMessagePrefix("HackNack")

   SLASH_HACKSLASH1 = '/hack'
   SlashCmdList['HACKSLASH'] =
      function(name)
         if name == '' then
            Hack.Toggle()
         else
            Hack.Run(name)
         end
      end

   printf('Loaded. /hack to toggle')
end

function Hack.VARIABLES_LOADED(self)
   db = HackDB
   items = db.books[db.book].data
   Hack.UpdateFont()
   Hack.UpdateButtons()
   Hack.UpdateSearchContext()
   HackSnap:SetChecked(HackDB.snap)
   Hack.Snap()
   if not HackIndent then HackColorize:Hide() end
   self:SetMaxResize(Hack.MaxWidth, (Hack.MaxVisible * Hack.ListItemHeight) + Hack.ListVOffset + 5)
   self:SetMinResize(Hack.MinWidth, Hack.MinHeight)
   HackListFrame:SetScript('OnSizeChanged', Hack.UpdateNumListItemsVisible)
   Hack.UpdateNumListItemsVisible()
   Hack.DoAutorun()
end

-- switch between viewing books vs pages
function Hack.SetMode(newmode)
   mode = newmode
   if mode == 'page' then
      db.book = math.min(db.book, #db.books)
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
   Hack.UpdateButtons()
   Hack.UpdateListItems()
end

function Hack.SelectListItem(index)
   selected = index
   Hack.UpdateButtons()
   if mode == 'page' then
      Hack.EditPage()
   else -- 'book'
      db.book = index
   end
end

local function ListItemClickCommon(id, op)
   PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
   op(id + FauxScrollFrame_GetOffset(HackListScrollFrame))
   Hack.UpdateListItems()
end

function Hack.OnListItemClicked(id)
   ListItemClickCommon(id, Hack.SelectListItem)
end

function Hack.OnListItemAutorunClicked(id, enable)
   ListItemClickCommon(id, function(selected) items[selected].autorun = enable end)
end

function Hack.UpdateNumListItemsVisible()
   local visible = math.floor( (HackListFrame:GetHeight()-Hack.ListVOffset) / Hack.ListItemHeight )
   Hack.NumVisible = math.min( Hack.MaxVisible, visible )
   Hack.UpdateListItems()
end

function Hack.UpdateListItems()
   local scrollFrameWidth = HackListFrame:GetWidth() - 18 -- N = inset from right edge
   FauxScrollFrame_Update(HackListScrollFrame, #items, Hack.NumVisible, Hack.ListItemHeight,
      nil, nil, nil, HackListScrollFrame, scrollFrameWidth-17, scrollFrameWidth) -- N = room for scrollbar
   local offset = FauxScrollFrame_GetOffset(HackListScrollFrame)
   for widgetIndex=1, Hack.MaxVisible do
      local itemIndex = offset + widgetIndex
      local item = items[itemIndex]
      local widget = getobj('HackListItem%d', widgetIndex)
      if not item or widgetIndex > Hack.NumVisible then
         widget:Hide()
      else
         widget:Show()
         local name = getobj('HackListItem%dName', widgetIndex)
         local edit = getobj('HackListItem%dEdit', widgetIndex)
         local auto = getobj('HackListItem%dAutorun', widgetIndex)
         edit:ClearFocus() -- in case someone tries to scroll while renaming
         if Hack.SearchMatch(item) then
            name:SetTextColor(1,1,1) else name:SetTextColor(.3,.3,.3) end
         if itemIndex == selected then
            widget:LockHighlight() else widget:UnlockHighlight() end
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

function Hack.UpdateButtons()
   enableButton( HackDelete,   selected )
   enableButton( HackRename,   selected )
   enableButton( HackSend,     selected )
   enableButton( HackMoveUp,   selected and selected > 1 )
   enableButton( HackMoveDown, selected and selected < #items )
end

function Hack.UpdateSearchContext()
   local pattern = HackSearchEdit:GetText()
      :gsub('[%[%]%%()]', '%%%1') -- escape magic chars (the price we pay for real-time filtering)
      :gsub('%a', function(c) return format('[%s%s]', c:lower(), c:upper()) end) -- case insensitive
   local nx, bx = HackSearchName:GetChecked(), HackSearchBody:GetChecked()
   function Hack.SearchMatch(item)
      return not (nx or bx)
             or (                   nx and item.name:match(pattern))
             or (mode == 'page' and bx and item.data:match(pattern))
   end
   Hack.UpdateListItems()
end

function Hack.DoSearch(direction) -- 1=down, -1=up
   if #items == 0 then return end
   local start = selected or 1
   local it = start
   repeat
      it = it + direction
      if     it > #items then it = 1 -- wrap at..
      elseif it < 1 then it = #items --   ..either end
      end
      if Hack.SearchMatch(items[it]) then
         Hack.SelectListItem(it)
         Hack.ScrollSelectedIntoView()
         HackSearchEdit:SetFocus()
         break
      end
   until it == start
end

function Hack.ScrollSelectedIntoView()
   local offset = FauxScrollFrame_GetOffset(HackListScrollFrame)
   local id = selected - offset
   if     id >  Hack.NumVisible then offset = selected-Hack.NumVisible
   elseif id <= 0                then offset = selected-1 end
   FauxScrollFrame_SetOffset(HackListScrollFrame, offset)
   HackListScrollFrameScrollBar:SetValue(offset * Hack.ListItemHeight)
   Hack.UpdateListItems()
end

function Hack.Toggle(msg)
   if HackListFrame:IsVisible() then
      HackListFrame:Hide()
   else
      HackListFrame:Show()
   end
end

function Hack.Tooltip(self)
   local which = self:GetName()
   local tip = which:match('Autorun')
      and 'Automatically run this page when Hack loads'
      or format(Hack.tooltips[which], mode)
   GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
   GameTooltip:AddLine(tip)
   GameTooltip:Show()
end

function Hack.Rename()
   local id = selected - FauxScrollFrame_GetOffset(HackListScrollFrame)
   local name = getobj("HackListItem%dName", id)
   local edit = getobj("HackListItem%dEdit", id)
   edit:SetText( items[selected].name )
   edit:Show()
   edit:SetCursorPosition(0)
   edit:SetFocus()
   name:Hide()
end

function Hack.FinishRename(name, editbox)
   items[selected].name = name
   Hack.UpdateListItems()
end

function Hack.New(page)
   local index = selected or #items+1
   local data = (mode == 'page') and '' or {}
   page = page or { name='', data=data }
   table.insert(items, index, page)
   Hack.SelectListItem(index)
   Hack.UpdateListItems()
   Hack.ScrollSelectedIntoView()
   if HackListFrame:IsShown() then Hack.Rename() end
end

function Hack.Delete()
   if mode == 'book' and #items == 1 then
      printf('You cannot delete the last %s!', mode)
   elseif IsShiftKeyDown() or #items[selected].data == 0 then
      Hack.DeleteSelected()
   else
      StaticPopup_Show('HackDelete', mode)
   end
end

function Hack.DeleteSelected()
   HackEditFrame:Hide()
   table.remove(items,selected)
   if #items == 0 then selected = nil
   elseif selected > #items then selected = #items end
   Hack.UpdateButtons()
   Hack.UpdateListItems()
end

function Hack.Revert()
   HackEditBox:SetText(Hack.revert)
   HackEditBox:SetCursorPosition(0)
   HackRevert:Disable()
end

function Hack.MoveItem(direction)
   local to = selected + direction * (IsShiftKeyDown() and 5 or 1)
   if     to > #items then to = #items
   elseif to < 1      then to = 1      end
   while selected ~= to do
      items[selected], items[selected+direction] = items[selected+direction], items[selected]
      selected = selected + direction
   end
   Hack.ScrollSelectedIntoView()
   Hack.UpdateButtons()
end

function Hack.MoveUp()
   Hack.MoveItem(-1)
end

function Hack.MoveDown()
   Hack.MoveItem(1)
end

function Hack.FontBigger()
   db.fontsize = db.fontsize + 1
   Hack.UpdateFont()
end

function Hack.FontSmaller()
   db.fontsize = db.fontsize - 1
   Hack.UpdateFont()
end

function Hack.FontCycle()
   db.font = (db.font < #Hack.fonts) and (db.font + 1) or (1)
   Hack.UpdateFont()
end

function Hack.UpdateFont()
   HackEditBox:SetFont(Hack.fonts[db.font], db.fontsize)
end

function Hack.OnButtonClick(name)
   Hack[ name:match('Hack(.*)') ]()
end

function Hack.ApplyColor(colorize)
   if colorize then
      HackIndent.enable(HackEditBox, 3)
      HackIndent.colorCodeEditbox(HackEditBox)
   else
      HackIndent.disable(HackEditBox, 3)
   end
end

function Hack.EditPage()
   local page = items[selected]
   Hack.revert = page.data
   HackEditBox:SetText(page.data)
   HackRevert:Disable()
   HackEditFrame:Show()
   HackEditBox:SetCursorPosition(0)
   if HackIndent then
      HackColorize:SetChecked(page.colorize)
      Hack.ApplyColor(page.colorize)
   end
end

function Hack.OnEditorTextChanged(self)
   local page = items[selected]
   page.data = self:GetText()
   enableButton(HackRevert, page.data ~= Hack.revert)
   if not HackEditScrollFrameScrollBarThumbTexture:IsVisible() then
      HackEditScrollFrameScrollBar:Hide()
   end
end

function Hack.OnEditorShow()
   Hack.MakeESCable('HackListFrame',false)
   PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
end

function Hack.OnEditorHide()
   Hack.MakeESCable('HackListFrame',true)
   PlaySound(SOUNDKIT.IG_QUEST_LIST_CLOSE)
end

function Hack.OnEditorLoad(self)
   table.insert(UISpecialFrames,'HackEditFrame')
   self:SetMinResize(Hack.MinWidth,Hack.MinHeight)
end

function Hack.Snap()
   HackDB.snap = HackSnap:GetChecked()
   if HackDB.snap then
      HackEditFrame:ClearAllPoints()
      HackEditFrame:SetPoint('TOPLEFT', HackListFrame, 'TOPRIGHT', -2, 0)
   end
end

function Hack.Colorize()
   local page = items[selected]
   page.colorize = HackColorize:GetChecked()
   Hack.ApplyColor(page.colorize)
end

do
   local function send(self) Hack.SendPage(items[selected], self.value) end
   local menu = {
      { text = 'Player', func = function()
            local dialog = StaticPopup_Show('HackSendTo')
            if dialog then
               dialog.page = items[selected]
               dialog.editBox:SetScript('OnEnterPressed',  function(t) dialog.button1:Click() end)
            end
         end
      },
      { text = 'Party', func = send },
      { text = 'Raid',  func = send },
      { text = 'Guild', func = send },
      { text = 'Cancel' },
   }
   CreateFrame('Frame', 'HackSendMenu', HackListFrame, 'UIDropDownMenuTemplate')
   function Hack.Send()
      menu[2].disabled = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) == 0
      menu[3].disabled = not UnitInRaid('player')
      menu[4].disabled = not IsInGuild()
      EasyMenu(menu, HackSendMenu, 'cursor', nil, nil, 'MENU')
   end
end

function Hack.SendPage(page, channel, name)
   local id = 'Hack'..(time()%2+1)
   local chunksize = 254 - #id
   local pagename = format('%s [from %s on %s]', page.name, PLAYERNAME, date())
   SendAddonMessage(id, pagename, channel, name)
   for i=1,#page.data,chunksize do
      SendAddonMessage(id, page.data:sub(i,i+chunksize-1), channel, name)
   end
   SendAddonMessage(id, '', channel, name)
end

do -- receive page
   local receiving = {}
   function Hack.CHAT_MSG_ADDON(self, msg, prefix, body, channel, sender)
      if sender == PLAYERNAME then return end
		local id
		if not prefix then
			id = nil
		else
			id = strmatch(prefix, 'Hack(.*)')
		end
      --local id = prefix:match('Hack(.*)')
      if not id then
         return -- message not for Hack
      elseif id == 'Ack' then
         printf('%s accepted your page.', sender)
      elseif id == 'Nack' then
         printf('%s rejected your page.', sender)
      elseif not receiving[id] then -- new page incoming
         receiving[id] = { name = body, data = {} }
      elseif #body > 1 then -- append to page body
         table.insert(receiving[id].data, body)
      else -- page end
         local page = { name=receiving[id].name, data=table.concat(receiving[id].data) }
         receiving[id] = nil
         local dialog = StaticPopup_Show('HackAccept', sender)
         if dialog then
            dialog.page = page
            dialog.sender = sender
         end
      end
   end
end

-- add/remove frame from UISpecialFrames (borrowed from TinyPad)
function Hack.MakeESCable(frame,enable)
   local index
   for i=1,#UISpecialFrames do
      if UISpecialFrames[i]==frame then
         index = i
         break
      end
   end
   if index and not enable then
      table.remove(UISpecialFrames,index)
   elseif not index and enable then
      table.insert(UISpecialFrames,1,frame)
   end
end
