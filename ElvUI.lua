if not AddOnSkins then return end
local AS = unpack(AddOnSkins)
if not AS:CheckAddOn('REHack') then return end

function AS:REHack()
  AS:SkinFrame(HackListFrame)
  AS:SkinFrame(HackEditFrame)
  AS:SkinCloseButton(HackListFrameClose)
  AS:SkinCloseButton(HackEditFrameClose)
  AS:SkinCheckBox(HackSearchName)
  AS:SkinCheckBox(HackSearchBody)
  AS:SkinEditBox(HackSearchEdit)
  AS:SkinScrollBar(HackEditScrollFrameScrollBar)
  AS:SkinTab(HackListFrameTab1)
  AS:SkinTab(HackListFrameTab2)
  HackEditBoxLineBG:SetColorTexture(0, 0, 0, 0.25)
end

AS:RegisterSkin('REHack', AS.REHack)
