package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type surfaceLevel struct {
	name  string
	level float64
}

func main() {
	path := flag.String("path", "", "generate colorscheme from image (unused; matugen handles this)")
	size := flag.Int("size", 128, "bitmap image size (unused)")
	colorArg := flag.String("color", "", "generate colorscheme from color (unused; matugen handles this)")
	mode := flag.String("mode", "dark", "dark or light mode")
	scheme := flag.String("scheme", "vibrant", "material scheme to use")
	smart := flag.Bool("smart", false, "decide scheme type based on image color (unused)")
	transparency := flag.String("transparency", "opaque", "enable transparency")
	termscheme := flag.String("termscheme", "", "JSON file containing the terminal scheme")
	harmony := flag.Float64("harmony", 0.4, "(0-1) Color hue shift towards accent")
	harmonizeThreshold := flag.Float64("harmonize_threshold", 100, "(0-180) Max threshold angle to limit color hue shift")
	termFgBoost := flag.Float64("term_fg_boost", 0.35, "unused")
	termSaturation := flag.Float64("term_saturation", 0.65, "Terminal color saturation (0.0-1.0)")
	termBrightness := flag.Float64("term_brightness", 0.60, "Terminal color brightness/lightness (0.0-1.0)")
	termBgBrightness := flag.Float64("term_bg_brightness", 0.50, "Terminal background brightness (0.0-1.0)")
	blendBgFg := flag.Bool("blend_bg_fg", false, "unused")
	cachePath := flag.String("cache", "", "file path to store the generated color")
	soften := flag.Bool("soften", false, "soften generated colors")
	debug := flag.Bool("debug", false, "enable debug output")
	jsonOutput := flag.String("json-output", "", "file path to write colors.json")
	flag.Parse()

	_ = path
	_ = size
	_ = colorArg
	_ = smart
	_ = termFgBoost
	_ = blendBgFg

	darkmode := strings.ToLower(*mode) == "dark"
	transparent := strings.ToLower(*transparency) == "transparent"

	colorsJSONPath := expandPath("~/.local/state/quickshell/user/generated/colors.json")
	colorsJSON := readJSON(colorsJSONPath)
	if len(colorsJSON) == 0 {
		fmt.Fprintln(os.Stderr, "Error: colors.json not found or empty. Run matugen first.")
		os.Exit(1)
	}

	materialColors := map[string]string{}
	for k, v := range colorsJSON {
		camel := snakeToCamel(k)
		materialColors[camel] = normalizeHex(v)
	}

	if *cachePath != "" {
		primary := getColor(materialColors, "primary", "#6750A4")
		_ = os.WriteFile(expandPath(*cachePath), []byte(strings.ToUpper(primary)), 0o644)
	}

	termColors := map[string]string{}
	if *termscheme != "" {
		termColors = harmonizedTermColors(*termscheme, darkmode, materialColors, *scheme, *harmony, *harmonizeThreshold, *termSaturation, *termBrightness, *termBgBrightness, *soften)
	}

	if len(termColors) == 0 {
		termColors = fallbackTermColors(materialColors)
	}

	if *debug {
		printDebug(darkmode, *scheme, materialColors, termColors)
	} else {
		printScss(darkmode, transparent, materialColors, termColors)
	}

	if *jsonOutput != "" {
		writeJSONOutput(*jsonOutput, colorsJSON)
	}
}

