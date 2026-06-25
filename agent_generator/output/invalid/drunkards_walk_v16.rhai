let price_history = [];
let fomo_triggered = false;
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() >= 2 {
        let old_price = price_history[0];
        let change_pct = (market.price - old_price) * 10000 / old_price;
        if change_pct > 200 {
            fomo_triggered = true;
            let buy_qty = rng.rand_int(1, 100);
            orders.submit_market_buy(buy_qty);
            return;
        }
    }
    
    fomo_triggered = false;
    
    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 {
        let qty = rng.rand_int(1, 100);
        let offset = rng.rand_int(-5000, 5000);
        let target_price = market.price + offset;
        let rounded_price = ((target_price + 500_000) / 1_000_000) * 1_000_000;
        if rounded_price > 0 {
            orders.submit_limit_buy(rounded_price, qty);
        }
    } else if rand_val > 95 && market.price > account.avg_cost {
        let qty = rng.rand_int(1, 100);
        if qty > account.stock {
            qty = account.stock;
        }
        if qty > 0 {
            let offset = rng.rand_int(-5000, 5000);
            let target_price = market.price + offset;
            let rounded_price = ((target_price + 500_000) / 1_000_000) * 1_000_000;
            if rounded_price > 0 {
                orders.submit_limit_sell(rounded_price, qty);
            }
        }
    }
}