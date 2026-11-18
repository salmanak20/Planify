# Design System Document: The Mindful Architect

## 1. Overview & Creative North Star: The Mindful Architect
This design system moves beyond the utility of a standard productivity tool to create a "Digital Sanctuary." Our Creative North Star, **The Mindful Architect**, treats the screen not as a flat surface, but as an intentional, multi-dimensional space for deep work. 

While we adhere to the functional logic of Material Design 3, we elevate the aesthetic through an **Editorial High-Contrast** approach. We break the "template" feel by utilizing dramatic typography scales, intentional asymmetry in layout, and a "No-Line" philosophy that relies on tonal depth rather than structural borders. The goal is a workspace that feels expensive, calm, and hyper-focused.

---

## 2. Colors & Tonal Depth
Our palette is rooted in a sophisticated neutral base, using subtle shifts in luminance to define hierarchy.

### The Palette (M3 Tokens)
*   **Surface Foundation:** `surface` (#f8f9fa), `surface_container_low` (#f1f4f5), `surface_container_highest` (#dee3e6).
*   **Primary (Tasks):** `primary` (#435f92) / `primary_container` (#a5c1fb).
*   **Secondary (Notes):** `secondary` (#57634c) / `secondary_container` (#dae7ca).
*   **Tertiary (Calendar):** `tertiary` (#7c5831) / `tertiary_container` (#fdcb9c).

### The "No-Line" Rule
**Explicit Instruction:** Prohibit the use of 1px solid borders to section off content. Boundaries must be defined solely through background color shifts. 
*   *Example:* A high-priority task card (`surface_container_lowest` / #ffffff) should sit on a page background of `surface_container_low` (#f1f4f5). The contrast in tone provides the "edge," not a line.

### Surface Hierarchy & Nesting
Treat the UI as stacked sheets of fine paper. 
*   **Level 0 (Background):** `surface`
*   **Level 1 (Sections):** `surface_container_low`
*   **Level 2 (Active Elements/Cards):** `surface_container_lowest` (White)
*   **Level 3 (Overlays):** Semi-transparent `surface` with a 20px Backdrop Blur (Glassmorphism).

### The "Glass & Gradient" Rule
To inject "soul" into the UI, main CTAs and Hero sections should utilize a subtle linear gradient transitioning from `primary` (#435f92) to `primary_dim` (#365385) at a 135-degree angle. Floating navigation elements should use Glassmorphism—applying an 80% opacity to the surface color to allow underlying content to bleed through softly.

---

## 3. Typography: Editorial Authority
We pair the structural precision of **Inter** with the character-rich **Manrope** to create an editorial feel.

*   **Display & Headlines (Manrope):** These are our "Statement" layers. Use `display-lg` (3.5rem) for empty states or daily welcomes to create a sense of breath and premium quality.
*   **Titles & Body (Inter):** Inter handles the "Work." Its high x-height ensures legibility in dense task lists.
*   **Hierarchy Strategy:** Always favor extreme scale contrast. A `display-sm` header paired with a `label-md` sub-header creates more visual interest than two medium-sized fonts.

---

## 4. Elevation & Depth: Tonal Layering
Traditional drop shadows are largely replaced by **Tonal Layering**. We communicate "lift" through color density.

*   **Ambient Shadows:** When an object must float (like a FAB), use an extra-diffused shadow. 
    *   *Specs:* Blur: 24dp, Spread: -4dp, Color: `on_surface` (#2d3335) at **6% opacity**. This mimics natural ambient light.
*   **The "Ghost Border" Fallback:** If a container requires more definition against a complex background, use a "Ghost Border": `outline_variant` (#adb3b5) at **15% opacity**. Never use a 100% opaque border.
*   **Intentional Asymmetry:** Break the grid. Align your headlines to a wide left margin (24dp) while keeping your cards at a 16dp margin. This creates a sophisticated, "magazine-style" layout that feels custom-built.

---

## 5. Components

### Floating Action Button (FAB)
*   **Shape:** `xl` (1.5rem) or `full` roundedness.
*   **Color:** `primary_container` with `on_primary_container` icons.
*   **Style:** No shadow when idle; 8% ambient shadow on press.

### Cards & Productivity Lists
*   **Constraint:** Zero dividers.
*   **Separation:** Use a 12dp vertical spacing scale. Separate different categories (Tasks vs. Notes) by changing the card background from `surface_container_lowest` to a very faint tint of the category color (e.g., `primary_container` at 10% opacity).
*   **Interaction:** On tap, the card should scale down slightly (98%) and shift color to `surface_bright`.

### Inputs & Search
*   **Style:** Filled variant using `surface_container_high`. 
*   **Focus State:** Do not use a heavy border. Indicate focus by shifting the background to `surface_container_lowest` and changing the label color to `primary`.

### Navigation Rail / Bottom Bar
*   **Aesthetic:** Use the "Glassmorphism" rule. 
*   **Active State:** Use a "pill" indicator with `secondary_container` (#dae7ca) rounded at `full`.

### Contextual Chips
*   **Categorization:** Blue (Tasks), Green (Notes), Orange (Calendar). 
*   **Visuals:** Use the `_container` tokens for the background and `on__container` for the text to ensure AA accessibility while maintaining a soft, pastel-like aesthetic.

---

## 6. Do’s and Don’ts

### Do:
*   **Do** use white space as a functional tool. If a screen feels cluttered, increase the margin, don't add a border.
*   **Do** use `manrope` for any text that isn't data-entry (Headings, Empty States, Brand moments).
*   **Do** utilize "Surface Tint" (#435f92) at very low opacities (3-5%) over your neutrals to give the app a cohesive temperature.

### Don't:
*   **Don't** use pure black (#000000) for text. Always use `on_surface` (#2d3335) to maintain a soft, premium look.
*   **Don't** use standard M3 "Elevated Cards" with heavy shadows. Stick to tonal shifts.
*   **Don't** cram icons. If an icon doesn't add immediate functional value, remove it to reduce cognitive load. 
*   **Don't** use 1px dividers. If you feel you need one, use a 4dp or 8dp gap instead.