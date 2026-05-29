using UnityEngine;

public class ControlCamaraOrbital : MonoBehaviour
{
    [Header("Configuración de Objetivos")]
    [SerializeField] private Transform[] teteras;
    private int indiceActual = 0;
    private bool vistaGeneralActiva = false;

    [Header("Controles de Orbita y Zoom")]
    [SerializeField] private float distancia = 5.0f;
    [SerializeField] private float velocidadZoom = 2.0f;
    [SerializeField] private float distanciaMinima = 1.5f;
    [SerializeField] private float distanciaMaxima = 35.0f;

    [SerializeField] private float velocidadRotacion = 5.0f;
    private float anguloX = 0.0f;
    private float anguloY = 20.0f;

    [Header("Ajuste de Vista General (Tecla F)")]
    [Tooltip("Qué tan atrás se para la cámara para ver todo el estante")]
    [SerializeField] private float distanciaVistaGeneral = 16.0f;
    [Tooltip("Inclinación vertical de la cámara en la vista general")]
    [SerializeField] private float inclinacionVistaGeneral = 10.0f;
    [Tooltip("Rotación en el eje Y para mirar de frente si el estante está rotado en el mapa")]
    [SerializeField] private float rotacionYVistaGeneral = -90.0f; // <-- NUEVO: Ajustalo según tu eje

    [Header("Suavizado")]
    [SerializeField] private float velocidadLerp = 5.0f;

    void Start()
    {
        // Forzamos que la órbita inicial de la tetera arranque con el mismo desfasaje de tu eje
        anguloX = rotacionYVistaGeneral;
        anguloY = 12.0f;

        if (teteras.Length == 0)
        {
            Debug.LogWarning("Por favor, asigná las teteras en el Inspector.");
        }
    }

    void Update()
    {
        // 1. Tecla F: Alternar Vista General automática
        if (Input.GetKeyDown(KeyCode.F))
        {
            vistaGeneralActiva = !vistaGeneralActiva;
            Debug.Log(vistaGeneralActiva ? "Vista General Activa" : "Volviendo a enfoque individual");
        }

        // 2. Detección de TAB / SHIFT+TAB
        if (!vistaGeneralActiva && Input.GetKeyDown(KeyCode.Tab))
        {
            if (Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift))
            {
                indiceActual--;
                if (indiceActual < 0) indiceActual = teteras.Length - 1;
            }
            else
            {
                indiceActual++;
                if (indiceActual >= teteras.Length) indiceActual = 0;
            }
        }

        // 3. Controles de Mouse en modo individual
        if (!vistaGeneralActiva && teteras.Length > 0 && teteras[indiceActual] != null)
        {
            float entradaZoom = Input.GetAxis("Mouse ScrollWheel");
            distancia -= entradaZoom * velocidadZoom;
            distancia = Mathf.Clamp(distancia, distanciaMinima, distanciaMaxima);

            if (Input.GetMouseButton(1))
            {
                anguloX += Input.GetAxis("Mouse X") * velocidadRotacion;
                anguloY -= Input.GetAxis("Mouse Y") * velocidadRotacion;
                anguloY = Mathf.Clamp(anguloY, -20f, 80f);
            }
        }
    }

    void LateUpdate()
    {
        if (teteras.Length == 0) return;

        Vector3 targetPos = Vector3.zero;
        Quaternion targetRot = Quaternion.identity;

        if (vistaGeneralActiva)
        {
            // Calculamos el centro geométrico real de las teteras
            Vector3 centroAcumulado = Vector3.zero;
            int contadorValidas = 0;

            for (int k = 0; k < teteras.Length; k++)
            {
                if (teteras[k] != null)
                {
                    centroAcumulado += teteras[k].position;
                    contadorValidas++;
                }
            }

            Vector3 centroReal = (contadorValidas > 0) ? (centroAcumulado / contadorValidas) : Vector3.zero;

            // CORRECCIÓN: Aplicamos la rotación en Y que configuramos para tu eje X
            targetRot = Quaternion.Euler(inclinacionVistaGeneral, rotacionYVistaGeneral, 0f);

            // Nos posicionamos hacia atrás en base a la nueva rotación del estante
            targetPos = centroReal - (targetRot * Vector3.forward * distanciaVistaGeneral);
        }
        else
        {
            // Modo Órbita Individual
            if (teteras[indiceActual] == null) return;

            targetRot = Quaternion.Euler(anguloY, anguloX, 0);
            targetPos = teteras[indiceActual].position - (targetRot * Vector3.forward * distancia);
        }

        // Interpolación fluida
        transform.position = Vector3.Lerp(transform.position, targetPos, Time.deltaTime * velocidadLerp);
        transform.rotation = Quaternion.Slerp(transform.rotation, targetRot, Time.deltaTime * velocidadLerp);
    }
}