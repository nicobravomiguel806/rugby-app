package mx.rugbyapp.app

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

/** Punto de entrada de Hilt (ADR 0005). */
@HiltAndroidApp
class RugbyApp : Application()
