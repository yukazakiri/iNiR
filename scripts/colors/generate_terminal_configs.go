package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

func main() {
	args := os.Args[1:]
	parsed := parseArgs(args)
	exitCode := 0

	if parsed.scssPath == "" {
		parsed.scssPath = expandPath("~/.local/state/quickshell/user/generated/material_colors.scss")
	}

	colors, err := parseScssColors(parsed.scssPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if len(colors) == 0 {
		fmt.Fprintln(os.Stderr, "Error: No colors found in SCSS file")
		os.Exit(1)
	}

	home, _ := os.UserHomeDir()
	terminals := normalizeTerminals(parsed.terminals)

	if contains(terminals, "kitty") {
		generateKittyConfig(colors, filepath.Join(home, ".config/kitty/current-theme.conf"))
	}
	if contains(terminals, "alacritty") {
		generateAlacrittyConfig(colors, filepath.Join(home, ".config/alacritty/colors.toml"))
	}
	if contains(terminals, "foot") {
		generateFootConfig(colors, filepath.Join(home, ".config/foot/colors.ini"))
	}
	if contains(terminals, "wezterm") {
		generateWeztermConfig(colors, filepath.Join(home, ".config/wezterm/colors.lua"))
	}
	if contains(terminals, "ghostty") {
		generateGhosttyConfig(colors, filepath.Join(home, ".config/ghostty/themes/ii-auto"))
	}
	if contains(terminals, "konsole") {
		generateKonsoleConfig(colors, filepath.Join(home, ".local/share/konsole/ii-auto.colorscheme"))
	}
	if contains(terminals, "starship") {
		generateStarshipConfig(colors, filepath.Join(home, ".config/starship/ii-palette.toml"))
	}
	if contains(terminals, "omp") {
		m3Colors := loadColorsJSON(expandPath("~/.local/state/quickshell/user/generated/colors.json"))
		merged := mergeMaps(colors, m3Colors)
		generateOmpConfig(merged, filepath.Join(home, ".config/oh-my-posh/ii-auto.json"))
	}
	if contains(terminals, "btop") {
		m3Colors := loadColorsJSON(expandPath("~/.local/state/quickshell/user/generated/colors.json"))
		merged := mergeMaps(colors, m3Colors)
		generateBtopConfig(merged, filepath.Join(home, ".config/btop/themes/ii-auto.theme"))
	}
	if contains(terminals, "lazygit") {
		generateLazygitConfig(colors, filepath.Join(home, ".config/lazygit/ii-theme.yml"))
	}
	if contains(terminals, "yazi") {
		generateYaziConfig(colors, filepath.Join(home, ".config/yazi/flavors/ii-auto.yazi/flavor.toml"))
	}

	if parsed.zed {
		err := runZedGenerator(parsed.scssPath, filepath.Join(home, ".config/zed/themes/ii-theme.json"))
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			exitCode = 1
		}
	}

	if parsed.vscode {
		if err := runVSCodeGenerator(parsed.scssPath, parsed.vscodeForks); err != nil {
			fmt.Fprintln(os.Stderr, err)
			exitCode = 1
		}
	}
	if exitCode != 0 {
		os.Exit(exitCode)
	}
}

type parsedArgs struct {
	scssPath    string
	terminals   []string
	zed         bool
	vscode      bool
	vscodeForks []string
}

func parseArgs(args []string) parsedArgs {
	out := parsedArgs{terminals: []string{"all"}}

	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch arg {
		case "--scss":
			if i+1 < len(args) {
				out.scssPath = args[i+1]
				i++
			}
		case "--terminals":
			out.terminals = consumeList(args, &i)
		case "--zed":
			out.zed = true
		case "--vscode":
			out.vscode = true
		case "--vscode-forks":
			out.vscodeForks = consumeList(args, &i)
		default:
			if strings.HasPrefix(arg, "--") {
				continue
			}
		}
	}

	return out
}

func consumeList(args []string, i *int) []string {
	values := []string{}
	for j := *i + 1; j < len(args); j++ {
		if strings.HasPrefix(args[j], "--") {
			*i = j - 1
			return values
		}
		values = append(values, args[j])
	}
	*i = len(args) - 1
	return values
}

func normalizeTerminals(terminals []string) []string {
	if len(terminals) == 0 {
		return []string{"kitty", "alacritty", "foot", "wezterm", "ghostty", "konsole", "starship", "omp", "btop", "lazygit", "yazi"}
	}
	if contains(terminals, "all") {
		return []string{"kitty", "alacritty", "foot", "wezterm", "ghostty", "konsole", "starship", "omp", "btop", "lazygit", "yazi"}
	}
	return terminals
}

func parseScssColors(path string) (map[string]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("Error: Could not find %s", path)
	}

	colors := map[string]string{}
	re := regexp.MustCompile(`^\$(\w+):\s*(#[A-Fa-f0-9]{6});`)
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		match := re.FindStringSubmatch(line)
		if match != nil {
			colors[match[1]] = match[2]
		}
	}
	return colors, nil
}

func ensureLineInFile(path, lineToAdd, checkPattern string, atTop bool) bool {
	path = expandPath(path)
	_ = os.MkdirAll(filepath.Dir(path), 0o755)

	content := ""
	if data, err := os.ReadFile(path); err == nil {
		content = string(data)
		if checkPattern != "" {
			re := regexp.MustCompile(checkPattern)
			if re.MatchString(content) {
				return false
			}
		} else if strings.Contains(content, lineToAdd) {
			return false
		}
	}

	if atTop {
		content = lineToAdd + "\n" + content
	} else {
		if content != "" && !strings.HasSuffix(content, "\n") {
			content += "\n"
		}
		content += lineToAdd + "\n"
	}

	_ = os.WriteFile(path, []byte(content), 0o644)
	return true
}

