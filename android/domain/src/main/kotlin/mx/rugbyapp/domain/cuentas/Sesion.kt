package mx.rugbyapp.domain.cuentas

/** SP-04 · Sesión del usuario tal como la ve Domain. No lleva tokens. Espejo en iOS: Domain/Cuentas/Sesion.swift. */
data class Sesion(val usuarioId: String, val correo: String?)
