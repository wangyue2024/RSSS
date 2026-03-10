let initialized = false;
let entered = false;
let in_trade = false;
let entry_price = 0;
let last_eval_tick = -50;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    if market.tick - last_eval_tick < 50 { return; }
    last_eval_tick = market.tick;
    
    if !entered {
        if rng.rand_bool(1) {
            let amount = 100;
            let cost = market.ask_price_0 * amount;
            if cost <= account.cash {
                entry_price = market.ask_price_0;
                orders.submit_market_buy(amount);
                let tp_price = entry_price * 105 / 100;
                orders.submit_limit_sell(tp_price, amount);
                entered = true;
                in_trade = true;
            }
        }
    } else if in_trade {
        if account.stock == 0 {
            in_trade = false;
        } else {
            let stop_price = entry_price * 98 / 100;
            if market.price <= stop_price {
                let pending_cnt = my_orders.pending_count();
                let i = 0;
                while i < pending_cnt {
                    let oid = my_orders.pending_id(i);
                    orders.submit_cancel(oid);
                    i += 1;
                }
                orders.submit_market_sell(account.stock);
                in_trade = false;
            }
        }
    }
}