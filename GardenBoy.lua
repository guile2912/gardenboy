-----------------------------------------------------------------------------------------------
-- Client Lua Script for GardenBoy
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
 --Recuperer la valeur potentiel d'une graine par rapport au prix de vente courrant du produit
 --Fonction qui renvoi les items ids drope par une plante, avec leur %, pour la zone sky 
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- GardenBoy Module Definition
-----------------------------------------------------------------------------------------------
local GardenBoy = {} 
local unitCache = {}
local KEY_ITEMS = "items"
local TYPE_HARVEST = 'Harvest'
local CommodityStats = {}
local computage


-- Price groups
CommodityStats.Pricegroup = {
    TOP1 = 1,
    TOP10 = 2,
    TOP50 = 3
}
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local SeedMapping = {}
SeedMapping[14182] = { plant = "Bladeleaf", mins = 30, produce = 14181 }
SeedMapping[15631] = { plant = "Bloodbriar", mins = 120, produce =  15630}
SeedMapping[15772] = { plant = "Coralscale", mins = 45, produce = 15771}
SeedMapping[15646] = { plant = "Crowncorn", mins = 35, produce = 14649 }
SeedMapping[15629] = { plant = "Faerybloom", mins = 65, produce = 15628 }
SeedMapping[15643] = { plant = "Flamefrond", mins = 60, produce = 15642 }
SeedMapping[15635] = { plant = "Glowmelon", mins = 55, produce = 15634 }
SeedMapping[15625] = { plant = "Goldleaf", mins = 40, produce = 15624 }
SeedMapping[15648] = { plant = "Grimgourd", mins = 80, produce = 15647 }
SeedMapping[15641] = { plant = "Heartichoke", mins = 105, produce = 15640}
SeedMapping[4687] = { plant = "Honeywheat", mins = 30, produce = 3908 }
SeedMapping[14204] = { plant = "Logicleaf", mins = 60, produce = 14203 }
SeedMapping[15633] = { plant = "Mourningstar", mins = 90, produce = 15632 }
SeedMapping[4685] = { plant = "Octopod", mins = 80, produce = 12815 }
SeedMapping[14616] = { plant = "Pummelgranate", mins = 25, produce = 14615 }
SeedMapping[14197] = { plant = "Serpentlily", mins = 35, produce = 14196 }
SeedMapping[4686] = { plant = "Spirovine", mins = 25, produce = 12816 }
SeedMapping[15483] = { plant = "Stoutroot", mins = 40, produce = 15482 }
SeedMapping[15627] = { plant = "Witherwood", mins = 90, produce = 15626 }
SeedMapping[14427] = { plant = "Yellowbell", mins = 20, produce = 14426 }

--local SeedMapping = { 14182 = { plant = "Bladeleaf", mins = 30, produce = 14181 }, 15631 = { plant = "Bloodbriar", mins = 120, produce =  15630}, 15772 = { plant = "Coralscale", mins = 45, produce = 15771},  15646 = { plant = "Crowncorn", mins = 35, produce = 14649 },  15629 = { plant = "Faerybloom", mins = 65, produce = 15628 },  15643 = { plant = "Flamefrond", mins = 60, produce = 15642 },  15635 = { plant = "Glowmelon", mins = 55, produce = 15634 },  15625 = { plant = "Goldleaf", mins = 40, produce = 15624 },   15648 = { plant = "Grimgourd", mins = 80, produce = 15647 },  15641 = { plant = "Heartichoke", mins = 105, produce = 15640},  4687 = { plant = "Honeywheat", mins = 30, produce = 3908 },  14204 = { plant = "Logicleaf", mins = 60, produce = 14203 },  15633 = { plant = "Mourningstar", mins = 90, produce = 15632 },  4685 = { plant = "Octopod", mins = 80, produce = 12815 },  14616 = { plant = "Pummelgranate", mins = 25, produce = 14615 },  14197 = { plant = "Serpentlily", mins = 35, produce = 14196 },  4686 = { plant = "Spirovine", mins = 25, produce = 12816 },  15483 = { plant = "Stoutroot", mins = 40, produce = 15482 },  15627 = { plant = "Witherwood", mins = 90, produce = 15626 },  14427 = { plant = "Yellowbell", mins = 20, produce = 14426 }}
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function GardenBoy:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	self.tSavedData = { -- saved data table
			REVISION = 0,
      VERSION = 1,
			[TYPE_HARVEST] = {},
			commodity = {}
		}
    
  self.currentLootTarget = nil -- current loot target
	self.nGameTime = nil -- time stamp in seconds
	self.tFactoryCache = {}
		
    return o
