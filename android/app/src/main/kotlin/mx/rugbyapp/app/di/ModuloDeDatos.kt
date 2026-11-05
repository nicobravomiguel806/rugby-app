package mx.rugbyapp.app.di

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton
import mx.rugbyapp.data.rules.RepositorioDeReglasPorDefecto
import mx.rugbyapp.domain.rules.RepositorioDeReglas

/** Liga los puertos de Domain con sus implementaciones de :data (ADR 0005). Espejo de ContenedorDeDependencias en iOS. */
@Module
@InstallIn(SingletonComponent::class)
object ModuloDeDatos {
    @Provides @Singleton
    fun repositorioDeReglas(): RepositorioDeReglas = RepositorioDeReglasPorDefecto()
}
