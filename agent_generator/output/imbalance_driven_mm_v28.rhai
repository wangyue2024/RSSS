let initialized = false;
let personality = 0;
let base_spread = 0;
let lot_size = 0;
let max_position = 0;
let volatility_threshold = 0;
let last_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        personality = rng.rand_int(0, 1);
        
        if personality == 0 {
            base_spread = rng.rand_int(200, 1000);
            let capital = account.total_equity;
            let price_for_calc = market.price;
            if price_for_calc == 0 { price_for_calc = 1_000_000; }
            let max_shares = (capital * 5 / 100) / price_for_calc;
            if max_shares < 1 { max_shares = 1; }
            lot_size = rng.rand_int(1, max_shares);
            max_position = lot_size * 10;
            volatility_threshold = rng.rand_int(3000, 10000);
        } else {
            base_spread = rng.rand_int(50, 200);
            let capital = account.total_equity;
            let price_for_calc = market.price;
            if price_for_calc == 0 { price_for_calc = 1_000_000; }
            let max_shares = (capital * 50 / 100) / price_for_calc;
            if max_shares < 1 { max_shares = 1; }
            lot_size = rng.rand_int(max_shares / 2, max_shares);
            max_position = lot_size * 100;
            volatility_threshold = 1000000;
        }
        
        last_price = market.price;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if personality == 0 && market.std_dev > volatility_threshold {
        return;
    }
    
    let current_position = account.stock;
    
    let best_bid = market.bid_price_0;
    let best_ask = market.ask_price_0;
    
    let mid_price;
    if best_bid > 0 && best_ask > 0 {
        mid_price = (best_bid + best_ask) / 2;
    } else {
        mid_price = last_price;
    }
    
    let imbalance = market.order_imbalance;
    let imbalance_factor = clamp_val(imbalance / 100, -500, 500);
    
    let adjusted_mid = mid_price + imbalance_factor;
    
    let half_spread = base_spread / 2;
    let bid_price = adjusted_mid - half_spread;
    let ask_price = adjusted_mid + half_spread;
    
    if bid_price < 1 { bid_price = 1; }
    if ask_price <= bid_price { ask_price = bid_price + 1; }
    
    let max_buy_by_cash = account.cash / ask_price;
    let max_buy_by_position = max_position - current_position;
    let buy_amount = lot_size;
    if buy_amount > max_buy_by_cash { buy_amount = max_buy_by_cash; }
    if buy_amount > max_buy_by_position { buy_amount = max_buy_by_position; }
    
    let max_sell_by_stock = account.stock;
    let max_sell_by_position = current_position + max_position;
    let sell_amount = lot_size;
    if sell_amount > max_sell_by_stock { sell_amount = max_sell_by_stock; }
    if sell_amount > max_sell_by_position { sell_amount = max_sell_by_position; }
    
    if buy_amount > 0 && max_buy_by_position > 0 {
        orders.submit_limit_buy(bid_price, buy_amount);
    }
    
    if sell_amount > 0 && max_sell_by_position > 0 {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
    
    last_price = market.price;
}