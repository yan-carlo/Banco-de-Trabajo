# Plano de Funcionamiento — `yn-dealer-menu`

## Resumen General

Script sin NUI para servidores FiveM que otorga a jugadores con el **Job de dealer** un menú (vía `ox_lib`) con dos funcionalidades principales:

1. **Poner vehículo en venta** — el dealer congela el coche donde está aparcado y queda disponible para que cualquier jugador lo compre.
2. **Traspaso de vehículo** — el dealer gestiona la transferencia de titularidad de un vehículo entre dos jugadores con confirmación bidireccional.

---

## Dependencias

| Recurso | Uso |
|---|---|
| `ox_lib` | Menús contextuales, diálogos de input, notificaciones, targets de proximidad |
| `origen_masterjob` | Depositar el importe de la venta en la cuenta del local/empresa |
| `oxmysql` | Persistencia de vehículos en venta |
| `es_extended` / `qb-core` | Detección automática de framework (ESX o QBCore) |

---

## Estructura de Archivos

```
yn-dealer-menu/
├── client/
│   ├── main.lua          ← Menú dealer, hilo de proximidad, freeze local
│   └── vehicle_utils.lua ← Helpers: leer todos los mods/colores del vehículo
├── server/
│   ├── main.lua          ← Validaciones, BD, traspasos, depósito de dinero
│   └── callbacks.lua     ← Callbacks oxmysql y helpers de servidor
├── locales/
│   ├── es.lua
│   └── en.lua
├── config/
│   └── config.lua
├── sql/
│   └── install.sql
├── fxmanifest.lua
└── README.md
```

---

## Base de Datos

### Tabla `dealer_vehicles` — vehículos en venta

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | INT AUTO_INCREMENT PK | Identificador único |
| `seller_id` | VARCHAR(60) | Identifier del vendedor |
| `seller_name` | VARCHAR(100) | Nombre del vendedor |
| `plate` | VARCHAR(20) UNIQUE | Matrícula del vehículo |
| `model_hash` | VARCHAR(50) | Nombre legible del modelo |
| `vehicle_data` | LONGTEXT | JSON con colores, mods estéticos y de rendimiento |
| `price` | INT | Precio de venta |
| `pos_x / pos_y / pos_z / pos_h` | FLOAT | Posición de congelado |
| `network_id` | INT | Network ID del vehículo para freeze/sync |
| `status` | ENUM | `sale` \| `sold` \| `cancelled` |
| `created_at` | TIMESTAMP | Fecha de creación |
| `updated_at` | TIMESTAMP | Última actualización |

> **No hay tabla de traspasos** — el traspaso modifica directamente `owned_vehicles` (ESX) o `player_vehicles` (QBCore).

---

## Configuración (`config/config.lua`)

```lua
Config = {}

Config.Framework        = 'auto'      -- 'esx' | 'qbcore' | 'auto'
Config.Locale           = 'es'
Config.Debug            = false

Config.DealerJob        = 'dealer'    -- Job requerido para abrir el menú
Config.DealerCommand    = 'dealer'    -- /dealer abre el menú
Config.InteractionDist  = 4.0         -- Distancia para ver coches en venta
Config.PollingInterval  = 2000        -- ms entre actualizaciones del hilo de proximidad

Config.MasterjobAccount = 'dealer'    -- Cuenta de origen_masterjob donde ingresan las ventas
Config.CommissionPct    = 0           -- % de comisión que retiene el local (0 = 100% al local)

Config.MaxVehiclesOnSale = 10         -- Máximo simultáneo de coches en venta por dealer
Config.SaleCooldown      = 30000      -- ms entre ventas consecutivas del mismo dealer

Config.Blip = {
    sprite = 326,
    color  = 2,
    scale  = 0.8,
    label  = 'Vehículo en Venta',
}
```

---

## Opciones del Menú Principal Dealer

```
┌──────────────────────────────────┐
│       Menú Dealer                │
├──────────────────────────────────┤
│  Poner vehículo en venta         │  ← solo si es conductor
│  Traspasar vehículo              │  ← solo si es conductor
│  Ver mis vehículos en venta      │  ← lista + opción de retirar
│  Retirar vehículo de venta       │  ← sub-opción del anterior
└──────────────────────────────────┘
```

---

## Flujo 1 — Poner Coche en Venta

### Diagrama de secuencia

