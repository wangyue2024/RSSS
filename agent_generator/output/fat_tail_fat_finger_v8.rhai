let initialized = false;
let base_lot_size = 0;
let risk_seeking_factor = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_seeking_factor = rng.rand_int(30, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let cash_for_trade = account.cash * risk_seeking_factor / 100;
    if market.price > 0 {
        base_lot_size = cash_for_trade / market.price;
        if base_lot_size < 1 {
            base_lot_size = 1;
        }
    } else {
        base_lot_size = 1;
    }
    
    let fat_finger_chance = rng.rand_int(0, 9999);
    if fat_finger_chance == 0 {
        let fat_finger_size = base_lot_size * 100;
        let buy_or_sell = rng.rand_bool(50);
        
        if buy_or_sell && market.ask_price_0 > 0 {
            let max_affordable = account.cash / market.ask_price_0;
            let final_size = if fat_finger_size > max_affordable { max_affordable } else { fat_finger_size };
            if final_size > 0 {
                orders.submit_market_buy(final_size);
            }
        } else if !buy_or_sell && account.stock > 0 {
            let final_size = if fat_finger_size > account.stock { account.stock } else { fat_finger_size };
            if final_size > 0 {
                orders.submit_market_sell(final_size);
            }
        }
        return;
    }
    
    let normal_trade_chance = rng.rand_int(0, 99);
    if normal_trade_chance >= 90 {
        let side = rng.rand_bool(50);
        let round_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
        
        if side {
            if round_price > 0 && base_lot_size > 0 {
                orders.submit_limit_buy(round_price, base_lot_size);
            }
        } else {
            if round_price > 0 && base_lot_size > 0 && account.stock >= base_lot_size {
                orders.submit_limit_sell(round_price, base_lot_size);
            }
        }
    }
}