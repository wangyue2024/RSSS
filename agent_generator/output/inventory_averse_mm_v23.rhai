let initialized = false;
let panic_threshold = 0;
let price_history = [];
let DELAY_TICKS = 5;
let INVENTORY_TARGET = 0;
let MAX_INVENTORY = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(1_000_000, 5_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > DELAY_TICKS {
        price_history.remove(0);
    }
    
    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        } else if account.stock < 0 {
            orders.submit_market_buy(-account.stock);
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() < DELAY_TICKS {
        return;
    }
    
    let delayed_price = price_history[0];
    let inventory = account.stock;
    let base_spread = 10_000;
    let inventory_skew = 5_000;
    
    let bid_spread_adjust = 0;
    let ask_spread_adjust = 0;
    
    if inventory > MAX_INVENTORY {
        bid_spread_adjust = inventory_skew;
        ask_spread_adjust = -inventory_skew;
    } else if inventory <= INVENTORY_TARGET {
        bid_spread_adjust = -inventory_skew;
        ask_spread_adjust = inventory_skew;
    }
    
    let bid_price = delayed_price - (base_spread + bid_spread_adjust);
    let ask_price = delayed_price + (base_spread + ask_spread_adjust);
    let order_size = 100;
    
    if bid_price > 0 {
        orders.submit_limit_buy(bid_price, order_size);
    }
    if ask_price > 0 {
        orders.submit_limit_sell(ask_price, order_size);
    }
}