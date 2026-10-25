# Landing implementation

## Source → implementation

Approved visual: `exec-07ef68be-9a55-4868-80c4-4e290a600087.png`.
Motion source: `../LANDING_MOTION_DESIGN.md`.

- Top kitchen scene → full-width photograph, semantic headline, real download controls, three separately animated phone assets.
- Cream editorial chapter → two-column meal/pantry layout with separate photographs and semantic copy.
- Sage download chapter → separate photograph, heading and download controls; cream footer.
- Phone fan → image layers whose transforms animate without changing document layout.

## Architecture and ownership

Standalone React/Vite project in `landing/`; original web prototype and Flutter sources retain their existing entry points. App component owns reveal observers, hero scroll listener and download dialog. Effects detach listeners and cancel pending animation frames on unmount or reduced-motion changes. Static assets and bundled fonts live in `public/assets/`. No user information is collected.

## Invariants

Preserve approved content, warm hero/green final scene, inclusive food imagery, readable download actions, normal scrolling, and keyboard access. Play Store has no listing: its control opens an honest coming-soon notice. APK links to the existing debug preview build, explicitly labelled as a preview. No live AI or ordering claims.

## Semantic differences

The selected mock is a single raster image; the implementation uses independent images and HTML. Generated phone screen details can differ from Flutter source screens. Hover is supplemental; focus and touch operate independently. Reduced motion presents the final composition immediately. Narrow viewports reflow editorial content and scale the fan without horizontal overflow.

## Validation approach

Review the code independently after implementation. Inspect desktop and narrow browser rendering and the download interaction. Compare rendered composition with the approved source, record evidence in `design-qa.md`, and clearly distinguish executed checks from checks not run. No new automated tests are planned.
