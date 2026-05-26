Shader "Custom/ShaderCookTorrance"
{
    Properties
    {
        _MainColor ("Base Color (Diffuse)", Color) = (1, 1, 1, 1)
        
        // Propiedades de Cook-Torrance
        _Roughness ("Roughness (rp)", Range(0.0, 1.0)) = 0.5
        _F0 ("Fresnel Reflectance (F0)", Color) = (0.04, 0.04, 0.04, 1) // 0.04 para pl�stico/vidrio, valores m�s altos (ej. oro, cobre) para metales
        _RhoD ("Diffuse Coefficient (rho_d)", Range(0.0, 1.0)) = 0.5

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
            float _Roughness;
            float4 _F0;
            float _RhoD;
            
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



            // GGX (D)
            float NDF_GGX(float NdotH, float alpha)
            {
                float alpha2 = alpha * alpha;
                float denom = (NdotH * NdotH * (alpha2 - 1.0) + 1.0);
                return alpha2 / (3.14159265 * denom * denom);
            }

            //  G1
            float GeometrySchlickGGX(float NdotV, float k)
            {
                return NdotV / (NdotV * (1.0 - k) + k);
            }

            // G
            float GeometrySmith(float NdotV, float NdotL, float alpha)
            {
                float k = alpha / 2.0;
                float g1_v = GeometrySchlickGGX(NdotV, k);
                float g1_l = GeometrySchlickGGX(NdotL, k);
                return g1_v * g1_l;
            }

            // Reflectancia, Schlick (F)
            float3 FresnelSchlick(float VdotH, float3 F0)
            {
                return F0 + (1.0 - F0) * pow(max(0.0, 1.0 - VdotH), 5.0);
            }

            //  BRDF de Cook-Torrance por cada luz
            float3 ComputeCookTorrance(float3 N, float3 L, float3 V, float3 lightColor, float alpha, float3 F0, float rhoD)
            {
                float3 H = normalize(V + L);

                // Productos escalares para BRDF
                float NdotL = max(0.001, dot(N, L));
                float NdotV = max(0.001, dot(N, V));
                float NdotH = max(0.001, dot(N, H));
                float VdotH = max(0.001, dot(V, H));

                // Componentes de la BRDF
                float D = NDF_GGX(NdotH, alpha);
                float G = GeometrySmith(NdotV, NdotL, alpha);
                float3 F = FresnelSchlick(VdotH, F0);

                // T�rmino Especular (f_s)
                float3 specularNumerator = D * G * F;
                float specularDenominator = 4.0 * NdotL * NdotV;
                float3 f_s = specularNumerator / max(0.001, specularDenominator);

                // T�rmino Difuso (f_d)
                float3 f_d = rhoD / 3.14159265;

                // El resultado final de la BRDF para esta luz se multiplica por la irradiancia (NdotL * Color)
                return (f_d + f_s) * lightColor * NdotL;
            }

            //frag shader
            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal_w);
                
                // Vector de visi�n hacia la c�mara en World Space
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                //alpha = rp^2
                float alpha = _Roughness * _Roughness;
                float3 F0 = _F0.rgb;

                // direccional
                float3 L1 = normalize(-_DirLightDirection.xyz);
                float3 lightDirResult = ComputeCookTorrance(normal, L1, viewDir, _DirLightColor.rgb, alpha, F0, _RhoD);

                // puntual
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                float3 lightPointColor = _PointLightColor.rgb * attenPoint;
                float3 lightPointResult = ComputeCookTorrance(normal, L2, viewDir, lightPointColor, alpha, F0, _RhoD);

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
                    lightSpotResult = ComputeCookTorrance(normal, L3, viewDir, lightSpotColor, alpha, F0, _RhoD);
                }

                // Unificaci�n y modulaci�n con el color de la superficie
                float3 totalRadiance = lightDirResult + lightPointResult + lightSpotResult;
                float3 finalColor = totalRadiance * _MainColor.rgb;

                return float4(finalColor, _MainColor.a);
            }
            ENDCG
        }
    }
}