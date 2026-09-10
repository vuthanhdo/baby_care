---
name: Be Khoe - Bo Me An Tam
colors:
  surface: '#effcff'
  surface-dim: '#c8dee3'
  surface-bright: '#effcff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#e2f7fd'
  surface-container: '#dcf2f7'
  surface-container-high: '#d6ecf2'
  surface-container-highest: '#d1e6ec'
  on-surface: '#0a1e23'
  on-surface-variant: '#3f4946'
  inverse-surface: '#203338'
  inverse-on-surface: '#dff5fa'
  outline: '#6f7976'
  outline-variant: '#bec9c5'
  surface-tint: '#106a5e'
  primary: '#005248'
  on-primary: '#ffffff'
  primary-container: '#146c60'
  on-primary-container: '#9ceadb'
  inverse-primary: '#87d5c6'
  secondary: '#09658b'
  on-secondary: '#ffffff'
  secondary-container: '#8fd4ff'
  on-secondary-container: '#005c80'
  tertiary: '#624200'
  on-tertiary: '#ffffff'
  tertiary-container: '#7e5914'
  on-tertiary-container: '#ffd494'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#a3f1e2'
  primary-fixed-dim: '#87d5c6'
  on-primary-fixed: '#00201b'
  on-primary-fixed-variant: '#005047'
  secondary-fixed: '#c5e7ff'
  secondary-fixed-dim: '#89cff9'
  on-secondary-fixed: '#001e2d'
  on-secondary-fixed-variant: '#004c6a'
  tertiary-fixed: '#ffdead'
  tertiary-fixed-dim: '#efbf71'
  on-tertiary-fixed: '#281900'
  on-tertiary-fixed-variant: '#604100'
  background: '#effcff'
  on-background: '#0a1e23'
  surface-variant: '#d1e6ec'
  surface-bg: '#F7F9F8'
  surface-card: '#FFFFFF'
  text-primary: '#172D32'
  text-secondary: '#52666B'
  action-primary: '#146C60'
  action-primary-pressed: '#0E4E45'
  activity-medical: '#B63B48'
  activity-medical-surface: '#FBECEE'
  activity-nutrition: '#176B91'
  activity-nutrition-surface: '#E8F3FA'
  activity-routine: '#805B16'
  activity-routine-surface: '#FFF3D7'
  status-alert-border: '#F3B2B9'
  divider-hairline: '#E3E8E7'
typography:
  headline-large-title:
    fontFamily: Be Vietnam Pro
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 41px
    letterSpacing: -0.4px
  headline-large-title-mobile:
    fontFamily: Be Vietnam Pro
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.3px
  headline-title-1:
    fontFamily: Be Vietnam Pro
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
    letterSpacing: -0.2px
  headline-title-2:
    fontFamily: Be Vietnam Pro
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.15px
  headline-title-3:
    fontFamily: Be Vietnam Pro
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-large:
    fontFamily: Be Vietnam Pro
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 23px
  body-large-medium:
    fontFamily: Be Vietnam Pro
    fontSize: 17px
    fontWeight: '500'
    lineHeight: 23px
  body-medium:
    fontFamily: Be Vietnam Pro
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 21px
  body-medium-semibold:
    fontFamily: Be Vietnam Pro
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 21px
  label-callout:
    fontFamily: Be Vietnam Pro
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 19px
  label-footnote:
    fontFamily: Be Vietnam Pro
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-caption:
    fontFamily: Be Vietnam Pro
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.2px
  cta-button-text:
    fontFamily: Be Vietnam Pro
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  space-xxs: 4px
  space-xs: 8px
  space-sm: 12px
  space-md: 16px
  space-lg: 20px
  space-xl: 24px
  space-xxl: 32px
  margin-screen: 20px
  touch-target-min: 48px
  cta-height: 56px
  tabbar-height: 84px
  card-padding: 16px
---

## Brand & Style

This design system is tailored for an iOS native health tracking companion for Vietnamese parents caring for infants and toddlers. 

### Brand Personality & Emotional Promise
Caring for a newborn or sick child is fraught with cognitive fatigue, sleep deprivation, and acute anxiety. The interface acts as a serene, reliable, and deeply empathetic partner:
- **Warm & Protective (Ấm áp, Che chở):** Reassuring without being infantilizing. Soft organic surfaces replace clinical coldness.
- **Utilitarian Calm (Điềm tĩnh, Rõ ràng):** Zero visual clutter. Forms prioritize primary inputs first, reducing mental overhead when logging a 3 AM bottle or a spiking fever.
- **Authoritative & Trustworthy (Đáng tin cậy):** Strict adherence to Apple Human Interface Guidelines (HIG) and WCAG AA contrast ensures information hierarchy is unmistakable and dependable.

