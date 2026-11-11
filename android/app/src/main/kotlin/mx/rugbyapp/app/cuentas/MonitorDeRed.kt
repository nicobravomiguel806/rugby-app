package mx.rugbyapp.app.cuentas

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import java.util.concurrent.atomic.AtomicBoolean

/**
 * C-02 · CA-4 (ADR 0010): avisa cuando vuelve la red para reintentar las revocaciones pendientes. Solo dispara en la
 * transición «sin red → con red». Necesita `ACCESS_NETWORK_STATE`. Espejo en iOS: MonitorDeRed.swift (NWPathMonitor).
 */
class MonitorDeRed(contexto: Context) {
    private val conectividad = contexto.applicationContext.getSystemService(ConnectivityManager::class.java)
    private val empezado = AtomicBoolean(false)

    fun empezar(alVolverLaRed: () -> Unit) {
        if (!empezado.compareAndSet(false, true)) return
        val sinRed = AtomicBoolean(conectividad?.activeNetwork == null)
        conectividad?.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                if (sinRed.getAndSet(false)) alVolverLaRed()
            }

            override fun onLost(network: Network) {
                sinRed.set(true)
            }
        })
    }
}
