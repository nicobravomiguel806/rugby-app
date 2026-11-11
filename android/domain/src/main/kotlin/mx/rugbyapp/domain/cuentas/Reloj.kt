package mx.rugbyapp.domain.cuentas

/**
 * C-02 · La hora actual en segundos, para que los tests controlen el tiempo (CP-167g).
 * Implementación: :app/cuentas/RelojDelSistema. Espejo en iOS: Domain/Cuentas/Reloj.swift.
 */
fun interface Reloj {
    fun ahoraEnSegundos(): Long
}
