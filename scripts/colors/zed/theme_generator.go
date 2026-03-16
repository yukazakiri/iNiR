package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

type Theme struct {
	Name       string                 `json:"name"`
	Appearance string                 `json:"appearance"`
	Style      map[string]interface{} `json:"style"`
}

type ThemeData struct {
	Schema string  `json:"$schema"`
	Name   string  `json:"name"`
	Author string  `json:"author"`
	Themes []Theme `json:"themes"`
}

func main() {
	scssPath := flag.String("scss", "", "Path to material_colors.scss")
	outPath := flag.String("out", "", "Output JSON path")
	colorsPath := flag.String("colors", "", "Path to colors.json (optional)")
	flag.Parse()

	if *scssPath == "" || *outPath == "" {
		fmt.Fprintln(os.Stderr, "Usage: theme_generator --scss <path> --out <path> [--colors <path>]")
		os.Exit(2)
	}

	if *colorsPath == "" {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			fmt.Fprintln(os.Stderr, "Error: could not determine home directory")
			os.Exit(1)
		}
		*colorsPath = filepath.Join(homeDir, ".local/state/quickshell/user/generated/colors.json")
	}

	if err := generateZedConfig(*scssPath, *outPath, *colorsPath); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func generateZedConfig(scssPath, outputPath, colorsPath string) error {
	myColors, usedDefault, err := loadColors(colorsPath)
	if err != nil {
		return err
	}
	if usedDefault {
		fmt.Fprintln(os.Stderr, "Warning: Could not find colors.json. Using defaults for Zed theme.")
	}

	termColors := parseScssColors(scssPath)

	surfaceLum := luminance(getColor(myColors, "surface", "#000000"))
	isDarkPalette := surfaceLum < 128

	var (
		dkSurface, dkSurfaceLow, dkSurfaceStd, dkSurfaceHigh                   string
		dkOnSurface, dkOnSurfaceVariant, dkOutline                             string
		ltSurface, ltSurfaceLow, ltSurfaceStd, ltSurfaceHigh, ltSurfaceHighest string
		ltOnSurface, ltOnSurfaceVariant, ltOutline, ltOutlineVariant           string
	)

	if isDarkPalette {
		dkSurface = getColor(myColors, "surface", "#1a1b26")
		dkSurfaceLow = getColor(myColors, "surface_container_low", "#24283b")
		dkSurfaceStd = getColor(myColors, "surface_container", "#414868")
		dkSurfaceHigh = getColor(myColors, "surface_container_high", "#565f89")
		dkOnSurface = getColor(myColors, "on_surface", "#c0caf5")
		dkOnSurfaceVariant = getColor(myColors, "on_surface_variant", "#9aa5ce")
		dkOutline = getColor(myColors, "outline", "#565f89")

		ltSurface = getColor(myColors, "inverse_surface", "#f1dedc")
		ltOnSurface = getColor(myColors, "inverse_on_surface", "#392e2c")
		ltOnSurfaceVariant = getColor(myColors, "outline_variant", "#534341")
		ltOutline = getColor(myColors, "outline", "#565f89")
		ltOutlineVariant = getColor(myColors, "outline_variant", "#534341")
		ltSurfaceLow = adjustLightness(ltSurface, 0.97)
		ltSurfaceStd = adjustLightness(ltSurface, 0.94)
		ltSurfaceHigh = adjustLightness(ltSurface, 0.91)
		ltSurfaceHighest = adjustLightness(ltSurface, 0.88)
	} else {
		ltSurface = getColor(myColors, "surface", "#fff8f7")
		ltSurfaceLow = getColor(myColors, "surface_container_low", "#fff0f2")
		ltSurfaceStd = getColor(myColors, "surface_container", "#fbeaec")
		ltSurfaceHigh = getColor(myColors, "surface_container_high", "#f5e4e6")
		ltSurfaceHighest = getColor(myColors, "surface_container_highest", "#efdee0")
		ltOnSurface = getColor(myColors, "on_surface", "#22191b")
		ltOnSurfaceVariant = getColor(myColors, "on_surface_variant", "#514346")
		ltOutline = getColor(myColors, "outline", "#847376")
		ltOutlineVariant = getColor(myColors, "outline_variant", "#d6c2c4")

		dkSurface = getColor(myColors, "inverse_surface", "#382e30")
		dkOnSurface = getColor(myColors, "inverse_on_surface", "#feedef")
		dkOnSurfaceVariant = getColor(myColors, "outline_variant", "#d6c2c4")
		dkOutline = getColor(myColors, "outline", "#847376")
		dkSurfaceLow = adjustLightness(dkSurface, 1.15)
		dkSurfaceStd = adjustLightness(dkSurface, 1.35)
		dkSurfaceHigh = adjustLightness(dkSurface, 1.55)
	}

	darkStyle := buildZedDarkTheme(myColors, termColors, dkSurface, dkSurfaceLow, dkSurfaceStd, dkSurfaceHigh, dkOnSurface, dkOnSurfaceVariant, dkOutline)
	lightStyle := buildZedLightTheme(myColors, termColors, ltSurface, ltSurfaceLow, ltSurfaceStd, ltSurfaceHigh, ltSurfaceHighest, ltOnSurface, ltOnSurfaceVariant, ltOutline, ltOutlineVariant)

	themeData := ThemeData{
		Schema: "https://zed.dev/schema/themes/v0.2.0.json",
		Name:   "iNiR Material",
		Author: "iNiR Theme System",
		Themes: []Theme{
			{Name: "iNiR Dark", Appearance: "dark", Style: darkStyle},
			{Name: "iNiR Light", Appearance: "light", Style: lightStyle},
		},
	}

	if err := os.MkdirAll(filepath.Dir(outputPath), 0o755); err != nil {
		return err
	}

	file, err := os.Create(outputPath)
	if err != nil {
		return err
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetEscapeHTML(false)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(themeData); err != nil {
		return err
	}

	fmt.Println("✓ Generated Zed theme")
	return nil
}

func loadColors(colorsPath string) (map[string]string, bool, error) {
	defaultColors := map[string]string{
		"primary":                "#7aa2f7",
		"secondary":              "#bb9af7",
		"tertiary":               "#9ece6a",
		"error":                  "#f7768e",
		"surface":                "#1a1b26",
		"surface_container_low":  "#24283b",
		"surface_container":      "#414868",
		"surface_container_high": "#565f89",
		"outline":                "#565f89",
		"on_surface":             "#c0caf5",
		"on_surface_variant":     "#9aa5ce",
		"on_primary":             "#1a1b26",
	}

	data, err := os.ReadFile(colorsPath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return defaultColors, true, nil
		}
		return nil, false, err
	}

	colors := map[string]string{}
	if err := json.Unmarshal(data, &colors); err != nil {
		return nil, false, err
	}

	for k, v := range colors {
		colors[k] = strings.ToLower(v)
	}

	return colors, false, nil
}

