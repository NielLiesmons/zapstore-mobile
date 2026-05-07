---
description: Design system — colors, typography, stroke, radius, buttons, icons, spacing, patterns
alwaysApply: true
---

# Zapstore — Design System

For component APIs (ProfilePic, AppPic, LabButton, LabIcon, showModal, etc.), see `spec/guidelines/DESIGN_COMPONENTS.md`.

## Code Locations

| What | File |
|------|------|
| Colors, stroke, radius, theme | `lib/theme.dart` |
| Typography tokens | `lib/utils/text_styles.dart` |
| Button component | `lib/widgets/common/button.dart` |
| Icon component + registry | `lib/widgets/icons/icons.dart` |
| SVG icon assets | `assets/icons/` (normal) and `assets/icons/thick/` |
| Top scroll fader + scroll-to-top button | `lib/widgets/common/top_scroll_fader.dart` |
| Scroll-to-top button | `lib/widgets/common/scroll_to_top_button.dart` |
| Modal helper | `lib/widgets/common/modal.dart` |
| Dropdown / context menu | `lib/widgets/common/dropdown_menu.dart` |

## Color System

Access via `Theme.of(context).extension<LabColors>()!`. Never hardcode hex values.

### White opacity scale

| Token | Opacity | Use case |
|-------|---------|----------|
| `c.white` | 100% | Primary text |
| `c.white66` | 66% | Secondary text |
| `c.white33` | 33% | Tertiary text, timestamps |
| `c.white16` | 16% | Element borders |
| `c.white11` | 11% | Dividers |
| `c.white8` | 8% | Subtle backgrounds |
| `c.white4` | 4% | Very subtle backgrounds |
| `c.whiteEnforced` | ~100% | Theme-aware near-white — always close to white regardless of theme. Use on colored backgrounds (gradient buttons, primary CTAs) where readability must be guaranteed. |

### Surface colors

