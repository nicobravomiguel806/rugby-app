package mx.rugbyapp.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
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
import mx.rugbyapp.app.cuentas.PreparacionDelArranque
import mx.rugbyapp.data.cuentas.ClienteSupabase
import mx.rugbyapp.domain.cuentas.AceptarAvisoDePrivacidadUseCase
import mx.rugbyapp.domain.cuentas.CerrarSesionUseCase
import mx.rugbyapp.domain.cuentas.CerrarRecuperacionAbandonadaUseCase
import mx.rugbyapp.domain.cuentas.ConfirmarCorreoUseCase
import mx.rugbyapp.domain.cuentas.ConfirmarRecuperacionDeContrasenaUseCase
import mx.rugbyapp.domain.cuentas.ConsultarAvisoAceptadoUseCase
import mx.rugbyapp.domain.cuentas.HayQuePedirElAvisoAlArrancarUseCase
import mx.rugbyapp.domain.cuentas.IniciarSesionConCorreoUseCase
import mx.rugbyapp.domain.cuentas.IniciarSesionUseCase
import mx.rugbyapp.domain.cuentas.ObtenerSesionActualUseCase
import mx.rugbyapp.domain.cuentas.PedirRecuperacionDeContrasenaUseCase
import mx.rugbyapp.domain.cuentas.RechazarAvisoDePrivacidadUseCase
import mx.rugbyapp.domain.cuentas.ReenviarVerificacionUseCase
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro
import mx.rugbyapp.domain.cuentas.RegistrarUsuarioUseCase
import mx.rugbyapp.domain.cuentas.RestablecerContrasenaUseCase
import mx.rugbyapp.domain.cuentas.Sesion
import mx.rugbyapp.domain.rules.ObtenerModalidadesUseCase
import mx.rugbyapp.presentation.cuentas.AccesoScreen
import mx.rugbyapp.presentation.cuentas.AccesoViewModel
import mx.rugbyapp.presentation.cuentas.AvisoDePrivacidadScreen
import mx.rugbyapp.presentation.cuentas.AvisoDePrivacidadViewModel
import mx.rugbyapp.presentation.cuentas.BienvenidaScreen
import mx.rugbyapp.presentation.cuentas.CuentaActivadaScreen
import mx.rugbyapp.presentation.cuentas.EnlaceInvalidoScreen
import mx.rugbyapp.presentation.cuentas.EnlaceInvalidoViewModel
import mx.rugbyapp.presentation.cuentas.EstadoDeInicioDeSesion
import mx.rugbyapp.presentation.cuentas.EstadoDeNuevaContrasena
import mx.rugbyapp.presentation.cuentas.EstadoDeAcceso
import mx.rugbyapp.presentation.cuentas.EstadoDeRegistro
import mx.rugbyapp.presentation.cuentas.EstadoDelAviso
import mx.rugbyapp.presentation.cuentas.EventosDeCuenta
import mx.rugbyapp.presentation.cuentas.IniciarSesionScreen
import mx.rugbyapp.presentation.cuentas.IniciarSesionViewModel
import mx.rugbyapp.presentation.cuentas.NuevaContrasenaScreen
import mx.rugbyapp.presentation.cuentas.NuevaContrasenaViewModel
import mx.rugbyapp.presentation.cuentas.ProximamenteScreen
import mx.rugbyapp.presentation.cuentas.RecuperarContrasenaScreen
import mx.rugbyapp.presentation.cuentas.RecuperarContrasenaViewModel
import mx.rugbyapp.presentation.cuentas.RegistroScreen
import mx.rugbyapp.presentation.cuentas.RegistroViewModel
import mx.rugbyapp.presentation.cuentas.TipoDeEnlace
import mx.rugbyapp.presentation.cuentas.VerificaTuCorreoScreen
import mx.rugbyapp.presentation.inicio.InicioScreen
import mx.rugbyapp.presentation.inicio.InicioViewModel

