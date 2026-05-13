pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    // Discovered custom widgets: [{ id, name, icon, qmlPath, dirPath, ... }]
    property list<var> widgets: []
    readonly property bool ready: _scanDone
    readonly property string widgetsDir: `${Directories.configPath}/inir/widgets`

    property bool _scanDone: false

    Component.onCompleted: _scan()

    function reload(): void {
        root._scanDone = false;
        root.widgets = [];
        _scan();
    }

    function _scan(): void {
        _scanProcess.running = true;
    }

    // Single process that finds and reads all manifests, outputs JSON array
    Process {
        id: _scanProcess
        command: [Directories.scriptsPath + "/scan-widgets.sh", root.widgetsDir]
        running: false

        stdout: StdioCollector {
            id: _scanCollector
            onStreamFinished: {
                const output = (_scanCollector.text ?? "").trim();
                root._parseResults(output || "[]");
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !root._scanDone) {
                root._scanDone = true;
            }
        }
    }

    // Validate manifest fields, returns array of warning strings (empty = valid)
    function _validateManifest(id: string, m: var, dir: string): list<string> {
        const warnings = [];
        if (!m.name) warnings.push(`${id}: missing "name" field`);
        if (!m.version) warnings.push(`${id}: missing "version" field`);
        const qmlFile = m.main || (id.charAt(0).toUpperCase() + id.slice(1) + ".qml");
        // configKeys type validation
        if (m.configKeys && typeof m.configKeys === "object") {
            for (const key in m.configKeys) {
                const spec = m.configKeys[key];
                const validTypes = ["int", "real", "bool", "string"];
                if (spec.type && validTypes.indexOf(spec.type) < 0)
                    warnings.push(`${id}: configKey "${key}" has unknown type "${spec.type}"`);
            }
        }
        return warnings;
    }

    function _parseResults(jsonStr: string): void {
        try {
            const entries = JSON.parse(jsonStr);
            const result = [];
            for (const entry of entries) {
                const m = entry.manifest;
                const warnings = root._validateManifest(entry.id, m, entry.dir);
                if (warnings.length > 0)
                    console.warn("[CustomWidgets]", warnings.join("; "));
                const qmlFile = m.main || (entry.id.charAt(0).toUpperCase() + entry.id.slice(1) + ".qml");
                result.push({
                    id: entry.id,
                    name: m.name || entry.id,
                    icon: m.icon || "widgets",
                    version: m.version || "1.0",
                    author: m.author || "",
                    qmlPath: `file://${entry.dir}/${qmlFile}`,
                    dirPath: entry.dir,
                    configKeys: m.configKeys || {},
                    resizableAxes: m.resizableAxes || {},
                    defaultSize: m.defaultSize || { width: 200, height: 100 },
                    valid: warnings.length === 0,
                    warnings: warnings
                });
            }
            root.widgets = result;
        } catch (e) {
            console.warn("[CustomWidgets] Failed to parse manifests:", e);
        }
        root._scanDone = true;
    }

    // Get a custom widget's config value (freeform namespace)
    function getConfigValue(widgetId: string, key: string, defaultValue: var): var {
        return Config.options?.background?.widgets?.custom?.[widgetId]?.[key] ?? defaultValue;
    }

    // Set a custom widget's config value
    function setConfigValue(widgetId: string, key: string, value: var): void {
        Config.setNestedValue("background.widgets.custom." + widgetId + "." + key, value);
    }

    IpcHandler {
        target: "customWidgets"

        function reload(): string {
            root.reload();
            return "Reloading custom widgets...";
        }

        function list(): string {
            return JSON.stringify(root.widgets.map(w => ({
                id: w.id, name: w.name, version: w.version,
                valid: w.valid, path: w.dirPath
            })), null, 2);
        }

        function create(name: string): string {
            if (!name || name.length === 0) return "Usage: inir customWidgets create <name>";
            _createProcess.widgetName = name;
            _createProcess.running = true;
            return `Creating widget "${name}" in ${root.widgetsDir}/${name}/...`;
        }
    }

    // Widget template generator
    Process {
        id: _createProcess
        property string widgetName: ""
        property string _pascalName: widgetName.charAt(0).toUpperCase() + widgetName.slice(1).replace(/-([a-z])/g, (_, c) => c.toUpperCase())
        running: false
        command: ["bash", "-c", `
            dir="${root.widgetsDir}/${_createProcess.widgetName}"
            mkdir -p "$dir"
            cat > "$dir/widget.json" << 'MANIFEST'
{
    "name": "${_createProcess._pascalName}",
    "icon": "widgets",
    "version": "1.0",
    "author": "",
    "main": "${_createProcess._pascalName}.qml",
    "configKeys": {
        "message": { "type": "string", "default": "Hello!", "label": "Message" }
    },
    "resizableAxes": {},
    "defaultSize": { "width": 200, "height": 100 }
}
MANIFEST
            cat > "$dir/${_createProcess._pascalName}.qml" << 'QML'
import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "custom.${_createProcess.widgetName}"
    defaultConfig: ({ placementStrategy: "free", widgetScale: 100, widgetOpacity: 100, colorMode: "auto", x: 200, y: 200 })
    implicitWidth: Math.round(200 * scaleFactor)
    implicitHeight: Math.round(100 * scaleFactor)

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: ColorUtils.applyAlpha(Appearance.colors.colPrimaryContainer, root.backgroundOpacity > 0 ? root.backgroundOpacity : 0.6)
        border { width: root.borderWidth; color: ColorUtils.applyAlpha(Appearance.colors.colOnPrimaryContainer, root.borderOpacity) }

        StyledText {
            anchors.centerIn: parent
            text: "Your widget here"
            color: Appearance.colors.colOnPrimaryContainer
            font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
        }
    }
}
QML
            echo "done"
        `]
        stdout: StdioCollector {
            onStreamFinished: root.reload()
        }
    }
}
