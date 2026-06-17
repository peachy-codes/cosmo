// Utility function for 2D rotations
mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    // Normalize pixel coordinates (from -0.5 to 0.5)
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Camera setup
    vec3 ro = vec3(0.0, 0.0, -2.5); // Ray origin
    vec3 rd = normalize(vec3(uv, 1.0)); // Ray direction

    vec3 col = vec3(0.0);
    float t = 0.0; // Total distance traveled

    // Raymarching loop optimized for volumetric glow rather than hard surfaces
    for(int i = 0; i < 80; i++) {
        vec3 p = ro + rd * t;

        // Twist space based on depth and time
        p.xy *= rot(t * 0.2 + iTime * 0.5);
        p.xz *= rot(iTime * 0.3);

        // KIFS Fractal folding
        // Space is repeatedly mirrored and rotated to create infinite complexity
        for(int j = 0; j < 5; j++) {
            p = abs(p) - 0.4;
            p.xy *= rot(0.5);
            p.xz *= rot(0.7);
        }

        // Distance to the core fractal structure
        float d = length(p) - 0.05; 

        // Dynamic color palette based on time and screen coordinates
        vec3 glowColor = 0.5 + 0.5 * cos(iTime + uv.xyx + vec3(0.0, 2.0, 4.0));

        // Volumetric accumulation
        // Instead of stopping when hitting a surface, we add color based on proximity
        col += glowColor * 0.003 / (0.001 + d * d) * exp(-t * 0.5);

        // Step forward conservatively to ensure we catch the glow
        t += d * 0.7; 
    }

    // ACES-style Tone mapping to prevent color blowout
    col = 1.0 - exp(-col);

    // Output to screen
    fragColor = vec4(col, 1.0);
}