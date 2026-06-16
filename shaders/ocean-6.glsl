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
#define COLOR_FOAM          vec3(0.95, 0.85, 0.75) 

// --- Dynamic Sun Settings ---
#define SUNSET_DURATION     6.0   //set to 6000  // Time in seconds for one full transit cycle
#define SUN_START_POS       vec3(-3.0, 2.0, 10.0)  // (proposed -10, 6, 10)Top Left coordinate setup
#define SUN_END_POS         vec3(4.0, 0.0, 20.0)  // (proposed 8, -.5, 50)  Bottom Right (Y is negative to sink below horizon)

// --- Wave Geometry Profiles ---
#define SWELL_SCALE         0.15     
#define SWELL_SPEED         0.001
#define SWELL_HEIGHT        0.004
#define CHOP_SPEED          0.15 // set to .15
#define CHOP_HEIGHT         0.20
#define CHOP_SHARPNESS      800.0     
#define MICRO_CHOP_SCALE    8.0
#define MICRO_CHOP_HEIGHT   0.03

// --- Shading Modifiers ---
#define SPECULAR_POWER      300.0    
#define SPECULAR_INTENSITY  2.0     
#define GLITTER_FREQUENCY   7.1     
#define GLITTER_SPEED       1.0
#define GLITTER_ROUGHNESS   0.4     
#define SCATTER_INTENSITY   0.19     
#define ATMOSPHERE_FOG      0.05    

// --- Foam Control Modifiers ---
#define FOAM_THRESHOLD      0.17    
#define FOAM_SHARPNESS      0.3     
#define FOAM_SCALE          50.0
#define FOAM_DISTORTION     10.0
#define FOAM_FLOW_SPEED     0.15
#define FOAM_WEBBING        2.0
#define FOAM_DENSITY        0.4   

// --- Caustics Modifiers ---

#define CAUSTIC_SCALE       10.0
#define CAUSTIC_SPEED       0.1
#define CAUSTIC_INTENSITY   1.0

// ============================================================================
// RENDERING CORE
// ============================================================================

vec2 hash2d(vec2 p) {
    p = mod(p, 289.0);
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
    
    float swell = sin(pos.x * 1.5 + pos.y * 1.0 + time * SWELL_SPEED);
    height += (1.0 - abs(swell)) * SWELL_HEIGHT; 
    
    float crossSwell = sin(pos.x * -1.2 + pos.y * 1.8 + time * CHOP_SPEED);
    height += pow(crossSwell * 0.5 + 0.5, CHOP_SHARPNESS) * CHOP_HEIGHT;
    
    vec2 chopUV = pos * MICRO_CHOP_SCALE + vec2(time * 0.5, -time * 0.3);
    height += gradientNoise(chopUV) * MICRO_CHOP_HEIGHT;
    
    return height;
}

vec3 getOceanNormal(vec3 p, float time, float t) {
    float eps = 0.001 + (t * .0015); 
    float h = getOceanHeight(p, time);
    float hx = getOceanHeight(p + vec3(eps, 0.0, 0.0), time) - h;
    float hz = getOceanHeight(p + vec3(0.0, 0.0, eps), time) - h;
    return normalize(vec3(-hx, eps, -hz));
}

