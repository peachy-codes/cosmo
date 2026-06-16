// Voronoi / Cellular noise to simulate sharp caustic web networks
vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

float caustics(vec2 p, float time) {
    vec2 n = floor(p);
    vec2 f = fract(p);
    float minDist = 1.0;
    
    // Check neighboring cells to find the closest Voronoi cell center
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            // Animate the cell centers over time using overlapping sine waves
            vec2 o = hash22(n + g);
            o = 0.5 + 0.4 * sin(time + o * 6.2831);
            
            vec2 r = g + o - f;
            float d = dot(r, r); // Squared distance
            minDist = min(minDist, d);
        }
    }
    // Invert and sharpen the distance metric to create the classic "web" look
    return pow(max(0.0, 1.0 - sqrt(minDist)), 4.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Correct aspect ratio and center coordinates
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    float safeTime = mod(iTime, 62.8318);

    // 1. Create multi-layered surface wave vectors
    vec2 waveUV = uv * 2.5;
    waveUV.x += safeTime * 0.1;
    waveUV.y += sin(waveUV.x + safeTime * 0.4) * 0.2;

    // 2. Compute sharp caustics by layering two speeds for parallax depth
    float c1 = caustics(waveUV * 2.0, safeTime * 1.5);
    float c2 = caustics(waveUV * 3.5 - vec2(safeTime * 0.05), safeTime * 2.1);
    float finalCaustic = max(c1 * 0.6, c2 * 0.4);

    // 3. Chromatic Refraction: Offset the Red, Green, and Blue channels slightly
    // This creates the organic color splitting seen along underwater light boundaries
    vec2 refractOffset = vec2(finalCaustic) * 0.03;
    
    float rChannel = caustics(waveUV * 2.0 + refractOffset, safeTime * 1.5);
    float gChannel = finalCaustic;
    float bChannel = caustics(waveUV * 2.0 - refractOffset, safeTime * 1.5);
    vec3 causticColor = vec3(rChannel, gChannel, bChannel) * 1.3;

    // 4. Volumetric Depth Gradient (Deep ocean absorption)
    // Water absorbs red light quickly, leaving a deep blue/cyan base
    float depth = uv.y * 0.5 + 0.5; // Top-to-bottom linear gradient
    vec3 deepWater = vec3(0.0, 0.05, 0.15);
    vec3 shallowWater = vec3(0.05, 0.35, 0.5);
    vec3 baseGradient = mix(deepWater, shallowWater, depth);

    // 5. Fresnel Effect Reflection 
    // Emulates a bright light source reflecting off the surface at sharp viewing angles
    float fresnel = pow(1.0 - max(0.0, dot(vec3(0.0, 0.0, 1.0), vec3(uv, 1.0))), 3.0);
    vec3 reflectionColor = vec3(0.4, 0.7, 0.9) * fresnel * (0.5 + 0.5 * sin(safeTime));

    // Combine features: base water + refracted caustics + surface reflection
    vec3 finalImage = baseGradient + (causticColor * vec3(0.3, 0.8, 0.9)) + reflectionColor;

    // Subtle vignette to focus the installation asset
    finalImage *= 1.0 - length(uv * 0.3);

    fragColor = vec4(finalImage, 1.0);
}