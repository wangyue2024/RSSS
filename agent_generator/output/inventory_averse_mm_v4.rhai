let initialized = false;
let panic_threshold = 0;
let fomo_window = 5;
let last_cancel_check = 0;
let order_lifespan = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(50000, 200000);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > order_lifespan {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    if market.history_len() >= fomo_window {
        let current_price = market.price;
        let old_price = market.history_price(fomo_window - 1);
        if old_price > 0 {
            let price_change = (current_price - old_price) * 10000 / old_price;
            if price_change > 200 {
                let buy_amount = account.cash * 100 / market.price;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
                return;
            }
        }
    }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let base_spread = mid_price * 20 / 10000;
    
    let buy_distance = base_spread;
    let sell_distance = base_spread;
    
    if account.stock > 1000 {
        buy_distance = base_spread * 3 / 2;
        sell_distance = base_spread / 2;
    } else if account.stock <= 0 {
        buy_distance = base_spread / 2;
        sell_distance = base_spread * 3 / 2;
    }
    
    let buy_price = mid_price - buy_distance;
    let sell_price = mid_price + sell_distance;
    
    let order_size = 100;
    
    if buy_price > 0 && buy_price < market.ask_price_0 {
        orders.submit_limit_buy(buy_price, order_size);
    }
    
    if sell_price > 0 && sell_price > market.bid_price_0 {
        orders.submit_limit_sell(sell_price, order_size);
    }
}