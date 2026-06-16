// Simple sine-based noise to simulate water surface waves
float waterNoise(vec2 p, float time) {
    float waves = sin(p.x * 4.0 + time * 1.5) * cos(p.y * 4.0 + time * 1.5);
    waves += sin(p.x * 8.0 - time * 2.0) * 0.5; // Layer a smaller wave
    return waves * 0.5 + 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    float safeTime = mod(iTime, 62.8318);

    // 1. Calculate wave values at the current pixel position
    float waveHeight = waterNoise(uv * 2.0, safeTime);

    // 2. Calculate the slope (Normal) by checking nearby pixels
    // This tells us which way the wave face is tilted
    float delta = 0.01;
    float waveLeft  = waterNoise(vec2(uv.x - delta, uv.y) * 2.0, safeTime);
    float waveUp    = waterNoise(vec2(uv.x, uv.y + delta) * 2.0, safeTime);
    vec2 distortion = vec2(waveLeft - waveHeight, waveUp - waveHeight) * 0.15;

    // 3. Refraction: Distort the background coordinates using the wave slope
    vec2 backgroundUV = uv + distortion;
    
    // Create a background grid pattern to see the refraction clearly
    vec2 grid = fract(backgroundUV * 6.0) - 0.5;
    float gridMask = smoothstep(0.0, 0.05, abs(grid.x) * abs(grid.y));
    vec3 backgroundColor = mix(vec3(0.0, 0.1, 0.3), vec3(0.1, 0.4, 0.6), gridMask);

    // 4. Specular Highlight: Add bright glints where the wave tilts toward the screen center
    float specular = pow(max(0.0, 1.0 - length(distortion * 8.0)), 16.0);
    vec3 waterColor = backgroundColor + vec3(specular * 0.6);

    fragColor = vec4(waterColor, 1.0);
}