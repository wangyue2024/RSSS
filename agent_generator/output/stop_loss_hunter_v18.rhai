let initialized = false;
let last_action_tick = 0;
let lot_size = 100;
let base_lot_size = 100;
let last_trade_profit = true;
let pending_attack = false;
let attack_sell_price = 0;
let attack_start_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(80, 150);
        lot_size = base_lot_size;
        last_action_tick = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick - last_action_tick < 50 { return; }
    
    last_action_tick = market.tick;
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let profit_check = false;
    if account.stock > 0 && market.price < account.avg_cost {
        profit_check = false;
    } else if account.stock > 0 && market.price >= account.avg_cost {
        profit_check = true;
    } else {
        let fill_count = my_orders.fill_count();
        if fill_count > 0 {
            let last_fill_side = my_orders.fill_side(fill_count - 1);
            let last_fill_price = my_orders.fill_price(fill_count - 1);
            if last_fill_side == 0 {
                profit_check = market.price > last_fill_price;
            } else {
                profit_check = market.price < last_fill_price;
            }
        }
    }
    
    if !profit_check {
        lot_size = lot_size * 2;
        if lot_size > 1000 { lot_size = 1000; }
    } else {
        lot_size = base_lot_size;
    }
    
    if pending_attack {
        if market.tick - attack_start_tick > 5 {
            pending_attack = false;
        } else if market.price < attack_sell_price * 95 / 100 {
            orders.submit_limit_buy(market.price * 98 / 100, lot_size);
            pending_attack = false;
        }
        return;
    }
    
    if my_orders.pending_count() > 0 { return; }
    
    if market.price > market.low_20 * 101 / 100 && market.price < market.low_20 * 102 / 100 {
        let threshold_volume = 500;
        let support_level = market.low_20 * 99 / 100;
        let volume_below = 0;
        
        if market.bid_price_0 < support_level && market.bid_price_0 > 0 {
            volume_below += market.bid_vol_0;
        }
        if market.bid_price_1 < support_level && market.bid_price_1 > 0 {
            volume_below += market.bid_vol_1;
        }
        if market.bid_price_2 < support_level && market.bid_price_2 > 0 {
            volume_below += market.bid_vol_2;
        }
        
        if volume_below > threshold_volume {
            orders.submit_market_sell(lot_size);
            attack_sell_price = market.price;
            attack_start_tick = market.tick;
            pending_attack = true;
        }
    }
}