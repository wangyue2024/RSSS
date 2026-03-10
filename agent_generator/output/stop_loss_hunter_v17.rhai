let initialized = false;
let last_prices = [];
let cluster_threshold = 0;
let aggression_level = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        cluster_threshold = rng.rand_int(5000, 20000);
        aggression_level = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    last_prices.push(market.price);
    if last_prices.len() > 5 {
        last_prices.remove(0);
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if last_prices.len() < 5 { return; }
    
    let delayed_price = last_prices[0];
    let price_movement = market.price - delayed_price;
    
    let bid_cluster_volume = market.bid_vol_0 + market.bid_vol_1 + market.bid_vol_2;
    let ask_cluster_volume = market.ask_vol_0 + market.ask_vol_1 + market.ask_vol_2;
    
    let bid_price_range = abs_val(market.bid_price_0 - market.bid_price_2);
    let ask_price_range = abs_val(market.ask_price_0 - market.ask_price_2);
    
    let sell_pressure = ask_cluster_volume > bid_cluster_volume * 120 / 100;
    let tight_bid_range = bid_price_range < micros(0, 5);
    
    let target_buy_price = market.bid_price_0 * 98 / 100;
    let target_sell_price = market.ask_price_0 * 102 / 100;
    
    if sell_pressure && tight_bid_range && bid_cluster_volume > cluster_threshold {
        let sell_amt = cluster_threshold * aggression_level / 100;
        orders.submit_market_sell(sell_amt);
        
        let buy_back_amt = sell_amt * 110 / 100;
        orders.submit_limit_buy(target_buy_price, buy_back_amt);
    }
    
    if market.order_imbalance < -20000 && price_movement < 0 {
        let position_size = (account.cash * 30 / 100) / market.price;
        if position_size > 0 {
            orders.submit_limit_buy(target_buy_price, position_size);
        }
    }
    
    if my_orders.pending_count() == 0 && account.stock > 0 {
        let sell_position = account.stock * 20 / 100;
        if sell_position > 0 {
            orders.submit_limit_sell(target_sell_price, sell_position);
        }
    }
}