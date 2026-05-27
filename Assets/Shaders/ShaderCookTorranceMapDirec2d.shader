Shader "Custom/ShaderCookTorranceMapeo2D"
{
    Properties
    {
        _MaterialColor ("Color de Tinte", Color) = (1,1,1,1)
        _MainTex ("Textura Base (Albedo 2D)", 2D) = "white" {}
        
        _F0 ("Reflectancia Base (Fresnel F0)", Range(0.0, 1.0)) = 0.04
        _Roughness ("Rugosidad (Alpha)", Range(0.01, 1.0)) = 0.5
        
        _LightPos ("Posición de la Luz", Vector) = (0, 3, 0, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float4 _MaterialColor;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            float _F0;
            float _Roughness;
            float4 _LightPos;

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 normalWorld : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD3;
            };

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                // Volvemos a pasar normales y posición al espacio del mundo directo
                o.normalWorld = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                // Vectores en World Space (superficie lisa de la geometría)
                float3 N = normalize(i.normalWorld);
                float3 L = normalize(_LightPos.xyz - i.worldPos);
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);
                
                // Vector Medio (H)
                float3 H = normalize(L + V);

                // Productos punto protegidos para evitar división por cero en los bordes
                float dotNL = dot(N, L);
                float NdotL = max(0.0001, dotNL);
                float NdotV = max(0.0001, dot(N, V));
                float NdotH = max(0.0, dot(N, H));
                float HdotV = max(0.0, dot(H, V));

                // --- Ecuación D (GGX) ---
                float alpha2 = _Roughness * _Roughness;
                float denomD = (NdotH * NdotH) * (alpha2 - 1.0) + 1.0;
                float D = alpha2 / (3.14159265 * denomD * denomD);

                // --- Ecuación F (Schlick) ---
                float F = _F0 + (1.0 - _F0) * pow(1.0 - HdotV, 5.0);

                // --- Ecuación G (Schlick-GGX / Smith) ---
                float k = _Roughness / 2.0;
                float G1_L = NdotL / (NdotL * (1.0 - k) + k);
                float G1_V = NdotV / (NdotV * (1.0 - k) + k);
                float G = G1_L * G1_V; 
               
                // --- BRILLO ESPECULAR COOK-TORRANCE ---
                float specularTerm = (D * F * G) / (4.0 * NdotL * NdotV);
                float3 specular = specularTerm * float3(1, 1, 1);

                // --- COMPONENTE DIFUSA CON TEXTURA 2D ---
                // Leemos el color de la imagen usando las UVs interpoladas
                float3 texColor = tex2D(_MainTex, i.uv).rgb;
                float3 albedoColor = texColor * _MaterialColor.rgb;
                
                float realLambert = max(0.0, dotNL);
                float3 diffuse = realLambert * albedoColor;

                // --- FILTRO DEL TERMINADOR SUAVE ---
                float terminadorMask = smoothstep(0.0, 0.05, dotNL);
                specular *= terminadorMask;

                // --- SUMA TOTAL ---
                fixed4 fragColor = 1;
                fragColor.rgb = diffuse + specular;

                return fragColor;
            }
            ENDCG
        }
    }
}