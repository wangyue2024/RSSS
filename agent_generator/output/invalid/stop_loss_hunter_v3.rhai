let initialized = false;
let risk_percent = 0;
let state = 0;
let target_buy_price = 0;
let sold_amount = 0;
let consecutive_sells = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_percent = rng.rand_int(40, 50);
        state = 0;
        target_buy_price = 0;
        sold_amount = 0;
        consecutive_sells = 0;
    }

    if !market.trading_enabled {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_price = market.price;
    let cash_available = account.cash;

    if state == 0 {
        let position_cash = cash_available * risk_percent / 100;
        let buy_amount = position_cash * 1_000_000 / current_price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            state = 1;
        }
    } else if state == 1 {
        let total_bid_vol = 0;
        let max_bid_price = market.bid_price_0;
        let min_bid_price = market.bid_price_4;

        let j = 0;
        while j < 5 {
            total_bid_vol += get_market_bid_vol(j);
            j += 1;
        }

        let price_range = max_bid_price - min_bid_price;
        let range_percent = price_range * 10000 / current_price;

        if total_bid_vol > 2000 && range_percent < 150 {
            let sell_amount = account.stock;
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
                sold_amount = sell_amount;
                target_buy_price = current_price * 97 / 100;
                state = 2;
                consecutive_sells += 1;
            }
        }
    } else if state == 2 {
        if current_price <= target_buy_price {
            let buy_back_amount = sold_amount;
            if buy_back_amount > 0 {
                orders.submit_market_buy(buy_back_amount);
            }
            state = 0;
            target_buy_price = 0;
            sold_amount = 0;

            if consecutive_sells >= 2 {
                risk_percent = rng.rand_int(45, 60);
                consecutive_sells = 0;
            } else if rng.rand_bool(30) {
                risk_percent = rng.rand_int(40, 50);
            }
        }
    }
}

fn get_market_bid_vol(index) {
    if index == 0 { return market.bid_vol_0; }
    if index == 1 { return market.bid_vol_1; }
    if index == 2 { return market.bid_vol_2; }
    if index == 3 { return market.bid_vol_3; }
    if index == 4 { return market.bid_vol_4; }
    return 0;
}