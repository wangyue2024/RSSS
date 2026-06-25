let initialized = false;
let lot_size = 0;
let last_rebalance_tick = 0;
let last_trade_was_loss = false;
let acc_filled_shares = 0;
let acc_filled_value = 0;
let acc_trade_side = 0;

fn on_tick() {
    if !initialized {
        let total_equity = account.total_equity;
        if total_equity > 0 {
            let min_lot_value = total_equity * 100 / 2000;
            let max_lot_value = total_equity * 500 / 10000;
            let lot_value = rng.rand_int(min_lot_value, max_lot_value);
            lot_size = lot_value / market.price;
            if lot_size == 0 {
                lot_size = 1;
            }
        } else {
            lot_size = 100;
        }
        last_rebalance_tick = market.tick;
        initialized = true;
    }

    if !market.trading_enabled {
        return;
    }

    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_amt = my_orders.fill_amount(i);
        let fill_price = my_orders.fill_price(i);
        let fill_side = my_orders.fill_side(i);
        acc_filled_shares += fill_amt;
        acc_filled_value += fill_amt * fill_price;
        if acc_trade_side == 0 {
            acc_trade_side = fill_side;
        }
        i += 1;
    }

    let pending_cnt = my_orders.pending_count();
    i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let ticks_since_rebalance = market.tick - last_rebalance_tick;
    if ticks_since_rebalance >= 10 {
        if acc_filled_shares > 0 {
            let avg_fill_price = acc_filled_value / acc_filled_shares;
            if (acc_trade_side == 1 && market.price < avg_fill_price) || (acc_trade_side == -1 && market.price > avg_fill_price) {
                last_trade_was_loss = true;
            } else {
                last_trade_was_loss = false;
            }
            acc_filled_shares = 0;
            acc_filled_value = 0;
            acc_trade_side = 0;
        }

        if last_trade_was_loss {
            lot_size = lot_size * 2;
        }

        let two_percent_of_price = (market.price * 2) / 100;
        if market.std_dev <= two_percent_of_price {
            let current_stock_value = account.stock * market.price;
            let current_equity = account.total_equity;
            if current_equity > 0 {
                let stock_percentage = (current_stock_value * 10000) / current_equity;
                let target_stock_value = (current_equity * 5000) / 10000;
                let value_difference = target_stock_value - current_stock_value;
                let shares_difference = value_difference / market.price;

                let trade_shares = 0;
                if shares_difference > 0 {
                    trade_shares = shares_difference;
                    if trade_shares > lot_size {
                        trade_shares = lot_size;
                    }
                    let cost = trade_shares * market.price;
                    if cost <= account.cash && trade_shares > 0 {
                        orders.submit_limit_buy(market.price, trade_shares);
                    }
                } else if shares_difference < 0 {
                    trade_shares = -shares_difference;
                    if trade_shares > lot_size {
                        trade_shares = lot_size;
                    }
                    if trade_shares <= account.stock && trade_shares > 0 {
                        orders.submit_limit_sell(market.price, trade_shares);
                    }
                }
            }
        }

        last_rebalance_tick = market.tick;
    }
}