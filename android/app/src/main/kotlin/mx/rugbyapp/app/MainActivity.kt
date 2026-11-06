package mx.rugbyapp.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject
import mx.rugbyapp.app.cuentas.ObtenedorDeCredencialGoogle
import mx.rugbyapp.domain.cuentas.CerrarSesionUseCase
import mx.rugbyapp.domain.cuentas.IniciarSesionUseCase
import mx.rugbyapp.domain.cuentas.ObtenerSesionActualUseCase
import mx.rugbyapp.domain.rules.ObtenerModalidadesUseCase
import mx.rugbyapp.presentation.cuentas.AccesoScreen
import mx.rugbyapp.presentation.cuentas.AccesoViewModel
import mx.rugbyapp.presentation.inicio.InicioScreen
import mx.rugbyapp.presentation.inicio.InicioViewModel

/**
 * Navegación base (CA-6): un NavHost con las rutas `inicio` y `acceso` (SP-04, P-6). Hilt inyecta los casos de uso y
 * la Activity crea los ViewModels con una fábrica, para que :presentation no dependa de Hilt (ADR 0005).
 */
@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var obtenerModalidades: ObtenerModalidadesUseCase
    @Inject lateinit var iniciarSesion: IniciarSesionUseCase
    @Inject lateinit var obtenerSesionActual: ObtenerSesionActualUseCase
    @Inject lateinit var cerrarSesion: CerrarSesionUseCase
    @Inject lateinit var obtenedorDeGoogle: ObtenedorDeCredencialGoogle

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        obtenedorDeGoogle.vincular(this) // Credential Manager necesita el contexto de la Activity
        setContent {
            MaterialTheme {
                Surface {
                    val navController = rememberNavController()
                    NavHost(navController = navController, startDestination = RUTA_INICIO) {
                        composable(RUTA_INICIO) {
                            val viewModel: InicioViewModel = viewModel(
                                factory = viewModelFactory { initializer { InicioViewModel(obtenerModalidades) } }
                            )
                            Column(Modifier.fillMaxSize()) {
                                InicioScreen(viewModel, Modifier.weight(1f))
                                // SP-04 · P-6: botón «Cuenta» provisional que abre Acceso.
                                Button(
                                    onClick = { navController.navigate(RUTA_ACCESO) },
                                    modifier = Modifier.fillMaxWidth().padding(16.dp).defaultMinSize(minHeight = 48.dp),
                                ) { Text("Cuenta") }
                            }
                        }
                        composable(RUTA_ACCESO) {
                            val viewModel: AccesoViewModel = viewModel(
                                factory = viewModelFactory {
                                    initializer { AccesoViewModel(iniciarSesion, obtenerSesionActual, cerrarSesion) }
                                }
                            )
                            AccesoScreen(viewModel)
                        }
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        obtenedorDeGoogle.desvincular(this)
        super.onDestroy()
    }

    private companion object {
        const val RUTA_INICIO = "inicio"
        const val RUTA_ACCESO = "acceso"
    }
}
