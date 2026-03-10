let initialized = false;
let lot_size = 0;
let spread_micros = 0;
let last_trade_profit = 0;
let martingale_active = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_factor = rng.rand_int(30, 50);
        let cash_for_trade = account.cash * risk_factor / 100;
        if market.price > 0 {
            lot_size = cash_for_trade / market.price;
            if lot_size < 1 { lot_size = 1; }
        } else {
            lot_size = 100;
        }
        spread_micros = rng.rand_int(5000, 20000);
        last_trade_profit = 0;
        martingale_active = false;
    }

    if !market.trading_enabled { return; }

    if market.tick % 50 != 0 { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if last_trade_profit < 0 && martingale_active {
        lot_size = lot_size * 2;
    } else {
        martingale_active = false;
    }

    let current_price = market.price;
    if current_price == 0 { return; }

    let buy_price = current_price - spread_micros;
    let sell_price = current_price + spread_micros;

    if buy_price > 0 && account.cash >= buy_price * lot_size {
        orders.submit_limit_buy(buy_price, lot_size);
    }

    if account.stock >= lot_size {
        orders.submit_limit_sell(sell_price, lot_size);
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        let fill_price = my_orders.fill_price(last_fill_idx);
        
        if fill_side == 1 {
            if current_price < fill_price {
                last_trade_profit = -1;
                martingale_active = true;
            } else {
                last_trade_profit = 1;
                martingale_active = false;
            }
        } else if fill_side == -1 {
            if current_price > fill_price {
                last_trade_profit = -1;
                martingale_active = true;
            } else {
                last_trade_profit = 1;
                martingale_active = false;
            }
        }
    }
}