# Valora landing page motion

## Visual target

Use the approved landing page revision `exec-07ef68be-9a55-4868-80c4-4e290a600087.png`: warm kitchen hero, three app phones, balanced vegetarian/chicken/fish/egg imagery, cream editorial section, and a distinct sage food backdrop for the last download section. Preserve its copy and composition.

This document defines motion; it does not indicate that a runnable landing page or animations have been implemented.

## Reference and interpretation

Reference: https://dribbble.com/shots/21331912-Mobile-App-Landing-Page

The 22-second reference video was inspected in the browser at multiple playback positions. It moves between a phone-led dark hero, a light feature section, and a dark download section with three phones. The presentation also changes framing and apparent scale. Some of that movement may be video presentation rather than behavior implemented on the original website. We should reproduce the sense of continuity through native page scrolling, rather than assume the video demonstrates scroll-driven code.

The timing values below are Valora design decisions, not measurements of the reference.

## Motion principles

- Let text establish context before product imagery arrives.
- Use a short, coordinated sequence per section instead of animating every element independently.
- Preserve normal wheel, touch, keyboard, and anchor scrolling. No forced scrolling or timed page changes.
- Keep download controls stationary and immediately usable during transitions.
- Animate opacity and transforms. Reserve image dimensions before loading so the page does not jump.
- The kitchen and sage photographs remain different. Motion does not replace either with a third visual direction.

## Entrance sequence

| Element | Start after content is ready | Duration | Movement |
| --- | --- | --- | --- |
| Navigation | 0 ms | 350 ms | Opacity only |
| “Eat well.” | 80 ms | 650 ms | Reveal upward through a line mask, 24 px travel |
| “Think less.” | 180 ms | 650 ms | Same treatment |
| Supporting sentence | 300 ms | 450 ms | Fade and move up 12 px |
| Download controls | 380 ms | 350 ms | Opacity only; interactive from first render |
| Centre phone | 400 ms | 900 ms | Rise 48 px, scale 0.96 to 1 |
| Left and right phones | 520 ms | 950 ms | Rise 56 px and settle into their final fan angles |

Use an ease-out curve such as cubic-bezier(0.22, 1, 0.36, 1). Avoid spring overshoot: food and phone imagery should feel settled. The whole entrance finishes in roughly 1.5 seconds. Do not delay it behind a full-page loading screen. If an image is late, reveal it independently when available.

Phones must be separate image layers to support independent movement. A flattened full-page mockup cannot provide these transitions and must not be presented as the implemented page.

## Hero to editorial section

On desktop, as the hero leaves the viewport, move the phone group upward by at most 24 px relative to its resting position. Leave the kitchen image steady. The cream editorial section enters with normal document flow; its heading reveals once with a 24 px rise over 650 ms.

Do not pin the page or stretch a short transition across several screens of scrolling. The reference's presentation-style movement is translated into a modest sense of depth, not a literal camera zoom.

## Editorial section

- Reveal the meal photograph and adjacent copy as one group over 650 ms.
- Reveal the pantry photograph and its copy 120 ms after the first group when both enter together. When they enter separately, reveal each on its own viewport intersection.
- Within each image's fixed crop, allow a restrained scale from 1.035 to 1 over 900 ms. Do not move the containing layout.
- Keep food images visually balanced across diets throughout the sequence.
- Links receive a 2 px arrow translation on hover or keyboard focus, over 160 ms. Keep a visible focus outline.

Trigger reveals when approximately 15% of a group is visible. Reveal each group once per page visit; scrolling back should not hide content again.

## Final download section

The sage backdrop enters naturally with the page. Reveal the heading with an 18 px rise over 600 ms. Fade in the buttons 100 ms later over 300 ms. The background photograph may settle from scale 1.025 to 1 over 1,000 ms inside its reserved bounds.

The footer stays still. Download buttons do not pulse, bounce, float, or move away from a pointer. Google Play remains clearly marked “Coming soon” until a real listing exists. APK download identifies the available build as an Android preview.

## Controls

Hover: primary button lifts by 2 px over 160 ms. Press: return to resting position and scale to 0.98 for 100 ms. Focus: visible forest outline with an offset. No motion is required to communicate availability or activation.

Navigation anchors use native smooth scrolling when motion is enabled and instant scrolling otherwise. Apply scroll margins so headings remain visible below the navigation.

## Mobile and accessibility

At narrow widths, preserve the headline, download controls, and product preview hierarchy. Reduce phone entrance travel to 20 px and duration to 550 ms; keep the fan compact enough that no horizontal page scrolling is introduced. Remove scroll-linked parallax and hover-only behavior on touch devices. Keep normal vertical page scrolling.

For `prefers-reduced-motion: reduce`, display all content in its final position immediately, disable line-mask motion, scale, parallax, stagger delays, and smooth anchor scrolling. Never make content dependent on animation completion. The page must also remain readable when JavaScript is unavailable.

## Implementation boundaries and review

Implement the landing page separately from the existing mobile prototype and Flutter application. Reuse the approved palette and bundled fonts. Use independently generated or supplied photographs and phone layers, semantic HTML for all text and controls, CSS for entrances, and IntersectionObserver for one-time section reveals. Use requestAnimationFrame only for the limited desktop scroll effect, schedule work only while the hero is visible, and cancel it when reduced motion is enabled.

Before claiming completion, inspect the page at desktop and narrow mobile widths, inspect normal and reduced-motion states, and independently review that controls work before and after transitions, scrolling stays native, content stays readable without animation, and imagery does not cause layout shifts. Runtime validation has not yet been performed because the landing page has not been built.
