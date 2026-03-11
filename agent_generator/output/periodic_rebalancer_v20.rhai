let initialized = false;
let panic_threshold = 0;
let lot_size = 100;
let last_trade_was_loss = false;
let tick_counter = 0;
let last_trade_side = 0;
let last_trade_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(1000, 10000);
        lot_size = 100;
        last_trade_was_loss = false;
        tick_counter = 0;
        last_trade_side = 0;
        last_trade_price = 0;
    }

    if !market.trading_enabled { return; }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        let last_fill_idx = fill_count - 1;
        last_trade_side = my_orders.fill_side(last_fill_idx);
        last_trade_price = my_orders.fill_price(last_fill_idx);
        
        if last_trade_side == 0 {
            last_trade_was_loss = market.price < account.avg_cost;
        } else {
            last_trade_was_loss = market.price > last_trade_price;
        }
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    tick_counter += 1;
    if tick_counter % 10 != 0 { return; }

    let equity = account.total_equity;
    if equity <= 0 { return; }
    
    let stock_value = account.stock * market.price;
    let stock_pct = (stock_value * 100) / equity;

    if last_trade_was_loss {
        lot_size = lot_size * 2;
    } else {
        lot_size = 100;
    }
    lot_size = clamp_val(lot_size, 100, 10000);

    let target_shares = 0;
    let order_price = 0;

    if stock_pct > 55 && account.stock > 0 {
        target_shares = lot_size;
        if target_shares > account.stock {
            target_shares = account.stock;
        }
        order_price = market.bid_price_0;
        if order_price <= 0 {
            order_price = market.price - 1_000_000;
        }
        if order_price > 0 && target_shares > 0 {
            orders.submit_limit_sell(order_price, target_shares);
        }
    } else if stock_pct < 45 {
        let max_buy_by_cash = account.cash / market.price;
        target_shares = lot_size;
        if target_shares > max_buy_by_cash {
            target_shares = max_buy_by_cash;
        }
        order_price = market.ask_price_0;
        if order_price <= 0 {
            order_price = market.price + 1_000_000;
        }
        if order_price > 0 && target_shares > 0 {
            orders.submit_limit_buy(order_price, target_shares);
        }
    }
}