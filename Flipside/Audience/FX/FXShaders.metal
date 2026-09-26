#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Flipside's own effect shaders, written for SwiftUI's layerEffect.

static float fx_hash(float2 p) {
  p = fract(p * float2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

static float fx_noise(float2 p) {
  float2 i = floor(p);
  float2 f = fract(p);
  float a = fx_hash(i);
  float b = fx_hash(i + float2(1, 0));
  float c = fx_hash(i + float2(0, 1));
  float d = fx_hash(i + float2(1, 1));
  float2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fx_fbm(float2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * fx_noise(p);
    p = p * 2.03 + 17.0;
    a *= 0.5;
  }
  return v;
}

// Cosine palette through four brand stops, t in 0...1.
static half3 fx_palette(float t, half3 c0, half3 c1, half3 c2) {
  t = fract(t);
  if (t < 0.333) return mix(c0, c1, half(smoothstep(0.0, 0.333, t)));
  if (t < 0.666) return mix(c1, c2, half(smoothstep(0.333, 0.666, t)));
  return mix(c2, c0, half(smoothstep(0.666, 1.0, t)));
}

/// Pixel-mosaic loader that resolves into the layer underneath.
/// mode 0 = organic (noise-shaped reveal), 1 = mechanic (cell by cell), 2 = sweep (left to right).
/// progress 0 is pure churn, 1 is the crisp image.
[[ stitchable ]] half4 fxPixelReveal(
  float2 position,
  SwiftUI::Layer layer,
  float2 size,
  float time,
  float progress,
  float mode,
  half4 colorA,
  half4 colorB,
  half4 colorC
) {
  float settle = smoothstep(0.55, 1.0, progress);
  float cell = mix(26.0, 2.0, settle);
  float2 cellId = floor(position / cell);
  float2 cellCenter = (cellId + 0.5) * cell;
  float2 uv = cellCenter / max(size, float2(1.0));

  float jitter = fx_hash(cellId + 3.1);
  float field;
  if (mode < 0.5) {
    field = fx_fbm(uv * 2.6 + float2(0.0, time * 0.04)) * 0.85 + jitter * 0.15;
  } else if (mode < 1.5) {
    field = jitter;
  } else {
    field = uv.x * 0.85 + jitter * 0.15;
  }
  float front = progress * 1.2 - 0.1;
  float revealed = step(field, front);

  // Churning mosaic: slow noise flow plus a per-cell flicker every ~150 ms.
  float n = fx_fbm(uv * 3.2 + float2(time * 0.22, -time * 0.17));
  float flicker = fx_hash(cellId + floor(time * 7.0));
  half3 churn = fx_palette(n * 1.4 + time * 0.04, colorA.rgb, colorB.rgb, colorC.rgb);
  churn *= half(0.45 + 0.55 * flicker);

  // Round the cells slightly so the mosaic reads as tiles.
  float2 local = (position - cellId * cell) / cell - 0.5;
  float tile = 1.0 - smoothstep(0.38, 0.5, max(abs(local.x), abs(local.y)));

  half4 pixelated = layer.sample(clamp(cellCenter, float2(0.5), size - 0.5));
  half4 mosaic = half4(churn * half(0.35 + 0.65 * tile), 1.0);
  half4 color = mix(mosaic, pixelated, half(revealed));

  // Bright rim where the reveal front passes.
  float rim = 1.0 - smoothstep(0.0, 0.05, abs(field - front));
  color.rgb += half3(rim * 0.35) * half(1.0 - revealed);

  half4 crisp = layer.sample(position);
  return mix(color, crisp, half(smoothstep(0.9, 1.0, progress)));
}
