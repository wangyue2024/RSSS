let initialized = false;
let base_atr_multiplier = 150;
let fomo_window = 5;
let fomo_threshold_percent = 2;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_atr_multiplier = rng.rand_int(130, 170);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_price = market.price;
    let ma_20 = market.ma_20;
    let atr_14 = market.atr_14;

    if market.history_len() >= fomo_window {
        let price_n_ticks_ago = market.history_price(fomo_window - 1);
        if price_n_ticks_ago > 0 {
            let price_change_micros = abs_val(current_price - price_n_ticks_ago) * 100;
            let percent_change = price_change_micros / price_n_ticks_ago;
            if percent_change > fomo_threshold_percent {
                let cash_available = account.cash;
                if cash_available > current_price {
                    let buy_amount = cash_available / current_price;
                    if buy_amount > 0 {
                        orders.submit_market_buy(buy_amount);
                    }
                }
                return;
            }
        }
    }

    if atr_14 == 0 { return; }
    let deviation = current_price - ma_20;
    let abs_deviation = abs_val(deviation);
    let threshold = (atr_14 * base_atr_multiplier) / 100;

    if abs_deviation > threshold {
        let position_size = 0;
        if deviation > 0 {
            if account.stock > 0 {
                position_size = account.stock / 10;
                if position_size > 0 {
                    let limit_price = current_price - (current_price * 1) / 1000;
                    orders.submit_limit_sell(limit_price, position_size);
                }
            }
        } else {
            let cash_available = account.cash;
            if cash_available > current_price {
                position_size = (cash_available / current_price) / 10;
                if position_size > 0 {
                    let limit_price = current_price + (current_price * 1) / 1000;
                    orders.submit_limit_buy(limit_price, position_size);
                }
            }
        }
    }
}