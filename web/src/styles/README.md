# Web theme (mirrors the Flutter app)

`app-theme.css` = design tokens + shared primitives, imported by `index.css`. Everything below
exists already — build screens from these instead of inventing new styles.
(`index.css` also contains fork A's own screen styles: home, create, join, room.)

## Page frame
```tsx
<div className="app-page">            {/* phone column, max 520px, centered, bg #F2F3FF */}
  <AppBar title="내 전적" />            {/* components/AppBar */}
  <div className="page-body"> … </div> {/* padding 16, vertical gap 14 */}
</div>
```
`app-page--wide` = up to 1080px. `bottom-bar` = sticky bottom area for the primary action.

## Components (src/components)
| import | use |
|---|---|
| `AppBar` | `title`, `back` (true = history back / string = path / false), `actions`, `variant` = indigo (default) / primary / gradient / dark |
| `SectionCard` | white card with coloured icon box + title/subtitle/badge, children inside |
| `Avatar` | `name`, `size` sm/md/lg/xl, `crown`, `online`, `onBrand` |
| `toast(text, "ok"|"error"|"info")` | floating snackbar (host is mounted in App) |
| `confirmDialog({title, content, confirmLabel, danger})` | `await` → boolean |

## CSS classes
- **Cards**: `card`, `card--flat`, `card--tint`, `card--clickable`; headers `section-head` (+ `__text/__title/__sub`), `section-label` (small caps label above a group)
- **Icon box**: `icon-box` + `icon-box--primary|accent|blue|red|orange|purple|ghost`, `icon-box--lg`
- **Buttons**: `btn` (primary gradient) + `btn--block`, `btn--accent`, `btn--danger`, `btn--ghost` (white/outlined), `btn--soft`, `btn--white`, `btn--sm`; `disabled` greys out
- **Chips**: `chip-row` > `chip` (+ `is-on`); `badge` (+ `badge--green|orange|red`), `pill`
- **Forms**: `field` > `field__label` + `input` | `select` | `field__count`; `input-icon` > `input-icon__glyph` + `input`; `switch` (`<label class="switch"><input type=checkbox><span class="switch__track"/></label>`); `slider-card` (`slider-card__top` + `pill` + `input.range`); `field-error`
- **Lists**: `list` > `list-tile` (`__body`, `__title`, `__sub`, `__chev`), `progress` > `<i style="width:40%">`, `list-divider`, `mono`
- **Overlays**: `sheet` inside `backdrop backdrop--sheet`, `dialog` inside `backdrop`
- **Misc**: `empty` (`empty__icon`, `empty__title`), `spinner`, `row`, `col`, `grow`, `muted`, `center`, `anim-up`

Tokens: `--primary #6C63FF`, `--accent #00C896`, `--bg #F2F3FF`, `--text`, `--text-2`, `--grad-primary|accent|indigo`, `--shadow-card|btn|soft`, `--r-card 18px`, `--r-btn 14px`.
Inputs are 16px on purpose (iOS Safari zooms into smaller ones).

## Build / test (fork A)
`cd web; npx tsc -b && npx vite build --outDir .dist-a --emptyOutDir` (never write `web/dist`).
