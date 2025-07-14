-- ====================================================================
-- FL EMERGENCY VEHICLES - MEMORY MANAGEMENT SYSTEM (SELF-FEHLER BEHOBEN)
-- KRITISCHER FIX: 'self' durch 'FL.VehicleManager' ersetzt
-- ====================================================================

FL.VehicleManager = {
    maxVehiclesPerPlayer = 3,
    cleanupInterval = 60000, -- 1 minute
    lastCleanup = 0,

    init = function(self)         -- KORRIGIERT: 'self' Parameter hinzugefügt
        FL.Debug('🚗 Vehicle Manager initialized')
        self:startCleanupThread() -- KORRIGIERT: self: syntax verwendet
    end,

    spawnVehicle = function(self, stationId, vehicleKey, spawnIndex) -- KORRIGIERT: 'self' Parameter
        -- Check vehicle limit before spawning
        local currentCount = self:getPlayerVehicleCount()

        if currentCount >= self.maxVehiclesPerPlayer then
            self:cleanupOldestVehicle()
        end

        -- Call original spawn function
        SpawnEmergencyVehicle(stationId, vehicleKey, spawnIndex)
    end,

    getPlayerVehicleCount = function(self) -- KORRIGIERT: 'self' Parameter
        local count = 0
        for vehicle, data in pairs(FL.Client.spawnedVehicles) do
            if DoesEntityExist(vehicle) then
                count = count + 1
            end
        end
        return count
    end,

    cleanupOldestVehicle = function(self) -- KORRIGIERT: 'self' Parameter
        local oldestVehicle = nil
        local oldestTime = GetGameTimer()

        for vehicle, data in pairs(FL.Client.spawnedVehicles) do
            if DoesEntityExist(vehicle) and data.spawnTime < oldestTime then
                oldestVehicle = vehicle
                oldestTime = data.spawnTime
            end
        end

        if oldestVehicle then
            FL.Debug('🗑️ Cleaning up oldest vehicle to make space')
            self:deleteVehicle(oldestVehicle)
        end
    end,

    deleteVehicle = function(self, vehicle) -- KORRIGIERT: 'self' Parameter
        if FL.Client.spawnedVehicles[vehicle] then
            FL.Client.spawnedVehicles[vehicle] = nil
        end

        if FL.Client.vehicleBlips[vehicle] then
            RemoveBlip(FL.Client.vehicleBlips[vehicle])
            FL.Client.vehicleBlips[vehicle] = nil
        end

        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end,

    startCleanupThread = function(self) -- KORRIGIERT: 'self' Parameter
        CreateThread(function()
            while true do
                Wait(self.cleanupInterval)
                self:performCleanup()
            end
        end)
    end,

    performCleanup = function(self) -- KORRIGIERT: 'self' Parameter
        local cleaned = 0
        local toRemove = {}

        for vehicle, data in pairs(FL.Client.spawnedVehicles) do
            if not DoesEntityExist(vehicle) then
                table.insert(toRemove, vehicle)
                cleaned = cleaned + 1
            end
        end

        for _, vehicle in pairs(toRemove) do
            FL.Client.spawnedVehicles[vehicle] = nil
            if FL.Client.vehicleBlips[vehicle] then
                RemoveBlip(FL.Client.vehicleBlips[vehicle])
                FL.Client.vehicleBlips[vehicle] = nil
            end
        end

        if cleaned > 0 then
            FL.Debug('🧹 Cleaned up ' .. cleaned .. ' invalid vehicle references')
        end
    end
}

-- Initialize on resource start (KORRIGIERT: Proper method call)
CreateThread(function()
    Wait(5000)               -- Wait for main systems to load
    FL.VehicleManager:init() -- KORRIGIERT: self: syntax verwendet
end)
