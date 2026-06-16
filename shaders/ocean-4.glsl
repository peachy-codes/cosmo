// ============================================================================
// GLOBAL CONFIGURATION PARAMETERS (User Adjusted)
// ============================================================================

// --- Camera Settings ---
#define CAMERA_HEIGHT       0.3
#define CAMERA_PITCH       -0.1      
#define CAMERA_FOV          1.2      

// --- Environment Colors ---
#define COLOR_SUN           vec3(1.0, 0.55, 0.25)  
#define COLOR_SKY_ZENITH    vec3(0.12, 0.18, 0.35) 
#define COLOR_SKY_HORIZON   vec3(0.9, 0.45, 0.2)   
#define COLOR_WATER_DEEP    vec3(0.002, 0.02, 0.06)
#define COLOR_WATER_SHALLOW vec3(0.01, 0.12, 0.18)
#define COLOR_FOAM          vec3(0.95, 0.85, 0.75) // Tinted whitecap foam color

// --- Sun & Light Positions ---
#define SUN_DIRECTION       normalize(vec3(2.0, 0.15, 10.0)) 

// --- Wave Geometry Profiles ---
#define SWELL_SCALE         0.15     
#define SWELL_SPEED         0.001
#define SWELL_HEIGHT        0.004
#define CHOP_SPEED          0.15
#define CHOP_HEIGHT         0.20
#define CHOP_SHARPNESS      500.0     
#define MICRO_CHOP_SCALE    8.0
#define MICRO_CHOP_HEIGHT   0.08

// --- Shading Modifiers ---
#define SPECULAR_POWER      400.0    
#define SPECULAR_INTENSITY  12.0     
#define GLITTER_FREQUENCY   10.0     
#define GLITTER_SPEED       1.0
#define GLITTER_ROUGHNESS   0.4     
#define SCATTER_INTENSITY   0.19     
#define ATMOSPHERE_FOG      0.1     

// --- Foam Control Modifiers ---
#define FOAM_THRESHOLD      0.15     // Height cutoff where foam begins to generate
#define FOAM_SHARPNESS      1.0      // Blending falloff curve for whitecaps