/**
 * Navegación base (CA-6): un NavHost con las rutas de Inicio y de la cuenta. Hilt inyecta los casos de uso y la
 * Activity crea los ViewModels con una fábrica, para que :presentation no dependa de Hilt (ADR 0005).
 * C-01 · Rutas `bienvenida`, `registro`, `verifica`, `aviso`, `activada` y `proximamente` (§3.6 del contrato). El enlace
 * `rugbyapp://auth-callback` llega por el intent de arranque o por `onNewIntent` (singleTop, ADR 0008).
 * C-02 · Rutas `iniciar_sesion`, `recuperar`, `nueva_contrasena` y `enlace_invalido`; el enlace
 * `rugbyapp://recuperar-contrasena`; y el arranque serializado (PreparacionDelArranque) antes del aviso y los enlaces.
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
    @Inject lateinit var hayQuePedirElAvisoAlArrancar: HayQuePedirElAvisoAlArrancarUseCase
    @Inject lateinit var iniciarSesionConCorreo: IniciarSesionConCorreoUseCase
    @Inject lateinit var pedirRecuperacion: PedirRecuperacionDeContrasenaUseCase
    @Inject lateinit var confirmarRecuperacion: ConfirmarRecuperacionDeContrasenaUseCase
    @Inject lateinit var restablecerContrasena: RestablecerContrasenaUseCase
    @Inject lateinit var cerrarRecuperacionAbandonada: CerrarRecuperacionAbandonadaUseCase
    @Inject lateinit var preparacion: PreparacionDelArranque

    /**
     * H-5 · Qué estados ya atendió la navegación y la sesión de «Sesión iniciada». Es un ViewModel: sobrevive a la
     * rotación, así que los `LaunchedEffect` de la composición nueva no repiten lo que ya hizo la anterior.
     * H-6 · También anota si llegó un enlace del correo, para que el arranque no pida el aviso.
     */
    private val eventos: EventosDeCuenta by viewModels()

    /** Enlace de verificación pendiente de procesar. Solo en memoria. */
    private val enlaces = MutableStateFlow<String?>(null)
    /** C-02 · Enlace de recuperación pendiente de procesar. Solo en memoria. */
    private val enlacesDeRecuperacion = MutableStateFlow<String?>(null)

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

    /** Cada enlace va a su flujo por esquema, host exacto y path vacío (ADR 0008, C02-7). Lo demás se ignora. */
    private fun recibir(intent: Intent?) {
        val enlace = intent?.takeIf { it.action == Intent.ACTION_VIEW }?.dataString ?: return
        when {
            ClienteSupabase.esEnlaceDeVerificacion(enlace) -> {
                eventos.llegoUnEnlace = true // H-6: antes de procesarlo, para que el arranque no pida el aviso
                enlaces.value = enlace
            }
            ClienteSupabase.esEnlaceDeRecuperacion(enlace) -> {
                eventos.llegoUnEnlace = true
                enlacesDeRecuperacion.value = enlace
            }
        }
    }

    @Composable
    private fun Navegacion() {
        val navController = rememberNavController()
        // Al rechazar el aviso se crea otro RegistroViewModel: lo marcado en memoria se olvida (CA-9, AT-17).
        var generacion by rememberSaveable { mutableIntStateOf(0) }

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

        // C-02 · Cada visita a estas pantallas usa un ViewModel nuevo (lo escrito se olvida, CA-3). La generación
        // sobrevive a la rotación y forma parte de la clave con la que EventosDeCuenta recuerda lo ya atendido.
        var genInicio by rememberSaveable { mutableIntStateOf(0) }
        var genRecuperar by rememberSaveable { mutableIntStateOf(0) }
        var genNueva by rememberSaveable { mutableIntStateOf(0) }
        var genEnlace by rememberSaveable { mutableIntStateOf(0) }
        var tipoDeEnlace by rememberSaveable { mutableStateOf(TipoDeEnlace.VERIFICACION.name) }
        var correoDelEnlace by rememberSaveable { mutableStateOf<String?>(null) }
        var enlaceParaNueva by remember { mutableStateOf<String?>(null) } // con el código: solo en memoria

        val inicioDeSesion: IniciarSesionViewModel = viewModel(
            key = "inicio-$genInicio",
            factory = viewModelFactory {
                initializer { IniciarSesionViewModel(iniciarSesionConCorreo, iniciarSesion, reenviarVerificacion) }
            },
        )
        val recuperar: RecuperarContrasenaViewModel = viewModel(
            key = "recuperar-$genRecuperar",
            factory = viewModelFactory {
                initializer { RecuperarContrasenaViewModel(pedirRecuperacion, inicioDeSesion.formulario.value.correo) }
            },
        )
        val nueva: NuevaContrasenaViewModel = viewModel(
            key = "nueva-$genNueva",
            factory = viewModelFactory {
                initializer { NuevaContrasenaViewModel(confirmarRecuperacion, restablecerContrasena, cerrarRecuperacionAbandonada) }
            },
        )
        val enlaceInvalido: EnlaceInvalidoViewModel = viewModel(
            key = "enlace-$genEnlace",
            factory = viewModelFactory {
                initializer { EnlaceInvalidoViewModel(TipoDeEnlace.valueOf(tipoDeEnlace), correoDelEnlace, reenviarVerificacion) }
            },
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
        /** `cerrarHoja` (C-02, Iniciar sesión y Nueva contraseña): vuelve al Inicio provisional (§3.6). */
        suspend fun trasIniciarSesion(sesion: Sesion, desdeRegistro: Boolean, cerrarHoja: Boolean = false) {
            if (aviso.hayQuePedirlo(siFalla = true)) {
                mostrarAviso()
            } else if (desdeRegistro) {
                eventos.sesionActivada = sesion
                navController.irA(RUTA_ACTIVADA)
            } else if (cerrarHoja) {
                navController.irA(RUTA_INICIO)
            }
        }
        suspend fun irAIniciarSesion() {
            genInicio++
            navController.irA(RUTA_INICIAR_SESION)
        }
        suspend fun irAEnlaceInvalido(tipo: TipoDeEnlace, correo: String?) {
            tipoDeEnlace = tipo.name
            correoDelEnlace = correo
            genEnlace++
            navController.irA(RUTA_ENLACE_INVALIDO)
        }

        // H-5 · Cada estado se atiende una sola vez: se revisa al empezar y se marca al terminar, así una rotación que
        // interrumpe la atención la deja pendiente para la composición nueva.
        suspend fun atenderUnaVez(fuente: String, estado: Any, bloque: suspend () -> Unit) {
            if (!eventos.pendiente(fuente, estado)) return
            bloque()
            eventos.atendido(fuente, estado)
        }

        // App cerrada sin decidir o cuenta de SP-04 sin aviso: se vuelve a pedir. Sin red no se bloquea (§3.6, CP-164d).
        // H-6 · Si llegó un enlace del correo, no se pide aquí: lo consulta el flujo del enlace (CP-164e).
        LaunchedEffect(Unit) {
            atenderUnaVez(EventosDeCuenta.ARRANQUE, Unit) {
                preparacion.esperar() // C-02 · §3.6: la recuperación abandonada primero
                if (hayQuePedirElAvisoAlArrancar.ejecutar(llegoUnEnlace = { eventos.llegoUnEnlace })) mostrarAviso()
            }
        }

        val enlace by enlaces.collectAsState()
        LaunchedEffect(enlace) {
            val pendiente = enlace ?: return@LaunchedEffect
            enlaces.value = null
            preparacion.esperar()
            navController.irA(RUTA_VERIFICA)
            registro.confirmarEnlace(pendiente)
        }

        // C-02 · `rugbyapp://recuperar-contrasena?code=…`. Espera al arranque: si no, la recuperación abandonada de
        // antes podría cerrar la sesión recién canjeada.
        val enlaceDeRecuperacion by enlacesDeRecuperacion.collectAsState()
        LaunchedEffect(enlaceDeRecuperacion) {
            val pendiente = enlaceDeRecuperacion ?: return@LaunchedEffect
            enlacesDeRecuperacion.value = null
            preparacion.esperar()
            enlaceParaNueva = pendiente
            genNueva++
            navController.irA(RUTA_NUEVA_CONTRASENA)
        }
        LaunchedEffect(nueva) {
            val pendiente = enlaceParaNueva ?: return@LaunchedEffect
            enlaceParaNueva = null
            nueva.confirmarEnlace(pendiente)
        }

        val estadoDeInicio by inicioDeSesion.estado.collectAsState()
        LaunchedEffect(estadoDeInicio) {
            val actual = estadoDeInicio
            atenderUnaVez("${EventosDeCuenta.INICIO_DE_SESION}-$genInicio", actual) {
                (actual as? EstadoDeInicioDeSesion.ConSesion)?.let { trasIniciarSesion(it.sesion, desdeRegistro = false, cerrarHoja = true) }
            }
        }

        val estadoDeNueva by nueva.estado.collectAsState()
        LaunchedEffect(estadoDeNueva) {
            val actual = estadoDeNueva
            atenderUnaVez("${EventosDeCuenta.NUEVA_CONTRASENA}-$genNueva", actual) {
                when (actual) {
                    EstadoDeNuevaContrasena.EnlaceInvalido -> irAEnlaceInvalido(TipoDeEnlace.RECUPERACION, null)
                    is EstadoDeNuevaContrasena.Guardada -> trasIniciarSesion(actual.sesion, desdeRegistro = false, cerrarHoja = true)
                    EstadoDeNuevaContrasena.Abandonada -> irAIniciarSesion() // P-7: vuelve a Iniciar sesión
                    else -> Unit
                }
            }
        }

        val irARecuperar by enlaceInvalido.irARecuperar.collectAsState()
        LaunchedEffect(irARecuperar) {
            if (!irARecuperar) return@LaunchedEffect
            enlaceInvalido.yaSeFueARecuperar()
            genRecuperar++
            withContext(Dispatchers.Main.immediate) { navController.navigate(RUTA_RECUPERAR) }
        }

        val estadoDeRegistro by registro.estado.collectAsState()
        LaunchedEffect(estadoDeRegistro) {
            val actual = estadoDeRegistro
            atenderUnaVez(EventosDeCuenta.REGISTRO, actual) {
                when (actual) {
                    is EstadoDeRegistro.EnlaceEnviado -> withContext(Dispatchers.Main.immediate) {
                        if (navController.currentDestination?.route != RUTA_VERIFICA) navController.navigate(RUTA_VERIFICA)
                    }
                    is EstadoDeRegistro.SesionIniciada -> trasIniciarSesion(actual.sesion, desdeRegistro = true)
                    // C-02 · CA-8: Enlace inválido. Si la app se abrió desde el enlace no conoce el correo y lo pide.
                    is EstadoDeRegistro.Error -> if (actual.error == ErrorDeRegistro.EnlaceInvalido) {
                        irAEnlaceInvalido(TipoDeEnlace.VERIFICACION, registro.formulario.value.correo.trim().ifEmpty { null })
                    }
                    else -> Unit
                }
            }
        }

        val estadoDeAcceso by acceso.estado.collectAsState()
        LaunchedEffect(estadoDeAcceso) {
            val actual = estadoDeAcceso
            atenderUnaVez(EventosDeCuenta.ACCESO, actual) {
                when (actual) {
                    is EstadoDeAcceso.ConSesion -> trasIniciarSesion(actual.sesion, desdeRegistro = false)
                    // C-02 · CA-3: tras cerrar sesión vuelve a Bienvenida y se olvida lo escrito en memoria.
                    EstadoDeAcceso.SinSesion -> if (navController.currentDestination?.route == RUTA_ACCESO) {
                        generacion++
                        genInicio++
                        aviso.reiniciar()
                        navController.irA(RUTA_BIENVENIDA)
                    }
                    else -> Unit
                }
            }
        }

        val estadoDelAviso by aviso.estado.collectAsState()
        LaunchedEffect(estadoDelAviso) {
            val actual = estadoDelAviso
            atenderUnaVez(EventosDeCuenta.AVISO, actual) {
                when (actual) {
                    EstadoDelAviso.Aceptado -> {
                        eventos.sesionActivada = obtenerSesionActual.ejecutar()
                        navController.irA(RUTA_ACTIVADA)
                    }
                    EstadoDelAviso.Rechazado -> {
                        // CA-9: sesión cerrada y nada guardado (o revocación registrada, H-6). Se vuelve a Bienvenida.
                        generacion++
                        aviso.reiniciar()
                        acceso.cargar()
                        navController.irA(RUTA_BIENVENIDA)
                    }
                    else -> Unit
                }
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
                    yaTengoCuenta = { genInicio++; navController.navigate(RUTA_INICIAR_SESION) }, // C-02 · cierra P-10 de C-01
                )
            }
            composable(RUTA_INICIAR_SESION) {
                IniciarSesionScreen(inicioDeSesion, olvideMiContrasena = { genRecuperar++; navController.navigate(RUTA_RECUPERAR) })
            }
            composable(RUTA_RECUPERAR) { RecuperarContrasenaScreen(recuperar) }
            composable(RUTA_NUEVA_CONTRASENA) { NuevaContrasenaScreen(nueva) }
            composable(RUTA_ENLACE_INVALIDO) { EnlaceInvalidoScreen(enlaceInvalido) }
            composable(RUTA_REGISTRO) { RegistroScreen(registro, urlDelAviso = BuildConfig.AVISO_DE_PRIVACIDAD_URL) }
            composable(RUTA_VERIFICA) { VerificaTuCorreoScreen(registro) }
            composable(RUTA_ACCESO) { AccesoScreen(acceso) }
            composable(RUTA_AVISO) { AvisoDePrivacidadScreen(aviso, urlDelAviso = BuildConfig.AVISO_DE_PRIVACIDAD_URL) }
            composable(RUTA_ACTIVADA) {
                eventos.sesionActivada?.let { CuentaActivadaScreen(it, crearMiPerfil = { navController.navigate(RUTA_PROXIMAMENTE) }) }
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
        const val RUTA_INICIAR_SESION = "iniciar_sesion"
        const val RUTA_RECUPERAR = "recuperar"
        const val RUTA_NUEVA_CONTRASENA = "nueva_contrasena"
        const val RUTA_ENLACE_INVALIDO = "enlace_invalido"
    }
}
