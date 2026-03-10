let initialized = false;
let hunting_mode = false;
let target_buy_price = 0;
let pending_buy_id = 0;
let cluster_threshold = 15_000_000;
let push_size = 0;
let morning_end_tick = 0;

fn round_to_dollar(price) {
    ((price + 500_000) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        cluster_threshold = rng.rand_int(10_000_000, 20_000_000);
        morning_end_tick = market.total_ticks / 5;
    }
    
    if market.tick >= morning_end_tick {
        return;
    }
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if hunting_mode && pending_buy_id == 0 {
        let buy_amount = push_size;
        if buy_amount > 0 && account.cash >= target_buy_price * buy_amount / 1_000_000 {
            orders.submit_limit_buy(target_buy_price, buy_amount);
        }
        hunting_mode = false;
    }
    
    pending_buy_id = 0;
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        if my_orders.pending_side(j) == 0 {
            pending_buy_id = my_orders.pending_id(j);
        }
        j += 1;
    }
    
    if hunting_mode && pending_buy_id == 0 {
        hunting_mode = false;
    }
    
    if !hunting_mode && account.stock > 0 && market.price > account.avg_cost {
        let cluster_pressure = 0;
        if market.bid_price_0 > 0 && market.price - market.bid_price_0 < 5_000_000 {
            cluster_pressure += market.bid_vol_0;
        }
        if market.bid_price_1 > 0 && market.price - market.bid_price_1 < 5_000_000 {
            cluster_pressure += market.bid_vol_1;
        }
        if market.bid_price_2 > 0 && market.price - market.bid_price_2 < 5_000_000 {
            cluster_pressure += market.bid_vol_2;
        }
        
        if cluster_pressure > cluster_threshold {
            push_size = account.stock * 10 / 100;
            if push_size < 1 { push_size = 1; }
            if push_size > account.stock { push_size = account.stock; }
            
            orders.submit_market_sell(push_size);
            
            let target_price = market.price * 98 / 100;
            target_buy_price = round_to_dollar(target_price);
            hunting_mode = true;
        }
    }
}