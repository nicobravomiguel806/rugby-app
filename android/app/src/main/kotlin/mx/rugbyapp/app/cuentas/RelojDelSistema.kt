package mx.rugbyapp.app.cuentas

import mx.rugbyapp.domain.cuentas.Reloj

/** C-02 · Reloj real para la vigencia de 7 días de las revocaciones pendientes (ADR 0010). Espejo en iOS: RelojDelSistema.swift. */
class RelojDelSistema : Reloj {
    override fun ahoraEnSegundos(): Long = System.currentTimeMillis() / 1_000
}
