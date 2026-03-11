let last_rebalance_tick = -10;
let lot_multiplier = 0;
let pending_orders = [];
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_multiplier = rng.rand_int(25, 50);
    }
    
    if !market.trading_enabled {
        return;
    }

    let current_tick = market.tick;
    
    let i = 0;
    let pcount = my_orders.pending_count();
    while i < pcount {
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if current_tick - last_rebalance_tick >= 10 {
        let equity = account.total_equity;
        let stock_value = account.stock * market.price;
        let stock_pct = if equity == 0 { 0 } else { stock_value * 100 / equity };

        if stock_pct > 55 {
            let over_value = stock_value - (equity * 50 / 100);
            let target_sell_value = over_value * lot_multiplier / 100;
            let sell_amount = target_sell_value / market.price;
            if sell_amount > 0 && market.bid_price_0 != 0 {
                let limit_price = market.bid_price_0;
                orders.submit_limit_sell(limit_price, sell_amount);
            }
        } else if stock_pct < 45 {
            let under_value = (equity * 50 / 100) - stock_value;
            let cash_to_use = account.cash * lot_multiplier / 100;
            let buy_value = if under_value < cash_to_use { under_value } else { cash_to_use };
            let buy_amount = buy_value / market.price;
            if buy_amount > 0 && market.ask_price_0 != 0 {
                let limit_price = market.ask_price_0;
                orders.submit_limit_buy(limit_price, buy_amount);
            }
        }

        last_rebalance_tick = current_tick;
    }
}