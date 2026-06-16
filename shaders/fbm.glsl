// 1. A standard 2D pseudo-random hash function
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2. 2D Value Noise: Generates smooth interpolation between grid points
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Smoothstep interpolation curve to remove grid artifacts
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    // Mix the 4 corners of the current grid cell
    return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
               mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}

// 3. Fractional Brownian Motion: Layering noise at varying frequencies
float fBm(vec2 uv) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    // Loop 5 times to stack 5 distinct layers of detail
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(uv * frequency);
        frequency *= 2.0;   // Make the pattern smaller/denser
        amplitude *= 0.5;   // Make the pattern less intense
    }
    return value;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    float safeTime = mod(iTime, 62.8318);

    // Scale coordinates and animate them over time to simulate movement
    vec2 motionUV = uv * 3.0;
    motionUV.y -= safeTime * 0.2;
    motionUV.x += sin(safeTime * 0.1) * 0.5;

    // Calculate the final fBm value (returns a normalized 0.0 to 1.0 float)
    float cloudDensity = fBm(motionUV);

    // Define background sky color and foreground cloud color
    vec3 skyColor = vec3(0.1, 0.3, 0.6);
    vec3 cloudColor = vec3(0.9, 0.9, 0.9);

    // Mix the colors based on the fBm calculation
    vec3 finalColor = mix(skyColor, cloudColor, cloudDensity);

    fragColor = vec4(finalColor, 1.0);
}