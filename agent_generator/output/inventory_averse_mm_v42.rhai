let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_profitable = true;
let morning_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(50, 200);
        current_lot_size = base_lot_size;
        morning_ticks = market.total_ticks / 5;
    }

    if !market.trading_enabled { return; }
    
    if market.tick >= morning_ticks {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }

    let loss_occurred = false;
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        let i = 0;
        while i < fill_count {
            let fill_side = my_orders.fill_side(i);
            let fill_price = my_orders.fill_price(i);
            
            if fill_side == 0 && market.price < fill_price {
                loss_occurred = true;
            }
            if fill_side == 1 && market.price > fill_price {
                loss_occurred = true;
            }
            i += 1;
        }
        
        if loss_occurred {
            current_lot_size = current_lot_size * 2;
            if current_lot_size > 1000 {
                current_lot_size = 1000;
            }
        } else {
            current_lot_size = base_lot_size;
        }
    }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    let inventory = account.stock;
    let spread_base = 2000;
    let buy_offset = spread_base;
    let sell_offset = spread_base;

    if inventory > 1000 {
        buy_offset = spread_base * 3 / 2;
        sell_offset = spread_base * 1 / 2;
    } else if inventory <= 0 {
        buy_offset = spread_base * 1 / 2;
        sell_offset = spread_base * 3 / 2;
    }

    let buy_price = market.price - buy_offset;
    let sell_price = market.price + sell_offset;

    if buy_price > 0 {
        let buy_amount = current_lot_size;
        let max_buy = account.cash / buy_price;
        if buy_amount > max_buy && max_buy > 0 {
            buy_amount = max_buy;
        }
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }

    if account.stock > 0 {
        let sell_amount = current_lot_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}