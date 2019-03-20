local _G = _G
local unpack = _G.unpack

if not _G.AddOnSkins then return end
local AS = unpack(_G.AddOnSkins)
if not AS:CheckAddOn('REHack') then return end

function AS:REHack()
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
  _G.HackEditBoxLineBG:SetColorTexture(0, 0, 0, 0.25)
end

AS:RegisterSkin('REHack', AS.REHack)
