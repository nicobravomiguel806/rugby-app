package mx.rugbyapp.app.di

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton
import mx.rugbyapp.app.BuildConfig
import mx.rugbyapp.app.cuentas.ObtenedorDeCredencialGoogle
import mx.rugbyapp.domain.cuentas.CerrarSesionUseCase
import mx.rugbyapp.domain.cuentas.GeneradorDeNonce
import mx.rugbyapp.domain.cuentas.HashDeNonce
import mx.rugbyapp.domain.cuentas.IniciarSesionUseCase
import mx.rugbyapp.domain.cuentas.ObtenerSesionActualUseCase
import mx.rugbyapp.domain.cuentas.RepositorioDeSesion
import mx.rugbyapp.domain.rules.ObtenerModalidadesUseCase
import mx.rugbyapp.domain.rules.RepositorioDeReglas

/** Construye los casos de uso de Domain, que no llevan anotaciones de DI (ADR 0005). */
@Module
@InstallIn(SingletonComponent::class)
object ModuloDeCasosDeUso {
    @Provides
    fun obtenerModalidades(repositorio: RepositorioDeReglas): ObtenerModalidadesUseCase =
        ObtenerModalidadesUseCase(repositorio)

    // SP-04 · El adaptador de Google es único en la app; MainActivity se vincula a él.
    @Provides @Singleton
    fun obtenedorDeGoogle(): ObtenedorDeCredencialGoogle = ObtenedorDeCredencialGoogle(BuildConfig.GOOGLE_WEB_CLIENT_ID)

    @Provides
    fun iniciarSesion(
        generador: GeneradorDeNonce,
        hash: HashDeNonce,
        obtenedor: ObtenedorDeCredencialGoogle,
        repositorio: RepositorioDeSesion,
    ): IniciarSesionUseCase = IniciarSesionUseCase(generador, hash, obtenedor, repositorio)

    @Provides
    fun obtenerSesionActual(repositorio: RepositorioDeSesion): ObtenerSesionActualUseCase = ObtenerSesionActualUseCase(repositorio)

    @Provides
    fun cerrarSesion(repositorio: RepositorioDeSesion): CerrarSesionUseCase = CerrarSesionUseCase(repositorio)
}
