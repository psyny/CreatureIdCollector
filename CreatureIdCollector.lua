-- CreatureIdCollector.lua

CreatureIdCollector = {}

local frame = CreateFrame("Frame")

-- Register events

-- Update
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("TALKINGHEAD_REQUESTED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        CreatureIdCollector:HandleNameplateAdded(...)    
    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        CreatureIdCollector:HandleBossAppearance(...)
    elseif event == "PLAYER_TARGET_CHANGED" then
        CreatureIdCollector:HandleTargetChange(...)     
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        CreatureIdCollector:HandleMouseoverChange(...)  
    elseif event == "TALKINGHEAD_REQUESTED" then
        CreatureIdCollector:HandleTalkingHead(...)             
    end
end)

local function StringStartsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

local avoidSoftGroupTokenAdd = {
    ["mou"] = true,
    ["tar"] = true,
    ["nam"] = true,
    ["npc"] = true,
}

function CreatureIdCollector:FindUnitToken(unitName)
    -- Check the player
    local unittokenname = self:GetUnitTokenFullName("player")    
    if unittokenname == unitName then
        return "player"
    end

    -- Check the target
    local unittokenname = self:GetUnitTokenFullName("target")    
    if unittokenname == unitName then
        return "target"
    end    

    -- Check the party members
    if IsInRaid() then
        -- Look for 
        for i = 1, GetNumGroupMembers() do
            local unittoken = "raid" .. i
            local unittokenname = self:GetUnitTokenFullName(unittokenname)
            if unittokenname == unitName then
                return unittoken
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unittoken = "party" .. i
            local unittokenname = self:GetUnitTokenFullName(unittokenname)
            if unittokenname == unitName then
                return unittoken
            end
        end
    end

    -- Check the nameplates
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        if nameplate.UnitFrame then
            local unittoken = nameplate.UnitFrame.unit
            local unittokenname = self:GetUnitTokenFullName(unittoken)
            if unittokenname == unitName then
                return unittoken
            end
        end
    end

    return nil
end


function CreatureIdCollector:GetUnitTokenFullName(unitToken)
    local creatureName, creatureServer = UnitName(unitToken)

    if not UnitIsPlayer(unitToken) then
        return creatureName
    end

    if not creatureServer then
        creatureServer = GetRealmName()
    end
    
    creatureName = creatureName .. "-" .. creatureServer
    return creatureName
end


function CreatureIdCollector:SetCreatureDataOfToken(unittoken)
    -- Check if the target is an NPC
    if UnitExists(unittoken) then
        local creatureName, creatureServer = UnitName(unittoken)
        if not UnitIsPlayer(unittoken) then     
            -- Get GUID and creatureID
            local guid = UnitGUID(unittoken)
            local npcId = nil
            if guid then
                npcId = tonumber(guid:match("[Creature|Vehicle|Pet|Vignette|Instance]%-.-%-.-%-.-%-.-%-(%d+)"))
            end

            local zoneId = C_Map.GetBestMapForUnit("player")
            local inInstance, instanceType = IsInInstance()
            local classification = "boss"

            if not StringStartsWith(unittoken, "boss") then
                classification = UnitClassification(unittoken)
            end

            local isInGroup = UnitCanCooperate("player", unittoken)
            if isInGroup then
                if avoidSoftGroupTokenAdd[string.sub(unittoken, 1, 3)] then
                    classification = "softgroup"
                end
            end            

            local creatureData = {
                name = creatureName,
                npcId = npcId,
                displayId = nil,
                classification = classification,
                zoneId = zoneId,
                isInstance = inInstance,
            }
            CreatureIdCollectorRegistry:RegisterCreature(creatureData)            
        end
    end
end


-- Handle nameplate addition to update creatureIdMap
function CreatureIdCollector:HandleNameplateAdded(unitToken)
    self:SetCreatureDataOfToken(unitToken)
end

