local VORPCore = exports.vorp_core:GetCore()

-- Load plants & Schema Check
CreateThread(function()
    -- Check/Add fertilized column
    local checkFert = MySQL.scalar.await("SELECT count(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'rsg_weed_plants' AND column_name = 'fertilized'")
    if checkFert == 0 then
        MySQL.query('ALTER TABLE rsg_weed_plants ADD COLUMN fertilized INT DEFAULT 0')
        print('^3[devchacha-weed] Added initialized fertilized column to rsg_weed_plants^7')
    end

    -- Check/Add updated_at column
    local checkUpdated = MySQL.scalar.await("SELECT count(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'rsg_weed_plants' AND column_name = 'updated_at'")
    if checkUpdated == 0 then
        MySQL.query('ALTER TABLE rsg_weed_plants ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP')
        print('^3[devchacha-weed] Added initialized updated_at column to rsg_weed_plants^7')
    end

    -- Check/Add charid column (VORP character ID identifier)
    local checkOwner = MySQL.scalar.await("SELECT count(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'rsg_weed_plants' AND column_name = 'charid'")
    if checkOwner == 0 then
        MySQL.query('ALTER TABLE rsg_weed_plants ADD COLUMN charid INT DEFAULT NULL')
        print('^3[devchacha-weed] Added initialized charid column to rsg_weed_plants^7')
    end

    local success, result = pcall(MySQL.query.await, 'SELECT * FROM rsg_weed_plants')
    if success and result then
        for _, plant in ipairs(result) do
            plant.coords = json.decode(plant.coords)
            plant.stage = plant.stage or 1
            plant.growth = plant.growth or 0
            plant.water = plant.water or 100
            plant.fertilized = plant.fertilized or 0
            TriggerClientEvent('devchacha-weed:client:spawnPlant', -1, plant)
        end
    else
        print('^1[devchacha-weed] Error loading plants or table empty^7')
    end
end)

-- Sync on Player Character Selected
AddEventHandler('vorp:SelectedCharacter', function(source, character)
    local src = source
    MySQL.query('SELECT * FROM rsg_weed_plants', {}, function(plants)
        if plants then
            for _, plant in ipairs(plants) do
                plant.coords = json.decode(plant.coords)
                plant.stage = plant.stage or 1
                plant.growth = plant.growth or 0.0
                plant.water = plant.water or 100.0
                
                TriggerClientEvent('devchacha-weed:client:spawnPlant', src, plant)
            end
        end
    end)
end)

-- Save new plant
RegisterNetEvent('devchacha-weed:server:savePlant', function(coords, strain)
    local src = source
    local Character = VORPCore.getUser(src).getUsedCharacter
    if not Character then return end

    local seedItem = Config.Strains[strain].items.seed

    local count = exports.vorp_inventory:getItemCount(src, nil, seedItem)
    if count and count >= 1 then
        exports.vorp_inventory:subItem(src, seedItem, 1)
        
        local coordsTable = { x = coords.x, y = coords.y, z = coords.z, w = coords.w or 0.0 }
        local charid = Character.charIdentifier

        MySQL.insert('INSERT INTO rsg_weed_plants (coords, strain, water, growth, stage, fertilized, updated_at, charid) VALUES (?, ?, 0, 0, 1, 0, NOW(), ?)', { json.encode(coordsTable), strain, charid }, function(id)
            if not id then return print('^1[devchacha-weed] Failed to save plant to DB^7') end
            
            MySQL.scalar('SELECT count(*) FROM rsg_weed_plants WHERE charid = ?', { charid }, function(count)
                if count and count > 20 then
                    TriggerEvent('devchacha-weed:server:alertLaw', coordsTable, 'Large Illegal Farm Detected')
                end
            end)

            local plant = {
                id = id,
                strain = strain,
                coords = coordsTable,
                stage = 1,
                water = 0.0,
                growth = 0.0,
                fertilized = 0,
                charid = charid
            }
            TriggerClientEvent('devchacha-weed:client:spawnPlant', -1, plant)
        end)
    end
end)

-- Growth Loop
CreateThread(function()
    while true do
        Wait(60000)
        MySQL.query('SELECT * FROM rsg_weed_plants', {}, function(plants)
            if plants then
                local batchUpdates = {}
                for _, plant in ipairs(plants) do
                    local newWater = plant.water - Config.WaterRate
                    if newWater < 0 then newWater = 0 end
                    
                    local newGrowth = plant.growth
                    local newQuality = plant.quality or 100
                    
                    if plant.water > 0 then
                        newGrowth = plant.growth + (100 / Config.GrowthTime)
                    else
                        newQuality = newQuality - 1
                        if newQuality < 0 then newQuality = 0 end
                    end
                    
                    if newQuality <= 0 then
                        MySQL.update('DELETE FROM rsg_weed_plants WHERE id = ?', { plant.id })
                        TriggerClientEvent('devchacha-weed:client:removePlant', -1, plant.id)
                        print('^1[devchacha-weed] Plant ' .. plant.id .. ' died from neglect and was removed.^7')
                    else
                        if newGrowth > 100 then newGrowth = 100 end

                        local newStage = 1
                        if newGrowth >= 33.0 then newStage = 2 end
                        if newGrowth >= 66.0 then newStage = 3 end
                        
                        if newStage ~= plant.stage or math.floor(newGrowth) ~= math.floor(plant.growth) or math.floor(newWater) ~= math.floor(plant.water) or newQuality ~= (plant.quality or 100) then
                             MySQL.update('UPDATE rsg_weed_plants SET growth = ?, water = ?, stage = ?, quality = ?, updated_at = NOW() WHERE id = ?', { newGrowth, newWater, newStage, newQuality, plant.id })
                             
                             plant.growth = newGrowth
                             plant.water = newWater
                             plant.stage = newStage
                             plant.quality = newQuality
                             plant.coords = json.decode(plant.coords)
                             
                             table.insert(batchUpdates, plant)
                        end
                    end
                end
                
                if #batchUpdates > 0 then
                    TriggerClientEvent('devchacha-weed:client:updatePlantsBatch', -1, batchUpdates)
                end
            end
        end)
    end
end)

