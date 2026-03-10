let initialized = false;
let base_lot = 1000;
let current_lot = base_lot;
let last_trade_was_loss = false;
let stop_loss_ticks = 10;
let last_breakout_tick = -100;

fn round_to_nearest_micro(price) {
    let remainder = price % 1_000_000;
    if remainder < 500_000 {
        price - remainder
    } else {
        price + (1_000_000 - remainder)
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_ticks = rng.rand_int(8, 15);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock > 0 {
        let avg = account.avg_cost;
        let stop_price = avg - (stop_loss_ticks * 10_000);
        if market.price <= stop_price {
            orders.submit_market_sell(account.stock);
            last_trade_was_loss = market.price < avg;
            if last_trade_was_loss {
                current_lot = current_lot * 2;
                current_lot = clamp_val(current_lot, base_lot, 10_0000);
            } else {
                current_lot = base_lot;
            }
            return;
        }
    }
    
    let breakout_condition = market.price > market.high_20 && (market.tick - last_breakout_tick) > 5;
    if breakout_condition && account.stock == 0 {
        last_breakout_tick = market.tick;
        let rounded_price = round_to_nearest_micro(market.price);
        let buy_price = rounded_price + 10_000;
        let buy_amount = current_lot;
        if buy_amount > 0 && account.cash >= buy_price * buy_amount {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
}