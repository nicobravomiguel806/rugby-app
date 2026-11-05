# ADR 0005 · Inyección de dependencias

- **Estado:** Aceptada · 5 nov 2026 · T-03 / AN-T-03
- **Contexto:** la regla de dependencias (Domain ← Data, Domain ← Presentation, App → todas) exige que alguien conecte las implementaciones de Data con los casos de uso de Domain y los ViewModels de Presentation, sin que Domain conozca un framework de DI. AN-T-03 pide Hilt en Android.
- **Decisión:**
  - **iOS:** raíz de composición manual, `ContenedorDeDependencias` en el target `RugbyApp`, con inyección por constructor (Data → caso de uso → ViewModel). Sin librerías de terceros.
  - **Android:** Hilt. Todos los módulos de Hilt viven en `:app` (`di/ModuloDeDatos` liga los puertos de Domain con `:data`; `di/ModuloDeCasosDeUso` construye los casos de uso con `@Provides`). `RugbyApp` lleva `@HiltAndroidApp` y `MainActivity` `@AndroidEntryPoint`.
  - **ViewModels en Android:** `:presentation` no depende de Hilt. `MainActivity` recibe los casos de uso por `@Inject` y crea cada ViewModel con una fábrica (`viewModelFactory { initializer { … } }`) dentro de su ruta del `NavHost`. Así `:presentation` queda igual que en iOS: el ViewModel solo recibe el caso de uso por constructor. Por eso no se usa `@HiltViewModel` ni `hilt-navigation-compose`.
  - Domain y Data no llevan anotaciones de DI en ninguna plataforma (ni `@Inject` ni `@Module`), y así Domain sigue siendo puro.
- **Consecuencias:** (+) las capas son idénticas en las dos plataformas y se prueban sin DI (los tests construyen los objetos a mano); cambiar de framework de DI solo toca `:app`. (−) cada ViewModel nuevo necesita su fábrica en `:app`; si las pantallas crecen, se puede revisar este ADR para adoptar `@HiltViewModel`.
