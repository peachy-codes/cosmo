#define CAMERA_HEIGHT       0.3
#define CAMERA_PITCH       -0.1      
#define CAMERA_FOV          1.2      

#define COLOR_SUN           vec3(1.0, 0.55, 0.25)  
#define COLOR_SKY_ZENITH    vec3(0.12, 0.18, 0.35) 
#define COLOR_SKY_HORIZON   vec3(0.9, 0.45, 0.2)   
#define COLOR_WATER_DEEP    vec3(0.002, 0.02, 0.06)
#define COLOR_WATER_SHALLOW vec3(0.01, 0.12, 0.18)
#define COLOR_FOAM          vec3(0.95, 0.85, 0.75) 

#define SUNSET_DURATION     60.0   
#define SUN_START_POS       vec3(-6.0, 5.0, 10.0)  
#define SUN_END_POS         vec3(4.0, -0.2, 20.0)  

#define SWELL_SCALE         0.15     
#define SWELL_SPEED         0.001
#define SWELL_HEIGHT        0.004
#define CHOP_SPEED          0.15 
#define CHOP_HEIGHT         0.20
#define CHOP_SHARPNESS      800.0     
#define MICRO_CHOP_SCALE    8.0
#define MICRO_CHOP_HEIGHT   0.03

#define SPECULAR_POWER      300.0    
#define SPECULAR_INTENSITY  5.0     
#define GLITTER_FREQUENCY   7.1     
#define GLITTER_SPEED       1.0
#define GLITTER_ROUGHNESS   0.4     
#define SCATTER_INTENSITY   0.19     
#define ATMOSPHERE_FOG      0.05    

#define FOAM_THRESHOLD      0.17    
#define FOAM_SHARPNESS      0.3     
#define FOAM_SCALE          50.0
#define FOAM_DISTORTION     10.0
#define FOAM_FLOW_SPEED     0.15
#define FOAM_WEBBING        2.0
#define FOAM_DENSITY        0.4   

#define CAUSTIC_SCALE       10.0
#define CAUSTIC_SPEED       0.1
#define CAUSTIC_INTENSITY   1.0

#define RAY_STEPS             290
#define RENDER_MAX_DIST       45.0
#define RAY_HIT_DIST          0.01
#define RAY_MIN_STEP          0.02
#define RAY_STEP_MULT         0.8
#define RAY_DIST_BIAS         0.005
#define SKY_HORIZON_Y         0.1

#define SHADOW_STEPS          12
#define SHADOW_START_DIST     0.1
#define SHADOW_MAX_DIST       6.0
#define SHADOW_HIT_DIST       0.005
#define SHADOW_MIN_INTENSITY  0.1
#define SHADOW_SOFTNESS       4.0
#define SHADOW_STEP_MIN       0.05

#define AA_OFFSET             0.25

#define CLOUD_SCALE         0.1
#define CLOUD_SPEED         0.04
#define CLOUD_COVERAGE      0.001
#define CLOUD_DENSITY       1.5
#define CLOUD_BASE_COLOR    vec3(0.9, 0.9, 0.95)
#define CLOUD_SUNSET_COLOR  vec3(1.0, 0.45, 0.15)

#define VOL_RAY_STEPS       32
#define VOL_BEAM_INTENSITY  .02
#define CLOUD_PLANE_HEIGHT  1.0

#define FLOCK_SIZE 25
#define FLOCK_INTERVAL 20.0
#define FLOCK_START_X -1.0
#define BASE_SPEED 0.3
#define FLAP_FREQUENCY 15.0
#define VERTICAL_SPREAD 0.6
#define BIRD_SCALE 0.04

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

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

float drawBird(vec2 p, float t) {
    p /= BIRD_SCALE;
    p.x = abs(p.x);
    
    float flap = sin(t * FLAP_FREQUENCY) * 0.5;
    float y = p.x * (0.3 + flap);
    
    float thickness = 0.02 - p.x * 0.015;
    float d = abs(p.y - y);
    
    return smoothstep(thickness, thickness - 0.005, d) * smoothstep(1.0, 0.7, p.x);
}

float getFlockMask(vec2 uv, float t) {
    float flockMask = 0.0;

    float cycleTime = mod(t, FLOCK_INTERVAL);

    for(int i = 0; i < FLOCK_SIZE; i++) {
        float id = float(i);
        float h1 = hash(id * 11.11);
        float h2 = hash(id * 22.22);
        float h3 = hash(id * 33.33);

        float speed = BASE_SPEED * (0.8 + h1 * 0.4);
        
        float delay = h2 * 4.0;
        
        float x = FLOCK_START_X + max(0.0, cycleTime - delay) * speed;

        float y = (h3 - 0.5) * VERTICAL_SPREAD + 0.3;
        y += sin(x * 2.0 + h1 * 10.0) * 0.05;

        vec2 pos = vec2(x, y);

        if (x > -2.5 && x < 2.5) {
            float flapTime = t + h2 * 6.28;
            flockMask = max(flockMask, drawBird(uv - pos, flapTime));
        }
    }

    return flockMask;
}


