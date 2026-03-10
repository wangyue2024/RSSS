let strategy_initialized = false;
let trade_every_ticks = 50;
let fixed_order_amount = 100;

fn round_to_dollar(price_micros) {
    let remainder = price_micros % 1_000_000;
    let rounded = price_micros - remainder;
    if remainder >= 500_000 {
        rounded = rounded + 1_000_000;
    }
    if rounded < 1_000_000 {
        rounded = 1_000_000;
    }
    return rounded;
}

fn on_tick() {
    if !strategy_initialized {
        strategy_initialized = true;
    }

    if !market.trading_enabled {
        return;
    }

    if market.tick % trade_every_ticks != 0 {
        return;
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let order_id = my_orders.pending_id(i);
        orders.submit_cancel(order_id);
        i += 1;
    }

    let two_std = 2 * market.std_dev;
    let lower_band_raw = market.ma_20 - two_std;
    let upper_band_raw = market.ma_20 + two_std;

    let buy_price = round_to_dollar(lower_band_raw);
    let sell_price = round_to_dollar(upper_band_raw);

    if buy_price > 0 && sell_price > buy_price {
        if account.cash >= buy_price * fixed_order_amount {
            orders.submit_limit_buy(buy_price, fixed_order_amount);
        }
        if account.stock >= fixed_order_amount {
            orders.submit_limit_sell(sell_price, fixed_order_amount);
        }
    }
}