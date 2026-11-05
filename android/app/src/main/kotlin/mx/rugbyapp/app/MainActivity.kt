package mx.rugbyapp.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject
import mx.rugbyapp.domain.rules.ObtenerModalidadesUseCase
import mx.rugbyapp.presentation.inicio.InicioScreen
import mx.rugbyapp.presentation.inicio.InicioViewModel

/**
 * Navegación base (CA-6): un NavHost con una sola ruta, `inicio`. Hilt inyecta los casos de uso y la
 * Activity crea los ViewModels con una fábrica, para que :presentation no dependa de Hilt (ADR 0005).
 */
@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var obtenerModalidades: ObtenerModalidadesUseCase

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface {
                    val navController = rememberNavController()
                    NavHost(navController = navController, startDestination = RUTA_INICIO) {
                        composable(RUTA_INICIO) {
                            val viewModel: InicioViewModel = viewModel(
                                factory = viewModelFactory { initializer { InicioViewModel(obtenerModalidades) } }
                            )
                            InicioScreen(viewModel)
                        }
                    }
                }
            }
        }
    }

    private companion object {
        const val RUTA_INICIO = "inicio"
    }
}