-- Handle the appearance of the new boss
function CreatureIdCollector:HandleBossAppearance()
    -- Iterate over all potential boss frames (boss1, boss2, etc.)
    for i = 1, MAX_BOSS_FRAMES do
        -- Get the GUID of the boss unit (if available)
        local unitToken = "boss" .. i
        self:SetCreatureDataOfToken(unitToken)
    end
end

-- Handle the target change
function CreatureIdCollector:HandleTargetChange()
    self:SetCreatureDataOfToken("target")
end

-- Handle the mouseover change
function CreatureIdCollector:HandleMouseoverChange()
    self:SetCreatureDataOfToken("mouseover")
end

-- Handle the roster change (party or raid changes)
function CreatureIdCollector:HandleRosterChange()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unittoken = "raid" .. i
            self:SetCreatureDataOfToken(unittoken)
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unittoken = "party" .. i
            self:SetCreatureDataOfToken(unittoken)
        end
    end
end

-- Handle talking head appearance
function CreatureIdCollector:HandleTalkingHead()
    self:HandleTalkingHeadAux()
    C_Timer.After(0.1, function() CreatureIdCollector:HandleTalkingHeadAux() end)  
end

function CreatureIdCollector:HandleTalkingHeadAux()
    if TalkingHeadFrame and TalkingHeadFrame:IsShown() then
        -- Save its contents
        local nameText = TalkingHeadFrame.NameFrame.Name:GetText()
        if nameText then
            -- Save Display Id
            local thModel = TalkingHeadFrame.MainFrame.Model
            local displayId = nil
            if thModel then
                displayId = thModel:GetDisplayInfo()
                if displayId then
                    local zoneId = C_Map.GetBestMapForUnit("player")
                    local inInstance, instanceType = IsInInstance()
                    local classification = "talkinghead"
        
                    local creatureData = {
                        name = nameText,
                        npcId = nil,
                        displayId = displayId,
                        classification = classification,
                        zoneId = zoneId,
                        isInstance = inInstance,
                    }

                    CreatureIdCollectorRegistry:RegisterCreature(creatureData)           
                end
            end    
        end
    end
end

local function tableToJson(tbl)
    local function jsonscape(val)
        return '"' .. val:gsub('"', '\\"') .. '"'
    end

    local function serialize(value)
        if type(value) == "table" then
            local result = {}
            for k, v in pairs(value) do
                local tk = type(k)
                if (tk == "string" and #k > 0) or tk ~= "string" then
                    -- local key = type(k) == "string" and ('"' .. k .. '"') or k
                    local key = jsonscape("" .. k)
                    table.insert(result, key .. ":" .. serialize(v))
                end
            end
            return "{" .. table.concat(result, ",") .. "}"
        elseif type(value) == "string" then
            return jsonscape(value)
        elseif type(value) == "number" or type(value) == "boolean" then
            return tostring(value)
        else
            return "null"
        end
    end
    return serialize(tbl)
end


SLASH_CreatureIdCollectorDump1 = "/CreatureIdCollectorDump"
SlashCmdList["CreatureIdCollectorDump"] = function()   
    local tableToDump = CreatureIdCollectorDB
 
    -- Serialize the table to JSON
    local json = tableToJson(tableToDump)

    -- Create the main frame
    local frame = CreateFrame("Frame", "CopyFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(600, 400)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    -- Title text
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject("GameFontHighlight")
    frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER", 0, 0)
    frame.title:SetText("Copy JSON")

    -- Scroll frame
    frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)

    -- Edit box
    frame.editBox = CreateFrame("EditBox", nil, frame.scrollFrame)
    frame.editBox:SetMultiLine(true)
    frame.editBox:SetFontObject("ChatFontNormal")
    frame.editBox:SetWidth(540)
    frame.editBox:SetAutoFocus(false)
    frame.editBox:SetScript("OnEscapePressed", function() frame:Hide() end)

    -- Set scroll child
    frame.scrollFrame:SetScrollChild(frame.editBox)

    -- Close button
    frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- Add to edit box
    frame:Show()
    frame.editBox:SetText(json)
    frame.editBox:HighlightText()

    return frame
end
