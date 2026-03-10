let initialized = false;
let lot_size = 0;
let price_jump_threshold = 20000;
let inventory_threshold = 1000;
let max_lot_pct = 500;
let volatility_threshold = 500000;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_cap = account.total_equity / 10000 * max_lot_pct;
        lot_size = rng.rand_int(1, max_cap);
        if lot_size < 1 { lot_size = 1; }
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        return;
    }
    
    let fomo_window = 10;
    if market.history_len() >= fomo_window {
        let past_price = market.history_price(market.history_len() - fomo_window);
        let price_change = abs_val(market.price - past_price) * 10000 / past_price;
        if price_change > price_jump_threshold {
            orders.submit_market_buy(lot_size);
            return;
        }
    }
    
    if market.std_dev > volatility_threshold {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let inventory = account.stock;
    let spread = market.ask_price_0 - market.bid_price_0;
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    
    let buy_distance = spread * 5 / 10;
    let sell_distance = spread * 5 / 10;
    
    if inventory > inventory_threshold {
        buy_distance = spread * 7 / 10;
        sell_distance = spread * 3 / 10;
    } else if inventory <= 0 {
        buy_distance = spread * 3 / 10;
        sell_distance = spread * 7 / 10;
    }
    
    let buy_price = market.bid_price_0 - buy_distance;
    let sell_price = market.ask_price_0 + sell_distance;
    
    if buy_price > 0 {
        orders.submit_limit_buy(buy_price, lot_size);
    }
    
    if sell_price > 0 {
        orders.submit_limit_sell(sell_price, lot_size);
    }
}