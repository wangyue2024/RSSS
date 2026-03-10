let initialized = false;
let price_history = [];
let order_timestamps = #{};

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let current_tick = market.tick;
    price_history.push(market.price);
    
    while price_history.len() > 6 {
        price_history.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if price_history.len() < 6 {
        return;
    }
    
    let delayed_price = price_history[0];
    let volatility = market.std_dev;
    
    let base_spread_bps = 50;
    let vol_adjustment = volatility * 200 / 10000;
    let total_spread_bps = base_spread_bps + vol_adjustment;
    
    let half_spread_micros = delayed_price * total_spread_bps / 20000;
    
    let raw_buy_price = delayed_price - half_spread_micros;
    let raw_sell_price = delayed_price + half_spread_micros;
    
    let rounded_buy_price = (raw_buy_price + 500000) / 1000000 * 1000000;
    let rounded_sell_price = (raw_sell_price + 500000) / 1000000 * 1000000;
    
    let buy_price = clamp_val(rounded_buy_price, 1000000, 1000000000);
    let sell_price = clamp_val(rounded_sell_price, 1000000, 1000000000);
    
    if buy_price < sell_price {
        let order_amount = 100;
        
        orders.submit_limit_buy(buy_price, order_amount);
        orders.submit_limit_sell(sell_price, order_amount);
    }
}