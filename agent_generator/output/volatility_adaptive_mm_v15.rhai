let initialized = false;
let base_spread_bps = 10;
let vol_sensitivity = 200;
let base_order_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_size = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all existing orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let mid_price = market.price;
    let vol_factor = market.std_dev * vol_sensitivity / 1_000_000;
    let spread_bps = base_spread_bps + vol_factor;
    let spread_micros = mid_price * spread_bps / 10000;
    
    let buy_price = mid_price - spread_micros;
    let sell_price = mid_price + spread_micros;
    
    // Place buy order if we have cash
    if account.cash > buy_price * base_order_size {
        orders.submit_limit_buy(buy_price, base_order_size);
    }
    
    // Diamond hands: only sell if profitable
    if account.stock > 0 && sell_price > account.avg_cost {
        let sell_amount = base_order_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}