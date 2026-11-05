# 11. Usabilidad y accesibilidad

## Automatizado (`mobile/test/task_list_screen_test.dart`)

| Verificación | Cómo |
|--------------|------|
| Objetivos táctiles ≥ 48×48 dp (Android) y ≥ 44×44 pt (iOS) | `meetsGuideline(androidTapTargetGuideline)`, `iOSTapTargetGuideline` |
| Todo control tocable tiene nombre accesible | `meetsGuideline(labeledTapTargetGuideline)` (los `IconButton` tienen `tooltip`) |
| Contraste de texto suficiente | `meetsGuideline(textContrastGuideline)` |
| Texto al 200 % en pantalla de 320×568 sin desbordes | `textScaleFactorTestValue = 2.0` + `tester.takeException()` es `null` |

## Decisiones de diseño

- El estado de una tarea se comunica con **texto** (*Pending* / *Completed*), además del tachado y la casilla: el color no es la única señal.
- Errores con `Semantics(liveRegion: true)` para que el lector de pantalla los anuncie.
- Los mensajes de error dicen cómo recuperarse (*Check your connection and try again*, *Try again*).
- Indicadores de carga con `semanticsLabel` (*Loading tasks*, *Saving*, *Signing in*).
- `AutofillHints` en email y contraseña.

## Checklist manual (TalkBack / VoiceOver + texto grande)

| Punto | Resultado |
|-------|-----------|
| Contraste suficiente en tema claro y oscuro | ☐ |
| Botones y campos con etiqueta clara | ☐ |
| El lector anuncia título, estado y errores en orden útil | ☐ |
| Usable con texto al tamaño máximo del sistema | ☐ |
| Objetivos táctiles fáciles de seleccionar | ☐ |
| Los errores explican cómo recuperarse | ☐ |
| El color no es la única señal | ☐ |
| Navegación con teclado / switch (Tab, Enter) | ☐ |

**Ejercicio:** activar TalkBack y el tamaño de fuente máximo, crear una tarea, provocar el error de título vacío y anotar controles sin etiqueta o recortados.

## Hallazgo: BUG-003

Al manejar la app por su árbol de accesibilidad, el botón Borrar de cada fila estaba fusionado con la casilla (`CheckboxListTile` usa `MergeSemantics`): activarlo completaba la tarea. Las guías automáticas no lo detectaron. Ya está corregido y tiene prueba de regresión ([03-reporte-de-bug.md](03-reporte-de-bug.md#bug-003--para-lectores-de-pantalla-borrar-marca-la-tarea-como-completada-encontrado-al-capturar-evidencias)).
