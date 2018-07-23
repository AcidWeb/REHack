-- This is a Hack-specific version of the addon 'For All Indents And Purposes'
-- written by kristofer.karlsson@gmail.com
--
-- The original library has a bug which causes it to consume vertical bars
-- (i.e. '|') if you enabled/disabled the library on an edit box. This version
-- fixes that issue, with a few other minor changes:
-- * I've moved some items from tables to locals for speed reasons.
-- * I rewrote stripWoWColors for speed reasons.
-- * Replaced cursor positioning code with standard editbox methods added in WoW 2.3
-- * I hardcoded my prefered syntax highlighting colors into it ; you can edit
--   these by searching this code for 'colorTable'.
-- The temptation to do a major rewrite of this code is strong, but my laziness
-- is stronger...
--
-- Mud, aka Eric Tetz <erictetz@gmail.com>


if not HackIndent then
   HackIndent = {}
end

local lib = HackIndent

local stringlen = string.len
local stringformat = string.format
local stringfind = string.find
local stringsub = string.sub
local stringbyte = string.byte
local stringchar = string.char
local stringrep = string.rep
local stringgsub = string.gsub

local function stringinsert(s, pos, insertStr)
   return format('%s%s%s', stringsub(s, 1, pos), insertStr, stringsub(s, pos + 1))
end

local function stringdelete(s, pos1, pos2)
   return stringsub(s, 1, pos1 - 1) .. stringsub(s, pos2 + 1)
end

local workingTable = {}
local workingTable2 = {}
local function tableclear(t)
   for k in next,t do
      t[k] = nil
   end
end

-- token types
local TOKEN_UNKNOWN = 0
local TOKEN_NUMBER = 1
local TOKEN_LINEBREAK = 2
local TOKEN_WHITESPACE = 3
local TOKEN_IDENTIFIER = 4
local TOKEN_ASSIGNMENT = 5
local TOKEN_EQUALITY = 6
local TOKEN_MINUS = 7
local TOKEN_COMMENT_SHORT = 8
local TOKEN_COMMENT_LONG = 9
local TOKEN_STRING = 10
local TOKEN_LEFTBRACKET = 11
local TOKEN_PERIOD = 12
local TOKEN_DOUBLEPERIOD = 13
local TOKEN_TRIPLEPERIOD = 14
local TOKEN_LTE = 15
local TOKEN_LT = 16
local TOKEN_GTE = 17
local TOKEN_GT = 18
local TOKEN_NOTEQUAL = 19
local TOKEN_COMMA = 20
local TOKEN_SEMICOLON = 21
local TOKEN_COLON = 22
local TOKEN_LEFTPAREN = 23
local TOKEN_RIGHTPAREN = 24
local TOKEN_PLUS = 25
local TOKEN_SLASH = 27
local TOKEN_LEFTWING = 28
local TOKEN_RIGHTWING = 29
local TOKEN_CIRCUMFLEX = 30
local TOKEN_ASTERISK = 31
local TOKEN_RIGHTBRACKET = 32
local TOKEN_KEYWORD = 33
local TOKEN_SPECIAL = 34
local TOKEN_VERTICAL = 35
local TOKEN_TILDE = 36

-- WoW specific tokens
local TOKEN_COLORCODE_START = 37
local TOKEN_COLORCODE_STOP = 38

-- new as of lua 5.1
local TOKEN_HASH = 39
local TOKEN_PERCENT = 40


-- color scheme
local colorTable = { [0] = '|r' }
local function set(color, ...)
   for i=1,select('#',...) do
      colorTable[select(i,...)] = color
   end
end
set('|c008DBBD7', TOKEN_KEYWORD)
set('|c00FFA600', TOKEN_SPECIAL, '..','...')
set('|c00c27272', TOKEN_STRING, TOKEN_NUMBER)
set('|c00888855', TOKEN_COMMENT_SHORT, TOKEN_COMMENT_LONG)
set('|c00ccbbaa', '{','}','[',']','(',')','+','-','/','*')
set('|c00ccddee', '==','<','<=','>','>=','~=','and','or','not')


