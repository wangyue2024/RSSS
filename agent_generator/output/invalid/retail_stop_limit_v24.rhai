let entered = false;
let state = 0;
let entry_price = 0;
let take_profit_price = 0;
let stop_loss_price = 0;
let position_amount = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !entered && market.tick < market.total_ticks / 5 {
        let chance = rng.rand_int(1, 100);
        if chance <= 5 {
            let side = rng.rand_bool(50);
            let amount = rng.rand_int(1, 10);
            
            if side {
                orders.submit_market_buy(amount);
                state = 1;
            } else {
                orders.submit_market_sell(amount);
                state = 2;
            }
            entered = true;
        }
    }
    
    if state == 1 || state == 2 {
        let fill_count = my_orders.fill_count();
        let i = 0;
        while i < fill_count {
            let fill_side = my_orders.fill_side(i);
            if (state == 1 && fill_side == 0) || (state == 2 && fill_side == 1) {
                entry_price = my_orders.fill_price(i);
                position_amount = my_orders.fill_amount(i);
                
                if state == 1 {
                    take_profit_price = entry_price * 105 / 100;
                    stop_loss_price = entry_price * 98 / 100;
                    orders.submit_limit_sell(take_profit_price, position_amount);
                    state = 3;
                } else {
                    take_profit_price = entry_price * 95 / 100;
                    stop_loss_price = entry_price * 102 / 100;
                    orders.submit_limit_buy(take_profit_price, position_amount);
                    state = 4;
                }
            }
            i += 1;
        }
    }
    
    if state == 3 {
        if market.price <= stop_loss_price {
            let pending_count = my_orders.pending_count();
            let i = 0;
            while i < pending_count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            orders.submit_market_sell(position_amount);
            state = 5;
        }
    }
    
    if state == 4 {
        if market.price >= stop_loss_price {
            let pending_count = my_orders.pending_count();
            let i = 0;
            while i < pending_count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            orders.submit_market_buy(position_amount);
            state = 5;
        }
    }
    
    if state >= 3 && account.stock == 0 {
        state = 5;
    }
}