let initialized = false;
let lot_size = 0;
let stop_loss_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_factor = rng.rand_int(300000, 500000);
        lot_size = (account.cash * risk_factor) / 1000000;
        let loss_factor = rng.rand_int(10000, 50000);
        stop_loss_threshold = -loss_factor;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let fat_finger_roll = rng.rand_int(0, 9999);
    if fat_finger_roll == 0 {
        let normal_amount = lot_size / market.price;
        if normal_amount == 0 {
            normal_amount = 1;
        }
        let fat_amount = normal_amount * 100;
        if fat_amount > 0 {
            let buy_roll = rng.rand_bool(50);
            if buy_roll {
                orders.submit_market_buy(fat_amount);
            } else {
                orders.submit_market_sell(fat_amount);
            }
        }
        return;
    }

    let normal_chance = rng.rand_bool(1);
    if normal_chance {
        let side_roll = rng.rand_bool(50);
        if side_roll && market.bid_price_0 > 0 {
            let bid_price = market.bid_price_0 + 1;
            let order_amount = lot_size / market.price;
            if order_amount == 0 {
                order_amount = 1;
            }
            orders.submit_limit_buy(bid_price, order_amount);
        } else if !side_roll && market.ask_price_0 > 0 {
            let ask_price = market.ask_price_0 + 1;
            let order_amount = lot_size / market.price;
            if order_amount == 0 {
                order_amount = 1;
            }
            orders.submit_limit_sell(ask_price, order_amount);
        }
    }
}