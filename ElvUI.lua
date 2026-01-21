if not ElvUI then return end

local E = unpack(ElvUI)
local S = E:GetModule('Skins')

local function Skin_REHack()
  S:HandleFrame(HackListFrame)
  S:HandleFrame(HackEditFrame)
  S:HandleCloseButton(HackListFrameClose)
  S:HandleCloseButton(HackEditFrameClose)
  S:HandleCheckBox(HackSearchName)
  S:HandleCheckBox(HackSearchBody)
  S:HandleEditBox(HackSearchEdit)
  S:HandleScrollBar(HackEditScrollFrameScrollBar)
  S:HandleTab(HackListFrameTab1)
  S:HandleTab(HackListFrameTab2)
  HackEditBoxLineBG:SetColorTexture(0, 0, 0, 0.25)
end

S:AddCallbackForAddon('REHack', 'REHack', Skin_REHack)
