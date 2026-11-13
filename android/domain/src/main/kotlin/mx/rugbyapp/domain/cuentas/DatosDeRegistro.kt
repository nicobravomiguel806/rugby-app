package mx.rugbyapp.domain.cuentas

/**
 * C-01 · Lo que la persona escribe en el formulario de registro con correo. `toString()` nunca imprime la contraseña
 * (SP-04 H-7). Espejo en iOS: Domain/Cuentas/DatosDeRegistro.swift.
 */
data class DatosDeRegistro(
    val nombreCompleto: String,
    val correo: String,
    val contrasena: String,
    val aceptoAvisoDePrivacidad: Boolean,
    /** Finalidades secundarias marcadas. Vacío por defecto: las tres casillas desmarcadas (A-1). */
    val finalidadesAceptadas: Set<FinalidadSecundaria> = emptySet(),
) {
    override fun toString() =
        "DatosDeRegistro(nombreCompleto=$nombreCompleto, correo=$correo, contrasena=***, " +
            "aceptoAvisoDePrivacidad=$aceptoAvisoDePrivacidad, finalidadesAceptadas=${finalidadesAceptadas.map { it.valorCrudo }.sorted()})"
}
