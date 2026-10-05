-- CreatureIdCollectorRegistry.lua

-- Structure:
--     CreatureIdCollectorDB[name][gameVersion] = {
--         name = name,
--         world | instance = {                -- from IsInInstance()
--             [classification] = {
--                 [zoneId] = {                -- C_Map.GetBestMapForUnit("player"), 0 if nil
--                     nids = { [npcId] = 1 },
--                     dids = { [displayId] = 1 },
--                 },
--             },
--         },
--     }
-- gameVersion is the version string from GetBuildInfo(), e.g. "12.0.1"

CreatureIdCollectorRegistry = {}

local GAME_VERSION = (GetBuildInfo())

-- Records saved before game versions were tracked are moved under this key
local LEGACY_VERSION = "legacy"

local isMigrated = false

-- Old records were CreatureIdCollectorDB[name] = { name, world, instance }
local function IsLegacyRecord(creatureDb)
    return type(creatureDb.name) == "string" and (type(creatureDb.world) == "table" or type(creatureDb.instance) == "table")
end

local function MigrateLegacyRecords()
    isMigrated = true

    for name, creatureDb in pairs(CreatureIdCollectorDB) do
        if type(creatureDb) == "table" and IsLegacyRecord(creatureDb) then
            CreatureIdCollectorDB[name] = {
                [LEGACY_VERSION] = creatureDb,
            }
        end
    end
end

function CreatureIdCollectorRegistry:RegisterCreature(creatureData)
    if issecretvalue and issecretvalue(creatureData.name) then
        return
    end

    if not creatureData.name then
        return
    end

    if not CreatureIdCollectorDB then
        CreatureIdCollectorDB = {}
    end

    if not isMigrated then
        MigrateLegacyRecords()
    end

    local creatureDbByVersion = CreatureIdCollectorDB[creatureData.name]
    if not creatureDbByVersion then
        creatureDbByVersion = {}
        CreatureIdCollectorDB[creatureData.name] = creatureDbByVersion
    end

    local creatureDb = creatureDbByVersion[GAME_VERSION]
    if not creatureDb then
        -- Create Creature Registry on Database
        creatureDb = {
            name = creatureData.name,
            world = {},
            instance = {},
        }
        creatureDbByVersion[GAME_VERSION] = creatureDb
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