-- ascii codes
local BYTE_LINEBREAK_UNIX = stringbyte("\n")
local BYTE_LINEBREAK_MAC = stringbyte("\r")
local BYTE_SINGLE_QUOTE = stringbyte("'")
local BYTE_DOUBLE_QUOTE = stringbyte('"')
local BYTE_0 = stringbyte("0")
local BYTE_9 = stringbyte("9")
local BYTE_PERIOD = stringbyte(".")
local BYTE_SPACE = stringbyte(" ")
local BYTE_TAB = stringbyte("\t")
local BYTE_E = stringbyte("E")
local BYTE_e = stringbyte("e")
local BYTE_MINUS = stringbyte("-")
local BYTE_EQUALS = stringbyte("=")
local BYTE_LEFTBRACKET = stringbyte("[")
local BYTE_RIGHTBRACKET = stringbyte("]")
local BYTE_BACKSLASH = stringbyte("\\")
local BYTE_COMMA = stringbyte(",")
local BYTE_SEMICOLON = stringbyte(";")
local BYTE_COLON = stringbyte(":")
local BYTE_LEFTPAREN = stringbyte("(")
local BYTE_RIGHTPAREN = stringbyte(")")
local BYTE_TILDE = stringbyte("~")
local BYTE_PLUS = stringbyte("+")
local BYTE_SLASH = stringbyte("/")
local BYTE_LEFTWING = stringbyte("{")
local BYTE_RIGHTWING = stringbyte("}")
local BYTE_CIRCUMFLEX = stringbyte("^")
local BYTE_ASTERISK = stringbyte("*")
local BYTE_LESSTHAN = stringbyte("<")
local BYTE_GREATERTHAN = stringbyte(">")
-- WoW specific chars
local BYTE_VERTICAL = stringbyte("|")
local BYTE_r = stringbyte("r")
local BYTE_c = stringbyte("c")

-- new as of lua 5.1
local BYTE_HASH = stringbyte("#")
local BYTE_PERCENT = stringbyte("%")

local linebreakCharacters = {}
lib.linebreakCharacters = linebreakCharacters
linebreakCharacters[BYTE_LINEBREAK_UNIX] = 1
linebreakCharacters[BYTE_LINEBREAK_MAC] = 1

local whitespaceCharacters = {}
lib.whitespaceCharacters = whitespaceCharacters
whitespaceCharacters[BYTE_SPACE] = 1
whitespaceCharacters[BYTE_TAB] = 1

local specialCharacters = {}
lib.specialCharacters = specialCharacters
specialCharacters[BYTE_PERIOD] = -1
specialCharacters[BYTE_LESSTHAN] = -1
specialCharacters[BYTE_GREATERTHAN] = -1
specialCharacters[BYTE_LEFTBRACKET] = -1
specialCharacters[BYTE_EQUALS] = -1
specialCharacters[BYTE_MINUS] = -1
specialCharacters[BYTE_SINGLE_QUOTE] = -1
specialCharacters[BYTE_DOUBLE_QUOTE] = -1
specialCharacters[BYTE_TILDE] = -1
specialCharacters[BYTE_RIGHTBRACKET] = TOKEN_RIGHTBRACKET
specialCharacters[BYTE_COMMA] = TOKEN_COMMA
specialCharacters[BYTE_COLON] = TOKEN_COLON
specialCharacters[BYTE_SEMICOLON] = TOKEN_SEMICOLON
specialCharacters[BYTE_LEFTPAREN] = TOKEN_LEFTPAREN
specialCharacters[BYTE_RIGHTPAREN] = TOKEN_RIGHTPAREN
specialCharacters[BYTE_PLUS] = TOKEN_PLUS
specialCharacters[BYTE_SLASH] = TOKEN_SLASH
specialCharacters[BYTE_LEFTWING] = TOKEN_LEFTWING
specialCharacters[BYTE_RIGHTWING] = TOKEN_RIGHTWING
specialCharacters[BYTE_CIRCUMFLEX] = TOKEN_CIRCUMFLEX
specialCharacters[BYTE_ASTERISK] = TOKEN_ASTERISK
-- WoW specific
specialCharacters[BYTE_VERTICAL] = -1
-- new as of lua 5.1
specialCharacters[BYTE_HASH] = TOKEN_HASH
specialCharacters[BYTE_PERCENT] = TOKEN_PERCENT

