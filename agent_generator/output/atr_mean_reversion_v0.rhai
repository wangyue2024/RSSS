let initialized = false;
let base_lot_size = 100;
let max_lot_size = 1600;
let current_lot_size = base_lot_size;
let last_trade_was_loss = false;
let position_state = 0;
let entry_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        if rng.rand_bool(50) {
            base_lot_size = 150;
        }
    }

    if !market.trading_enabled {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.atr_14 == 0 || market.ma_20 == 0 {
        return;
    }

    let deviation = abs_val(market.price - market.ma_20);
    let threshold = market.atr_14 * 3 / 2;

    if account.stock == 0 && deviation > threshold {
        if market.price < market.ma_20 {
            let buy_price = if market.ask_price_0 > 0 { market.ask_price_0 } else { market.price };
            let max_shares = account.cash / buy_price;
            let shares_to_buy = current_lot_size;
            if shares_to_buy > max_shares {
                shares_to_buy = max_shares;
            }
            if shares_to_buy > 0 {
                orders.submit_market_buy(shares_to_buy);
                position_state = 1;
                entry_price = buy_price;
            }
        }
    } else if account.stock > 0 && deviation > threshold {
        if market.price > market.ma_20 {
            let sell_price = if market.bid_price_0 > 0 { market.bid_price_0 } else { market.price };
            let sell_value = sell_price * account.stock;
            let buy_cost = entry_price * account.stock;
            orders.submit_market_sell(account.stock);
            if sell_value < buy_cost {
                last_trade_was_loss = true;
            } else {
                last_trade_was_loss = false;
            }
            if last_trade_was_loss {
                current_lot_size = current_lot_size * 2;
                if current_lot_size > max_lot_size {
                    current_lot_size = max_lot_size;
                }
            } else {
                current_lot_size = base_lot_size;
            }
            position_state = 0;
            entry_price = 0;
        }
    }
}