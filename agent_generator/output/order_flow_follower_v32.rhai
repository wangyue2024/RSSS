let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;
    
    if buy_vol > 3 * sell_vol {
        let raw_price = market.price;
        let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        let max_afford = account.cash / rounded_price;
        let amount = clamp_val(100, 1, max_afford);
        if amount > 0 {
            orders.submit_limit_buy(rounded_price, amount);
        }
    } else if sell_vol > 3 * buy_vol {
        let raw_price = market.price;
        let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        let amount = clamp_val(100, 1, account.stock);
        if amount > 0 {
            orders.submit_limit_sell(rounded_price, amount);
        }
    }
}