func parseScssColors(scssPath string) map[string]string {
	colors := map[string]string{}
	data, err := os.ReadFile(scssPath)
	if err != nil {
		return colors
	}

	re := regexp.MustCompile(`^\$(\w+):\s*(#[A-Fa-f0-9]{6});`)
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		match := re.FindStringSubmatch(line)
		if match != nil {
			colors[match[1]] = match[2]
		}
	}
	return colors
}

func getColor(colors map[string]string, key, fallback string) string {
	if value, ok := colors[key]; ok && value != "" {
		return value
	}
	return fallback
}

func hexWithAlpha(hexColor, alpha string) string {
	hexColor = strings.TrimPrefix(hexColor, "#")
	return "#" + hexColor + alpha
}

func adjustLightness(hexColor string, factor float64) string {
	r, g, b := hexToRGBFloat(hexColor)

	maxC := maxFloat(r, g, b)
	minC := minFloat(r, g, b)
	l := (maxC + minC) / 2.0

	var h, s float64
	if maxC == minC {
		h = 0
		s = 0
	} else {
		d := maxC - minC
		if l > 0.5 {
			s = d / (2.0 - maxC - minC)
		} else {
			s = d / (maxC + minC)
		}

		if maxC == r {
			if g < b {
				h = (g-b)/d + 6
			} else {
				h = (g - b) / d
			}
		} else if maxC == g {
			h = (b-r)/d + 2
		} else {
			h = (r-g)/d + 4
		}
		h /= 6.0
	}

	l = clamp(l*factor, 0, 1)

	var rOut, gOut, bOut float64
	if s == 0 {
		rOut = l
		gOut = l
		bOut = l
	} else {
		q := 0.0
		if l < 0.5 {
			q = l * (1 + s)
		} else {
			q = l + s - l*s
		}
		p := 2*l - q
		rOut = hueToRGB(p, q, h+1.0/3.0)
		gOut = hueToRGB(p, q, h)
		bOut = hueToRGB(p, q, h-1.0/3.0)
	}

	return fmt.Sprintf("#%02x%02x%02x", int(rOut*255), int(gOut*255), int(bOut*255))
}

func saturate(hexColor string, factor float64) string {
	r, g, b := hexToRGBFloat(hexColor)

	maxC := maxFloat(r, g, b)
	minC := minFloat(r, g, b)
	l := (maxC + minC) / 2.0

	if maxC == minC {
		return fmt.Sprintf("#%02x%02x%02x", int(r*255), int(g*255), int(b*255))
	}

	d := maxC - minC
	s := 0.0
	if l > 0.5 {
		s = d / (2.0 - maxC - minC)
	} else {
		s = d / (maxC + minC)
	}

	var h float64
	if maxC == r {
		if g < b {
			h = (g-b)/d + 6
		} else {
			h = (g - b) / d
		}
	} else if maxC == g {
		h = (b-r)/d + 2
	} else {
		h = (r-g)/d + 4
	}
	h /= 6.0

	s = minFloat(1.0, s*factor)

	var rOut, gOut, bOut float64
	if s == 0 {
		rOut = l
		gOut = l
		bOut = l
	} else {
		q := 0.0
		if l < 0.5 {
			q = l * (1 + s)
		} else {
			q = l + s - l*s
		}
		p := 2*l - q
		rOut = hueToRGB(p, q, h+1.0/3.0)
		gOut = hueToRGB(p, q, h)
		bOut = hueToRGB(p, q, h-1.0/3.0)
	}

	return fmt.Sprintf("#%02x%02x%02x", int(rOut*255), int(gOut*255), int(bOut*255))
}

func hueToRGB(p, q, t float64) float64 {
	if t < 0 {
		t += 1
	}
	if t > 1 {
		t -= 1
	}
	if t < 1.0/6.0 {
		return p + (q-p)*6*t
	}
	if t < 0.5 {
		return q
	}
	if t < 2.0/3.0 {
		return p + (q-p)*(2.0/3.0-t)*6
	}
	return p
}

func luminance(hexColor string) float64 {
	r, g, b := hexToRGBInt(hexColor)
	return float64(r)*0.299 + float64(g)*0.587 + float64(b)*0.114
}