func harmonizedTermColors(termschemePath string, darkmode bool, materialColors map[string]string, scheme string, harmony float64, threshold float64, sat float64, brightness float64, bgBrightness float64, soften bool) map[string]string {
	data, err := os.ReadFile(expandPath(termschemePath))
	if err != nil {
		return map[string]string{}
	}

	base := map[string]map[string]string{}
	if err := json.Unmarshal(data, &base); err != nil {
		return map[string]string{}
	}

	modeKey := "light"
	if darkmode {
		modeKey = "dark"
	}

	termSource := base[modeKey]
	if len(termSource) == 0 {
		return map[string]string{}
	}

	primary := getColor(materialColors, "primary", "#6750A4")
	termColors := map[string]string{}

	surfaceLevels := []surfaceLevel{
		{name: "background", level: 0.0},
		{name: "surfaceContainerLowest", level: 0.2},
		{name: "surfaceContainerLow", level: 0.4},
		{name: "surfaceContainer", level: 0.6},
		{name: "surfaceContainerHigh", level: 0.8},
		{name: "surfaceContainerHighest", level: 1.0},
	}

	getInterpolatedSurface := func(brightness float64) string {
		for i, level := range surfaceLevels {
			if brightness <= level.level || i == len(surfaceLevels)-1 {
				if i == 0 {
					return getColor(materialColors, level.name, "#1a1a1a")
				}
				prev := surfaceLevels[i-1]
				t := 0.0
				if level.level != prev.level {
					t = (brightness - prev.level) / (level.level - prev.level)
				}
				c1 := getColor(materialColors, prev.name, "#1a1a1a")
				c2 := getColor(materialColors, level.name, "#2a2a2a")
				return interpolateHex(c1, c2, t)
			}
		}
		return getColor(materialColors, "surfaceContainerLow", "#1a1a1a")
	}

	for name, val := range termSource {
		if strings.Contains(strings.ToLower(scheme), "monochrome") {
			termColors[name] = normalizeHex(val)
			continue
		}

		switch name {
		case "term0":
			termColors[name] = getInterpolatedSurface(bgBrightness)
			continue
		case "term15":
			termColors[name] = getColor(materialColors, "onSurface", "#e0e0e0")
			continue
		case "term8":
			if darkmode {
				termColors[name] = getColor(materialColors, "outline", getInterpolatedSurface(clamp(bgBrightness+0.45, 0, 1)))
			} else {
				termColors[name] = getColor(materialColors, "outlineVariant", getInterpolatedSurface(clamp(bgBrightness-0.45, 0, 1)))
			}
			continue
		}

		baseColor := normalizeHex(val)
		harmonized := harmonizeHSL(baseColor, primary, threshold, harmony)
		if name == "term7" {
			harmonized = adjustHSL(harmonized, sat*1.2, 1.0)
		} else {
			toneMult := 1 + ((brightness - 0.5) * 0.4)
			if !darkmode {
				toneMult = 1 - ((brightness - 0.5) * 0.4)
			}
			harmonized = adjustHSL(harmonized, sat*1.5, toneMult)
		}

		if soften && !strings.Contains(strings.ToLower(scheme), "tonal-spot") && !strings.Contains(strings.ToLower(scheme), "neutral") && !strings.Contains(strings.ToLower(scheme), "monochrome") {
			harmonized = adjustHSL(harmonized, 0.55, 1.0)
		}

		termColors[name] = harmonized
	}

	return termColors
}

func fallbackTermColors(materialColors map[string]string) map[string]string {
	return map[string]string{
		"term0":  getColor(materialColors, "surfaceVariant", "#282828"),
		"term1":  getColor(materialColors, "error", "#CC241D"),
		"term2":  getColor(materialColors, "secondary", "#98971A"),
		"term3":  getColor(materialColors, "tertiary", "#D79921"),
		"term4":  getColor(materialColors, "primary", "#458588"),
		"term5":  getColor(materialColors, "tertiary", "#B16286"),
		"term6":  getColor(materialColors, "secondary", "#689D6A"),
		"term7":  getColor(materialColors, "onSurfaceVariant", "#A89984"),
		"term8":  getColor(materialColors, "outline", "#928374"),
		"term9":  getColor(materialColors, "error", "#FB4934"),
		"term10": getColor(materialColors, "secondary", "#B8BB26"),
		"term11": getColor(materialColors, "tertiary", "#FABD2F"),
		"term12": getColor(materialColors, "primary", "#83A598"),
		"term13": getColor(materialColors, "tertiary", "#D3869B"),
		"term14": getColor(materialColors, "secondary", "#8EC07C"),
		"term15": getColor(materialColors, "onSurface", "#EBDBB2"),
	}
}

