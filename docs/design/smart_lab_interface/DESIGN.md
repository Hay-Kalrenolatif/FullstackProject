---
name: Smart Lab Interface
colors:
  surface: '#0f141a'
  surface-dim: '#0f141a'
  surface-bright: '#353a40'
  surface-container-lowest: '#0a0f14'
  surface-container-low: '#171c22'
  surface-container: '#1b2026'
  surface-container-high: '#252a31'
  surface-container-highest: '#30353c'
  on-surface: '#dee3eb'
  on-surface-variant: '#bbcac4'
  inverse-surface: '#dee3eb'
  inverse-on-surface: '#2c3137'
  outline: '#86948e'
  outline-variant: '#3c4a45'
  surface-tint: '#51dcbc'
  primary: '#78ffde'
  on-primary: '#00382d'
  primary-container: '#58e2c2'
  on-primary-container: '#006251'
  inverse-primary: '#006b58'
  secondary: '#c1d045'
  on-secondary: '#2e3300'
  secondary-container: '#8b9805'
  on-secondary-container: '#282c00'
  tertiary: '#f4e2ff'
  on-tertiary: '#490081'
  tertiary-container: '#e1bfff'
  on-tertiary-container: '#7237ac'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#72f9d8'
  primary-fixed-dim: '#51dcbc'
  on-primary-fixed: '#002019'
  on-primary-fixed-variant: '#005142'
  secondary-fixed: '#ddec5f'
  secondary-fixed-dim: '#c1d045'
  on-secondary-fixed: '#1a1e00'
  on-secondary-fixed-variant: '#444b00'
  tertiary-fixed: '#f0dbff'
  tertiary-fixed-dim: '#ddb8ff'
  on-tertiary-fixed: '#2c0051'
  on-tertiary-fixed-variant: '#62259b'
  background: '#0f141a'
  on-background: '#dee3eb'
  surface-variant: '#30353c'
  surface-card: '#182326'
  surface-card-subtle: '#161F22'
  surface-card-elevated: '#1C2729'
  warning-amber: '#F59E0B'
  warning-amber-tint: '#F6AD55'
  status-mint: '#3BD6B0'
  border-subtle: '#253438'
  border-glow-mint: '#58E2C240'
  border-glow-amber: '#F59E0B40'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
  display-stat:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system defines a technical, tactile dark-mode interface built specifically for smart laboratory hardware tracking, computer inventory, and real-time device diagnostics. It merges the ergonomics of modern high-utility mobile apps with the focused precision of enterprise instrumentation tools.

The interface evokes confidence, quiet precision, and effortless readability in low-light laboratory or server room environments. Rather than flat monochrome gray surfaces, it leverages rich obsidian and deep cyan-tinted charcoal tones paired with high-chroma neon accents: mint green for normal operational status, vibrant lemon-lime yellow for filters and high-priority metrics, neon amber for service warnings, and soft lilac for secondary multi-tier telemetry. 

The aesthetic is clean, modular, and modern corporate technicality, marked by rounded container geometry, gentle luminescent borders, pill-shaped tactile chips, and floating bottom navigation anchors.

## Colors

The palette is engineered around an OLED-optimized backdrop (`#10151B` and `#0D1117`) that reduces eye strain and provides superior contrast against chromatic diagnostic data.

### Functional Palette Structure
- **Primary (`#58E2C2`)**: The definitive system color representing online hardware, healthy system status, active navigation targets, and primary positive feedback.
- **Secondary (`#E2F163`)**: High-contrast lemon-lime yellow reserved for focused category selectors, active segment filters, and primary metric emphasis.
- **Tertiary (`#C084FC`)**: Soft technical lilac utilized across layered multi-axis metrics, concentric ring data visualizers, and secondary operational tallies.
- **Neutral (`#10151B`)**: Deep midnight obsidian base that serves as the deep field for higher-order surfaces.

### Surface and Status Tokens
- **Surfaces**: Cards and interactive trays utilize subtle cyan-tinted charcoals (`#161F22`, `#182326`, `#1C2729`), eliminating harsh pure black cutoffs while creating a coherent chromatic family.
- **Warning & Alert (`#F59E0B` / `#F6AD55`)**: High-visibility neon amber applied to fault notifications, equipment needing repair, and diagnostic warnings.
- **Borders & Radiance**: Micro-borders utilize `#253438` for soft structure, with glowing variant borders (`#58E2C240` and `#F59E0B40`) used dynamically to denote system health and urgent alerts.

## Typography

Typography is clean, highly legible, and optimized for technical legibility. Inter provides clear character distinction, structured tabular figures for inventory counts, and consistent baseline alignment across dense mobile and tablet displays.

### Hierarchy Guidelines
- **Display Stat & Headlines**: Bold, confident titles for screen contexts and prominent sensor summaries. Headers maintain concise line heights to preserve vertical screen efficiency.
- **Body Elements**: Standardized at regular weights (`400`) in muted gray tones (`#94A3B8` / `#CBD5E1`) to maintain clear hierarchy underneath pure white primary titles (`#FFFFFF`).
- **Data Specs and Key-Values**: Technical specifications (processor versions, RAM, port numbers) utilize `body-md` with semi-bold weights for numerical values and medium weights for metadata labels.

