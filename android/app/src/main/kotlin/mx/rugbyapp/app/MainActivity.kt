package mx.rugbyapp.app

import android.content.Intent
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import mx.rugbyapp.app.cuentas.ObtenedorDeCredencialGoogle
import mx.rugbyapp.data.cuentas.RepositorioDeRegistroSupabase
import mx.rugbyapp.domain.cuentas.AceptarAvisoDePrivacidadUseCase
import mx.rugbyapp.domain.cuentas.CerrarSesionUseCase
import mx.rugbyapp.domain.cuentas.ConfirmarCorreoUseCase
import mx.rugbyapp.domain.cuentas.ConsultarAvisoAceptadoUseCase
import mx.rugbyapp.domain.cuentas.IniciarSesionUseCase
import mx.rugbyapp.domain.cuentas.ObtenerSesionActualUseCase
import mx.rugbyapp.domain.cuentas.RechazarAvisoDePrivacidadUseCase
import mx.rugbyapp.domain.cuentas.ReenviarVerificacionUseCase
import mx.rugbyapp.domain.cuentas.RegistrarUsuarioUseCase
import mx.rugbyapp.domain.cuentas.Sesion
import mx.rugbyapp.domain.rules.ObtenerModalidadesUseCase
import mx.rugbyapp.presentation.cuentas.AccesoScreen
import mx.rugbyapp.presentation.cuentas.AccesoViewModel
import mx.rugbyapp.presentation.cuentas.AvisoDePrivacidadScreen
import mx.rugbyapp.presentation.cuentas.AvisoDePrivacidadViewModel
import mx.rugbyapp.presentation.cuentas.BienvenidaScreen
import mx.rugbyapp.presentation.cuentas.CuentaActivadaScreen
import mx.rugbyapp.presentation.cuentas.EstadoDeAcceso
import mx.rugbyapp.presentation.cuentas.EstadoDeRegistro
import mx.rugbyapp.presentation.cuentas.EstadoDelAviso
import mx.rugbyapp.presentation.cuentas.ProximamenteScreen
import mx.rugbyapp.presentation.cuentas.RegistroScreen
import mx.rugbyapp.presentation.cuentas.RegistroViewModel
import mx.rugbyapp.presentation.cuentas.VerificaTuCorreoScreen
import mx.rugbyapp.presentation.inicio.InicioScreen
import mx.rugbyapp.presentation.inicio.InicioViewModel

/**
 * Navegación base (CA-6): un NavHost con las rutas de Inicio y de la cuenta. Hilt inyecta los casos de uso y la
 * Activity crea los ViewModels con una fábrica, para que :presentation no dependa de Hilt (ADR 0005).
 * C-01 · Rutas `bienvenida`, `registro`, `verifica`, `aviso`, `activada` y `proximamente` (§3.6 del contrato). El enlace
 * `rugbyapp://auth-callback` llega por el intent de arranque o por `onNewIntent` (singleTop, ADR 0008).
 * Espejo en iOS: RugbyAppApp.swift y NavegacionDeCuenta.swift.
 */
