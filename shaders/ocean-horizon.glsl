// Upgraded hash for complex noise layering
vec2 hash2d(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

// 2D Smooth Gradient Noise
float gradientNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(dot(hash2d(i + vec2(0.0,0.0)), f - vec2(0.0,0.0)), 
                   dot(hash2d(i + vec2(1.0,0.0)), f - vec2(1.0,0.0)), u.x),
               mix(dot(hash2d(i + vec2(0.0,1.0)), f - vec2(0.0,1.0)), 
                   dot(hash2d(i + vec2(1.0,1.0)), f - vec2(1.0,1.0)), u.x), u.y);
}

// Advanced Multi-Layered Wave System: Sharp peaks + micro-chop
float getOceanHeight(vec3 p, float time) {
    vec2 pos = p.xz * 0.25;
    float height = 0.0;
    
    // Wave Layer 1: Heavy, sweeping deep ocean swell
    float swell = sin(pos.x * 1.5 + pos.y * 1.0 + time * .1);
    height += (1.0 - abs(swell)) * 0.04; 
    
    // Wave Layer 2: Intersecting cross-swell creating peak pyramids
    float crossSwell = sin(pos.x * -1.2 + pos.y * 1.8 + time * 1.5);
    height += pow(crossSwell * 0.5 + 0.5, 10.0) * 0.15;
    
    // Wave Layer 3: High-frequency wind chop using gradient noise
    vec2 chopUV = pos * 8.0 + vec2(time * 0.5, -time * 0.3);
    height += gradientNoise(chopUV) * 0.08;
    
    return height;
}

// Calculates accurate 3D surface vectors
vec3 getOceanNormal(vec3 p, float time) {
    // Tight sampling step size yields crisp reflections and prevents blurring
    float eps = 0.0001; 
    float h = getOceanHeight(p, time);
    float hx = getOceanHeight(p + vec3(eps, 0.0, 0.0), time) - h;
    float hz = getOceanHeight(p + vec3(0.0, 0.0, eps), time) - h;
    return normalize(vec3(-hx, eps, -hz));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Center coordinates and establish proper vertical FOV
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    float safeTime = mod(iTime, 62.8318);

    // 1. Cinematic Camera Matrix (Low angle, sweeping wide view)
    vec3 cameraPos = vec3(0.0, 2.2, -5.0);
    // Tilting down just enough to dedicate 60% of screen to ocean, 40% to sky
    vec3 rayDir = normalize(vec3(uv.x * 1.2, uv.y - 0.1, 1.5)); 

    // Global Environment Directions and Palette
    vec3 sunDir = normalize(vec3(2.0, 0.15, 10.0)); // Sun positioned low over the horizon
    vec3 sunColor = vec3(1.0, 0.55, 0.25);        // Deep sunset amber
    vec3 skySkyColor = vec3(0.12, 0.18, 0.35);    // Dark twilight zenith
    vec3 horizonSkyColor = vec3(0.9, 0.45, 0.2);  // Fiery horizon band

    vec3 finalColor = vec3(0.0);
    
    // 2. High-Precision Raymarching Engine
    float t = 0.01;
    bool hit = false;
    vec3 p = vec3(0.0);

    for (int i = 0; i < 1024; i++) {
        p = cameraPos + rayDir * t;
        float currentSurfaceHeight = getOceanHeight(p, safeTime);
        
        // Precise intersection boundary check
        if (p.y <= currentSurfaceHeight) {
            hit = true;
            break;
        }
        
        // Adaptive step length: Steps slow down dramatically near the surface
        // to capture microscopic distant wave tips right at the horizon line
        t += max(0.005, (p.y - currentSurfaceHeight) * 0.9);
        if (t > 45.0) break; 
    }

    // 3. Advanced Lighting and Shading Architecture
    if (hit) {
        vec3 normal = getOceanNormal(p, safeTime);
        vec3 viewDir = -rayDir;

        // Base Water Absorption
        vec3 deepWater = vec3(0.002, 0.02, 0.06);
        vec3 shallowWater = vec3(0.01, 0.12, 0.18);
        float facing = max(0.0, dot(normal, viewDir));
        vec3 baseColor = mix(shallowWater, deepWater, facing);

        // FEATURE 1: Subsurface Volume Scattering (Internal Wave Glow)
        // Light passing through the back of wave crests illuminates them from within
        float waveForwardScattering = max(0.0, dot(sunDir, -viewDir));
        float internalGlowMask = pow(1.0 - facing, 4.0) * pow(waveForwardScattering, 8.0);
        vec3 subsurfaceGlow = vec3(0.0, 0.6, 0.5) * internalGlowMask * .09;

        // FEATURE 2: High-Intensity Specular Light Path
        vec3 halfVector = normalize(sunDir + viewDir);
        float specGlint = pow(max(0.0, dot(normal, halfVector)), 250.0);
        vec3 sunReflection = sunColor * specGlint * 4.0; // Overdriven intensity for camera bloom

        // FEATURE 3: Balanced Fresnel Sky Reflection
        float fresnel = pow(1.0 - facing, 5.0);
        vec3 skyReflection = mix(horizonSkyColor, skySkyColor, normal.y) * fresnel * 0.6;

        // Combine all shading layers
        finalColor = baseColor + subsurfaceGlow + sunReflection + skyReflection;

        // FEATURE 4: Exponential Horizon Fog
        // Thicken the air near the distant background to blend ocean into sky flawlessly
        float horizonFog = 1.0 - exp(-t * 0.05);
        finalColor = mix(finalColor, horizonSkyColor, horizonFog);
        
    } else {
        // 4. Dynamic Sky & Sun Architecture
        float skyPitch = max(0.0, rayDir.y + 0.1);
        vec3 backgroundSky = mix(horizonSkyColor, skySkyColor, smoothstep(0.0, 0.4, skyPitch));
        
        // Solar Disk Rendering
        float sunCone = max(0.0, dot(rayDir, sunDir));
        vec3 solarCore = sunColor * pow(sunCone, 2000.0) * 5.0; // Crisp, sharp solar disk
        vec3 solarGlow = horizonSkyColor * pow(sunCone, 32.0) * 0.5; // Atmospheric halo
        
        finalColor = backgroundSky + solarCore + solarGlow;
    }

    // Post-processing: Subtle contrast curve and vignette
    finalColor = pow(finalColor, vec3(1.1)); 
    finalColor *= 1.0 - length(uv * 0.25);

    fragColor = vec4(finalColor, 1.0);
}