func generateKittyConfig(colors map[string]string, outputPath string) {
	config := fmt.Sprintf(`# Auto-generated by ii wallpaper theming system
# Do not edit manually - changes will be overwritten

# The basic colors
foreground              %s
background              %s
selection_foreground    %s
selection_background    %s

# Cursor colors
cursor                  %s
cursor_text_color       %s

# URL underline color when hovering with mouse
url_color               %s

# Kitty window border colors
active_border_color     %s
inactive_border_color   %s
bell_border_color       %s

# Tab bar colors
active_tab_foreground   %s
active_tab_background   %s
inactive_tab_foreground %s
inactive_tab_background %s
tab_bar_background      %s

# The 16 terminal colors

# black
color0 %s
color8 %s

# red
color1 %s
color9 %s

# green
color2  %s
color10 %s

# yellow
color3  %s
color11 %s

# blue
color4  %s
color12 %s

# magenta
color5  %s
color13 %s

# cyan
color6  %s
color14 %s

# white
color7  %s
color15 %s
`,
		color(colors, "term7", "#A89984"),
		color(colors, "term0", "#282828"),
		color(colors, "term0", "#282828"),
		color(colors, "term7", "#A89984"),
		color(colors, "term7", "#A89984"),
		color(colors, "term0", "#282828"),
		color(colors, "term4", "#458588"),
		color(colors, "primary", "#458588"),
		color(colors, "term8", "#928374"),
		color(colors, "term1", "#CC241D"),
		color(colors, "onPrimary", "#FFFFFF"),
		color(colors, "primary", "#458588"),
		color(colors, "term7", "#A89984"),
		color(colors, "term8", "#928374"),
		color(colors, "term0", "#282828"),
		color(colors, "term0", "#282828"),
		color(colors, "term8", "#928374"),
		color(colors, "term1", "#CC241D"),
		color(colors, "term9", "#FB4934"),
		color(colors, "term2", "#98971A"),
		color(colors, "term10", "#B8BB26"),
		color(colors, "term3", "#D79921"),
		color(colors, "term11", "#FABD2F"),
		color(colors, "term4", "#458588"),
		color(colors, "term12", "#83A598"),
		color(colors, "term5", "#B16286"),
		color(colors, "term13", "#D3869B"),
		color(colors, "term6", "#689D6A"),
		color(colors, "term14", "#8EC07C"),
		color(colors, "term7", "#A89984"),
		color(colors, "term15", "#EBDBB2"),
	)

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)

	themeConf := filepath.Join(filepath.Dir(outputPath), "theme.conf")
	_ = os.WriteFile(themeConf, []byte(config), 0o644)

	tmpLink := outputPath + ".tmp"
	if _, err := os.Lstat(tmpLink); err == nil {
		_ = os.Remove(tmpLink)
	}
	_ = os.Symlink("theme.conf", tmpLink)
	_ = os.Rename(tmpLink, outputPath)

	home, _ := os.UserHomeDir()
	kittyConf := filepath.Join(home, ".config/kitty/kitty.conf")
	if ensureLineInFile(kittyConf, "include current-theme.conf", `include\s+current-theme\.conf`, false) {
		fmt.Println("✓ Generated Kitty config and auto-integrated")
	} else {
		fmt.Println("✓ Generated Kitty config (already integrated)")
	}

	reloadKitty()
}

func reloadKitty() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "pkill", "--signal", "SIGUSR1", "-x", "kitty")
	_ = cmd.Run()
	if ctx.Err() == nil {
		fmt.Println("  → Live-reloaded Kitty config (SIGUSR1)")
	}
}

func generateAlacrittyConfig(colors map[string]string, outputPath string) {
	config := fmt.Sprintf(`# Auto-generated by ii wallpaper theming system
# Do not edit manually - changes will be overwritten

[colors.primary]
background = '%s'
foreground = '%s'

[colors.cursor]
text   = '%s'
cursor = '%s'

[colors.selection]
text       = '%s'
background = '%s'

[colors.normal]
black   = '%s'
red     = '%s'
green   = '%s'
yellow  = '%s'
blue    = '%s'
magenta = '%s'
cyan    = '%s'
white   = '%s'

[colors.bright]
black   = '%s'
red     = '%s'
green   = '%s'
yellow  = '%s'
blue    = '%s'
magenta = '%s'
cyan    = '%s'
white   = '%s'
`,
		color(colors, "term0", "#282828"),
		color(colors, "term7", "#A89984"),
		color(colors, "term0", "#282828"),
		color(colors, "term7", "#A89984"),
		color(colors, "term0", "#282828"),
		color(colors, "term7", "#A89984"),
		color(colors, "term0", "#282828"),
		color(colors, "term1", "#CC241D"),
		color(colors, "term2", "#98971A"),
		color(colors, "term3", "#D79921"),
		color(colors, "term4", "#458588"),
		color(colors, "term5", "#B16286"),
		color(colors, "term6", "#689D6A"),
		color(colors, "term7", "#A89984"),
		color(colors, "term8", "#928374"),
		color(colors, "term9", "#FB4934"),
		color(colors, "term10", "#B8BB26"),
		color(colors, "term11", "#FABD2F"),
		color(colors, "term12", "#83A598"),
		color(colors, "term13", "#D3869B"),
		color(colors, "term14", "#8EC07C"),
		color(colors, "term15", "#EBDBB2"),
	)

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)
	_ = os.WriteFile(outputPath, []byte(config), 0o644)

	home, _ := os.UserHomeDir()
	alacrittyConf := filepath.Join(home, ".config/alacritty/alacritty.toml")
	if fileExists(alacrittyConf) {
		modified, message := fixAlacrittyImportOrder(alacrittyConf)
		fmt.Printf("✓ Generated Alacritty config (%s)\n", message)
		if modified {
			return
		}
	} else {
		newConf := "# iNiR wallpaper theming\n[general]\nimport = [\"~/.config/alacritty/colors.toml\"]\n"
		_ = os.MkdirAll(filepath.Dir(alacrittyConf), 0o755)
		_ = os.WriteFile(alacrittyConf, []byte(newConf), 0o644)
		fmt.Println("✓ Generated Alacritty config and created new config file")
	}
}

func fixAlacrittyImportOrder(configPath string) (bool, string) {
	contentBytes, err := os.ReadFile(configPath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return false, "Config file not found"
		}
		if errors.Is(err, os.ErrPermission) {
			return false, "Permission denied"
		}
		return false, err.Error()
	}
	content := string(contentBytes)

	importLine := `import = ["~/.config/alacritty/colors.toml"]`
	bareImportPat := regexp.MustCompile(`^import\s*=\s*\[.*?colors\.toml.*?\]`)
	generalImportPat := regexp.MustCompile(`import\s*=\s*\[.*?colors\.toml.*?\]`)

	hasHardcoded := regexp.MustCompile(`^\[colors\.(primary|normal|bright)\]`).MatchString(content)

	lines := strings.Split(content, "\n")
	topLines := []string{}
	for _, line := range lines {
		trim := strings.TrimSpace(line)
		if trim == "" || strings.HasPrefix(trim, "#") {
			continue
		}
		topLines = append(topLines, trim)
		if len(topLines) >= 10 {
			break
		}
	}

	correct := len(topLines) >= 2 && topLines[0] == "[general]" && generalImportPat.MatchString(topLines[1]) && !hasHardcoded
	if correct {
		return false, "Config is already correct"
	}

	timestamp := time.Now().Format("20060102_150405")
	backupPath := fmt.Sprintf("%s.backup_%s", configPath, timestamp)
	if err := os.WriteFile(backupPath, contentBytes, 0o644); err != nil {
		return false, fmt.Sprintf("Failed to create backup: %v", err)
	}

	newLines := []string{
		"# iNiR wallpaper theming - import must be at top to override colors",
		"[general]",
		importLine,
	}

	inGeneral := false
	inColorsSection := false
	addedColorsComment := false

	for _, line := range lines {
		stripped := strings.TrimSpace(line)

		if bareImportPat.MatchString(stripped) {
			continue
		}
		if strings.HasPrefix(stripped, "# iNiR wallpaper theming") {
			continue
		}

		if stripped == "[general]" {
			inGeneral = true
			continue
		}
		if inGeneral {
			if strings.HasPrefix(stripped, "[") && stripped != "[general]" {
				inGeneral = false
			} else if generalImportPat.MatchString(stripped) {
				continue
			} else if stripped != "" {
				newLines = append(newLines, stripped)
				continue
			} else {
				continue
			}
		}

		if regexp.MustCompile(`^\[colors\.(primary|normal|bright|cursor|selection)\]`).MatchString(stripped) {
			if !addedColorsComment {
				inColorsSection = true
				addedColorsComment = true
				newLines = append(newLines, "", "# Color definitions commented out by iNiR wallpaper theming", "# Colors are managed via the import in [general] above", "#")
			}
			newLines = append(newLines, "# "+line)
			continue
		}

		if inColorsSection {
			if strings.HasPrefix(stripped, "[") && !strings.HasPrefix(stripped, "[colors") {
				inColorsSection = false
				newLines = append(newLines, "", line)
			} else if stripped != "" && strings.Contains(stripped, "=") {
				newLines = append(newLines, "# "+line)
			} else {
				if stripped != "" {
					newLines = append(newLines, "# "+line)
				} else {
					newLines = append(newLines, "")
				}
			}
			continue
		}

		newLines = append(newLines, line)
	}

	if err := os.WriteFile(configPath, []byte(strings.Join(newLines, "\n")), 0o644); err != nil {
		_ = os.WriteFile(configPath, contentBytes, 0o644)
		return false, fmt.Sprintf("Failed to write config: %v", err)
	}

	return true, fmt.Sprintf("Fixed config (backup: %s)", backupPath)
}

