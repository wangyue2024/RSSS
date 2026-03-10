let initialized = false;
let lot_size = 0;
let base_spread = 0;
let vol_multiplier = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_seek = rng.rand_int(70, 95);
        let cash_in_shares = account.cash / market.price;
        lot_size = (cash_in_shares * risk_seek) / 100;
        base_spread = rng.rand_int(50, 150);
        vol_multiplier = rng.rand_int(30, 70);
    }

    if !market.trading_enabled { return; }

    if market.tick * 5 >= market.total_ticks {
        let pc = my_orders.pending_count();
        let i = 0;
        while i < pc {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }

    let cancel_count = my_orders.pending_count();
    let j = 0;
    while j < cancel_count {
        orders.submit_cancel(my_orders.pending_id(j));
        j += 1;
    }

    let mid = market.price;
    let vol_adj = (market.std_dev * vol_multiplier) / 10_000;
    let total_spread = base_spread + vol_adj;
    let half = total_spread / 2;

    let bid_price = mid - half;
    let ask_price = mid + half;

    let buy_shares = lot_size;
    if buy_shares > 0 && bid_price > 0 {
        orders.submit_limit_buy(bid_price, buy_shares);
    }

    if ask_price > account.avg_cost && account.stock > 0 {
        let sell_shares = lot_size;
        if sell_shares > account.stock {
            sell_shares = account.stock;
        }
        if sell_shares > 0 {
            orders.submit_limit_sell(ask_price, sell_shares);
        }
    }
}