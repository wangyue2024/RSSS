let initialized = false;
let base_lot_size = 0;
let lot_size = 0;
let stop_loss_threshold = 0;
let last_trade_price = 0;
let last_trade_side = 0; // 0 for none, 1 for buy, 2 for sell
let last_trade_was_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(1, 10);
        lot_size = base_lot_size;
        stop_loss_threshold = rng.rand_int(-500000, -100000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        lot_size = base_lot_size;
        last_trade_side = 0;
        return;
    }

    if last_trade_side != 0 {
        let loss_condition = false;
        if last_trade_side == 1 && market.bid_price_0 < last_trade_price {
            loss_condition = true;
        } else if last_trade_side == 2 && market.ask_price_0 > last_trade_price {
            loss_condition = true;
        }
        if loss_condition {
            lot_size = lot_size * 2;
            if lot_size > 1000 {
                lot_size = 1000;
            }
            last_trade_was_loss = true;
        } else {
            last_trade_was_loss = false;
            lot_size = base_lot_size;
        }
        last_trade_side = 0;
    }

    let fills = my_orders.fill_count();
    if fills > 0 {
        let idx = fills - 1;
        last_trade_price = my_orders.fill_price(idx);
        last_trade_side = my_orders.fill_side(idx);
    }

    let r = rng.rand_int(0, 99);
    let qty = lot_size * rng.rand_int(1, 3);
    let price_offset = rng.rand_int(1, 5) * 1000;

    if r < 5 && account.cash > 1000000 {
        let target_price = market.bid_price_0 - price_offset;
        if target_price > 0 {
            orders.submit_limit_buy(target_price, qty);
        }
    } else if r > 95 && account.stock >= qty {
        let target_price = market.ask_price_0 + price_offset;
        orders.submit_limit_sell(target_price, qty);
    }
}