float calcCaustics(vec2 p, float time) {
    p *= CAUSTIC_SCALE;
    float t = time * CAUSTIC_SPEED;
    vec2 shift = vec2(cos(p.y + t), sin(p.x - t)) * 0.5;
    p += shift;
    return pow(max(0.0, sin(p.x) * sin(p.y)), 2.0) * CAUSTIC_INTENSITY;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    float manualTime = (iMouse.x / iResolution.x) * SUNSET_DURATION * 5.0;
    float safeTime = iMouse.z > 0.0 ? manualTime : iTime;

    // Camera Configuration
    vec3 cameraPos = vec3(0.0, CAMERA_HEIGHT, -5.0);
    vec3 rayDir = normalize(vec3(uv.x * CAMERA_FOV, uv.y + CAMERA_PITCH, 1.5)); 

    // CALCULATE TRUE DIAGONAL SUNSET AXIS
    // NormFactor loops cleanly from 0.0 to 1.0 back and forth over the defined duration
    float normFactor = fract(iTime / SUNSET_DURATION);
    vec3 rawSunPos = mix(SUN_START_POS, SUN_END_POS, normFactor);
    vec3 sunDir = normalize(rawSunPos);

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
    float sunCone = max(0.0, dot(rayDir, sunDir));
    vec3 solarCore = COLOR_SUN * pow(sunCone, 2000.0) * 5.0; 
    vec3 solarGlow = COLOR_SKY_HORIZON * pow(sunCone, 32.0) * 0.5; 
    vec3 fullSkyColor = backgroundSky + solarCore + solarGlow;

    // Process Ocean
    vec3 normal = getOceanNormal(p, safeTime, t);
    
    float horizonFlatten = smoothstep(20.0, 45.0, t);
    normal = normalize(mix(normal, vec3(0.0, 1.0, 0.0), horizonFlatten));

    vec3 viewDir = -rayDir;

    float grazingAngle = 1.0 - max(0.0, dot(vec3(0.0, 1.0, 0.0), viewDir));
    float lodFade = smoothstep(0.0, 30.0, t);
    float combinedLOD = clamp(lodFade + (grazingAngle * smoothstep(10.0, 30.0, t)), 0.0, 1.0);

    float dynamicGlitter = mix(GLITTER_ROUGHNESS, 0.0, combinedLOD);
    float dynamicSpecPower = mix(SPECULAR_POWER, 20.0, combinedLOD);

    float microChop = gradientNoise(p.xz * GLITTER_FREQUENCY + safeTime * GLITTER_SPEED);
    vec3 glitterNormal = normalize(normal + vec3(microChop * dynamicGlitter, 0.0, microChop * dynamicGlitter));

    float facing = max(0.0, dot(normal, viewDir));
    vec3 baseColor = mix(COLOR_WATER_SHALLOW, COLOR_WATER_DEEP, facing);

    float waveForwardScattering = max(0.0, dot(sunDir, -viewDir));
    float internalGlowMask = pow(1.0 - facing, 4.0) * pow(waveForwardScattering, 8.0);
    
    float causticIntensity = calcCaustics(p.xz + normal.xz * 0.5, safeTime);
    vec3 causticsLayer = COLOR_SUN * causticIntensity * max(0.0, sunDir.y);
    vec3 subsurfaceGlow = (vec3(0.0, 0.6, 0.5) * SCATTER_INTENSITY + causticsLayer) * internalGlowMask;

    vec3 halfVector = normalize(sunDir + viewDir);
    float specGlint = pow(max(0.0, dot(glitterNormal, halfVector)), dynamicSpecPower); 
    vec3 sunReflection = COLOR_SUN * specGlint * SPECULAR_INTENSITY; 

    float fresnel = pow(1.0 - facing, 5.0);
    vec3 skyReflection = mix(COLOR_SKY_HORIZON, COLOR_SKY_ZENITH, normal.y) * fresnel * 0.6;

    float crestMask = clamp((p.y - FOAM_THRESHOLD) / (CHOP_HEIGHT - FOAM_THRESHOLD), 0.0, 1.0);
    crestMask = pow(crestMask, FOAM_SHARPNESS);

    vec2 flowOffset = vec2(
        gradientNoise(p.xz * 2.0 + safeTime * FOAM_FLOW_SPEED), 
        gradientNoise(p.xz * 2.0 - safeTime * FOAM_FLOW_SPEED)
    );
    vec2 foamUV = p.xz * FOAM_SCALE + flowOffset * FOAM_DISTORTION;

    float baseFoamNoise = gradientNoise(foamUV); 
    
    vec2 lightDir2D = normalize(sunDir.xz);
    float offsetNoise = gradientNoise(foamUV + lightDir2D * 0.5);
    float foamSlopeHighlight = max(0.0, baseFoamNoise - offsetNoise) * 3.0;

    float foamWebbing = 1.0 - abs(baseFoamNoise * 1.5);
    foamWebbing = clamp(foamWebbing, 0.0, 1.0);
    foamWebbing = pow(foamWebbing, FOAM_WEBBING); 

    float foamDistanceFade = 1.0 - smoothstep(15.0, 40.0, t);
    float finalWhitecapMask = smoothstep(FOAM_DENSITY, 0.6, crestMask * foamWebbing) * foamDistanceFade;

    float baseIllumination = max(0.4, dot(normal, sunDir)) * 0.8 + 0.2;
    float foamSpecular = pow(max(0.0, dot(normal, halfVector)), 15.0) * 0.5;
    
    vec3 volumetricFoamColor = COLOR_FOAM * (baseIllumination + foamSlopeHighlight * max(0.0, sunDir.y) + foamSpecular);

    float foamShadowMask = smoothstep(0.0, 0.5, crestMask * foamWebbing) - finalWhitecapMask;

    vec3 cleanOceanColor = baseColor + subsurfaceGlow + sunReflection + skyReflection;
    cleanOceanColor *= clamp(1.0 - foamShadowMask * 0.8, 0.0, 1.0); 

    vec3 fullOceanColor = mix(cleanOceanColor, volumetricFoamColor, finalWhitecapMask);
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