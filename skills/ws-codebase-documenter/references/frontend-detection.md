# Frontend Detection Reference

Procedures for scanning and classifying frontend assets, CSS methodology, design tokens, breakpoints, JS initialization patterns, build tools, and anti-patterns. Loaded when `config.frontend.enabled` is `true`.

## Table of Contents
1. [Monorepo Guard](#monorepo-guard)
2. [Detect CSS/SCSS Assets](#detect-cssscss-assets)
3. [Detect CSS Methodology](#detect-css-methodology)
4. [Detect Design Tokens](#detect-design-tokens)
5. [Detect Breakpoints](#detect-breakpoints)
6. [Detect JS Initialization Patterns](#detect-js-initialization-patterns)
7. [Detect Build Tools](#detect-build-tools)
8. [Detect Anti-Patterns](#detect-anti-patterns)
9. [Output Structure](#output-structure)

---

## Monorepo Guard

Run this procedure **before** all other detection procedures.

1. Check if any of these exist at the project root:
   - `workspaces` field in `package.json`
   - `lerna.json`
   - `nx.json`
   - `pnpm-workspace.yaml`
2. If no monorepo indicator is detected, proceed normally with all detection procedures.
3. If `config.frontend.css_paths` IS set, proceed normally even in a monorepo — the user has explicitly scoped the scan.
4. If a monorepo is detected AND `config.frontend.css_paths` is empty, attempt to auto-detect the primary frontend workspace:

   a. Resolve the workspace directories:
      - `package.json` workspaces: expand the `workspaces` glob patterns (e.g., `packages/*`, `apps/*`)
      - `pnpm-workspace.yaml`: read the `packages` list
      - `lerna.json`: read the `packages` list
      - `nx.json`: list directories containing `project.json` or listed in `workspace.json`

   b. For each workspace directory, read its `package.json` and check `dependencies` + `devDependencies` for frontend framework indicators:

   | Indicator Package | Framework |
   |-------------------|-----------|
   | `react`, `react-dom` | React |
   | `next` | Next.js |
   | `vue` | Vue |
   | `nuxt` | Nuxt |
   | `svelte`, `@sveltejs/kit` | Svelte |
   | `@angular/core` | Angular |
   | `solid-js` | Solid |
   | `astro` | Astro |

   c. Count how many workspaces have at least one frontend indicator.

   d. **Exactly one workspace found**: Use it as the frontend root. Set the scan scope to that workspace directory and proceed with all detection procedures scoped to it. Log: `"Monorepo detected. Auto-selected workspace '{workspace_name}' as frontend root."`

   e. **Zero workspaces found**: No frontend detected. Set all frontend detection results to empty/null. Log: `"Monorepo detected. No frontend workspace found. Set frontend.enabled to false in config.json, or set frontend.css_paths manually."` Stop.

   f. **Multiple workspaces found**: Ambiguous — do not guess. Set all frontend detection results to empty/null. Log: `"Monorepo detected with multiple frontend workspaces: {list}. Set frontend.css_paths and frontend.js_paths in config.json to specify which workspace to scan."` Stop.

---

## Detect CSS/SCSS Assets

### Inputs
- `config.frontend.css_paths` (optional array of paths)
- Project root path

### Steps

1. Glob for `*.css`, `*.scss`, `*.less`, `*.sass` files. Exclude these directories:
   ```
   node_modules, vendor, dist, build, target
   ```
2. If `config.frontend.css_paths` is set, limit the search to those paths. Otherwise search from the project root.
3. Identify the root/entry stylesheet. Check for common entry names first:
   ```
   main.scss, style.scss, app.scss, index.scss, global.scss
   main.css, style.css, app.css, index.css, global.css
   ```
   If no common name matches, find the file with the most `@import` or `@use` statements:
   ```regex
   @(import|use)\s+['"]
   ```
4. Trace the import chain from the root stylesheet. Follow each `@import` and `@use` to discover the full file tree.
5. Classify the organization pattern:

   | Pattern | Indicator |
   |---------|-----------|
   | by-component | Stylesheets co-located with component files (e.g., `Button/Button.scss`) |
   | by-block | Stylesheets in a `blocks/` or `components/` directory separate from source |
   | by-page | Stylesheets named after routes or pages (e.g., `home.scss`, `about.scss`) |
   | flat | All stylesheets in a single directory with no sub-structure |

6. Record results:
   - `css_files`: list of all discovered CSS/SCSS/LESS/SASS file paths
   - `root_stylesheet`: path to the identified entry stylesheet
   - `organization`: one of `by-component`, `by-block`, `by-page`, `flat`

---

## Detect CSS Methodology

### Inputs
- List of CSS/SCSS files from the previous procedure
- `config.frontend.methodology` (optional override)

### Steps

1. If `config.frontend.methodology` is explicitly set, use that value. Skip auto-detection. Record the value and stop.
2. Sample up to 10 CSS/SCSS files. Prefer files with the most lines of content.
3. Run each detection heuristic against the sampled files:

#### BEM Detection

Search for class selectors matching the BEM pattern:

```regex
\.([\w-]+)__([\w-]+)(?:--([\w-]+))?
```

If >60% of class selectors in the sample match this pattern, classify as `BEM`.

#### Utility-First Detection

Check for `tailwind.config.js`, `tailwind.config.ts`, or `tailwind.config.cjs` at the project root. Also search for high frequency of single-property utility classes:

```regex
\.(m|p|mx|my|px|py|mt|mr|mb|ml|pt|pr|pb|pl|w|h|flex|grid|text|bg|border|rounded|shadow|z)-
```

If Tailwind config exists OR >50% of classes match utility patterns, classify as `utility-first`.

#### CSS Modules Detection

Search for files matching:

```
*.module.css, *.module.scss
```

If any are found, classify as `css-modules`.

#### CSS-in-JS Detection

Search for import statements from known CSS-in-JS libraries:

```regex
import .+ from ['"](?:styled-components|@emotion\/|@stitches\/|@vanilla-extract\/)
```

If any are found, classify as `css-in-js`.

#### Component-Scoped Detection

Search for:
- Vue SFC scoped styles: `<style scoped>`
- Angular `styleUrls` in component decorators: `styleUrls\s*:\s*\[`
- Co-located files where `ComponentName.scss` sits beside `ComponentName.tsx` or `ComponentName.vue`

If any are found, classify as `component-scoped`.

#### SMACSS Detection

Check for a directory structure matching:

```
base/, layout/, module/, state/, theme/
```

If 3 or more of these directories exist under the CSS root, classify as `SMACSS`.

### Decision Table

| Indicator | Methodology |
|-----------|-------------|
| >60% BEM-pattern class selectors | `BEM` |
| Tailwind config OR >50% utility classes | `utility-first` |
| `*.module.css`/`*.module.scss` files present | `css-modules` |
| Imports from styled-components/emotion/stitches/vanilla-extract | `css-in-js` |
| `<style scoped>`, `styleUrls`, or co-located `Component.scss` | `component-scoped` |
| 3+ SMACSS directories present | `SMACSS` |
| None of the above | `unstructured` |

If multiple indicators match, prefer the one with the strongest signal (highest percentage or most files).

4. Record: `methodology` as the detected or configured value.

---

## Detect Design Tokens

### Inputs
- `config.frontend.token_files` (optional array of paths)
- Project root path

### Steps

1. If `config.frontend.token_files` is set, use those paths. Otherwise search for known token file names:
   ```
   _variables.scss, _tokens.scss, variables.scss, tokens.ts, tokens.json,
   theme.ts, theme.js, design-tokens.json
   ```
2. For each discovered token file, extract variables.

   **SCSS variables:**
   ```regex
   \$([\w-]+)\s*:\s*(.+?)\s*(?:!default\s*)?;
   ```

   **CSS custom properties:**
   ```regex
   --([\w-]+)\s*:\s*(.+?)\s*;
   ```

3. Categorize each token by its prefix:

   | Prefix Pattern | Category |
   |---------------|----------|
   | `$color-*`, `--color-*`, `$clr-*` | Colors |
   | `$spacing-*`, `--spacing-*`, `$space-*` | Spacing |
   | `$font-*`, `--font-*`, `$type-*` | Typography |
   | `$bp-*`, `$breakpoint-*`, `--bp-*` | Breakpoints |
   | `$shadow-*`, `--shadow-*` | Shadows |
   | `$radius-*`, `--radius-*`, `$border-radius-*` | Border Radii |
   | `$z-*`, `$z-index-*`, `--z-*` | Z-Index |

   Tokens that do not match any prefix pattern go into an `other` category.

4. Record:
   - `token_files`: list of discovered token file paths
   - `token_counts`: count per category
   - `tokens`: full name-value list grouped by category

---

## Detect Breakpoints

### Inputs
- Tokens from the design tokens procedure (breakpoint category)
- List of CSS/SCSS files

### Steps

1. Extract breakpoint tokens identified in the design tokens procedure (category: Breakpoints).
2. Extract breakpoint values from media queries across all CSS/SCSS files:
   ```regex
   @media\s*[^{]*\b(min|max)-width\s*:\s*(\d+(?:\.\d+)?(?:px|em|rem))
   ```
3. Deduplicate breakpoint values. Merge values from tokens and media queries.
4. Determine the approach:
   - Count occurrences of `min-width` queries vs `max-width` queries across all files.
   - If `min-width` queries are the majority, classify as `mobile-first`.
   - If `max-width` queries are the majority, classify as `desktop-first`.
5. Record:
   - `breakpoint_values`: list of name-value pairs (use token names where available, otherwise use the raw pixel value as the name)
   - `approach`: `mobile-first` or `desktop-first`

---

## Detect JS Initialization Patterns

### Inputs
- `config.frontend.js_paths` (optional array of paths)
- Project root path

### Steps

1. If `config.frontend.js_paths` is set, limit search to those paths. Otherwise search for `*.js`, `*.ts`, `*.jsx`, `*.tsx` files excluding `node_modules`, `vendor`, `dist`, `build`, `target`.
2. Scan for initialization patterns:

   | Pattern | Detection Regex/Indicator | Framework |
   |---------|--------------------------|-----------|
   | DOM Ready | `DOMContentLoaded`, `\$\(document\)\.ready`, `\$\(function\(\)` | Vanilla/jQuery |
   | React | `ReactDOM\.render`, `createRoot`, `hydrateRoot` | React |
   | Vue | `Vue\.createApp`, `new Vue`, `createApp` (from `vue`) | Vue |
   | Svelte | `new App\(\{\s*target:` | Svelte |
   | Module Init | `\.init\(\)` calls on imported modules | Custom |
   | WordPress | `wp_enqueue_script` in `.php` files | WordPress |
   | Next.js | `app/` directory containing `page.tsx` or `layout.tsx` | Next.js |

3. For each matched entry point file, record:
   - File path
   - Which initialization pattern it uses
   - Its imported dependencies (first-party modules only)
4. Record:
   - `js_entry_points`: list of `{ path, pattern, dependencies }`

---

## Detect Build Tools

### Inputs
- Project root path
- `config.frontend.build_tool` (optional override)

### Steps

1. Check for config files at the project root:

   | File Pattern | Build Tool |
   |-------------|-----------|
   | `webpack.config.*` | webpack |
   | `vite.config.*` | vite |
   | `gulpfile.*` | gulp |
   | `rollup.config.*` | rollup |
   | `esbuild.*` or `build.mjs` with `esbuild` import | esbuild |
   | `postcss.config.*` | postcss |
   | `tailwind.config.*` | tailwind |
   | `.babelrc` or `babel.config.*` | babel |
   | `next.config.*` | next.js |
   | `nuxt.config.*` | nuxt |

2. If `config.frontend.build_tool` is set, use that value as the primary build tool.
3. If a build tool config is detected, read it and extract:
   - Entry point(s)
   - Output path(s)
   - Key loaders or plugins
4. Check `package.json` `scripts` for build-related commands:
   ```
   build, dev, start, serve, watch
   ```
5. Record:
   - `build_tool`: name of the detected or configured build tool
   - `config_path`: path to the build tool config file
   - `entry`: entry point(s) from the config
   - `output`: output path(s) from the config
   - `scripts`: relevant `package.json` scripts

---

## Detect Anti-Patterns

### Inputs
- List of CSS/SCSS files
- List of template files (`*.html`, `*.php`, `*.jsx`, `*.tsx`, `*.vue`, `*.blade.php`, `*.cshtml`, `*.erb`, `*.twig`, `*.hbs`)
- Design tokens from the tokens procedure

### Steps

1. **Count `!important` occurrences.** Search all CSS/SCSS files for:
   ```regex
   !important
   ```
   Record count per file and total count.

2. **Count inline styles.** Search all template files for:
   ```regex
   style\s*=\s*["']
   ```
   Record count per file and total count.

3. **Detect duplicated color values.** Extract all hex color values from CSS/SCSS files:
   ```regex
   #[0-9a-fA-F]{3,8}
   ```
   For each hex value that appears in 3 or more different files: check if a color token already exists with that value. If yes, flag as a duplicated color anti-pattern.

4. Record:
   - `important_count`: total `!important` occurrences
   - `inline_style_count`: total inline style occurrences
   - `duplicated_colors`: list of hex values that appear in 3+ files where a token equivalent exists

---

## Output Structure

After all procedures complete, assemble the results into this structure:

```
Frontend Scan Results:
- css_files: [list of paths]
- root_stylesheet: path
- organization: pattern name
- methodology: detected methodology
- tokens: { colors: [...], spacing: [...], typography: [...], breakpoints: [...], shadows: [...], radii: [...], z_index: [...] }
- breakpoints: { values: [...], approach: mobile-first|desktop-first }
- js_entry_points: [{ path, pattern, dependencies }]
- build_tool: { name, config_path, entry, output }
- anti_patterns: { important_count, inline_style_count, duplicated_colors: [...] }
```

This structure feeds into:
- `style-guide.md` generation (step 2.5, item 9)
- `frontend_stats` in `.docstate` (step 2.7)
- `detected_patterns.frontend_*` in `.docstate`
- Consistency checking rules (step 3.4.5)
