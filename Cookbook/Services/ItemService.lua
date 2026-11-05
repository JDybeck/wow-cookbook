-- ItemService: item names, icons, quality colors, bag counts, links, tooltips and money.
-- Reads the bundled data first so the UI never waits on the server item cache.
local _, ns = ...

local ItemService = {}
ns.ItemService = ItemService

local FALLBACK_ICON = 134400 -- INV_Misc_QuestionMark

local QUALITY_COLORS = {
    [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd",
    [4] = "a335ee", [5] = "ff8000", [6] = "e6cc80", [7] = "00ccff",
}

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

--- Returns name, quality, icon, sellPrice.
function ItemService:Get(itemID)
    local row = ns.Data.items[itemID]
    if row then
        return row[1], row[2], row[3], row[4]
    end
    local name, _, quality, _, _, _, _, _, _, icon, sellPrice = GetItemInfo(itemID)
    return name or ("Item #" .. itemID), quality or 1, icon or FALLBACK_ICON, sellPrice or 0
end

function ItemService:GetName(itemID)
    return (self:Get(itemID))
end

function ItemService:GetIcon(itemID)
    local _, _, icon = self:Get(itemID)
    return icon ~= 0 and icon or FALLBACK_ICON
end

function ItemService:GetSellPrice(itemID)
    local _, _, _, sellPrice = self:Get(itemID)
    return sellPrice or 0
end

function ItemService:GetQualityHex(itemID)
    local _, quality = self:Get(itemID)
    return QUALITY_COLORS[quality] or "ffffff"
end

function ItemService:GetColoredName(itemID)
    return "|cff" .. self:GetQualityHex(itemID) .. self:GetName(itemID) .. "|r"
end

--- Count in bags and bank.
function ItemService:GetCount(itemID)
    if not GetItemCount then
        return 0
    end
    return GetItemCount(itemID, true) or 0
end

function ItemService:GetLink(itemID)
    local _, link = GetItemInfo(itemID)
    return link
end

function ItemService:InsertLink(link)
    local insert = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
    if link and insert then
        insert(link)
    end
end

function ItemService:ShowTooltip(owner, itemID)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(itemID)
    GameTooltip:Show()
end

function ItemService:FormatMoney(copper)
    if not copper or copper <= 0 then
        return "|cff808080none|r"
    end
    if GetMoneyString then
        return GetMoneyString(copper, true)
    end
    local gold = floor(copper / 10000)
    local silver = floor((copper % 10000) / 100)
    local rest = copper % 100
    return ("%dg %ds %dc"):format(gold, silver, rest)
end
