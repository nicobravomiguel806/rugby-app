package mx.rugbyapp.domain.cuentas

/**
 * C-01 · Resultado del registro con correo. Es el mismo para un correo nuevo y para uno que ya tiene cuenta
 * (P-7, AT-11): la app nunca confirma si un correo existe. Espejo en iOS: Domain/Cuentas/ResultadoDeRegistro.swift.
 */
sealed class ResultadoDeRegistro {
    data class EnlaceEnviado(val correo: String) : ResultadoDeRegistro()
}
