pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.services

// ============================================================================
// InirMenuService — Global Launcher "Inir Menu" backend
//
// Developer guide
// ───────────────
// Each menu category is a plain JS object in `categories`. To add one:
//
//   {
//     id:          string          — unique key
//     label:       string          — display name in the list
//     icon:        string          — Material Symbol name
//     description: string          — subtitle shown in the row
//     buildResults: (query) => []  — returns [{id,name,icon,iconType,verb,description,execute}]
//   }
//
// iconType: 0=Material symbol  2=system theme icon
// ============================================================================

Singleton {
    id: root

    // ── open state (the only state the service owns) ──────────────────────
    property bool open: false

    // ── category registry ─────────────────────────────────────────────────
    readonly property var categories: [

        // 1. Apps ─────────────────────────────────────────────────────────
        {
            id:          "apps",
            label:       "Apps",
            icon:        "apps",
            description: "Search and launch installed applications",
            buildResults: function(query) {
                if (!query || query.trim() === "") return []
                const entries = AppSearch.fuzzyQuery(query)
                const seen = new Set()
                const out  = []
                for (let i = 0; i < entries.length && out.length < 30; i++) {
                    const e   = entries[i]
                    const key = (e?.name ?? "").trim().toLowerCase()
                    if (!key || seen.has(key)) continue
                    seen.add(key)
                    out.push({
                        id:          e.id ?? e.name ?? "",
                        name:        e.name  ?? "",
                        icon:        e.icon  ?? "",
                        iconType:    2,
                        verb:        "Launch",
                        description: e.comment ?? e.genericName ?? "",
                        execute: (function(entry) { return function() {
                            if (!entry.runInTerminal) {
                                entry.execute()
                            } else {
                                const term = Config.options?.apps?.terminal ?? "/usr/bin/kitty"
                                Quickshell.execDetached(["/usr/bin/bash", "-c",
                                    term + " -e '" + (entry.command?.join(" ") ?? "") + "'"])
                            }
                            root.open = false
                        }})(e)
                    })
                }
                return out
            }
        },

        // 2. Setup ────────────────────────────────────────────────────────
        {
            id:          "setup",
            label:       "Setup",
            icon:        "tune",
            description: "Configure system settings",
            buildResults: function(query) {
                const items = [
                    { id: "wifi",      name: "Wi-Fi",            icon: "wifi",                  description: "Manage wireless networks",        execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center wifi"]);         root.open=false } },
                    { id: "bt",        name: "Bluetooth",         icon: "bluetooth",             description: "Pair and connect Bluetooth",      execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center bluetooth"]);    root.open=false } },
                    { id: "display",   name: "Display",           icon: "desktop_windows",       description: "Resolution, scaling, refresh",   execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center display"]);      root.open=false } },
                    { id: "sound",     name: "Sound",             icon: "volume_up",             description: "Audio output and input",         execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center sound"]);        root.open=false } },
                    { id: "network",   name: "Network",           icon: "lan",                   description: "Wired connections and VPN",      execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center network"]);      root.open=false } },
                    { id: "power",     name: "Power",             icon: "battery_charging_full", description: "Battery and power mode",         execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center power"]);        root.open=false } },
                    { id: "users",     name: "Users",             icon: "manage_accounts",       description: "User accounts and passwords",    execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center user-accounts"]); root.open=false } },
                    { id: "keyboard",  name: "Keyboard",          icon: "keyboard",              description: "Layout and shortcuts",           execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center keyboard"]);      root.open=false } },
                    { id: "mouse",     name: "Mouse & Touchpad",  icon: "mouse",                 description: "Pointer speed and gestures",     execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center mouse"]);         root.open=false } },
                    { id: "wallpaper", name: "Wallpaper",         icon: "wallpaper",             description: "Change desktop wallpaper",       execute: function() { GlobalStates.wallpaperSelectorOpen = true; root.open=false } },
                    { id: "inir",      name: "Inir Settings",     icon: "settings",              description: "Open Inir shell settings",       execute: function() { Quickshell.execDetached(["/usr/bin/qs","-c","ii","ipc","call","settings","open"]); root.open=false } },
                ]
                return _filter(items, query)
            }
        },

        // 3. Install ──────────────────────────────────────────────────────
        {
            id:          "install",
            label:       "Install",
            icon:        "download",
            description: "Install apps and developer dependencies",
            buildResults: function(query) {
                const items = [
                    { id: "pacman", name: "Install with pacman", icon: "package_2", description: "sudo pacman -S <pkg>",        execute: function() { _terminal("sudo pacman -S ");  root.open=false } },
                    { id: "yay",    name: "Install with yay",    icon: "package_2", description: "yay -S <pkg>  (AUR)",        execute: function() { _terminal("yay -S ");           root.open=false } },
                    { id: "paru",   name: "Install with paru",   icon: "package_2", description: "paru -S <pkg>  (AUR)",       execute: function() { _terminal("paru -S ");          root.open=false } },
                    { id: "flat",   name: "Install Flatpak",     icon: "widgets",   description: "flatpak install <app>",      execute: function() { _terminal("flatpak install ");  root.open=false } },
                    { id: "pip",    name: "Install Python pkg",  icon: "code",      description: "pip install <pkg>",          execute: function() { _terminal("pip install ");       root.open=false } },
                    { id: "npm",    name: "Install npm pkg",     icon: "code",      description: "npm install -g <pkg>",       execute: function() { _terminal("npm install -g ");   root.open=false } },
                    { id: "cargo",  name: "Install Rust crate",  icon: "code",      description: "cargo install <crate>",      execute: function() { _terminal("cargo install ");    root.open=false } },
                    { id: "go",     name: "Install Go module",   icon: "code",      description: "go install <module>",        execute: function() { _terminal("go install ");        root.open=false } },
                ]
                return _filter(items, query)
            }
        },

        // 4. Remove ───────────────────────────────────────────────────────
        {
            id:          "remove",
            label:       "Remove",
            icon:        "delete_sweep",
            description: "Uninstall applications and packages",
            buildResults: function(query) {
                const items = [
                    { id: "pacman-r", name: "Remove with pacman",    icon: "package_2",      description: "sudo pacman -Rns <pkg>",          execute: function() { _terminal("sudo pacman -Rns ");  root.open=false } },
                    { id: "yay-r",    name: "Remove with yay",       icon: "package_2",      description: "yay -Rns <pkg>",                  execute: function() { _terminal("yay -Rns ");           root.open=false } },
                    { id: "flat-r",   name: "Remove Flatpak",        icon: "widgets",        description: "flatpak uninstall <app>",         execute: function() { _terminal("flatpak uninstall "); root.open=false } },
                    { id: "pip-r",    name: "Remove Python pkg",     icon: "code",           description: "pip uninstall <pkg>",             execute: function() { _terminal("pip uninstall ");     root.open=false } },
                    { id: "npm-r",    name: "Remove npm pkg",        icon: "code",           description: "npm uninstall -g <pkg>",          execute: function() { _terminal("npm uninstall -g "); root.open=false } },
                    { id: "orphans",  name: "Remove orphan pkgs",    icon: "cleaning_services", description: "pacman -Rns $(pacman -Qtdq)", execute: function() { _terminal("sudo pacman -Rns $(pacman -Qtdq)"); root.open=false } },
                ]
                return _filter(items, query)
            }
        },

        // 5. Update ───────────────────────────────────────────────────────
        {
            id:          "update",
            label:       "Update",
            icon:        "system_update_alt",
            description: "Update Inir and system packages",
            buildResults: function(query) {
                const items = [
                    { id: "inir-up",  name: "Update Inir Shell",     icon: "update",           description: "Pull latest Inir dots",        execute: function() { Quickshell.execDetached(["/usr/bin/qs","-c","ii","ipc","call","shellUpdate","check"]); root.open=false } },
                    { id: "sysup",    name: "Full system upgrade",   icon: "system_update_alt", description: "sudo pacman -Syu",             execute: function() { _terminal("sudo pacman -Syu");   root.open=false } },
                    { id: "yay-up",   name: "AUR upgrade (yay)",     icon: "package_2",         description: "yay -Syu",                     execute: function() { _terminal("yay -Syu");           root.open=false } },
                    { id: "paru-up",  name: "AUR upgrade (paru)",    icon: "package_2",         description: "paru -Syu",                    execute: function() { _terminal("paru -Syu");          root.open=false } },
                    { id: "flat-up",  name: "Update Flatpak apps",   icon: "widgets",           description: "flatpak update",               execute: function() { _terminal("flatpak update");     root.open=false } },
                ]
                return _filter(items, query)
            }
        },

        // 6. About ────────────────────────────────────────────────────────
        {
            id:          "about",
            label:       "About",
            icon:        "info",
            description: "OS and Inir shell information",
            buildResults: function(query) {
                const items = [
                    { id: "distro",  name: SystemInfo.distroName,         icon: SystemInfo.distroIcon, iconType: 2, description: "Operating System",      execute: function() {} },
                    { id: "user",    name: SystemInfo.username,           icon: "person",               description: "Current user",                       execute: function() {} },
                    { id: "de",      name: SystemInfo.desktopEnvironment, icon: "desktop_windows",      description: "Desktop environment",                execute: function() {} },
                    { id: "wm",      name: SystemInfo.windowingSystem,    icon: "window",               description: "Windowing system",                   execute: function() {} },
                    { id: "home",    name: "Project Homepage",             icon: "open_in_new",          description: SystemInfo.homeUrl,                   execute: function() { if (SystemInfo.homeUrl) Qt.openUrlExternally(SystemInfo.homeUrl) } },
                    { id: "docs",    name: "Documentation",                icon: "menu_book",            description: SystemInfo.documentationUrl,          execute: function() { if (SystemInfo.documentationUrl) Qt.openUrlExternally(SystemInfo.documentationUrl) } },
                    { id: "bugs",    name: "Bug Reports",                  icon: "bug_report",           description: SystemInfo.bugReportUrl,              execute: function() { if (SystemInfo.bugReportUrl) Qt.openUrlExternally(SystemInfo.bugReportUrl) } },
                    { id: "repo",    name: "Inir Repository",              icon: "terminal",             description: "github.com/anomalyco/inir",          execute: function() { Qt.openUrlExternally("https://github.com/anomalyco/inir") } },
                    { id: "changes", name: "Inir Changelog",               icon: "history",              description: "View recent shell changes",          execute: function() { Quickshell.execDetached(["/usr/bin/qs","-c","ii","ipc","call","shellUpdate","open"]) } },
                ]
                return _filter(items, query)
            }
        },
    ]

    // ── internal helpers ──────────────────────────────────────────────────
    function _filter(items, query) {
        if (!query || query.trim() === "") return items
        const q = query.trim().toLowerCase()
        return items.filter(function(item) {
            return (item.name        ?? "").toLowerCase().includes(q)
                || (item.description ?? "").toLowerCase().includes(q)
        })
    }

    function _terminal(cmd) {
        const term = Config.options?.apps?.terminal ?? "/usr/bin/kitty"
        Quickshell.execDetached(["/usr/bin/bash", "-c",
            term + " -e bash -c '" + cmd + "; exec bash'"])
    }
}