func generateFootConfig(colors map[string]string, outputPath string) {
	strip := func(val string) string {
		return strings.TrimPrefix(val, "#")
	}

	config := fmt.Sprintf(`# Auto-generated by ii wallpaper theming system
# Do not edit manually - changes will be overwritten

[colors]
foreground=%s
background=%s

## Normal/regular colors (color palette 0-7)
regular0=%s  # black
regular1=%s  # red
regular2=%s  # green
regular3=%s  # yellow
regular4=%s  # blue
regular5=%s  # magenta
regular6=%s  # cyan
regular7=%s  # white

## Bright colors (color palette 8-15)
bright0=%s   # bright black
bright1=%s   # bright red
bright2=%s  # bright green
bright3=%s  # bright yellow
bright4=%s  # bright blue
bright5=%s  # bright magenta
bright6=%s  # bright cyan
bright7=%s  # bright white

## Cursor and selection colors
selection-foreground=%s
selection-background=%s
jump-labels=%s %s
urls=%s
`,
		strip(color(colors, "term7", "#A89984")),
		strip(color(colors, "term0", "#282828")),
		strip(color(colors, "term0", "#282828")),
		strip(color(colors, "term1", "#CC241D")),
		strip(color(colors, "term2", "#98971A")),
		strip(color(colors, "term3", "#D79921")),
		strip(color(colors, "term4", "#458588")),
		strip(color(colors, "term5", "#B16286")),
		strip(color(colors, "term6", "#689D6A")),
		strip(color(colors, "term7", "#A89984")),
		strip(color(colors, "term8", "#928374")),
		strip(color(colors, "term9", "#FB4934")),
		strip(color(colors, "term10", "#B8BB26")),
		strip(color(colors, "term11", "#FABD2F")),
		strip(color(colors, "term12", "#83A598")),
		strip(color(colors, "term13", "#D3869B")),
		strip(color(colors, "term14", "#8EC07C")),
		strip(color(colors, "term15", "#EBDBB2")),
		strip(color(colors, "term0", "#282828")),
		strip(color(colors, "term7", "#A89984")),
		strip(color(colors, "term0", "#282828")),
		strip(color(colors, "term3", "#D79921")),
		strip(color(colors, "term4", "#458588")),
	)

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)
	_ = os.WriteFile(outputPath, []byte(config), 0o644)

	home, _ := os.UserHomeDir()
	footConf := filepath.Join(home, ".config/foot/foot.ini")
	if ensureLineInFile(footConf, "include=~/.config/foot/colors.ini", `include\s*=.*colors\.ini`, true) {
		fmt.Println("✓ Generated Foot config and auto-integrated")
	} else {
		fmt.Println("✓ Generated Foot config (already integrated)")
	}

	removeFootLegacyInclude(footConf)
}

func removeFootLegacyInclude(path string) {
	path = expandPath(path)
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	re := regexp.MustCompile(`(?m)^include\s*=\s*~/.config/foot/colors\.ini\s*\n?`)
	newContent := re.ReplaceAllString(string(data), "")
	if newContent != string(data) {
		_ = os.WriteFile(path, []byte(newContent), 0o644)
	}
}

func generateWeztermConfig(colors map[string]string, outputPath string) {
	config := fmt.Sprintf(`-- Auto-generated by ii wallpaper theming system
-- Do not edit manually - changes will be overwritten

return {
  foreground = '%s',
  background = '%s',

  cursor_bg = '%s',
  cursor_fg = '%s',
  cursor_border = '%s',

  selection_fg = '%s',
  selection_bg = '%s',

  scrollbar_thumb = '%s',
  split = '%s',

  ansi = {
    '%s',  -- black
    '%s',  -- red
    '%s',  -- green
    '%s',  -- yellow
    '%s',  -- blue
    '%s',  -- magenta
    '%s',  -- cyan
    '%s',  -- white
  },

  brights = {
    '%s',  -- bright black
    '%s',  -- bright red
    '%s', -- bright green
    '%s', -- bright yellow
    '%s', -- bright blue
    '%s', -- bright magenta
    '%s', -- bright cyan
    '%s', -- bright white
  },

  tab_bar = {
    background = '%s',
    active_tab = {
      bg_color = '%s',
      fg_color = '%s',
    },
    inactive_tab = {
      bg_color = '%s',
      fg_color = '%s',
    },
    inactive_tab_hover = {
      bg_color = '%s',
      fg_color = '%s',
    },
  },
}
`,
		color(colors, "term7", "#A89984"),
		color(colors, "term0", "#282828"),
		color(colors, "term7", "#A89984"),
		color(colors, "term0", "#282828"),
		color(colors, "term7", "#A89984"),
		color(colors, "term0", "#282828"),
		color(colors, "term7", "#A89984"),
		color(colors, "term8", "#928374"),
		color(colors, "term8", "#928374"),
		color(colors, "term0", "#282828"),
		color(colors, "term1", "#CC241D"),
		color(colors, "term2", "#98971A"),
		color(colors, "term3", "#D79921"),
		color(colors, "term4", "#458588"),
		color(colors, "term5", "#B16286"),
		color(colors, "term6", "#689D6A"),
		color(colors, "term7", "#A89984"),
		color(colors, "term8", "#928374"),
		color(colors, "term9", "#FB4934"),
		color(colors, "term10", "#B8BB26"),
		color(colors, "term11", "#FABD2F"),
		color(colors, "term12", "#83A598"),
		color(colors, "term13", "#D3869B"),
		color(colors, "term14", "#8EC07C"),
		color(colors, "term15", "#EBDBB2"),
		color(colors, "term0", "#282828"),
		color(colors, "primary", "#458588"),
		color(colors, "onPrimary", "#FFFFFF"),
		color(colors, "term8", "#928374"),
		color(colors, "term7", "#A89984"),
		color(colors, "term8", "#928374"),
		color(colors, "term15", "#EBDBB2"),
	)

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)
	_ = os.WriteFile(outputPath, []byte(config), 0o644)

	home, _ := os.UserHomeDir()
	weztermConf := filepath.Join(home, ".config/wezterm/wezterm.lua")
	integrationCode := "local wezterm = require('wezterm')\nlocal config = wezterm.config_builder()\nlocal colors = require('colors')\nconfig.colors = colors\nreturn config\n"

	if fileExists(weztermConf) {
		contentBytes, _ := os.ReadFile(weztermConf)
		content := string(contentBytes)
		if !strings.Contains(content, "require('colors')") {
			lines := strings.Split(content, "\n")
			for i, line := range lines {
				if strings.Contains(line, "return config") || strings.Contains(line, "return {") {
					lines = append(lines[:i], append([]string{"local colors = require('colors')", "config.colors = colors"}, lines[i:]...)...)
					break
				}
			}
			_ = os.WriteFile(weztermConf, []byte(strings.Join(lines, "\n")), 0o644)
			fmt.Println("✓ Generated WezTerm config and auto-integrated")
		} else {
			fmt.Println("✓ Generated WezTerm config (already integrated)")
		}
	} else {
		_ = os.MkdirAll(filepath.Dir(weztermConf), 0o755)
		_ = os.WriteFile(weztermConf, []byte(integrationCode), 0o644)
		fmt.Println("✓ Generated WezTerm config and auto-integrated (created config)")
	}
}

