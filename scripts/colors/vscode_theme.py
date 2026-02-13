#!/usr/bin/env python3
"""Generate VSCode workbench theme from Material You colors.

This script reads the Material You color palette and produces a VSCode
theme JSON file that styles the workbench UI (sidebar, status bar, editor
backgrounds, etc.) while preserving VSCode's default syntax highlighting.

The theme is written to the user's VSCode extensions folder as a proper
VSCode extension theme.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Dict, Optional


COLOR_SOURCE = Path(
    os.environ.get(
        "QUICKSHELL_COLORS_JSON",
        "~/.local/state/quickshell/user/generated/colors.json",
    )
).expanduser()

# VSCode theme output paths - handles various VSCode forks
THEME_OUTPUT_PATHS = [
    Path(
        "~/.vscode/extensions/ini-material-theme/themes/ini-material-color-theme.json"
    ).expanduser(),
    Path(
        "~/.vscode-oss/extensions/ini-material-theme/themes/ini-material-color-theme.json"
    ).expanduser(),
    Path(
        "~/.vscode-insiders/extensions/ini-material-theme/themes/ini-material-color-theme.json"
    ).expanduser(),
    Path(
        "~/.cursor/extensions/ini-material-theme/themes/ini-material-color-theme.json"
    ).expanduser(),
    Path(
        "~/.vscodium/extensions/ini-material-theme/themes/ini-material-color-theme.json"
    ).expanduser(),
]

# Package.json for the extension
PACKAGE_JSON = {
    "name": "ini-material-theme",
    "displayName": "iNiR Material Theme",
    "description": "Dynamic Material You theme from iNiR Quickshell",
    "version": "1.0.0",
    "publisher": "inir",
    "engines": {"vscode": "^1.60.0"},
    "categories": ["Themes"],
    "contributes": {
        "themes": [
            {
                "label": "iNiR Material",
                "uiTheme": "vs-dark",
                "path": "./themes/ini-material-color-theme.json",
            }
        ]
    },
}


def _hex_to_rgb(color: str) -> tuple:
    color = color.lstrip("#")
    return tuple(int(color[i : i + 2], 16) for i in range(0, 6, 2))


def _rgba(color: str, alpha: float) -> str:
    r, g, b = _hex_to_rgb(color)
    return f"rgba({r}, {g}, {b}, {alpha:.2f})"


def _adjust_lightness(color: str, delta: float) -> str:
    """Adjust color lightness using simple RGB blending with white/black."""
    r, g, b = _hex_to_rgb(color)
    if delta > 0:
        # Lighten: blend towards white
        factor = delta
        r = int(r + (255 - r) * factor)
        g = int(g + (255 - g) * factor)
        b = int(b + (255 - b) * factor)
    else:
        # Darken: blend towards black
        factor = -delta
        r = int(r * (1 - factor))
        g = int(g * (1 - factor))
        b = int(b * (1 - factor))
    return f"#{r:02x}{g:02x}{b:02x}"


def _mix(color_a: str, color_b: str, weight: float) -> str:
    """Mix two colors."""
    ra, ga, ba = _hex_to_rgb(color_a)
    rb, gb, bb = _hex_to_rgb(color_b)
    r = int(ra * (1 - weight) + rb * weight)
    g = int(ga * (1 - weight) + gb * weight)
    b = int(ba * (1 - weight) + bb * weight)
    return f"#{r:02x}{g:02x}{b:02x}"


def _load_colors() -> Dict[str, str]:
    if not COLOR_SOURCE.exists():
        raise FileNotFoundError(
            f"Material colors file not found: {COLOR_SOURCE}. "
            "Ensure switchwall.sh has been executed successfully."
        )
    with COLOR_SOURCE.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    return {k: v.lower() for k, v in data.items()}


def _build_vscode_theme(colors: Dict[str, str]) -> Dict:
    """Build VSCode workbench theme from Material You colors."""

    # Extract key colors
    background = colors.get("background", "#1e1e2e")
    surface = colors.get("surface", "#1e1e2e")
    surface_container = colors.get("surface_container", "#313244")
    surface_container_high = colors.get("surface_container_high", "#45475a")
    surface_container_highest = colors.get("surface_container_highest", "#585b70")
    surface_bright = colors.get("surface_bright", "#313244")

    foreground = colors.get("on_background", "#cdd6f4")
    on_surface = colors.get("on_surface", "#cdd6f4")
    on_surface_variant = colors.get("on_surface_variant", "#bac2de")

    primary = colors.get("primary", "#cba6f7")
    on_primary = colors.get("on_primary", "#1e1e2e")
    primary_container = colors.get("primary_container", "#45475a")
    on_primary_container = colors.get("on_primary_container", "#f5c2e7")

    secondary = colors.get("secondary", "#f5c2e7")
    secondary_container = colors.get("secondary_container", "#45475a")

    tertiary = colors.get("tertiary", "#94e2d5")

    error = colors.get("error", "#f38ba8")
    on_error = colors.get("on_error", "#1e1e2e")
    error_container = colors.get("error_container", "#45475a")

    outline = colors.get("outline", "#6c7086")
    outline_variant = colors.get("outline_variant", "#45475a")

    # Determine if dark mode
    bg_rgb = _hex_to_rgb(background)
    luminance = (0.299 * bg_rgb[0] + 0.587 * bg_rgb[1] + 0.114 * bg_rgb[2]) / 255
    is_dark = luminance < 0.5

    theme = {
        "name": "iNiR Material",
        "type": "dark" if is_dark else "light",
        "colors": {
            # === Base Colors ===
            "foreground": foreground,
            "background": background,
            "editor.foreground": foreground,
            "editor.background": surface,
            "editor.inactiveSelectionBackground": _rgba(primary, 0.15),
            "editor.selectionBackground": _rgba(primary, 0.25),
            "editor.selectionHighlightBackground": _rgba(primary, 0.10),
            "editor.lineHighlightBackground": surface_container,
            "editor.lineHighlightBorder": surface_container,
            "editor.rangeHighlightBackground": _rgba(primary, 0.08),
            "editor.wordHighlightBackground": _rgba(primary, 0.15),
            "editor.wordHighlightStrongBackground": _rgba(primary, 0.25),
            # === Cursor & Selection ===
            "editorCursor.foreground": primary,
            "editorCursor.background": background,
            "editorWhitespace.foreground": outline_variant,
            "editorIndentGuide.background": outline_variant,
            "editorIndentGuide.activeBackground": outline,
            "editorLineNumber.foreground": outline,
            "editorLineNumber.activeForeground": on_surface_variant,
            "editorRuler.foreground": outline_variant,
            # === Editor UI ===
            "editorBracketMatch.background": _rgba(primary, 0.15),
            "editorBracketMatch.border": primary,
            "editor.findMatchBackground": _rgba(primary, 0.30),
            "editor.findMatchHighlightBackground": _rgba(primary, 0.15),
            "editor.findRangeHighlightBackground": _rgba(primary, 0.10),
            "editor.hoverHighlightBackground": _rgba(primary, 0.08),
            "editor.linkedEditingBackground": _rgba(primary, 0.10),
            "editorInlayHint.background": _adjust_lightness(
                surface, 0.05 if is_dark else -0.05
            ),
            "editorInlayHint.foreground": on_surface_variant,
            "editorInlayHint.paramBackground": surface_container,
            "editorInlayHint.paramForeground": on_surface_variant,
            "editorInlayHint.typeBackground": surface_container,
            "editorInlayHint.typeForeground": on_surface_variant,
            # === Minimap ===
            "minimap.background": surface,
            "minimap.selectionHighlight": _rgba(primary, 0.30),
            "minimap.errorHighlight": error,
            "minimap.warningHighlight": tertiary,
            "minimapSlider.background": _rgba(primary, 0.10),
            "minimapSlider.hoverBackground": _rgba(primary, 0.15),
            "minimapSlider.activeBackground": _rgba(primary, 0.20),
            # === Sidebar ===
            "sideBar.background": background,
            "sideBar.foreground": on_surface_variant,
            "sideBar.border": outline_variant,
            "sideBar.dropBackground": _rgba(primary, 0.15),
            "sideBarSectionHeader.background": surface_container,
            "sideBarSectionHeader.foreground": foreground,
            "sideBarSectionHeader.border": outline_variant,
            "sideBarTitle.foreground": foreground,
            # === Activity Bar ===
            "activityBar.background": background,
            "activityBar.foreground": on_surface_variant,
            "activityBar.border": outline_variant,
            "activityBar.inactiveForeground": outline,
            "activityBar.activeBorder": primary,
            "activityBar.activeBackground": "transparent",
            "activityBar.activeFocusBorder": primary,
            "activityBarBadge.background": primary,
            "activityBarBadge.foreground": on_primary,
            # === Status Bar ===
            "statusBar.background": surface_container,
            "statusBar.foreground": on_surface_variant,
            "statusBar.border": outline_variant,
            "statusBar.debuggingBackground": _mix(error, surface_container, 0.5),
            "statusBar.debuggingForeground": on_surface,
            "statusBar.noFolderBackground": surface_container_high,
            "statusBar.noFolderForeground": on_surface_variant,
            "statusBarItem.activeBackground": _rgba(primary, 0.20),
            "statusBarItem.hoverBackground": _rgba(primary, 0.15),
            "statusBarItem.prominentBackground": primary_container,
            "statusBarItem.prominentForeground": on_primary_container,
            "statusBarItem.prominentHoverBackground": _adjust_lightness(
                primary_container, 0.05 if is_dark else -0.05
            ),
            "statusBarItem.errorBackground": _rgba(error, 0.20),
            "statusBarItem.errorForeground": error,
            "statusBarItem.warningBackground": _rgba(tertiary, 0.20),
            "statusBarItem.warningForeground": tertiary,
            # === Title Bar ===
            "titleBar.activeBackground": background,
            "titleBar.activeForeground": foreground,
            "titleBar.inactiveBackground": surface,
            "titleBar.inactiveForeground": outline,
            "titleBar.border": outline_variant,
            # === Tabs ===
            "tab.activeBackground": surface,
            "tab.activeForeground": foreground,
            "tab.activeBorder": primary,
            "tab.activeBorderTop": primary,
            "tab.inactiveBackground": background,
            "tab.inactiveForeground": outline,
            "tab.border": outline_variant,
            "tab.hoverBackground": surface_container,
            "tab.hoverForeground": foreground,
            "tab.hoverBorder": primary,
            "tab.unfocusedActiveBackground": surface,
            "tab.unfocusedActiveForeground": on_surface_variant,
            "tab.unfocusedInactiveBackground": background,
            "tab.unfocusedInactiveForeground": outline,
            "tab.unfocusedHoverBackground": surface_container,
            "tab.unfocusedHoverForeground": on_surface_variant,
            # === Editor Groups ===
            "editorGroupHeader.tabsBackground": background,
            "editorGroupHeader.tabsBorder": outline_variant,
            "editorGroupHeader.noTabsBackground": background,
            "editorGroup.border": outline_variant,
            "editorGroup.dropBackground": _rgba(primary, 0.15),
            "editorGroup.focusedEmptyBorder": primary,
            # === Breadcrumb ===
            "breadcrumb.background": surface,
            "breadcrumb.foreground": on_surface_variant,
            "breadcrumb.focusForeground": foreground,
            "breadcrumb.activeSelectionForeground": primary,
            "breadcrumbPicker.background": surface_container,
            # === Panels ===
            "panel.background": background,
            "panel.border": outline_variant,
            "panel.dropBorder": primary,
            "panelSection.border": outline_variant,
            "panelSection.dropBackground": _rgba(primary, 0.15),
            "panelTitle.activeBorder": primary,
            "panelTitle.activeForeground": foreground,
            "panelTitle.inactiveForeground": on_surface_variant,
            # === Terminal ===
            "terminal.background": background,
            "terminal.foreground": foreground,
            "terminal.ansiBlack": "#000000" if is_dark else foreground,
            "terminal.ansiWhite": "#ffffff" if is_dark else background,
            "terminal.ansiRed": colors.get("term1", error),
            "terminal.ansiGreen": colors.get("term2", "#a6e3a1"),
            "terminal.ansiYellow": colors.get("term3", "#f9e2af"),
            "terminal.ansiBlue": colors.get("term4", "#89b4fa"),
            "terminal.ansiMagenta": colors.get("term5", secondary),
            "terminal.ansiCyan": colors.get("term6", tertiary),
            "terminal.ansiBrightBlack": outline,
            "terminal.ansiBrightWhite": on_surface if is_dark else background,
            "terminal.ansiBrightRed": colors.get("term9", error),
            "terminal.ansiBrightGreen": colors.get("term10", "#a6e3a1"),
            "terminal.ansiBrightYellow": colors.get("term11", "#f9e2af"),
            "terminal.ansiBrightBlue": colors.get("term12", "#89b4fa"),
            "terminal.ansiBrightMagenta": colors.get("term13", secondary),
            "terminal.ansiBrightCyan": colors.get("term14", tertiary),
            "terminal.selectionBackground": _rgba(primary, 0.25),
            "terminalCursor.foreground": primary,
            "terminalCursor.background": background,
            # === Input ===
            "input.background": surface_container,
            "input.foreground": foreground,
            "input.border": outline_variant,
            "input.placeholderForeground": outline,
            "inputOption.activeBackground": _rgba(primary, 0.20),
            "inputOption.activeBorder": primary,
            "inputOption.activeForeground": foreground,
            "inputValidation.errorBackground": error_container,
            "inputValidation.errorForeground": on_error,
            "inputValidation.errorBorder": error,
            "inputValidation.infoBackground": primary_container,
            "inputValidation.infoForeground": on_primary_container,
            "inputValidation.infoBorder": primary,
            "inputValidation.warningBackground": _mix(tertiary, surface_container, 0.3),
            "inputValidation.warningForeground": foreground,
            "inputValidation.warningBorder": tertiary,
            # === Dropdown ===
            "dropdown.background": surface_container,
            "dropdown.foreground": foreground,
            "dropdown.border": outline_variant,
            "dropdown.listBackground": surface_container_high,
            # === List/Tree ===
            "list.background": background,
            "list.foreground": foreground,
            "list.hoverBackground": surface_container,
            "list.hoverForeground": foreground,
            "list.activeSelectionBackground": _rgba(primary, 0.20),
            "list.activeSelectionForeground": foreground,
            "list.inactiveSelectionBackground": _rgba(primary, 0.10),
            "list.inactiveSelectionForeground": foreground,
            "list.focusBackground": _rgba(primary, 0.25),
            "list.focusForeground": foreground,
            "list.focusHighlightForeground": primary,
            "list.highlightForeground": primary,
            "list.dropBackground": _rgba(primary, 0.15),
            "list.errorForeground": error,
            "list.warningForeground": tertiary,
            "listFilterWidget.background": surface_container,
            "listFilterWidget.outline": primary,
            "listFilterWidget.noMatchesOutline": error,
            "tree.indentGuidesStroke": outline_variant,
            # === Notifications ===
            "notifications.background": surface_container,
            "notifications.foreground": foreground,
            "notifications.border": outline_variant,
            "notificationCenter.border": outline_variant,
            "notificationCenterHeader.foreground": on_surface_variant,
            "notificationCenterHeader.background": background,
            "notificationToast.border": outline_variant,
            "notificationLink.foreground": primary,
            "notificationsErrorIcon.foreground": error,
            "notificationsWarningIcon.foreground": tertiary,
            "notificationsInfoIcon.foreground": primary,
            # === Scrollbar ===
            "scrollbar.shadow": "transparent",
            "scrollbarSlider.activeBackground": _rgba(primary, 0.40),
            "scrollbarSlider.background": _rgba(outline, 0.20),
            "scrollbarSlider.hoverBackground": _rgba(primary, 0.25),
            # === Widget ===
            "widget.shadow": _rgba("#000000" if is_dark else "#ffffff", 0.20),
            "editorWidget.background": surface_container,
            "editorWidget.foreground": foreground,
            "editorWidget.resizeBorder": outline,
            "editorSuggestWidget.background": surface_container,
            "editorSuggestWidget.border": outline_variant,
            "editorSuggestWidget.foreground": foreground,
            "editorSuggestWidget.highlightForeground": primary,
            "editorSuggestWidget.selectedBackground": _rgba(primary, 0.20),
            "editorSuggestWidget.selectedForeground": foreground,
            # === Peek View ===
            "peekView.border": primary,
            "peekViewEditor.background": surface,
            "peekViewEditor.matchHighlightBackground": _rgba(primary, 0.30),
            "peekViewEditorGutter.background": surface,
            "peekViewResult.background": background,
            "peekViewResult.fileForeground": foreground,
            "peekViewResult.lineForeground": on_surface_variant,
            "peekViewResult.matchHighlightBackground": _rgba(primary, 0.25),
            "peekViewResult.selectionBackground": _rgba(primary, 0.20),
            "peekViewResult.selectionForeground": foreground,
            "peekViewTitle.background": surface_container,
            "peekViewTitleDescription.foreground": on_surface_variant,
            "peekViewTitleLabel.foreground": primary,
            # === Merge Conflicts ===
            "merge.currentHeaderBackground": _rgba(primary, 0.30),
            "merge.currentContentBackground": _rgba(primary, 0.10),
            "merge.incomingHeaderBackground": _rgba(tertiary, 0.30),
            "merge.incomingContentBackground": _rgba(tertiary, 0.10),
            "merge.border": outline,
            "merge.commonHeaderBackground": _rgba(outline, 0.30),
            "merge.commonContentBackground": _rgba(outline, 0.10),
            # === Diff Editor ===
            "diffEditor.insertedTextBackground": _rgba(tertiary, 0.15),
            "diffEditor.insertedLineBackground": _rgba(tertiary, 0.08),
            "diffEditor.removedTextBackground": _rgba(error, 0.15),
            "diffEditor.removedLineBackground": _rgba(error, 0.08),
            "diffEditor.diagonalFill": _rgba(outline, 0.20),
            "diffEditor.move.border": primary,
            "diffEditor.moveActive.border": primary,
            "diffEditor.unchangedRegionBackground": surface_container,
            "diffEditor.unchangedRegionForeground": on_surface_variant,
            # === Charts ===
            "charts.foreground": foreground,
            "charts.lines": outline,
            "charts.red": error,
            "charts.blue": primary,
            "charts.yellow": tertiary,
            "charts.orange": _mix(error, tertiary, 0.5),
            "charts.green": tertiary,
            "charts.purple": secondary,
            # === Buttons ===
            "button.background": primary,
            "button.foreground": on_primary,
            "button.border": "transparent",
            "button.hoverBackground": _adjust_lightness(
                primary, 0.08 if is_dark else -0.08
            ),
            "button.secondaryBackground": surface_container,
            "button.secondaryForeground": foreground,
            "button.secondaryHoverBackground": surface_container_high,
            "checkbox.background": surface_container,
            "checkbox.foreground": foreground,
            "checkbox.border": outline_variant,
            # === Welcome Page ===
            "welcomePage.background": background,
            "welcomePage.foreground": on_surface_variant,
            "welcomePage.progress.background": primary,
            "welcomePage.progress.foreground": on_primary,
            "welcomeTile.background": surface_container,
            "welcomeTile.foreground": foreground,
            "welcomeTile.hoverBackground": surface_container_high,
            "welcomeTile.border": outline_variant,
            # === Walkthrough ===
            "walkThrough.embeddedEditorBackground": surface,
            # === Debug ===
            "debugToolBar.background": surface_container,
            "debugToolBar.border": outline_variant,
            "debugExceptionWidget.background": error_container,
            "debugExceptionWidget.border": error,
            "debugTokenExpression.number": tertiary,
            "debugTokenExpression.boolean": secondary,
            "debugTokenExpression.string": primary,
            "debugView.stateLabelBackground": _rgba(primary, 0.15),
            "debugView.stateLabelForeground": foreground,
            "debugView.valueChangedHighlight": tertiary,
            # === Testing ===
            "testing.iconErrored": error,
            "testing.iconFailed": error,
            "testing.iconPassed": tertiary,
            "testing.iconQueued": outline,
            "testing.iconUnset": on_surface_variant,
            "testing.iconSkipped": outline,
            "testing.runAction": primary,
            "testing.message.error.decorationForeground": error,
            "testing.message.error.lineBackground": _rgba(error, 0.10),
            "testing.message.hint.decorationForeground": on_surface_variant,
            "testing.message.hint.lineBackground": _rgba(primary, 0.05),
            # === Extensions ===
            "extensionButton.prominentBackground": primary,
            "extensionButton.prominentForeground": on_primary,
            "extensionButton.prominentHoverBackground": _adjust_lightness(
                primary, 0.08 if is_dark else -0.08
            ),
            "extensionButton.background": surface_container,
            "extensionButton.foreground": foreground,
            "extensionButton.hoverBackground": surface_container_high,
            "extensionBadge.remoteBackground": primary,
            "extensionBadge.remoteForeground": on_primary,
            "extensionIcon.starForeground": tertiary,
            "extensionIcon.verifiedForeground": tertiary,
            "extensionIcon.preReleaseForeground": outline,
            "extensionIcon.sponsorForeground": secondary,
            # === Git ===
            "gitDecoration.addedResourceForeground": tertiary,
            "gitDecoration.modifiedResourceForeground": primary,
            "gitDecoration.deletedResourceForeground": error,
            "gitDecoration.renamedResourceForeground": primary,
            "gitDecoration.stageModifiedResourceForeground": primary,
            "gitDecoration.stageDeletedResourceForeground": error,
            "gitDecoration.untrackedResourceForeground": tertiary,
            "gitDecoration.ignoredResourceForeground": outline,
            "gitDecoration.conflictingResourceForeground": secondary,
            "gitDecoration.submoduleResourceForeground": on_surface_variant,
            # === Problems ===
            "problemsErrorIcon.foreground": error,
            "problemsWarningIcon.foreground": tertiary,
            "problemsInfoIcon.foreground": primary,
            # === Settings ===
            "settings.headerForeground": foreground,
            "settings.modifiedItemIndicator": primary,
            "settings.dropdownBackground": surface_container,
            "settings.dropdownForeground": foreground,
            "settings.dropdownBorder": outline_variant,
            "settings.dropdownListBorder": outline_variant,
            "settings.checkboxBackground": surface_container,
            "settings.checkboxForeground": foreground,
            "settings.checkboxBorder": outline_variant,
            "settings.rowHoverBackground": surface_container,
            "settings.textInputBackground": surface_container,
            "settings.textInputForeground": foreground,
            "settings.textInputBorder": outline_variant,
            "settings.numberInputBackground": surface_container,
            "settings.numberInputForeground": foreground,
            "settings.numberInputBorder": outline_variant,
            "settings.focusedRowBackground": _rgba(primary, 0.08),
            "settings.focusedRowBorder": primary,
            # === Keybinding ===
            "keybindingLabel.background": surface_container,
            "keybindingLabel.foreground": foreground,
            "keybindingLabel.border": outline_variant,
            "keybindingLabel.bottomBorder": outline_variant,
            # === Snippet ===
            "editor.snippetFinalTabstopHighlightBorder": primary,
            "editor.snippetFinalTabstopHighlightBackground": _rgba(primary, 0.15),
            "editor.snippetTabstopHighlightBackground": _rgba(primary, 0.10),
            "editor.snippetTabstopHighlightBorder": outline_variant,
            # === Symbol Icons ===
            "symbolIcon.arrayForeground": secondary,
            "symbolIcon.booleanForeground": secondary,
            "symbolIcon.classForeground": primary,
            "symbolIcon.colorForeground": tertiary,
            "symbolIcon.constantForeground": primary,
            "symbolIcon.constructorForeground": primary,
            "symbolIcon.enumeratorForeground": primary,
            "symbolIcon.enumeratorMemberForeground": primary,
            "symbolIcon.eventForeground": secondary,
            "symbolIcon.fieldForeground": foreground,
            "symbolIcon.fileForeground": foreground,
            "symbolIcon.folderForeground": on_surface_variant,
            "symbolIcon.functionForeground": primary,
            "symbolIcon.interfaceForeground": primary,
            "symbolIcon.keyForeground": secondary,
            "symbolIcon.keywordForeground": secondary,
            "symbolIcon.methodForeground": primary,
            "symbolIcon.moduleForeground": on_surface_variant,
            "symbolIcon.namespaceForeground": on_surface_variant,
            "symbolIcon.nullForeground": outline,
            "symbolIcon.numberForeground": tertiary,
            "symbolIcon.objectForeground": foreground,
            "symbolIcon.operatorForeground": foreground,
            "symbolIcon.packageForeground": on_surface_variant,
            "symbolIcon.propertyForeground": foreground,
            "symbolIcon.referenceForeground": on_surface_variant,
            "symbolIcon.snippetForeground": foreground,
            "symbolIcon.stringForeground": tertiary,
            "symbolIcon.structForeground": primary,
            "symbolIcon.textForeground": foreground,
            "symbolIcon.typeParameterForeground": secondary,
            "symbolIcon.unitForeground": tertiary,
            "symbolIcon.variableForeground": foreground,
            # === Editor Lightbulb ===
            "editorLightBulb.foreground": tertiary,
            "editorLightBulbAutoFix.foreground": primary,
            "editorLightBulbAi.foreground": secondary,
            # === Bracket Pair Colorization ===
            "editorBracketHighlight.foreground1": primary,
            "editorBracketHighlight.foreground2": secondary,
            "editorBracketHighlight.foreground3": tertiary,
            "editorBracketHighlight.foreground4": error,
            "editorBracketHighlight.foreground5": tertiary,
            "editorBracketHighlight.foreground6": secondary,
            "editorBracketHighlight.unexpectedBracket.foreground": error,
            # === Sticky Scroll ===
            "editorStickyScroll.background": surface,
            "editorStickyScroll.border": outline_variant,
            "editorStickyScroll.shadow": _rgba("#000000", 0.30),
            "editorStickyScrollHover.background": surface_container,
            # === Inline Values (Debug) ===
            "editor.inlineValuesBackground": _rgba(primary, 0.05),
            "editor.inlineValuesForeground": on_surface_variant,
            # === Guides ===
            "guide.activeBackground": outline,
            "guide.background": outline_variant,
            "guide.hoverBackground": on_surface_variant,
            # === Comments ===
            "editorGutter.commentRangeForeground": outline,
            "editorGutter.foldingControlForeground": on_surface_variant,
            # === Search ===
            "searchEditor.findMatchBackground": _rgba(primary, 0.25),
            "searchEditor.findMatchBorder": primary,
            "searchEditor.textInputBorder": outline_variant,
            # === Multi Diff Editor ===
            "multiDiffEditor.border": outline_variant,
            "multiDiffEditor.headerBackground": surface_container,
            # === Simple Find Widget ===
            "simpleFindWidget.sashBorder": outline_variant,
            # === Terminalansi ===
            "terminal.ansiBrightBlack": outline,
            "terminal.ansiBrightBlue": colors.get("term12", "#89b4fa"),
            "terminal.ansiBrightCyan": colors.get("term14", tertiary),
            "terminal.ansiBrightGreen": colors.get("term10", "#a6e3a1"),
            "terminal.ansiBrightMagenta": colors.get("term13", secondary),
            "terminal.ansiBrightRed": colors.get("term9", error),
            "terminal.ansiBrightWhite": on_surface if is_dark else background,
            "terminal.ansiBrightYellow": colors.get("term11", "#f9e2af"),
        },
        # No tokenColors - preserves VSCode's default syntax highlighting
        "tokenColors": [],
    }

    return theme


def _ensure_extension_structure(base_path: Path) -> None:
    """Create the extension directory structure if needed."""
    base_path.parent.parent.mkdir(parents=True, exist_ok=True)
    base_path.parent.mkdir(parents=True, exist_ok=True)

    # Write package.json if it doesn't exist
    package_json_path = base_path.parent.parent / "package.json"
    if not package_json_path.exists():
        with package_json_path.open("w", encoding="utf-8") as f:
            json.dump(PACKAGE_JSON, f, indent=2)
        print(f"Created: {package_json_path}")


def _write_theme(theme: Dict) -> None:
    """Write the theme to all VSCode extension directories."""
    written = False

    for path in THEME_OUTPUT_PATHS:
        try:
            _ensure_extension_structure(path)
            with path.open("w", encoding="utf-8") as f:
                json.dump(theme, f, indent=2)
            print(f"Generated: {path}")
            written = True
        except PermissionError:
            print(f"Permission denied: {path}")
        except Exception as e:
            print(f"Error writing to {path}: {e}")

    if not written:
        # Create at least one location
        default_path = THEME_OUTPUT_PATHS[0]
        _ensure_extension_structure(default_path)
        with default_path.open("w", encoding="utf-8") as f:
            json.dump(theme, f, indent=2)
        print(f"Generated: {default_path}")


def main() -> None:
    try:
        colors = _load_colors()
    except FileNotFoundError as exc:
        print(f"Error: {exc}")
        return

    theme = _build_vscode_theme(colors)
    _write_theme(theme)
    print("VSCode theme generated successfully!")
    print("Select 'iNiR Material' theme in VSCode to apply.")


if __name__ == "__main__":
    main()