end

function GardenBoy:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		"MarketplaceCommodity",
        "Gemini:Logging-1.2"
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)

  Apollo.RegisterEventHandler("CommodityInfoResults", "OnCommodityInfoResults", self)

  --Apollo.RegisterEventHandler("CombatLogDamage", "OnCombatLogDamage", self)
  
	Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
	Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)
  Apollo.RegisterEventHandler("SubZoneChanged","OnSubZoneChanged", self)

end
 

-----------------------------------------------------------------------------------------------
-- GardenBoy OnLoad
-----------------------------------------------------------------------------------------------
function GardenBoy:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("GardenBoy.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end


-- save session data
function GardenBoy:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.General then return end
	self.tSavedData.REVISION = self.tSavedData.REVISION + 1
	return self.tSavedData
end

-- restore session data
function GardenBoy:OnRestore(eType, tSavedData)
	--if eType ~= GameLib.CodeEnumAddonSaveLevel.General then return end
	self.tSavedData = tSavedData or self.tSavedData
	
	-- create new session
	--if self.sSessionKey then
	--	self.tSavedData.tSessions[self.sSessionKey] = self.tSessionTable
	--else
	--	local sSessionKey, tSessionTable = self:CreateSession()
	--	self.tSavedData.tSessions[sSessionKey] = tSessionTable
	--	self.sSessionKey = sSessionKey
	--	self.tSessionTable = tSessionTable
	--end
end

-----------------------------------------------------------------------------------------------
-- GardenBoy OnDocLoaded
-----------------------------------------------------------------------------------------------
function GardenBoy:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "GardenBoyForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("gardenboy", "OnGardenBoyOn", self)
		Apollo.RegisterSlashCommand("gb", "OnGardenBoyOn", self)
    
    Apollo.RegisterSlashCommand("gbseed", "ComputeSeedPrice", self)
    Apollo.RegisterSlashCommand("gblow", "GetLowestCommodity", self)
    Apollo.RegisterSlashCommand("gbd", "GetBestDeltaCommodity", self)

		self.timer = ApolloTimer.Create(1.0, true, "OnTimer", self)

		-- Do additional Addon initialization here
		
	end
end

-----------------------------------------------------------------------------------------------
-- GardenBoy Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/gardenboy"
function GardenBoy:OnGardenBoyOn()

  self:GetLowestCommodity()
	self.wndMain:Invoke() -- show the window
  self:Redraw()
end

-- on timer
function GardenBoy:OnTimer()
	-- Do your timer-related stuff here.
end

--herbs 14181 15630 15771 29564 15628


---------------------------------------------------------------------------------------------------
-- GardenBoy Event Handlers
---------------------------------------------------------------------------------------------------

function GardenBoy:OnCommodityInfoResults(nItemId, tStats, tOrders)
  local item = Item.GetDataFromId(nItemId)
  --local iteminfo = item:GetDetailedInfo()
  local itemtype = item:GetItemType()


	--Print("Commodity info received for item ID " .. tostring(nItemId) .. "." .. tostring( itemtype ))
  
	--if itemtype == 213 or itemtype == 198 or itemtype == 221 or then --213 Seeds, 198 Herb, 221 produce
		--Print("Seed" )
    --save
    local stat = self:CreateCommodityStat(tStats)
    if stat.buyOrderCount ~= 0 or stat.sellOrderCount ~= 0 then
        if self.tSavedData['commodity'][nItemId]  == nil then
            self.tSavedData['commodity'][nItemId]  = {}
        end

        self.tSavedData['commodity'][nItemId] = stat
    end
	--end

end

function GardenBoy:GetLowestCommodity()

  computage = {}

  for nItemId, stat in pairs(self.tSavedData['commodity']) do 
    local item = Item.GetDataFromId(nItemId)
    local info=item:GetDetailedInfo().tPrimary
    
    if info.tCost and info.tCost.arMonSell then
      --self.tSavedData[KEY_ITEMS][id]["sold4"] = info.tCost.arMonSell[1]:GetAmount()
      --self.tSavedData[KEY_ITEMS][id]["soldc"]=info.tCost.arMonSell[1]:GetMoneyType()
      if self.tSavedData['commodity'][nItemId] then

        local rez = 0
        --if there is a buy order
        if self.tSavedData['commodity'][nItemId].buyPrices.top10 > 0 then
          local money = info.tCost.arMonSell[1]:GetAmount();
			local moneytype = info.tCost.arMonSell[1]:GetMoneyType()
			if moneytype  == 4 
			then 
			money = money * 100
			end
          rez = money  - self.tSavedData['commodity'][nItemId].buyPrices.top10 * 100
          
        end
        table.insert(computage, {nItemId, rez})
        
      --if rez > 500 then
      --      computage[nItemId] =    rez 
      --end
      
      end
	end
  
  end
  
  table.sort(computage, function(a,b) return a[2] > b[2] end)
 
  for i = 1, 5, 1 do
    local k = computage[i][1]
    local item2 = Item.GetDataFromId(k)
    Print(item2:GetName() .. ' each win ' .. tostring(computage[i][2]))
  end
 
	--for k, v in pairs(computage) do
	--    local item2 = Item.GetDataFromId( k)
	--	Print(item2:GetName() .. ' each win ' .. tostring(computage[k]))
		--info=item2:GetDetailedInfo().tPrimary
		--Print(tostring(info.tCost.arMonSell[1]:GetAmount()))
		--Print(tostring(info.tCost.arMonSell[1]:GetMoneyType()))
		
	--end


end

function GardenBoy:GetBestDeltaCommodity()

  computage = {}

  for nItemId, stat in pairs(self.tSavedData['commodity']) do 
	
	    local res = self.tSavedData['commodity'][nItemId].sellPrices.top10  - self.tSavedData['commodity'][nItemId].buyPrices.top10
	    local counts = self.tSavedData['commodity'][nItemId].buyOrderCount + self.tSavedData['commodity'][nItemId].sellOrderCount
		local percent = self.tSavedData['commodity'][nItemId].buyPrices.top10 * 100 / self.tSavedData['commodity'][nItemId].sellPrices.top10
	    local indice = res / counts
	    if res > 0 and self.tSavedData['commodity'][nItemId].sellOrderCount > 20 and percent > 30 and self.tSavedData['commodity'][nItemId].sellPrices.top10 < 100000 then
	    	table.insert(computage, {nItemId, res , indice, percent  })
	    end
	
  end
  
  
  table.sort(computage, function(a,b) return a[2] > b[2] end)
  --self.wndMain:Show()
  --self:Redraw()

  Print('-------')
  for i = 1, 10, 1 do
    local k = computage[i][1]
    local item2 = Item.GetDataFromId(k)
    Print(item2:GetName() .. ' each win ' .. tostring(computage[i][2]) .. ' (' .. tostring(computage[i][4]) ..'%)')
  end
end


--compute the seed prices
function GardenBoy:ComputeSeedPrice()
  computage = {}
  for nItemId, plant in pairs(SeedMapping) do 
local seedprice = 0
if self.tSavedData['commodity'][nItemId] then
    seedprice =  self.tSavedData['commodity'][nItemId].sellPrices.top10
else
Print('Not found ' .. tostring(nItemId))
end
    local produceprice =  self.tSavedData['commodity'][plant.produce].sellPrices.top10
    if seedprice and produceprice then
      	local benef = produceprice * 1.2 + seedprice * 0.4 - seedprice
		if benef > 0 then
          table.insert(computage, { nItemId, benef })
		end
		
	end

	--Print('Price ' .. tostring(seedprice) .. ' - ' .. tostring(produceprice ))

  end
  
  table.sort(computage, function(a,b) return a[2] > b[2] end)
  
    for i = 1, 5, 1 do
    local k = computage[i][1]
    local item2 = Item.GetDataFromId(k)
    Print(item2:GetName() .. ' each win ' .. tostring(computage[i][2]))
  end
      
end

function GardenBoy:generate_key_list(t)
    local keys = {}
	if t then
	    for k, v in pairs(t) do
	        keys[#keys+1] = k
	    end
	    return keys
	end
end

function GardenBoy:CreateCommodityStat(tStats)
    local stat = {}
    stat.buyOrderCount = tStats.nBuyOrderCount
    stat.sellOrderCount = tStats.nSellOrderCount
    stat.buyPrices = {}
    stat.buyPrices.top1 = tStats.arBuyOrderPrices[CommodityStats.Pricegroup.TOP1].monPrice:GetAmount()
    stat.buyPrices.top10 = tStats.arBuyOrderPrices[CommodityStats.Pricegroup.TOP10].monPrice:GetAmount()
    stat.buyPrices.top50 = tStats.arBuyOrderPrices[CommodityStats.Pricegroup.TOP50].monPrice:GetAmount()
    stat.sellPrices = {}
    stat.sellPrices.top1 = tStats.arSellOrderPrices[CommodityStats.Pricegroup.TOP1].monPrice:GetAmount()
    stat.sellPrices.top10 = tStats.arSellOrderPrices[CommodityStats.Pricegroup.TOP10].monPrice:GetAmount()
    stat.sellPrices.top50 = tStats.arSellOrderPrices[CommodityStats.Pricegroup.TOP50].monPrice:GetAmount()
    return stat
end

-- UnitCreated is used as a trigger for dropped loot
-- param unit <userdata> Item that was created
function GardenBoy:OnUnitCreated(unit)
  self:SetupInternals()
	if unit and unit:IsValid() and not unit:IsACharacter() then
		if unit:GetType() == "PinataLoot" then
			--droppedItems[unit:GetName()] = true
			local loot=unit:GetLoot()
			if loot then
				if loot.itemLoot then
					if loot.idOwner then
						if unitCache[loot.idOwner] then
							--self:AddCreature(unitCache[loot.idOwner],true)
							self:AddItem(loot,-1,unitCache[loot.idOwner],true)
						end
					end
				end
			end
		else
			unitCache[unit:GetId()] = unit
		end
	end
end


function GardenBoy:OnUnitDestroyed(unit)
  self:SetupInternals()
	if unit then
		if unit:GetType() == "PinataLoot" then
			local loot = unit:GetLoot()
			if loot then
				if loot.itemLoot then
-- save items looted by others too
--					if justLootedCache[loot.item:GetItemId()] then
					if loot.idOwner then
						if unitCache[loot.idOwner] then
							--self:AddCreature(unitCache[loot.idOwner],true)
							self:AddItem(loot ,-1,unitCache[loot.idOwner],true)
						else
							self:AddItem(loot ,-1,nil,true)
						end
					else
						self:AddItem(loot ,-1,nil,true)
					end
				end
			end
		end
	end
end 


function GardenBoy:OnSubZoneChanged(id,name)
	self:SetupInternals()
--	self:AddPathEpisode(PlayerPathLib.GetCurrentEpisode())

	--self:AddZone(self.tZone)

	unitCache = {}
	
	--self:SaveHousingStuff()
end






function GardenBoy:AddItem(tPinataLoot, questId, unit, bSaveSide, bIsRoot)
  local zoneid= self.tZone.id
  local item = tPinataLoot.itemLoot
  
  if unit then
    local sType = unit:GetType()
    if( sType  == TYPE_HARVEST and tPinataLoot.eLootItemType == 0 ) then
    
      local unitid = self:MakeCreatureId(unit)
      local nItemId = item:GetItemId()
		Print('Looted: '  .. tostring(tPinataLoot.nCount) .. 'x ' .. item:GetName() .. ' from ' .. unit:GetName() )

      local tUnit = self.tSavedData[TYPE_HARVEST][unitid]
      
      if tUnit == nil then
          tUnit = { kill = 1, items = {} }
        else
          tUnit.kill = tUnit.kill + 1
      end
    
      --set the loot
      local tUnitItem = tUnit.items[nItemId] or {
        nItemId = nItemId,
        nDropCount = 0,
        nMinDropCount = tPinataLoot.nCount,
        nMaxDropCount = tPinataLoot.nCount,
        nTotalDropCount = 0
      }
      tUnit.items[nItemId] = tUnitItem
      
      -- increment drop by 1, regardless of how many were dropped
      tUnitItem.nDropCount = tUnitItem.nDropCount + 1
      -- get drop min, max, total drop count
      tUnitItem.nMinDropCount = math.min(tUnitItem.nMinDropCount, tPinataLoot.nCount)
      tUnitItem.nMaxDropCount = math.max(tUnitItem.nMaxDropCount, tPinataLoot.nCount)
      tUnitItem.nTotalDropCount = tUnitItem.nTotalDropCount + tPinataLoot.nCount
          
      --save
      self.tSavedData[TYPE_HARVEST][unitid] = tUnit 
      
    end

  end
  
end

function GardenBoy:MakeCreatureId(unit)
	local n=unit:GetName()
	if n==nil or n=="" then
		n="Name not specified"
	end
	ret = self.tZone.id .. "/" .. n
	return ret
end

function GardenBoy:SetupInternals()
	self.tPlayer = GameLib.GetPlayerUnit()
	if self.tPlayer ~= nil then
		self.tPlayerFaction = self.tPlayer:GetFaction()
	end
	self.tZone=GameLib.GetCurrentZoneMap()
	if self.tZone==nil then
		self.tZone={
			id=0,
			strName="unspecified",
			continentId=0,
			strFolder="",
			fNorth=0,
			fEast=0,
			fSouth=0,
			fWest=0
		}
	end
end



-----------------------------------------------------------------------------------------------
-- GardenBoyForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function GardenBoy:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function GardenBoy:OnCancel()
	self.wndMain:Close() -- hide the window
end

--item : {nItemId,}
function GardenBoy:Redraw()
--	if not self.wndMain or not self.wndMain:IsShown() then
--Print("nothing here")
--		return
--	end

  for i = 1, 10, 1 do
    local nItemId = computage[i][1]
    local wndCurr = self:FactoryCacheProduce(self.wndMain:FindChild("MainSliderPanel"), "ListItem", "I" .. nItemId)
    local tCurrItem = Item.GetDataFromId(nItemId)
    wndCurr:FindChild("ListItemBtn"):SetData(tCurrItem)
    wndCurr:FindChild("ListItemTitle"):SetText(tCurrItem.strName)
    
    --icone
    if tCurrItem.eType == Item.CodeEnumLootItemType.StaticItem then
      wndCurr:FindChild("ListItemIcon"):GetWindowSubclass():SetItem(tCurrItem.itemData)
    else
      wndCurr:FindChild("ListItemIcon"):SetSprite(tCurrItem.strIcon)
    end
    
    local stat = self.tSavedData['commodity'][nItemId]
    
    --nombre d element a vendre
    wndCurr:FindChild("ListItemSellOrderCount"):SetText(stat.sellOrderCount)
    --wndCurr:FindChild("ListItemBuyOrderCount"):SetText(stat.buyOrderCount)
      
      
    -- Price
    --if monPrice and monPrice:GetMoneyType() ~= Money.CodeEnumCurrencyType.Credits then
    --  self.tAltCurrency = {}
    --  self.tAltCurrency.eMoneyType = monPrice:GetMoneyType()
    --  self.tAltCurrency.eAltType = monPrice:GetAltType()
    --end
    --if monPrice then
    --  wndCash:SetAmount(monPrice, true)
    --else
    --  wndCash:SetMoneySystem(Money.CodeEnumCurrencyType.Credits)
    --  wndCash:SetAmount(0, true)
    --end
    
    local monPrice = Money.new(Money.CodeEnumCurrencyType.Credits)
    
    --buy top1
	--	monPrice:SetAmount(stat.buyPrices.top1)
   -- wndCurr:FindChild("ListItemCashWindowBuyTop1"):SetAmount(monPrice, true)
    --buy top10
	--	monPrice:SetAmount(stat.buyPrices.top1)
   -- wndCurr:FindChild("ListItemCashWindowBuyTop10"):SetAmount(monPrice, true)
    --buy top50
	--	monPrice:SetAmount(stat.buyPrices.top1)
   -- wndCurr:FindChild("ListItemCashWindowBuyTop50"):SetAmount(monPrice, true)
    
    --sell top1
--		monPrice:SetAmount(stat.sellPrices.top1)
  --  wndCurr:FindChild("ListItemCashWindowSellTop1"):SetAmount(monPrice, true)
    --sell top10
--		monPrice:SetAmount(stat.sellPrices.top1)
  --  wndCurr:FindChild("ListItemCashWindowSellTop10"):SetAmount(monPrice, true)
    --sell top50
	--	monPrice:SetAmount(stat.sellPrices.top1)
  --  wndCurr:FindChild("ListItemCashWindowSellTop50"):SetAmount(monPrice, true)

    monPrice:SetAmount( stat.sellPrices.top10 - stat.buyPrices.top10)
    wndCurr:FindChild("ListItemCashWindowBenef"):SetAmount(monPrice, true)
      
  end
end

function GardenBoy:FactoryCacheProduce(wndParent, strFormName, strKey)
	local wnd = self.tFactoryCache[strKey]
	if not wnd or not wnd:IsValid() then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		self.tFactoryCache[strKey] = wnd
	end
	
	for idx=1,#self.tFactoryCache do
		if not self.tFactoryCache[idx]:IsValid() then
			self.tFactoryCache[idx] = nil
		end
	end
	
	return wnd
end


-----------------------------------------------------------------------------------------------
-- GardenBoy Instance
-----------------------------------------------------------------------------------------------
local GardenBoyInst = GardenBoy:new()
GardenBoyInst:Init()

----------------------
function GardenBoy :AssignLoot(loot)

  -- skip if unit is nil
	if self.currentLootTarget == nil then return nil end
  
  	-- get time difference
	local nTimeDiff = nil
	if self.nGameTime ~= nil then
		nTimeDiff = GameLib.GetGameTime()-self.nGameTime
	end
  
  if nTimeDiff ~= nil and nTimeDiff <= 1 and self.currentLootTarget then
  
  local tPinataLoot = loot:GetLoot()
  -- Static Item
	if tPinataLoot.eLootItemType == 0 then
      local itemLoot = tPinataLoot.itemLoot
      local nItemId = itemLoot:GetItemId()
      
      local sName = self.currentLootTarget:GetName()
      local tUnit = self.tSavedData.tUnits[sName]
      
      --add one kill
      if tUnit then
        tUnit.kill = tUnit.kill + 1
      else
        tUnit = { kill = 1, items = {} }
      end
      
      
      --set the loot
			local tUnitItem = tUnit.items[nItemId] or {
				nItemId = nItemId,
				nDropCount = 0,
				nMinDropCount = tPinataLoot.nCount,
				nMaxDropCount = tPinataLoot.nCount,
				nTotalDropCount = 0
			}
			tUnit.items[nItemId] = tUnitItem
      
      -- increment drop by 1, regardless of how many were dropped
			tUnitItem.nDropCount = tUnitItem.nDropCount + 1
			-- get drop min, max, total drop count
			tUnitItem.nMinDropCount = math.min(tUnitItem.nMinDropCount, tPinataLoot.nCount)
			tUnitItem.nMaxDropCount = math.max(tUnitItem.nMaxDropCount, tPinataLoot.nCount)
			tUnitItem.nTotalDropCount = tUnitItem.nTotalDropCount + tPinataLoot.nCount
          
      --save
      self.tSavedData.tUnits[sName] = tUnit 
      
      Print('Dead ' .. sName  .. ' (' .. tostring(tUnit.kill) .. ') dropped ' .. tostring(tPinataLoot.nCount) .. ' x ' .. loot:GetName() .. ' (id=' .. tostring(nItemId) .. ')' )
    end
    
  end

end

-- CombatDamageLog is a good way to monitor kills
function GardenBoy :OnCombatLogDamage(tEventArgs)
	-- something has been killed
	if tEventArgs.bTargetKilled then
		local unit = tEventArgs.unitTarget
		if not unit:IsACharacter() then
			-- set loot target and time stamp

			--Print('dead')
			local sName = unit:GetName()
			--local sclass = unit:GetClassId()
			local sType = unit:GetType()
			--local iId = unit:GetId()
			if( sType  == 'Harvest') then
      	self.currentLootTarget = unit
        self.nGameTime=GameLib.GetGameTime()	
Print('Dead detected')			
			end
		end
	end
end

--Honeywheat 3908, Seeds 4687
--Serpentlily 14196 , Seeds 14197
--Crowncorn 14649
