pragma Singleton

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    Connections {
        target: GlobalStates
        function onPackageInstallerOpenChanged() {
            console.log(`[PackageInstaller] GlobalStates.packageInstallerOpen changed to:`, GlobalStates.packageInstallerOpen);
        }
    }

    Component.onCompleted: {
        console.log("[PackageInstaller] Module loaded");
        console.log("[PackageInstaller] GlobalStates.packageInstallerOpen:", GlobalStates.packageInstallerOpen);
    }

    readonly property var focusedScreen: CompositorService.isNiri
        ? (Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? Quickshell.screens[0])
        : (Quickshell.screens[0])
    readonly property string focusedMonitorName: focusedScreen?.name ?? ""

    // Package categories configuration
    readonly property var categories: [
        {
            name: "Development",
            icon: "code",
            description: "Development tools and environments",
            packages: [
                { name: "git", description: "Distributed version control system" },
                { name: "github-cli", description: "GitHub command-line tool" },
                { name: "docker", description: "Container platform" },
                { name: "nodejs", description: "JavaScript runtime" },
                { name: "python", description: "Python programming language" },
                { name: "rust", description: "Rust programming language" },
                { name: "go", description: "Go programming language" },
                { name: "clang", description: "C/C++ compiler toolchain" },
                { name: "make", description: "Build automation tool" },
                { name: "cmake", description: "Cross-platform build system" }
            ]
        },
        {
            name: "Code Editors",
            icon: "edit_note",
            description: "Text editors and IDEs",
            packages: [
                { name: "neovim", description: "Vim-fork focused on extensibility" },
                { name: "visual-studio-code-bin", description: "Visual Studio Code (AUR)" },
                { name: "zed-editor-bin", description: "High-performance code editor (AUR)" },
                { name: "sublime-text-4", description: "Sophisticated text editor (AUR)" },
                { name: "vim", description: "Vim text editor" },
                { name: "helix", description: "Modal text editor with tree-sitter" },
                { name: "kate", description: "KDE Advanced Text Editor" },
                { name: "atom", description: "Hackable text editor (AUR)" }
            ]
        },
        {
            name: "AUR Packages",
            icon: "cloud_download",
            description: "Popular AUR packages",
            aur: true,
            packages: [
                { name: "yay", description: "Yet Another Yogurt - AUR helper" },
                { name: "paru", description: "Feature packed AUR helper" },
                { name: "pikaur", description: "AUR helper with minimal dependencies" },
                { name: "trizen", description: "Lightweight AUR helper" },
                { name: "aurman", description: "AUR helper with pacman-like interface" },
                { name: "pacaur", description: "AUR helper with pacman-like interface" },
                { name: "aura", description: "AUR helper written in Haskell" },
                { name: "herd", description: "AUR helper focused on simplicity" },
                { name: "pamac-aur-git", description: "Graphical package manager (AUR)" },
                { name: "octopi", description: "Graphical package manager" }
            ]
        },
        {
            name: "System Tools",
            icon: "settings_applications",
            description: "System administration and utilities",
            packages: [
                { name: "htop", description: "Interactive process viewer" },
                { name: "btop", description: "Resource monitor" },
                { name: "neofetch", description: "System information tool" },
                { name: "fastfetch", description: "Neofetch-like system info tool" },
                { name: "tree", description: "Directory listing utility" },
                { name: "ripgrep", description: "Fast search tool" },
                { name: "fd", description: "Simple, fast alternative to find" },
                { name: "bat", description: "Cat clone with syntax highlighting" },
                { name: "exa", description: "Modern replacement for ls" },
                { name: "eza", description: "Modern replacement for ls (maintained)" }
            ]
        },
        {
            name: "Multimedia",
            icon: "movie",
            description: "Audio and video applications",
            packages: [
                { name: "vlc", description: "Cross-platform media player" },
                { name: "mpv", description: "Lightweight media player" },
                { name: "obs-studio", description: "Streaming and recording software" },
                { name: "audacity", description: "Audio editor" },
                { name: "gimp", description: "Image editor" },
                { name: "inkscape", description: "Vector graphics editor" },
                { name: "blender", description: "3D creation suite" },
                { name: "kdenlive", description: "Video editor" },
                { name: "ffmpeg", description: "Multimedia framework" },
                { name: "imagemagick", description: "Image manipulation tools" }
            ]
        }
    ]

    function installPackage(packageName: string, isAur: bool): void {
        console.log("[PackageInstaller] installPackage called:", packageName, "isAur:", isAur);
        const installScript = isAur
            ? (Config.options?.packageInstaller?.aurHelper ?? "yay")
            : "sudo pacman";

        const installCmd = isAur
            ? [installScript, "-S", "--noconfirm", packageName]
            : [installScript, "-S", "--noconfirm", packageName];

        console.log("[PackageInstaller] Install command:", installCmd.join(" "));
        Quickshell.execDetached(["/usr/bin/notify-send", "Package Installer",
            `Installing ${packageName}...`, "-a", "Quick Action"]);

        const proc = Process {
            command: installCmd
            stdout: SplitParser {
                onRead: data => {
                    console.log(`[PackageInstaller] Installing: ${data}`);
                }
            }
            onExited: (code, status) => {
                console.log(`[PackageInstaller] Installation exited with code:`, code, "status:", status);
                if (code === 0) {
                    console.log(`[PackageInstaller] Successfully installed ${packageName}`);
                    Quickshell.execDetached(["/usr/bin/notify-send", "Package Installer",
                        `Successfully installed ${packageName}`, "-a", "Quick Action"]);
                } else {
                    console.log(`[PackageInstaller] Failed to install ${packageName}`);
                    Quickshell.execDetached(["/usr/bin/notify-send", "Package Installer",
                        `Failed to install ${packageName}`, "-a", "Quick Action", "-u", "critical"]);
                }
            }
        }
        console.log("[PackageInstaller] Starting installation process...");
        proc.running = true;
    }

    Loader {
        id: packageInstallerLoader
        active: GlobalStates.packageInstallerOpen

        onActiveChanged: {
            console.log(`[PackageInstaller] Loader.active changed to:`, active);
        }

        onLoadedChanged: {
            console.log(`[PackageInstaller] Loader.loaded changed to:`, loaded);
        }

        sourceComponent: PanelWindow {
            id: panelWindow
            screen: root.focusedScreen
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:packageInstaller"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            // Click outside to close
            MouseArea {
                anchors.fill: parent
                onClicked: mouse => {
                    const localPos = mapToItem(content, mouse.x, mouse.y)
                    if (localPos.x < 0 || localPos.x > content.width
                            || localPos.y < 0 || localPos.y > content.height) {
                        GlobalStates.packageInstallerOpen = false;
                    }
                }
            }

            PackageInstallerContent {
                id: content
                anchors.centerIn: parent
                implicitWidth: 800
                implicitHeight: 600
                // Subtle scale + fade when opening
                transformOrigin: Item.Center
                scale: GlobalStates.packageInstallerOpen ? 1.0 : 0.95
                opacity: GlobalStates.packageInstallerOpen ? 1.0 : 0.0
                Behavior on scale {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }
    }

    function openPackageInstaller() {
        GlobalStates.packageInstallerOpen = true
    }

    IpcHandler {
        target: "packageInstaller"

        function open(): void {
            root.openPackageInstaller();
        }

        function close(): void {
            GlobalStates.packageInstallerOpen = false;
        }

        function toggle(): void {
            if (GlobalStates.packageInstallerOpen) {
                GlobalStates.packageInstallerOpen = false;
            } else {
                root.openPackageInstaller();
            }
        }
    }
}
