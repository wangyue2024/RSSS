let initialized = false;
let fixed_order_amount = 100;
let max_position = 1000;
let pending_order_placed_tick = 0;

fn is_exhaustion(price_condition) {
    let lookback = 20;
    let history_len = market.history_len();
    if history_len < lookback {
        return false;
    }
    let sum = 0;
    let i = 0;
    while i < lookback {
        sum += market.history_volume(i);
        i += 1;
    }
    let avg_volume = sum / lookback;
    if avg_volume == 0 {
        return false;
    }
    let volume_threshold = avg_volume / 10;
    return market.volume < volume_threshold && price_condition;
}

fn on_tick() {
    if !initialized {
        initialized = true;
        pending_order_placed_tick = market.tick;
    }

    if !market.trading_enabled {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if my_orders.pending_count() > 0 {
        return;
    }

    let exhaustion_top = is_exhaustion(market.price > market.ma_60);
    let exhaustion_bottom = is_exhaustion(market.price < market.ma_60);

    if exhaustion_bottom && account.cash > market.price * fixed_order_amount && account.stock < max_position {
        let buy_price = market.price;
        orders.submit_limit_buy(buy_price, fixed_order_amount);
        pending_order_placed_tick = market.tick;
    } else if exhaustion_top && account.stock >= fixed_order_amount && market.price > account.avg_cost {
        let sell_price = market.price;
        orders.submit_limit_sell(sell_price, fixed_order_amount);
        pending_order_placed_tick = market.tick;
    }
}