```
[Cliente] Jugador escribe /dealer
    └─► Verificar: ¿tiene job dealer?        → No → notificación de error
    └─► Verificar: ¿es conductor?            → No → notificación de error
    └─► Abrir menú ox_lib

[Cliente] Selecciona "Poner vehículo en venta"
    └─► lib.inputDialog:
            · Precio (number, requerido, min 1)
            · Descripción opcional (string)
    └─► Recopilar datos del vehículo:
            · Matrícula (GetVehicleNumberPlateText)
            · Modelo (GetEntityModel → GetDisplayNameFromVehicleModel)
            · Coordenadas + heading actuales
            · Colores: primario, secundario, perla, ruedas, tyresmoke
            · Mods estéticos: spoiler, bumpers, skirts, escape, capó,
              alerón, rejilla, techo, bocina, livery, tinte de ventanas,
              luces xenón, neones (color + estado por lado), estilo de matrícula
            · Mods de rendimiento: motor, caja, frenos, suspensión, turbo, blindaje
            · Extras activos (IsVehicleExtraTurnedOn 1-12)
    └─► TriggerServerEvent('yn-dealer:server:listVehicle', datos)

[Servidor] Recibe evento
    └─► Validar job dealer del source
    └─► Validar que la matrícula pertenece al jugador en BD
    └─► Validar que no está ya en venta
    └─► Validar cooldown del dealer
    └─► Validar límite máximo de coches en venta
    └─► INSERT en dealer_vehicles con status='sale'
    └─► TriggerClientEvent('yn-dealer:client:freezeVehicle', source, networkId, recordId)

[Cliente] Recibe freezeVehicle
    └─► FreezeEntityPosition(vehículo, true)
    └─► SetEntityInvincible(vehículo, true)
    └─► Crear blip en las coordenadas del coche
    └─► Notificación de éxito con precio
```

### Datos de vehículo guardados en `vehicle_data` (JSON)

```json
{
  "colors": {
    "primary":   [R, G, B],
    "secondary": [R, G, B],
    "pearl":     0,
    "wheel":     0,
    "tyresmoke": [R, G, B]
  },
  "mods": {
    "engine": 3, "brakes": 2, "transmission": 3,
    "suspension": 0, "armor": 0, "turbo": true,
    "spoiler": 0, "bumper_f": -1, "bumper_r": -1,
    "skirt": -1, "exhaust": -1, "livery": -1,
    "horn": 0, "window_tint": 0,
    "xenon": false, "xenon_color": 0
  },
  "neon": {
    "left": false, "right": false,
    "front": false, "back": false,
    "color": [R, G, B]
  },
  "extras":      [1, 4, 7],
  "plate_style": 0
}
```

---

## Flujo 2 — Comprar Vehículo en Venta

### Detección de proximidad (cliente, hilo permanente)

```
CreateThread — Wait(Config.PollingInterval) lejos, Wait(500) cerca

Cada ciclo:
    └─► Lista activa cacheada en cliente (se refresca desde servidor cada 10 s)
    └─► Para cada vehículo en venta:
            · Calcular distancia player ↔ coords del vehículo
            · Si < Config.InteractionDist:
                  Mostrar "[E] Ver detalles del vehículo"
                  Si IsControlJustPressed(0, 38):
                      AbrirMenuVehiculo(recordId)
```

### Menú de detalle del vehículo (ox_lib context menu)

```
┌────────────────────────────────────────────────┐
│  Sultan RS                                     │
│  Vendido por: John Doe                         │
│  Precio: $45,000                               │
├────────────────────────────────────────────────┤
│  [Ver detalles de rendimiento]                 │
│    → Motor Nv.4, Caja Nv.3, Frenos Nv.2,      │
│       Suspensión Nv.1, Turbo: Sí, Blindaje Nv.0│
│  [Ver personalización]                         │
│    → Color primario / secundario / perla       │
│       Neones, Tinte ventanas, Xenón, Extras    │
│  [Comprar por $45,000]                         │
│  [Cerrar]                                      │
└────────────────────────────────────────────────┘
```

### Secuencia de compra

```
[Cliente] Pulsa "Comprar"
    └─► lib.alertDialog("¿Confirmas la compra por $X?")
    └─► TriggerServerEvent('yn-dealer:server:buyVehicle', recordId)

[Servidor]
    └─► Verificar status='sale' (lock optimista)
    └─► Verificar fondos suficientes del comprador
    └─► Transacción atómica:
            1. Descontar dinero al comprador
            2. Transferir propiedad:
               ESX    → UPDATE owned_vehicles  SET owner=newIdentifier  WHERE plate=?
               QBCore → UPDATE player_vehicles SET citizenid=newCitizenId WHERE plate=?
            3. UPDATE dealer_vehicles SET status='sold'
            4. exports['origen_masterjob']:depositMoney(
                   Config.MasterjobAccount, price, 'Venta vehiculo '..plate
               )
    └─► TriggerClientEvent('yn-dealer:client:vehicleSold', -1, networkId, recordId)

[Cliente — todos]
    └─► Si networkId coincide con un vehículo congelado local:
            FreezeEntityPosition(veh, false)
            SetEntityInvincible(veh, false)
    └─► Eliminar de la lista de coches en venta y destruir blip
```

---

