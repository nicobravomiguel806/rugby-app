package mx.rugbyapp.domain.cuentas

/**
 * C-02 · Errores de la recuperación de contraseña. `CorreoInvalido` y `ContrasenaCorta` los valida Domain; los demás
 * los traduce Data. No hay «correo no registrado»: la respuesta es neutra (AT-11).
 * Espejo en iOS: Domain/Cuentas/ErrorDeRecuperacion.swift.
 */
sealed class ErrorDeRecuperacion : Exception() {
    data object CorreoInvalido : ErrorDeRecuperacion()
    data object ContrasenaCorta : ErrorDeRecuperacion()
    /** El enlace de recuperación no sirve: vencido, ya usado o abierto en otro teléfono (ADR 0008). */
    data object EnlaceInvalido : ErrorDeRecuperacion()
    data object DemasiadosIntentos : ErrorDeRecuperacion()
    data object SinConexion : ErrorDeRecuperacion()
    data object Desconocido : ErrorDeRecuperacion()
}

/** Único resultado de pedir la recuperación, exista o no la cuenta (AT-11). */
sealed class ResultadoDeRecuperacion {
    data class EnlaceEnviado(val correo: String) : ResultadoDeRecuperacion()
}
