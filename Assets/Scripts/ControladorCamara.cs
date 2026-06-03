using UnityEngine;

public class ControlCamaraCompleto : MonoBehaviour
{
    public enum ModoCamara { OrbitaCerca, OrbitaLejos, PrimeraPersona }

    [Header("Estado de la Cámara")]
    [SerializeField] private ModoCamara modoActual = ModoCamara.OrbitaLejos;
    private Camera componenteCamara;

    [Header("Configuración de Objetivos (TAB)")]
    [SerializeField] private Transform[] objetivos;
    private int indiceActual = 0;

    [Header("Controles Generales")]
    [SerializeField] private float velocidadZoom = 4.0f;
    [SerializeField] private float velocidadRotacion = 5.0f;
    [SerializeField] private float velocidadLerp = 5.0f;

    [Header("Modo Cerca (Objetivos)")]
    [SerializeField] private float distanciaCerca = 4.0f;
    [SerializeField] private float distMinCerca = 1.5f;
    [SerializeField] private float distMaxCerca = 10.0f;
    [SerializeField] private float fovCerca = 60.0f;

    [Header("Modo Lejos (Vista General F)")]
    [SerializeField] private float distanciaLejos = 16.0f;
    [SerializeField] private float distMinLejos = 10.0f;
    [SerializeField] private float distMaxLejos = 40.0f;
    [SerializeField] private float fovLejos = 40.0f;
    [SerializeField] private float rotacionYVistaGeneral = -90.0f;

    [Header("Modo Primera Persona (Tecla P + WASD)")]
    [SerializeField] private float velocidadCaminar = 5.0f;
    [SerializeField] private float sensibilidadMouseFP = 2.0f;
    [SerializeField] private float fovPrimeraPersona = 65.0f;
    [Tooltip("Velocidad para subir con Espacio o bajar con Ctrl")]
    [SerializeField] private float velocidadEjeY = 4.0f; // <-- NUEVO

    private float anguloX_Cerca = 0.0f;
    private float anguloY_Cerca = 12.0f;
    private float anguloX_Lejos = 0.0f;
    private float anguloY_Lejos = 15.0f;

    private float fpRotacionX = 0.0f;
    private float fpRotacionY = 0.0f;

    void Start()
    {
        componenteCamara = GetComponent<Camera>();
        anguloX_Cerca = rotacionYVistaGeneral;
        anguloX_Lejos = rotacionYVistaGeneral;
        ActualizarEstadoCursor();
    }

    void Update()
    {
        // Tecla F: Alterna entre Órbita de Cerca (Individual) u Órbita de Lejos (General)
        if (Input.GetKeyDown(KeyCode.F))
        {
            if (modoActual == ModoCamara.OrbitaLejos)
                modoActual = ModoCamara.OrbitaCerca;
            else
                modoActual = ModoCamara.OrbitaLejos;

            ActualizarEstadoCursor();
        }

        // Tecla P: Entra/Sal de Primera Persona libre
        if (Input.GetKeyDown(KeyCode.P))
        {
            if (modoActual != ModoCamara.PrimeraPersona)
            {
                fpRotacionX = transform.eulerAngles.y;
                fpRotacionY = transform.eulerAngles.x;
                modoActual = ModoCamara.PrimeraPersona;
            }
            else
            {
                modoActual = ModoCamara.OrbitaCerca;
            }

            ActualizarEstadoCursor();
        }

        // Navegación de objetivos con TAB / SHIFT+TAB
        if (modoActual == ModoCamara.OrbitaCerca && Input.GetKeyDown(KeyCode.Tab))
        {
            Debug.Log("hola pepe");
            if (Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift))
            {
                indiceActual--;
                if (indiceActual < 0) indiceActual = objetivos.Length - 1;
            }
            else
            {
                indiceActual++;
                if (indiceActual >= objetivos.Length) indiceActual = 0;
            }
        }

        // Captura de Inputs según el modo activo
        float entradaZoom = Input.GetAxis("Mouse ScrollWheel");

