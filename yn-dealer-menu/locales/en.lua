Locales = Locales or {}

Locales['en'] = {
    -- ── General errors ────────────────────────────────────────────────────────
    ['no_job']               = 'You do not have the required job to use this.',
    ['not_driver']           = 'You must be the driver of the vehicle.',
    ['vehicle_not_owned']    = 'This vehicle does not belong to you.',
    ['vehicle_already_sale'] = 'This vehicle is already listed for sale.',
    ['max_vehicles']         = 'You have reached the vehicle listing limit (%s).',
    ['cooldown']             = 'You must wait before listing another vehicle.',
    ['no_funds']             = 'You do not have enough money for this purchase.',
    ['vehicle_not_found']    = 'This vehicle is no longer available.',
    ['player_not_found']     = 'Player not found or not connected.',
    ['error_generic']        = 'An error occurred. Please try again.',
    ['invalid_data']         = 'Invalid data received.',
    ['invalid_price']        = 'Price must be a number greater than 0.',
    ['invalid_target']       = 'The player ID entered is not valid.',
    ['self_transfer']        = 'You cannot transfer a vehicle to yourself.',
    ['transfer_pending']     = 'There is already an active transfer request for that player.',
    ['transfer_expired']     = 'The transfer request has expired.',
    ['transfer_no_request']  = 'You have no pending transfer request.',
    ['own_vehicle_buy']      = 'You cannot buy your own vehicle.',

    -- ── Dealer menu ───────────────────────────────────────────────────────────
    ['menu_dealer_title']      = 'Dealer Menu',
    ['menu_list_vehicle']      = 'List Vehicle for Sale',
    ['menu_list_desc']         = 'List the vehicle you are currently driving for sale.',
    ['menu_transfer']          = 'Transfer Vehicle',
    ['menu_transfer_desc']     = 'Transfer vehicle ownership to another player.',
    ['menu_my_vehicles']       = 'My Vehicles for Sale',
    ['menu_my_vehicles_desc']  = 'Manage your listed vehicles.',
    ['menu_no_vehicles']       = 'You have no vehicles listed for sale.',
    ['menu_cancel_listing']    = 'Remove from Sale',
    ['menu_cancel_desc']       = 'Remove this vehicle from the market.',
    ['menu_disabled_no_veh']   = 'You must be the driver of a vehicle.',

    -- ── Input dialogs ─────────────────────────────────────────────────────────
    ['input_price']      = 'Sale Price ($)',
    ['input_price_ph']   = 'e.g. 50000',
    ['input_desc']       = 'Description (optional)',
    ['input_desc_ph']    = 'Condition, extras, mileage...',
    ['input_target_id']  = 'New owner ID',
    ['input_target_ph']  = 'Player server ID',
    ['input_cancelled']  = 'Action cancelled.',

    -- ── Sale actions ──────────────────────────────────────────────────────────
    ['vehicle_listed']      = 'Vehicle listed for $%s.',
    ['vehicle_sold_seller'] = 'Your %s has been sold for $%s.',
    ['vehicle_sold_buyer']  = 'You bought the %s for $%s. It\'s yours!',
    ['vehicle_cancelled']   = 'Vehicle removed from the market.',
    ['confirm_buy']         = 'Confirm purchase of %s for $%s?',
    ['confirm_cancel']      = 'Are you sure you want to remove this vehicle from sale?',

    -- ── Buyer menu ────────────────────────────────────────────────────────────
    ['menu_vehicle_title'] = 'Vehicle for Sale',
    ['menu_seller']        = 'Seller',
    ['menu_price_label']   = 'Price',
    ['menu_performance']   = 'Performance',
    ['menu_cosmetics']     = 'Customization',
    ['menu_buy']           = 'Buy for $%s',
    ['menu_close']         = 'Close',
    ['menu_description']   = 'Description',

    -- ── Performance details ───────────────────────────────────────────────────
    ['perf_engine']       = 'Engine',
    ['perf_brakes']       = 'Brakes',
    ['perf_transmission'] = 'Transmission',
    ['perf_suspension']   = 'Suspension',
    ['perf_armor']        = 'Armor',
    ['perf_turbo']        = 'Turbo',
    ['level']             = 'Lv. %s',
    ['yes']               = 'Yes',
    ['no']                = 'No',
    ['stock']             = 'Stock',

    -- ── Cosmetic details ──────────────────────────────────────────────────────
    ['cos_primary']   = 'Primary Color',
    ['cos_secondary'] = 'Secondary Color',
    ['cos_pearl']     = 'Pearl',
    ['cos_wheel']     = 'Wheel Color',
    ['cos_tint']      = 'Window Tint',
    ['cos_neon']      = 'Neon Lights',
    ['cos_xenon']     = 'Xenon Lights',
    ['cos_extras']    = 'Active Extras',
    ['cos_livery']    = 'Livery',
    ['custom_rgb']    = 'Custom RGB(%s,%s,%s)',
    ['color_index']   = 'Color #%s',
    ['none']          = 'None',

    -- ── Transfer ──────────────────────────────────────────────────────────────
    ['transfer_sent']         = 'Transfer request sent to %s. Expires in 60s.',
    ['transfer_request']      = '%s wants to transfer vehicle %s (%s) to you.\nDo you accept?',
    ['transfer_accepted']     = 'Transfer complete. The %s (%s) is now yours.',
    ['transfer_received']     = 'The player accepted the transfer of %s.',
    ['transfer_rejected']     = 'The player rejected the transfer.',
    ['transfer_reject_notify']= 'You rejected the transfer of %s.',

    -- ── Proximity ─────────────────────────────────────────────────────────────
    ['press_e'] = '[E] View vehicle details',
}
