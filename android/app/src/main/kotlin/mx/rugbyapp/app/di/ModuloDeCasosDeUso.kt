package mx.rugbyapp.app.di

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import mx.rugbyapp.domain.rules.ObtenerModalidadesUseCase
import mx.rugbyapp.domain.rules.RepositorioDeReglas

/** Construye los casos de uso de Domain, que no llevan anotaciones de DI (ADR 0005). */
@Module
@InstallIn(SingletonComponent::class)
object ModuloDeCasosDeUso {
    @Provides
    fun obtenerModalidades(repositorio: RepositorioDeReglas): ObtenerModalidadesUseCase =
        ObtenerModalidadesUseCase(repositorio)
}