func generateGhosttyConfig(colors map[string]string, outputPath string) {
	config := fmt.Sprintf(`# Auto-generated by ii wallpaper theming system
# Do not edit manually - changes will be overwritten

background = %s
foreground = %s

cursor-color = %s
cursor-text = %s

selection-background = %s
selection-foreground = %s

palette = 0=%s
palette = 1=%s
palette = 2=%s
palette = 3=%s
palette = 4=%s
palette = 5=%s
palette = 6=%s
palette = 7=%s
palette = 8=%s
palette = 9=%s
palette = 10=%s
palette = 11=%s
palette = 12=%s
palette = 13=%s
palette = 14=%s
palette = 15=%s
`,
		color(colors, "term0", "#282828"),
		color(colors, "term7", "#A89984"),
		color(colors, "term7", "#A89984"),
		color(colors, "term0", "#282828"),
		color(colors, "term7", "#A89984"),
		color(colors, "term0", "#282828"),
		color(colors, "term0", "#282828"),
		color(colors, "term1", "#CC241D"),
		color(colors, "term2", "#98971A"),
		color(colors, "term3", "#D79921"),
		color(colors, "term4", "#458588"),
		color(colors, "term5", "#B16286"),
		color(colors, "term6", "#689D6A"),
		color(colors, "term7", "#A89984"),
		color(colors, "term8", "#928374"),
		color(colors, "term9", "#FB4934"),
		color(colors, "term10", "#B8BB26"),
		color(colors, "term11", "#FABD2F"),
		color(colors, "term12", "#83A598"),
		color(colors, "term13", "#D3869B"),
		color(colors, "term14", "#8EC07C"),
		color(colors, "term15", "#EBDBB2"),
	)

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)
	_ = os.WriteFile(outputPath, []byte(config), 0o644)

	home, _ := os.UserHomeDir()
	ghosttyConf := filepath.Join(home, ".config/ghostty/config")
	if ensureLineInFile(ghosttyConf, "include ~/.config/ghostty/themes/ii-auto", `include\s+.*ii-auto`, false) {
		fmt.Println("✓ Generated Ghostty config and auto-integrated")
	} else {
		fmt.Println("✓ Generated Ghostty config (already integrated)")
	}
}

func generateKonsoleConfig(colors map[string]string, outputPath string) {
	config := fmt.Sprintf(`[General]
Description=ii-auto
Opacity=1

[Background]
Color=%s

[BackgroundIntense]
Color=%s

[Foreground]
Color=%s

[ForegroundIntense]
Color=%s

[Color0]
Color=%s

[Color0Intense]
Color=%s

[Color1]
Color=%s

[Color1Intense]
Color=%s

[Color2]
Color=%s

[Color2Intense]
Color=%s

[Color3]
Color=%s

[Color3Intense]
Color=%s

[Color4]
Color=%s

[Color4Intense]
Color=%s

[Color5]
Color=%s

[Color5Intense]
Color=%s

[Color6]
Color=%s

[Color6Intense]
Color=%s

[Color7]
Color=%s

[Color7Intense]
Color=%s
`,
		konsoleRGB(color(colors, "term0", "#282828")),
		konsoleRGB(color(colors, "term8", "#928374")),
		konsoleRGB(color(colors, "term7", "#A89984")),
		konsoleRGB(color(colors, "term15", "#EBDBB2")),
		konsoleRGB(color(colors, "term0", "#282828")),
		konsoleRGB(color(colors, "term8", "#928374")),
		konsoleRGB(color(colors, "term1", "#CC241D")),
		konsoleRGB(color(colors, "term9", "#FB4934")),
		konsoleRGB(color(colors, "term2", "#98971A")),
		konsoleRGB(color(colors, "term10", "#B8BB26")),
		konsoleRGB(color(colors, "term3", "#D79921")),
		konsoleRGB(color(colors, "term11", "#FABD2F")),
		konsoleRGB(color(colors, "term4", "#458588")),
		konsoleRGB(color(colors, "term12", "#83A598")),
		konsoleRGB(color(colors, "term5", "#B16286")),
		konsoleRGB(color(colors, "term13", "#D3869B")),
		konsoleRGB(color(colors, "term6", "#689D6A")),
		konsoleRGB(color(colors, "term14", "#8EC07C")),
		konsoleRGB(color(colors, "term7", "#A89984")),
		konsoleRGB(color(colors, "term15", "#EBDBB2")),
	)

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)
	_ = os.WriteFile(outputPath, []byte(config), 0o644)

	home, _ := os.UserHomeDir()
	konsoleConf := filepath.Join(home, ".config/konsolerc")
	if fileExists(konsoleConf) {
		contentBytes, _ := os.ReadFile(konsoleConf)
		content := string(contentBytes)
		newLine := "ColorScheme=ii-auto"
		if regexp.MustCompile(`(?m)^ColorScheme=`).MatchString(content) {
			newContent := regexp.MustCompile(`(?m)^ColorScheme=.*$`).ReplaceAllString(content, newLine)
			if newContent != content {
				_ = os.WriteFile(konsoleConf, []byte(newContent), 0o644)
				fmt.Println("✓ Generated Konsole config and updated konsolerc")
			} else {
				fmt.Println("✓ Generated Konsole config (already using ii-auto)")
			}
		} else {
			konsoleConfPath := filepath.Dir(konsoleConf)
			_ = os.MkdirAll(konsoleConfPath, 0o755)
			_ = os.WriteFile(konsoleConf, []byte("[Desktop Entry]\nColorScheme=ii-auto\n"), 0o644)
			fmt.Println("✓ Generated Konsole config and created konsolerc")
		}
	} else {
		fmt.Println("✓ Generated Konsole config")
	}
}

