let initialized = false;
let base_qty = 1000;
let offset_frac = 2500;
let spread_threshold = 50000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    let high = market.high_20;
    let low = market.low_20;
    let spread = high - low;
    
    let qty = base_qty;
    if spread < spread_threshold {
        qty = qty * 2;
    }
    
    let offset = spread * offset_frac / 10000;
    let buy_price_target = low + offset;
    let sell_price_target = high - offset;
    
    let buy_price = buy_price_target + 1;
    let sell_price = sell_price_target;
    
    let max_buy = account.cash / buy_price;
    let buy_amount = qty;
    if buy_amount > max_buy { buy_amount = max_buy; }
    if buy_amount > 0 {
        orders.submit_limit_buy(buy_price, buy_amount);
    }
    
    let max_sell = account.stock;
    let sell_amount = qty;
    if sell_amount > max_sell { sell_amount = max_sell; }
    if sell_amount > 0 {
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}