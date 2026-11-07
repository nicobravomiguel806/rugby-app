package mx.rugbyapp.domain.cuentas

/**
 * SP-04 · Sesión del usuario tal como la ve Domain. No lleva tokens.
 * C-01 · `nombre` viene de los datos de la cuenta (`full_name` del registro con correo o el nombre de Google). Es solo
 * para mostrar (saludo); nunca decide permisos (domain-model.md §1). Espejo en iOS: Domain/Cuentas/Sesion.swift.
 */
data class Sesion(val usuarioId: String, val correo: String?, val nombre: String? = null)
