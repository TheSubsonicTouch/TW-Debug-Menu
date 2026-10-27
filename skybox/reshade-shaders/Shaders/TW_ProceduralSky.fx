// Procedural fractal-space experiment for Triad Wars / ReShade 5+.
// Inspired by the folding/inversion fractal technique in Star Nest by
// Pablo Roman Andrioli (Kali): https://www.shadertoy.com/view/XlfGRj
// Independently arranged experimental implementation; not a native sky hook.
#include "ReShade.fxh"

uniform bool Enabled < ui_label = "Enable sky replacement"; > = false;
uniform bool PreviewMask < ui_label = "Preview sky mask (white = replace)"; > = false;
uniform bool PreviewFullScreen < ui_label = "Preview effect without depth (testing only)"; > = false;
uniform float FarThreshold < ui_type = "slider"; ui_min = 0.9; ui_max = 1.0; ui_step = 0.0001; ui_label = "Linear depth sky threshold"; > = 0.9995;
uniform float MaskFeather < ui_type = "slider"; ui_min = 0.00001; ui_max = 0.005; ui_step = 0.00001; > = 0.0002;
uniform float Blend < ui_type = "slider"; ui_min = 0.0; ui_max = 1.0; > = 1.0;
uniform float Exposure < ui_type = "slider"; ui_min = 0.1; ui_max = 4.0; > = 1.0;
uniform float AnimationSpeed < ui_type = "slider"; ui_min = 0.0; ui_max = 0.1; > = 0.01;
uniform float VerticalFOV < ui_type = "slider"; ui_min = 30.0; ui_max = 110.0; ui_label = "Approximate vertical FOV"; > = 60.0;
uniform float Yaw < ui_type = "slider"; ui_min = -180.0; ui_max = 180.0; > = 0.0;
uniform float Pitch < ui_type = "slider"; ui_min = -89.0; ui_max = 89.0; > = 0.0;
uniform float3 Tint < ui_type = "color"; > = float3(0.45, 0.65, 1.0);
uniform float ClockMS < source = "timer"; >;

float2 RotatePair(float2 v, float angle)
{
    float c = cos(angle), s = sin(angle);
    return float2(c*v.x - s*v.y, s*v.x + c*v.y);
}

float3 SpaceColor(float3 ray)
{
    float t = ClockMS * 0.001 * AnimationSpeed;
    float3 origin = float3(1.2 + t, 0.4, 0.7 + t * 0.3);
    float3 glow = 0.0;
    float transmission = 1.0;
    // Fixed, bounded workload. Cost is still significant at high resolutions.
    [loop] for (int step = 0; step < 14; ++step)
    {
        float distance = 0.15 + step * 0.13;
        float3 p = origin + ray * distance;
        p = abs(frac(p / 1.7) * 1.7 - 0.85);
        float change = 0.0;
        float previous = 0.0;
        [loop] for (int iteration = 0; iteration < 12; ++iteration)
        {
            p = abs(p) / max(dot(p,p), 0.002) - 0.53;
            float radius = length(p);
            change += abs(radius - previous);
            previous = radius;
        }
        float energy = min(change * change * change * 0.0007, 12.0);
        float3 spectrum = lerp(Tint, float3(1.0, 0.45, 0.2), step / 13.0);
        glow += spectrum * energy * transmission * 0.08;
        transmission *= 0.78;
    }
    return saturate(1.0 - exp(-glow * Exposure));
}

float4 PS_Sky(float4 position : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 scene = tex2D(ReShade::BackBuffer, uv);
    if (!Enabled) return scene;
    float depth = ReShade::GetLinearizedDepth(uv);
    float mask = smoothstep(FarThreshold - MaskFeather, FarThreshold, depth);
    if (PreviewFullScreen) mask = 1.0;
    if (PreviewMask) return float4(mask.xxx, 1.0);
    // Avoid the fractal loop on opaque scenery. Invalid/missing depth must be
    // diagnosed with PreviewMask before enabling this on a real game build.
    if (mask <= 0.0) return scene;
    float2 screen = uv * 2.0 - 1.0;
    screen.y = -screen.y;
    screen.x *= BUFFER_WIDTH * 1.0 / BUFFER_HEIGHT;
    float3 ray = normalize(float3(screen * tan(radians(VerticalFOV) * 0.5), 1.0));
    ray.yz = RotatePair(ray.yz, radians(Pitch));
    ray.xz = RotatePair(ray.xz, radians(Yaw));
    return float4(lerp(scene.rgb, SpaceColor(ray), mask * Blend), scene.a);
}

technique TW_ProceduralSky < ui_label = "Triad Wars - experimental procedural sky"; >
{
    pass { VertexShader = PostProcessVS; PixelShader = PS_Sky; }
}
