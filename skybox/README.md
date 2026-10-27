# Custom procedural sky for Triad Wars

## What the reference actually uses

The supplied [Sleeping Dogs video](https://www.youtube.com/watch?v=Sw86hELcc2Y)
is titled **SD / Custom Shader Test**. Its description links to
[Star Nest by Pablo Roman Andrioli / Kali](https://www.shadertoy.com/view/XlfGRj),
a volumetric folding/inversion fractal, rather than a static cubemap. The video
metadata identifies the visual source, but does **not** establish how its author
hooks the Sleeping Dogs renderer. This project does not claim to reproduce that hook.

The repository contains only a ZIP with a precompiled `dinput8.dll`, presets,
and server configuration. There is no mod-menu C++ source, game executable,
capture, camera layout, or shader bytecode to implement or validate a native
Triad Wars replacement against. Sleeping Dogs addresses and shader hashes must
not be assumed to work in Triad Wars.

## Included approach: ReShade prototype

`reshade-shaders/Shaders/TW_ProceduralSky.fx` implements a similar fractal-space
look and composites it over pixels with far **linearized** depth. It needs no
textures or game offsets. It is an experimental screen-space replacement, **not
a world-locked skybox**, and is untested in the game. Shader compilation and
visual correctness must be checked on a Windows installation with ReShade.

### Install (offline game only)

1. Back up the game folder and existing ReShade configuration/preset.
2. Install ReShade for `TriadWars.exe` using DirectX 10/11/12, as recommended by
   the packaged menu's install guide. Keep the menu's `dinput8.dll`; do not replace
   it. If `dxgi.dll` already belongs to another injector, resolve that conflict
   before installing rather than overwriting it blindly.
3. Copy this folder's `reshade-shaders` into the game root, merging directories.
   Ensure ReShade's effect search paths include `.\reshade-shaders\Shaders` and
   that the standard `ReShade.fxh` include is installed/searchable.
4. Copy `Shaders/Procedural_Space.ini` into the game's `Shaders` folder. Select
   it with the menu's preset selector (which copies to `ReShadePreset.ini`),
   with ReShade configured to use that active preset; or load the INI directly
   in ReShade. Selecting this preset replaces the active technique list; it does
   not automatically combine existing color grading presets.
5. Reload effects. The effect's `Enabled` control deliberately defaults to OFF.
   Enable the technique and `Enabled`, then switch on **Preview sky mask**.
6. Inspect outdoors: only open sky should be white; buildings and people must
   be black. Use ReShade's depth visualization to choose the correct depth
   buffer first. Set reversed/logarithmic/upside-down depth definitions to
   match the actual game buffer, not guesses. The mask uses normalized linear
   depth after those corrections. Adjust the threshold and feather carefully.
7. Turn mask preview off once verified. Tune exposure, tint and animation speed.
   `Preview effect without depth` is only a full-screen diagnostic: keep it OFF
   during gameplay. Save the preset in ReShade when satisfied.

### Known limitations / stop conditions

- No depth or a wrong depth buffer can replace the entire frame. If mask preview
  is all white/all black, stop and fix depth selection; threshold tuning is not
  a substitute. The shader cannot reliably detect missing depth automatically.
- A sky pass that writes non-far depth may not be separable by this method.
  Far geometry may also pass the mask. No universal threshold exists.
- Transparent glass, particles, fog, rain, and HUD pixels may lack their own
  depth. This late composite can paint over them. It does not relight buildings,
  change reflections, or integrate with engine atmosphere/exposure.
- ReShade alone does not supply Triad Wars' camera orientation. Yaw, pitch and
  FOV are manual preview controls. Moving the camera will expose screen-space
  locking; time animation is not camera tracking. For a genuine skybox use the
  native route below, not mouse-delta integration (which drifts).
- The bounded fractal loops still cost GPU time. Compare frame times at your
  resolution. No performance or compatibility claims have been measured.
- Disable the technique or `Enabled` to restore the original image immediately.
  To uninstall, remove only `TW_ProceduralSky.fx` and `Procedural_Space.ini` and
  restore the previous preset. Do not remove a shared ReShade installation.

## Route to a true Triad Wars sky shader

For the reference-style effect that stays behind the city, implement replacement
at the engine's **sky draw**, before transparencies and UI, instead of Present:

1. On the offline DX11 build, capture a clear outdoor frame with RenderDoc (if
   capture works with the existing injectors). Temporarily disable third-party
   overlays if necessary. Identify the sky draw by inspecting render targets,
   depth state and before/after output. Repeat across weather and time of day.
2. Save that draw's shader bytecode, input signature, resource bindings, constant
   buffers, viewport, depth/stencil and blend state. Determine whether sky uses
   a sphere/cube or full-screen triangle and whether it is a separate pass at all.
3. Disassemble/reflection-inspect its vertex shader and constant buffers to find
   the actual camera/view-projection layout and coordinate conventions. Verify
   by rotating the camera with time paused. Do not guess matrix offsets.
4. With the mod-menu source, add a DX11 hook; alternatively build a separate
   versioned ReShade add-on with shader/pipeline replacement support. Identify
   the sky pixel shader by captured bytecode hash **and** draw context. Log and
   fail closed for unknown builds; never replace every shader or guess an RVA.
5. Prefer replacing only the sky pixel shader while retaining the original
   vertex shader, geometry and depth/blend state. Match its interpolator input
   signature and use a verified world-space viewing direction. For a full-screen
   sky pass, reconstruct directions with inverse projection and inverse view
   **rotation only**, so camera translation produces no sky parallax.
6. Feed animation time and settings in a verified unused constant-buffer slot;
   preserve/restore bindings, manage COM lifetimes, device resets, and shader
   permutations. Handle deferred contexts if the renderer uses them. Keep the
   hook disabled when identification or resource setup fails.
7. Render linear radiance in the sky pass's actual HDR/color-space convention;
   let the game apply fog, exposure and tone mapping. The included ReShade
   shader's display-range tone map is for late compositing, not a drop-in HDR
   engine shader. Decide whether to keep clouds as separate layers.
8. Validate occlusion, horizon orientation, camera rotation/FOV changes,
   weather changes, interiors, particles, reflections, HUD, resize and restart.
   Add a hot toggle that restores the original shader.

**Next useful inputs:** a Triad Wars outdoor DX11 frame capture (with build
identifier) and the menu's C++ source, if available. These would turn the native
route from an investigation plan into a build-specific implementation. Do not
share proprietary game executables or credentials.

## Validation checklist

- ReShade compiles the FX with no errors and finds the named technique.
- Disabled effect reproduces the unmodified frame.
- Mask separates skyline from city in multiple locations and weather states.
- Depth-free preview shows the fractal; disable that preview afterward.
- Inspect tree edges, glass, rain, HUD and distant geometry for false replacement.
- Measure GPU/frame-time overhead; confirm preset reload and rollback.

No automated shader compiler or live Triad Wars runtime is bundled here.
