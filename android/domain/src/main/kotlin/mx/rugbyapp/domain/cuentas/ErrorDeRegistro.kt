package mx.rugbyapp.domain.cuentas

/**
 * C-01 · Errores del registro con correo. Los cuatro primeros son de validación (Domain); los demás los traduce Data.
 * No hay `CorreoYaRegistrado`: un correo existente recibe el mismo resultado que uno nuevo (P-7, AT-11).
 * Espejo en iOS: Domain/Cuentas/ErrorDeRegistro.swift.
 */
sealed class ErrorDeRegistro : Exception() {
    data object NombreInvalido : ErrorDeRegistro()
    data object CorreoInvalido : ErrorDeRegistro()
    data object ContrasenaCorta : ErrorDeRegistro()
    data object AvisoNoAceptado : ErrorDeRegistro()
    /** El enlace de verificación no sirve: vencido, ya usado o abierto en otro teléfono (ADR 0008). */
    data object EnlaceInvalido : ErrorDeRegistro()
    data object DemasiadosIntentos : ErrorDeRegistro()
    data object SinConexion : ErrorDeRegistro()
    data object Desconocido : ErrorDeRegistro()
}

/** Todos los errores de validación del formulario, en orden fijo: nombre, correo, contraseña, aviso (CP-160f). */
class ErroresDeValidacion(val errores: List<ErrorDeRegistro>) : Exception() {
    override fun equals(other: Any?) = other is ErroresDeValidacion && other.errores == errores
    override fun hashCode() = errores.hashCode()
    override fun toString() = "ErroresDeValidacion($errores)"
}
