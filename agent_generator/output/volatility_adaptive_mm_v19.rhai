let initialized = false;
let lot_size = 0;
let spread_factor = 100;
let placed_orders = [];
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        let equity = account.total_equity;
        let max_lot_value = equity * 5 / 100;
        let est_lot = max_lot_value / market.price;
        if est_lot < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, est_lot);
        }
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 6 {
        price_history.remove(0);
    }
    
    if price_history.len() == 6 {
        let old_price = price_history[0];
        let change_pct = (market.price - old_price) * 10000 / old_price;
        if change_pct > 200 || change_pct < -200 {
            fomo_triggered = true;
        }
    }
    
    let volatility = market.std_dev;
    let vol_threshold = market.price * 300 / 10000;
    
    if fomo_triggered {
        let cancel_count = my_orders.pending_count();
        let i = 0;
        while i < cancel_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        orders.submit_market_buy(lot_size);
        fomo_triggered = false;
        return;
    }
    
    if volatility > vol_threshold {
        let cancel_count = my_orders.pending_count();
        let i = 0;
        while i < cancel_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let current_tick = market.tick;
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let vol_ratio = (volatility * 10000) / market.price;
    let dynamic_spread = 50 + vol_ratio * 2;
    spread_factor = clamp_val(dynamic_spread, 20, 500);
    
    let half_spread = spread_factor / 2;
    let buy_price = market.price * (10000 - half_spread) / 10000;
    let sell_price = market.price * (10000 + half_spread) / 10000;
    
    if account.stock < lot_size * 10 {
        orders.submit_limit_buy(buy_price, lot_size);
    }
    
    if account.stock > 0 {
        let sell_amount = if account.stock < lot_size { account.stock } else { lot_size };
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}