func generateStarshipConfig(colors map[string]string, outputPath string) {
	config := fmt.Sprintf(`# Auto-generated by ii wallpaper theming system
# Do not edit manually - changes will be overwritten
# This file provides Material You colors to your Starship prompt

[palettes.ii]
primary = '%s'
onPrimary = '%s'
secondary = '%s'
onSecondary = '%s'
tertiary = '%s'
onTertiary = '%s'
surface = '%s'
onSurface = '%s'
background = '%s'
foreground = '%s'
black = '%s'
red = '%s'
green = '%s'
yellow = '%s'
blue = '%s'
magenta = '%s'
cyan = '%s'
white = '%s'
bright_black = '%s'
bright_red = '%s'
bright_green = '%s'
bright_yellow = '%s'
bright_blue = '%s'
bright_magenta = '%s'
bright_cyan = '%s'
bright_white = '%s'
`,
		color(colors, "primary", "#458588"),
		color(colors, "onPrimary", "#FFFFFF"),
		color(colors, "secondary", "#83A598"),
		color(colors, "onSecondary", "#1D2021"),
		color(colors, "tertiary", "#D3869B"),
		color(colors, "onTertiary", "#1D2021"),
		color(colors, "surface", "#1D2021"),
		color(colors, "onSurface", "#EBDBB2"),
		color(colors, "term0", "#282828"),
		color(colors, "term7", "#A89984"),
		color(colors, "term0", "#282828"),
		color(colors, "term1", "#CC241D"),
		color(colors, "term2", "#98971A"),
		color(colors, "term3", "#D79921"),
		color(colors, "term4", "#458588"),
		color(colors, "term5", "#B16286"),
		color(colors, "term6", "#689D6A"),
		color(colors, "term7", "#A89984"),
		color(colors, "term8", "#928374"),
		color(colors, "term9", "#FB4934"),
		color(colors, "term10", "#B8BB26"),
		color(colors, "term11", "#FABD2F"),
		color(colors, "term12", "#83A598"),
		color(colors, "term13", "#D3869B"),
		color(colors, "term14", "#8EC07C"),
		color(colors, "term15", "#EBDBB2"),
	)

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)
	_ = os.WriteFile(outputPath, []byte(config), 0o644)

	home, _ := os.UserHomeDir()
	starshipConf := filepath.Join(home, ".config/starship.toml")
	if fileExists(starshipConf) {
		contentBytes, _ := os.ReadFile(starshipConf)
		content := string(contentBytes)

		if strings.Contains(content, "palette = \"ii\"") {
			fmt.Println("✓ Generated Starship palette (already using ii palette)")
		} else {
			if !strings.Contains(content, "palette =") {
				newContent := "palette = \"ii\"\n\n" + content
				_ = os.WriteFile(starshipConf, []byte(newContent), 0o644)
				content = newContent
				fmt.Println("✓ Generated Starship palette and set as active")
			} else {
				fmt.Println("✓ Generated Starship palette (using different palette, change to 'palette = \"ii\"' to use)")
			}
		}

		if strings.Contains(content, "[palettes.ii]") {
			paletteBlock := strings.Split(strings.TrimSpace(config), "\n")
			paletteStart := 0
			for i, line := range paletteBlock {
				if strings.HasPrefix(line, "[palettes.ii]") {
					paletteStart = i
					break
				}
			}
			paletteContent := strings.Join(paletteBlock[paletteStart:], "\n")
			if !strings.HasSuffix(paletteContent, "\n") {
				paletteContent += "\n"
			}

			start := strings.Index(content, "[palettes.ii]")
			if start >= 0 {
				next := strings.Index(content[start+1:], "\n[")
				end := len(content)
				if next >= 0 {
					end = start + 1 + next
				}
				newContent := content[:start] + paletteContent + content[end:]
				if newContent != content {
					_ = os.WriteFile(starshipConf, []byte(newContent), 0o644)
					fmt.Println("  → Updated ii palette in starship.toml")
				}
			}
		} else {
			f, _ := os.OpenFile(starshipConf, os.O_APPEND|os.O_WRONLY, 0o644)
			if f != nil {
				_, _ = f.WriteString("\n" + config)
				_ = f.Close()
			}
			fmt.Println("  → Appended ii palette to starship.toml")
		}
	} else {
		fmt.Println("✓ Generated Starship palette (starship.toml not found - create it and add 'palette = \"ii\"')")
	}
}

func generateBtopConfig(colors map[string]string, outputPath string) {
	bg := pick(colors, "surface", "background")
	surfaceLow := colors["surface_container_low"]
	surfaceHigh := colors["surface_container_high"]

	onSurface := colors["on_surface"]
	onSurfaceVariant := colors["on_surface_variant"]

	outlineVariant := colors["outline_variant"]

	primary := colors["primary"]
	primaryDim := colors["primary_fixed_dim"]
	secondaryDim := colors["secondary_fixed_dim"]
	tertiaryDim := colors["tertiary_fixed_dim"]
	errorColor := colors["error"]

	config := fmt.Sprintf(`# Auto-generated by ii wallpaper theming system
# Do not edit manually

theme[main_bg]="%s"
theme[main_fg]="%s"
theme[title]="%s"
theme[hi_fg]="%s"
theme[selected_bg]="%s"
theme[selected_fg]="%s"
theme[inactive_fg]="%s"
theme[graph_text]="%s"
theme[meter_bg]="%s"
theme[proc_misc]="%s"

theme[cpu_box]="%s"
theme[mem_box]="%s"
theme[net_box]="%s"
theme[proc_box]="%s"
theme[div_line]="%s"

theme[temp_start]="%s"
theme[temp_mid]="%s"
theme[temp_end]="%s"

theme[cpu_start]="%s"
theme[cpu_mid]="%s"
theme[cpu_end]="%s"

theme[free_start]="%s"
theme[free_mid]="%s"
theme[free_end]="%s"
theme[cached_start]="%s"
theme[cached_mid]="%s"
theme[cached_end]="%s"
theme[available_start]="%s"
theme[available_mid]="%s"
theme[available_end]="%s"
theme[used_start]="%s"
theme[used_mid]="%s"
theme[used_end]="%s"

theme[download_start]="%s"
theme[download_mid]="%s"
theme[download_end]="%s"
theme[upload_start]="%s"
theme[upload_mid]="%s"
theme[upload_end]="%s"

theme[process_start]="%s"
theme[process_mid]="%s"
theme[process_end]="%s"
`,
		bg,
		onSurface,
		onSurface,
		primary,
		surfaceHigh,
		onSurface,
		onSurfaceVariant,
		onSurfaceVariant,
		surfaceLow,
		onSurfaceVariant,
		outlineVariant,
		outlineVariant,
		outlineVariant,
		outlineVariant,
		outlineVariant,
		tertiaryDim,
		secondaryDim,
		errorColor,
		tertiaryDim,
		secondaryDim,
		errorColor,
		tertiaryDim,
		tertiaryDim,
		tertiaryDim,
		primaryDim,
		primaryDim,
		primaryDim,
		secondaryDim,
		secondaryDim,
		secondaryDim,
		tertiaryDim,
		secondaryDim,
		errorColor,
		tertiaryDim,
		tertiaryDim,
		tertiaryDim,
		secondaryDim,
		secondaryDim,
		secondaryDim,
		primaryDim,
		primaryDim,
		primaryDim,
	)

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)
	_ = os.WriteFile(outputPath, []byte(config), 0o644)

	home, _ := os.UserHomeDir()
	btopConf := filepath.Join(home, ".config/btop/btop.conf")
	newLine := "color_theme = \"ii-auto\""
	if fileExists(btopConf) {
		contentBytes, _ := os.ReadFile(btopConf)
		content := string(contentBytes)
		if regexp.MustCompile(`(?m)^color_theme\s*=`).MatchString(content) {
			newContent := regexp.MustCompile(`(?m)^color_theme\s*=.*$`).ReplaceAllString(content, newLine)
			if newContent != content {
				_ = os.WriteFile(btopConf, []byte(newContent), 0o644)
				fmt.Println("✓ Generated btop theme and updated btop.conf")
			} else {
				fmt.Println("✓ Generated btop theme (already using ii-auto)")
			}
		} else {
			f, _ := os.OpenFile(btopConf, os.O_APPEND|os.O_WRONLY, 0o644)
			if f != nil {
				_, _ = f.WriteString("\n" + newLine + "\n")
				_ = f.Close()
			}
			fmt.Println("✓ Generated btop theme and added to btop.conf")
		}
	} else {
		_ = os.MkdirAll(filepath.Dir(btopConf), 0o755)
		_ = os.WriteFile(btopConf, []byte(newLine+"\n"), 0o644)
		fmt.Println("✓ Generated btop theme and created btop.conf")
	}
}