@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var obtenerModalidades: ObtenerModalidadesUseCase
    @Inject lateinit var iniciarSesion: IniciarSesionUseCase
    @Inject lateinit var obtenerSesionActual: ObtenerSesionActualUseCase
    @Inject lateinit var cerrarSesion: CerrarSesionUseCase
    @Inject lateinit var obtenedorDeGoogle: ObtenedorDeCredencialGoogle
    @Inject lateinit var registrarUsuario: RegistrarUsuarioUseCase
    @Inject lateinit var reenviarVerificacion: ReenviarVerificacionUseCase
    @Inject lateinit var confirmarCorreo: ConfirmarCorreoUseCase
    @Inject lateinit var aceptarAviso: AceptarAvisoDePrivacidadUseCase
    @Inject lateinit var consultarAviso: ConsultarAvisoAceptadoUseCase
    @Inject lateinit var rechazarAviso: RechazarAvisoDePrivacidadUseCase

    /** Enlace de verificación pendiente de procesar. Solo en memoria. */
    private val enlaces = MutableStateFlow<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        obtenedorDeGoogle.vincular(this) // Credential Manager necesita el contexto de la Activity
        if (savedInstanceState == null) recibir(intent)
        setContent {
            MaterialTheme {
                Surface { Navegacion() }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        recibir(intent)
    }

    override fun onDestroy() {
        obtenedorDeGoogle.desvincular(this)
        super.onDestroy()
    }

    /** Solo `rugbyapp://auth-callback…` va a ConfirmarCorreoUseCase (ADR 0008). */
    private fun recibir(intent: Intent?) {
        val enlace = intent?.takeIf { it.action == Intent.ACTION_VIEW }?.dataString ?: return
        if (RepositorioDeRegistroSupabase.esEnlaceDeVerificacion(enlace)) enlaces.value = enlace
    }

    @Composable
    private fun Navegacion() {
        val navController = rememberNavController()
        // Al rechazar el aviso se crea otro RegistroViewModel: lo marcado en memoria se olvida (CA-9, AT-17).
        var generacion by rememberSaveable { mutableIntStateOf(0) }
        var sesionActivada by remember { mutableStateOf<Sesion?>(null) }

        val registro: RegistroViewModel = viewModel(
            key = "registro-$generacion",
            factory = viewModelFactory {
                initializer { RegistroViewModel(registrarUsuario, reenviarVerificacion, confirmarCorreo, aceptarAviso, iniciarSesion) }
            },
        )
        val aviso: AvisoDePrivacidadViewModel = viewModel(
            factory = viewModelFactory {
                initializer { AvisoDePrivacidadViewModel(aceptarAviso, rechazarAviso, consultarAviso, obtenerSesionActual) }
            },
        )
        val acceso: AccesoViewModel = viewModel(
            factory = viewModelFactory { initializer { AccesoViewModel(iniciarSesion, obtenerSesionActual, cerrarSesion) } },
        )

        // NavController exige el hilo principal; tras una llamada suspendida se vuelve a él explícitamente.
        suspend fun NavHostController.irA(ruta: String) = withContext(Dispatchers.Main.immediate) {
            navigate(ruta) {
                popUpTo(RUTA_INICIO)
                launchSingleTop = true
            }
        }
        suspend fun mostrarAviso() {
            aviso.reiniciar()
            navController.irA(RUTA_AVISO)
        }
        suspend fun trasIniciarSesion(sesion: Sesion, desdeRegistro: Boolean) {
            if (aviso.hayQuePedirlo(siFalla = true)) {
                mostrarAviso()
            } else if (desdeRegistro) {
                sesionActivada = sesion
                navController.irA(RUTA_ACTIVADA)
            }
        }

        // App cerrada sin decidir o cuenta de SP-04 sin aviso: se vuelve a pedir. Sin red no se bloquea (§3.6, CP-164d).
        LaunchedEffect(Unit) { if (aviso.hayQuePedirlo(siFalla = false)) mostrarAviso() }

        val enlace by enlaces.collectAsState()
        LaunchedEffect(enlace) {
            val pendiente = enlace ?: return@LaunchedEffect
            enlaces.value = null
            navController.irA(RUTA_VERIFICA)
            registro.confirmarEnlace(pendiente)
        }

        val estadoDeRegistro by registro.estado.collectAsState()
        LaunchedEffect(estadoDeRegistro) {
            when (val actual = estadoDeRegistro) {
                is EstadoDeRegistro.EnlaceEnviado -> withContext(Dispatchers.Main.immediate) {
                    if (navController.currentDestination?.route != RUTA_VERIFICA) navController.navigate(RUTA_VERIFICA)
                }
                is EstadoDeRegistro.SesionIniciada -> trasIniciarSesion(actual.sesion, desdeRegistro = true)
                else -> Unit
            }
        }

        val estadoDeAcceso by acceso.estado.collectAsState()
        LaunchedEffect(estadoDeAcceso) {
            (estadoDeAcceso as? EstadoDeAcceso.ConSesion)?.let { trasIniciarSesion(it.sesion, desdeRegistro = false) }
        }

        val estadoDelAviso by aviso.estado.collectAsState()
        LaunchedEffect(estadoDelAviso) {
            when (estadoDelAviso) {
                EstadoDelAviso.Aceptado -> {
                    sesionActivada = obtenerSesionActual.ejecutar()
                    navController.irA(RUTA_ACTIVADA)
                }
                EstadoDelAviso.Rechazado -> {
                    // CA-9: sesión cerrada y nada guardado. Se vuelve a Bienvenida.
                    generacion++
                    aviso.reiniciar()
                    acceso.cargar()
                    navController.irA(RUTA_BIENVENIDA)
                }
                else -> Unit
            }
        }

        NavHost(navController = navController, startDestination = RUTA_INICIO) {
            composable(RUTA_INICIO) {
                val viewModel: InicioViewModel = viewModel(
                    factory = viewModelFactory { initializer { InicioViewModel(obtenerModalidades) } }
                )
                Column(Modifier.fillMaxSize()) {
                    InicioScreen(viewModel, Modifier.weight(1f))
                    // SP-04 · P-6: botón «Cuenta» provisional. C-01: sin sesión abre Bienvenida (§3.6).
                    Button(
                        onClick = {
                            lifecycleScope.launch {
                                val ruta = if (obtenerSesionActual.ejecutar() != null) RUTA_ACCESO else RUTA_BIENVENIDA
                                withContext(Dispatchers.Main.immediate) { navController.navigate(ruta) }
                            }
                        },
                        modifier = Modifier.fillMaxWidth().padding(16.dp).defaultMinSize(minHeight = 48.dp),
                    ) { Text("Cuenta") }
                }
            }
            composable(RUTA_BIENVENIDA) {
                BienvenidaScreen(
                    crearCuenta = { navController.navigate(RUTA_REGISTRO) },
                    yaTengoCuenta = { navController.navigate(RUTA_ACCESO) }, // Acceso de SP-04 hasta C-02 (P-10)
                )
            }
            composable(RUTA_REGISTRO) { RegistroScreen(registro, urlDelAviso = BuildConfig.AVISO_DE_PRIVACIDAD_URL) }
            composable(RUTA_VERIFICA) { VerificaTuCorreoScreen(registro) }
            composable(RUTA_ACCESO) { AccesoScreen(acceso) }
            composable(RUTA_AVISO) { AvisoDePrivacidadScreen(aviso, urlDelAviso = BuildConfig.AVISO_DE_PRIVACIDAD_URL) }
            composable(RUTA_ACTIVADA) {
                sesionActivada?.let { CuentaActivadaScreen(it, crearMiPerfil = { navController.navigate(RUTA_PROXIMAMENTE) }) }
            }
            composable(RUTA_PROXIMAMENTE) { ProximamenteScreen() } // C-03 (P-10)
        }
    }

    private companion object {
        const val RUTA_INICIO = "inicio"
        const val RUTA_ACCESO = "acceso"
        const val RUTA_BIENVENIDA = "bienvenida"
        const val RUTA_REGISTRO = "registro"
        const val RUTA_VERIFICA = "verifica"
        const val RUTA_AVISO = "aviso"
        const val RUTA_ACTIVADA = "activada"
        const val RUTA_PROXIMAMENTE = "proximamente"
    }
}