RegisterNetEvent('devchacha-weed:server:syncAll', function()
    MySQL.query('SELECT * FROM rsg_weed_plants', {}, function(plants)
        if plants then
             local ids = {}
             for _, p in ipairs(plants) do ids[p.id] = true end
             TriggerClientEvent('devchacha-weed:client:cleanupPlants', -1, ids)
        end
    end)
end)

-- Harvest / Destroy
RegisterNetEvent('devchacha-weed:server:deletePlant', function(plantId, actionType)
    local src = source
    
    MySQL.query('SELECT strain, fertilized FROM rsg_weed_plants WHERE id = ?', { plantId }, function(result)
        if result and result[1] then
            local strain = result[1].strain
            local fertilized = result[1].fertilized
            
            MySQL.update('DELETE FROM rsg_weed_plants WHERE id = ?', { plantId }, function(affectedRows)
                if affectedRows > 0 then
                     TriggerClientEvent('devchacha-weed:client:removePlant', -1, plantId)
                     
                     if actionType == 'harvest' then
                         local amount = math.random(Config.HarvestAmount.min, Config.HarvestAmount.max)
                         if fertilized and fertilized == 1 then
                             amount = math.floor(amount * 1.5)
                         end
                         
                         local leafItem = Config.Strains[strain].items.leaf
                         exports.vorp_inventory:addItem(src, leafItem, amount)
                         VORPCore.NotifyRightTip(src, 'Harvested ' .. amount .. 'x weed', 4000)
                     else
                         VORPCore.NotifyRightTip(src, 'Plant destroyed', 4000)
                     end
                end
            end)
        end
    end)
end)

-- Callbacks for Plant Interaction
VORPCore.Callback.Register('devchacha-weed:server:waterPlant', function(source, cb, plantId)
    local src = source
    
    local firstBucket = exports.vorp_inventory:getItemByName(src, Config.WaterItem)
    if firstBucket then
        local metadata = firstBucket.metadata or {}
        local uses = metadata.uses or Config.BucketUses
        uses = uses - 1
        
        exports.vorp_inventory:subItemById(src, firstBucket.id, nil, nil, 1)
        
        if uses <= 0 then
            exports.vorp_inventory:addItem(src, Config.EmptyBucketItem, 1)
        else
            exports.vorp_inventory:addItem(src, Config.WaterItem, 1, { uses = uses })
        end

        MySQL.query('SELECT * FROM rsg_weed_plants WHERE id = ?', { plantId }, function(result)
            if result and result[1] then
                if result[1].water >= 100 then
                    cb({ success = false, msg = 'Plant is already fully watered!' })
                    return
                end

                local newWater = math.min(100.0, result[1].water + 50.0)
                MySQL.update('UPDATE rsg_weed_plants SET water = ?, updated_at = NOW() WHERE id = ?', { newWater, plantId })
                
                local plant = result[1]
                plant.water = newWater
                plant.coords = json.decode(plant.coords)
                plant.growth = plant.growth or 0.0
                TriggerClientEvent('devchacha-weed:client:updatePlant', -1, plant)
                
                cb({ success = true, usesLeft = uses })
            else
                cb({ success = false, msg = 'Plant not found' })
            end
        end)
    else
        cb({ success = false, msg = 'You need water!' })
    end
end)

VORPCore.Callback.Register('devchacha-weed:server:fertilizePlant', function(source, cb, plantId)
    local src = source
    
    local count = exports.vorp_inventory:getItemCount(src, nil, Config.FertilizerItem)
    if not count or count < 1 then
        cb({ success = false, msg = 'You need fertilizer!' })
        return
    end
    
    MySQL.query('SELECT * FROM rsg_weed_plants WHERE id = ?', { plantId }, function(result)
        if result and result[1] then
            if result[1].fertilized == 1 then
                cb({ success = false, msg = 'Already fertilized!' })
                return
            end
            
            if result[1].growth >= 99 then
                cb({ success = false, msg = 'Plant is fully grown!' })
                return
            end
            
            exports.vorp_inventory:subItem(src, Config.FertilizerItem, 1)

            local newGrowth = math.min(100.0, result[1].growth + 10.0)
            MySQL.update('UPDATE rsg_weed_plants SET growth = ?, fertilized = 1, updated_at = NOW() WHERE id = ?', { newGrowth, plantId })
            
            local plant = result[1]
            plant.growth = newGrowth
            plant.fertilized = 1
            plant.coords = json.decode(plant.coords)
            TriggerClientEvent('devchacha-weed:client:updatePlant', -1, plant)
            
            cb({ success = true })
        else
            cb({ success = false, msg = 'Plant not found' })
        end
    end)
end)
