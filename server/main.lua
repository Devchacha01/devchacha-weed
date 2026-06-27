local VORPCore = exports.vorp_core:GetCore()

-- Callback: Check if player has a shovel
VORPCore.Callback.Register('devchacha-weed:server:hasShovel', function(source, cb)
    local count = exports.vorp_inventory:getItemCount(source, nil, Config.ShovelItem)
    cb(count and count >= 1)
end)

-- Callback: Check if player has a water bucket
VORPCore.Callback.Register('devchacha-weed:server:hasWaterBucket', function(source, cb)
    local count = exports.vorp_inventory:getItemCount(source, nil, Config.WaterItem)
    cb(count and count >= 1)
end)

-- Callback: Check if player has fertilizer
VORPCore.Callback.Register('devchacha-weed:server:hasFertilizer', function(source, cb)
    local count = exports.vorp_inventory:getItemCount(source, nil, Config.FertilizerItem)
    cb(count and count >= 1)
end)

-- Callback: Check if player has an empty bucket
VORPCore.Callback.Register('devchacha-weed:server:hasEmptyBucket', function(source, cb)
    local count = exports.vorp_inventory:getItemCount(source, nil, Config.EmptyBucketItem)
    cb(count and count >= 1)
end)

-- Callback: Get weed inventory for NPC selling
VORPCore.Callback.Register('devchacha-weed:server:getWeedInventory', function(source, cb)
    local availableItems = {}
    for _, strain in pairs(Config.Strains) do
        local trimmedCount = exports.vorp_inventory:getItemCount(source, nil, strain.items.trimmed)
        if trimmedCount and trimmedCount >= 1 then
            table.insert(availableItems, {
                name = strain.items.trimmed,
                label = strain.label .. ' Bud',
                type = 'trimmed',
                amount = trimmedCount
            })
        end
        local jointCount = exports.vorp_inventory:getItemCount(source, nil, strain.items.joint)
        if jointCount and jointCount >= 1 then
            table.insert(availableItems, {
                name = strain.items.joint,
                label = strain.label .. ' Joint',
                type = 'joint',
                amount = jointCount
            })
        end
    end
    cb(availableItems)
end)

-- Callback: Check processing requirements
VORPCore.Callback.Register('devchacha-weed:server:canProcess', function(source, cb, data)
    local type = data.type
    
    if type == 'roll' then
        local countPaper = exports.vorp_inventory:getItemCount(source, nil, 'rolling_paper')
        if not countPaper or countPaper < 1 then
            cb(false, "You need Rolling Paper!")
            return
        end
        
        for _, strain in pairs(Config.Strains) do
            local countTrimmed = exports.vorp_inventory:getItemCount(source, nil, strain.items.trimmed)
            if countTrimmed and countTrimmed >= 1 then
                cb(true)
                return
            end
        end
        cb(false, "You need trimmed buds to roll!")
        return
    end
    
    for _, strain in pairs(Config.Strains) do
        local requiredItem = nil
        if type == 'wash' then requiredItem = strain.items.leaf
        elseif type == 'dry' then requiredItem = strain.items.washed
        elseif type == 'trim' then requiredItem = strain.items.dried
        end
        
        if requiredItem then
            local count = exports.vorp_inventory:getItemCount(source, nil, requiredItem)
            if count and count >= 50 then
                cb(true)
                return
            end
        end
    end
    
    -- None of the strains had enough, find best message to show
    local bestLabel = nil
    for _, strain in pairs(Config.Strains) do
        local requiredItem = nil
        if type == 'wash' then requiredItem = strain.items.leaf
        elseif type == 'dry' then requiredItem = strain.items.washed
        elseif type == 'trim' then requiredItem = strain.items.dried
        end
        if requiredItem then
            local itemDB = exports.vorp_inventory:getItemDB(requiredItem)
            if itemDB and itemDB.label then bestLabel = itemDB.label end
            break
        end
    end
    cb(false, "You need 50x of any leaf type to process!")
end)

