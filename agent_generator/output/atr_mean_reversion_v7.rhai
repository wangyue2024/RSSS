let initialized = false;
let max_position = 1000;
let base_order_amount = 100;
let atr_multiplier = 150;
let half_atr_multiplier = 50;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    if market.tick % 50 != 0 { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_price = market.price;
    let ma20 = market.ma_20;
    let atr = market.atr_14;

    if atr <= 0 { return; }

    let price_deviation = abs_val(current_price - ma20);
    let threshold = (atr * atr_multiplier) / 100;

    if price_deviation > threshold {
        let half_atr = (atr * half_atr_multiplier) / 100;

        if current_price > ma20 && account.stock > 0 {
            let sell_price = ma20 + half_atr;
            let sell_amount = if account.stock < base_order_amount { account.stock } else { base_order_amount };
            if sell_amount > 0 {
                orders.submit_limit_sell(sell_price, sell_amount);
            }
        } else if current_price < ma20 && account.stock < max_position {
            let buy_price = ma20 - half_atr;
            let max_buy_by_cash = account.cash / buy_price;
            let buy_amount = if base_order_amount < max_buy_by_cash { base_order_amount } else { max_buy_by_cash };
            let max_by_position = max_position - account.stock;
            if buy_amount > max_by_position { buy_amount = max_by_position; }
            if buy_amount > 0 {
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
}