-- ====================================================================
-- FLASHING LIGHTS EMERGENCY SERVICES - QBCORE JOBS INTEGRATION
-- Füge diese Jobs in qb-core/shared/jobs.lua hinzu
-- ====================================================================

-- In qb-core/shared/jobs.lua hinzufügen oder bestehende erweitern:

-- Fire Department
fire = {
    label = 'Los Santos Fire Department',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Probationary Firefighter', payment = 150 },
        ['1'] = { name = 'Firefighter', payment = 200 },
        ['2'] = { name = 'Senior Firefighter', payment = 250 },
        ['3'] = { name = 'Lieutenant', payment = 300 },
        ['4'] = { name = 'Captain', payment = 350 },
        ['5'] = { name = 'Battalion Chief', payment = 400 },
        ['6'] = { name = 'Fire Chief', payment = 450, isboss = true },
    },
},

-- Police Department (erweitert falls bereits vorhanden)
police = {
    label = 'Los Santos Police Department',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Cadet', payment = 150 },
        ['1'] = { name = 'Officer', payment = 200 },
        ['2'] = { name = 'Senior Officer', payment = 250 },
        ['3'] = { name = 'Corporal', payment = 300 },
        ['4'] = { name = 'Sergeant', payment = 350 },
        ['5'] = { name = 'Lieutenant', payment = 400 },
        ['6'] = { name = 'Captain', payment = 450 },
        ['7'] = { name = 'Commander', payment = 500 },
        ['8'] = { name = 'Chief of Police', payment = 550, isboss = true },
    },
},

-- Emergency Medical Services
ambulance = {  -- QBCore nutzt standardmäßig 'ambulance' für EMS
    label = 'Los Santos Emergency Medical Services',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'EMT Student', payment = 150 },
        ['1'] = { name = 'EMT', payment = 200 },
        ['2'] = { name = 'Paramedic', payment = 250 },
        ['3'] = { name = 'Senior Paramedic', payment = 300 },
        ['4'] = { name = 'Supervisor', payment = 350 },
        ['5'] = { name = 'EMS Captain', payment = 400 },
        ['6'] = { name = 'EMS Chief', payment = 450, isboss = true },
    },
},

--[[
ANLEITUNG:
1. Öffne qb-core/shared/jobs.lua
2. Wenn 'police' oder 'ambulance' bereits existieren, erweitere sie
3. Füge 'fire' als neuen Job hinzu
4. Verwende die Standard QBCore Boss-Befehle:
   - /boss (für isboss = true ranks)
   - /duty (für An/Abmeldung)
   - /setjob (für Admins)

VORTEILE:
✅ Nutzt vorhandenes QBCore Job-System
✅ Kompatibel mit allen anderen Scripts
✅ Boss-Menü funktioniert automatisch
✅ Duty-System ist bereits implementiert
✅ Permissions über QBCore.Functions.HasPermission
✅ Keine eigenen Commands nötig
--]]