        if (modoActual == ModoCamara.PrimeraPersona)
        {
            fpRotacionX += Input.GetAxis("Mouse X") * sensibilidadMouseFP;
            fpRotacionY -= Input.GetAxis("Mouse Y") * sensibilidadMouseFP;
            fpRotacionY = Mathf.Clamp(fpRotacionY, -85f, 85f);

            if (Input.GetKeyDown(KeyCode.Escape))
            {
                Cursor.lockState = (Cursor.lockState == CursorLockMode.Locked) ? CursorLockMode.None : CursorLockMode.Locked;
                Cursor.visible = (Cursor.lockState != CursorLockMode.Locked);
            }
        }
        else if (modoActual == ModoCamara.OrbitaLejos)
        {
            distanciaLejos -= entradaZoom * velocidadZoom;
            distanciaLejos = Mathf.Clamp(distanciaLejos, distMinLejos, distMaxLejos);

            if (Input.GetMouseButton(1))
            {
                anguloX_Lejos += Input.GetAxis("Mouse X") * velocidadRotacion;
                anguloY_Lejos -= Input.GetAxis("Mouse Y") * velocidadRotacion;
                anguloY_Lejos = Mathf.Clamp(anguloY_Lejos, -10f, 60f);
            }
        }
        else if (modoActual == ModoCamara.OrbitaCerca)
        {
            distanciaCerca -= entradaZoom * velocidadZoom;
            distanciaCerca = Mathf.Clamp(distanciaCerca, distMinCerca, distMaxCerca);

            if (Input.GetMouseButton(1))
            {
                anguloX_Cerca += Input.GetAxis("Mouse X") * velocidadRotacion;
                anguloY_Cerca -= Input.GetAxis("Mouse Y") * velocidadRotacion;
                anguloY_Cerca = Mathf.Clamp(anguloY_Cerca, -20f, 80f);
            }
        }
    }

    void LateUpdate()
    {
        // CONTROL CLAVE: Si el arreglo está vacío o no asignado, salimos para que no tire error NaN
        if (objetivos == null || objetivos.Length == 0) return;

        Vector3 targetPos = transform.position;
        Quaternion targetRot = transform.rotation;
        float targetFOV = fovCerca;

        if (modoActual == ModoCamara.PrimeraPersona)
        {
            targetRot = Quaternion.Euler(fpRotacionY, fpRotacionX, 0.0f);
            transform.rotation = targetRot;

            // Desplazamiento WASD plano
            float moverX = Input.GetAxis("Horizontal");
            float moverZ = Input.GetAxis("Vertical");

            Vector3 adelante = transform.forward;
            Vector3 derecha = transform.right;
            adelante.y = 0f;
            derecha.y = 0f;
            adelante.Normalize();
            derecha.Normalize();

            Vector3 direccionHoriz = (adelante * moverZ) + (derecha * moverX);

            // --- NUEVO: Cálculo del movimiento vertical libre (Eje Y) ---
            float moverY = 0f;
            if (Input.GetKey(KeyCode.Space))
            {
                moverY = 1f; // Ascender
            }
            else if (Input.GetKey(KeyCode.LeftControl))
            {
                moverY = -1f; // Descender
            }

            // Aplicamos ambos movimientos combinados
            transform.position += direccionHoriz * velocidadCaminar * Time.deltaTime;
            transform.position += Vector3.up * moverY * velocidadEjeY * Time.deltaTime;

            if (componenteCamara != null) componenteCamara.fieldOfView = fovPrimeraPersona;
            return;
        }

        if (modoActual == ModoCamara.OrbitaLejos)
        {
            Vector3 centroAcumulado = Vector3.zero;
            for (int k = 0; k < objetivos.Length; k++)
            {
                centroAcumulado += objetivos[k].position;
            }
            Vector3 centroReal = centroAcumulado / objetivos.Length;

            targetRot = Quaternion.Euler(anguloY_Lejos, anguloX_Lejos, 0f);
            targetPos = centroReal - (targetRot * Vector3.forward * distanciaLejos);
            targetFOV = fovLejos;
        }
        else if (modoActual == ModoCamara.OrbitaCerca)
        {
            targetRot = Quaternion.Euler(anguloY_Cerca, anguloX_Cerca, 0f);
            targetPos = objetivos[indiceActual].position - (targetRot * Vector3.forward * distanciaCerca);
            targetFOV = fovCerca;
        }

        transform.position = Vector3.Lerp(transform.position, targetPos, Time.deltaTime * velocidadLerp);
        transform.rotation = Quaternion.Slerp(transform.rotation, targetRot, Time.deltaTime * velocidadLerp);

        if (componenteCamara != null)
        {
            componenteCamara.fieldOfView = Mathf.Lerp(componenteCamara.fieldOfView, targetFOV, Time.deltaTime * velocidadLerp);
        }
    }

    private void ActualizarEstadoCursor()
    {
        if (modoActual == ModoCamara.PrimeraPersona)
        {
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;
        }
        else
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }
    }
}