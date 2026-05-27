Shader "Custom/ToonShaderMapeoDirec2d"
{
    Properties
    {
        _MaterialColor ("Color de Tinte", Color) = (1,1,1,1)
        _MainTex ("Textura Base (Albedo 2D)", 2D) = "white" {}
        
        _Glossiness ("Tamaño del Brillo Toon", Range(0.01, 1.0)) = 0.3
        _LightPos ("Posición de la Luz", Vector) = (0, 3, 0, 1)
        
        // NUEVO: Parámetro para controlar el ancho de la línea negra exterior
        _OutlineThickness ("Grosor del Borde Negro", Range(0.0, 0.5)) = 0.25
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
            
            float _Glossiness;
            float4 _LightPos;
            float _OutlineThickness; // Variable global del grosor

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
                
                o.normalWorld = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                // Vectores en World Space
                float3 N = normalize(i.normalWorld);
                float3 L = normalize(_LightPos.xyz - i.worldPos);
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                // --- 1. DETECCIÓN DEL BORDE EXTERIOR (N dot V) ---
                float NdotV = max(0.0, dot(N, V));
                
                // Si NdotV es menor al umbral fijado, creamos una máscara de 0.0 (negro), si no, 1.0 (normal)
                float outlineMask = 1.0;
                if (NdotV < _OutlineThickness) {
                    outlineMask = 0.0;
                }

                // --- 2. DIFUSA ESTILO TOON (Escalones duros) ---
                float NdotL = dot(N, L);
                float toonLambert = 0.2; 

                if (NdotL > 0.6) {
                    toonLambert = 1.0; 
                } else if (NdotL > 0.2) {
                    toonLambert = 0.6; 
                }

                // --- 3. ESPECULAR ESTILO TOON (Brillo seco) ---
                float3 R = reflect(-L, N);
                float RdotV = max(0.0, dot(R, V));
                
                float spec = pow(RdotV, 32.0); 
                float toonSpecular = 0.0;

                if (spec > (1.0 - _Glossiness)) {
                    toonSpecular = 1.0;
                }

                // --- 4. LEER TEXTURA 2D ---
                float3 texColor = tex2D(_MainTex, i.uv).rgb;
                float3 albedo = texColor * _MaterialColor.rgb;
                
                // --- COMPOSICIÓN FINAL ---
                fixed4 fragColor = 1;
                float3 colorIluminado = (albedo * toonLambert) + (toonSpecular * float3(1,1,1));
                
                // Multiplicamos todo el color por la máscara del contorno.
                // Si outlineMask es 0.0, el píxel se tiñe de negro puro instantáneamente.
                fragColor.rgb = colorIluminado * outlineMask;

                return fragColor;
            }
            ENDCG
        }
    }
}