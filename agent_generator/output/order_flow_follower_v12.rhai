let initialized = false;
let panic_threshold = 0;
let TRADE_AMOUNT = 1000;

fn on_tick() {
    if !market.trading_enabled {
        return;
    }

    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(50_000, 200_000);
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.tick % 50 == 0 {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        let buy_vol = market.buy_volume;
        let sell_vol = market.sell_volume;

        if buy_vol >= 3 * sell_vol {
            orders.submit_market_buy(TRADE_AMOUNT);
        } else if sell_vol >= 3 * buy_vol {
            orders.submit_market_sell(TRADE_AMOUNT);
        }
    }
}