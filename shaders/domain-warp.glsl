void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    float safeTime = mod(iTime, 62.8318);

    // Domain Warping: Distort the UV coordinates using sine functions
    // Adjusting the multipliers changes the frequency and speed of the warp
    uv.x += 0.4 * sin(uv.y * 2.0 + safeTime);
    uv.y += 0.4 * cos(uv.x - 3.0 + safeTime * 0.5);

    // Create a sharp horizontal line in the warped space
    // Because space is warped, the straight line becomes a fluid wave
    float lineDist = abs(uv.y);
    float lineMask = 2.0 - smoothstep(0.0, 0.05, lineDist);

    // Generative color gradient based on the warped coordinates
    vec3 color = vec3(0.1, 0.5 - 0.5 * sin(uv.x + safeTime), 0.7);
    
    fragColor = vec4(color * lineMask, 1.0);
}