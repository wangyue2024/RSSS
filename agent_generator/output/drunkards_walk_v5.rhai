let initialized = false;
let base_lot_size = 0;
let current_lot_size = 0;
let last_trade_price = 0;
let last_trade_side = 0;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(100, 500);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_idx = fill_cnt - 1;
        last_trade_price = my_orders.fill_price(last_idx);
        let side_str = my_orders.fill_side(last_idx);
        if side_str == "buy" {
            last_trade_side = 1;
        } else {
            last_trade_side = -1;
        }
    }
    
    if last_trade_price != 0 {
        let current_price = market.price;
        if (last_trade_side == 1 && current_price < last_trade_price) || (last_trade_side == -1 && current_price > last_trade_price) {
            current_lot_size = current_lot_size * 2;
            if current_lot_size > 10000 {
                current_lot_size = 10000;
            }
        } else {
            current_lot_size = base_lot_size;
        }
    }
    
    fomo_triggered = false;
    if market.history_len() >= 5 {
        let price_5_ago = market.history_price(4);
        let jump_threshold = price_5_ago * 2 / 100;
        if (market.price - price_5_ago) > jump_threshold {
            let buy_amount = current_lot_size * 2;
            orders.submit_market_buy(buy_amount);
            fomo_triggered = true;
        }
    }
    
    if !fomo_triggered {
        let rand_val = rng.rand_int(0, 99);
        
        if rand_val < 5 {
            let price_offset = rng.rand_int(-500, 500);
            let limit_price = market.price + price_offset;
            if limit_price < 1 {
                limit_price = 1;
            }
            let qty = rng.rand_int(1, current_lot_size);
            orders.submit_limit_buy(limit_price, qty);
        } else if rand_val > 95 {
            let price_offset = rng.rand_int(-500, 500);
            let limit_price = market.price + price_offset;
            if limit_price < 1 {
                limit_price = 1;
            }
            let qty = rng.rand_int(1, current_lot_size);
            orders.submit_limit_sell(limit_price, qty);
        }
    }
}