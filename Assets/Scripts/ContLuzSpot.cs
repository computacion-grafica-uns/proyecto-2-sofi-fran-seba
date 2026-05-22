using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ControladorLuzSpot : MonoBehaviour
{
    public Material[] Materiales_De_La_Escena_Luz_Spot ;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        foreach (Material mat in Materiales_De_La_Escena_Luz_Spot)
        {
            mat.SetVector("_SpotLightPosition", transform.position);
            mat.SetVector("_SpotLightDirection", transform.up); 
        }
    }
}
