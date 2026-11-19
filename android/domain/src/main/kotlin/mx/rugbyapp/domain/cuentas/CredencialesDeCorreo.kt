package mx.rugbyapp.domain.cuentas

/**
 * C-02 · Lo que la persona escribe en Iniciar sesión (D-5). `toString()` nunca imprime la contraseña (como CP-160j).
 * Espejo en iOS: Domain/Cuentas/CredencialesDeCorreo.swift.
 */
data class CredencialesDeCorreo(val correo: String, val contrasena: String) {
    override fun toString() = "CredencialesDeCorreo(correo=$correo, contrasena=***)"
}
