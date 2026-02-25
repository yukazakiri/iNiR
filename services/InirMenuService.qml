pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.services

// ============================================================================
// InirMenuService — Global Launcher "Inir Menu" backend
//
// Developer guide
// ───────────────
// Each menu category is a plain JS object stored in `categories`.
// To add a new category, append an entry with:
//
//   {
//     id:          string           — unique key, used for routing
//     label:       string           — display name shown in the tab bar
//     icon:        string           — Material Symbol icon name
//     description: string           — shown in the empty-state placeholder
//     buildResults: (query) => []   — function that returns [{id,name,icon,iconType,verb,description,execute}]
//   }
//
// `iconType` values mirror LauncherSearchResult.IconType:
//   0 = Material symbol   1 = plain text   2 = system theme icon   3 = none
// ============================================================================

Singleton {
    id: root

    // ── state ────────────────────────────────────────────────────────────────
    property bool open: false
    property string activeCategoryId: "apps"
    property string query: ""
    property string _debouncedQuery: ""

    Timer {
        id: debounceTimer
        interval: 80
        onTriggered: root._debouncedQuery = root.query
    }
    onQueryChanged: {
        if (query === "") {
            _debouncedQuery = ""
            debounceTimer.stop()
        } else {
            debounceTimer.restart()
        }
    }

    // ── category registry ─────────────────────────────────────────────────────
    // Each entry's buildResults(query) is called by InirMenuContent to populate
    // the result list.  Results must be plain JS objects — NOT QML components.
    // ─────────────────────────────────────────────────────────────────────────
    readonly property var categories: [
        // 1. Apps ─────────────────────────────────────────────────────────────
        {
            id:          "apps",
            label:       "Apps",
            icon:        "apps",
            description: "Search and launch installed applications",
            buildResults: function(query) {
                if (!query || query.trim() === "") return []
                const entries = AppSearch.fuzzyQuery(query)
                const seen = new Set()
                const out = []
                for (let i = 0; i < entries.length && out.length < 30; i++) {
                    const e = entries[i]
                    const key = (e?.name ?? "").trim().toLowerCase()
                    if (!key || seen.has(key)) continue
                    seen.add(key)
                    out.push({
                        id:          e.id ?? e.name ?? "",
                        name:        e.name ?? "",
                        icon:        e.icon ?? "",
                        iconType:    2, // system
                        verb:        "Launch",
                        description: e.comment ?? e.genericName ?? "",
                        execute:     (function(entry) {
                            return function() {
                                if (!entry.runInTerminal) {
                                    entry.execute()
                                } else {
                                    const term = Config.options?.apps?.terminal ?? "/usr/bin/kitty"
                                    Quickshell.execDetached(["/usr/bin/bash", "-c",
                                        term + " -e '" + (entry.command?.join(" ") ?? "") + "'"])
                                }
                                root.open = false
                            }
                        })(e)
                    })
                }
                return out
            }
        },

        // 2. Setup ────────────────────────────────────────────────────────────
        {
            id:          "setup",
            label:       "Setup",
            icon:        "tune",
            description: "Configure system settings: Wi-Fi, Bluetooth, display and more",
            buildResults: function(query) {
                const items = [
                    { id: "wifi",       name: "Wi-Fi",           icon: "wifi",             description: "Manage wireless networks",       execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center wifi"]); root.open=false } },
                    { id: "bluetooth",  name: "Bluetooth",       icon: "bluetooth",        description: "Pair and connect Bluetooth devices", execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center bluetooth"]); root.open=false } },
                    { id: "display",    name: "Display",         icon: "desktop_windows",  description: "Resolution, refresh rate, scaling",  execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center display"]); root.open=false } },
                    { id: "sound",      name: "Sound",           icon: "volume_up",        description: "Audio output and input devices",      execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center sound"]); root.open=false } },
                    { id: "network",    name: "Network",         icon: "lan",              description: "Wired connections and VPN",           execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center network"]); root.open=false } },
                    { id: "power",      name: "Power",           icon: "battery_charging_full", description: "Battery, power mode and sleep",  execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center power"]); root.open=false } },
                    { id: "users",      name: "Users",           icon: "manage_accounts",  description: "User accounts and passwords",         execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center user-accounts"]); root.open=false } },
                    { id: "keyboard",   name: "Keyboard",        icon: "keyboard",         description: "Keyboard layout and shortcuts",       execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center keyboard"]); root.open=false } },
                    { id: "mouse",      name: "Mouse & Touchpad", icon: "mouse",           description: "Pointer speed and gestures",          execute: function() { Quickshell.execDetached(["bash","-c","XDG_CURRENT_DESKTOP=GNOME gnome-control-center mouse"]); root.open=false } },
                    { id: "wallpaper",  name: "Wallpaper",       icon: "wallpaper",        description: "Change desktop wallpaper",            execute: function() { GlobalStates.wallpaperSelectorOpen = true; root.open=false } },
                    { id: "inir-settings", name: "Inir Settings", icon: "settings",        description: "Open the Inir shell settings panel",  execute: function() { Quickshell.execDetached(["/usr/bin/qs","-c","ii","ipc","call","settings","open"]); root.open=false } },
                ]
                return _filterItems(items, query)
            }
        },

        // 3. Install ──────────────────────────────────────────────────────────
        {
            id:          "install",
            label:       "Install",
            icon:        "download",
            description: "Install applications and developer dependencies",
            buildResults: function(query) {
                const items = [
                    { id: "pacman",   name: "Install with pacman",  icon: "package_2", description: "pacman -S <package>",          execute: function() { _runInTerminal("sudo pacman -S "); root.open=false } },
                    { id: "yay",      name: "Install with yay",     icon: "package_2", description: "yay -S <package> (AUR)",       execute: function() { _runInTerminal("yay -S "); root.open=false } },
                    { id: "paru",     name: "Install with paru",    icon: "package_2", description: "paru -S <package> (AUR)",      execute: function() { _runInTerminal("paru -S "); root.open=false } },
                    { id: "flatpak",  name: "Install Flatpak app",  icon: "widgets",   description: "flatpak install <app>",        execute: function() { _runInTerminal("flatpak install "); root.open=false } },
                    { id: "pip",      name: "Install Python pkg",   icon: "code",      description: "pip install <package>",        execute: function() { _runInTerminal("pip install "); root.open=false } },
                    { id: "npm",      name: "Install npm package",  icon: "code",      description: "npm install -g <package>",     execute: function() { _runInTerminal("npm install -g "); root.open=false } },
                    { id: "cargo",    name: "Install Rust crate",   icon: "code",      description: "cargo install <crate>",        execute: function() { _runInTerminal("cargo install "); root.open=false } },
                    { id: "go-get",   name: "Install Go module",    icon: "code",      description: "go install <module>",          execute: function() { _runInTerminal("go install "); root.open=false } },
                ]
                return _filterItems(items, query)
            }
        },

        // 4. Remove ───────────────────────────────────────────────────────────
        {
            id:          "remove",
            label:       "Remove",
            icon:        "delete_sweep",
            description: "Uninstall applications and packages",
            buildResults: function(query) {
                const items = [
                    { id: "pacman-r",  name: "Remove with pacman",   icon: "package_2", description: "pacman -Rns <package>",        execute: function() { _runInTerminal("sudo pacman -Rns "); root.open=false } },
                    { id: "yay-r",     name: "Remove with yay",      icon: "package_2", description: "yay -Rns <package>",          execute: function() { _runInTerminal("yay -Rns "); root.open=false } },
                    { id: "flatpak-r", name: "Remove Flatpak app",   icon: "widgets",   description: "flatpak uninstall <app>",      execute: function() { _runInTerminal("flatpak uninstall "); root.open=false } },
                    { id: "pip-r",     name: "Remove Python pkg",    icon: "code",      description: "pip uninstall <package>",      execute: function() { _runInTerminal("pip uninstall "); root.open=false } },
                    { id: "npm-r",     name: "Remove npm package",   icon: "code",      description: "npm uninstall -g <package>",   execute: function() { _runInTerminal("npm uninstall -g "); root.open=false } },
                    { id: "orphans",   name: "Remove orphan packages", icon: "cleaning_services", description: "pacman -Rns $(pacman -Qtdq)", execute: function() { _runInTerminal("sudo pacman -Rns $(pacman -Qtdq) "); root.open=false } },
                ]
                return _filterItems(items, query)
            }
        },

        // 5. Update ───────────────────────────────────────────────────────────
        {
            id:          "update",
            label:       "Update",
            icon:        "system_update_alt",
            description: "Update Inir dots and system packages",
            buildResults: function(query) {
                const items = [
                    { id: "inir-update",    name: "Update Inir Shell",      icon: "update",           description: "Pull latest Inir dots from git",    execute: function() { Quickshell.execDetached(["/usr/bin/qs","-c","ii","ipc","call","shellUpdate","check"]); root.open=false } },
                    { id: "sysupgrade",     name: "Full system upgrade",    icon: "system_update_alt", description: "pacman -Syu",                       execute: function() { _runInTerminal("sudo pacman -Syu"); root.open=false } },
                    { id: "yay-upgrade",    name: "AUR upgrade (yay)",      icon: "package_2",         description: "yay -Syu",                          execute: function() { _runInTerminal("yay -Syu"); root.open=false } },
                    { id: "paru-upgrade",   name: "AUR upgrade (paru)",     icon: "package_2",         description: "paru -Syu",                         execute: function() { _runInTerminal("paru -Syu"); root.open=false } },
                    { id: "flatpak-update", name: "Update Flatpak apps",    icon: "widgets",           description: "flatpak update",                    execute: function() { _runInTerminal("flatpak update"); root.open=false } },
                    { id: "pip-upgrade",    name: "Upgrade all pip pkgs",   icon: "code",              description: "pip list --outdated | upgrade all", execute: function() { _runInTerminal("pip list --outdated --format=freeze | grep -v '^\\-e' | cut -d = -f 1 | xargs -n1 pip install -U "); root.open=false } },
                ]
                return _filterItems(items, query)
            }
        },

        // 6. About ────────────────────────────────────────────────────────────
        {
            id:          "about",
            label:       "About",
            icon:        "info",
            description: "OS and shell information",
            buildResults: function(query) {
                const items = [
                    { id: "distro",    name: SystemInfo.distroName,         icon: SystemInfo.distroIcon, iconType: 2, description: "Operating System",       execute: function() {} },
                    { id: "user",      name: SystemInfo.username,           icon: "person",              description: "Current user",                        execute: function() {} },
                    { id: "de",        name: SystemInfo.desktopEnvironment, icon: "desktop_windows",     description: "Desktop environment",                 execute: function() {} },
                    { id: "wm",        name: SystemInfo.windowingSystem,    icon: "window",              description: "Windowing system",                    execute: function() {} },
                    { id: "home-url",  name: "Project Homepage",            icon: "open_in_new",         description: SystemInfo.homeUrl,                    execute: function() { if (SystemInfo.homeUrl) Qt.openUrlExternally(SystemInfo.homeUrl) } },
                    { id: "docs-url",  name: "Documentation",               icon: "menu_book",           description: SystemInfo.documentationUrl,           execute: function() { if (SystemInfo.documentationUrl) Qt.openUrlExternally(SystemInfo.documentationUrl) } },
                    { id: "bug-url",   name: "Bug Reports",                 icon: "bug_report",          description: SystemInfo.bugReportUrl,               execute: function() { if (SystemInfo.bugReportUrl) Qt.openUrlExternally(SystemInfo.bugReportUrl) } },
                    { id: "inir-repo", name: "Inir Shell Repository",       icon: "terminal",            description: "https://github.com/anomalyco/inir",   execute: function() { Qt.openUrlExternally("https://github.com/anomalyco/inir") } },
                    { id: "changelog", name: "Inir Changelog",              icon: "history",             description: "View recent shell changes",           execute: function() { Quickshell.execDetached(["/usr/bin/qs","-c","ii","ipc","call","shellUpdate","open"]) } },
                ]
                return _filterItems(items, query)
            }
        },
    ]

    // ── helpers ───────────────────────────────────────────────────────────────

    // Fuzzy-ish filter: returns items whose name or description contains the query
    function _filterItems(items, query) {
        if (!query || query.trim() === "") return items
        const q = query.trim().toLowerCase()
        return items.filter(function(item) {
            return (item.name  ?? "").toLowerCase().includes(q) ||
                   (item.description ?? "").toLowerCase().includes(q)
        })
    }

    // Open a terminal and pre-fill a command (cursor at end for user to type package name)
    function _runInTerminal(cmd) {
        const term = Config.options?.apps?.terminal ?? "/usr/bin/kitty"
        // kitty / foot style: -e bash -c '…; bash'  — keeps terminal open after
        Quickshell.execDetached(["/usr/bin/bash", "-c",
            term + " -e bash -c 'echo Running: " + cmd + "; " + cmd + "; exec bash'"])
    }

    // ── IPC ───────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "inirMenu"
        function toggle(): void    { root.open = !root.open }
        function open(): void      { root.open = true }
        function close(): void     { root.open = false }
        function showCategory(id: string): void {
            root.activeCategoryId = id
            root.open = true
        }
    }

    // ── convenience getters ───────────────────────────────────────────────────
    function activeCategory() {
        for (let i = 0; i < categories.length; i++) {
            if (categories[i].id === activeCategoryId) return categories[i]
        }
        return categories[0]
    }

    function results() {
        const cat = activeCategory()
        if (!cat) return []
        return cat.buildResults(_debouncedQuery)
    }
}
