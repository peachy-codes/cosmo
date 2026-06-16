vec2 hash2d(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

float gradientNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(dot(hash2d(i + vec2(0.0,0.0)), f - vec2(0.0,0.0)), 
                   dot(hash2d(i + vec2(1.0,0.0)), f - vec2(1.0,0.0)), u.x),
               mix(dot(hash2d(i + vec2(0.0,1.0)), f - vec2(0.0,1.0)), 
                   dot(hash2d(i + vec2(1.0,1.0)), f - vec2(1.0,1.0)), u.x), u.y);
}

float getOceanHeight(vec3 p, float time) {
    vec2 pos = p.xz * 0.25;
    float height = 0.0;
    
    float swell = sin(pos.x * 1.5 + pos.y * 1.0 + time * 0.1);
    height += (1.0 - abs(swell)) * 0.04; 
    
    float crossSwell = sin(pos.x * -1.2 + pos.y * 1.8 + time * 1.5);
    height += pow(crossSwell * 0.5 + 0.5, 10.0) * 0.15;
    
    vec2 chopUV = pos * 8.0 + vec2(time * 0.5, -time * 0.3);
    height += gradientNoise(chopUV) * 0.08;
    
    return height;
}

vec3 getOceanNormal(vec3 p, float time) {
    float eps = 0.0001; 
    float h = getOceanHeight(p, time);
    float hx = getOceanHeight(p + vec3(eps, 0.0, 0.0), time) - h;
    float hz = getOceanHeight(p + vec3(0.0, 0.0, eps), time) - h;
    return normalize(vec3(-hx, eps, -hz));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    float safeTime = mod(iTime, 62.8318);

    // Camera & Global Environment Setup
    vec3 cameraPos = vec3(0.0, 2.2, -5.0);
    vec3 rayDir = normalize(vec3(uv.x * 1.2, uv.y - 0.1, 1.5)); 

    vec3 sunDir = normalize(vec3(2.0, 0.15, 10.0)); 
    vec3 sunColor = vec3(1.0, 0.55, 0.25);        
    vec3 skySkyColor = vec3(0.12, 0.18, 0.35);    
    vec3 horizonSkyColor = vec3(0.9, 0.45, 0.2);  

    // 1. Raymarching Loop (Optimized to 180 iterations with geometric scaling)
    float t = 0.01;
    float hitSignal = 0.0; 
    vec3 p = vec3(0.0);

    for (int i = 0; i < 180; i++) {
        p = cameraPos + rayDir * t;
        float currentSurfaceHeight = getOceanHeight(p, safeTime);
        
        // Mathematical hit mask flag (1.0 if inside water, 0.0 if above)
        float check = step(p.y, currentSurfaceHeight);
        hitSignal = max(hitSignal, check);
        
        // Scaling acceleration: scales larger as distances grow to preserve performance
        t += (max(0.005, (p.y - currentSurfaceHeight) * 0.9) + (t * 0.002)) * (1.0 - check);
    }
    
    // Clamp ray length to horizon boundary limits
    t = min(t, 45.0);

    // 2. Compute Sky & Sun Shading (Calculated natively for color mixing)
    float skyPitch = max(0.0, rayDir.y + 0.1);
    vec3 backgroundSky = mix(horizonSkyColor, skySkyColor, smoothstep(0.0, 0.4, skyPitch));
    float sunCone = max(0.0, dot(rayDir, sunDir));
    vec3 solarCore = sunColor * pow(sunCone, 2000.0) * 5.0; 
    vec3 solarGlow = horizonSkyColor * pow(sunCone, 32.0) * 0.5; 
    vec3 fullSkyColor = backgroundSky + solarCore + solarGlow;

    // 3. Compute Ocean Shading
    vec3 normal = getOceanNormal(p, safeTime);
    vec3 viewDir = -rayDir;

    // Micro-Glitter Normal Disruption
    float microChop = gradientNoise(p.xz * 60.0 + safeTime * 4.0);
    vec3 glitterNormal = normalize(normal + vec3(microChop * 0.04, 0.0, microChop * 0.04));

    // Base Water Absorption
    float facing = max(0.0, dot(normal, viewDir));
    vec3 baseColor = mix(vec3(0.01, 0.12, 0.18), vec3(0.002, 0.02, 0.06), facing);

    // Subsurface Scattering
    float waveForwardScattering = max(0.0, dot(sunDir, -viewDir));
    float internalGlowMask = pow(1.0 - facing, 4.0) * pow(waveForwardScattering, 8.0);
    vec3 subsurfaceGlow = vec3(0.0, 0.6, 0.5) * internalGlowMask * 0.09;

    // High-Frequency Specular Glitter Path
    vec3 halfVector = normalize(sunDir + viewDir);
    float specGlint = pow(max(0.0, dot(glitterNormal, halfVector)), 600.0); 
    vec3 sunReflection = sunColor * specGlint * 12.0; 

    // Fresnel Reflection
    float fresnel = pow(1.0 - facing, 5.0);
    vec3 skyReflection = mix(horizonSkyColor, skySkyColor, normal.y) * fresnel * 0.6;

    // Combine Ocean Elements & Apply Horizon Haze
    vec3 fullOceanColor = baseColor + subsurfaceGlow + sunReflection + skyReflection;
    float horizonHaze = pow(1.0 - max(0.0, dot(normal, vec3(0.0, 1.0, 0.0))), 8.0);
    fullOceanColor = mix(fullOceanColor, horizonSkyColor, horizonHaze * 0.5);
    
    // Atmospheric Fog Decay over distance
    float horizonFog = 1.0 - exp(-t * 0.05);
    fullOceanColor = mix(fullOceanColor, horizonSkyColor, horizonFog);

    // 4. Zero-Branch Mix: Selects final color using our loop signal instead of if/else
    vec3 finalColor = mix(fullSkyColor, fullOceanColor, hitSignal);

    // Post-processing
    finalColor = pow(finalColor, vec3(1.1)); 
    finalColor *= 1.0 - length(uv * 0.25);

    fragColor = vec4(finalColor, 1.0);
}