## Flujo 3 — Traspaso de Vehículo

```
[Cliente — dealer conductor del vehículo]
Selecciona "Traspasar vehículo"
    └─► lib.inputDialog:
            · ID de servidor del nuevo propietario (number)
    └─► TriggerServerEvent('yn-dealer:server:initiateTransfer', targetServerId, plate)

[Servidor]
    └─► Validar job dealer del source
    └─► Validar que la matrícula pertenece al source en BD
    └─► Validar que targetServerId está conectado y existe
    └─► Guardar solicitud en memoria con timeout de 60 s:
            transferRequests[targetSource] = {
                dealer    = source,
                plate     = plate,
                model     = modelName,
                expireAt  = GetGameTimer() + 60000
            }
    └─► TriggerClientEvent('yn-dealer:client:transferRequest', targetSource, {
            dealerName, plate, modelName, expireSeconds = 60
        })

[Cliente — jugador receptor]
    └─► lib.alertDialog:
            "El dealer [nombre] quiere traspasarte el vehículo
             [modelo] ([matrícula]). ¿Aceptas?"
            [Aceptar] / [Rechazar]
    └─► TriggerServerEvent('yn-dealer:server:respondTransfer', accepted)

[Servidor — respuesta]
    Si accepted y no expirado:
        └─► Transferir propiedad en BD (igual que en compra)
        └─► Notificar a ambos jugadores
        └─► Limpiar transferRequests[targetSource]
    Si rechazado o expirado:
        └─► Notificar al dealer
        └─► Limpiar transferRequests[targetSource]
```

---

## Sistema de Eventos

| Evento | Dirección | Descripción |
|---|---|---|
| `yn-dealer:server:listVehicle` | C → S | Poner coche en venta |
| `yn-dealer:server:buyVehicle` | C → S | Comprar coche en venta |
| `yn-dealer:server:initiateTransfer` | C → S | Iniciar traspaso |
| `yn-dealer:server:respondTransfer` | C → S | Respuesta del receptor al traspaso |
| `yn-dealer:server:cancelListing` | C → S | Retirar coche de venta |
| `yn-dealer:client:freezeVehicle` | S → C | Congelar vehículo tras listar |
| `yn-dealer:client:vehicleSold` | S → C (all) | Descongelar y limpiar tras venta |
| `yn-dealer:client:transferRequest` | S → C | Solicitud de traspaso al receptor |
| `yn-dealer:client:syncListings` | S → C | Sincronizar lista completa al conectar |

---

## Integración `origen_masterjob`

```lua
-- Al confirmar una venta en el servidor:
exports['origen_masterjob']:depositMoney(
    Config.MasterjobAccount,        -- nombre de la cuenta del local dealer
    price,                          -- importe (íntegro o con comisión aplicada)
    'Venta vehiculo: ' .. plate     -- concepto visible en el local
)
```

Si `Config.CommissionPct > 0`, el cálculo sería:

```lua
local netAmount = math.floor(price * (1 - Config.CommissionPct / 100))
```

---

## Ciclo de Vida de un Vehículo en Venta

```
Listado
   │
   ▼
En Venta  ──────────────────────┐
(congelado, blip activo,        │
 interactuable por todos)       │
   │                            │
   ├─── Comprado ───►  Vendido  │
   │    (descongelado,          │
   │     ownership → comprador, │
   │     dinero → masterjob)    │
   │                            │
   └─── Dealer retira ─► Cancelado
        (descongelado,
         sin cambio de propietario)
```

---

## Seguridad

- Toda validación de **job, propiedad, fondos y cooldowns** ocurre exclusivamente en el servidor.
- El cliente solo envía `networkId` y `plate`; **nunca el precio ni el identifier**.
- Cooldown por jugador para evitar spam de listados (`GetGameTimer()`).
- Las solicitudes de traspaso expiran en **60 segundos** en memoria de servidor.
- Todas las consultas SQL usan **parámetros preparados** (nunca concatenación).
- `CheckCooldown` aplicado a todos los eventos sensibles del servidor.
- Validación de tipos y rangos en cada dato recibido del cliente.

---

## Optimización

- El hilo de proximidad usa `Wait(Config.PollingInterval)` (2 s por defecto) cuando el jugador está lejos, y reduce a `Wait(500)` al acercarse a un vehículo en venta.
- La lista de vehículos en venta se cachea en el cliente y se refresca cada 10 s desde el servidor, evitando queries continuas a BD.
- Los blips y las entidades congeladas se gestionan solo en el cliente propietario o en todos tras un evento de sincronización.

---

## Nomenclatura de Eventos

Todos los eventos siguen el formato:

```
'yn-dealer:lado:accion'

Ejemplos:
  yn-dealer:server:listVehicle
  yn-dealer:client:freezeVehicle
  yn-dealer:server:buyVehicle
```
