Shader "Custom/ToonShaderMapNorm"
{
    Properties
    {
        _MaterialColor ("Color del Objeto (Albedo)", Color) = (1,1,1,1)
        _MainTex ("Textura Base (Albedo)", 2D) = "white" {}
        _NormalMap ("Normal Map (Bump)", 2D) = "bump" {}
        
        _Glossiness ("Tamaño del Brillo Toon", Range(0.01, 1.0)) = 0.3
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

            float4 _MaterialColor;
            sampler2D _MainTex;
            sampler2D _NormalMap;
            float4 _MainTex_ST;
            
            float _Glossiness;
            float4 _LightPos;

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 lightDirTangent : TEXCOORD1;
                float3 viewDirTangent : TEXCOORD3;
            };

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                float3 worldBitangent = cross(worldNormal, worldTangent) * v.tangent.w;

                float3x3 worldToTangentSpace = float3x3(worldTangent, worldBitangent, worldNormal);

                float3 worldL = _LightPos.xyz - worldPos;
                float3 worldV = _WorldSpaceCameraPos - worldPos;

                o.lightDirTangent = mul(worldToTangentSpace, worldL);
                o.viewDirTangent = mul(worldToTangentSpace, worldV);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                // 1. Leer la normal del mapa de relieve
                float3 N = normalize(UnpackNormal(tex2D(_NormalMap, i.uv)));

                // 2. Normalizar vectores en espacio de tangente
                float3 L = normalize(i.lightDirTangent);
                float3 V = normalize(i.viewDirTangent);

                // --- DIFUSA ESTILO TOON (Cortes discretos) ---
                float NdotL = dot(N, L);
                float toonLambert = 0.2; // Color de sombra base por defecto

                // Segmentamos la luz en escalones duros
                if (NdotL > 0.6) {
                    toonLambert = 1.0; // Luz plena
                } else if (NdotL > 0.2) {
                    toonLambert = 0.6; // Tono medio
                }

                // --- ESPECULAR ESTILO TOON (Brillo seco de historieta) ---
                float3 R = reflect(-L, N);
                float RdotV = max(0.0, dot(R, V));
                
                // Usamos una potencia básica de Phong
                float spec = pow(RdotV, 32.0); 
                float toonSpecular = 0.0;

                // Si el brillo pasa el umbral de glossiness, se vuelve un manchón blanco puro (1.0)
                if (spec > (1.0 - _Glossiness)) {
                    toonSpecular = 1.0;
                }

                // Mezclamos con la textura de Albedo
                float3 albedo = tex2D(_MainTex, i.uv).rgb * _MaterialColor.rgb;
                
                // --- COMPOSICIÓN FINAL ---
                fixed4 fragColor = 1;
                // Sumamos el manchón especular arriba del color escalonado
                fragColor.rgb = (albedo * toonLambert) + (toonSpecular * float3(1,1,1));

                return fragColor;
            }
            ENDCG
        }
    }
}