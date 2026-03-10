let initialized = false;
let trade_cap_pct = 0;
let price_buffer = [];
let atr_buffer = [];
let ma_buffer = [];
let std_buffer = [];
let buffer_size = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_cap_pct = rng.rand_int(1, 4);
    }

    if !market.trading_enabled {
        return;
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_buffer.push(market.price);
    atr_buffer.push(market.atr_14);
    ma_buffer.push(market.ma_20);
    std_buffer.push(market.std_dev);

    if price_buffer.len() > buffer_size {
        price_buffer.remove(0);
        atr_buffer.remove(0);
        ma_buffer.remove(0);
        std_buffer.remove(0);
    }

    if price_buffer.len() < buffer_size {
        return;
    }

    let old_price = price_buffer[0];
    let old_atr = atr_buffer[0];
    let old_ma = ma_buffer[0];
    let old_std = std_buffer[0];

    if old_std > (market.price * 2) / 100 {
        return;
    }

    let max_trade_value = (account.total_equity * trade_cap_pct) / 100;
    let desired_shares = max_trade_value / market.price;
    if desired_shares < 1 {
        return;
    }

    let upper_band = old_ma + (15 * old_atr) / 10;
    let lower_band = old_ma - (15 * old_atr) / 10;

    let can_buy = account.cash > market.price && desired_shares >= 1;
    let can_sell = account.stock > 0 && market.price > account.avg_cost;

    if old_price > upper_band && can_sell {
        let sell_shares = if desired_shares > account.stock { account.stock } else { desired_shares };
        if sell_shares > 0 {
            orders.submit_limit_sell(market.price, sell_shares);
        }
    } else if old_price < lower_band && can_buy {
        let max_affordable = account.cash / market.price;
        let buy_shares = if desired_shares > max_affordable { max_affordable } else { desired_shares };
        if buy_shares > 0 {
            orders.submit_limit_buy(market.price, buy_shares);
        }
    }
}