### Design Movement & Direction
The aesthetic fuses **Modern iOS Native Utility** with **Tactile Soft Ergonomics**:
- **Continuous Curvature:** Surfaces utilize Apple's continuous curve (`.continuous`) to convey gentleness and natural rhythm.
- **Thumb-Zone Engineering:** Prioritizes single-handed interactions—56pt bottom CTAs, responsive sheet dismissals, and comfortable 48pt minimum tap boundaries.
- **Categorical Clarity:** Rather than decorative color flourishes, color strictly carries semantic domain meaning across three vital activity pillars: Medical & Symptoms, Nutrition & Feeding, and Sleep & Daily Routine.

## Colors

The color architecture is built around functional tranquility and unmistakable categorization.

### Surface and Typography
- **App Canvas (`surface-bg` / `#F7F9F8`):** An organic, lightly tinted off-white that prevents screen glare during low-light nighttime feedings.
- **Card Surface (`surface-card` / `#FFFFFF`):** Crisp pure white, elevated over the background to define grouped list cards and modal sheets.
- **Primary Typography (`text-primary` / `#172D32`):** Deep charcoal with a slate-teal undertone, guaranteeing high-contrast legibility (> 11:1 against white).
- **Secondary Typography (`text-secondary` / `#52666B`):** Muted slate-teal for secondary units, timestamps, and captions, passing WCAG AA (> 4.5:1).

### Semantic Health Activity Domains
Every event logged by parents routes into one of three distinct pillars. Each pillar couples an accessible foreground text/icon color with a soothing, desaturated tint background:
1. **Medical & Symptoms (Y tế & Triệu chứng):**
   - Accent / Icon: `#B63B48`
   - Background Surface: `#FBECEE`
   - Used for: Fevers, medications, vaccinations, doctor appointments, and urgent symptom alerts.
2. **Nutrition & Feeding (Ăn uống):**
   - Accent / Icon: `#176B91`
   - Background Surface: `#E8F3FA`
   - Used for: Breastfeeding, formula intake, water, solid meals, and pumping logs.
3. **Sleep & Routine (Ngủ & Sinh hoạt):**
   - Accent / Icon: `#805B16`
   - Background Surface: `#FFF3D7`
   - Used for: Sleep timers, diaper changes, bath time, tummy time, and mood logs.

### Action & Feedback Token
- **Primary Action (`action-primary` / `#146C60`):** Grounded emerald teal used exclusively for primary CTAs ("Lưu nhật ký", "Bắt đầu tính giờ") and primary toggles, signaling progress and safety.

## Typography

The typography strategy employs **Be Vietnam Pro**, engineered specifically for Vietnamese typography, rendering complex diacritical marks (dấu hỏi, ngã, nặng, sắc, huyền) with optical balance and zero vertical clipping.

### Dynamic Type & Ergonomic Hierarchy
- **Native iOS Dynamic Type Support:** All text elements map to native iOS text styles (`.largeTitle`, `.title`, `.headline`, `.body`, `.caption`). When users increase font scaling in iOS Accessibility settings, components gracefully wrap or switch from horizontal stacks to vertical stacks.
- **Large Title Navigation:** Follows Apple's collapsible Large Title pattern. At full scroll offset, headers render at `headline-large-title-mobile` (28pt/34pt) and compress to `headline-title-3` (18pt) inline with navigation bars upon upward drag.
- **Numerical Prominence:** Quantitative measurements (e.g., "38.5°C", "120 ml", "2h 45m") utilize `Be Vietnam Pro` semi-bold weights paired with secondary captions (`13px` / `label-footnote`) to guarantee swift scanning without confusion.

## Layout & Spacing

### Mobile-First Layout Model
The layout adheres strictly to iPhone geometry (baseline 390x844 pt) while testing gracefully down to 360pt and up to Pro Max devices (430pt).

- **Screen Margins:** Fixed 20pt horizontal inset (`margin-screen`) across all scrollable feeds, grouped list views, and bottom sheets.
- **Grouping Architecture:** Employs the iOS Grouped List layout idiom (`InsetGroupedListStyle`), separating chronological logs into distinct white floating cards spaced 12pt to 16pt apart.
- **Safe Area Management:** 
  - Dynamic Island / Notch safe area respected at the top.
  - Home Indicator safe area at the bottom reserved for the floating dock CTA and native Tab Bar.

### Single-Handed Thumb Ergonomics
- **48pt Minimum Hit Target (`touch-target-min`):** Any clickable icon, filter chip, or stepper possesses a bounding interaction box of at least 48x48pt, regardless of visual glyph size.
- **56pt Bottom Primary CTA (`cta-height`):** Fixed or floating action triggers anchor directly into the natural lower thumb arc, elevated with safe area clearance.

## Elevation & Depth

Visual depth is achieved through gentle tonal layers and Apple-grade ambient shadows rather than stark structural drop shadows.

### Layer Hierarchy
1. **Level 0 (Canvas Base):** Grounded background `#F7F9F8`.
2. **Level 1 (Grouped Cards & Modules):** Pure white `#FFFFFF` cards resting on `#F7F9F8` with an ultra-soft ambient shadow:
   - *Shadow:* `Y: 2pt, Blur: 8pt, Color: #172D32, Opacity: 4%`.
