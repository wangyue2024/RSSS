let initialized = false;
let position_size = 100;
let threshold_basis = 5000;
let max_wait_ticks = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        position_size = rng.rand_int(80, 120);
        threshold_basis = rng.rand_int(3000, 7000);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let i = 0;
    let pending = my_orders.pending_count();
    while i < pending {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= max_wait_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let threshold = market.vwap * threshold_basis / 1000000;
    let buy_price_target = market.vwap - threshold;
    
    let has_pending = my_orders.pending_count() > 0;
    let current_position = account.stock;
    
    if !has_pending {
        if current_position <= 0 && market.price < buy_price_target {
            let bid_price = buy_price_target + 1;
            let amount = clamp_val(position_size, 1, account.cash / bid_price);
            if amount > 0 {
                orders.submit_limit_buy(bid_price, amount);
            }
        } else if current_position > 0 && market.price >= market.vwap {
            let ask_price = market.vwap;
            let amount = clamp_val(position_size, 1, current_position);
            if amount > 0 {
                orders.submit_limit_sell(ask_price, amount);
            }
        }
    }
}