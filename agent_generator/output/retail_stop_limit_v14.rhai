let price_buffer = [];
let delayed_price = 0;
let in_trade = false;
let entry_price = 0;
let lot_size = 0;
let last_trade_loss = false;
let initialized = false;

fn on_tick() {
    if !market.trading_enabled {
        return;
    }

    if !initialized {
        initialized = true;
        let max_shares = (account.total_equity * 5 / 100) / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
    }

    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }

    if price_buffer.len() == 5 {
        delayed_price = price_buffer[0];
    } else {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if !in_trade {
        if market.std_dev < (delayed_price * 5 / 100) {
            if rng.rand_bool(10) {
                orders.submit_limit_buy(delayed_price, lot_size);
                in_trade = true;
                entry_price = delayed_price;
            }
        }
    } else {
        let current_position = account.stock;
        if current_position == 0 {
            let fill_cnt = my_orders.fill_count();
            if fill_cnt > 0 {
                let last_fill_idx = fill_cnt - 1;
                let fill_price = my_orders.fill_price(last_fill_idx);
                let fill_side = my_orders.fill_side(last_fill_idx);
                
                if fill_side == 1 && fill_price < entry_price {
                    last_trade_loss = true;
                } else {
                    last_trade_loss = false;
                }
            }
            
            let max_shares = (account.total_equity * 5 / 100) / delayed_price;
            if max_shares < 1 {
                lot_size = 1;
            } else {
                if last_trade_loss {
                    lot_size = lot_size * 2;
                    if lot_size > max_shares {
                        lot_size = max_shares;
                    }
                } else {
                    lot_size = rng.rand_int(1, max_shares);
                }
            }
            
            in_trade = false;
            entry_price = 0;
        } else {
            if market.price <= entry_price * 98 / 100 {
                orders.submit_market_sell(current_position);
            } else {
                orders.submit_limit_sell(entry_price * 105 / 100, current_position);
            }
        }
    }
}