local function nextNumberExponentPartInt(text, pos)
   while true do
      local byte = stringbyte(text, pos)
      if not byte then
         return TOKEN_NUMBER, pos
      end

      if byte >= BYTE_0 and byte <= BYTE_9 then  
         pos = pos + 1
      else
         return TOKEN_NUMBER, pos 
      end
   end
end

local function nextNumberExponentPart(text, pos)
   local byte = stringbyte(text, pos)
   if not byte then
      return TOKEN_NUMBER, pos
   end

   if byte == BYTE_MINUS then
      -- handle this case: a = 1.2e-- some comment
      -- i decide to let 1.2e be parsed as a a number
      byte = stringbyte(text, pos + 1)
      if byte == BYTE_MINUS then
         return TOKEN_NUMBER, pos
      end
      return nextNumberExponentPartInt(text, pos + 1)
   end

   return nextNumberExponentPartInt(text, pos)
end

local function nextNumberFractionPart(text, pos)
   while true do
      local byte = stringbyte(text, pos)
      if not byte then
         return TOKEN_NUMBER, pos
      end

      if byte >= BYTE_0 and byte <= BYTE_9 then  
         pos = pos + 1
      elseif byte == BYTE_E or byte == BYTE_e then
         return nextNumberExponentPart(text, pos + 1)
      else
         return TOKEN_NUMBER, pos 
      end
   end
end

local function nextNumberIntPart(text, pos)
   while true do
      local byte = stringbyte(text, pos)
      if not byte then
         return TOKEN_NUMBER, pos
      end

      if byte >= BYTE_0 and byte <= BYTE_9 then  
         pos = pos + 1
      elseif byte == BYTE_PERIOD then
         return nextNumberFractionPart(text, pos + 1)
      elseif byte == BYTE_E or byte == BYTE_e then
         return nextNumberExponentPart(text, pos + 1)
      else
         return TOKEN_NUMBER, pos
      end
   end
end

local function nextIdentifier(text, pos)
   while true do
      local byte = stringbyte(text, pos)

      if not byte or
         linebreakCharacters[byte] or
         whitespaceCharacters[byte] or
         specialCharacters[byte] then
         return TOKEN_IDENTIFIER, pos
      end
      pos = pos + 1
   end
end

-- returns false or: true, nextPos, equalsCount
local function isBracketStringNext(text, pos)
   local byte = stringbyte(text, pos)
   if byte == BYTE_LEFTBRACKET then
      local pos2 = pos + 1
      byte = stringbyte(text, pos2)
      while byte == BYTE_EQUALS do
         pos2 = pos2 + 1
         byte = stringbyte(text, pos2)
      end
      if byte == BYTE_LEFTBRACKET then
         return true, pos2 + 1, (pos2 - 1) - pos
      else
         return false
      end
   else
      return false
   end
end


