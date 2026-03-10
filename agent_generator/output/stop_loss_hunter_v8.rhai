let initialized = false;
let last_trade_loss = false;
let lot_size = 1000;
let tick_counter = 0;
let in_position = false;
let entry_price = 0;
let stop_hunt_active = false;
let stop_hunt_tick = 0;
let base_lot = 1000;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(800, 1200);
        lot_size = base_lot;
    }
    
    tick_counter += 1;
    
    if tick_counter % 50 != 0 { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let bid_vol_total = 0;
    let ask_vol_total = 0;
    
    let bid_price_1 = market.bid_price_0;
    let bid_vol_1 = market.bid_vol_0;
    let bid_price_2 = market.bid_price_1;
    let bid_vol_2 = market.bid_vol_1;
    let bid_price_3 = market.bid_price_2;
    let bid_vol_3 = market.bid_vol_2;
    let bid_price_4 = market.bid_price_3;
    let bid_vol_4 = market.bid_vol_3;
    
    if bid_price_1 > 0 && bid_price_1 < current_price * 98 / 100 && bid_price_1 > current_price * 95 / 100 {
        bid_vol_total += bid_vol_1;
    }
    if bid_price_2 > 0 && bid_price_2 < current_price * 98 / 100 && bid_price_2 > current_price * 95 / 100 {
        bid_vol_total += bid_vol_2;
    }
    if bid_price_3 > 0 && bid_price_3 < current_price * 98 / 100 && bid_price_3 > current_price * 95 / 100 {
        bid_vol_total += bid_vol_3;
    }
    if bid_price_4 > 0 && bid_price_4 < current_price * 98 / 100 && bid_price_4 > current_price * 95 / 100 {
        bid_vol_total += bid_vol_4;
    }
    
    let cluster_threshold = 5000;
    let sell_pressure = bid_vol_total > cluster_threshold && bid_vol_total * 3 > ask_vol_total;
    
    if stop_hunt_active && market.tick - stop_hunt_tick > 20 {
        stop_hunt_active = false;
    }
    
    if !in_position {
        if sell_pressure && !stop_hunt_active && rng.rand_bool(60) {
            orders.submit_market_sell(lot_size);
            in_position = true;
            entry_price = current_price;
            stop_hunt_active = true;
            stop_hunt_tick = market.tick;
        }
    } else {
        let unrealized_pnl = (current_price - entry_price) * market.stock;
        
        if unrealized_pnl > 50_000 || unrealized_pnl < -200_000 {
            orders.submit_market_buy(lot_size);
            
            if unrealized_pnl < 0 {
                last_trade_loss = true;
            } else {
                last_trade_loss = false;
            }
            
            if last_trade_loss {
                lot_size = lot_size * 2;
                lot_size = clamp_val(lot_size, 100, 10000);
            } else {
                lot_size = base_lot;
            }
            
            in_position = false;
            entry_price = 0;
        } else if stop_hunt_active && market.tick - stop_hunt_tick > 5 && current_price < entry_price * 97 / 100 {
            orders.submit_limit_buy(current_price * 95 / 100, lot_size);
        }
    }
    
    if !in_position && last_trade_loss && rng.rand_bool(30) {
        orders.submit_limit_buy(current_price * 99 / 100, lot_size);
    }
}