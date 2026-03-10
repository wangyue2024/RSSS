let initialized = false;
let last_active_tick = -1000;
let max_hold_ticks = 3;
let risk_factor = 0;
let lot_size_multiplier = 0;
let cooldown_counter = 0;
let detection_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_factor = rng.rand_int(75, 100);
        lot_size_multiplier = rng.rand_int(40, 60);
        detection_threshold = rng.rand_int(200, 800);
    }

    if !market.trading_enabled { return; }

    let tick = market.tick;
    if tick % 50 != 0 && cooldown_counter == 0 {
        return;
    }

    if cooldown_counter > 0 {
        cooldown_counter -= 1;
    }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let placed = my_orders.pending_placed_tick(i);
        if tick - placed >= max_hold_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if cooldown_counter > 0 {
        return;
    }

    let current_price = market.price;
    let lookback_ticks = 30;
    let potential_support_levels = [];

    let hist_len = market.history_len();
    if hist_len >= lookback_ticks {
        let local_low = 1_000_000_000_000;
        let idx = 0;
        while idx < lookback_ticks {
            let price = market.history_price(idx);
            if price < local_low {
                local_low = price;
            }
            idx += 1;
        }

        let support_band = local_low * 101 / 100;
        if current_price * 100 / support_band > 100 && current_price * 100 / support_band < 102 {
            let bid_pressure = 0;
            let j = 0;
            while j < 5 {
                let bid_price = market.bid_price_0;
                if j == 1 { bid_price = market.bid_price_1; }
                if j == 2 { bid_price = market.bid_price_2; }
                if j == 3 { bid_price = market.bid_price_3; }
                if j == 4 { bid_price = market.bid_price_4; }

                let bid_vol = market.bid_vol_0;
                if j == 1 { bid_vol = market.bid_vol_1; }
                if j == 2 { bid_vol = market.bid_vol_2; }
                if j == 3 { bid_vol = market.bid_vol_3; }
                if j == 4 { bid_vol = market.bid_vol_4; }

                if bid_price > 0 && bid_price * 100 / support_band > 98 && bid_price * 100 / support_band < 101 {
                    bid_pressure += bid_vol;
                }
                j += 1;
            }

            if bid_pressure > detection_threshold {
                let available_stock = account.stock;
                if available_stock > 0 {
                    let sell_amount = available_stock * lot_size_multiplier / 100;
                    if sell_amount < 1 { sell_amount = 1; }
                    orders.submit_market_sell(sell_amount);
                    cooldown_counter = 10;
                }
            }
        }
    }

    let depressed_buy_price = current_price * 95 / 100;
    let available_cash = account.cash;
    if available_cash > 100_000 && depressed_buy_price > 0 {
        let buy_amount_cash = available_cash * lot_size_multiplier / 100;
        let buy_amount = buy_amount_cash / depressed_buy_price;
        if buy_amount > 0 {
            orders.submit_limit_buy(depressed_buy_price, buy_amount);
        }
    }
}