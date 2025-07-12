# 🚨 Flashing Lights Emergency Services - Installation Guide

## 📋 Voraussetzungen

- **QBCore Framework v1.3.0+**
- **oxmysql** (wird automatisch mit QBCore installiert)
- **EUP Kleidungspaket** (für Uniformen)
- **MariaDB/MySQL Datenbank**

## 📁 Installation

### 1. Dateien kopieren

```
resources/
├── [emergency]/
│   └── fl_core/
│       ├── fxmanifest.lua
│       ├── config.lua
│       ├── shared/
│       │   └── functions.lua
│       ├── server/
│       │   └── main.lua
│       ├── client/
│       │   └── main.lua
│       └── html/
│           ├── index.html
│           ├── css/
│           │   └── style.css
│           └── js/
│               └── script.js
```

### 2. QBCore Items hinzufügen

**Datei:** `qb-core/shared/items.lua`

Füge die Items aus `items.lua` zu deiner bestehenden Items-Liste hinzu.

### 3. Server.cfg anpassen

```cfg
# Emergency Services
ensure fl_core

# Optional: Weitere FL Module
# ensure fl_fire
# ensure fl_police
# ensure fl_ems
```

### 4. Datenbank

Die Tabellen werden **automatisch** beim ersten Start erstellt! 🎉

**Automatisches Setup:**

- ✅ Alle Tabellen werden beim ersten Start erstellt
- ✅ Views, Triggers und Procedures optional verfügbar
- ✅ Konfigurierbar über `config.lua`
- ✅ Keine manuelle SQL-Ausführung nötig

**Konfiguration in `config.lua`:**

```lua
Config.Database.autoSetup = {
    enabled = true,           -- Automatisches Setup
    createViews = true,       -- Database Views
    createTriggers = true,    -- Automatische Statistiken
    createSamples = false,    -- Test-Daten (nur für Testing)
    cleanupProcedures = true, -- Aufräum-Prozeduren
}
```

**Manuelle Installation (falls nötig):**
Falls das automatische Setup nicht funktioniert, kannst du die `database.sql` verwenden.

### 5. Berechtigungen vergeben

**Als Admin im Spiel:**

```lua
-- Spieler zur Feuerwehr hinzufügen (Rang 0-6)
/addwhitelist [playerid] fire [rank]

-- Beispiele:
/addwhitelist 1 fire 1        -- Firefighter
/addwhitelist 2 police 3      -- Corporal
/addwhitelist 3 ems 2         -- Paramedic
```

## ⚙️ Konfiguration

### Stationen anpassen

**Datei:** `config.lua`

```lua
Config.Stations = {
    ['custom_fire_station'] = {
        service = 'fire',
        name = 'Deine Feuerwache',
        coords = vector3(x, y, z),  -- Hauptkoordinaten
        garage_coords = vector3(x, y, z),  -- Fahrzeug-Spawn

        duty_marker = {
            coords = vector3(x, y, z),  -- Marker für Dienst-Ein/Ausstempeln
            size = vector3(2.0, 2.0, 1.0),
            color = {r = 255, g = 0, b = 0, a = 100}
        },

        vehicle_spawns = {
            vector4(x, y, z, heading),  -- Spawn-Punkte für Fahrzeuge
        },

        equipment_coords = vector3(x, y, z)  -- Equipment-Ausgabe
    }
}
```

### EUP Uniformen anpassen

```lua
Config.Uniforms = {
    ['fire'] = {
        male = {
            tshirt_1 = 15, tshirt_2 = 0,   -- Deine EUP IDs
            torso_1 = 314, torso_2 = 0,    -- Feuerwehrjacke
            -- ... weitere Kleidungsstücke
        }
    }
}
```

## 🎮 Nutzung

### Für Spieler

1. **Dienst antreten:**

   - Gehe zur entsprechenden Wache (Blip auf der Karte)
   - Stehe im **roten/blauen/grünen Marker**
   - Drücke **[E]** um das Dienst-UI zu öffnen
   - Klicke "Start Duty"

2. **MDT öffnen:**

   - `/mdt` - Öffnet das Mobile Data Terminal
   - Zeigt aktive Notrufe, Einheiten, etc.

3. **Dienst beenden:**
   - Gehe zurück zum Marker in der Wache
   - Drücke **[E]** und bestätige "End Duty"