3. **Level 2 (Floating Action Zone & Sticky Elements):** Bottom pinned action bars and active ongoing timers ("Đang ngủ"):
   - *Shadow:* `Y: 4pt, Blur: 16pt, Color: #172D32, Opacity: 8%`.
4. **Level 3 (Toasts & Notifications):** Transient toast pills floating above the bottom tab bar:
   - *Shadow:* `Y: 6pt, Blur: 20pt, Color: #172D32, Opacity: 10%`.
5. **Level 4 (Modal Sheets & Action Dialogs):** Native Presentation Detents (`.sheet(isPresented:)`) dimmed by a 30% black backdrop tint (`#000000` with 0.3 opacity).

### Tactile Feedback
Interactive surfaces (cards, buttons, chips) provide micro-haptic feedback via `UIImpactFeedbackGenerator(style: .light)` upon toggle, tap, and sheet snaps.

## Shapes

The design system employs continuous rounded geometry (iOS squircle geometry) to project warmth, softness, and safety.

### Geometric Rules
- **Cards & Sheets (`16px` / `0.5rem` to `1rem`):** Primary event cards, grouped list containers, and bottom sheet containers utilize a continuous corner radius of 16pt (`.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))`).
- **Form Controls & Inputs (`12px`):** Text fields, numeric pickers, and stepper containers feature 12pt corner radii.
- **Pill-Shaped Elements (`999px` / Full Pill):** Category filter chips, status badges, active audio recording capsules, and floating toasts use fully rounded pill ends.
- **Icon Visual Harmony:** All SF Symbols and custom iconography must use the `.rounded` design variant (`Image(systemName: "...").fontDesign(.rounded)`) to align with card curvature.

## Components

### 1. Primary Bottom Action Button (Floating CTA)
- **Geometry:** Height 56pt, full-width minus 40pt horizontal margins (or pinned flush inside bottom bar), corner radius 16pt continuous or 28pt pill.
- **Color:** `#146C60` background with `#FFFFFF` semi-bold text (`cta-button-text`). Pressed state transitions to `#0E4E45`.
- **Haptic:** Medium impact feedback on trigger.

### 2. Category Activity Chips (Pill Filter)
- **Geometry:** Height 36pt, minimum touch box 48x48pt, horizontal padding 14pt, fully rounded pill.
- **States:**
  - *Inactive:* Transparent background, hairline border (`#E3E8E7`), text `#52666B`.
  - *Active (Medical):* `#FBECEE` background, `#B63B48` text & icon, checkmark glyph visible.
  - *Active (Nutrition):* `#E8F3FA` background, `#176B91` text & icon, checkmark glyph visible.
  - *Active (Routine):* `#FFF3D7` background, `#805B16` text & icon, checkmark glyph visible.

### 3. Bottom Tab Bar (3 Primary Tabs)
- **Structure:** 
  1. **Ghi nhanh (Quick Log):** Center quick-entry action or leftmost tab with plus icon.
  2. **Nhật ký (Daily Timeline):** Central chronological feed of all logged events.
  3. **Thống kê (Insights & Growth):** Visual reports, percentiles, and doctor-ready summaries.
- **Aesthetic:** Native translucent material (`.ultraThinMaterial`) background with 0.5pt top hairline `#E3E8E7`.
- **States:** Selected tab uses `#146C60`; unselected tabs use `#52666B`.

### 4. Baby Profile Header & Switcher Sheet
- **Header:** Circular baby avatar (36x36pt) paired with baby name, current age in months/days ("Bé Bơ - 4 tháng 12 ngày"), and a chevron down symbol.
- **Interaction:** Tapping triggers a native half-height sheet presenting sibling profiles and an "Thêm bé mới" action row.

### 5. Status Banners (Persistent Ongoing Trackers)
- **Active Sleep Tracker Banner ("Đang ngủ"):**
  - Surface: `#FFF3D7` with `#805B16` border.
  - Content: Live digital counter ("Đang ngủ: 1g 24p"), moon SF Symbol, and an inline "Thức dậy" button.
- **Symptom / Fever Alert Banner:**
  - Surface: `#FBECEE` with `#B63B48` left indicator bar (4pt width).
  - Content: "Cần theo dõi nhiệt độ - Lần đo cuối: 38.5°C lúc 02:15".

### 6. Toast Notification with Quick Undo
- **Geometry:** Height 48pt, pill-shaped, floating 16pt above the bottom tab bar.
- **Colors:** Deep `#172D32` surface with `#FFFFFF` typography.
- **Undo Action:** Explicit button labeled "Hoàn tác" colored in light emerald `#5EEAD4`.
- **Duration:** 4 seconds for simple confirms; 8 seconds when destructive or undoable actions are performed. Scales up automatically when iOS VoiceOver is active.

### 7. Form Inputs & Steppers
- **Fields:** Minimum height 48pt, `#FFFFFF` surface with 1pt `#E3E8E7` border. Active focus highlights with a 1.5pt `#146C60` stroke.
- **Segmented Controls:** Grouped pill selector with a smooth white sliding thumb over a `#F7F9F8` background.