func printScss(darkmode bool, transparent bool, materialColors map[string]string, termColors map[string]string) {
	fmt.Printf("$darkmode: %v;\n", darkmode)
	fmt.Printf("$transparent: %v;\n", transparent)

	materialOrder := []string{
		"background", "onBackground",
		"surface", "surfaceDim", "surfaceBright",
		"surfaceContainerLowest", "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest",
		"onSurface", "surfaceVariant", "onSurfaceVariant",
		"inverseSurface", "inverseOnSurface", "inversePrimary",
		"outline", "outlineVariant", "shadow", "scrim", "surfaceTint",
		"primary", "onPrimary", "primaryContainer", "onPrimaryContainer", "primaryFixed", "primaryFixedDim", "onPrimaryFixed", "onPrimaryFixedVariant",
		"secondary", "onSecondary", "secondaryContainer", "onSecondaryContainer", "secondaryFixed", "secondaryFixedDim", "onSecondaryFixed", "onSecondaryFixedVariant",
		"tertiary", "onTertiary", "tertiaryContainer", "onTertiaryContainer", "tertiaryFixed", "tertiaryFixedDim", "onTertiaryFixed", "onTertiaryFixedVariant",
		"error", "onError", "errorContainer", "onErrorContainer",
	}

	seen := map[string]bool{}
	for _, key := range materialOrder {
		if val, ok := materialColors[key]; ok && val != "" {
			fmt.Printf("$%s: %s;\n", key, val)
			seen[key] = true
		}
	}

	remaining := []string{}
	for key := range materialColors {
		if !seen[key] {
			remaining = append(remaining, key)
		}
	}
	sort.Strings(remaining)
	for _, key := range remaining {
		fmt.Printf("$%s: %s;\n", key, materialColors[key])
	}

	for i := 0; i < 16; i++ {
		key := fmt.Sprintf("term%d", i)
		if val, ok := termColors[key]; ok {
			fmt.Printf("$%s: %s;\n", key, val)
		}
	}
}

func printDebug(darkmode bool, scheme string, materialColors map[string]string, termColors map[string]string) {
	fmt.Println("Debug output")
	fmt.Printf("Dark mode: %v\n", darkmode)
	fmt.Printf("Scheme: %s\n", scheme)
	fmt.Printf("Primary: %s\n", getColor(materialColors, "primary", ""))
	fmt.Println("Material colors:")
	keys := make([]string, 0, len(materialColors))
	for k := range materialColors {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		fmt.Printf("%s: %s\n", k, materialColors[k])
	}
	fmt.Println("Terminal colors:")
	for i := 0; i < 16; i++ {
		k := fmt.Sprintf("term%d", i)
		if v, ok := termColors[k]; ok {
			fmt.Printf("%s: %s\n", k, v)
		}
	}
}

func writeJSONOutput(path string, colorsJSON map[string]string) {
	path = expandPath(path)
	_ = os.MkdirAll(filepath.Dir(path), 0o755)

	out := map[string]string{}
	keys := []string{
		"primary", "on_primary", "primary_container", "on_primary_container",
		"secondary", "on_secondary", "secondary_container", "on_secondary_container",
		"tertiary", "on_tertiary", "tertiary_container", "on_tertiary_container",
		"error", "on_error", "error_container", "on_error_container",
		"background", "on_background", "surface", "on_surface", "surface_variant", "on_surface_variant",
		"surface_container", "surface_container_low", "surface_container_high", "surface_container_highest",
		"outline", "outline_variant", "inverse_surface", "inverse_on_surface", "inverse_primary",
		"shadow", "scrim", "surface_tint",
	}

	for _, key := range keys {
		if val, ok := colorsJSON[key]; ok {
			out[key] = val
		} else {
			out[key] = ""
		}
	}

	data, _ := json.MarshalIndent(out, "", "  ")
	_ = os.WriteFile(path, data, 0o644)
}

func getColor(colors map[string]string, key, fallback string) string {
	if v, ok := colors[key]; ok && v != "" {
		return normalizeHex(v)
	}
	return fallback
}

func readJSON(path string) map[string]string {
	data, err := os.ReadFile(expandPath(path))
	if err != nil {
		return map[string]string{}
	}
	out := map[string]string{}
	_ = json.Unmarshal(data, &out)
	return out
}

func snakeToCamel(value string) string {
	parts := strings.Split(value, "_")
	if len(parts) == 1 {
		return parts[0]
	}
	for i := 1; i < len(parts); i++ {
		if parts[i] == "" {
			continue
		}
		parts[i] = strings.ToUpper(parts[i][:1]) + parts[i][1:]
	}
	return strings.Join(parts, "")
}

func normalizeHex(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return value
	}
	if !strings.HasPrefix(value, "#") {
		value = "#" + value
	}
	return strings.ToUpper(value)
}

