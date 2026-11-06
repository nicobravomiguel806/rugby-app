package mx.rugbyapp.domain.cuentas

/** SP-04 · La sesión guardada en el dispositivo (CP-154). Espejo en iOS: Domain/Cuentas/ObtenerSesionActualUseCase.swift. */
class ObtenerSesionActualUseCase(private val repositorio: RepositorioDeSesion) {
    suspend fun ejecutar(): Sesion? = repositorio.sesionActual()
}