func hexToRGBFloat(hexColor string) (float64, float64, float64) {
	r, g, b := hexToRGBInt(hexColor)
	return float64(r) / 255.0, float64(g) / 255.0, float64(b) / 255.0
}

func hexToRGBInt(hexColor string) (int, int, int) {
	hexColor = strings.TrimPrefix(hexColor, "#")
	if len(hexColor) != 6 {
		return 0, 0, 0
	}
	r, _ := strconv.ParseInt(hexColor[0:2], 16, 0)
	g, _ := strconv.ParseInt(hexColor[2:4], 16, 0)
	b, _ := strconv.ParseInt(hexColor[4:6], 16, 0)
	return int(r), int(g), int(b)
}

func maxFloat(values ...float64) float64 {
	max := values[0]
	for _, v := range values[1:] {
		if v > max {
			max = v
		}
	}
	return max
}

func minFloat(values ...float64) float64 {
	min := values[0]
	for _, v := range values[1:] {
		if v < min {
			min = v
		}
	}
	return min
}

func clamp(value, minVal, maxVal float64) float64 {
	if value < minVal {
		return minVal
	}
	if value > maxVal {
		return maxVal
	}
	return value
}

func buildZedDarkTheme(myColors, termColors map[string]string, surface, surfaceLow, surfaceStd, surfaceHigh, onSurface, onSurfaceVariant, outline string) map[string]interface{} {
	primary := getColor(myColors, "primary", "#7aa2f7")
	secondary := getColor(myColors, "secondary", "#bb9af7")
	tertiary := getColor(myColors, "tertiary", "#9ece6a")
	errorColor := getColor(myColors, "error", "#f7768e")

	theme := map[string]interface{}{
		"border":                                     hexWithAlpha(outline, "ff"),
		"border.variant":                             hexWithAlpha(adjustLightness(surfaceLow, 0.8), "ff"),
		"border.focused":                             hexWithAlpha(primary, "ff"),
		"border.selected":                            hexWithAlpha(adjustLightness(primary, 0.7), "ff"),
		"border.transparent":                         "#00000000",
		"border.disabled":                            hexWithAlpha(adjustLightness(outline, 0.5), "ff"),
		"elevated_surface.background":                hexWithAlpha(surfaceLow, "ff"),
		"surface.background":                         hexWithAlpha(surfaceLow, "ff"),
		"background":                                 hexWithAlpha(surface, "ff"),
		"element.background":                         hexWithAlpha(surfaceLow, "ff"),
		"element.hover":                              hexWithAlpha(surfaceStd, "ff"),
		"element.active":                             hexWithAlpha(surfaceHigh, "ff"),
		"element.selected":                           hexWithAlpha(surfaceHigh, "ff"),
		"element.disabled":                           hexWithAlpha(surfaceLow, "ff"),
		"drop_target.background":                     hexWithAlpha(primary, "80"),
		"ghost_element.background":                   "#00000000",
		"ghost_element.hover":                        hexWithAlpha(surfaceStd, "ff"),
		"ghost_element.active":                       hexWithAlpha(surfaceHigh, "ff"),
		"ghost_element.selected":                     hexWithAlpha(surfaceHigh, "ff"),
		"ghost_element.disabled":                     hexWithAlpha(surfaceLow, "ff"),
		"text":                                       hexWithAlpha(onSurface, "ff"),
		"text.muted":                                 hexWithAlpha(onSurfaceVariant, "ff"),
		"text.placeholder":                           hexWithAlpha(adjustLightness(onSurfaceVariant, 0.7), "ff"),
		"text.disabled":                              hexWithAlpha(adjustLightness(onSurfaceVariant, 0.6), "ff"),
		"text.accent":                                hexWithAlpha(primary, "ff"),
		"icon":                                       hexWithAlpha(onSurface, "ff"),
		"icon.muted":                                 hexWithAlpha(onSurfaceVariant, "ff"),
		"icon.disabled":                              hexWithAlpha(adjustLightness(onSurfaceVariant, 0.6), "ff"),
		"icon.placeholder":                           hexWithAlpha(onSurfaceVariant, "ff"),
		"icon.accent":                                hexWithAlpha(primary, "ff"),
		"status_bar.background":                      hexWithAlpha(surface, "ff"),
		"title_bar.background":                       hexWithAlpha(surface, "ff"),
		"title_bar.inactive_background":              hexWithAlpha(surfaceLow, "ff"),
		"toolbar.background":                         hexWithAlpha(surfaceLow, "ff"),
		"tab_bar.background":                         hexWithAlpha(surfaceLow, "ff"),
		"tab.inactive_background":                    hexWithAlpha(surfaceLow, "ff"),
		"tab.active_background":                      hexWithAlpha(adjustLightness(surface, 0.9), "ff"),
		"search.match_background":                    hexWithAlpha(primary, "66"),
		"search.active_match_background":             hexWithAlpha(tertiary, "66"),
		"panel.background":                           hexWithAlpha(surfaceLow, "ff"),
		"panel.focused_border":                       nil,
		"pane.focused_border":                        nil,
		"scrollbar.thumb.background":                 hexWithAlpha(onSurfaceVariant, "4c"),
		"scrollbar.thumb.hover_background":           hexWithAlpha(surfaceHigh, "ff"),
		"scrollbar.thumb.border":                     hexWithAlpha(surfaceStd, "ff"),
		"scrollbar.track.background":                 "#00000000",
		"scrollbar.track.border":                     hexWithAlpha(surfaceStd, "ff"),
		"editor.foreground":                          hexWithAlpha(onSurface, "ff"),
		"editor.background":                          hexWithAlpha(surface, "ff"),
		"editor.gutter.background":                   hexWithAlpha(surface, "ff"),
		"editor.subheader.background":                hexWithAlpha(surfaceLow, "ff"),
		"editor.active_line.background":              hexWithAlpha(surfaceLow, "bf"),
		"editor.highlighted_line.background":         hexWithAlpha(surfaceStd, "ff"),
		"editor.line_number":                         hexWithAlpha(onSurfaceVariant, "ff"),
		"editor.active_line_number":                  hexWithAlpha(onSurface, "ff"),
		"editor.hover_line_number":                   hexWithAlpha(adjustLightness(onSurface, 1.1), "ff"),
		"editor.invisible":                           hexWithAlpha(onSurfaceVariant, "ff"),
		"editor.wrap_guide":                          hexWithAlpha(onSurfaceVariant, "0d"),
		"editor.active_wrap_guide":                   hexWithAlpha(onSurfaceVariant, "1a"),
		"editor.document_highlight.read_background":  hexWithAlpha(primary, "1a"),
		"editor.document_highlight.write_background": hexWithAlpha(surfaceStd, "66"),
		"terminal.background":                        hexWithAlpha(surface, "ff"),
		"terminal.foreground":                        hexWithAlpha(onSurface, "ff"),
		"terminal.bright_foreground":                 hexWithAlpha(onSurface, "ff"),
		"terminal.dim_foreground":                    hexWithAlpha(adjustLightness(onSurface, 0.6), "ff"),
		"link_text.hover":                            hexWithAlpha(primary, "ff"),
		"version_control.added":                      hexWithAlpha(tertiary, "ff"),
		"version_control.modified":                   hexWithAlpha(adjustLightness(primary, 0.8), "ff"),
		"version_control.word_added":                 hexWithAlpha(tertiary, "59"),
		"version_control.word_deleted":               hexWithAlpha(errorColor, "cc"),
		"version_control.deleted":                    hexWithAlpha(errorColor, "ff"),
		"version_control.conflict_marker.ours":       hexWithAlpha(tertiary, "1a"),
		"version_control.conflict_marker.theirs":     hexWithAlpha(primary, "1a"),
		"conflict":                                   hexWithAlpha(adjustLightness(tertiary, 0.8), "ff"),
		"conflict.background":                        hexWithAlpha(adjustLightness(tertiary, 0.8), "1a"),
		"conflict.border":                            hexWithAlpha(adjustLightness(tertiary, 0.6), "ff"),
		"created":                                    hexWithAlpha(tertiary, "ff"),
		"created.background":                         hexWithAlpha(tertiary, "1a"),
		"created.border":                             hexWithAlpha(adjustLightness(tertiary, 0.6), "ff"),
		"deleted":                                    hexWithAlpha(errorColor, "ff"),
		"deleted.background":                         hexWithAlpha(errorColor, "1a"),
		"deleted.border":                             hexWithAlpha(adjustLightness(errorColor, 0.6), "ff"),
		"error":                                      hexWithAlpha(errorColor, "ff"),
		"error.background":                           hexWithAlpha(errorColor, "1a"),
		"error.border":                               hexWithAlpha(adjustLightness(errorColor, 0.6), "ff"),
		"hidden":                                     hexWithAlpha(onSurfaceVariant, "ff"),
		"hidden.background":                          hexWithAlpha(adjustLightness(onSurfaceVariant, 0.3), "1a"),
		"hidden.border":                              hexWithAlpha(outline, "ff"),
		"hint":                                       hexWithAlpha(adjustLightness(primary, 0.7), "ff"),
		"hint.background":                            hexWithAlpha(adjustLightness(primary, 0.7), "1a"),
		"hint.border":                                hexWithAlpha(adjustLightness(primary, 0.6), "ff"),
		"ignored":                                    hexWithAlpha(onSurfaceVariant, "ff"),
		"ignored.background":                         hexWithAlpha(adjustLightness(onSurfaceVariant, 0.3), "1a"),
		"ignored.border":                             hexWithAlpha(outline, "ff"),
		"info":                                       hexWithAlpha(primary, "ff"),
		"info.background":                            hexWithAlpha(primary, "1a"),
		"info.border":                                hexWithAlpha(adjustLightness(primary, 0.6), "ff"),
		"color":                                      hexWithAlpha(primary, "66"),
		"modified.background":                        hexWithAlpha(adjustLightness(primary, 0.8), "1a"),
		"modified.border":                            hexWithAlpha(primary, "ff"),
		"predictive":                                 hexWithAlpha(adjustLightness(secondary, 0.8), "ff"),
		"predictive.background":                      hexWithAlpha(adjustLightness(secondary, 0.8), "1a"),
		"predictive.border":                          hexWithAlpha(secondary, "ff"),
		"renamed":                                    hexWithAlpha(primary, "ff"),
		"renamed.background":                         hexWithAlpha(primary, "1a"),
		"renamed.border":                             hexWithAlpha(adjustLightness(primary, 0.6), "ff"),
		"success":                                    hexWithAlpha(tertiary, "ff"),
		"success.background":                         hexWithAlpha(tertiary, "1a"),
		"success.border":                             hexWithAlpha(adjustLightness(tertiary, 0.6), "ff"),
		"unreachable":                                hexWithAlpha(onSurfaceVariant, "ff"),
		"unreachable.background":                     hexWithAlpha(adjustLightness(onSurfaceVariant, 0.3), "1a"),
		"unreachable.border":                         hexWithAlpha(outline, "ff"),
		"warning":                                    hexWithAlpha(adjustLightness(tertiary, 0.9), "ff"),
		"warning.background":                         hexWithAlpha(adjustLightness(tertiary, 0.9), "1a"),
		"warning.border":                             hexWithAlpha(adjustLightness(tertiary, 0.9), "ff"),
	}

	theme["terminal.ansi.black"] = hexWithAlpha(getColor(termColors, "term0", "#000000"), "ff")
	theme["terminal.ansi.bright_black"] = hexWithAlpha(getColor(termColors, "term8", "#555555"), "ff")
	theme["terminal.ansi.dim_black"] = hexWithAlpha(adjustLightness(getColor(termColors, "term0", "#000000"), 0.6), "ff")

	colorMap := map[string]int{
		"red":            1,
		"bright_red":     9,
		"dim_red":        1,
		"green":          2,
		"bright_green":   10,
		"dim_green":      2,
		"yellow":         3,
		"bright_yellow":  11,
		"dim_yellow":     3,
		"blue":           4,
		"bright_blue":    12,
		"dim_blue":       4,
		"magenta":        5,
		"bright_magenta": 13,
		"dim_magenta":    5,
		"cyan":           6,
		"bright_cyan":    14,
		"dim_cyan":       6,
		"white":          7,
		"bright_white":   15,
		"dim_white":      7,
	}

	for name, idx := range colorMap {
		baseColor := getColor(termColors, fmt.Sprintf("term%d", idx), "#ffffff")
		color := baseColor
		if strings.Contains(name, "bright") {
			color = adjustLightness(baseColor, 1.2)
		} else if strings.Contains(name, "dim") {
			color = adjustLightness(baseColor, 0.7)
		}
		theme["terminal.ansi."+name] = hexWithAlpha(color, "ff")
	}

	playerColors := []string{
		primary,
		errorColor,
		adjustLightness(tertiary, 0.8),
		secondary,
		adjustLightness(secondary, 1.2),
		adjustLightness(errorColor, 0.8),
		adjustLightness(tertiary, 0.9),
		adjustLightness(primary, 0.8),
	}

	players := make([]map[string]string, 0, len(playerColors))
	for _, color := range playerColors {
		players = append(players, map[string]string{
			"cursor":     hexWithAlpha(color, "ff"),
			"background": hexWithAlpha(color, "ff"),
			"selection":  hexWithAlpha(color, "3d"),
		})
	}
	theme["players"] = players

	theme["syntax"] = map[string]interface{}{
		"attribute": map[string]interface{}{
			"color":       hexWithAlpha(primary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"boolean": map[string]interface{}{
			"color":       hexWithAlpha(tertiary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"comment": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(onSurfaceVariant, 0.7), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"comment.doc": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(onSurfaceVariant, 0.8), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"constant": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(tertiary, 0.9), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"constructor": map[string]interface{}{
			"color":       hexWithAlpha(primary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"embedded": map[string]interface{}{
			"color":       hexWithAlpha(onSurface, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"emphasis": map[string]interface{}{
			"color":       hexWithAlpha(primary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"emphasis.strong": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(tertiary, 0.8), "ff"),
			"font_style":  nil,
			"font_weight": 700,
		},
		"enum": map[string]interface{}{
			"color":       hexWithAlpha(secondary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"function": map[string]interface{}{
			"color":       hexWithAlpha(primary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"hint": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(primary, 0.7), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"keyword": map[string]interface{}{
			"color":       hexWithAlpha(secondary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"label": map[string]interface{}{
			"color":       hexWithAlpha(primary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"link_text": map[string]interface{}{
			"color":       hexWithAlpha(primary, "ff"),
			"font_style":  "normal",
			"font_weight": nil,
		},
		"link_uri": map[string]interface{}{
			"color":       hexWithAlpha(secondary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"namespace": map[string]interface{}{
			"color":       hexWithAlpha(onSurface, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"number": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(tertiary, 0.8), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"operator": map[string]interface{}{
			"color":       hexWithAlpha(secondary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"predictive": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(secondary, 0.8), "ff"),
			"font_style":  "italic",
			"font_weight": nil,
		},
		"preproc": map[string]interface{}{
			"color":       hexWithAlpha(onSurface, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"primary": map[string]interface{}{
			"color":       hexWithAlpha(onSurface, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"property": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(primary, 0.85), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"punctuation": map[string]interface{}{
			"color":       hexWithAlpha(onSurface, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"punctuation.bracket": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(onSurface, 0.9), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"punctuation.delimiter": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(onSurface, 0.9), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"punctuation.list_marker": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(primary, 0.85), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"punctuation.markup": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(primary, 0.85), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"punctuation.special": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(errorColor, 0.8), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"selector": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(tertiary, 0.9), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"selector.pseudo": map[string]interface{}{
			"color":       hexWithAlpha(primary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"string": map[string]interface{}{
			"color":       hexWithAlpha(tertiary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"string.escape": map[string]interface{}{
			"color":       hexWithAlpha(onSurfaceVariant, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"string.regex": map[string]interface{}{
			"color":       hexWithAlpha(tertiary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"string.special": map[string]interface{}{
			"color":       hexWithAlpha(tertiary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"string.special.symbol": map[string]interface{}{
			"color":       hexWithAlpha(tertiary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"text.literal": map[string]interface{}{
			"color":       hexWithAlpha(tertiary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"title": map[string]interface{}{
			"color":       hexWithAlpha(primary, "ff"),
			"font_style":  nil,
			"font_weight": 400,
		},
		"variable": map[string]interface{}{
			"color":       hexWithAlpha(onSurface, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"variable.special": map[string]interface{}{
			"color":       hexWithAlpha(adjustLightness(tertiary, 0.8), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"variant": map[string]interface{}{
			"color":       hexWithAlpha(primary, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
	}

	return theme
}

func buildZedLightTheme(myColors, termColors map[string]string, surface, surfaceLow, surfaceStd, surfaceHigh, surfaceHighest, onSurface, onSurfaceVariant, outline, outlineVariant string) map[string]interface{} {
	primary := getColor(myColors, "primary", "#7aa2f7")
	secondary := getColor(myColors, "secondary", "#bb9af7")
	tertiary := getColor(myColors, "tertiary", "#9ece6a")
	errorColor := getColor(myColors, "error", "#f7768e")

	lighten := func(color string, factor float64) string {
		return adjustLightness(color, factor)
	}
	darken := func(color string, factor float64) string {
		return adjustLightness(color, factor)
	}

	lightTheme := map[string]interface{}{
		"border":                                     hexWithAlpha(outlineVariant, "ff"),
		"border.variant":                             hexWithAlpha(lighten(outlineVariant, 1.1), "ff"),
		"border.focused":                             hexWithAlpha(primary, "ff"),
		"border.selected":                            hexWithAlpha(darken(primary, 0.9), "ff"),
		"border.transparent":                         "#00000000",
		"border.disabled":                            hexWithAlpha(lighten(outlineVariant, 1.2), "ff"),
		"elevated_surface.background":                hexWithAlpha(surfaceLow, "ff"),
		"surface.background":                         hexWithAlpha(surfaceLow, "ff"),
		"background":                                 hexWithAlpha(surface, "ff"),
		"element.background":                         hexWithAlpha(surfaceStd, "ff"),
		"element.hover":                              hexWithAlpha(surfaceHigh, "ff"),
		"element.active":                             hexWithAlpha(surfaceHighest, "ff"),
		"element.selected":                           hexWithAlpha(surfaceHighest, "ff"),
		"element.disabled":                           hexWithAlpha(surfaceLow, "ff"),
		"drop_target.background":                     hexWithAlpha(primary, "30"),
		"ghost_element.background":                   "#00000000",
		"ghost_element.hover":                        hexWithAlpha(surfaceHigh, "ff"),
		"ghost_element.active":                       hexWithAlpha(surfaceHighest, "ff"),
		"ghost_element.selected":                     hexWithAlpha(surfaceHighest, "ff"),
		"ghost_element.disabled":                     hexWithAlpha(surfaceLow, "ff"),
		"text":                                       hexWithAlpha(onSurface, "ff"),
		"text.muted":                                 hexWithAlpha(onSurfaceVariant, "ff"),
		"text.placeholder":                           hexWithAlpha(lighten(onSurfaceVariant, 1.3), "ff"),
		"text.disabled":                              hexWithAlpha(lighten(onSurfaceVariant, 1.5), "ff"),
		"text.accent":                                hexWithAlpha(primary, "ff"),
		"icon":                                       hexWithAlpha(onSurface, "ff"),
		"icon.muted":                                 hexWithAlpha(onSurfaceVariant, "ff"),
		"icon.disabled":                              hexWithAlpha(lighten(onSurfaceVariant, 1.5), "ff"),
		"icon.placeholder":                           hexWithAlpha(onSurfaceVariant, "ff"),
		"icon.accent":                                hexWithAlpha(primary, "ff"),
		"status_bar.background":                      hexWithAlpha(surface, "ff"),
		"title_bar.background":                       hexWithAlpha(surface, "ff"),
		"title_bar.inactive_background":              hexWithAlpha(surfaceLow, "ff"),
		"toolbar.background":                         hexWithAlpha(surfaceLow, "ff"),
		"tab_bar.background":                         hexWithAlpha(surfaceLow, "ff"),
		"tab.inactive_background":                    hexWithAlpha(surfaceLow, "ff"),
		"tab.active_background":                      hexWithAlpha(surface, "ff"),
		"search.match_background":                    hexWithAlpha(primary, "40"),
		"search.active_match_background":             hexWithAlpha(tertiary, "40"),
		"panel.background":                           hexWithAlpha(surfaceLow, "ff"),
		"panel.focused_border":                       nil,
		"pane.focused_border":                        nil,
		"scrollbar.thumb.background":                 hexWithAlpha(onSurfaceVariant, "4c"),
		"scrollbar.thumb.hover_background":           hexWithAlpha(onSurfaceVariant, "80"),
		"scrollbar.thumb.border":                     hexWithAlpha(onSurfaceVariant, "60"),
		"scrollbar.track.background":                 "#00000000",
		"scrollbar.track.border":                     hexWithAlpha(outlineVariant, "ff"),
		"editor.foreground":                          hexWithAlpha(onSurface, "ff"),
		"editor.background":                          hexWithAlpha(surface, "ff"),
		"editor.gutter.background":                   hexWithAlpha(surface, "ff"),
		"editor.subheader.background":                hexWithAlpha(surfaceLow, "ff"),
		"editor.active_line.background":              hexWithAlpha(surfaceStd, "bf"),
		"editor.highlighted_line.background":         hexWithAlpha(surfaceHigh, "ff"),
		"editor.line_number":                         hexWithAlpha(onSurfaceVariant, "ff"),
		"editor.active_line_number":                  hexWithAlpha(onSurface, "ff"),
		"editor.hover_line_number":                   hexWithAlpha(darken(onSurface, 0.8), "ff"),
		"editor.invisible":                           hexWithAlpha(lighten(onSurfaceVariant, 1.3), "ff"),
		"editor.wrap_guide":                          hexWithAlpha(onSurfaceVariant, "0d"),
		"editor.active_wrap_guide":                   hexWithAlpha(onSurfaceVariant, "1a"),
		"editor.document_highlight.read_background":  hexWithAlpha(primary, "20"),
		"editor.document_highlight.write_background": hexWithAlpha(onSurfaceVariant, "66"),
		"terminal.background":                        hexWithAlpha(surface, "ff"),
		"terminal.foreground":                        hexWithAlpha(onSurface, "ff"),
		"terminal.bright_foreground":                 hexWithAlpha(onSurface, "ff"),
		"terminal.dim_foreground":                    hexWithAlpha(onSurfaceVariant, "ff"),
		"link_text.hover":                            hexWithAlpha(primary, "ff"),
		"version_control.added":                      hexWithAlpha(saturate(tertiary, 1.3), "ff"),
		"version_control.modified":                   hexWithAlpha(saturate(primary, 1.3), "ff"),
		"version_control.word_added":                 hexWithAlpha(tertiary, "40"),
		"version_control.word_deleted":               hexWithAlpha(errorColor, "40"),
		"version_control.deleted":                    hexWithAlpha(saturate(errorColor, 1.3), "ff"),
		"version_control.conflict_marker.ours":       hexWithAlpha(tertiary, "25"),
		"version_control.conflict_marker.theirs":     hexWithAlpha(primary, "25"),
		"conflict":                                   hexWithAlpha(saturate(tertiary, 1.3), "ff"),
		"conflict.background":                        hexWithAlpha(tertiary, "18"),
		"conflict.border":                            hexWithAlpha(saturate(tertiary, 1.5), "ff"),
		"created":                                    hexWithAlpha(saturate(tertiary, 1.3), "ff"),
		"created.background":                         hexWithAlpha(tertiary, "18"),
		"created.border":                             hexWithAlpha(saturate(tertiary, 1.5), "ff"),
		"deleted":                                    hexWithAlpha(saturate(errorColor, 1.3), "ff"),
		"deleted.background":                         hexWithAlpha(errorColor, "18"),
		"deleted.border":                             hexWithAlpha(saturate(errorColor, 1.5), "ff"),
		"error":                                      hexWithAlpha(saturate(errorColor, 1.3), "ff"),
		"error.background":                           hexWithAlpha(errorColor, "18"),
		"error.border":                               hexWithAlpha(saturate(errorColor, 1.5), "ff"),
		"hidden":                                     hexWithAlpha(onSurfaceVariant, "ff"),
		"hidden.background":                          hexWithAlpha(onSurfaceVariant, "18"),
		"hidden.border":                              hexWithAlpha(outlineVariant, "ff"),
		"hint":                                       hexWithAlpha(saturate(primary, 1.3), "ff"),
		"hint.background":                            hexWithAlpha(primary, "18"),
		"hint.border":                                hexWithAlpha(saturate(primary, 1.5), "ff"),
		"ignored":                                    hexWithAlpha(onSurfaceVariant, "ff"),
		"ignored.background":                         hexWithAlpha(onSurfaceVariant, "18"),
		"ignored.border":                             hexWithAlpha(outlineVariant, "ff"),
		"info":                                       hexWithAlpha(saturate(primary, 1.3), "ff"),
		"info.background":                            hexWithAlpha(primary, "18"),
		"info.border":                                hexWithAlpha(saturate(primary, 1.5), "ff"),
		"modified":                                   hexWithAlpha(saturate(primary, 1.3), "ff"),
		"modified.background":                        hexWithAlpha(primary, "18"),
		"modified.border":                            hexWithAlpha(saturate(primary, 1.5), "ff"),
		"predictive":                                 hexWithAlpha(saturate(secondary, 1.3), "ff"),
		"predictive.background":                      hexWithAlpha(secondary, "18"),
		"predictive.border":                          hexWithAlpha(saturate(secondary, 1.5), "ff"),
		"renamed":                                    hexWithAlpha(saturate(primary, 1.3), "ff"),
		"renamed.background":                         hexWithAlpha(primary, "18"),
		"renamed.border":                             hexWithAlpha(saturate(primary, 1.5), "ff"),
		"success":                                    hexWithAlpha(saturate(tertiary, 1.3), "ff"),
		"success.background":                         hexWithAlpha(tertiary, "18"),
		"success.border":                             hexWithAlpha(saturate(tertiary, 1.5), "ff"),
		"unreachable":                                hexWithAlpha(onSurfaceVariant, "ff"),
		"unreachable.background":                     hexWithAlpha(onSurfaceVariant, "18"),
		"unreachable.border":                         hexWithAlpha(outlineVariant, "ff"),
		"warning":                                    hexWithAlpha(saturate(tertiary, 1.3), "ff"),
		"warning.background":                         hexWithAlpha(tertiary, "18"),
		"warning.border":                             hexWithAlpha(saturate(tertiary, 1.5), "ff"),
	}

	term0 := getColor(termColors, "term0", "#000000")
	term7 := getColor(termColors, "term7", "#000000")
	term8 := getColor(termColors, "term8", "#000000")
	term15 := getColor(termColors, "term15", "#000000")

	lightTheme["terminal.ansi.black"] = hexWithAlpha(term0, "ff")
	lightTheme["terminal.ansi.white"] = hexWithAlpha(darken(term7, 0.5), "ff")
	lightTheme["terminal.ansi.bright_black"] = hexWithAlpha(darken(term8, 0.6), "ff")
	lightTheme["terminal.ansi.bright_white"] = hexWithAlpha(darken(term15, 0.3), "ff")

	colorMap := map[string]int{
		"red":            1,
		"bright_red":     9,
		"dim_red":        1,
		"green":          2,
		"bright_green":   10,
		"dim_green":      2,
		"yellow":         3,
		"bright_yellow":  11,
		"dim_yellow":     3,
		"blue":           4,
		"bright_blue":    12,
		"dim_blue":       4,
		"magenta":        5,
		"bright_magenta": 13,
		"dim_magenta":    5,
		"cyan":           6,
		"bright_cyan":    14,
		"dim_cyan":       6,
	}

	for name, idx := range colorMap {
		baseColor := getColor(termColors, fmt.Sprintf("term%d", idx), "#000000")
		color := baseColor
		if strings.Contains(name, "bright") {
			color = darken(baseColor, 0.75)
		} else if strings.Contains(name, "dim") {
			color = darken(baseColor, 0.5)
		} else {
			color = darken(baseColor, 0.85)
		}
		lightTheme["terminal.ansi."+name] = hexWithAlpha(color, "ff")
	}

	playerColors := []string{
		saturate(primary, 1.3),
		saturate(errorColor, 1.3),
		saturate(tertiary, 1.3),
		saturate(secondary, 1.3),
	}

	players := make([]map[string]string, 0, len(playerColors))
	for _, color := range playerColors {
		players = append(players, map[string]string{
			"cursor":     hexWithAlpha(color, "ff"),
			"background": hexWithAlpha(color, "ff"),
			"selection":  hexWithAlpha(lighten(color, 1.2), "3d"),
		})
	}
	lightTheme["players"] = players

	lightTheme["syntax"] = map[string]interface{}{
		"attribute": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"boolean": map[string]interface{}{
			"color":       hexWithAlpha(saturate(tertiary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"comment": map[string]interface{}{
			"color":       hexWithAlpha(onSurfaceVariant, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"comment.doc": map[string]interface{}{
			"color":       hexWithAlpha(onSurfaceVariant, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"constant": map[string]interface{}{
			"color":       hexWithAlpha(saturate(tertiary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"constructor": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"embedded": map[string]interface{}{
			"color":       hexWithAlpha(onSurface, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"emphasis": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"emphasis.strong": map[string]interface{}{
			"color":       hexWithAlpha(saturate(tertiary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": 700,
		},
		"enum": map[string]interface{}{
			"color":       hexWithAlpha(saturate(secondary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"function": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"hint": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"keyword": map[string]interface{}{
			"color":       hexWithAlpha(saturate(secondary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"label": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"link_text": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  "normal",
			"font_weight": nil,
		},
		"link_uri": map[string]interface{}{
			"color":       hexWithAlpha(saturate(secondary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"namespace": map[string]interface{}{
			"color":       hexWithAlpha(onSurface, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"number": map[string]interface{}{
			"color":       hexWithAlpha(saturate(tertiary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"operator": map[string]interface{}{
			"color":       hexWithAlpha(saturate(secondary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"predictive": map[string]interface{}{
			"color":       hexWithAlpha(saturate(secondary, 1.5), "ff"),
			"font_style":  "italic",
			"font_weight": nil,
		},
		"preproc": map[string]interface{}{
			"color":       hexWithAlpha(onSurface, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"primary": map[string]interface{}{
			"color":       hexWithAlpha(onSurface, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"property": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"punctuation": map[string]interface{}{
			"color":       hexWithAlpha(onSurface, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"punctuation.bracket": map[string]interface{}{
			"color":       hexWithAlpha(onSurfaceVariant, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"punctuation.delimiter": map[string]interface{}{
			"color":       hexWithAlpha(onSurfaceVariant, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"punctuation.list_marker": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"punctuation.markup": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"punctuation.special": map[string]interface{}{
			"color":       hexWithAlpha(saturate(errorColor, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"selector": map[string]interface{}{
			"color":       hexWithAlpha(saturate(tertiary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"selector.pseudo": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"string": map[string]interface{}{
			"color":       hexWithAlpha(saturate(tertiary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"string.escape": map[string]interface{}{
			"color":       hexWithAlpha(onSurfaceVariant, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"string.regex": map[string]interface{}{
			"color":       hexWithAlpha(saturate(tertiary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"string.special": map[string]interface{}{
			"color":       hexWithAlpha(saturate(tertiary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"string.special.symbol": map[string]interface{}{
			"color":       hexWithAlpha(saturate(tertiary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"tag": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"text.literal": map[string]interface{}{
			"color":       hexWithAlpha(saturate(tertiary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"title": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": 400,
		},
		"type": map[string]interface{}{
			"color":       hexWithAlpha(saturate(secondary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"variable": map[string]interface{}{
			"color":       hexWithAlpha(onSurface, "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"variable.special": map[string]interface{}{
			"color":       hexWithAlpha(saturate(tertiary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
		"variant": map[string]interface{}{
			"color":       hexWithAlpha(saturate(primary, 1.5), "ff"),
			"font_style":  nil,
			"font_weight": nil,
		},
	}

	return lightTheme
}
