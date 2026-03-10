let initialized = false;
let fomo_active = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel any pending order older than 3 ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if (market.tick - placed) >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // FOMO check: price jump >2% in last 5 ticks
    if market.history_len() >= 5 {
        let current = market.price;
        let past = market.history_price(4);
        if past != 0 {
            let change_pct = (current - past) * 10000 / past;
            if change_pct > 200 {
                fomo_active = true;
                orders.submit_market_buy(100);
                return;
            }
        }
    }
    
    // Reset FOMO after acting
    fomo_active = false;
    
    // Core random strategy
    let dice = rng.rand_int(0, 99);
    
    if dice < 5 {
        // Random buy
        let qty = rng.rand_int(1, 100);
        let offset = rng.rand_int(-500, 500);
        let price = market.price + offset;
        if price > 0 {
            orders.submit_limit_buy(price, qty);
        }
    } else if dice > 95 && market.price > account.avg_cost {
        // Random sell only if profitable
        let qty = rng.rand_int(1, 100);
        if qty > account.stock {
            qty = account.stock;
        }
        if qty > 0 {
            let offset = rng.rand_int(-500, 500);
            let price = market.price + offset;
            if price > 0 {
                orders.submit_limit_sell(price, qty);
            }
        }
    }
}