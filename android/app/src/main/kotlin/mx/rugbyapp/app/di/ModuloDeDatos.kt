package mx.rugbyapp.app.di

import android.content.Context
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton
import mx.rugbyapp.app.BuildConfig
import mx.rugbyapp.data.cuentas.AlmacenDeSesionCifrado
import mx.rugbyapp.data.cuentas.AlmacenSeguroDeSesion
import mx.rugbyapp.data.cuentas.ConfiguracionDeSupabase
import mx.rugbyapp.data.cuentas.GeneradorDeNonceSeguro
import mx.rugbyapp.data.cuentas.HashDeNonceSHA256
import mx.rugbyapp.data.cuentas.RepositorioDeSesionSupabase
import mx.rugbyapp.data.rules.RepositorioDeReglasPorDefecto
import mx.rugbyapp.domain.cuentas.GeneradorDeNonce
import mx.rugbyapp.domain.cuentas.HashDeNonce
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

    @Provides @Singleton
    fun repositorioDeSesion(almacen: AlmacenSeguroDeSesion): RepositorioDeSesion = RepositorioDeSesionSupabase(
        ConfiguracionDeSupabase(url = BuildConfig.SUPABASE_URL, anonKey = BuildConfig.SUPABASE_ANON_KEY),
        almacen,
    )

    @Provides
    fun generadorDeNonce(): GeneradorDeNonce = GeneradorDeNonceSeguro()

    @Provides
    fun hashDeNonce(): HashDeNonce = HashDeNonceSHA256()
}