-- Already parsed the [==[ part when get here
local function nextBracketString(text, pos, equalsCount)
   local state = 0
   while true do
      local byte = stringbyte(text, pos)
      if not byte then
         return TOKEN_STRING, pos
      end

      if byte == BYTE_RIGHTBRACKET then
         if state == 0 then
            state = 1
         elseif state == equalsCount + 1 then
            return TOKEN_STRING, pos + 1
         else
            state = 0
         end
      elseif byte == BYTE_EQUALS then
         if state > 0 then
            state = state + 1
         end
      else
         state = 0
      end
      pos = pos + 1
   end
end

local function nextComment(text, pos)
   -- When we get here we have already parsed the "--"
   -- Check for long comment
   local isBracketString, nextPos, equalsCount = isBracketStringNext(text, pos)
   if isBracketString then
      local tokenType, nextPos2 = nextBracketString(text, nextPos, equalsCount)
      return TOKEN_COMMENT_LONG, nextPos2
   end

   local byte = stringbyte(text, pos)

   -- Short comment, find the first linebreak
   while true do
      byte = stringbyte(text, pos)
      if not byte then
         return TOKEN_COMMENT_SHORT, pos
      end
      if linebreakCharacters[byte] then
         return TOKEN_COMMENT_SHORT, pos
      end
      pos = pos + 1
   end
end

local function nextString(text, pos, character)
   local even = true
   while true do
      local byte = stringbyte(text, pos)
      if not byte then
         return TOKEN_STRING, pos
      end

      if byte == character then
         if even then
            return TOKEN_STRING, pos + 1
         end
      end
      if byte == BYTE_BACKSLASH then
         even = not even
      else
         even = true
      end

      pos = pos + 1
   end
end

-- INPUT
-- 1: text: text to search in
-- 2: tokenPos:  where to start searching
-- OUTPUT
-- 1: token type
-- 2: position after the last character of the token
local function nextToken(text, pos)
   local byte = stringbyte(text, pos)
   if not byte then
      return nil
   end

   if linebreakCharacters[byte] then
      return TOKEN_LINEBREAK, pos + 1
   end

   if whitespaceCharacters[byte] then
      while true do
         pos = pos + 1
         byte = stringbyte(text, pos)
         if not byte or not whitespaceCharacters[byte] then
            return TOKEN_WHITESPACE, pos
         end
      end
   end

   local token = specialCharacters[byte]
   if token then
      if token ~= -1 then
         return token, pos + 1
      end

      -- WoW specific (for color codes)
      if byte == BYTE_VERTICAL then
         byte = stringbyte(text, pos + 1)
         if byte == BYTE_VERTICAL then
            return TOKEN_VERTICAL, pos + 1
         end
         if byte == BYTE_c then
            return TOKEN_COLORCODE_START, pos + 10
         end
         if byte == BYTE_r then
            return TOKEN_COLORCODE_STOP, pos + 2
         end
         return TOKEN_UNKNOWN, pos + 1
      end

      if byte == BYTE_MINUS then
         byte = stringbyte(text, pos + 1)
         if byte == BYTE_MINUS then
            return nextComment(text, pos + 2)
         end
         return TOKEN_MINUS, pos + 1
      end

      if byte == BYTE_SINGLE_QUOTE then
         return nextString(text, pos + 1, BYTE_SINGLE_QUOTE)
      end

      if byte == BYTE_DOUBLE_QUOTE then
         return nextString(text, pos + 1, BYTE_DOUBLE_QUOTE)
      end

      if byte == BYTE_LEFTBRACKET then
         local isBracketString, nextPos, equalsCount = isBracketStringNext(text, pos)
         if isBracketString then
            return nextBracketString(text, nextPos, equalsCount)
         else
            return TOKEN_LEFTBRACKET, pos + 1
         end
      end

      if byte == BYTE_EQUALS then
         byte = stringbyte(text, pos + 1)
         if not byte then
            return TOKEN_ASSIGNMENT, pos + 1
         end
         if byte == BYTE_EQUALS then
            return TOKEN_EQUALITY, pos + 2
         end
         return TOKEN_ASSIGNMENT, pos + 1
      end

      if byte == BYTE_PERIOD then
         byte = stringbyte(text, pos + 1)
         if not byte then
            return TOKEN_PERIOD, pos + 1
         end
         if byte == BYTE_PERIOD then
            byte = stringbyte(text, pos + 2)
            if byte == BYTE_PERIOD then
               return TOKEN_TRIPLEPERIOD, pos + 3
            end
            return TOKEN_DOUBLEPERIOD, pos + 2
         elseif byte >= BYTE_0 and byte <= BYTE_9 then
            return nextNumberFractionPart(text, pos + 2)
         end
         return TOKEN_PERIOD, pos + 1
      end

      if byte == BYTE_LESSTHAN then
         byte = stringbyte(text, pos + 1)
         if byte == BYTE_EQUALS then
            return TOKEN_LTE, pos + 2
         end
         return TOKEN_LT, pos + 1
      end

      if byte == BYTE_GREATERTHAN then
         byte = stringbyte(text, pos + 1)
         if byte == BYTE_EQUALS then
            return TOKEN_GTE, pos + 2
         end
         return TOKEN_GT, pos + 1
      end

      if byte == BYTE_TILDE then
         byte = stringbyte(text, pos + 1)
         if byte == BYTE_EQUALS then
            return TOKEN_NOTEQUAL, pos + 2
         end
         return TOKEN_TILDE, pos + 1
      end

      return TOKEN_UNKNOWN, pos + 1
   elseif byte >= BYTE_0 and byte <= BYTE_9 then
      return nextNumberIntPart(text, pos + 1)
   else
      return nextIdentifier(text, pos + 1)
   end
end

-- Cool stuff begins here! (indentation and highlighting)

local noIndentEffect = {0, 0}
local indentLeft = {-1, 0}
local indentRight = {0, 1}
local indentBoth = {-1, 1}

local keywords = {}
lib.keywords = keywords
keywords["and"] = noIndentEffect
keywords["break"] = noIndentEffect
keywords["false"] = noIndentEffect
keywords["for"] = noIndentEffect
keywords["if"] = noIndentEffect
keywords["in"] = noIndentEffect
keywords["local"] = noIndentEffect
keywords["nil"] = noIndentEffect
keywords["not"] = noIndentEffect
keywords["or"] = noIndentEffect
keywords["return"] = noIndentEffect
keywords["true"] = noIndentEffect
keywords["while"] = noIndentEffect

keywords["until"] = indentLeft
keywords["elseif"] = indentLeft
keywords["end"] = indentLeft

keywords["do"] = indentRight
keywords["then"] = indentRight
keywords["repeat"] = indentRight
keywords["function"] = indentRight

keywords["else"] = indentBoth

local tokenIndentation = {}
lib.tokenIndentation = tokenIndentation
tokenIndentation[TOKEN_LEFTPAREN] = indentRight
tokenIndentation[TOKEN_LEFTBRACKET] = indentRight
tokenIndentation[TOKEN_LEFTWING] = indentRight

tokenIndentation[TOKEN_RIGHTPAREN] = indentLeft
tokenIndentation[TOKEN_RIGHTBRACKET] = indentLeft
tokenIndentation[TOKEN_RIGHTWING] = indentLeft

local function fillWithTabs(n)
   return stringrep("\t", n)
end

local function fillWithSpaces(a, b)
   return stringrep(" ", a*b)
end

function lib.colorCodeCode(code, caretPosition)
   local stopColor = colorTable and colorTable[0]
   if not stopColor then
      return code, caretPosition
   end

   local stopColorLen = stringlen(stopColor)

   tableclear(workingTable)
   local tsize = 0
   local totalLen = 0

   local numLines = 0
   local newCaretPosition
   local prevTokenWasColored = false
   local prevTokenWidth = 0

   local pos = 1
   local level = 0

   while true do
      if caretPosition and not newCaretPosition and pos >= caretPosition then
         if pos == caretPosition then
            newCaretPosition = totalLen
         else
            newCaretPosition = totalLen
            local diff = pos - caretPosition
            if diff > prevTokenWidth then
               diff = prevTokenWidth
            end
            if prevTokenWasColored then
               diff = diff + stopColorLen
            end
            newCaretPosition = newCaretPosition - diff
         end
      end

      prevTokenWasColored = false
      prevTokenWidth = 0

      local tokenType, nextPos = nextToken(code, pos)

      if not tokenType then
         break
      end

      if tokenType == TOKEN_COLORCODE_START or tokenType == TOKEN_COLORCODE_STOP or tokenType == TOKEN_UNKNOWN then
         -- ignore color codes

      elseif tokenType == TOKEN_LINEBREAK or tokenType == TOKEN_WHITESPACE then
         if tokenType == TOKEN_LINEBREAK then
            numLines = numLines + 1
         end
         local str = stringsub(code, pos, nextPos - 1)
         prevTokenWidth = nextPos - pos

         tsize = tsize + 1
         workingTable[tsize] = str
         totalLen = totalLen + stringlen(str)
      else
         local str = stringsub(code, pos, nextPos - 1)

         prevTokenWidth = nextPos - pos

         -- Add coloring
         if keywords[str] then
            tokenType = TOKEN_KEYWORD
         end

         local color
         if stopColor then
            color = colorTable[str]
            if not color then
               color = colorTable[tokenType]
               if not color then
                  if tokenType == TOKEN_IDENTIFIER then
                     color = colorTable[TOKEN_IDENTIFIER]
                  else
                     color = colorTable[TOKEN_SPECIAL]
                  end
               end
            end
         end

         if color then
            tsize = tsize + 1
            workingTable[tsize] = color
            tsize = tsize + 1
            workingTable[tsize] = str
            tsize = tsize + 1
            workingTable[tsize] = stopColor

            totalLen = totalLen + stringlen(color) + (nextPos - pos) + stopColorLen
            prevTokenWasColored = true
         else
            tsize = tsize + 1
            workingTable[tsize] = str

            totalLen = totalLen + stringlen(str)
         end
      end

      pos = nextPos
   end
   return table.concat(workingTable), newCaretPosition, numLines
end

function lib.indentCode(code, tabWidth, caretPosition)
   local fillFunction
   if tabWidth == nil then
      tabWidth = defaultTabWidth
   end
   if tabWidth then
      fillFunction = fillWithSpaces
   else
      fillFunction = fillWithTabs
   end

   tableclear(workingTable)
   local tsize = 0
   local totalLen = 0

   tableclear(workingTable2)
   local tsize2 = 0
   local totalLen2 = 0


   local stopColor = colorTable and colorTable[0]
   local stopColorLen = not stopColor or stringlen(stopColor)

   local newCaretPosition
   local newCaretPositionFinalized = false
   local prevTokenWasColored = false
   local prevTokenWidth = 0

   local pos = 1
   local level = 0

   local hitNonWhitespace = false
   local hitIndentRight = false
   local preIndent = 0
   local postIndent = 0
   while true do
      if caretPosition and not newCaretPosition and pos >= caretPosition then
         if pos == caretPosition then
            newCaretPosition = totalLen + totalLen2
         else
            newCaretPosition = totalLen + totalLen2
            local diff = pos - caretPosition
            if diff > prevTokenWidth then
               diff = prevTokenWidth
            end
            if prevTokenWasColored then
               diff = diff + stopColorLen
            end
            newCaretPosition = newCaretPosition - diff
         end
      end

      prevTokenWasColored = false
      prevTokenWidth = 0

      local tokenType, nextPos = nextToken(code, pos)

      if not tokenType or tokenType == TOKEN_LINEBREAK then
         level = level + preIndent
         if level < 0 then level = 0 end

         local s = fillFunction(level, tabWidth)

         tsize = tsize + 1
         workingTable[tsize] = s
         totalLen = totalLen + stringlen(s)

         if newCaretPosition and not newCaretPositionFinalized then
            newCaretPosition = newCaretPosition + stringlen(s)
            newCaretPositionFinalized = true
         end


         for k, v in next,workingTable2 do
            tsize = tsize + 1
            workingTable[tsize] = v
            totalLen = totalLen + stringlen(v)
         end

         if not tokenType then
            break
         end

         tsize = tsize + 1
         workingTable[tsize] = stringsub(code, pos, nextPos - 1)
         totalLen = totalLen + nextPos - pos

         level = level + postIndent
         if level < 0 then level = 0 end

         tableclear(workingTable2)
         tsize2 = 0
         totalLen2 = 0

         hitNonWhitespace = false
         hitIndentRight = false
         preIndent = 0
         postIndent = 0
      elseif tokenType == TOKEN_WHITESPACE then
         if hitNonWhitespace then
            prevTokenWidth = nextPos - pos

            tsize2 = tsize2 + 1
            local s = stringsub(code, pos, nextPos - 1)
            workingTable2[tsize2] = s
            totalLen2 = totalLen2 + stringlen(s)
         end
      elseif tokenType == TOKEN_COLORCODE_START or tokenType == TOKEN_COLORCODE_STOP or tokenType == TOKEN_UNKNOWN then
         -- skip these, though they shouldn't be encountered here anyway
      else
         hitNonWhitespace = true

         local str = stringsub(code, pos, nextPos - 1)

         prevTokenWidth = nextPos - pos

         -- See if this is an indent-modifier
         local indentTable
         if tokenType == TOKEN_IDENTIFIER then
            indentTable = keywords[str]
         else
            indentTable = tokenIndentation[tokenType]
         end

         if indentTable then
            if hitIndentRight then
               postIndent = postIndent + indentTable[1] + indentTable[2]
            else
               local pre = indentTable[1]
               local post = indentTable[2]
               if post > 0 then
                  hitIndentRight = true
               end
               preIndent = preIndent + pre
               postIndent = postIndent + post
            end
         end

         -- Add coloring
         if keywords[str] then
            tokenType = TOKEN_KEYWORD
         end

         local color
         if stopColor then
            color = colorTable[str]
            if not color then
               color = colorTable[tokenType]
               if not color then
                  if tokenType == TOKEN_IDENTIFIER then
                     color = colorTable[TOKEN_IDENTIFIER]
                  else
                     color = colorTable[TOKEN_SPECIAL]
                  end
               end
            end
         end

         if color then
            tsize2 = tsize2 + 1
            workingTable2[tsize2] = color
            totalLen2 = totalLen2 + stringlen(color)

            tsize2 = tsize2 + 1
            workingTable2[tsize2] = str
            totalLen2 = totalLen2 + nextPos - pos

            tsize2 = tsize2 + 1
            workingTable2[tsize2] = stopColor
            totalLen2 = totalLen2 + stopColorLen

            prevTokenWasColored = true
         else
            tsize2 = tsize2 + 1
            workingTable2[tsize2] = str
            totalLen2 = totalLen2 + nextPos - pos

         end
      end
      pos = nextPos
   end
   return table.concat(workingTable), newCaretPosition
end



-- WoW specific code:
local GetTime = GetTime

local editboxSetText
local editboxGetText

function lib.stripWowColors(code)
   code = stringgsub(code, '||','\1')
   code = stringgsub(code, '|c%x%x%x%x%x%x%x%x','')
   code = stringgsub(code, '|r','')
   code = stringgsub(code, '\1', '||')
   return code
end

function lib.stripWowColorsWithPos(code, pos)
   code = stringinsert(code, pos, '\2')
   code = lib.stripWowColors(code)
   pos = stringfind(code, '\2', 1, 1)
   code = stringdelete(code, pos, pos)
   return code, pos
end

function lib.decode(code)
   return lib.stripWowColors(code)
end

function lib.encode(code)
   return code
end

-- returns the padded code, and true if modified, false if unmodified
local linebreak = stringbyte("\n")
function lib.padWithLinebreaks(code)
   local len = stringlen(code)
   if stringbyte(code, len) == linebreak then
      if stringbyte(code, len - 1) == linebreak then
         return code, false
      end
      return code .. "\n", true
   end
   return code .. "\n\n", true

end

local defaultTabWidth = 2
local defaultColorTable

-- Data tables
-- No weak table magic, since editboxes can never be removed in WoW
local enabled = {}
local dirty = {}

local editboxIndentCache = {}
local decodeCache = {}
local editboxStringCache = {}
local editboxNumLinesCache = {}

function lib.colorCodeEditbox(editbox)
   dirty[editbox] = nil

   local tabWidth = editbox.faiap_tabWidth

   local orgCode = editboxGetText(editbox)
   local prevCode = editboxStringCache[editbox]
   if prevCode == orgCode then
      return
   end

   local pos = editbox:GetCursorPosition()
   local code
   code, pos = lib.stripWowColorsWithPos(orgCode, pos)

   colorTable[0] = "|r"

   local newCode, newPos, numLines = lib.colorCodeCode(code, pos)
   newCode = lib.padWithLinebreaks(newCode)

   editboxStringCache[editbox] = newCode
   if orgCode ~= newCode then
      decodeCache[editbox] = nil
      local stringlenNewCode = stringlen(newCode)

      editboxSetText(editbox, newCode)
      if newPos then
         if newPos < 0 then newPos = 0 end
         if newPos > stringlenNewCode then newPos = stringlenNewCode end

         editbox:SetCursorPosition(newPos)
      end
   end

   if editboxNumLinesCache[editbox] ~= numLines then
      lib.indentEditbox(editbox)
   end
   editboxNumLinesCache[editbox] = numLines
end

function lib.indentEditbox(editbox)
   dirty[editbox] = nil

   local tabWidth = editbox.faiap_tabWidth

   local orgCode = editboxGetText(editbox)
   local prevCode = editboxIndentCache[editbox]
   if prevCode == orgCode then
      return
   end

   local pos = editbox:GetCursorPosition()

   local code
   code, pos = lib.stripWowColorsWithPos(orgCode, pos)

   colorTable[0] = "|r"
   local newCode, newPos = lib.indentCode(code, tabWidth, pos)
   newCode = lib.padWithLinebreaks(newCode)
   editboxIndentCache[editbox] = newCode
   if code ~= newCode then
      decodeCache[editbox] = nil

      local stringlenNewCode = stringlen(newCode)

      editboxSetText(editbox, newCode)

      if newPos then
         if newPos < 0 then newPos = 0 end
         if newPos > stringlenNewCode then newPos = stringlenNewCode end
         editbox:SetCursorPosition(newPos)
      end
   end
end

local function hookHandler(editbox, handler, newFun)
   local oldFun = editbox:GetScript(handler)
   if oldFun == newFun then
      -- already hooked, ignore it
      return
   end
   editbox["faiap_old_" .. handler] = oldFun
   editbox:SetScript(handler, newFun)
end

local function textChangedHook(editbox, ...)
   local oldFun = editbox["faiap_old_OnTextChanged"]
   if oldFun then
      oldFun(editbox, ...)
   end
   if enabled[editbox] then
      dirty[editbox] = GetTime()
   end
end

local function tabPressedHook(editbox, ...)
   local oldFun = editbox["faiap_old_OnTabPressed"]
   if oldFun then
      oldFun(editbox, ...)
   end
   if enabled[editbox] then
      return lib.indentEditbox(editbox)
   end
end

local function onUpdateHook(editbox, ...)
   local oldFun = editbox["faiap_old_OnUpdate"]
   if oldFun then
      oldFun(editbox, ...)
   end
   if enabled[editbox] then
      local now = GetTime()
      local lastUpdate = dirty[editbox] or now
      if now - lastUpdate > 0.2 then
         decodeCache[editbox] = nil
         return lib.colorCodeEditbox(editbox)
      end
   end
end

local function newGetText(editbox)
   local decoded = decodeCache[editbox]
   if not decoded then
      decoded = lib.decode(editboxGetText(editbox))
      decodeCache[editbox] = decoded
   end
   return decoded or ""
end

local function newSetText(editbox, text)
   decodeCache[editbox] = nil
   if text then
      local encoded = lib.encode(text)

      return editboxSetText(editbox, encoded)
   end
end

function lib.enable(editbox, tabWidth)
   if not editboxSetText then
      editboxSetText = editbox.SetText
      editboxGetText = editbox.GetText
   end

   local modified
   if editbox.faiap_tabWidth ~= tabWidth then
      editbox.faiap_tabWidth = tabWidth
      modified = true
   end

   if enabled[editbox] then
      if modified then
         lib.indentEditbox(editbox)
      end
      return
   end

   -- Editbox is possibly hooked, but disabled
   enabled[editbox] = true

   editbox.oldMaxBytes = editbox:GetMaxBytes()
   editbox.oldMaxLetters = editbox:GetMaxLetters()
   editbox:SetMaxBytes(0)
   editbox:SetMaxLetters(0)

   editbox.GetText = newGetText
   editbox.SetText = newSetText

   hookHandler(editbox, "OnTextChanged", textChangedHook)
   hookHandler(editbox, "OnTabPressed", tabPressedHook)      
   hookHandler(editbox, "OnUpdate", onUpdateHook)      

   lib.indentEditbox(editbox)
end

function lib.disable(editbox)
   if not enabled[editbox] then
      return
   end
   enabled[editbox] = nil

   -- revert settings for max bytes / letters
   editbox:SetMaxBytes(editbox.oldMaxBytes)
   editbox:SetMaxLetters(editbox.oldMaxLetters)

   -- try a real unhooking, if possible
   if editbox:GetScript("OnTextChanged") == textChangedHook then
      editbox:SetScript("OnTextChanged", editbox.faiap_old_OnTextChanged)
      editbox.faiap_old_OnTextChanged = nil
   end

   if editbox:GetScript("OnTabPressed") == tabPressedHook then
      editbox:SetScript("OnTabPressed", editbox.faiap_old_OnTabPressed)
      editbox.faiap_old_OnTabPressed = nil
   end

   if editbox:GetScript("OnUpdate") == onUpdateHook then
      editbox:SetScript("OnUpdate", editbox.faiap_old_OnUpdate)
      editbox.faiap_old_OnUpdate = nil
   end

   editbox.GetText = nil
   editbox.SetText = nil

   -- change the text back to unformatted
   local pos = editbox:GetCursorPosition()
   local code = editbox:GetText()
   code, pos =  lib.stripWowColorsWithPos(code, pos)
   editbox:SetText(code)
   editbox:SetCursorPosition(pos-1)

   -- clear caches
   editboxIndentCache[editbox] = nil
   decodeCache[editbox] = nil
   editboxStringCache[editbox] = nil
   editboxNumLinesCache[editbox] = nil
end

function lib.rawGetText(editbox)
   return editboxGetText(editbox)
end

function lib.rawSetText(editbox)
   return editboxSetText(editbox)
end