// ============================================================================
// RENDERING CORE
// ============================================================================

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
    vec2 pos = p.xz * SWELL_SCALE;
    float height = 0.0;
    
    // Layer 1: Swell
    float swell = sin(pos.x * 1.5 + pos.y * 1.0 + time * SWELL_SPEED);
    height += (1.0 - abs(swell)) * SWELL_HEIGHT; 
    
    // Layer 2: Intersecting Chop (Main driver for whitecap peaks)
    float crossSwell = sin(pos.x * -1.2 + pos.y * 1.8 + time * CHOP_SPEED);
    height += pow(crossSwell * 0.5 + 0.5, CHOP_SHARPNESS) * CHOP_HEIGHT;
    
    // Layer 3: Micro Wind Rumbles
    vec2 chopUV = pos * MICRO_CHOP_SCALE + vec2(time * 0.5, -time * 0.3);
    height += gradientNoise(chopUV) * MICRO_CHOP_HEIGHT;
    
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

    // Camera Configuration
    vec3 cameraPos = vec3(0.0, CAMERA_HEIGHT, -5.0);
    vec3 rayDir = normalize(vec3(uv.x * CAMERA_FOV, uv.y + CAMERA_PITCH, 1.5)); 

    // Raymarching Loop
    float t = 0.01;
    float hitSignal = 0.0; 
    vec3 p = vec3(0.0);

    for (int i = 0; i < 180; i++) {
        p = cameraPos + rayDir * t;
        float currentSurfaceHeight = getOceanHeight(p, safeTime);
        float check = step(p.y, currentSurfaceHeight);
        hitSignal = max(hitSignal, check);
        t += (max(0.005, (p.y - currentSurfaceHeight) * 0.9) + (t * 0.002)) * (1.0 - check);
    }
    t = min(t, 45.0);

    // Process Sky
    float skyPitch = max(0.0, rayDir.y - CAMERA_PITCH);
    vec3 backgroundSky = mix(COLOR_SKY_HORIZON, COLOR_SKY_ZENITH, smoothstep(0.0, 0.4, skyPitch));
    float sunCone = max(0.0, dot(rayDir, SUN_DIRECTION));
    vec3 solarCore = COLOR_SUN * pow(sunCone, 2000.0) * 5.0; 
    vec3 solarGlow = COLOR_SKY_HORIZON * pow(sunCone, 32.0) * 0.5; 
    vec3 fullSkyColor = backgroundSky + solarCore + solarGlow;

    // Process Ocean
    vec3 normal = getOceanNormal(p, safeTime);
    vec3 viewDir = -rayDir;

    // Distort surface normals via glitter noise
    float microChop = gradientNoise(p.xz * GLITTER_FREQUENCY + safeTime * GLITTER_SPEED);
    vec3 glitterNormal = normalize(normal + vec3(microChop * GLITTER_ROUGHNESS, 0.0, microChop * GLITTER_ROUGHNESS));

    // Optical Calculations
    float facing = max(0.0, dot(normal, viewDir));
    vec3 baseColor = mix(COLOR_WATER_SHALLOW, COLOR_WATER_DEEP, facing);

    float waveForwardScattering = max(0.0, dot(SUN_DIRECTION, -viewDir));
    float internalGlowMask = pow(1.0 - facing, 4.0) * pow(waveForwardScattering, 8.0);
    vec3 subsurfaceGlow = vec3(0.0, 0.6, 0.5) * internalGlowMask * SCATTER_INTENSITY;

    vec3 halfVector = normalize(SUN_DIRECTION + viewDir);
    float specGlint = pow(max(0.0, dot(glitterNormal, halfVector)), SPECULAR_POWER); 
    vec3 sunReflection = COLOR_SUN * specGlint * SPECULAR_INTENSITY; 

    float fresnel = pow(1.0 - facing, 5.0);
    vec3 skyReflection = mix(COLOR_SKY_HORIZON, COLOR_SKY_ZENITH, normal.y) * fresnel * 0.6;

    // FEATURE ADDITION: Procedural Whitecap Foam Layer
    // 1. Isolate the vertical position relative to the base plain
    float crestMask = clamp((p.y - FOAM_THRESHOLD) / (CHOP_HEIGHT - FOAM_THRESHOLD), 0.0, 1.0);
    crestMask = pow(crestMask, FOAM_SHARPNESS);

    // 2. Break up the foam lines using high-frequency noise so it looks bubbly, not flat
    float foamNoise = gradientNoise(p.xz * 45.0 + safeTime * 1.5) * 0.5 + 0.5;
    float finalWhitecapMask = smoothstep(0.2, 0.5, crestMask * foamNoise);

    // Combine Ocean Elements & Mix Foam based on the mask
    vec3 cleanOceanColor = baseColor + subsurfaceGlow + sunReflection + skyReflection;
    vec3 fullOceanColor = mix(cleanOceanColor, COLOR_FOAM, finalWhitecapMask);

    // Apply Atmospheric Attenuation
    float horizonHaze = pow(1.0 - max(0.0, dot(normal, vec3(0.0, 1.0, 0.0))), 8.0);
    fullOceanColor = mix(fullOceanColor, COLOR_SKY_HORIZON, horizonHaze * 0.5);
    
    float horizonFog = 1.0 - exp(-t * ATMOSPHERE_FOG);
    fullOceanColor = mix(fullOceanColor, COLOR_SKY_HORIZON, horizonFog);

    // Final Interpolation
    vec3 finalColor = mix(fullSkyColor, fullOceanColor, hitSignal);

    // Output Post Processing
    finalColor = pow(finalColor, vec3(1.1)); 
    finalColor *= 1.0 - length(uv * 0.25);

    fragColor = vec4(finalColor, 1.0);
}