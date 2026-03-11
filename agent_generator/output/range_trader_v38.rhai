let initialized = false;
let base_lot_percent = 0;
let edge_buffer_percent = 0;
let min_spread_threshold = 0;
let aggressive_multiplier = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_percent = rng.rand_int(35, 50);
        edge_buffer_percent = rng.rand_int(5, 15);
        min_spread_threshold = rng.rand_int(5000, 15000);
        aggressive_multiplier = rng.rand_int(2, 4);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let high = market.high_20;
    let low = market.low_20;
    let spread = high - low;
    
    if spread < min_spread_threshold {
        return;
    }
    
    let available_cash = account.cash;
    let position_size_base = available_cash * base_lot_percent / 100;
    
    let spread_narrow = spread < min_spread_threshold * 2;
    let position_multiplier = if spread_narrow { aggressive_multiplier } else { 1 };
    let position_size = position_size_base * position_multiplier;
    
    let buy_offset = spread * edge_buffer_percent / 100;
    let sell_offset = spread * edge_buffer_percent / 100;
    
    let buy_price = low + buy_offset;
    let sell_price = high - sell_offset;
    
    let buy_amount = position_size / market.price;
    if buy_amount > 0 && buy_price < sell_price && available_cash > position_size {
        orders.submit_limit_buy(buy_price, buy_amount);
    }
    
    let sell_amount = buy_amount;
    if sell_amount > 0 && account.stock >= sell_amount && buy_price < sell_price {
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}