| Token | Use case |
|-------|----------|
| `c.black` | App background |
| `c.gray` | Surface (#242424) |
| `c.gray66` | Panel / button default background |
| `c.gray33` | Input fill, subtle containers |

### Semantic gradients

| Token | Use case |
|-------|----------|
| `c.blurple` | Primary CTA buttons, default success state |
| `c.blurple66/33/16` | Dimmed blurple accents |
| `c.gold` | Zap / secondary actions |
| `c.rouge` | Destructive actions |
| `c.green` | Explicit confirmation states only (installed, completed). Rarely used — default success uses `c.blurple`. |
| `c.graydient` | Neutral gradient headings |

Each gradient family also has `66/33/16` opacity variants.

### Profile text color

Use `profileTextColor(hexToColor(pubkey))` or `profileTextColor(stringToColor(name))` for name/avatar accent colors. Never hardcode profile colors.

## Typography

Font: **Inter** (variable, `FontVariation('wght', value)`). Code blocks: **JetBrains Mono** (`LabTextStyles.code`).

Tokens are literal — the number IS the pixel size.

### Heading tokens

Weight 700 throughout. Named for what they are, not where they sit.

| Token | Size | Tracking | Use case |
|-------|------|----------|----------|
| `semibold23` | 23px | 0.7 | App name hero, screen titles, modal headings |
| `eyebrow13` | 13px | 2.2 | ALL-CAPS section eyebrows |
| `eyebrow11` | 11px | 2.2 | Compact ALL-CAPS labels |

### Body tokens

| Token | Size | Weight | Use case |
|-------|------|--------|----------|
| `semibold17` | 17px | 600 | Emphasized body |
| `med17` | 17px | 500 | Default body text |
| `reg17` | 17px | 400 | Descriptions |
| `semibold15` | 15px | 600 | Strong labels |
| `med15` | 15px | 500 | Button text, default labels |
| `reg15` | 15px | 400 | Secondary body |
| `semibold13` | 13px | 600 | Profile names in bubbles |
| `med13` | 13px | 500 | Compact labels |
| `reg13` | 13px | 400 | Small body text |
| `med11` | 11px | 500 | Timestamps, badge counters |
| `reg11` | 11px | 400 | Smallest readable text |

Always use `.copyWith(color: …)` — tokens have no color baked in.

## Stroke

| Constant | Value | Use case |
|----------|-------|----------|
| `LabStroke.thin` | 0.33px | Input fields, comment boxes, bottom-bar input-style containers, dropdown/picker dividers. **Never on panels or cards — those have no border.** |
| `LabStroke.medium` | 1.6px | Default for all outline SVG icons and dividers in main screens. |
| `LabStroke.thick` | 3.2px | Emphasis borders, thick SVG icon variant. |

Always use `LabBorder.all(color: …, width: …)` instead of `Border.all()` — it uses `strokeAlignCenter` to match CSS box-model behaviour (no layout inflation).

## Radius

| Constant | Value | Use case |
|----------|-------|----------|
| `LabRadius.r4` | 4px | Micro — incoming bubble corner |
| `LabRadius.r8` | 8px | Small pill, app icon xs |
| `LabRadius.r11` | 11px | Standard — input fields, small containers |
| `LabRadius.r14` | 14px | Medium containers |
| `LabRadius.r17` | 17px | Pill button (34px height ÷ 2) |
| `LabRadius.r20` | 20px | Large containers |
| `LabRadius.r24` | 24px | Large app icons |
| `LabRadius.r32` | 32px | Modals & bottom bars |

## Panels

- Default panel: `gray66` background, `LabRadius.r16` radius, 16px padding.
- **Panels have zero borders.** Never add borders or box-shadows to panel-like containers.
- Exception: input fields and interactive containers use `LabStroke.thin` via `LabBorder.all`.

## Buttons

All buttons use factory constructors from `lib/widgets/common/button.dart`. No custom button widgets.

| Factory | Height | Radius | Background | Use case |
|---------|--------|--------|------------|----------|
| `LabButton.primary` | 40px | 10px | `c.blurple` gradient | Primary CTAs |
| `LabButton.secondary` | 40px | 10px | `c.gray66` | Secondary actions |
| `LabButton.primarySmall` | 34px | pill | `c.blurple` gradient | Compact primary |
| `LabButton.secondarySmall` | 34px | pill | `c.gray66` | Compact secondary |
| `LabButton.primaryXs` | 26px | pill | `c.blurple` gradient | Badges, inline actions |
| `LabButton.secondaryXs` | 26px | pill | `c.gray66` | Compact inline |
| `LabButton.tab` | 34px | pill | `c.blurple66` / `c.gray66` | `SocialTabs` buttons |

Press scale: `0.97` on tap-down, `1.0` on release. Built into `LabButton` — do not add external scale wrappers.

## Icons

SVG-based. Rendered via `LabIcon` from `lib/widgets/icons/icons.dart`.

```dart
LabIcon(LabIcons.zap, size: 20, color: c.white)             // outline, 1.6px stroke
LabIcon(LabIcons.zap, size: 20, color: c.white, thick: true) // 3.2px stroke
```

- Default stroke: **1.6px** (baked into SVG assets)
- Thick stroke: **3.2px** (`thick: true`)
- Standard sizes: 16, 18, 20, 24px
- Never call `SvgPicture.asset()` directly — always go through `LabIcon`

## Spacing

| Context | Value |
|---------|-------|
| Screen horizontal padding | 14px |
| Modal horizontal padding | 14px |
| Default gap between panels and content sections | 12px |
| Avatar → bubble gap (comments) | 6px |
| Message bubble vertical spacing | 4px top padding |
| Top bar height (home) | 42px |
| Top bar height (detail screens) | 48px |

**14px horizontal padding** is the universal standard across screens and modals. It is applied either at the container level (wrapping the entire screen body) or per-element (e.g. on individual rows that need padding while a full-width divider or image bleeds edge-to-edge). Never mix both on the same layer — pick one approach and be consistent within each screen or modal.

## Loading States

| Content type | Placeholder |
|--------------|-------------|
| App icons, profile pics, titles | Shimmer skeleton (`Skeletonizer`) |
| Body text, descriptions, secondary text | Static `gray33` container — **no shimmer** |

Show loading UI only after a 100ms delay. Before that, the screen is blank.

## Standard Screen Layout

~90% of screens share this layout pattern. Two structural variants exist depending on whether the top bar is floating (Stack) or fixed (Column).

### Floating-header screens (detail screens, updates, user profile, …)

Content scrolls beneath a blurred header that stays pinned at the top.

```dart
Scaffold(
  body: Stack(
    children: [
      // Full-body scrollable — behind the header
      Positioned.fill(
        child: TopScrollFader(
          scrollController: scrollController,
          fadeStart: headerHeight, // positions the fade gradient at the header bottom
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: headerHeight + 10, // clears the header
              bottom: MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: …,
          ),
        ),
      ),
      // Floating blurred header — on top
      Positioned(top: 0, left: 0, right: 0, child: _DetailHeader(…)),
    ],
  ),
)
```

Header height formula: `topPad + 48.0` (safe-area top + 8px gap + 30px row + 10px gap).

### Column-layout screens (home screen)

The top bar is a sibling widget above the scrollable; no overlap occurs.

```dart
Scaffold(
  body: Column(
    children: [
      _HomeTopBar(…),
      Expanded(
        child: TopScrollFader(
          scrollController: scrollController,
          // fadeStart and offsetBias omitted — y=0 is already below the bar
          child: SingleChildScrollView(…),
        ),
      ),
    ],
  ),
)
```

### Floating header appearance

Every floating blurred header uses the same visual recipe:

```dart
ClipRect(
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
    child: Container(
      color: c.black, // fills behind the blur so scrolled content doesn't show through
      child: Column(
        children: [
          SizedBox(height: topPad + 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(…), // back button / title / actions
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  ),
)
```

### Scroll Patterns

Use `TopScrollFader` wherever scrollable content passes under a floating header. It handles:
- The scroll-driven top-edge fade (content fades as it scrolls under the header)
- The `ScrollToTopButton` (appears after 1200px of scroll, bottom-right at 14px from edge)
- A blurred safe-area overlay at the very bottom edge (on screens without a `BottomBar`)

Key parameters:

| Parameter | Default | When to override |
|-----------|---------|-----------------|
| `fadeStart` | `null` (= `offsetBias`) | Set to `headerHeight` on floating-header screens |
| `showScrollToTop` | `true` | `false` on screens with a custom FAB at that position |
| `hasBottomBar` | `false` | `true` when the screen contains a `BottomBar` widget |

All horizontal scroll rows must apply an edge-fade mask (transparent → opaque → transparent, 14px fade matching screen padding).

## UI Surface Hierarchy

Three surface layers exist in the app. Choose based on content weight, not convenience:

| Layer | Component | When to use |
|-------|-----------|-------------|
| Full screen | `GoRouter` page push | Primary navigation destinations — app detail, updates list, user profile, settings |
| Modal | `showModal` | Secondary views that build on a primary screen — deeper comment threads, zap flow, onboarding steps, setting panels, action confirmations |
| Dropdown menu | `LabDropdownMenu` | Small contextual menus — option pickers, suggestion panels, inline action lists with 2–6 items |

**Rule:** modals are for depth (a user wants to go deeper into something on the current screen). Dropdowns are for breadth (a user wants to pick from a small set of options without leaving context). Never use a dropdown where a modal belongs.

## Modals

Use `showModal(context, builder: …)` from `lib/widgets/common/modal.dart`. No raw `showModalBottomSheet` calls.

**Visual spec:**
- Background: `gray66` + `BackdropFilter` blur 14px
- Border: `0.33px white8` on top, left, right (no bottom)
- Radius: 32px top corners
- Barrier: 65% black
- No drag handle
- Dismissible by tapping outside

**Behaviour:**
- Default max height: **75% of screen height**. Override with `maxHeightFactor`.
- `fillHeight: true` makes the sheet always reach `maxHeightFactor`.
- When the keyboard opens, the sheet expands to near-full-height automatically.
- Modal-in-modal: parent scales to `0.96` and receives a dark overlay automatically. Call `ModalNestScope.setNested(context, isOpen: true)` before opening a child modal and reset it on close.

**Content padding:**
Use **14px horizontal padding** inside modal content, matching screen padding. Apply it either at the top-level `Padding` wrapping the content column, or per-row when full-width elements (dividers, images) need to bleed edge-to-edge.

**Title and footer:**
- Pass `title:` and optionally `description:` to `showModal` for a standard centred heading block. The title scrolls with content (not pinned).
- Use `ModalFooterBar` as the `footer:` argument for a pinned bottom action bar (e.g. a comment input row). It includes a `0.33px white8` top divider and safe-area padding.

**Convenience variants:**
- `showConfirm(…)` — standard confirm/cancel dialog with title, message, and destructive-flag support.

## Dropdown Menus

Use `LabDropdownMenu` + `LabDropdownItem` from `lib/widgets/common/dropdown_menu.dart` for small floating contextual menus.

**Visual spec:**
- Background: `gray66` + `BackdropFilter` blur 24px
- Border: `0.33px white16`
- Radius: 16px
- Shadow: `0 8px 32px black33`
- Items: `10px 14px` padding, 14px/500 white text, `white4` press feedback
- Auto-divider (`0.33px white16`) between adjacent items; pass `isFirst: true` on the first item to suppress

**Item variants:**
- `isDanger: true` — label in rouge (destructive actions)
- `isActive: true` — label in white/600 (selected state)
- `trailing:` — optional trailing widget (e.g. a chevron icon)

**Positioning:** the caller is responsible for positioning via `Overlay`, `CompositedTransformFollower`, or absolute layout. `LabDropdownMenu` handles only appearance.

## Screen Transitions

All new screens push with a slide-from-right transition via `CustomTransitionPage` + `SlideTransition` in the router.

## Animations

| Element | Animation |
|---------|-----------|
| Button press | `AnimatedScale` 0.97 on tap-down |
| Swipe-to-reply trigger | `Curves.easeOutCubic` snap-back, 380ms |
| Swipe pop burst | Scale 1.0 → 1.2 → 1.0, 140ms |
| Profile pic / app pic tap | `AnimatedScale` 0.96 on press |

## General Rules

- Never hardcode colors — always use `LabColors` tokens via `Theme.of(context).extension<LabColors>()!`.
- Never use `Theme.of(context).colorScheme.*` for app-specific colors.
- Never use `Border.all()` — use `LabBorder.all()` (center-aligned stroke, no layout inflation).
- Never use `SvgPicture.asset()` directly — always use `LabIcon`.
- Font sizes are specified in literal pixels — no global scale factor.
- Pixel values are integers or simple fractions (0.33, 1.6, 3.2). No computed fractional arithmetic.
