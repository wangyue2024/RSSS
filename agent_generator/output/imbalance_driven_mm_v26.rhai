let initialized = false;
let fomo_triggered = false;
let last_price = 0;
let base_spread = 0;
let max_position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(10000, 30000);
        max_position = rng.rand_int(1000, 5000);
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let history_len = market.history_len();
    if history_len >= 5 {
        let price_5_ticks_ago = market.history_price(history_len - 5);
        let change_pct = (current_price - price_5_ticks_ago) * 10000 / price_5_ticks_ago;
        if change_pct > 200 && change_pct < 1000000 {
            fomo_triggered = true;
        }
    }
    
    if fomo_triggered {
        let buy_amount = max_position / 10;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        fomo_triggered = false;
        return;
    }
    
    let imbalance = market.order_imbalance;
    let imbalance_factor = imbalance * 10;
    
    let imbalance_adjustment = imbalance_factor;
    let mid_price = current_price + imbalance_adjustment;
    
    let bid_price = mid_price - base_spread / 2;
    let ask_price = mid_price + base_spread / 2;
    
    let min_bid = market.bid_price_4;
    let max_ask = market.ask_price_4;
    
    if bid_price < 1 { bid_price = 1; }
    if ask_price < 1 { ask_price = 1; }
    
    if bid_price > 0 && bid_price < market.price {
        let position_limit = max_position - account.stock;
        if position_limit > 0 {
            let order_size = position_limit / 10;
            if order_size > 0 {
                orders.submit_limit_buy(bid_price, order_size);
            }
        }
    }
    
    if ask_price > 0 && ask_price > market.price && account.stock > 0 {
        let sell_amount = account.stock / 10;
        if sell_amount > 0 {
            orders.submit_limit_sell(ask_price, sell_amount);
        }
    }
    
    last_price = current_price;
}