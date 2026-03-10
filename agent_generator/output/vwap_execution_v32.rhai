let initialized = false;
let target_shares = 0;
let remaining_shares = 0;
let base_lot_size = 0;
let recent_prices = [];
let max_trade_value = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        max_trade_value = account.total_equity * 5 / 100;
        if market.price > 0 {
            let max_shares = max_trade_value / market.price;
            if max_shares < 1 { max_shares = 1; }
            target_shares = rng.rand_int(1, max_shares);
            remaining_shares = target_shares;
            base_lot_size = rng.rand_int(1, target_shares);
            if base_lot_size < 1 { base_lot_size = 1; }
        }
        let i = 0;
        while i < 5 {
            recent_prices.push(market.price);
            i += 1;
        }
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if remaining_shares <= 0 { return; }

    recent_prices.push(market.price);
    if recent_prices.len() > 5 {
        recent_prices.remove(0);
    }

    if recent_prices.len() == 5 {
        let old_price = recent_prices[0];
        let change_threshold = old_price + (old_price * 2 / 100);
        if market.price > change_threshold && old_price > 0 {
            let buy_amount = remaining_shares;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
                remaining_shares = 0;
            }
            return;
        }
    }

    let std_dev_threshold = market.price * 2 / 100;
    if market.std_dev > std_dev_threshold { return; }

    let avg_volume = 0;
    let history_len = market.history_len();
    if history_len >= 5 {
        let volume_arr = [];
        let j = 0;
        while j < 5 {
            volume_arr.push(market.history_volume(j));
            j += 1;
        }
        avg_volume = arr_mean(volume_arr);
    } else {
        avg_volume = market.volume;
    }

    let volume_ratio = 100;
    if avg_volume > 0 {
        volume_ratio = (market.volume * 100) / avg_volume;
    }

    let dynamic_lot = (base_lot_size * volume_ratio) / 100;
    if dynamic_lot < 1 { dynamic_lot = 1; }
    let buy_amount = dynamic_lot;
    if buy_amount > remaining_shares {
        buy_amount = remaining_shares;
    }

    if buy_amount > 0 {
        orders.submit_limit_buy(market.price, buy_amount);
        remaining_shares -= buy_amount;
    }
}