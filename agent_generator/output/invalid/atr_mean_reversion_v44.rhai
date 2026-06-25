let initialized = false;
let base_lot_size = 0;
let position = 0;
let last_action_tick = -1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(100000, 500000);
        position = 0;
        last_action_tick = -1000;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let atr = market.atr_14;
    let ma20 = market.ma_20;
    let price = market.price;
    let deviation = price - ma20;
    let abs_dev = abs_val(deviation);
    let threshold = (atr * 15) / 10;

    if abs_dev > threshold {
        let ticks_since_last = market.tick - last_action_tick;
        if ticks_since_last > 10 {
            if deviation < 0 && position <= 0 {
                let max_by_cash = (account.cash * 50) / (100 * price);
                let buy_amount = clamp_val(base_lot_size, 100, max_by_cash);
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                    position = 1;
                    last_action_tick = market.tick;
                }
            } else if deviation > 0 && position >= 0 {
                let max_by_stock = account.stock;
                let sell_amount = clamp_val(base_lot_size, 100, max_by_stock);
                if sell_amount > 0 {
                    orders.submit_market_sell(sell_amount);
                    position = -1;
                    last_action_tick = market.tick;
                }
            }
        }
    }

    if position != 0 && abs_dev < (atr * 5) / 10 {
        if position > 0 && account.stock > 0 {
            orders.submit_market_sell(account.stock);
            position = 0;
            last_action_tick = market.tick;
        } else if position < 0 && account.cash > price {
            let max_by_cash = account.cash / price;
            let cover_amount = clamp_val(base_lot_size, 100, max_by_cash);
            if cover_amount > 0 {
                orders.submit_market_buy(cover_amount);
                position = 0;
                last_action_tick = market.tick;
            }
        }
    }
}