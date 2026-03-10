let initialized = false;
let cooldown = 0;
let position_size = 10_000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    // Morning person: only trade in first 20% of session
    if market.tick >= market.total_ticks / 5 {
        return;
    }

    // Cancel any pending orders each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Cooldown decrement
    if cooldown > 0 {
        cooldown -= 1;
    }

    // Order flow logic: buy if buy_volume > 3 * sell_volume
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;
    
    if buy_vol > 3 * sell_vol && cooldown == 0 {
        let cash_available = account.cash;
        let max_buyable = cash_available / market.ask_price_0;
        let amount_to_buy = arr_min([position_size, max_buyable]);
        
        if amount_to_buy > 0 {
            orders.submit_market_buy(amount_to_buy);
            cooldown = 5;
        }
    }
}