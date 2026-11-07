package mx.rugbyapp.domain.cuentas

/**
 * C-01 · Reglas de «Datos del registro con correo» (domain-model.md §1, P-8). Puras.
 * Las longitudes se cuentan en puntos de código Unicode para dar lo mismo en Swift y en Kotlin.
 * Espejo en iOS: Domain/Cuentas/ValidadorDeRegistro.swift.
 */
class ValidadorDeRegistro {
    /** Todos los errores a la vez, en orden: nombre, correo, contraseña, aviso. Vacío si los datos son válidos. */
    fun validar(datos: DatosDeRegistro): List<ErrorDeRegistro> = buildList {
        val nombre = recortar(datos.nombreCompleto).let { it.codePointCount(0, it.length) }
        if (nombre < LONGITUD_MINIMA_DEL_NOMBRE || nombre > LONGITUD_MAXIMA_DEL_NOMBRE) add(ErrorDeRegistro.NombreInvalido)
        if (!esCorreoValido(normalizarCorreo(datos.correo))) add(ErrorDeRegistro.CorreoInvalido)
        if (datos.contrasena.codePointCount(0, datos.contrasena.length) < LONGITUD_MINIMA_DE_LA_CONTRASENA) add(ErrorDeRegistro.ContrasenaCorta)
        if (!datos.aceptoAvisoDePrivacidad) add(ErrorDeRegistro.AvisoNoAceptado)
    }

    /** Nombre sin espacios al inicio y al final; correo además en minúsculas. La contraseña no se toca. */
    fun normalizar(datos: DatosDeRegistro): DatosDeRegistro =
        datos.copy(nombreCompleto = recortar(datos.nombreCompleto), correo = normalizarCorreo(datos.correo))

    companion object {
        const val LONGITUD_MINIMA_DEL_NOMBRE = 2
        const val LONGITUD_MAXIMA_DEL_NOMBRE = 120
        const val LONGITUD_MINIMA_DE_LA_CONTRASENA = 10

        internal fun normalizarCorreo(correo: String): String = recortar(correo).lowercase()

        internal fun recortar(texto: String): String = texto.trim { it.isWhitespace() }

        /**
         * Formato `algo@dominio.tld`: una sola `@`, sin espacios, parte local no vacía y un dominio con al menos dos
         * etiquetas no vacías separadas por puntos.
         */
        internal fun esCorreoValido(correo: String): Boolean {
            if (correo.any { it.isWhitespace() }) return false
            val partes = correo.split("@")
            if (partes.size != 2 || partes[0].isEmpty()) return false
            val etiquetas = partes[1].split(".")
            return etiquetas.size >= 2 && etiquetas.all { it.isNotEmpty() }
        }
    }
}
