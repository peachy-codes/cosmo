float sharpWave(vec2 position, vec2 direction, float speed, float frequency, float sharpness, float time) {
    float waveSetup = dot(position, direction) * frequency + time * speed;
    float baseSine = sin(waveSetup) * 0.5 + 0.5;
    return pow(baseSine, sharpness);
}

float getOceanHeight(vec3 p, float time) {
    vec2 pos = p.xz;
    float height = 0.0;
    height += sharpWave(pos, vec2(0.7, 0.7), 1.2, 0.5, 4.0, time) * 0.25;
    height += sharpWave(pos, vec2(0.8, -0.6), 2.1, 1.2, 3.5, time) * 0.10;
    height += sharpWave(pos, vec2(-1.0, 0.0), 3.4, 2.8, 2.0, time) * 0.03;
    return height;
}

vec3 getOceanNormal(vec3 p, float time) {
    float eps = 0.005;
    float h = getOceanHeight(p, time);
    float hx = getOceanHeight(p + vec3(eps, 0.0, 0.0), time) - h;
    float hz = getOceanHeight(p + vec3(0.0, 0.0, eps), time) - h;
    return normalize(vec3(-hx, eps, -hz));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    float safeTime = mod(iTime, 62.8318);

    vec3 cameraPos = vec3(0.0, 1.5, -3.0);
    vec3 rayDir = normalize(vec3(uv.x, uv.y - 0.2, 1.3));

    vec3 sunDir = normalize(vec3(0.6, 0.35, 0.7));
    
    // Changing environmental colors to match a sunset theme
    vec3 skyColor = vec3(0.3, 0.4, 0.6);         // Deeper twilight blue
    vec3 deepWaterColor = vec3(0.005, 0.04, 0.1); // Darker water base
    
    // NEW: Sunlight color vector (Warm Gold / Amber)
    vec3 sunLightColor = vec3(1.0, 0.65, 0.3); 

    vec3 finalColor = vec3(0.0);
    float t = 0.01;
    bool hit = false;
    vec3 p = vec3(0.0);

    for (int i = 0; i < 80; i++) {
        p = cameraPos + rayDir * t;
        float currentSurfaceHeight = getOceanHeight(p, safeTime);
        if (p.y <= currentSurfaceHeight) {
            hit = true;
            break;
        }
        t += max(0.02, (p.y - currentSurfaceHeight) * 0.6);
        if (t > 30.0) break;
    }

    if (hit) {
        vec3 normal = getOceanNormal(p, safeTime);
        vec3 viewDir = -rayDir;

        float fresnel = pow(1.0 - max(0.0, dot(normal, viewDir)), 5.0);

        vec3 halfVector = normalize(sunDir + viewDir);
        float specGlint = pow(max(0.0, dot(normal, halfVector)), 120.0) * 2.5;

        vec3 surfaceReflection = mix(deepWaterColor, skyColor, fresnel);
        
        // MODIFIED: Apply the custom sunlight color to the wave glints
        finalColor = surfaceReflection + (sunLightColor * specGlint);

        float fog = 1.0 - exp(-t * 0.08);
        finalColor = mix(finalColor, skyColor, fog);
    } else {
        float skyGradient = max(0.0, rayDir.y + 0.2);
        finalColor = mix(vec3(0.9, 0.6, 0.5), skyColor, smoothstep(0.0, 0.6, skyGradient));
        
        float sunGlow = max(0.0, dot(rayDir, sunDir));
        
        // MODIFIED: Apply the custom sunlight color to the sun disk in the sky
        finalColor += sunLightColor * pow(sunGlow, 256.0);
    }

    fragColor = vec4(finalColor, 1.0);
}