### Für Admins

```lua
-- Testnotrufe erstellen
/testcall fire     -- Feuerwehr-Notruf
/testcall police   -- Polizei-Notruf
/testcall ems      -- Rettungsdienst-Notruf

-- Spieler zu Service hinzufügen
/addwhitelist [id] [service] [rank]

-- System-Verwaltung
/flstats          -- System-Statistiken anzeigen
/flcleanup        -- Datenbank-Bereinigung
/fldbinit         -- Datenbank neu initialisieren (VORSICHT!)
/flreload         -- Konfiguration neu laden
/dutylist         -- Alle aktiven Dienste anzeigen
/endduty [id]     -- Spieler vom Dienst abmelden
```

## 🔧 Erweiterte Konfiguration

### Debug-Modus

```lua
Config.Debug = true  -- Zeigt detaillierte Logs
```

### Fahrzeuge anpassen

```lua
Config.EmergencyServices = {
    ['fire'] = {
        vehicles = {
            'firetruk',     -- Deine Fahrzeug-Spawnnamen
            'ambulance',
            'custom_fire_truck'
        }
    }
}
```

### Marker-Farben ändern

```lua
duty_marker = {
    coords = vector3(x, y, z),
    size = vector3(2.0, 2.0, 1.0),
    color = {r = 255, g = 0, b = 0, a = 100}  -- RGBA-Werte
}
```

## 🐛 Troubleshooting

### Häufige Probleme

**"Database setup failed!"**

- Prüfe MySQL-Verbindung in server.cfg
- Stelle sicher, dass dein DB-User CREATE-Rechte hat
- Nutze `/fldbinit` für manuelle Neuinitialisierung

**"You are not authorized for this service"**

- Spieler ist nicht in der Whitelist
- Lösung: `/addwhitelist [id] [service] [rank]`

**UI öffnet sich nicht**

- Prüfe die Browser-Konsole (F12)
- Stelle sicher, dass alle HTML/CSS/JS Dateien vorhanden sind

**Marker werden nicht angezeigt**

- Überprüfe die Koordinaten in der config.lua
- Stelle sicher, dass der Spieler in der Nähe der Station ist

**Uniform wird nicht angezogen**

- Überprüfe EUP-Installation
- Passe die Uniform-IDs in der Config an

**"Failed to create view/trigger"**

- Das ist normal! Views und Triggers sind optional
- Deaktiviere sie in der Config falls nötig:

```lua
Config.Database.autoSetup = {
    createViews = false,
    createTriggers = false,
}
```

### Log-Ausgaben

Mit `Config.Debug = true` siehst du detaillierte Logs:

```
[FL-CORE DEBUG] 🔄 Initializing FL Emergency Services Database...
[FL-CORE DEBUG] 🔨 Creating core database tables...
[FL-CORE DEBUG] ✅ Create table: fl_duty_log
[FL-CORE DEBUG] ✅ Create table: fl_emergency_calls
[FL-CORE DEBUG] ✅ All core tables created successfully
[FL-CORE DEBUG] 🎉 Database initialization completed successfully!
[FL-CORE DEBUG] Client script initialized
[FL-CORE DEBUG] Applied fire uniform
[FL-CORE DEBUG] Started duty for fire at fire_station_1
```

## 📊 Datenbank-Struktur

### fl_duty_log

```sql
id, citizenid, service, station, duty_start, duty_end, duration
```

### fl_emergency_calls

```sql
id, call_id, service, call_type, coords_x, coords_y, coords_z, priority, description, status, assigned_units, created_at, completed_at
```

### fl_service_whitelist

```sql
id, citizenid, service, rank, added_by, added_at
```

## 🔮 Nächste Schritte

Das Core ist jetzt **einsatzbereit**! Du kannst mit folgenden Modulen erweitern:

- **fl_fire** - Detailliertes Feuerwehr-System
- **fl_police** - Polizei-Features
- **fl_ems** - Rettungsdienst-System
- **fl_dispatch** - Leitstellensystem

## 💡 Tipps

- Teste zuerst im Debug-Modus (`Config.Debug = true`)
- Backup deine Datenbank vor größeren Änderungen
- Verwende die `/testcall` Befehle zum Testen
- Die UI ist responsiv und funktioniert auch auf Tablets/Handys