RegisterNetEvent('devchacha-weed:server:finishProcess', function(type)
    local src = source
    
    if type == 'roll' then
        for _, strain in pairs(Config.Strains) do
            local countTrimmed = exports.vorp_inventory:getItemCount(src, nil, strain.items.trimmed)
            if countTrimmed and countTrimmed >= 1 then
                local countPaper = exports.vorp_inventory:getItemCount(src, nil, 'rolling_paper')
                if countPaper and countPaper >= 1 then
                    exports.vorp_inventory:subItem(src, strain.items.trimmed, 1)
                    exports.vorp_inventory:subItem(src, 'rolling_paper', 1)
                    exports.vorp_inventory:addItem(src, strain.items.joint, 1)
                    
                    local jointLabel = strain.items.joint
                    local itemDB = exports.vorp_inventory:getItemDB(strain.items.joint)
                    if itemDB and itemDB.label then jointLabel = itemDB.label end
                    VORPCore.NotifyRightTip(src, 'Rolled 1x ' .. jointLabel, 4000)
                    return
                end
            end
        end
        return
    end
    
    for _, strain in pairs(Config.Strains) do
        local inputItem = nil
        local outputItem = nil
        
        if type == 'wash' then 
            inputItem = strain.items.leaf
            outputItem = strain.items.washed
        elseif type == 'dry' then 
            inputItem = strain.items.washed
            outputItem = strain.items.dried
        elseif type == 'trim' then 
            inputItem = strain.items.dried
            outputItem = strain.items.trimmed
        end
        
        if inputItem and outputItem then
            local count = exports.vorp_inventory:getItemCount(src, nil, inputItem)
            if count and count >= 50 then
                exports.vorp_inventory:subItem(src, inputItem, 50)
                local amount = math.random(46, 49)
                exports.vorp_inventory:addItem(src, outputItem, amount)
                VORPCore.NotifyRightTip(src, 'Processed 50x -> ' .. amount .. 'x Result', 4000)
                return
            end
        end
    end
end)

-- Buying Logic
RegisterNetEvent('devchacha-weed:server:buyItem', function(item, price, quantity)
    local src = source
    local Character = VORPCore.getUser(src).getUsedCharacter
    if not Character then return end
    
    local amount = quantity or 1
    
    if Character.money >= price then
        if item == 'wagon_rent' then
            Character.removeCurrency(0, price)
            TriggerClientEvent('devchacha-weed:client:spawnWagon', src)
            VORPCore.NotifyRightTip(src, 'Wagon rented! Check behind you.', 4000)
            return
        end

        Character.removeCurrency(0, price)
        if item == 'matches' then
            for i = 1, amount do
                exports.vorp_inventory:addItem(src, 'matches', 1, { uses = 20 })
            end
        else
            exports.vorp_inventory:addItem(src, item, amount)
        end
        VORPCore.NotifyRightTip(src, 'Bought ' .. amount .. 'x ' .. item, 4000)
    else
        VORPCore.NotifyRightTip(src, 'Not enough money', 4000)
    end
end)

-- Helper: Consume 1 match use
local function ConsumeMatch(src)
    if not Config.Smoking.requireMatches then return true end
    
    local matchItem = exports.vorp_inventory:getItemByName(src, 'matches')
    if not matchItem then return false end
    
    local metadata = matchItem:getMetadata() or {}
    local uses = metadata.uses or 20
    uses = uses - 1
    
    exports.vorp_inventory:subItem(src, 'matches', 1, metadata)
    
    if uses > 0 then
        exports.vorp_inventory:addItem(src, 'matches', 1, { uses = uses })
        VORPCore.NotifyRightTip(src, uses .. ' matches remaining', 4000)
    else
        VORPCore.NotifyRightTip(src, 'Match box is empty', 4000)
    end
    
    return true
end

-- Dynamic Selling Logic
RegisterNetEvent('devchacha-weed:server:sellDynamicItem', function(itemName, amount, price)
    local src = source
    local Character = VORPCore.getUser(src).getUsedCharacter
    if not Character then return end
    
    local count = exports.vorp_inventory:getItemCount(src, nil, itemName)
    if count and count >= amount then
        exports.vorp_inventory:subItem(src, itemName, amount)
        Character.addCurrency(0, price)
        
        local itemLabel = itemName
        local itemDB = exports.vorp_inventory:getItemDB(itemName)
        if itemDB and itemDB.label then itemLabel = itemDB.label end
        VORPCore.NotifyRightTip(src, 'Handed over ' .. amount .. 'x ' .. itemLabel .. '. Received $' .. price, 4000)
    else
        VORPCore.NotifyRightTip(src, 'Transaction failed. Item missing?', 4000)
    end
end)

-- Usable Placeables
exports.vorp_inventory:registerUsableItem('wash_barrel', function(data)
    exports.vorp_inventory:closeInventory(data.source)
    TriggerClientEvent('devchacha-weed:client:startPlacing', data.source, 'wash_barrel')
end)

exports.vorp_inventory:registerUsableItem('processing_table', function(data)
    exports.vorp_inventory:closeInventory(data.source)
    TriggerClientEvent('devchacha-weed:client:startPlacing', data.source, 'processing_table')
end)

