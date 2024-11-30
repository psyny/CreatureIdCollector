-- CreatureIdCollectorRegistry.lua

CreatureIdCollectorRegistry = {}

function CreatureIdCollectorRegistry:RegisterCreature(creatureData)
    if not creatureData.name then
        return
    end

    if not CreatureIdCollectorDB then
        CreatureIdCollectorDB = {}
    end

    local creatureDb = CreatureIdCollectorDB[creatureData.name]
    if not creatureDb then
        -- Create Creature Registry on Database
        creatureDb = {
            name = creatureData.name,
            world = {},
            instance = {},    
        }
        CreatureIdCollectorDB[creatureData.name] = creatureDb
    end

    -- Instance vs World
    local phase = "world"
    if creatureData.isInstance then
        phase = "instance"
    end

    local creatureDbPhase = creatureDb[phase]
    if not creatureDbPhase then
        creatureDbPhase = {}
        creatureDb[phase] = creatureDbPhase
    end

    -- Classification
    local classification = "none"
    if creatureData.classification then
        classification = creatureData.classification
    end

    local creatureDbClass = creatureDbPhase[classification]
    if not creatureDbClass then
        creatureDbClass = {}
        creatureDbPhase[classification] = creatureDbClass
    end

    --  Zone
    local zoneId = 0
    if creatureData.zoneId then
        zoneId = creatureData.zoneId
    end

    local creatureDbZone = creatureDbClass[zoneId]
    if not creatureDbZone then
        creatureDbZone = {
            dids = {},
            nids = {},
        }
        creatureDbClass[zoneId] = creatureDbZone
    end

    -- Data    
    if creatureData.npcId then
        creatureDbZone.nids[creatureData.npcId] = 1
    end

    if creatureData.displayId then
        creatureDbZone.dids[creatureData.displayId] = 1
    end    
end