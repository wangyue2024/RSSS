let initialized = false;
let lot_size = 0;
let last_trade_was_loss = false;
let last_avg_cost = 0;
let state = 0;
let target_buy_price = 0;
let aggressive_sell_done = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(100, 500);
        last_avg_cost = 0;
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
    let last_avg = last_avg_cost;
    if last_avg > 0 {
        if (account.stock > 0 && current_price < last_avg) || (account.stock < 0 && current_price > last_avg) {
            last_trade_was_loss = true;
        } else {
            last_trade_was_loss = false;
        }
    }

    if last_trade_was_loss {
        lot_size = lot_size * 2;
        lot_size = clamp_val(lot_size, 100, 5000);
    }

    let lookback = 5;
    if market.history_len() < lookback { return; }
    let recent_prices = [];
    let j = 0;
    while j < lookback {
        recent_prices.push(market.history_price(j));
        j += 1;
    }
    let price_trend = arr_slope(recent_prices);

    let cluster_threshold = 2000;
    let bid_cluster_vol = market.bid_vol_0 + market.bid_vol_1 + market.bid_vol_2;
    let ask_cluster_vol = market.ask_vol_0 + market.ask_vol_1 + market.ask_vol_2;

    if state == 0 {
        if ask_cluster_vol > cluster_threshold && price_trend > -5000 && market.ask_price_0 < current_price + 5000 {
            let sell_amount = lot_size;
            if account.stock + sell_amount > -10000 {
                orders.submit_market_sell(sell_amount);
                aggressive_sell_done = true;
                state = 1;
                target_buy_price = current_price - 10000;
            }
        } else if bid_cluster_vol > cluster_threshold && price_trend < 5000 && market.bid_price_0 > current_price - 5000 {
            let buy_amount = lot_size;
            if account.cash > buy_amount * current_price / 1_000_000 {
                orders.submit_market_buy(buy_amount);
                aggressive_sell_done = false;
                state = 1;
                target_buy_price = current_price + 10000;
            }
        }
    } else if state == 1 {
        if aggressive_sell_done {
            if current_price <= target_buy_price || market.tick % 5 == 0 {
                let cover_amount = abs_val(account.stock);
                if cover_amount > 0 {
                    orders.submit_market_buy(cover_amount);
                }
                last_avg_cost = market.price;
                state = 0;
                aggressive_sell_done = false;
            }
        } else {
            if current_price >= target_buy_price || market.tick % 5 == 0 {
                let sell_amount = abs_val(account.stock);
                if sell_amount > 0 {
                    orders.submit_market_sell(sell_amount);
                }
                last_avg_cost = market.price;
                state = 0;
                aggressive_sell_done = false;
            }
        }
    }

    if my_orders.fill_count() > 0 {
        let last_fill_side = my_orders.fill_side(0);
        if last_fill_side == 1 {
            last_avg_cost = my_orders.fill_price(0);
        } else if last_fill_side == 2 {
            last_avg_cost = my_orders.fill_price(0);
        }
    }
}