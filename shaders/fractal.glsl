mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

float gyroid(vec3 p) {
    return dot(sin(p), cos(p.yzx));
}

float map(vec3 p) {
    p.z += iTime * 0.001;
    p.xy *= rot(iTime * 0.02);
    p.xz *= rot(iTime * 0.01);
    
    float scale = 1.5;
    float d = abs(gyroid(p * scale)) / scale - 0.05;
    
    return d * 0.5;
}

vec3 getNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)
    ));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    
    vec3 ro = vec3(0.0, 0.0, -2.0);
    vec3 rd = normalize(vec3(uv, 1.0));
    
    float t = 0.0;
    vec3 col = vec3(0.0);
    float glow = 0.0;
    
    for(int i = 0; i < 128; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        
        glow += 0.005 / (0.01 + abs(d));
        
        if(d < 0.001 || t > 10.0) break;
        t += d;
    }
    
    if(t < 10.0) {
        vec3 p = ro + rd * t;
        vec3 n = getNormal(p);
        vec3 v = -rd;
        
        vec3 lightDir = normalize(vec3(1.0, 2.0, -3.0));
        float diff = max(dot(n, lightDir), 0.0);
        
        vec3 h = normalize(lightDir + v);
        float spec = pow(max(dot(n, h), 0.0), 64.0);
        
        float fresnel = pow(1.0 - max(dot(n, v), 0.0), 5.0);
        
        vec3 albedo = 0.5 + 0.5 * cos(vec3(0.0, 0.3, 0.6) + t * 0.4 - iTime);
        
        col = albedo * diff * 0.5;
        col += vec3(1.0, 0.9, 0.8) * spec;
        col += albedo * fresnel * 2.0;
    }
    
    col += vec3(0.8, 0.2, 0.5) * glow * 0.1;
    
    col = mix(col, vec3(0.05, 0.02, 0.1), 1.0 - exp(-0.1 * t));
    
    col = col / (1.0 + col);
    col = pow(col, vec3(0.4545));
    
    fragColor = vec4(col, 1.0);
}