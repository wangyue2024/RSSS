let initialized = false;
let base_lot = 100;
let current_lot = base_lot;
let last_trade_was_loss = false;
let last_rebalance_tick = -10;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(80, 120);
        current_lot = base_lot;
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks * 20 / 100 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        let fill_price = my_orders.fill_price(last_fill_idx);
        let new_avg = account.avg_cost;

        if fill_side == 0 && new_avg > fill_price {
            last_trade_was_loss = true;
        } else if fill_side == 1 && market.price > fill_price {
            last_trade_was_loss = true;
        } else {
            last_trade_was_loss = false;
        }
    }

    if market.tick - last_rebalance_tick >= 10 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }

        let stock_value = account.stock * market.price;
        let total_eq = account.total_equity;
        if total_eq > 0 {
            let stock_pct = stock_value * 100_00 / total_eq;
            let target_pct = 50_00;
            let upper_thresh = 55_00;
            let lower_thresh = 45_00;

            if stock_pct > upper_thresh {
                let excess_value = stock_value - total_eq * target_pct / 100_00;
                let sell_shares = excess_value / market.price;
                let amount_to_sell = sell_shares;
                if amount_to_sell < current_lot {
                    amount_to_sell = current_lot;
                }
                if amount_to_sell > account.stock {
                    amount_to_sell = account.stock;
                }
                if amount_to_sell > 0 {
                    let limit_price = market.bid_price_0;
                    if limit_price > 0 {
                        orders.submit_limit_sell(limit_price, amount_to_sell);
                        last_rebalance_tick = market.tick;
                    }
                }
            } else if stock_pct < lower_thresh {
                let deficit_value = total_eq * target_pct / 100_00 - stock_value;
                let buy_shares = deficit_value / market.price;
                let amount_to_buy = buy_shares;
                if amount_to_buy < current_lot {
                    amount_to_buy = current_lot;
                }
                let max_affordable = account.cash / market.price;
                if amount_to_buy > max_affordable {
                    amount_to_buy = max_affordable;
                }
                if amount_to_buy > 0 {
                    let limit_price = market.ask_price_0;
                    if limit_price > 0 {
                        orders.submit_limit_buy(limit_price, amount_to_buy);
                        last_rebalance_tick = market.tick;
                    }
                }
            }
        }

        if last_trade_was_loss {
            current_lot = current_lot * 2;
            if current_lot > 10000 {
                current_lot = 10000;
            }
        } else {
            current_lot = base_lot;
        }
    }
}