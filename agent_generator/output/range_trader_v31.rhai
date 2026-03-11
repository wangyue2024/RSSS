let initialized = false;
let base_equity_percent = 0;
let offset = 0;
let min_spread = 0;
let std_dev_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_equity_percent = rng.rand_int(1, 5);
        offset = rng.rand_int(5000, 20000);
        min_spread = rng.rand_int(50000, 150000);
        std_dev_threshold = rng.rand_int(150000, 300000);
    }

    if !market.trading_enabled {
        return;
    }

    if market.tick * 5 >= market.total_ticks {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let spread = market.high_20 - market.low_20;
    if spread < min_spread {
        return;
    }

    if market.std_dev > std_dev_threshold {
        return;
    }

    let max_position_value = account.total_equity * base_equity_percent / 100;
    if max_position_value <= 0 {
        return;
    }
    let base_lot = max_position_value / market.price;
    if base_lot <= 0 {
        return;
    }

    let target_spread = 200000;
    let lot_multiplier = 1;
    if spread < target_spread {
        lot_multiplier = 2;
    }
    if market.std_dev > std_dev_threshold * 8 / 10 {
        lot_multiplier = lot_multiplier / 2;
        if lot_multiplier < 1 {
            lot_multiplier = 1;
        }
    }

    let adjusted_lot = base_lot * lot_multiplier;
    if adjusted_lot < 1 {
        return;
    }

    let buy_price = market.low_20 + offset;
    let sell_price = market.high_20 - offset;

    if buy_price >= sell_price {
        return;
    }

    if market.price <= market.low_20 || market.price >= market.high_20 {
        return;
    }

    let available_cash = account.cash;
    let available_stock = account.stock;

    let buy_order_value = buy_price * adjusted_lot;
    let final_buy_lot = adjusted_lot;
    if buy_order_value > available_cash {
        final_buy_lot = available_cash / buy_price;
    }
    if final_buy_lot < 1 {
        final_buy_lot = 0;
    }

    let final_sell_lot = adjusted_lot;
    if final_sell_lot > available_stock {
        final_sell_lot = available_stock;
    }

    if final_buy_lot > 0 {
        orders.submit_limit_buy(buy_price, final_buy_lot);
    }
    if final_sell_lot > 0 {
        orders.submit_limit_sell(sell_price, final_sell_lot);
    }
}