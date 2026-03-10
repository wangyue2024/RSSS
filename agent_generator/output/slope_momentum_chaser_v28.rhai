let initialized = false;
let base_lot = 100;
let last_slope = 0;
let last_trade_loss = false;
let lot_multiplier = 1;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(80, 120);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    let fill_cnt = my_orders.fill_count();
    let j = 0;
    while j < fill_cnt {
        let side = my_orders.fill_side(j);
        if side == "sell" {
            let fill_price = my_orders.fill_price(j);
            if fill_price < account.avg_cost {
                last_trade_loss = true;
                lot_multiplier = lot_multiplier * 2;
            } else {
                last_trade_loss = false;
                lot_multiplier = 1;
            }
        }
        j += 1;
    }

    let lookback = 20;
    let current_slope = 0;
    if market.history_len() >= lookback {
        let price_arr = [];
        let idx = 0;
        while idx < lookback {
            price_arr.push(market.history_price(market.history_len() - 1 - idx));
            idx += 1;
        }
        current_slope = arr_slope(price_arr);
    }

    let aggressive_buy = false;
    if current_slope > 1000 && current_slope > last_slope * 120 / 100 {
        aggressive_buy = true;
    }

    let panic_sell = false;
    if current_slope < -500 {
        panic_sell = true;
    }

    let current_lot = base_lot * lot_multiplier;

    if account.stock > 0 {
        if panic_sell && market.price > account.avg_cost {
            orders.submit_market_sell(account.stock);
        } else if market.price > account.avg_cost * 105 / 100 {
            let sell_amt = current_lot;
            if sell_amt > account.stock {
                sell_amt = account.stock;
            }
            if sell_amt > 0 {
                orders.submit_limit_sell(market.price, sell_amt);
            }
        }
    } else {
        if aggressive_buy {
            let buy_amt = current_lot * 3;
            let max_afford = account.cash / market.price;
            if buy_amt > max_afford {
                buy_amt = max_afford;
            }
            if buy_amt > 0 {
                orders.submit_limit_buy(market.price, buy_amt);
            }
        } else if current_slope > 0 {
            let buy_amt = current_lot;
            let max_afford = account.cash / market.price;
            if buy_amt > max_afford {
                buy_amt = max_afford;
            }
            if buy_amt > 0 {
                orders.submit_limit_buy(market.ask_price_0, buy_amt);
            }
        }
    }

    last_slope = current_slope;
}