let prices_history = [];
let volumes_history = [];
let initialized = false;
let base_lot = 1000;
let next_lot = 1000;
let last_trade_avg_cost = 0;
let last_trade_stock = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(800, 1200);
        next_lot = base_lot;
    }
    
    if !market.trading_enabled { return; }
    
    prices_history.push(market.price);
    volumes_history.push(market.volume);
    
    if prices_history.len() > 5 {
        prices_history.remove(0);
        volumes_history.remove(0);
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock == 0 {
        last_trade_avg_cost = 0;
        last_trade_stock = 0;
    }
    
    if prices_history.len() == 5 {
        let price_5_ago = prices_history[0];
        let volume_5_ago = volumes_history[0];
        let ma_60_now = market.ma_60;
        let vol_threshold = 50000;
        
        if price_5_ago > ma_60_now && volume_5_ago < vol_threshold {
            let trade_amount = next_lot;
            
            if account.stock > 0 {
                orders.submit_market_sell(trade_amount);
            } else {
                orders.submit_market_sell(trade_amount);
            }
            
            if last_trade_stock != 0 {
                let current_val = market.price * abs_val(last_trade_stock);
                let cost_val = last_trade_avg_cost * abs_val(last_trade_stock);
                if ((last_trade_stock > 0 && market.price < last_trade_avg_cost) || 
                    (last_trade_stock < 0 && market.price > last_trade_avg_cost)) {
                    next_lot = base_lot * 2;
                } else {
                    next_lot = base_lot;
                }
            }
            
            last_trade_avg_cost = account.avg_cost;
            last_trade_stock = account.stock;
        }
    }
}