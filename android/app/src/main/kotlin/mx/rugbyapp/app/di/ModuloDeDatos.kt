package mx.rugbyapp.app.di

import android.content.Context
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton
import mx.rugbyapp.app.BuildConfig
import mx.rugbyapp.app.cuentas.MonitorDeRed
import mx.rugbyapp.app.cuentas.ObtenedorDeCredencialGoogle
import mx.rugbyapp.app.cuentas.RelojDelSistema
import mx.rugbyapp.app.cuentas.RepositorioDeSesionSinRastroDeGoogle
import mx.rugbyapp.data.cuentas.AlmacenDeSesionCifrado
import mx.rugbyapp.data.cuentas.AlmacenSeguroDeSesion
import mx.rugbyapp.data.cuentas.ClienteSupabase
import mx.rugbyapp.data.cuentas.ConfiguracionDeSupabase
import mx.rugbyapp.data.cuentas.GeneradorDeNonceSeguro
import mx.rugbyapp.data.cuentas.HashDeNonceSHA256
import mx.rugbyapp.data.cuentas.RepositorioDeConsentimientoSupabase
import mx.rugbyapp.data.cuentas.RepositorioDeRecuperacionSupabase
import mx.rugbyapp.data.cuentas.RepositorioDeRegistroSupabase
import mx.rugbyapp.data.cuentas.RepositorioDeRevocacionesPendientesSupabase
import mx.rugbyapp.data.cuentas.RepositorioDeSesionSupabase
import mx.rugbyapp.data.rules.RepositorioDeReglasPorDefecto
import mx.rugbyapp.domain.cuentas.GeneradorDeNonce
import mx.rugbyapp.domain.cuentas.HashDeNonce
import mx.rugbyapp.domain.cuentas.Reloj
import mx.rugbyapp.domain.cuentas.RepositorioDeConsentimiento
import mx.rugbyapp.domain.cuentas.RepositorioDeRecuperacion
import mx.rugbyapp.domain.cuentas.RepositorioDeRegistro
import mx.rugbyapp.domain.cuentas.RepositorioDeRevocacionesPendientes
import mx.rugbyapp.domain.cuentas.RepositorioDeSesion
import mx.rugbyapp.domain.rules.RepositorioDeReglas

/** Liga los puertos de Domain con sus implementaciones de :data (ADR 0005). Espejo de ContenedorDeDependencias en iOS. */
@Module
@InstallIn(SingletonComponent::class)
object ModuloDeDatos {
    @Provides @Singleton
    fun repositorioDeReglas(): RepositorioDeReglas = RepositorioDeReglasPorDefecto()

    // SP-04 · Sesión (ADR 0006 / ADR 0007). Las llaves llegan de local.properties por BuildConfig; vacías en CI.
    @Provides @Singleton
    fun almacenDeSesion(@ApplicationContext contexto: Context): AlmacenSeguroDeSesion = AlmacenDeSesionCifrado(contexto)

    // C-01 · Un solo cliente de Supabase (Auth + Postgrest) para toda la app (ADR 0006): sesión, registro y
    // consentimiento comparten la sesión y el code_verifier de PKCE en el mismo almacén cifrado.
    @Provides @Singleton
    fun clienteSupabase(almacen: AlmacenSeguroDeSesion): ClienteSupabase = ClienteSupabase(
        ConfiguracionDeSupabase(url = BuildConfig.SUPABASE_URL, anonKey = BuildConfig.SUPABASE_ANON_KEY),
        almacen,
    )

    // C-02 · CA-3: el decorador limpia también el estado de Credential Manager al cerrar sesión (SP-04 H-3).
    @Provides @Singleton
    fun repositorioDeSesion(cliente: ClienteSupabase, google: ObtenedorDeCredencialGoogle): RepositorioDeSesion =
        RepositorioDeSesionSinRastroDeGoogle(RepositorioDeSesionSupabase(cliente), google)

    @Provides @Singleton
    fun reloj(): Reloj = RelojDelSistema()

    // C-02 · ADR 0010: revocaciones pendientes en su propio DataStore cifrado (Tink + llave del Keystore), que el
    // cierre de sesión no borra. Mismas exclusiones de respaldo que la sesión (AT-17).
    @Provides @Singleton
    fun repositorioDeRevocaciones(
        @ApplicationContext contexto: Context,
        cliente: ClienteSupabase,
        reloj: Reloj,
    ): RepositorioDeRevocacionesPendientes = RepositorioDeRevocacionesPendientesSupabase(
        cliente,
        AlmacenDeSesionCifrado(contexto, nombre = "revocaciones", aliasDeLlave = "rugbyapp_revocaciones"),
        reloj,
    )

    @Provides @Singleton
    fun repositorioDeRecuperacion(cliente: ClienteSupabase): RepositorioDeRecuperacion = RepositorioDeRecuperacionSupabase(cliente)

    @Provides @Singleton
    fun monitorDeRed(@ApplicationContext contexto: Context): MonitorDeRed = MonitorDeRed(contexto)

    @Provides @Singleton
    fun repositorioDeRegistro(cliente: ClienteSupabase): RepositorioDeRegistro = RepositorioDeRegistroSupabase(cliente)

    @Provides @Singleton
    fun repositorioDeConsentimiento(cliente: ClienteSupabase): RepositorioDeConsentimiento = RepositorioDeConsentimientoSupabase(cliente)

    @Provides
    fun generadorDeNonce(): GeneradorDeNonce = GeneradorDeNonceSeguro()

    @Provides
    fun hashDeNonce(): HashDeNonce = HashDeNonceSHA256()
}
