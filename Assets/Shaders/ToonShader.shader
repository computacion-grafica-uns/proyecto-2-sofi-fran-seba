/*
Shader "Custom/ToonShader"
{
    Properties
    {
        _MainColor ("Base Color (Diffuse)", Color) = (1, 1, 1, 1)
        _ShadowColor ("Shadow Color", Color) = (0.2, 0.2, 0.2, 1) // Color de la zona de sombra
        
        // Propiedades del Toon-Shader
        _Glossiness ("Glossiness (Tamanio Brillo)", Range(0.01, 1.0)) = 0.5
        _ToonThreshold ("Toon Diffuse Threshold", Range(0.0, 1.0)) = 0.3
        _ToonSmoothness ("Toon Smoothness", Range(0.001, 0.5)) = 0.05

        _DirLightDirection ("Directional Light Direction", Vector) = (0, -1, 0, 0)
        _DirLightColor ("Directional Light Color", Color) = (1, 1, 1, 1)
        
        _PointLightPosition ("Point Light Position", Vector) = (0, 2, 0, 1)
        _PointLightColor ("Point Light Color", Color) = (1, 0, 0, 1)
        _LightRange ("Light Range", Float) = 5.0
        
        _SpotLightPosition ("Spot Light Position", Vector) = (0, 3, 0, 1)
        _SpotLightDirection ("Spot Light Direction", Vector) = (0, -1, 0, 0)
        _SpotLightColor ("Spot Light Color", Color) = (0, 0, 1, 1)
        _Apertura ("Apertura (Angulo)", Range(0.0, 90.0)) = 30.0
        _SpotRange ("Spot Range", Float) = 10.0
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct vertexdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float3 normal_w : TEXCOORD0; 
                float3 worldPos : TEXCOORD1; 
            };

            float4 _MainColor;
            float4 _ShadowColor;
            float _Glossiness;
            float _ToonThreshold;
            float _ToonSmoothness;
            
            float4 _DirLightDirection;
            float4 _DirLightColor;
            
            float4 _PointLightPosition;
            float4 _PointLightColor;
            float _LightRange;
            
            float4 _SpotLightPosition;
            float4 _SpotLightDirection;
            float4 _SpotLightColor;
            float _Apertura;
            float _SpotRange;

            v2f vert(vertexdata v)
            {
                v2f output;
                output.position = UnityObjectToClipPos(v.vertex); 
                output.normal_w = UnityObjectToWorldNormal(v.normal); 
                output.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return output;
            }

            // Función encargada de calcular el Toon Shading por cada luz
            float3 ComputeToon(float3 N, float3 L, float3 V, float3 lightColor)
            {
                // 1. Componente Difusa (Lambert clásico)
                float NdotL = dot(N, L);
                
                // Variación Toon usando smoothstep para controlar el escalón de la sombra de forma limpia
                // Si NdotL es mayor al umbral se vuelve 1 (iluminado), si es menor se vuelve 0 (sombra)
                float diffuseIntensity = smoothstep(_ToonThreshold - _ToonSmoothness, _ToonThreshold + _ToonSmoothness, NdotL);
                
                // Interpolamos entre el color de sombra y el color de luz pleno según la intensidad calculada
                float3 diffuseTerm = lerp(_ShadowColor.rgb, lightColor, diffuseIntensity);

                // 2. Componente Especular (Brillo duro de estilo cel-shading)
                float3 H = normalize(V + L);
                float NdotH = max(0.0, dot(N, H));
                
                // El brillo especular solo aparece si la intensidad supera un umbral muy estricto basado en la rugosidad/glosiness
                float specularIntensity = pow(NdotH, _Glossiness * 128.0);
                float specularToon = smoothstep(0.5 - _ToonSmoothness, 0.5 + _ToonSmoothness, specularIntensity);
                float3 specularTerm = specularToon * lightColor;

                // El resultado final para esta luz es la combinación de su sombra/luz plana + su brillo duro
                return (diffuseTerm + specularTerm) * max(0.0, NdotL);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal_w);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // direccional
                float3 L1 = normalize(-_DirLightDirection.xyz);
                float3 lightDirResult = ComputeToon(normal, L1, viewDir, _DirLightColor.rgb);

                // puntual
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                float3 lightPointColor = _PointLightColor.rgb * attenPoint;
                float3 lightPointResult = ComputeToon(normal, L2, viewDir, lightPointColor);

                // spot
                float3 toSpot = _SpotLightPosition.xyz - i.worldPos;
                float distanceSpot = length(toSpot);
                float3 L3 = normalize(toSpot);
                float3 spotDir = normalize(-_SpotLightDirection.xyz);
                
                float cosCurrentAngle = dot(L3, spotDir);
                float cosAperture = cos(radians(_Apertura));

                float3 lightSpotResult = float3(0, 0, 0);
                if (cosCurrentAngle > cosAperture)
                {
                    float attenSpot = max(0.0, 1.0 - (distanceSpot / _SpotRange));
                    float3 lightSpotColor = _SpotLightColor.rgb * attenSpot;
                    lightSpotResult = ComputeToon(normal, L3, viewDir, lightSpotColor);
                }

                // Unificación y modulación con el color de la superficie
                float3 totalRadiance = lightDirResult + lightPointResult + lightSpotResult;
                float3 finalColor = totalRadiance * _MainColor.rgb;

                return float4(finalColor, _MainColor.a);
            }
            ENDCG
        }
    }
}
*/
Shader "Custom/ToonShader"
{
    Properties
    {
        _MainColor ("Base Color (Diffuse)", Color) = (1, 1, 1, 1)
        _ShadowColor ("Shadow Color", Color) = (0.2, 0.2, 0.2, 1) // Color de la zona de sombra
        
        // Propiedades del Toon-Shader
        _Glossiness ("Glossiness (Tamanio Brillo)", Range(0.01, 1.0)) = 0.5
        _ToonThreshold ("Toon Diffuse Threshold", Range(0.0, 1.0)) = 0.3
        _ToonSmoothness ("Toon Smoothness", Range(0.001, 0.5)) = 0.05

        _DirLightDirection ("Directional Light Direction", Vector) = (0, -1, 0, 0)
        _DirLightColor ("Directional Light Color", Color) = (1, 1, 1, 1)
        
        _PointLightPosition ("Point Light Position", Vector) = (0, 2, 0, 1)
        _PointLightColor ("Point Light Color", Color) = (1, 0, 0, 1)
        _LightRange ("Light Range", Float) = 5.0
        
        _SpotLightPosition ("Spot Light Position", Vector) = (0, 3, 0, 1)
        _SpotLightDirection ("Spot Light Direction", Vector) = (0, -1, 0, 0)
        _SpotLightColor ("Spot Light Color", Color) = (0, 0, 1, 1)
        _Apertura ("Apertura (Angulo)", Range(0.0, 90.0)) = 30.0
        _SpotRange ("Spot Range", Float) = 10.0
    }
    
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct vertexdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float3 normal_w : TEXCOORD0; 
                float3 worldPos : TEXCOORD1; 
            };

            float4 _MainColor;
            float4 _ShadowColor;
            float _Glossiness;
            float _ToonThreshold;
            float _ToonSmoothness;
            
            float4 _DirLightDirection;
            float4 _DirLightColor;
            
            float4 _PointLightPosition;
            float4 _PointLightColor;
            float _LightRange;
            
            float4 _SpotLightPosition;
            float4 _SpotLightDirection;
            float4 _SpotLightColor;
            float _Apertura;
            float _SpotRange;

            // 1. Función auxiliar de luminancia (Declarada antes de usarse)
            float luma(float3 color) {
                return dot(color, float3(0.299, 0.587, 0.114));
            }

            // 2. Función encargada de calcular la intensidad Toon pura
            void ComputeToonLighting(float3 N, float3 L, float3 V, float attenuation, out float diffuseToon, out float specularToon)
            {
                float NdotL = dot(N, L);
                
                // Intensidad difusa Toonizada con atenuación de distancia integrada
                float lightIntensity = NdotL * attenuation;
                diffuseToon = smoothstep(_ToonThreshold - _ToonSmoothness, _ToonThreshold + _ToonSmoothness, lightIntensity);
                
                // Componente Especular de corte duro
                float3 H = normalize(V + L);
                float NdotH = max(0.0, dot(N, H));
                float specIntensity = pow(NdotH, _Glossiness * 128.0) * attenuation;
                specularToon = smoothstep(0.5 - _ToonSmoothness, 0.5 + _ToonSmoothness, specIntensity);
            }

            v2f vert(vertexdata v)
            {
                v2f output;
                output.position = UnityObjectToClipPos(v.vertex); 
                output.normal_w = UnityObjectToWorldNormal(v.normal); 
                output.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return output;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal_w);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                float totalDiffuseToon = 0.0;
                float3 totalSpecular = float3(0, 0, 0);

                // --- LUZ DIRECCIONAL ---
                float3 L1 = normalize(-_DirLightDirection.xyz);
                float diff1, spec1;
                ComputeToonLighting(normal, L1, viewDir, 1.0, diff1, spec1);
                float light1Power = luma(_DirLightColor.rgb); 
                totalDiffuseToon += diff1 * light1Power;
                totalSpecular += spec1 * _DirLightColor.rgb;

                // --- LUZ PUNTUAL ---
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                
                float diff2, spec2;
                ComputeToonLighting(normal, L2, viewDir, attenPoint, diff2, spec2);
                float light2Power = luma(_PointLightColor.rgb);
                totalDiffuseToon += diff2 * light2Power;
                totalSpecular += spec2 * _PointLightColor.rgb;

                // --- LUZ SPOT (FOCAL) ---
                float3 toSpot = _SpotLightPosition.xyz - i.worldPos;
                float distanceSpot = length(toSpot);
                float3 L3 = normalize(toSpot);
                float3 spotDir = normalize(-_SpotLightDirection.xyz);
                
                float cosCurrentAngle = dot(L3, spotDir);
                float cosAperture = cos(radians(_Apertura));

                if (cosCurrentAngle > cosAperture)
                {
                    float attenSpot = max(0.0, 1.0 - (distanceSpot / _SpotRange));
                    float diff3, spec3;
                    ComputeToonLighting(normal, L3, viewDir, attenSpot, diff3, spec3);
                    float light3Power = luma(_SpotLightColor.rgb);
                    totalDiffuseToon += diff3 * light3Power;
                    totalSpecular += spec3 * _SpotLightColor.rgb;
                }

                // Clampeamos la acumulación difusa para evitar sobresaturar el lerp
                totalDiffuseToon = saturate(totalDiffuseToon);

                // Mezcla final: Interpolamos la sombra con el color base usando la intensidad toonizada
                float3 diffuseColor = lerp(_ShadowColor.rgb, _MainColor.rgb, totalDiffuseToon);
                
                // Sumamos el brillo especular acumulado
                float3 finalColor = diffuseColor + totalSpecular;

                return float4(finalColor, _MainColor.a);
            }
            ENDCG
        }
    }
}