-- Usable seeds
for strainName, strain in pairs(Config.Strains) do
    exports.vorp_inventory:registerUsableItem(strain.items.seed, function(data)
        exports.vorp_inventory:closeInventory(data.source)
        TriggerClientEvent('devchacha-weed:client:startPlanting', data.source, strainName)
    end)
end

-- Usable water bucket
exports.vorp_inventory:registerUsableItem(Config.WaterItem, function(data)
    exports.vorp_inventory:closeInventory(data.source)
    TriggerClientEvent('devchacha-weed:client:useWaterBucket', data.source)
end)

RegisterNetEvent('devchacha-weed:server:removeItem', function(item, count)
    local src = source
    exports.vorp_inventory:subItem(src, item, count)
end)

-- Give placeable back when picked up
RegisterNetEvent('devchacha-weed:server:givePlaceable', function(type)
    local src = source
    exports.vorp_inventory:addItem(src, type, 1)
end)

RegisterNetEvent('devchacha-weed:server:fillBucket', function()
    local src = source
    local countBucket = exports.vorp_inventory:getItemCount(src, nil, Config.EmptyBucketItem)
    if countBucket and countBucket >= 1 then
        exports.vorp_inventory:subItem(src, Config.EmptyBucketItem, 1)
        exports.vorp_inventory:addItem(src, Config.WaterItem, 1, { uses = Config.BucketUses })
    end
end)

-- Useable: Trimmed Buds -> Roll Joint (from inventory)
for strainKey, strain in pairs(Config.Strains) do
    exports.vorp_inventory:registerUsableItem(strain.items.trimmed, function(data)
        local src = data.source
        local countPaper = exports.vorp_inventory:getItemCount(src, nil, 'rolling_paper')
        if not countPaper or countPaper < 1 then
            VORPCore.NotifyRightTip(src, 'You need Rolling Paper!', 4000)
            return
        end
        exports.vorp_inventory:closeInventory(src)
        TriggerClientEvent('devchacha-weed:client:rollJoint', src, strainKey)
    end)
end

-- Finish Roll Joint
RegisterNetEvent('devchacha-weed:server:finishRollJoint', function(strainKey)
    local src = source
    local strain = Config.Strains[strainKey]
    if not strain then return end
    
    local countTrimmed = exports.vorp_inventory:getItemCount(src, nil, strain.items.trimmed)
    local countPaper = exports.vorp_inventory:getItemCount(src, nil, 'rolling_paper')
    
    if countTrimmed and countTrimmed >= 1 and countPaper and countPaper >= 1 then
        exports.vorp_inventory:subItem(src, strain.items.trimmed, 1)
        exports.vorp_inventory:subItem(src, 'rolling_paper', 1)
        exports.vorp_inventory:addItem(src, strain.items.joint, 1)
        
        local jointLabel = strain.items.joint
        local itemDB = exports.vorp_inventory:getItemDB(strain.items.joint)
        if itemDB and itemDB.label then jointLabel = itemDB.label end
        VORPCore.NotifyRightTip(src, 'Rolled 1x ' .. jointLabel, 4000)
    end
end)

-- Usable: Joints -> Smoke
for strainKey, strain in pairs(Config.Strains) do
    exports.vorp_inventory:registerUsableItem(strain.items.joint, function(data)
        local src = data.source
        if Config.Smoking.requireMatches then
            local countMatches = exports.vorp_inventory:getItemCount(src, nil, 'matches')
            if not countMatches or countMatches < 1 then
                VORPCore.NotifyRightTip(src, 'You need Matches to light!', 4000)
                return
            end
        end
        exports.vorp_inventory:closeInventory(src)
        TriggerClientEvent('devchacha-weed:client:smokeJoint', src, strainKey)
    end)
end

-- Finish Smoke Joint
RegisterNetEvent('devchacha-weed:server:finishSmokeJoint', function(strainKey)
    local src = source
    local strain = Config.Strains[strainKey]
    if not strain then return end
    
    local countJoint = exports.vorp_inventory:getItemCount(src, nil, strain.items.joint)
    if countJoint and countJoint >= 1 then
        ConsumeMatch(src)
        exports.vorp_inventory:subItem(src, strain.items.joint, 1)
        TriggerClientEvent('devchacha-weed:client:applySmokingBoost', src, 'joint')
        VORPCore.NotifyRightTip(src, 'You smoked a ' .. strain.label .. ' Joint', 4000)
    end
end)

