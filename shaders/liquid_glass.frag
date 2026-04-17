#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uDistortionScale;
uniform float uBlurAmount;
uniform vec4 uTintColor;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uSize;

    // Generate procedural noise-based displacement
    vec2 center = vec2(0.5);
    vec2 delta = uv - center;
    float dist = length(delta);

    // Radial distortion with sinusoidal warp
    float warpX = sin(uv.y * 12.0 + uv.x * 8.0) * 0.015;
    float warpY = cos(uv.x * 10.0 + uv.y * 6.0) * 0.015;

    vec2 displacement = vec2(warpX, warpY) * uDistortionScale;

    // Chromatic aberration: offset RGB channels slightly differently
    vec2 uvR = uv + displacement * 1.1;
    vec2 uvG = uv + displacement;
    vec2 uvB = uv + displacement * 0.9;

    // Multi-sample blur approximation
    float blur = uBlurAmount / uSize.x;
    vec4 colorR = vec4(0.0);
    vec4 colorG = vec4(0.0);
    vec4 colorB = vec4(0.0);
    float total = 0.0;

    for (float x = -2.0; x <= 2.0; x += 1.0) {
        for (float y = -2.0; y <= 2.0; y += 1.0) {
            vec2 offset = vec2(x, y) * blur;
            float weight = 1.0 - length(vec2(x, y)) * 0.15;
            weight = max(weight, 0.0);

            colorR += texture(uTexture, clamp(uvR + offset, 0.0, 1.0)) * weight;
            colorG += texture(uTexture, clamp(uvG + offset, 0.0, 1.0)) * weight;
            colorB += texture(uTexture, clamp(uvB + offset, 0.0, 1.0)) * weight;
            total += weight;
        }
    }

    colorR /= total;
    colorG /= total;
    colorB /= total;

    vec4 distorted = vec4(colorR.r, colorG.g, colorB.b, 1.0);

    // Edge highlight based on distance from center
    float edgeGlow = smoothstep(0.0, 0.5, dist) * 0.08;

    // Blend with tint
    vec4 tinted = mix(distorted, uTintColor, uTintColor.a);

    // Add subtle edge highlight
    tinted.rgb += edgeGlow;

    fragColor = tinted;
}
