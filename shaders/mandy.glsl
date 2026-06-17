#define AA 2

vec3 getPalette(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (t + vec3(0.0, 0.15, 0.30)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec3 finalColor = vec3(0.0);
    
    vec2 target = vec2(-0.74364388703, 0.13182590421);
    
    float loopTime = mod(iTime, 16.0);
    float zoom = pow(0.9, loopTime + 3.0);
    float maxIter = 2048.0;

    for(int m = 0; m < AA; m++) {
        for(int n = 0; n < AA; n++) {
            vec2 offset = vec2(float(m), float(n)) / float(AA) - 0.5;
            vec2 uv = (fragCoord + offset - 0.5 * iResolution.xy) / iResolution.y;
            vec2 c = target + uv * zoom;
            
            vec2 z = vec2(0.0);
            float iter = 0.0;
            
            for(float i = 0.0; i < 256.0; i++) {
                z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
                if(dot(z, z) > 256.0) {
                    break;
                }
                iter++;
            }
            
            if(iter < maxIter) {
                float smoothIter = iter - log2(log2(dot(z, z))) + 4.0;
                finalColor += getPalette(smoothIter * 0.05 - iTime * 2.0);
            }
        }
    }
    
    finalColor /= float(AA * AA);
    fragColor = vec4(finalColor, 1.0);
}