// Polynomial smooth minimum function for organic blending
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    float safeTime = mod(iTime, 62.8318);

    // Define positions for two separate moving circles
    vec2 pos1 = vec2(sin(safeTime) * 0.4, 0.0);
    vec2 pos2 = vec2(cos(safeTime * 0.7) * 0.4, sin(safeTime * 0.5) * 0.2);

    // Calculate individual distance fields
    float circle1 = length(uv - pos1) - 0.25;
    float circle2 = length(uv - pos2) - 0.25;

    // Blend the distance fields together smoothly
    float blendedSDF = smin(circle1, circle2, 0.2);

    // Render the final mask
    float mask = 1.0 - smoothstep(-0.01, 0.01, blendedSDF);

    // Color based on the underlying distance field values
    vec3 color = mix(vec3(0.2, 0.8, 0.4), vec3(0.1, 0.2, 0.5), blendedSDF);

    fragColor = vec4(color * mask, 1.0);
}