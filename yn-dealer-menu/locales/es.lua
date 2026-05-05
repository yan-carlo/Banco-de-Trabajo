Locales = Locales or {}

Locales['es'] = {
    -- ── Errores generales ─────────────────────────────────────────────────────
    ['no_job']               = 'No tienes el trabajo necesario para usar esto.',
    ['not_driver']           = 'Debes ser el conductor del vehículo.',
    ['vehicle_not_owned']    = 'Este vehículo no te pertenece.',
    ['vehicle_already_sale'] = 'Este vehículo ya está en venta.',
    ['max_vehicles']         = 'Has alcanzado el límite de vehículos en venta (%s).',
    ['cooldown']             = 'Debes esperar antes de poner otro vehículo en venta.',
    ['no_funds']             = 'No tienes suficiente dinero para realizar esta compra.',
    ['vehicle_not_found']    = 'El vehículo ya no está disponible.',
    ['player_not_found']     = 'El jugador no existe o no está conectado.',
    ['error_generic']        = 'Ha ocurrido un error. Inténtalo de nuevo.',
    ['invalid_data']         = 'Los datos enviados no son válidos.',
    ['invalid_price']        = 'El precio debe ser un número mayor a 0.',
    ['invalid_target']       = 'El ID de jugador introducido no es válido.',
    ['self_transfer']        = 'No puedes traspasarte un vehículo a ti mismo.',
    ['transfer_pending']     = 'Ya existe una solicitud de traspaso activa para ese jugador.',
    ['transfer_expired']     = 'La solicitud de traspaso ha expirado.',
    ['transfer_no_request']  = 'No tienes ninguna solicitud de traspaso pendiente.',
    ['own_vehicle_buy']      = 'No puedes comprarte tu propio vehículo.',

    -- ── Menú dealer ───────────────────────────────────────────────────────────
    ['menu_dealer_title']      = 'Menú Dealer',
    ['menu_list_vehicle']      = 'Poner vehículo en venta',
    ['menu_list_desc']         = 'Pon el vehículo en el que estás sentado en venta.',
    ['menu_transfer']          = 'Traspasar vehículo',
    ['menu_transfer_desc']     = 'Transfiere la titularidad del vehículo a otro jugador.',
    ['menu_my_vehicles']       = 'Mis vehículos en venta',
    ['menu_my_vehicles_desc']  = 'Gestiona tus vehículos publicados.',
    ['menu_no_vehicles']       = 'No tienes vehículos en venta actualmente.',
    ['menu_cancel_listing']    = 'Retirar de venta',
    ['menu_cancel_desc']       = 'Retira este vehículo del mercado.',
    ['menu_disabled_no_veh']   = 'Debes ser conductor de un vehículo.',

    -- ── Diálogos de input ─────────────────────────────────────────────────────
    ['input_price']      = 'Precio de venta ($)',
    ['input_price_ph']   = 'Ej: 50000',
    ['input_desc']       = 'Descripción (opcional)',
    ['input_desc_ph']    = 'Estado, extras, kilómetros...',
    ['input_target_id']  = 'ID del nuevo propietario',
    ['input_target_ph']  = 'ID de servidor del jugador',
    ['input_cancelled']  = 'Acción cancelada.',

    -- ── Acciones de venta ─────────────────────────────────────────────────────
    ['vehicle_listed']      = 'Vehículo puesto en venta por $%s.',
    ['vehicle_sold_seller'] = 'Tu %s ha sido vendido por $%s.',
    ['vehicle_sold_buyer']  = 'Has comprado el %s por $%s. ¡Ya es tuyo!',
    ['vehicle_cancelled']   = 'Vehículo retirado del mercado.',
    ['confirm_buy']         = '¿Confirmas la compra del %s por $%s?',
    ['confirm_cancel']      = '¿Seguro que quieres retirar este vehículo de la venta?',

    -- ── Menú comprador ────────────────────────────────────────────────────────
    ['menu_vehicle_title'] = 'Vehículo en Venta',
    ['menu_seller']        = 'Vendedor',
    ['menu_price_label']   = 'Precio',
    ['menu_performance']   = 'Rendimiento',
    ['menu_cosmetics']     = 'Personalización',
    ['menu_buy']           = 'Comprar por $%s',
    ['menu_close']         = 'Cerrar',
    ['menu_description']   = 'Descripción',

    -- ── Detalles de rendimiento ───────────────────────────────────────────────
    ['perf_engine']       = 'Motor',
    ['perf_brakes']       = 'Frenos',
    ['perf_transmission'] = 'Caja de cambios',
    ['perf_suspension']   = 'Suspensión',
    ['perf_armor']        = 'Blindaje',
    ['perf_turbo']        = 'Turbo',
    ['level']             = 'Nv. %s',
    ['yes']               = 'Sí',
    ['no']                = 'No',
    ['stock']             = 'Stock',

    -- ── Detalles de personalización ───────────────────────────────────────────
    ['cos_primary']   = 'Color Primario',
    ['cos_secondary'] = 'Color Secundario',
    ['cos_pearl']     = 'Perla',
    ['cos_wheel']     = 'Color Llantas',
    ['cos_tint']      = 'Tinte Ventanas',
    ['cos_neon']      = 'Neones',
    ['cos_xenon']     = 'Luces Xenón',
    ['cos_extras']    = 'Extras Activos',
    ['cos_livery']    = 'Livery',
    ['custom_rgb']    = 'Personalizado RGB(%s,%s,%s)',
    ['color_index']   = 'Color #%s',
    ['none']          = 'Ninguno',

    -- ── Traspaso ─────────────────────────────────────────────────────────────
    ['transfer_sent']         = 'Solicitud de traspaso enviada a %s. Expira en 60 s.',
    ['transfer_request']      = '%s quiere traspasarte el vehículo %s (%s).\n¿Aceptas?',
    ['transfer_accepted']     = 'Traspaso completado. El %s (%s) ya es tuyo.',
    ['transfer_received']     = 'El jugador aceptó el traspaso del %s.',
    ['transfer_rejected']     = 'El jugador rechazó el traspaso.',
    ['transfer_reject_notify']= 'Has rechazado el traspaso del %s.',

    -- ── Proximidad ───────────────────────────────────────────────────────────
    ['press_e'] = '[E] Ver detalles del vehículo',
}
