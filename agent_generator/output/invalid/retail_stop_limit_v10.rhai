let initialized = false;
let have_position = false;
let entry_price = 0;
let panic_threshold = 0;
let base_lot_size = 100;
let current_lot_size = base_lot_size;
let last_trade_profit = true;
let tp_order_id = 0;
let sl_order_active = false;
let last_check_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(-500000, -100000);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if !have_position {
        if account.stock == 0 && rng.rand_bool(1) {
            let buy_price = market.price * 105 / 100 + 1;
            orders.submit_limit_buy(buy_price, current_lot_size);
            have_position = true;
            entry_price = buy_price;
            
            let tp_price = entry_price * 105 / 100;
            tp_order_id = orders.submit_limit_sell(tp_price, current_lot_size);
            sl_order_active = false;
            last_check_tick = market.tick;
        }
    } else {
        if account.stock == 0 {
            have_position = false;
            return;
        }
        
        if account.unrealized_pnl < panic_threshold {
            orders.submit_market_sell(account.stock);
            have_position = false;
            last_trade_profit = false;
            current_lot_size = current_lot_size * 2;
            return;
        }
        
        if !sl_order_active && market.tick > last_check_tick {
            let sl_trigger = entry_price * 98 / 100;
            if market.price <= sl_trigger {
                orders.submit_market_sell(account.stock);
                have_position = false;
                last_trade_profit = false;
                current_lot_size = current_lot_size * 2;
                return;
            }
            last_check_tick = market.tick;
        }
        
        let fill_cnt = my_orders.fill_count();
        let j = 0;
        while j < fill_cnt {
            let fill_side = my_orders.fill_side(j);
            let fill_price = my_orders.fill_price(j);
            if fill_side == 1 && fill_price >= entry_price * 105 / 100 {
                have_position = false;
                last_trade_profit = true;
                current_lot_size = base_lot_size;
                return;
            }
            j += 1;
        }
    }
}