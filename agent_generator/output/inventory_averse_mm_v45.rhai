let initialized = false;
let lot_size = 0;
let base_spread = 0;
let skew_factor = 0;
let cancel_threshold_ticks = 3;

fn on_tick() {
    if !market.trading_enabled {
        return;
    }

    if !initialized {
        initialized = true;
        let cash_pct = rng.rand_int(30, 50);
        let price_for_size = if market.price > 0 { market.price } else { 1_000_000 };
        lot_size = (account.cash * cash_pct / 100) / price_for_size;
        if lot_size < 100 {
            lot_size = 100;
        }
        base_spread = rng.rand_int(500, 3000);
        skew_factor = rng.rand_int(200, 1000);
    }

    let current_tick = market.tick;
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > cancel_threshold_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let inventory = account.stock;
    let mid_price = if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        (market.bid_price_0 + market.ask_price_0) / 2
    } else {
        market.price
    };

    let buy_spread = base_spread;
    let sell_spread = base_spread;

    let adjusted_buy_spread = if inventory > 1000 {
        buy_spread + skew_factor
    } else {
        if inventory <= 0 {
            buy_spread - skew_factor
        } else {
            buy_spread
        }
    };

    let adjusted_sell_spread = if inventory > 1000 {
        sell_spread - skew_factor
    } else {
        if inventory <= 0 {
            sell_spread + skew_factor
        } else {
            sell_spread
        }
    };

    let final_buy_spread = if adjusted_buy_spread < 100 { 100 } else { adjusted_buy_spread };
    let final_sell_spread = if adjusted_sell_spread < 100 { 100 } else { adjusted_sell_spread };

    let buy_price = mid_price - final_buy_spread;
    let sell_price = mid_price + final_sell_spread;

    if buy_price > 0 {
        let max_affordable = account.cash / buy_price;
        let buy_amount = if max_affordable < lot_size { max_affordable } else { lot_size };
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }

    if sell_price > 0 && account.stock > 0 {
        let sell_amount = if account.stock < lot_size { account.stock } else { lot_size };
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}