## Layout & Spacing

The layout model is anchored on an 8pt base grid with a fluid mobile container, transitioning into structured multi-column grids on tablets and desktop workstations.

### Grid & Margins
- **Mobile Viewports (< 640px)**: 16px outer margin (`space-md`), 12px internal card gap, with single-column linear stacks ensuring one-handed ergonomic interaction.
- **Tablet / Desktop Viewports (>= 768px)**: 24px outer margin (`space-lg`), 16px gutter (`gutter`), supporting a 2-column or 3-column card grid for asset matrices and equipment lists.
- **Vertical Rhythm**: 16px to 20px rhythm between distinct content blocks. Related micro-elements (chips, sub-details, pill badges) utilize 4px (`space-xs`) and 8px (`space-sm`) gaps.

### Docked Regions
Bottom navigation elements use floating rounded bar docks floating 16px above the display base, leaving safe margins for system gestures.

## Elevation & Depth

Visual hierarchy is achieved through distinct tonal layering and soft luminous glows rather than conventional heavy drop shadows.

### Elevation Hierarchy
1. **Level 0 (Base)**: `#10151B` canvas. Non-interactive, grounding backdrop.
2. **Level 1 (Cards & Groups)**: `#182326` background with a subtle, low-opacity outline (`1px solid #253438`). Provides clean containment for individual hardware units and metric summaries.
3. **Level 2 (Nested Interactive Elements)**: `#1C2729` or `#161F22` for inner action bars, counter toggles, and metadata cells.
4. **Level 3 (Floating Bars & Navigation)**: Deep translucent container (`#12191CD9` with `backdrop-filter: blur(16px)`) bounded by a hairline stroke (`#2B3C40`).

### Glows and Focus
- Active buttons and navigation pill triggers carry a soft, radial mint glow (`box-shadow: 0 0 16px rgba(88, 226, 194, 0.25)`).
- Critical warning cards carry an amber perimeter halo (`box-shadow: inset 0 0 0 1px rgba(245, 158, 11, 0.3)`).

## Shapes

The design system incorporates rounded, organic surface architecture that softens technical data presentation while retaining structured alignment.

### Geometry Specifications
- **Cards & Primary Modules**: Rounded corners at `1rem` to `1.25rem` (16px - 20px) to establish a friendly, ergonomic frame.
- **Action Buttons & Sub-containers**: Standard rounded shape (`0.5rem` to `0.75rem`), balancing structure and clickability.
- **Status Pills, Filter Tabs, and Nav Indicators**: Fully pill-shaped (`rounded-full` / `9999px`) to immediately denote toggleable states, tags, or live statuses.
- **Device Icon Badges**: Rounded squircle containers (`0.75rem` / 12px) housing hardware iconography.

## Components

### Buttons
- **Primary Action (Active / Affirmative)**: Filled pill or rounded rectangle with `#58E2C2` or `#E2F163` background, rich dark `#10151B` text, and bold weight.
- **Secondary / Action Strip**: Deep charcoal background (`#1C2729`), border `1px solid #28373B`, text in `#CBD5E1`. Hover/pressed states introduce subtle mint border brightening.
- **Destructive / Flag Button**: Outlined button or soft tint (`rgba(245, 158, 11, 0.1)`) with `#F59E0B` icon and typography, communicating maintenance requirements or damage marking.

### Chips & Status Pills
- **Filter Segment Chips**: Arranged in horizontal scroll rows. Selected chip is solid lemon-lime (`#E2F163`) with dark text; inactive chips are dark ghost surfaces with light text and subtle border.
- **Operational Status Indicators**: Pill badges featuring a 6px glowing indicator dot. Normal operations utilize green mint (`#3BD6B0`), while warning statuses utilize amber (`#F59E0B`).

### Hardware Inventory Cards
- Multi-tier cards built with `#182326` background, featuring:
  - Header with squircle device icon, unit title, inline status badge, and quick actions (edit, delete).
  - Key-value specification grid (Processor, RAM, Location) with dimmed labels and crisp white or accented values.
  - Action footer offering single-tap failure marking or maintenance dispatch.

### Progress Rings & Visualizers
- Concentric metric rings set against dark tracks (`#1F2B2E`), layering primary mint (`#58E2C2`), secondary lime (`#E2F163`), and tertiary lilac (`#C084FC`) to communicate proportional readiness without screen clutter.

### Counter Steppers
- Inline quantity modifiers featuring circular or squircle step buttons (`+` / `-`) flanking a centered bold quantity read-out, encased within a unified dark pill track.

### Floating Dock Navigation
- An elevated horizontal bar pinned to the screen bottom containing clean stroke icons. The active tab is framed within a glowing squircle or pill indicator highlighted with the seed mint tone (`#58E2C2`).