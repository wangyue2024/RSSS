let initialized = false;
let buy_edge_pct = 0;
let sell_edge_pct = 0;
let order_lifetime = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        buy_edge_pct = rng.rand_int(5, 15);
        sell_edge_pct = rng.rand_int(5, 15);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let high_20 = market.high_20;
    let low_20 = market.low_20;
    let spread = high_20 - low_20;
    let avg_price = (high_20 + low_20) / 2;
    
    let min_spread = micros(0, 500);
    let pos_multiplier = 1000;
    if spread < min_spread {
        pos_multiplier = 2000;
    }
    
    if spread > 0 {
        let buy_offset = spread * buy_edge_pct / 100;
        let buy_price = low_20 + buy_offset;
        
        let max_buy_cash = account.cash;
        let buy_amount_raw = max_buy_cash * pos_multiplier / micros(1, 0) / 1000;
        let buy_amount = clamp_val(buy_amount_raw, 1, 10000);
        
        if buy_price < market.price && buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    let stock_held = account.stock;
    let avg_cost = account.avg_cost;
    
    if stock_held > 0 && avg_cost > 0 && market.price > avg_cost && spread > 0 {
        let sell_offset = spread * sell_edge_pct / 100;
        let sell_price = high_20 - sell_offset;
        
        let sell_pct = 5000;
        let sell_amount_raw = stock_held * sell_pct / 10000;
        let sell_amount = clamp_val(sell_amount_raw, 1, stock_held);
        
        if sell_price > market.price && sell_price > avg_cost && sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}