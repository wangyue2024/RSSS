let initialized = false;
let base_lot_size = 0;
let current_lot_size = 0;
let panic_threshold = 0;
let last_rebalance_tick = 0;
let last_trade_price = 0;
let last_trade_side = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_rebalance_tick = market.tick;
        panic_threshold = -rng.rand_int(5_000, 15_000);
        base_lot_size = (account.cash * rng.rand_int(30, 50)) / (100 * market.price);
        if base_lot_size < 1 { base_lot_size = 1; }
        current_lot_size = base_lot_size;
    }

    if !market.trading_enabled { return; }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        current_lot_size = base_lot_size;
        last_trade_side = -1;
        return;
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let idx = fill_cnt - 1;
        last_trade_price = my_orders.fill_price(idx);
        last_trade_side = my_orders.fill_side(idx);
    }

    if market.tick - last_rebalance_tick >= 10 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        if last_trade_side == 0 && market.price < last_trade_price {
            current_lot_size = current_lot_size * 2;
        } else if last_trade_side == 1 && market.price > last_trade_price {
            current_lot_size = current_lot_size * 2;
        } else {
            current_lot_size = base_lot_size;
        }

        let stock_value = account.stock * market.price;
        let equity = account.total_equity;
        if equity > 0 {
            let stock_pct = (stock_value * 100) / equity;

            if stock_pct > 55 && account.stock > 0 {
                let sell_amount = current_lot_size;
                if sell_amount > account.stock {
                    sell_amount = account.stock;
                }
                if sell_amount > 0 {
                    let sell_price = market.price - 1;
                    orders.submit_limit_sell(sell_price, sell_amount);
                }
            } else if stock_pct < 45 {
                let max_buy = account.cash / market.price;
                let buy_amount = current_lot_size;
                if buy_amount > max_buy {
                    buy_amount = max_buy;
                }
                if buy_amount > 0 {
                    let buy_price = market.price + 1;
                    orders.submit_limit_buy(buy_price, buy_amount);
                }
            }
        }

        last_rebalance_tick = market.tick;
    }
}