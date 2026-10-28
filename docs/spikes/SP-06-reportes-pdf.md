# SP-06 · Reporte de partido en PDF (pendiente, S10)

**Como** Administrador de Torneo **quiero** que el reporte del partido salga en PDF firmado **para** sustituir el acta en papel (KR4 del socio).

- **Pregunta:** ¿generar el PDF en el dispositivo (PDFKit / PdfDocument, funciona offline) o en una Edge Function (un solo diseño para ambas plataformas)?
- **Plan:** prototipo de ambas opciones con el mismo reporte; comparar tiempo, peso del archivo, igualdad visual entre plataformas y si el PDF queda firmado (hash del contenido + quién firma).
- **Criterios de aceptación:**
  - Diseño: el PDF se genera desde `match_events`, nunca desde datos capturados a mano.
  - Interfaz gráfica: vista previa antes de firmar; botón "Firmar y cerrar" de 44 pt.
  - Escenarios de prueba: CP-072 (reporte completo) y CP-157 (el PDF guarda el hash de los eventos y no se puede alterar sin detectarlo).
- **Time-box:** 2 pts.
