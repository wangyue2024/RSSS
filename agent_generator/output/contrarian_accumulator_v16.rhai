let initialized = false;
let price_history = [];
let rsi_history = [];
let last_buy_avg = 0;
let lot_size = 20;
let last_trade_was_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(20, 100);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    // Update delayed data buffers
    price_history.push(market.price);
    rsi_history.push(market.rsi_14);
    
    if price_history.len() > 5 {
        price_history.remove(0);
        rsi_history.remove(0);
    }
    
    // Martingale sizing logic
    if last_trade_was_loss {
        lot_size = lot_size * 2;
        if lot_size > 100 { lot_size = 100; }
    } else {
        if lot_size < 20 { lot_size = 20; }
    }
    
    // Check fills to determine last trade outcome
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        let latest_fill_side = my_orders.fill_side(fill_count - 1);
        if latest_fill_side == "sell" && last_buy_avg > 0 {
            let fill_price = my_orders.fill_price(fill_count - 1);
            if fill_price < last_buy_avg {
                last_trade_was_loss = true;
            } else {
                last_trade_was_loss = false;
                lot_size = rng.rand_int(20, 100);
            }
            last_buy_avg = 0;
        } else if latest_fill_side == "buy" {
            last_buy_avg = account.avg_cost;
        }
    }
    
    // Only trade if we have 5 ticks of historical data
    if price_history.len() < 5 { return; }
    
    let delayed_rsi = rsi_history[0];
    let delayed_price = price_history[0];
    
    // Contrarian trading logic using delayed data
    if delayed_rsi < 3000 && account.stock < 1000 {
        let buy_price = delayed_price * 99 / 100;
        orders.submit_limit_buy(buy_price, lot_size);
    } else if delayed_rsi > 7000 && account.stock > 0 {
        let sell_price = delayed_price * 101 / 100;
        orders.submit_limit_sell(sell_price, account.stock);
    }
}