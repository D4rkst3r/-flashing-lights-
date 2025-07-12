# 🔥 FL Core - Automatisches Database Setup

Das FL Core System verfügt über ein **vollautomatisches Database-Setup**, das beim ersten Start alle notwendigen Tabellen, Views, Trigger und Prozeduren erstellt.

## 🚀 Quick Start

1. **Einfach starten:** Kopiere die fl_core Dateien in deinen Resources-Ordner
2. **Server starten:** Das Setup läuft automatisch beim ersten Start
3. **Fertig:** Alle Tabellen werden automatisch erstellt!

## ⚙️ Konfiguration

**Datei:** `config.lua`

```lua
Config.Database = {
    useOxMySQL = true,  -- QBCore 1.3.0 uses oxmysql
    tablePrefix = 'fl_', -- Prefix for all FL tables
    autoSetup = {
        enabled = true,           -- ✅ Automatisches Setup aktivieren
        createViews = true,       -- ✅ Database Views erstellen
        createTriggers = true,    -- ✅ Automatische Statistiken
        createSamples = false,    -- ❌ Test-Daten (nur für Testing)
        cleanupProcedures = true, -- ✅ Aufräum-Prozeduren
        scheduledEvents = false   -- ❌ Geplante Events (benötigt event_scheduler)
    }
}
```

## 📊 Was wird automatisch erstellt?

### 🗃️ Core Tabellen

- `fl_duty_log` - Dienstzeiten-Protokoll
- `fl_emergency_calls` - Notrufe und Einsätze
- `fl_service_whitelist` - Berechtigung für Fraktionen
- `fl_service_stats` - Spieler-Statistiken
- `fl_system_config` - System-Konfiguration

### 👁️ Database Views (optional)

- `fl_active_duty` - Aktuelle Dienste
- `fl_call_stats` - Einsatz-Statistiken
- `fl_service_roster` - Service-Mitglieder

### ⚡ Triggers (optional)

- Automatische Statistik-Updates
- Performance-Tracking
- Duty-Time-Berechnung

### 🧹 Cleanup Procedures (optional)

- `sp_cleanup_old_calls()` - Alte Einsätze löschen (30+ Tage)
- `sp_cleanup_old_duty_logs()` - Alte Duty-Logs löschen (90+ Tage)

## 🔧 Admin-Befehle

```lua
-- Datenbank-Statistiken anzeigen
/flstats

-- Manuelle Bereinigung ausführen
/flcleanup

-- Datenbank neu initialisieren (VORSICHT!)
/fldbinit

-- Konfiguration neu laden
/flreload
```

## 📝 Log-Ausgaben

**Beim Start siehst du folgende Meldungen:**

```
[FL-CORE DEBUG] 🔄 Initializing FL Emergency Services Database...
[FL-CORE DEBUG] ⏳ Waiting for oxmysql to start...
[FL-CORE DEBUG] 🔨 Creating core database tables...
[FL-CORE DEBUG] ✅ Create table: fl_duty_log
[FL-CORE DEBUG] ✅ Create table: fl_emergency_calls
[FL-CORE DEBUG] ✅ Create table: fl_service_whitelist
[FL-CORE DEBUG] ✅ Create table: fl_service_stats
[FL-CORE DEBUG] ✅ Create table: fl_system_config
[FL-CORE DEBUG] ✅ All core tables created successfully
[FL-CORE DEBUG] 👁️ Creating database views...
[FL-CORE DEBUG] ✅ Create view: fl_active_duty
[FL-CORE DEBUG] ✅ Create view: fl_call_stats
[FL-CORE DEBUG] ✅ Create view: fl_service_roster
[FL-CORE DEBUG] ✅ Database views creation completed
[FL-CORE DEBUG] ⚡ Creating database triggers...
[FL-CORE DEBUG] ✅ Create trigger: tr_duty_end_stats
[FL-CORE DEBUG] ✅ Create trigger: tr_call_complete_stats
[FL-CORE DEBUG] ✅ Database triggers creation completed
[FL-CORE DEBUG] 🧹 Creating cleanup procedures...
[FL-CORE DEBUG] ✅ Create procedure: sp_cleanup_old_calls
[FL-CORE DEBUG] ✅ Create procedure: sp_cleanup_old_duty_logs
[FL-CORE DEBUG] ✅ Cleanup procedures creation completed
[FL-CORE DEBUG] 🎉 Database initialization completed successfully!
[FL-CORE DEBUG] 📈 Database version: 1.0.0
```

## ❌ Troubleshooting

### Problem: "Database setup failed!"

**Mögliche Ursachen:**

- MySQL/MariaDB nicht erreichbar
- Fehlende Berechtigung für CREATE TABLE
- oxmysql noch nicht gestartet

**Lösung:**

1. Prüfe MySQL-Verbindung in `server.cfg`
2. Stelle sicher, dass dein DB-User CREATE-Rechte hat
3. Warte 30 Sekunden und restart den Server

### Problem: "Failed to create view/trigger"

**Das ist normal!** Views und Triggers sind optional und nicht kritisch. Das System funktioniert auch ohne sie.

**Ursachen:**

- Fehlende TRIGGER-Berechtigung
- MySQL Version zu alt
- Strict SQL Mode

**Lösung:**

```lua
-- In config.lua deaktivieren:
createViews = false,
createTriggers = false,
```

### Problem: Tabellen existieren bereits

**Beim ersten Start nach Update:**

```
[FL-CORE DEBUG] ✅ Database already initialized, loading whitelist cache...
```

Das ist **korrekt**! Das System erkennt vorhandene Tabellen und überspringt die Erstellung.

## 🔄 Manuelle Installation

Falls das automatische Setup nicht funktioniert, kannst du die Tabellen manuell erstellen:

```sql
-- Führe diesen Befehl in deiner MySQL-Konsole aus:
SOURCE path/to/fl_core/database.sql;
```

Oder nutze die bereitgestellte `database.sql` Datei aus dem fl_core Ordner.

## 📈 Performance-Tipps

### Für große Server (100+ Spieler):

```lua
-- In config.lua:
Config.Database.autoSetup = {
    createViews = true,        -- ✅ Für bessere Query-Performance
    createTriggers = false,    -- ❌ Kann bei hoher Last langsam werden
    cleanupProcedures = true,  -- ✅ Regelmäßige Bereinigung wichtig
    scheduledEvents = true     -- ✅ Automatische Bereinigung
}
```

### Für Entwicklung/Testing:

```lua
-- In config.lua:
Config.Database.autoSetup = {
    createSamples = true,      -- ✅ Test-Daten für Entwicklung
    createViews = true,        -- ✅ Einfachere SQL-Queries
    createTriggers = true,     -- ✅ Vollständige Funktionalität
}
```

## 🔒 Sicherheit

- Das System erstellt **nur** FL-spezifische Tabellen
- **Keine** bestehenden Tabellen werden verändert
- **Keine** sensiblen Daten werden gespeichert
- Alle Queries verwenden **Prepared Statements**

## 🎯 Nächste Schritte

Nach erfolgreichem Database-Setup:

1. **Spieler hinzufügen:** `/addwhitelist [id] [service] [rank]`
2. **Test-Calls erstellen:** `/testcall fire`
3. **System testen:** Gehe zu einer Station und starte Duty
4. **Erweitern:** Installiere fl_fire, fl_police oder fl_ems Module

Das automatische Database-Setup macht FL Core **sofort einsatzbereit** ohne manuelle SQL-Konfiguration! 🎉