func generateOmpConfig(colors map[string]string, outputPath string) {
	surfaceContainer := colors["surface_container"]
	surfaceContainerHigh := colors["surface_container_high"]
	onSurface := colors["on_surface"]
	onSurfaceVariant := colors["on_surface_variant"]
	primary := colors["primary"]
	primaryContainer := colors["primary_container"]
	onPrimaryContainer := colors["on_primary_container"]
	errorContainer := colors["error_container"]
	onErrorContainer := colors["on_error_container"]

	theme := map[string]interface{}{
		"$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
		"version": 4,
		"blocks": []interface{}{
			map[string]interface{}{
				"type":      "prompt",
				"alignment": "left",
				"segments": []interface{}{
					map[string]interface{}{
						"type":       "executiontime",
						"style":      "plain",
						"foreground": onSurfaceVariant,
						"background": surfaceContainerHigh,
						"template":   " {{ .FormattedMs }} ",
						"properties": map[string]interface{}{
							"style":     "austin",
							"threshold": 500,
						},
					},
					map[string]interface{}{
						"type":       "status",
						"style":      "plain",
						"foreground": onErrorContainer,
						"background": errorContainer,
						"template":   " {{ if gt .Code 0 }}✗ {{ .Code }}{{ end }} ",
					},
					map[string]interface{}{
						"type":       "path",
						"style":      "plain",
						"foreground": onSurface,
						"background": surfaceContainer,
						"template":   " {{ .Path }} ",
						"properties": map[string]interface{}{
							"style":                 "full",
							"folder_separator_icon": "/",
						},
					},
					map[string]interface{}{
						"type":       "git",
						"style":      "plain",
						"foreground": onPrimaryContainer,
						"background": primaryContainer,
						"template":   " {{ .HEAD }}{{ if .Working.Changed }} ●{{ end }}{{ if .Staging.Changed }} ✚{{ end }} ",
						"properties": map[string]interface{}{
							"branch_icon":  "",
							"fetch_status": true,
						},
					},
				},
			},
			map[string]interface{}{
				"type": "rprompt",
				"segments": []interface{}{
					map[string]interface{}{
						"type":       "time",
						"style":      "plain",
						"foreground": onSurfaceVariant,
						"template":   " {{ .CurrentDate | date \"15:04\" }} ",
					},
				},
			},
			map[string]interface{}{
				"type":      "prompt",
				"alignment": "left",
				"newline":   true,
				"segments": []interface{}{
					map[string]interface{}{
						"type":       "text",
						"style":      "plain",
						"foreground": primary,
						"template":   "❯ ",
					},
				},
			},
		},
	}

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)
	data, _ := json.MarshalIndent(theme, "", "  ")
	_ = os.WriteFile(outputPath, data, 0o644)
	fmt.Println("✓ Generated oh-my-posh theme")
}

func generateLazygitConfig(colors map[string]string, outputPath string) {
	primary := color(colors, "primary", "#458588")
	fg := color(colors, "term15", "#EBDBB2")
	gray := color(colors, "term8", "#928374")
	selBg := pick(colors, "surfaceContainer", "term8")
	if selBg == "" {
		selBg = "#3C3836"
	}
	red := color(colors, "term1", "#CC241D")
	yellow := color(colors, "term3", "#D79921")

	themeYaml := fmt.Sprintf(`    theme:
      activeBorderColor:
        - "%s"
        - bold
      inactiveBorderColor:
        - "%s"
      optionsTextColor:
        - "%s"
      selectedLineBgColor:
        - "%s"
      selectedRangeBgColor:
        - "%s"
      cherryPickedCommitFgColor:
        - "%s"
      cherryPickedCommitBgColor:
        - "%s"
      markedBaseCommitFgColor:
        - "%s"
      markedBaseCommitBgColor:
        - "%s"
      unstagedChangesColor:
        - "%s"
      defaultFgColor:
        - "%s"
`, primary, gray, primary, selBg, selBg, primary, selBg, yellow, selBg, red, fg)

	home, _ := os.UserHomeDir()
	configPath := filepath.Join(home, ".config/lazygit/config.yml")
	configFile := configPath

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)
	_ = os.WriteFile(outputPath, []byte("# Auto-generated by ii wallpaper theming system\n# This is the theme section for lazygit config.yml\ngui:\n"+themeYaml+"\n"), 0o644)

	if fileExists(configFile) {
		contentBytes, _ := os.ReadFile(configFile)
		content := string(contentBytes)
		if regexp.MustCompile(`(?m)^\s*theme:`).MatchString(content) {
			pattern := regexp.MustCompile(`(?m)(    theme:\n(?:      .*\n)*(?:        .*\n)*)`)
			newContent := pattern.ReplaceAllString(content, themeYaml+"\n")
			if newContent != content {
				_ = os.WriteFile(configFile, []byte(newContent), 0o644)
				fmt.Println("✓ Generated lazygit theme and updated config.yml")
			} else {
				fmt.Println("✓ Generated lazygit theme (config.yml unchanged)")
			}
		} else if regexp.MustCompile(`(?m)^gui:`).MatchString(content) {
			newContent := regexp.MustCompile(`(?m)^(gui:.*)`).ReplaceAllString(content, "$1\n"+themeYaml)
			_ = os.WriteFile(configFile, []byte(newContent), 0o644)
			fmt.Println("✓ Generated lazygit theme and added to gui section")
		} else {
			f, _ := os.OpenFile(configFile, os.O_APPEND|os.O_WRONLY, 0o644)
			if f != nil {
				_, _ = f.WriteString("\ngui:\n" + themeYaml + "\n")
				_ = f.Close()
			}
			fmt.Println("✓ Generated lazygit theme and appended gui section")
		}
	} else {
		_ = os.MkdirAll(filepath.Dir(configFile), 0o755)
		_ = os.WriteFile(configFile, []byte("gui:\n"+themeYaml+"\n"), 0o644)
		fmt.Println("✓ Generated lazygit config with theme")
	}

}

