float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float f = 0.0;
    float amp = 0.5;
    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 4; i++) {
        f += amp * noise(p);
        p = p * 2.0 * rot;
        amp *= 0.5;
    }
    return f;
}

#define MAX_STEPS 100
#define MAX_DIST 150.0
#define SURF_DIST 0.005

float getSandHeight(vec2 uv) {
    float slope = -uv.y * 0.05 - 0.5;
    float dunes = fbm(uv * 0.5) * 0.2;
    float detail = fbm(uv * 4.0) * 0.03;
    return slope + dunes + detail;
}

float getWaterHeight(vec2 uv, float t) {
    float h = 0.0;
    vec2 dir = normalize(vec2(-0.2, -1.0));
    float freq = 1.0;
    float amp = 0.15;
    float speed = 2.0;

    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 4; i++) {
        h += sin(dot(uv, dir) * freq + t * speed) * amp;
        uv = rot * uv * 1.5;
        amp *= 0.5;
        freq *= 1.8;
        speed *= 1.2;
    }
    return h - 0.8;
}

float rayMarchSand(vec3 ro, vec3 rd) {
    float dO = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * dO;
        float dS = p.y - getSandHeight(p.xz);
        if (abs(dS) < SURF_DIST || dO > MAX_DIST) break;
        dO += dS * 0.5;
    }
    return dO;
}

float rayMarchWater(vec3 ro, vec3 rd) {
    float dO = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * dO;
        float dS = p.y - getWaterHeight(p.xz, iTime);
        if (abs(dS) < SURF_DIST || dO > MAX_DIST) break;
        dO += dS * 0.5;
    }
    return dO;
}

vec3 getSandNormal(vec3 p) {
    vec2 e = vec2(0.01, 0.0);
    return normalize(vec3(
        getSandHeight(p.xz - e.xy) - getSandHeight(p.xz + e.xy),
        2.0 * e.x,
        getSandHeight(p.xz - e.yx) - getSandHeight(p.xz + e.yx)
    ));
}

vec3 getWaterNormal(vec3 p, float t) {
    vec2 e = vec2(0.01, 0.0);
    return normalize(vec3(
        getWaterHeight(p.xz - e.xy, t) - getWaterHeight(p.xz + e.xy, t),
        2.0 * e.x,
        getWaterHeight(p.xz - e.yx, t) - getWaterHeight(p.xz + e.yx, t)
    ));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0.0, 1.7, -5.0);
    vec3 rd = normalize(vec3(uv.x, uv.y - 0.15, 1.0));

    float t = iTime * 0.8;

    float dSand = rayMarchSand(ro, rd);
    float dWater = rayMarchWater(ro, rd);

    vec3 sunDir = normalize(vec3(0.6, 0.2, 0.8));
    vec3 skyCol = mix(vec3(0.8, 0.6, 0.5), vec3(0.3, 0.5, 0.8), clamp(rd.y * 2.0 + 0.1, 0.0, 1.0));
    float sun = pow(max(dot(rd, sunDir), 0.0), 64.0);
    skyCol += sun * vec3(1.0, 0.8, 0.5);

    vec3 color = skyCol;
    float minD = min(dSand, dWater);

    if (minD < MAX_DIST) {
        vec3 pSand = ro + rd * dSand;
        vec3 nSand = getSandNormal(pSand);

        vec3 sandCol = vec3(0.85, 0.75, 0.6);
        float diffS = max(dot(nSand, sunDir), 0.0);
        sandCol *= diffS * 0.7 + 0.3;

        float wetBand = -0.75 + fbm(pSand.xz * 2.0) * 0.1;
        float wetness = smoothstep(wetBand + 0.2, wetBand - 0.1, pSand.y);
        sandCol *= mix(1.0, 0.6, wetness);

        vec3 refSand = reflect(rd, nSand);
        float specSand = pow(max(dot(refSand, sunDir), 0.0), 32.0);
        sandCol += specSand * wetness * vec3(1.0, 0.9, 0.7) * 0.5;

        if (dWater < dSand) {
            vec3 pW = ro + rd * dWater;
            vec3 nW = getWaterNormal(pW, t);

            float vDepth = pW.y - getSandHeight(pW.xz);
            vDepth = max(vDepth, 0.0);

            vec3 shallow = vec3(0.1, 0.5, 0.4);
            vec3 deep = vec3(0.02, 0.1, 0.2);
            vec3 waterVol = mix(shallow, deep, clamp(vDepth * 1.5, 0.0, 1.0));

            vec3 transmitted = mix(sandCol, waterVol, clamp(vDepth * 2.5, 0.0, 1.0));

            vec3 refW = reflect(rd, nW);
            float fresnel = mix(0.04, 1.0, pow(1.0 - max(dot(nW, -rd), 0.0), 5.0));

            vec3 skyRef = mix(vec3(0.8, 0.6, 0.5), vec3(0.3, 0.5, 0.8), clamp(refW.y * 2.0 + 0.1, 0.0, 1.0));
            skyRef += pow(max(dot(refW, sunDir), 0.0), 128.0) * vec3(1.0, 0.9, 0.6);

            vec3 finalWater = mix(transmitted, skyRef, fresnel);

            float foamNoise = fbm(pW.xz * 8.0 - vec2(0.0, t));
            float edgeFoam = exp(-vDepth * 25.0) * smoothstep(0.2, 0.8, foamNoise);
            float waveCrest = smoothstep(0.05, 0.15, pW.y + 0.8);
            float crestFoam = waveCrest * smoothstep(0.3, 0.7, foamNoise);

            float foam = clamp(edgeFoam + crestFoam * exp(-vDepth * 0.5), 0.0, 1.0);

            color = mix(finalWater, vec3(0.95, 0.98, 1.0), foam);
        } else {
            color = sandCol;
        }

        float fog = 1.0 - exp(-minD * 0.015);
        color = mix(color, skyCol, fog);
    }

    color = pow(color, vec3(0.4545));
    fragColor = vec4(color, 1.0);
}