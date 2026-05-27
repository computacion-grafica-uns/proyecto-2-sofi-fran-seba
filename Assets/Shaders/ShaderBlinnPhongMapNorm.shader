Shader "Custom/ShaderBlinnPhongNormalMap"
{
    Properties
    {
        _MaterialColor ("Color del Objeto (Albedo)", Color) = (1,1,1,1)
        _MainTex ("Textura Base (Albedo)", 2D) = "white" {}
        _NormalMap ("Normal Map (Bump)", 2D) = "bump" {}
        
        _SpecularColor ("Color del Brillo (Ks)", Color) = (1,1,1,1)
        _Shininess ("Exponente de Brillo (n)", Range(1, 128)) = 32
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
            
            float4 _SpecularColor;
            float _Shininess;
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
                // 1. Leer y normalizar la normal obtenida del Normal Map
                float3 N = normalize(UnpackNormal(tex2D(_NormalMap, i.uv)));

                // 2. Normalizar vectores de entrada interpolados en espacio de tangente
                float3 L = normalize(i.lightDirTangent);
                float3 V = normalize(i.viewDirTangent);
                
                // 3. Vector Medio (H) - Eje central de Blinn-Phong
                float3 H = normalize(L + V);

                // --- 1. COMPONENTE AMBIENTE ---
                float3 albedo = tex2D(_MainTex, i.uv).rgb * _MaterialColor.rgb;
                float3 ambient = 0.1 * albedo;

                // --- 2. COMPONENTE DIFUSA (Lambert con la normal del mapa) ---
                float dotNL = dot(N, L);
                float3 diffuse = max(0.0, dotNL) * albedo;

                // --- 3. COMPONENTE ESPECULAR (Blinn-Phong: N dot H) ---
                // Usamos N dot H en lugar de R dot V
                float NdotH = max(0.0, dot(N, H));
                float spec = pow(NdotH, _Shininess);
                float3 specular = spec * _SpecularColor.rgb;

                // --- FILTRO DEL TERMINADOR SUAVE ---
                // Al igual que en Cook-Torrance, usamos smoothstep para evitar que
                // el brillo especular flote de manera irreal en el lado oscuro del relieve.
                float terminadorMask = smoothstep(0.0, 0.05, dotNL);
                specular *= terminadorMask;

                // --- SUMA FINAL ---
                fixed4 fragColor = 1;
                fragColor.rgb = ambient + diffuse + specular;

                return fragColor;
            }
            ENDCG
        }
    }
}