func generateYaziConfig(colors map[string]string, outputPath string) {
	bg := color(colors, "term0", "#282828")
	fg := color(colors, "term15", "#EBDBB2")
	fgDim := color(colors, "term7", "#A89984")
	gray := color(colors, "term8", "#928374")
	primary := color(colors, "primary", "#458588")
	selBg := pick(colors, "surfaceContainer", "term8")
	if selBg == "" {
		selBg = "#3C3836"
	}
	red := color(colors, "term1", "#CC241D")
	green := color(colors, "term2", "#98971A")
	yellow := color(colors, "term3", "#D79921")
	magenta := color(colors, "term5", "#B16286")
	cyan := color(colors, "term6", "#689D6A")

	config := fmt.Sprintf(`# Auto-generated by ii wallpaper theming system
# Do not edit manually - changes will be overwritten

[mgr]
cwd = { fg = "%s" }
hovered         = { fg = "%s", bg = "%s" }
preview_hovered = { underline = true }
find_keyword    = { fg = "%s", italic = true }
find_position   = { fg = "%s", bg = "reset", italic = true }
marker_selected = { fg = "%s", bg = "%s" }
marker_copied   = { fg = "%s", bg = "%s" }
marker_cut      = { fg = "%s", bg = "%s" }
tab_active      = { fg = "%s", bg = "%s" }
tab_inactive    = { fg = "%s", bg = "%s" }
tab_width       = 1
border_symbol   = "│"
border_style    = { fg = "%s" }
count_copied    = { fg = "%s", bg = "%s" }
count_cut       = { fg = "%s", bg = "%s" }
count_selected  = { fg = "%s", bg = "%s" }

[mode]
normal_main = { fg = "%s", bg = "%s", bold = true }
normal_alt  = { fg = "%s", bg = "%s", bold = true }
select_main = { fg = "%s", bg = "%s", bold = true }
select_alt  = { fg = "%s", bg = "%s", bold = true }
unset_main  = { fg = "%s", bg = "%s", bold = true }
unset_alt   = { fg = "%s", bg = "%s", bold = true }

[status]
separator_open  = ""
separator_close = ""
separator_style = { fg = "%s", bg = "%s" }
progress_label  = { fg = "%s", bold = true }
progress_normal = { fg = "%s", bg = "%s" }
progress_error  = { fg = "%s", bg = "%s" }
permissions_t   = { fg = "%s" }
permissions_r   = { fg = "%s" }
permissions_w   = { fg = "%s" }
permissions_x   = { fg = "%s" }
permissions_s   = { fg = "%s" }

[input]
border   = { fg = "%s" }
title    = {}
value    = {}
selected = { reversed = true }

[select]
border   = { fg = "%s" }
active   = { fg = "%s", bold = true }
inactive = {}

[tasks]
border  = { fg = "%s" }
title   = {}
hovered = { underline = true }

[which]
mask            = { bg = "%s" }
cand            = { fg = "%s" }
rest            = { fg = "%s" }
desc            = { fg = "%s" }
separator       = "  "
separator_style = { fg = "%s" }

[help]
on      = { fg = "%s" }
run     = { fg = "%s" }
desc    = { fg = "%s" }
hovered = { bg = "%s", bold = true }
footer  = { fg = "%s", bg = "%s" }

[filetype]
rules = [
  { mime = "image/*", fg = "%s" },
  { mime = "video/*", fg = "%s" },
  { mime = "audio/*", fg = "%s" },
  { mime = "application/zip",             fg = "%s" },
  { mime = "application/gzip",            fg = "%s" },
  { mime = "application/x-tar",           fg = "%s" },
  { mime = "application/x-bzip",          fg = "%s" },
  { mime = "application/x-bzip2",         fg = "%s" },
  { mime = "application/x-7z-compressed", fg = "%s" },
  { mime = "application/x-rar",           fg = "%s" },
  { name = "*",  fg = "%s" },
  { name = "*/", fg = "%s" },
]
`,
		primary, bg, primary,
		yellow, magenta, green, green, yellow, yellow, red, red,
		bg, selBg, fgDim, selBg, gray,
		bg, yellow, bg, red, bg, primary,
		bg, primary, bg, primary, bg, green, bg, green, bg, magenta, bg, magenta,
		selBg, selBg, fg, primary, selBg, red, selBg, primary, yellow, red, green, gray,
		primary, primary, magenta, primary,
		selBg, cyan, gray, magenta, gray,
		magenta, cyan, gray, selBg, fgDim, fgDim,
		magenta, cyan, cyan, red, red, red, red, red, red, red, fgDim, primary,
	)

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)
	_ = os.WriteFile(outputPath, []byte(config), 0o644)

	home, _ := os.UserHomeDir()
	themeToml := filepath.Join(home, ".config/yazi/theme.toml")
	flavorLine := "use = \"ii-auto\""
	if fileExists(themeToml) {
		contentBytes, _ := os.ReadFile(themeToml)
		content := string(contentBytes)
		if strings.Contains(content, "[flavor]") {
			if regexp.MustCompile(`(?m)^use\s*=\s*"ii-auto"`).MatchString(content) {
				fmt.Println("✓ Generated yazi flavor (already using ii-auto)")
			} else if regexp.MustCompile(`(?m)^use\s*=`).MatchString(content) {
				newContent := regexp.MustCompile(`(?m)^(use\s*=).*$`).ReplaceAllString(content, "use = \"ii-auto\"")
				_ = os.WriteFile(themeToml, []byte(newContent), 0o644)
				fmt.Println("✓ Generated yazi flavor and updated theme.toml")
			} else {
				newContent := strings.Replace(content, "[flavor]", "[flavor]\n"+flavorLine, 1)
				_ = os.WriteFile(themeToml, []byte(newContent), 0o644)
				fmt.Println("✓ Generated yazi flavor and added use directive")
			}
		} else {
			f, _ := os.OpenFile(themeToml, os.O_APPEND|os.O_WRONLY, 0o644)
			if f != nil {
				_, _ = f.WriteString("\n[flavor]\n" + flavorLine + "\n")
				_ = f.Close()
			}
			fmt.Println("✓ Generated yazi flavor and added [flavor] section")
		}
	} else {
		_ = os.MkdirAll(filepath.Dir(themeToml), 0o755)
		_ = os.WriteFile(themeToml, []byte("[flavor]\n"+flavorLine+"\n"), 0o644)
		fmt.Println("✓ Generated yazi flavor and created theme.toml")
	}

	_ = fg
}

func generateFuzzelConfig(colors map[string]string, outputPath string) {
	bg := pick(colors, "background", "term0")
	if bg == "" {
		bg = "#282828"
	}
	fg := pick(colors, "onBackground", "term15")
	if fg == "" {
		fg = "#EBDBB2"
	}
	surfaceVar := pick(colors, "surfaceVariant", "term8")
	if surfaceVar == "" {
		surfaceVar = "#928374"
	}
	onSurfaceVar := pick(colors, "onSurfaceVariant", "term7")
	if onSurfaceVar == "" {
		onSurfaceVar = "#A89984"
	}
	primary := color(colors, "primary", "#458588")

	hexAlpha := func(c string) string {
		return strings.TrimPrefix(c, "#") + "ff"
	}
	hexAlphaDim := func(c string) string {
		return strings.TrimPrefix(c, "#") + "dd"
	}

	config := fmt.Sprintf(`[colors]
background=%s
text=%s
selection=%s
selection-text=%s
border=%s
match=%s
selection-match=%s
`,
		hexAlpha(bg),
		hexAlpha(fg),
		hexAlpha(surfaceVar),
		hexAlpha(onSurfaceVar),
		hexAlphaDim(surfaceVar),
		hexAlpha(primary),
		hexAlpha(primary),
	)

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)
	_ = os.WriteFile(outputPath, []byte(config), 0o644)
	fmt.Println("✓ Generated Fuzzel theme")
}