-- Useable: Smoking Pipe -> Auto load if bud is owned
exports.vorp_inventory:registerUsableItem('smoking_pipe', function(data)
    local src = data.source
    local countPipe = exports.vorp_inventory:getItemCount(src, nil, 'smoking_pipe')
    if not countPipe or countPipe < 1 then
        VORPCore.NotifyRightTip(src, 'You need a Smoking Pipe!', 4000)
        return
    end
    for strainKey, strain in pairs(Config.Strains) do
        local countTrimmed = exports.vorp_inventory:getItemCount(src, nil, strain.items.trimmed)
        if countTrimmed and countTrimmed >= 1 then
            exports.vorp_inventory:closeInventory(src)
            TriggerClientEvent('devchacha-weed:client:loadPipe', src, strainKey)
            return
        end
    end
    VORPCore.NotifyRightTip(src, 'You need weed bud to load the pipe!', 4000)
end)

-- Finish loading pipe
RegisterNetEvent('devchacha-weed:server:finishLoadPipe', function(strainKey)
    local src = source
    local countPipe = exports.vorp_inventory:getItemCount(src, nil, 'smoking_pipe')
    local countTrimmed = exports.vorp_inventory:getItemCount(src, nil, Config.Strains[strainKey].items.trimmed)
    
    if countPipe and countPipe >= 1 and countTrimmed and countTrimmed >= 1 then
        exports.vorp_inventory:subItem(src, 'smoking_pipe', 1)
        exports.vorp_inventory:subItem(src, Config.Strains[strainKey].items.trimmed, 1)
        
        local loadedPipeName = 'loaded_pipe_' .. strainKey
        exports.vorp_inventory:addItem(src, loadedPipeName, 1, { puffs = Config.Smoking.pipePuffs, strain = strainKey })
        VORPCore.NotifyRightTip(src, 'Loaded pipe with ' .. Config.Strains[strainKey].label, 4000)
    end
end)

-- Useable: Loaded Pipes -> Smoke
for strainKey, strain in pairs(Config.Strains) do
    local loadedPipeName = 'loaded_pipe_' .. strainKey
    exports.vorp_inventory:registerUsableItem(loadedPipeName, function(data)
        local src = data.source
        if Config.Smoking.requireMatches then
            local countMatches = exports.vorp_inventory:getItemCount(src, nil, 'matches')
            if not countMatches or countMatches < 1 then
                VORPCore.NotifyRightTip(src, 'You need Matches to light!', 4000)
                return
            end
        end
        
        local metadata = data.item.metadata or {}
        local puffs = metadata.puffs or Config.Smoking.pipePuffs
        
        exports.vorp_inventory:closeInventory(src)
        TriggerClientEvent('devchacha-weed:client:smokePipe', src, strainKey, puffs)
    end)
end

-- Finish Smoke Pipe
RegisterNetEvent('devchacha-weed:server:finishSmokePipe', function(strainKey)
    local src = source
    local loadedPipeName = 'loaded_pipe_' .. strainKey
    
    local pipeItem = exports.vorp_inventory:getItemByName(src, loadedPipeName)
    if not pipeItem then return end
    
    local metadata = pipeItem:getMetadata() or {}
    local puffs = metadata.puffs or Config.Smoking.pipePuffs
    puffs = puffs - 1
    
    exports.vorp_inventory:subItem(src, loadedPipeName, 1, metadata)
    
    if puffs > 0 then
        exports.vorp_inventory:addItem(src, loadedPipeName, 1, { puffs = puffs, strain = strainKey })
        VORPCore.NotifyRightTip(src, puffs .. ' puffs remaining', 4000)
    else
        exports.vorp_inventory:addItem(src, 'smoking_pipe', 1)
        VORPCore.NotifyRightTip(src, 'Pipe is empty', 4000)
    end
    
    TriggerClientEvent('devchacha-weed:client:applySmokingBoost', src, 'pipe')
end)

-- Law Enforcement Alerts
RegisterNetEvent('devchacha-weed:server:alertLaw', function(coords, locationName)
    local src = source
    if not Config.PoliceAlerts.enabled then return end

    local users = VORPCore.getUsers()
    for _, user in pairs(users) do
        local Character = user.getUsedCharacter
        if Character then
            local job = Character.job
            for _, alertJob in ipairs(Config.PoliceAlerts.jobs) do
                if job == alertJob then
                    local title = 'Drug Sale Reported'
                    local description = 'A suspicious individual was seen selling drugs in ' .. locationName
                    
                    if locationName == 'Large Illegal Farm Detected' then
                        title = 'Illegal Cultivation Reported'
                        description = 'Reports of a large illegal farm operation in the area!'
                    end
                    
                    TriggerClientEvent('vorp:NotifyLeft', Character.source, title, description, "generic_textures", "tick", 10000, "COLOR_RED")
                    
                    if Config.PoliceAlerts.blip.enabled then
                        TriggerClientEvent('devchacha-weed:client:policeBlip', Character.source, coords)
                    end
                end
            end
        end
    end
end)