func interpolateHex(a, b string, t float64) string {
	r1, g1, b1 := hexToRGB(a)
	r2, g2, b2 := hexToRGB(b)
	r := int(float64(r1) + (float64(r2)-float64(r1))*t)
	g := int(float64(g1) + (float64(g2)-float64(g1))*t)
	bVal := int(float64(b1) + (float64(b2)-float64(b1))*t)
	return fmt.Sprintf("#%02X%02X%02X", clampInt(r), clampInt(g), clampInt(bVal))
}

func harmonizeHSL(base string, target string, threshold float64, harmony float64) string {
	h1, s1, l1 := rgbToHsl(hexToRGBFloat(base))
	h2, _, _ := rgbToHsl(hexToRGBFloat(target))

	diff := differenceDegrees(h1, h2)
	rotation := math.Min(diff*harmony, threshold)
	direction := rotationDirection(h1, h2)
	newHue := sanitizeDegrees(h1 + rotation*direction)

	r, g, b := hslToRgb(newHue, s1, l1)
	return rgbToHex(r, g, b)
}

func adjustHSL(hex string, satFactor float64, lightnessFactor float64) string {
	h, s, l := rgbToHsl(hexToRGBFloat(hex))
	s = clamp(s*satFactor, 0, 1)
	l = clamp(l*lightnessFactor, 0, 1)
	r, g, b := hslToRgb(h, s, l)
	return rgbToHex(r, g, b)
}

func differenceDegrees(a, b float64) float64 {
	diff := math.Mod(math.Abs(a-b), 360)
	if diff > 180 {
		return 360 - diff
	}
	return diff
}

func rotationDirection(a, b float64) float64 {
	delta := math.Mod(b-a+360, 360)
	if delta == 0 {
		return 0
	}
	if delta <= 180 {
		return 1
	}
	return -1
}

func sanitizeDegrees(deg float64) float64 {
	deg = math.Mod(deg, 360)
	if deg < 0 {
		deg += 360
	}
	return deg
}

func rgbToHex(r, g, b float64) string {
	return fmt.Sprintf("#%02X%02X%02X", clampInt(int(r*255)), clampInt(int(g*255)), clampInt(int(b*255)))
}

func hexToRGB(hex string) (int, int, int) {
	hex = strings.TrimPrefix(normalizeHex(hex), "#")
	if len(hex) != 6 {
		return 0, 0, 0
	}
	var r, g, b int
	fmt.Sscanf(hex, "%02X%02X%02X", &r, &g, &b)
	return r, g, b
}

func hexToRGBFloat(hex string) (float64, float64, float64) {
	r, g, b := hexToRGB(hex)
	return float64(r) / 255.0, float64(g) / 255.0, float64(b) / 255.0
}

func rgbToHsl(r, g, b float64) (float64, float64, float64) {
	max := math.Max(r, math.Max(g, b))
	min := math.Min(r, math.Min(g, b))
	l := (max + min) / 2

	if max == min {
		return 0, 0, l
	}

	d := max - min
	s := d / (1 - math.Abs(2*l-1))

	var h float64
	switch max {
	case r:
		h = math.Mod((g-b)/d, 6)
	case g:
		h = (b-r)/d + 2
	case b:
		h = (r-g)/d + 4
	}
	return sanitizeDegrees(h * 60), s, l
}

func hslToRgb(h, s, l float64) (float64, float64, float64) {
	c := (1 - math.Abs(2*l-1)) * s
	x := c * (1 - math.Abs(math.Mod(h/60, 2)-1))
	m := l - c/2

	var r, g, b float64
	switch {
	case h >= 0 && h < 60:
		r, g, b = c, x, 0
	case h >= 60 && h < 120:
		r, g, b = x, c, 0
	case h >= 120 && h < 180:
		r, g, b = 0, c, x
	case h >= 180 && h < 240:
		r, g, b = 0, x, c
	case h >= 240 && h < 300:
		r, g, b = x, 0, c
	default:
		r, g, b = c, 0, x
	}

	return r + m, g + m, b + m
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

func clampInt(value int) int {
	if value < 0 {
		return 0
	}
	if value > 255 {
		return 255
	}
	return value
}

func expandPath(path string) string {
	if strings.HasPrefix(path, "~") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, strings.TrimPrefix(path, "~/"))
	}
	return path
}
