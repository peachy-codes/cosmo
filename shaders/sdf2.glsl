precision highp float;

mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

float sdSphere(vec3 p, float s) {
    return length(p) - s;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float smoothMin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float map(vec3 p) {
    vec3 spherePos = p - vec3(0.0, 1.0, 0.0);
    float d1 = sdSphere(spherePos, 1.0);

    vec3 boxPos = p - vec3(0.0, 0.5, 0.0);
    boxPos.xz *= rot(iTime);
    float d2 = sdBox(boxPos, vec3(0.75));

    float d = smoothMin(d1, d2, 0.5);

    float plane = p.y;
    return min(d, plane);
}

vec3 calcNormal(vec3 p) {
    vec2 e = vec2(1.0, -1.0) * 0.5773 * 0.0005;
    return normalize(e.xyy * map(p + e.xyy) +
                     e.yyx * map(p + e.yyx) +
                     e.yxy * map(p + e.yxy) +
                     e.xxx * map(p + e.xxx));
}

float calcAO(vec3 pos, vec3 nor) {
    float occ = 0.0;
    float sca = 1.0;
    for(int i = 0; i < 5; i++) {
        float hr = 0.01 + 0.12 * float(i) / 4.0;
        vec3 aopos = nor * hr + pos;
        float dd = map(aopos);
        occ += -(dd - hr) * sca;
        sca *= 0.95;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

float softShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
    float res = 1.0;
    float t = mint;
    for(int i = 0; i < 256 && t < maxt; i++) {
        float h = map(ro + rd * t);
        if(h < 0.001) return 0.0;
        res = min(res, k * h / t);
        t += clamp(h, 0.02, 0.20);
    }
    return clamp(res, 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0.0, 2.0, 5.0);
    vec3 ta = vec3(0.0, 1.0, 0.0);
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = normalize(cross(uu, ww));
    vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.5 * ww);

    float t = 0.0;
    for(int i = 0; i < 256; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        if(d < 0.001 || t > 20.0) break;
        t += d;
    }

    vec3 col = vec3(0.0);

    if(t < 20.0) {
        vec3 p = ro + rd * t;
        vec3 n = calcNormal(p);

        vec3 lig = normalize(vec3(sin(iTime) * 2.0, 4.0, cos(iTime) * 2.0));

        float dif = clamp(dot(n, lig), 0.0, 1.0);
        float sha = softShadow(p, lig, 0.02, 10.0, 16.0);
        float ao = calcAO(p, n);

        col = vec3(0.8, 0.9, 1.0) * dif * sha * ao;

        vec3 amb = vec3(0.2, 0.22, 0.25) * ao;
        col += amb;
    } else {
        col = vec3(0.1, 0.15, 0.2) - uv.y * 0.1;
    }

    col = pow(col, vec3(1.0/2.2));

    fragColor = vec4(col, 1.0);
}