float fbm(vec2 p) {
    float f = 0.0;
    float amp = 0.5;
    for(int i = 0; i < 4; i++) {
        f += amp * abs(gradientNoise(p));
        p *= 2.0;
        amp *= 0.5;
    }
    return f;
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

float calcSoftShadow(vec3 ro, vec3 rd, float safeTime) {
    float res = 1.0;
    float t = SHADOW_START_DIST;
    
    for(int i = 0; i < SHADOW_STEPS; i++) {
        vec3 p = ro + rd * t;
        float h = getOceanHeight(p, safeTime);
        float d = p.y - h;
        
        if(d < SHADOW_HIT_DIST) return SHADOW_MIN_INTENSITY; 
        
        res = min(res, SHADOW_SOFTNESS * d / t);
        t += max(SHADOW_STEP_MIN, d);
        
        if(t > SHADOW_MAX_DIST) break;
    }
    return clamp(res, SHADOW_MIN_INTENSITY, 1.0);
}

float getCloudShadow(vec3 p, vec3 sunDir, float safeTime) {
    float intersectT = (CLOUD_PLANE_HEIGHT - p.y) / max(0.01, sunDir.y);
    if (intersectT < 0.0) return 1.0; 
    
    vec3 cloudHitP = p + sunDir * intersectT;
    vec2 uv = cloudHitP.xz * CLOUD_SCALE + safeTime * CLOUD_SPEED;
    float noiseValue = fbm(uv);
    float cloudMask = smoothstep(CLOUD_COVERAGE, CLOUD_COVERAGE + 0.3, noiseValue);
    
    return 1.0 - (cloudMask * CLOUD_DENSITY);
}

vec3 renderSky(vec3 ro, vec3 rd, vec3 sunDir, float safeTime) {
    float skyPitch = max(0.0, rd.y - CAMERA_PITCH);
    vec3 backgroundSky = mix(COLOR_SKY_HORIZON, COLOR_SKY_ZENITH, smoothstep(0.0, 0.4, skyPitch));
    float sunCone = max(0.0, dot(rd, sunDir));
    vec3 solarCore = COLOR_SUN * pow(sunCone, 2000.0) * 5.0; 
    vec3 solarGlow = COLOR_SKY_HORIZON * pow(sunCone, 32.0) * 0.5; 
    vec3 fullSkyColor = backgroundSky + solarCore + solarGlow;

    if (rd.y > 0.0) {
        float distToClouds = (CLOUD_PLANE_HEIGHT - ro.y) / rd.y;
        float marchLimit = min(distToClouds, RENDER_MAX_DIST);
        float stepSize = marchLimit / float(VOL_RAY_STEPS);
        float t = 0.0;
        vec3 accumulatedBeams = vec3(0.0);
        
        float phase = pow(sunCone, 3.0) + 0.1;

        for (int i = 0; i < VOL_RAY_STEPS; i++) {
            vec3 p = ro + rd * t;
            float shadow = getCloudShadow(p, sunDir, safeTime);
            accumulatedBeams += COLOR_SUN * shadow * phase * VOL_BEAM_INTENSITY * stepSize;
            t += stepSize;
        }
        
        fullSkyColor += accumulatedBeams;

        if (distToClouds < RENDER_MAX_DIST) {
            vec3 cloudHitP = ro + rd * distToClouds;
            vec2 cloudUV = cloudHitP.xz * CLOUD_SCALE + safeTime * CLOUD_SPEED;
            float noiseValue = fbm(cloudUV);
            float cloudMask = smoothstep(CLOUD_COVERAGE, CLOUD_COVERAGE + 0.3, noiseValue);

            if (cloudMask > 0.0) {
                float sunProximity = max(0.0, dot(rd, sunDir));
                vec3 cloudColor = mix(CLOUD_BASE_COLOR, CLOUD_SUNSET_COLOR, pow(sunProximity, 3.0));
                cloudColor *= mix(0.4, 1.0, noiseValue);
                float horizonFade = smoothstep(0.0, 0.2, rd.y);
                fullSkyColor = mix(fullSkyColor, cloudColor, cloudMask * CLOUD_DENSITY * horizonFade);
            }
        }
    }
    
    return fullSkyColor;
}

vec3 renderOcean(vec3 p, vec3 rd, vec3 sunDir, float safeTime, float t) {
    vec3 normal = getOceanNormal(p, safeTime, t);
    
    float horizonFlatten = smoothstep(20.0, RENDER_MAX_DIST, t);
    normal = normalize(mix(normal, vec3(0.0, 1.0, 0.0), horizonFlatten));

    vec3 viewDir = -rd;

    float shadow = 1.0;
    if (dot(normal, sunDir) > 0.0) {
        shadow = calcSoftShadow(p, sunDir, safeTime);
    }

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
    vec3 sunReflection = COLOR_SUN * specGlint * SPECULAR_INTENSITY * shadow; 

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

    float baseIllumination = max(0.4, dot(normal, sunDir)) * shadow * 0.8 + 0.2;
    float foamSpecular = pow(max(0.0, dot(normal, halfVector)), 15.0) * 0.5;
    
    vec3 volumetricFoamColor = COLOR_FOAM * (baseIllumination + foamSlopeHighlight * max(0.0, sunDir.y) + foamSpecular);

    float foamShadowMask = smoothstep(0.0, 0.5, crestMask * foamWebbing) - finalWhitecapMask;

    vec3 cleanOceanColor = baseColor + subsurfaceGlow + sunReflection + skyReflection;
    cleanOceanColor *= clamp(1.0 - foamShadowMask * 0.8, 0.0, 1.0); 

    vec3 fullOceanColor = mix(cleanOceanColor, volumetricFoamColor, finalWhitecapMask);

    float horizonHaze = pow(1.0 - max(0.0, dot(normal, vec3(0.0, 1.0, 0.0))), 8.0);
    fullOceanColor = mix(fullOceanColor, COLOR_SKY_HORIZON, horizonHaze * 0.5);
    
    float horizonFog = 1.0 - exp(-t * ATMOSPHERE_FOG);
    fullOceanColor = mix(fullOceanColor, COLOR_SKY_HORIZON, horizonFog);

    return fullOceanColor;
}

vec3 renderScene(vec2 uv, float safeTime, float normFactor) {
    vec3 cameraPos = vec3(0.0, CAMERA_HEIGHT, -5.0);
    vec3 rayDir = normalize(vec3(uv.x * CAMERA_FOV, uv.y + CAMERA_PITCH, 1.5)); 

    vec3 rawSunPos = mix(SUN_START_POS, SUN_END_POS, normFactor);
    vec3 sunDir = normalize(rawSunPos);

    float t = RAY_HIT_DIST;
    float hitSignal = 0.0; 
    vec3 p = vec3(0.0);

    if (rayDir.y > SKY_HORIZON_Y) {
        t = RENDER_MAX_DIST;
    } else {
        for (int i = 0; i < RAY_STEPS; i++) {
            p = cameraPos + rayDir * t;
            float currentSurfaceHeight = getOceanHeight(p, safeTime);
            float d = p.y - currentSurfaceHeight;
            
            if (d < RAY_HIT_DIST) {
                hitSignal = 1.0;
                break;
            }
            
            t += max(RAY_MIN_STEP, d * RAY_STEP_MULT) + (t * RAY_DIST_BIAS);
            if (t > RENDER_MAX_DIST) break;
        }
    }
    
    t = min(t, RENDER_MAX_DIST);

    vec3 finalColor = renderSky(cameraPos, rayDir, sunDir, safeTime);

    if (hitSignal > 0.5) {
        vec3 oceanColor = renderOcean(p, rayDir, sunDir, safeTime, t);
        finalColor = mix(finalColor, oceanColor, hitSignal);
    }

    float flock = getFlockMask(uv, safeTime);
    finalColor = mix(finalColor, vec3(0.08, 0.09, 0.1), flock);

    finalColor = pow(finalColor, vec3(1.1)); 
    finalColor *= 1.0 - length(uv * 0.25);

    return finalColor;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float manualTime = (iMouse.x / iResolution.x) * SUNSET_DURATION * 5.0;
    float safeTime = iMouse.z > 0.0 ? manualTime : iTime;
    float normFactor = fract(iTime / SUNSET_DURATION);

    vec3 totalColor = vec3(0.0);
    
    vec2 offsets[2];
    offsets[0] = vec2(-AA_OFFSET, -AA_OFFSET);
    offsets[1] = vec2(AA_OFFSET, AA_OFFSET);

    for(int i = 0; i < 2; i++) {
        vec2 uv = ((fragCoord + offsets[i]) * 2.0 - iResolution.xy) / iResolution.y;
        totalColor += renderScene(uv, safeTime, normFactor); 
    }
    
    totalColor /= 2.0;
    fragColor = vec4(totalColor, 1.0);
}