func generatePywalfoxConfig(colors map[string]string, outputPath string) {
	bg := pick(colors, "background", "term0")
	if bg == "" {
		bg = "#282828"
	}
	fg := pick(colors, "onBackground", "term15")
	if fg == "" {
		fg = "#EBDBB2"
	}
	primary := color(colors, "primary", "#458588")

	palette := map[string]string{}
	for i := 0; i < 16; i++ {
		palette[fmt.Sprintf("color%d", i)] = color(colors, fmt.Sprintf("term%d", i), "#000000")
	}

	wallpaper := ""
	wpPath := expandPath("~/.local/state/quickshell/user/generated/wallpaper/path.txt")
	if data, err := os.ReadFile(wpPath); err == nil {
		wallpaper = strings.TrimSpace(string(data))
	}

	pywalfoxData := map[string]interface{}{
		"wallpaper": wallpaper,
		"alpha":     "100",
		"colors":    palette,
		"special": map[string]string{
			"background": bg,
			"foreground": fg,
			"cursor":     primary,
		},
	}

	outputPath = expandPath(outputPath)
	_ = os.MkdirAll(filepath.Dir(outputPath), 0o755)
	data, _ := json.MarshalIndent(pywalfoxData, "", "  ")
	_ = os.WriteFile(outputPath, data, 0o644)
	fmt.Println("✓ Generated Pywalfox colors")
}

func runZedGenerator(scssPath, outputPath string) error {
	exePath, err := os.Executable()
	if err != nil {
		exePath = os.Args[0]
	}
	scriptDir := filepath.Dir(exePath)

	cacheDir := os.Getenv("XDG_CACHE_HOME")
	if cacheDir == "" {
		home, _ := os.UserHomeDir()
		cacheDir = filepath.Join(home, ".cache")
	}
	cacheDir = filepath.Join(cacheDir, "inir")
	_ = os.MkdirAll(cacheDir, 0o755)
	binary := filepath.Join(cacheDir, "zed_theme_generator")

	source := filepath.Join(scriptDir, "zed", "theme_generator.go")
	if !fileExists(source) {
		fallback := filepath.Join(scriptDir, "scripts", "colors", "zed", "theme_generator.go")
		if fileExists(fallback) {
			source = fallback
		}
	}
	if !fileExists(source) {
		if cwd, err := os.Getwd(); err == nil {
			fallback := filepath.Join(cwd, "scripts", "colors", "zed", "theme_generator.go")
			if fileExists(fallback) {
				source = fallback
			}
		}
	}

	if !fileExists(binary) || (fileExists(source) && newerThan(source, binary)) {
		if !fileExists(source) {
			return fmt.Errorf("Zed generator source not found")
		}
		buildCmd := exec.Command("go", "build", "-o", binary, source)
		buildCmd.Stdout = os.Stdout
		buildCmd.Stderr = os.Stderr
		if err := buildCmd.Run(); err != nil {
			return fmt.Errorf("failed to build Zed generator: %w", err)
		}
	}

	cmd := exec.Command(binary, "--scss", scssPath, "--out", outputPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func runVSCodeGenerator(scssPath string, forks []string) error {
	exePath, err := os.Executable()
	if err != nil {
		exePath = os.Args[0]
	}
	scriptDir := filepath.Dir(exePath)
	pyPath := filepath.Join(scriptDir, "vscode", "theme_generator.py")
	if !fileExists(pyPath) {
		fallback := filepath.Join(scriptDir, "scripts", "colors", "vscode", "theme_generator.py")
		if fileExists(fallback) {
			pyPath = fallback
		}
	}
	if !fileExists(pyPath) {
		if cwd, err := os.Getwd(); err == nil {
			fallback := filepath.Join(cwd, "scripts", "colors", "vscode", "theme_generator.py")
			if fileExists(fallback) {
				pyPath = fallback
			}
		}
	}
	if !fileExists(pyPath) {
		configHome := os.Getenv("XDG_CONFIG_HOME")
		if configHome == "" {
			home, _ := os.UserHomeDir()
			configHome = filepath.Join(home, ".config")
		}
		fallback := filepath.Join(configHome, "quickshell", "ii", "scripts", "colors", "vscode", "theme_generator.py")
		if fileExists(fallback) {
			pyPath = fallback
		}
	}
	if !fileExists(pyPath) {
		return fmt.Errorf("VSCode generator not found at %s", pyPath)
	}

	python := "python3"
	if venv := os.Getenv("ILLOGICAL_IMPULSE_VIRTUAL_ENV"); venv != "" {
		candidate := filepath.Join(expandPath(os.ExpandEnv(venv)), "bin/python3")
		if fileExists(candidate) {
			python = candidate
		}
	}

	colorsPath := expandPath("~/.local/state/quickshell/user/generated/colors.json")
	args := []string{pyPath, "--colors", colorsPath, "--scss", scssPath}
	if len(forks) > 0 {
		args = append(args, "--forks")
		args = append(args, forks...)
	}

	cmd := exec.Command(python, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func loadColorsJSON(path string) map[string]string {
	path = expandPath(path)
	data, err := os.ReadFile(path)
	if err != nil {
		fmt.Printf("Warning: %s not found, theme may be incomplete\n", path)
		return map[string]string{}
	}
	colors := map[string]string{}
	_ = json.Unmarshal(data, &colors)
	return colors
}

func mergeMaps(base, extra map[string]string) map[string]string {
	merged := map[string]string{}
	for k, v := range base {
		merged[k] = v
	}
	for k, v := range extra {
		merged[k] = v
	}
	return merged
}

func color(colors map[string]string, key, fallback string) string {
	if v, ok := colors[key]; ok && v != "" {
		return v
	}
	return fallback
}

func pick(colors map[string]string, key, fallbackKey string) string {
	if v, ok := colors[key]; ok && v != "" {
		return v
	}
	if v, ok := colors[fallbackKey]; ok && v != "" {
		return v
	}
	return ""
}

func konsoleRGB(hex string) string {
	hex = strings.TrimPrefix(hex, "#")
	if len(hex) != 6 {
		return "0,0,0"
	}
	r := hex[0:2]
	g := hex[2:4]
	b := hex[4:6]
	rv := parseHexByte(r)
	gv := parseHexByte(g)
	bv := parseHexByte(b)
	return fmt.Sprintf("%d,%d,%d", rv, gv, bv)
}

func parseHexByte(s string) int {
	val, err := strconv.ParseInt(s, 16, 0)
	if err != nil {
		return 0
	}
	return int(val)
}

func expandPath(path string) string {
	if strings.HasPrefix(path, "~") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, strings.TrimPrefix(path, "~/"))
	}
	return path
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func newerThan(src, dst string) bool {
	srcInfo, err := os.Stat(src)
	if err != nil {
		return false
	}
	dstInfo, err := os.Stat(dst)
	if err != nil {
		return false
	}
	return srcInfo.ModTime().After(dstInfo.ModTime())
}

func contains(list []string, val string) bool {
	for _, item := range list {
		if item == val {
			return true
		}
	}
	return false
}
