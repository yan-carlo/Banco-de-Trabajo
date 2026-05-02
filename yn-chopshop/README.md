# yn-chopshop

Sistema de robo de vehículo y desguace para FiveM. Compatible con ESX y QBCore.

## Dependencias

- `ox_lib`
- `ox_target`
- `ox_inventory`
- `origen_police`
- `es_extended` o `qb-core`

## Instalación

1. Coloca la carpeta `yn-chopshop` en tu directorio `resources/`.
2. Añade `ensure yn-chopshop` a tu `server.cfg`.
3. Ejecuta `sql/install.sql` en tu base de datos (opcional, solo para logs).
4. Añade los ítems a `ox_inventory` (ver sección de ítems).
5. Ajusta las coordenadas en `config/config.lua`.

## Ítems requeridos en ox_inventory

Añade estos ítems al archivo `items.lua` de ox_inventory:

```lua
['chop_door'] = {
    label  = 'Puerta de vehículo',
    weight = 15000,
    stack  = false,
    close  = false,
},
['chop_wheel'] = {
    label  = 'Rueda de vehículo',
    weight = 12000,
    stack  = false,
    close  = false,
},
```

## Configuración de origen_police

El recurso intenta llamar al export `createDispatch` de `origen_police`.
Si tu versión usa una firma diferente, ajusta la llamada en `server/main.lua`
en el evento `yn-chopshop:server:policeAlert`.

## Props de piezas

Los props visuales (`prop_wheel_01`, `prop_rub_boxpile_02`) pueden no existir
en todos los packs de streaming. Cámbialos en `config/config.lua` por props
válidos de tu servidor si los modelos predeterminados no cargan.

## Flujo del trabajo

1. Jugador interactúa con el NPC contacto (ox_target).
2. Aparece radio de búsqueda en el mapa y blip del vehículo objetivo.
3. Jugador roba el vehículo y lo lleva al desguace.
4. En el desguace, el jugador interactúa con la zona para entregar el vehículo.
5. El vehículo queda bloqueado. Aparece el NPC comprador.
6. Jugador usa ox_target sobre el vehículo para quitar cada pieza.
7. Animación + barra de progreso para cada pieza.
8. Al quitar la primera pieza → alerta a policía vía `origen_police`.
9. Prop en la mano del jugador → lleva la pieza al NPC comprador.
10. NPC da dinero por cada pieza.
11. Al vender todas → vehículo eliminado, NPC comprador desaparece.
12. Cooldown de 5 minutos antes del siguiente trabajo.

## Seguridad

- Solo **un trabajo activo** a la vez en el servidor.
- Toda la validación ocurre en el servidor (posición, propiedad del trabajo, existencia de pieza).
- El dinero y los ítems se otorgan únicamente desde el servidor.
- Rate limiting implícito por el sistema de trabajo único y cooldown.
