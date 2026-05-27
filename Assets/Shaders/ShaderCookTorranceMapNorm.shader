Shader "Custom/ShaderCookTorranceNormalMap"
{
    Properties
    {
        _MaterialColor ("Color del Objeto (Albedo)", Color) = (1,1,1,1)
        _MainTex ("Textura Base (Albedo)", 2D) = "white" {}
        _NormalMap ("Normal Map (Bump)", 2D) = "bump" {}
        
        _F0 ("Reflectancia Base (Fresnel F0)", Range(0.0, 1.0)) = 0.04
        _Roughness ("Rugosidad (Alpha)", Range(0.01, 1.0)) = 0.5
        
        _LightPos ("Posición de la Luz (World Space)", Vector) = (0, 3, 0, 1)
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

            // Variables del material
            float4 _MaterialColor;
            sampler2D _MainTex;
            sampler2D _NormalMap;
            float4 _MainTex_ST; // Necesario para el escalado de UVs
            
            float _F0;
            float _Roughness;
            float4 _LightPos;

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT; // Trae la dirección de la tangente y el signo
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                // Mandamos los vectores ya transformados al Espacio de Tangente
                float3 lightDirTangent : TEXCOORD1;
                float3 viewDirTangent : TEXCOORD3;
            };

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // 1. Calculamos la posición del vértice en el mundo
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                // 2. Reconstruimos los tres ejes del espacio TBN en World Space
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                // El Bitangente es perpendicular a los otros dos
                float3 worldBitangent = cross(worldNormal, worldTangent) * v.tangent.w;

                // 3. Creamos la matriz TBN (de Mundo a Tangente)
                // En HLSL, multiplicar un vector por filas de una matriz es lo mismo que rotarlo
                float3x3 worldToTangentSpace = float3x3(worldTangent, worldBitangent, worldNormal);

                // 4. Calculamos los vectores originales en World Space
                float3 worldL = _LightPos.xyz - worldPos; // Vector hacia la luz sin normalizar (para distancia)
                float3 worldV = _WorldSpaceCameraPos - worldPos; // Vector hacia la cámara

                // 5. Los transformamos al espacio de la textura usando la matriz TBN
                o.lightDirTangent = mul(worldToTangentSpace, worldL);
                o.viewDirTangent = mul(worldToTangentSpace, worldV);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                // 1. LEER EL NORMAL MAP
                // UnpackNormal toma el color de la textura y reconstruye el vector corregido en rango [-1, 1]
                float3 N = UnpackNormal(tex2D(_NormalMap, i.uv));
                N = normalize(N); // Aseguramos que la normal de la textura esté normalizada

                // 2. Normalizamos los vectores que vienen del vertex interpolados
                float3 L = normalize(i.lightDirTangent);
                float3 V = normalize(i.viewDirTangent);
                
                // Vector Medio (H) en espacio de tangente
                float3 H = normalize(L + V);

                // 3. Productos punto protegidos para las funciones D, F, G
                float dotNL = dot(N, L); // Guardamos el puro para el terminador
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

                // --- Ecuación G (Schlick-GGX / Smith corregido) ---
                float k = _Roughness / 2.0;
                float G1_L = NdotL / (NdotL * (1.0 - k) + k);
                float G1_V = NdotV / (NdotV * (1.0 - k) + k);
                float G = G1_L * G1_V; 
               
                // --- BRILLO ESPECULAR COOK-TORRANCE ---
                float specularTerm = (D * F * G) / (4.0 * NdotL * NdotV);
                float3 specular = specularTerm * float3(1, 1, 1);

                // --- COMPONENTE DIFUSA (Albedo + Lambert) ---
                float3 albedoColor = tex2D(_MainTex, i.uv).rgb * _MaterialColor.rgb;
                float realLambert = max(0.0, dotNL);
                float3 diffuse = realLambert * albedoColor;

                // --- FILTRO DEL TERMINADOR SUAVE ---
                // Usamos el smoothstep para que en las micro-sombras del normal map
                // el specular no genere tajos raros y se apague de manera prolija.
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