// 얼음 소행성 구역 셰이더 (URP, 한 구역에 떠 있는 얼음 가루 안개).
// 평면 Quad 한 장에 쓴다. 텍스처 없이 월드 xz 좌표 위 값 노이즈 fBm 으로 밀도를 만들고, 도메인 워프로 서서히 일렁인다.
// 태양 = 씬의 Point Light. URP 추가 광원 루프로 읽는다 (위치·방향 프로퍼티, C# 스크립트 없음). 메인 라이트(Directional)는 쓰지 않는다.
// 합성: 색은 이미 premultiplied. Blend One OneMinusSrcAlpha. _Opacity 0 = 순수 가산, 올리면 짙은 곳이 뒤 별을 가린다.
// 전제: Quad 를 X 90° 눕혀 위를 보게 한다 (평면 법선 = 월드 (0,1,0) 로 고정). 그림자 패스·그림자 키워드 없음.
// 추가 광원 모드: PC(Forward+)는 _CLUSTER_LIGHT_LOOP, Mobile(Forward)은 RP Asset 의 Additional Lights 가 Per Pixel 이어야 들어온다.
// 구현 순서(한 파일): 1 밀도 -> 2 일렁임 -> 3 점광원 감쇠 -> 4 법선+방향 확산 -> 5 반짝임+HDR
Shader "HybridShooter/Space/Ice Asteroid Field"
{
    Properties
    {
        // 1단계: 밀도
        _NoiseScale ("Noise Scale (cells per meter)", Range(0.05, 2)) = 0.35
        _Coverage ("Coverage (higher = less dust)", Range(0, 1)) = 0.48
        _Softness ("Softness", Range(0.02, 1)) = 0.3
        _EdgeFade ("Edge Fade", Range(0.02, 1)) = 0.35
        // 2단계: 일렁임
        _FlowSpeed ("Flow Speed", Range(0, 1)) = 0.05
        _WarpStrength ("Warp Strength", Range(0, 2)) = 0.6
        // 3~4단계: 태양 빛, 법선
        _LightGain ("Light Gain", Range(0, 8)) = 1
        _BumpStrength ("Bump Strength", Range(0, 8)) = 1.5
        _Wrap ("Wrap Diffuse", Range(0, 1)) = 0.3
        // 5단계: 합성, 반짝임
        _IceColor ("Ice Color", Color) = (0.75, 0.9, 1, 1)
        _Ambient ("Ambient (HDR floor brightness)", Range(0, 8)) = 0.15
        _Opacity ("Opacity", Range(0, 1)) = 0.25
        _SparkleScale ("Sparkle Scale (cells per meter)", Range(1, 40)) = 6
        _SparkleDensity ("Sparkle Density", Range(0, 1)) = 0.08
        _SparkleIntensity ("Sparkle Intensity", Range(0, 20)) = 3
        _TwinkleSpeed ("Twinkle Speed", Range(0, 10)) = 2
    }

    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "IceField"
            Tags { "LightMode" = "UniversalForward" }

            Blend One OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _NoiseScale;
                float _Coverage;
                float _Softness;
                float _EdgeFade;
                float _FlowSpeed;
                float _WarpStrength;
                float _LightGain;
                float _BumpStrength;
                float _Wrap;
                half4 _IceColor;
                float _Ambient;
                float _Opacity;
                float _SparkleScale;
                float _SparkleDensity;
                float _SparkleIntensity;
                float _TwinkleSpeed;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                output.uv = input.uv;
                return output;
            }

            // ===== 1단계: 밀도 (값 노이즈 fBm) =====

            // 해시 (사인 없음, 0~1). 입력 격자 점마다 의사 난수.
            float Hash21(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.x + p3.y) * p3.z);
            }

            // 값 노이즈 0~1. 격자 4점 해시를 5차 보간.
            float ValueNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
                float a = Hash21(i);
                float b = Hash21(i + float2(1.0, 0.0));
                float c = Hash21(i + float2(0.0, 1.0));
                float d = Hash21(i + float2(1.0, 1.0));
                return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
            }

            // fBm 0~1 (정규화). 옥타브마다 좌표를 회전·이동해서 격자축 줄무늬가 겹쳐 쌓이지 않게 한다.
            float Fbm(float2 p, int octaves)
            {
                const float2x2 rot = float2x2(0.8, -0.6, 0.6, 0.8);
                float sum = 0.0;
                float amp = 0.5;
                float norm = 0.0;
                for (int i = 0; i < octaves; i++)
                {
                    sum += amp * ValueNoise(p);
                    norm += amp;
                    p = mul(rot, p) * 2.03 + 17.1;
                    amp *= 0.5;
                }
                return sum / norm;
            }

            // ===== 2단계: 일렁임 (도메인 워프) =====
            // 서로 다른 방향으로 흐르는 저주파 fBm 두 개로 좌표를 비튼다. 모양이 바뀌고 판이 통째로 미끄러지지 않는다.
            float2 WarpCoord(float2 p)
            {
                float t = _Time.y * _FlowSpeed;
                float wx = Fbm(p * 0.6 + float2(t, 0.3 * t) + float2(5.2, 1.3), 2);
                float wy = Fbm(p * 0.6 + float2(-0.4 * t, -t) + float2(9.7, 3.1), 2);
                return p + (float2(wx, wy) - 0.5) * 2.0 * _WarpStrength;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float2 p = input.positionWS.xz * _NoiseScale;
                float2 q = WarpCoord(p);

                // 밀도: fBm 높이 h 를 _Coverage 위로 끌어올림. 가장자리 마스크는 uv 중심 거리(원형)라 Quad 직선 경계가 안 보인다.
                float h = Fbm(q, 4);
                float edge = smoothstep(0.0, 1.0, saturate((1.0 - length(input.uv - 0.5) * 2.0) / _EdgeFade));
                float density = saturate((h - _Coverage) / _Softness) * edge;

                // 단계별 확인: 한 줄만 주석을 풀고 나머지는 닫는다.
                // return half4(density.xxx, 1);  // 1단계: 흰 안개 (2단계 이후는 워프된 q 기준)

                // ===== 4단계: 노이즈 법선 (유한 차분) =====
                // 같은 fBm 높이를 3번 평가해 기울기를 얻고 평면 법선 (0,1,0) 을 기울인다.
                const float eps = 0.05;
                float hx = Fbm(q + float2(eps, 0.0), 4);
                float hz = Fbm(q + float2(0.0, eps), 4);
                float2 grad = float2(hx - h, hz - h) / eps;
                float3 n = normalize(float3(-grad.x * _BumpStrength, 1.0, -grad.y * _BumpStrength));

                // ===== 3단계: Point Light (URP 추가 광원 루프) =====
                // 3단계 확인: n 대신 (0,1,0) 이면 거리 감쇠만 보인다. 4단계: 방향 확산까지.
                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);

                half3 sun = 0;   // 방향 확산을 곱한 태양 빛 (면 밝기)
                half3 glow = 0;  // 방향 없이 합산한 받은 빛 (반짝임 세기)
                #if defined(_ADDITIONAL_LIGHTS)
                LIGHT_LOOP_BEGIN(GetAdditionalLightsCount())
                    Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
                    half3 received = light.color * light.distanceAttenuation * _LightGain;
                    half diffuse = saturate((dot(n, light.direction) + _Wrap) / (1.0 + _Wrap));
                    sun += received * diffuse;
                    glow += received;
                LIGHT_LOOP_END
                #endif

                // ===== 5단계: 반짝임 (칸 해시) + HDR 합성 =====
                // 월드 xz 를 칸으로 나눠 _SparkleDensity 비율의 칸만 칸 안 무작위 위치에 작은 점. 점마다 위상이 다른 사인으로 깜빡인다.
                float2 sp = input.positionWS.xz * _SparkleScale;
                float2 cell = floor(sp);
                float2 inCell = frac(sp);
                float pick = Hash21(cell + 3.7);
                float2 center = 0.2 + 0.6 * float2(Hash21(cell + 11.3), Hash21(cell + 23.9));
                float dotMask = smoothstep(0.16, 0.0, length(inCell - center)) * step(pick, _SparkleDensity);
                float phase = Hash21(cell + 41.1) * 6.2831853;
                float twinkle = 0.5 + 0.5 * sin(_Time.y * _TwinkleSpeed + phase);
                half3 sparkle = dotMask * twinkle * twinkle * density * glow * _SparkleIntensity;

                // _Ambient 는 그늘이 까맣지 않게 하는 바닥 밝기 (발광 아님). color 는 이미 premultiplied.
                half3 color = _IceColor.rgb * (_Ambient + sun) * density + sparkle;
                half alpha = density * _Opacity;
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
}
