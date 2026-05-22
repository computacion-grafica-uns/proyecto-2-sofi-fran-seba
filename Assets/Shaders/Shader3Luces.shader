Shader "Custom/Shader3Luces"
{
   
    Properties
    {
        _MainColor ("Base Color", Color) = (1, 1, 1, 1)
        
        // direccional
        _DirLightDirection ("Directional Light Direction", Vector) = (0, -1, 0, 0)
        _DirLightColor ("Directional Light Color", Color) = (1, 1, 1, 1)
        
        // puntual
        _PointLightPosition ("Point Light Position", Vector) = (0, 2, 0, 1)
        _PointLightColor ("Point Light Color", Color) = (1, 0, 0, 1)
        _LightRange ("Light Range", Float) = 5.0
        
        // spot
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

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal_w);

                // calculo direccional
                float3 L1 = normalize(-_DirLightDirection.xyz);
                float NdotL1 = max(0.0, dot(normal, L1));
                float3 resultDirectionalLight = NdotL1 * _DirLightColor.rgb;

                // calculo puntual
                float3 toPoint = _PointLightPosition.xyz - i.worldPos;
                float distancePoint = length(toPoint);
                float3 L2 = normalize(toPoint);
                float NdotL2 = max(0.0, dot(normal, L2));
                
                float attenPoint = max(0.0, 1.0 - (distancePoint / _LightRange));
                float3 resultPointLight = NdotL2 * _PointLightColor.rgb * attenPoint;

                //calculo spot
                float3 toSpot = _SpotLightPosition.xyz - i.worldPos;
                float distanceSpot = length(toSpot);
                float3 L3 = normalize(toSpot);

                float3 spotDir = normalize(-_SpotLightDirection.xyz);
                float cosCurrentAngle = dot(L3, spotDir);
                float cosAperture = cos(radians(_Apertura));

                float3 resultSpotLight = float3(0, 0, 0);

                if (cosCurrentAngle > cosAperture)
                {
                    float NdotL3 = max(0.0, dot(normal, L3));
                    float attenSpot = max(0.0, 1.0 - (distanceSpot / _SpotRange));
                    resultSpotLight = NdotL3 * _SpotLightColor.rgb * attenSpot;
                }

                // unificacion
               // fragColor.rgb = (resultDirectional + resultPoint + resultSpot) * materialColor
                float3 totalLight = resultDirectionalLight + resultPointLight + resultSpotLight;
                float3 finalColor = totalLight * _MainColor.rgb;

                return float4(finalColor, _MainColor.a);
            }
            ENDCG
        }
    }
}