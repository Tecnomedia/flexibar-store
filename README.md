# flexibar-store

Catalogo publico de Apps preconfiguradas para FlexibarNET. Servido por GitHub Pages:
`https://tecnomedia.github.io/flexibar-store/catalog.json`.

## Publicar o actualizar una App

1. Exportar la App desde FlexibarNET (Launcher → Exportar) o generarla con el flujo
   de app-authoring del repo principal.
2. `./publish.ps1 -PackPath <fichero.flexiapp.json> -Id <slug> -Category "<categoria>" [-Tags a,b] [-MinAppVersion 1.6.0] [-Changelog "..."]`
3. `git add -A && git commit && git push` — Pages publica en ~1 minuto.

El `id` es la identidad estable de la App: NUNCA cambiarlo entre versiones.
La `version` la incrementa el script automaticamente.
