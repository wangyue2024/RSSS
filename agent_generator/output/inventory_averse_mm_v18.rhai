let initialized = false;
let lot_size = 0;
let stop_loss_threshold = 0;
let evaluation_interval = 50;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        let max_lot_cash = account.cash / 2;
        let price_adj = if market.price == 0 { 1_000_000 } else { market.price };
        let max_lot_shares = max_lot_cash / price_adj;
        lot_size = rng.rand_int(max_lot_shares / 2, max_lot_shares);
        if lot_size < 10 { lot_size = 10; }
        stop_loss_threshold = -rng.rand_int(10_000, 50_000);
        initialized = true;
    }

    if account.unrealized_pnl < stop_loss_threshold {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if market.tick % evaluation_interval != 0 { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = market.price;
    let base_spread = 5000;
    let skew_factor = 20000;
    let buy_spread = base_spread;
    let sell_spread = base_spread;
    let inventory = account.stock;

    if inventory > 1000 {
        buy_spread = base_spread + skew_factor;
        sell_spread = base_spread - skew_factor / 2;
    } else if inventory <= 0 {
        buy_spread = base_spread - skew_factor / 2;
        sell_spread = base_spread + skew_factor;
    }

    let bid_price = mid_price - buy_spread;
    let ask_price = mid_price + sell_spread;
    if bid_price < 1 { bid_price = 1; }
    if ask_price < 1 { ask_price = bid_price + 1000; }

    let buy_amount = lot_size;
    let sell_amount = lot_size;

    if inventory > 1000 {
        buy_amount = lot_size / 2;
        sell_amount = lot_size * 2;
    } else if inventory <= 0 {
        buy_amount = lot_size * 2;
        sell_amount = lot_size / 2;
    }

    if rng.rand_bool(30) {
        buy_amount = buy_amount * 2;
        sell_amount = sell_amount * 2;
    }

    let max_buy_by_cash = account.cash / bid_price;
    if buy_amount > max_buy_by_cash && max_buy_by_cash > 0 {
        buy_amount = max_buy_by_cash;
    }
    if buy_amount > account.stock && inventory < 0 {
        buy_amount = -inventory;
    }

    if sell_amount > account.stock && account.stock > 0 {
        sell_amount = account.stock;
    }

    if buy_amount > 0 && bid_price > 0 {
        orders.submit_limit_buy(bid_price, buy_amount);
    }
    if sell_amount > 0 && ask_price > 0 {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}