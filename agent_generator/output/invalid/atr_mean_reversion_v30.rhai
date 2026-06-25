let initialized = false;
let tick_counter = 0;
let base_lot_size = 100;
let current_lot_size = base_lot_size;
let last_trade_was_loss = false;
let entry_price = 0;
let position_side = 0;
let position_amount = 0;
let recent_prices = [];

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        base_lot_size = 100;
        current_lot_size = base_lot_size;
    }

    let price_now = market.price;
    recent_prices.push(price_now);
    if recent_prices.len() > 5 {
        recent_prices.remove(0);
    }

    if recent_prices.len() == 5 {
        let old_price = recent_prices[0];
        let new_price = recent_prices[4];
        if (new_price - old_price) * 10000 > old_price * 200 {
            orders.submit_market_buy(current_lot_size);
            return;
        }
    }

    let fill_count = my_orders.fill_count();
    let i = 0;
    while i < fill_count {
        let fill_side = my_orders.fill_side(i);
        let fill_price = my_orders.fill_price(i);
        let fill_amount = my_orders.fill_amount(i);

        if fill_side == 0 {
            if position_side == 0 {
                position_side = 1;
                entry_price = fill_price;
                position_amount = fill_amount;
            } else if position_side == -1 {
                let profit = (entry_price - fill_price) * position_amount;
                if profit < 0 {
                    last_trade_was_loss = true;
                } else {
                    last_trade_was_loss = false;
                }
                if last_trade_was_loss {
                    current_lot_size = current_lot_size * 2;
                    if current_lot_size > 1000 {
                        current_lot_size = 1000;
                    }
                } else {
                    current_lot_size = base_lot_size;
                }
                position_side = 0;
                position_amount = 0;
                entry_price = 0;
            }
        } else if fill_side == 1 {
            if position_side == 0 {
                position_side = -1;
                entry_price = fill_price;
                position_amount = fill_amount;
            } else if position_side == 1 {
                let profit = (fill_price - entry_price) * position_amount;
                if profit < 0 {
                    last_trade_was_loss = true;
                } else {
                    last_trade_was_loss = false;
                }
                if last_trade_was_loss {
                    current_lot_size = current_lot_size * 2;
                    if current_lot_size > 1000 {
                        current_lot_size = 1000;
                    }
                } else {
                    current_lot_size = base_lot_size;
                }
                position_side = 0;
                position_amount = 0;
                entry_price = 0;
            }
        }
        i += 1;
    }

    tick_counter += 1;
    if tick_counter % 50 != 0 {
        return;
    }

    let pending_count = my_orders.pending_count();
    let j = 0;
    while j < pending_count {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }

    let atr = market.atr_14;
    let ma20 = market.ma_20;
    let deviation = atr * 3 / 2;
    let upper_band = ma20 + deviation;
    let lower_band = ma20 - deviation;

    if price_now > upper_band {
        if position_side == 1 {
            let stock_amount = account.stock;
            if stock_amount > 0 {
                orders.submit_market_sell(stock_amount);
            }
        }
        if current_lot_size > 0 {
            orders.submit_limit_sell(price_now, current_lot_size);
        }
    } else if price_now < lower_band {
        if position_side == -1 {
            let stock_amount = account.stock;
            if stock_amount < 0 {
                orders.submit_market_buy(-stock_amount);
            }
        }
        if current_lot_size > 0 {
            orders.submit_limit_buy(price_now, current_lot_size);
        }
    }
}