package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"inir/scripts/colors/themegencommon"
)

const (
	themeName = "inir-live"
)

func main() {
	var scssPath string
	var colorsPath string
	var terminalPath string
	flag.StringVar(&scssPath, "scss", "", "path to material_colors.scss")
	flag.StringVar(&colorsPath, "colors", "", "path to palette/colors json")
	flag.StringVar(&terminalPath, "terminal-json", "", "path to terminal palette json")
	flag.Parse()

	if scssPath == "" {
		fmt.Fprintln(os.Stderr, "missing --scss")
		os.Exit(1)
	}

	colors, err := loadMergedColors(scssPath, colorsPath, terminalPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "load palette: %v\n", err)
		os.Exit(1)
	}

	themeDir, configPath, err := cliampPaths()
	if err != nil {
		fmt.Fprintf(os.Stderr, "cliamp paths: %v\n", err)
		os.Exit(1)
	}

	if err := os.MkdirAll(themeDir, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "mkdir theme dir: %v\n", err)
		os.Exit(1)
	}

	themePath := filepath.Join(themeDir, themeName+".toml")
	if err := writeThemeFile(themePath, colors); err != nil {
		fmt.Fprintf(os.Stderr, "write theme: %v\n", err)
		os.Exit(1)
	}

	if err := ensureThemeSelected(configPath, themeName); err != nil {
		fmt.Fprintf(os.Stderr, "write config: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("updated %s and pinned cliamp theme to %q\n", themePath, themeName)
}

func loadMergedColors(scssPath, colorsPath, terminalPath string) (map[string]string, error) {
	scssColors, err := themegencommon.ParseSCSS(scssPath)
	if err != nil {
		return nil, err
	}

	var colorJSON map[string]string
	if colorsPath != "" {
		if loaded, err := themegencommon.ReadStringMapJSON(colorsPath); err == nil {
			colorJSON = loaded
		}
	}

	var terminalJSON map[string]string
	if terminalPath != "" {
		if loaded, err := themegencommon.ReadStringMapJSON(terminalPath); err == nil {
			terminalJSON = loaded
		}
	}

	return themegencommon.MergeStringMaps(scssColors, colorJSON, terminalJSON), nil
}

func cliampPaths() (string, string, error) {
	configHome, err := os.UserConfigDir()
	if err != nil {
		return "", "", err
	}

	root := filepath.Join(configHome, "cliamp")
	return filepath.Join(root, "themes"), filepath.Join(root, "config.toml"), nil
}

func writeThemeFile(path string, colors map[string]string) error {
	content := fmt.Sprintf(
		"accent = %q\nbright_fg = %q\nfg = %q\ngreen = %q\nyellow = %q\nred = %q\n",
		pickColor(colors, []string{"primary", "accent", "term6", "term12"}, "#89b4fa"),
		pickColor(colors, []string{"onBackground", "bright_fg", "term15", "term7"}, "#cdd6f4"),
		pickColor(colors, []string{"onSurfaceVariant", "outline", "fg", "term8", "term7"}, "#a6adc8"),
		pickColor(colors, []string{"success", "green", "term10", "term2"}, "#a6e3a1"),
		pickColor(colors, []string{"warning", "yellow", "term11", "term3"}, "#f9e2af"),
		pickColor(colors, []string{"error", "red", "term9", "term1"}, "#f38ba8"),
	)
	return writeAtomic(path, []byte(content), 0o644)
}

func ensureThemeSelected(path, theme string) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	data, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return err
	}

	themeLine := fmt.Sprintf("theme = %q", theme)
	if len(data) == 0 {
		return writeAtomic(path, []byte(themeLine+"\n"), 0o644)
	}

	re := regexp.MustCompile(`(?m)^theme\s*=\s*["'][^"']*["']\s*$`)
	updated := data
	if re.Match(data) {
		updated = re.ReplaceAll(data, []byte(themeLine))
	} else {
		if len(updated) > 0 && updated[len(updated)-1] != '\n' {
			updated = append(updated, '\n')
		}
		updated = append(updated, []byte(themeLine+"\n")...)
	}

	if bytes.Equal(data, updated) {
		return nil
	}
	return writeAtomic(path, updated, 0o644)
}

func pickColor(colors map[string]string, keys []string, fallback string) string {
	for _, key := range keys {
		if value, ok := colors[key]; ok && isHexColor(value) {
			return strings.ToLower(value)
		}
	}
	return fallback
}

func isHexColor(value string) bool {
	if len(value) != 7 || value[0] != '#' {
		return false
	}
	for _, ch := range value[1:] {
		switch {
		case ch >= '0' && ch <= '9':
		case ch >= 'a' && ch <= 'f':
		case ch >= 'A' && ch <= 'F':
		default:
			return false
		}
	}
	return true
}

func writeAtomic(path string, data []byte, mode os.FileMode) error {
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, mode); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
