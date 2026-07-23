#version 460 core

AppInclude(ShadingRateClassification/include/Constants.glsl)

layout(local_size_x = TILE_SIZE, local_size_y = TILE_SIZE, local_size_z = 1) in;

layout(binding = 0, rgba16f) restrict writeonly uniform image2D ImgResult;

layout(binding = 0) uniform sampler2D SamplerDest;
layout(binding = 1) uniform usampler2D SamplerRate;
layout(binding = 2) uniform sampler2D SamplerDebug;

layout(std140, binding = 0) uniform SettingsUBO
{
    int   DebugValue;

    float MotionLow;
    float MotionHigh;

    float LumaVarianceLow;
    float LumaVarianceHigh;

    float DepthRangeThreshold;

    vec2  MousePos;
    int   IsFoveated;
    float InnerRadius;
    float MiddleRadius;

    int   Allow2x2;
    int   Allow4x2;
    int   Allow4x4;

    float MotionBias;
    float VarianceBias;
    float _Pad0;
} settingsUBO;

vec3 GetRateColor(uint rate)
{
    if (rate == ENUM_SHADING_RATE_1_INVOCATION_PER_PIXEL_NV) return vec3(0.0, 1.0, 0.0);
    if (rate == ENUM_SHADING_RATE_1_INVOCATION_PER_2X1_PIXELS_NV) return vec3(0.0, 1.0, 1.0);
    if (rate == ENUM_SHADING_RATE_1_INVOCATION_PER_2X2_PIXELS_NV) return vec3(1.0, 1.0, 0.0);
    if (rate == ENUM_SHADING_RATE_1_INVOCATION_PER_4X2_PIXELS_NV) return vec3(1.0, 0.5, 0.0);
    return vec3(1.0, 0.0, 0.0);
}

void main()
{
    ivec2 pixelCoord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 fullRes = imageSize(ImgResult);

    if (pixelCoord.x >= fullRes.x || pixelCoord.y >= fullRes.y)
    {
        return;
    }

    vec2 uv = (vec2(pixelCoord) + 0.5) / vec2(fullRes);
    vec3 baseColor = textureLod(SamplerDest, uv, 0).rgb;

    ivec2 rateSize = textureSize(SamplerRate, 0);
    ivec2 tileCoord = ivec2(uv * vec2(rateSize));
    tileCoord = clamp(tileCoord, ivec2(0), rateSize - ivec2(1));

    vec3 overlay = vec3(0.0);

    if (settingsUBO.DebugValue == 1)
{
    uint rate = texelFetch(SamplerRate, tileCoord, 0).r;
    overlay = GetRateColor(rate);
}
else
{
    float debugValue = texelFetch(SamplerDebug, tileCoord, 0).r;
    float normalizedValue = 0.0;

    if (settingsUBO.DebugValue == 2)
    {
        // Motion
        normalizedValue = debugValue / max(settingsUBO.MotionHigh, 0.0001);
        overlay = vec3(clamp(normalizedValue, 0.0, 1.0), 0.0, 1.0 - clamp(normalizedValue, 0.0, 1.0));
    }
    else if (settingsUBO.DebugValue == 3)
    {
        // Luminance
        normalizedValue = clamp(debugValue, 0.0, 1.0);
        overlay = vec3(normalizedValue);
    }
    else if (settingsUBO.DebugValue == 4)
    {
        // LuminanceVariance
        normalizedValue = debugValue / max(settingsUBO.LumaVarianceHigh, 0.000001);
        overlay = vec3(clamp(normalizedValue, 0.0, 1.0), clamp(normalizedValue, 0.0, 1.0), 0.0);
    }
    else if (settingsUBO.DebugValue == 5)
    {
        // DepthRange
        normalizedValue = debugValue / max(settingsUBO.DepthRangeThreshold, 0.000001);
        overlay = vec3(1.0, 1.0 - clamp(normalizedValue, 0.0, 1.0), 0.0);
    }
    else if (settingsUBO.DebugValue == 6)
    {
        // Foveated distance
        normalizedValue = debugValue / max(settingsUBO.MiddleRadius, 0.0001);
        overlay = vec3(0.0, 1.0 - clamp(normalizedValue, 0.0, 1.0), clamp(normalizedValue, 0.0, 1.0));
    }
    else
    {
        overlay = vec3(1.0, 0.0, 1.0);
    }
}

    vec3 finalColor = mix(baseColor, overlay, 0.55);
    imageStore(ImgResult, pixelCoord, vec4(finalColor, 1.0));
}