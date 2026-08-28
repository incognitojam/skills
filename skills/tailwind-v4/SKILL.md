---
name: tailwind-v4
description: Tailwind CSS v4 conventions and v3 differences — CSS-first `@theme` configuration, automatic content detection, renamed and removed utilities, built-in container queries, OKLCH colors, and the Vite and PostCSS setups. Use when writing Tailwind in a project on v4, migrating one from v3, or when generated utility classes or config do not behave as expected.
---

# Tailwind CSS v4

## Key Changes from v3

| Aspect | v3 | v4 |
|--------|----|----|
| Config | `tailwind.config.js` | CSS `@theme` directive |
| Entry | Multiple `@tailwind` directives | Single `@import "tailwindcss"` |
| Tokens | JavaScript objects | CSS custom properties |
| Plugins | `require()` in JS | `@plugin` in CSS |
| Content | Manual `content` array | Automatic (respects .gitignore) |

## CSS-First Configuration

### Before (v3)

```javascript
// tailwind.config.js
module.exports = {
  content: ['./src/**/*.{html,js,tsx}'],
  theme: {
    extend: {
      colors: { brand: '#3b82f6' },
      fontFamily: { display: ['Satoshi', 'sans-serif'] },
    },
  },
  plugins: [require('@tailwindcss/typography')],
}
```

### After (v4)

```css
/* app.css */
@import "tailwindcss";

@theme {
  --color-brand: oklch(0.55 0.15 250);
  --font-display: "Satoshi", sans-serif;
  --breakpoint-3xl: 1920px;
}

@plugin "@tailwindcss/typography";
```

## @theme Variable Naming

| Token Type | Pattern | Example |
|------------|---------|---------|
| Colors | `--color-{name}-{shade}` | `--color-blue-500` |
| Fonts | `--font-{name}` | `--font-display` |
| Breakpoints | `--breakpoint-{name}` | `--breakpoint-3xl` |
| Spacing | `--spacing-{value}` | `--spacing-18` |
| Shadows | `--shadow-{size}` | `--shadow-glow` |
| Easing | `--ease-{name}` | `--ease-bounce` |

## Renamed Utilities

The scale shifted to make room for smaller values:

| v3 | v4 |
|----|----|
| `shadow-sm` | `shadow-xs` |
| `shadow` (default) | `shadow-sm` |
| `blur-sm` | `blur-xs` |
| `blur` (default) | `blur-sm` |
| `rounded-sm` | `rounded-xs` |
| `rounded` (default) | `rounded-sm` |

## Removed Utilities

These opacity utilities are removed - use modifiers instead:

```html
<!-- v3 (removed) -->
<div class="bg-blue-500 bg-opacity-50"></div>

<!-- v4 -->
<div class="bg-blue-500/50"></div>
```

Removed: `bg-opacity-*`, `text-opacity-*`, `border-opacity-*`, `ring-opacity-*`, `placeholder-opacity-*`

Also renamed:
- `flex-shrink-*` → `shrink-*`
- `flex-grow-*` → `grow-*`
- `overflow-ellipsis` → `text-ellipsis`

## Container Queries (Built-in)

No plugin needed - container queries are native in v4:

```html
<!-- Mark a container -->
<div class="@container">
  <!-- Use @-prefixed variants -->
  <div class="grid grid-cols-1 @sm:grid-cols-2 @lg:grid-cols-4">
    Content
  </div>
</div>

<!-- Named containers -->
<div class="@container/sidebar">
  <div class="@sm/sidebar:flex">Content</div>
</div>
```

### Container Sizes

| Variant | Width |
|---------|-------|
| `@xs` | 320px |
| `@sm` | 384px |
| `@md` | 448px |
| `@lg` | 512px |
| `@xl` | 576px |
| `@2xl` | 672px |

## OKLCH Colors

v4 uses OKLCH for wider color gamut and better gradients:

```css
@theme {
  /* oklch(Lightness Chroma Hue) */
  --color-primary: oklch(0.55 0.15 250);
  --color-accent: oklch(0.70 0.20 30);
}
```

### Gradient Interpolation

```html
<!-- Default (sRGB) - can look muddy -->
<div class="bg-linear-to-r from-indigo-500 to-teal-400"></div>

<!-- OKLCH interpolation - more vivid -->
<div class="bg-linear-to-r/oklch from-indigo-500 to-teal-400"></div>
```

## New Directives

| Directive | Purpose | Example |
|-----------|---------|---------|
| `@import "tailwindcss"` | Load Tailwind | Entry point |
| `@theme` | Define design tokens | `--color-brand: ...` |
| `@utility` | Create utilities | `@utility tab-4 { tab-size: 4; }` |
| `@custom-variant` | Create variants | `@custom-variant dark (...)` |
| `@plugin` | Load JS plugins | `@plugin "@tailwindcss/typography"` |
| `@source` | Add content sources | `@source "../packages/ui"` |

## Custom Utilities

```css
/* v3 */
@layer utilities {
  .tab-4 { tab-size: 4; }
}

/* v4 */
@utility tab-4 {
  tab-size: 4;
}
```

## Dark Mode

Default is `prefers-color-scheme`. For class-based:

```css
/* Class-based dark mode */
@custom-variant dark (&:where(.dark, .dark *));

/* Data attribute */
@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));
```

## Accessing Theme Values

```css
/* In CSS */
.my-class {
  background-color: var(--color-red-500);
}

/* In media queries */
@media (width >= theme(--breakpoint-xl)) {
  /* styles */
}
```

## Vite Setup

```typescript
// vite.config.ts
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [tailwindcss()],
});
```

## PostCSS Setup

```javascript
// postcss.config.js
export default {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
```

## Migration

```bash
# Automated upgrade tool
npx @tailwindcss/upgrade
```

The tool handles:
- Dependency updates
- Config migration to CSS
- Utility class renaming
- Plugin directive conversion

## Ring Default Change

```html
<!-- v3: ring was 3px blue-500 -->
<button class="focus:ring"></button>

<!-- v4: ring is 1px currentColor - be explicit -->
<button class="focus:ring-3 focus:ring-blue-500"></button>
```

## Browser Support

v4 requires modern browsers:
- Safari 16.4+
- Chrome 111+
- Firefox 128+

Uses: `@property`, `color-mix()`, cascade layers.

## Performance

| Build | v3.4 | v4.0 |
|-------|------|------|
| Full | 960ms | 105ms |
| Incremental (new CSS) | 44ms | 5ms |
| Incremental (no new) | 35ms | 192us |

## Official Docs

- [Tailwind v4 Release](https://tailwindcss.com/blog/tailwindcss-v4)
- [Upgrade Guide](https://tailwindcss.com/docs/upgrade-guide)
- [Functions and Directives](https://tailwindcss.com/docs/functions-and-directives)
