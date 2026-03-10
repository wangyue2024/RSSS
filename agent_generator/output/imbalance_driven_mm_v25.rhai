let initialized = false;
let base_lot = 0;
let last_trade_loss = false;
let consecutive_losses = 0;
let max_position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(500, 2500);
        max_position = rng.rand_int(5000, 15000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let tick_size = 10000;

    let imbalance = market.order_imbalance;
    let shift = imbalance * tick_size / 100;

    let adj_mid = mid_price + shift;
    let bid_price = adj_mid - tick_size;
    let ask_price = adj_mid + tick_size;

    let current_lot = base_lot;
    if last_trade_loss {
        current_lot = base_lot * (1 << consecutive_losses);
    }

    let risk_lot = current_lot;
    if risk_lot * adj_mid > account.cash / 2 {
        risk_lot = account.cash / (2 * adj_mid);
    }
    if risk_lot == 0 { risk_lot = 1; }

    let max_buy = max_position - account.stock;
    let max_sell = max_position + account.stock;

    if max_buy > 0 {
        let buy_qty = risk_lot;
        if buy_qty > max_buy { buy_qty = max_buy; }
        if buy_qty > 0 {
            orders.submit_limit_buy(bid_price, buy_qty);
        }
    }

    if max_sell > 0 {
        let sell_qty = risk_lot;
        if sell_qty > max_sell { sell_qty = max_sell; }
        if sell_qty > 0 {
            orders.submit_limit_sell(ask_price, sell_qty);
        }
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        let fill_price = my_orders.fill_price(last_fill_idx);

        let current_px = market.price;
        if (fill_side == 0 && current_px < fill_price) || (fill_side == 1 && current_px > fill_price) {
            last_trade_loss = true;
            consecutive_losses += 1;
            if consecutive_losses > 5 { consecutive_losses = 5; }
        } else {
            last_trade_loss = false;
            consecutive_losses = 0;
        }
    }
}