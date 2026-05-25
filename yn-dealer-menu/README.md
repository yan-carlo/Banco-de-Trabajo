# yn-dealer-menu

Menú profesional de dealer para FiveM. Permite a jugadores con el job configurado poner vehículos en venta y gestionar traspasos de titularidad, sin NUI y compatible con ESX y QBCore.

## Características

- Poner cualquier vehículo propio en venta con precio y descripción
- Vehículo se congela en su posición con blip visible en el mapa
- Cualquier jugador puede interactuar con el coche para ver detalles y comprar
- Detalles completos: rendimiento (motor, caja, frenos, suspensión, turbo) y personalización (colores, neones, xenón, livery, extras)
- Traspaso de vehículo con confirmación bidireccional (60 s para aceptar)
- El importe de cada venta se deposita en la cuenta del local via `origen_masterjob`
- Compatible con **ESX** y **QBCore** (detección automática)
- Sin NUI — usa menús de `ox_lib`
- Validaciones de seguridad completas en servidor

## Dependencias

| Recurso | Descripción |
|---|---|
| `ox_lib` | Menús, inputs, notificaciones |
| `oxmysql` | Base de datos |
| `origen_masterjob` | Depósito de ventas al local |
| `es_extended` o `qb-core` | Framework del servidor |

## Instalación

1. Copia la carpeta `yn-dealer-menu` en tu directorio de recursos.
2. Ejecuta `sql/install.sql` en tu base de datos.
3. Añade `ensure yn-dealer-menu` en tu `server.cfg` **después** de `ox_lib`, `oxmysql` y el framework.
4. Ajusta `config/config.lua` según tu servidor.

## Configuración principal (`config/config.lua`)

| Variable | Por defecto | Descripción |
|---|---|---|
| `Config.Framework` | `'auto'` | `'auto'`, `'esx'` o `'qbcore'` |
| `Config.Locale` | `'es'` | Idioma (`'es'` o `'en'`) |
| `Config.DealerJob` | `'dealer'` | Job requerido para abrir el menú |
| `Config.DealerCommand` | `'dealer'` | Comando (sin `/`) |
| `Config.InteractionDist` | `4.0` | Metros para ver el prompt `[E]` |
| `Config.MaxVehiclesOnSale` | `10` | Máximo de coches en venta simultáneos por dealer |
| `Config.SaleCooldown` | `30000` | ms entre listados consecutivos |
| `Config.MasterjobResource` | `'origen_masterjob'` | Nombre del recurso de masterjob |
| `Config.MasterjobAccount` | `'dealer'` | Cuenta donde se depositan las ventas |
| `Config.CommissionPct` | `0` | % de comisión que retiene el local (0 = 100 % al local) |

## Uso

### Como dealer

```
/dealer   →  abre el menú principal
```

- **Poner vehículo en venta**: debes estar conduciendo el vehículo. Se pedirá precio y descripción opcional. El coche queda congelado con blip en el mapa.
- **Traspasar vehículo**: debes estar conduciendo el vehículo. Introduce el ID de servidor del nuevo propietario. El receptor dispone de 60 s para aceptar.
- **Mis vehículos en venta**: lista y permite retirar tus coches publicados.

### Como comprador

Acércate a cualquier coche con blip amarillo en el mapa y pulsa `E` para ver detalles y comprarlo.

## Estructura

```
yn-dealer-menu/
├── client/
│   ├── main.lua           Menú dealer, proximidad, freeze/unfreeze
│   └── vehicle_utils.lua  Lectura de datos del vehículo y helpers
├── server/
│   ├── main.lua           Validaciones, BD, eventos, traspaso
│   └── callbacks.lua      Callbacks ox_lib
├── locales/
│   ├── es.lua
│   └── en.lua
├── config/
│   └── config.lua
├── sql/
│   └── install.sql
└── fxmanifest.lua
```

## Versión

`1.0.0` — YN Scripts
