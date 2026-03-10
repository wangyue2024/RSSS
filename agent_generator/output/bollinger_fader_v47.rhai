let initialized = false;
let stop_loss_threshold = 0;
let base_lot_size = 100;
let current_lot_size = base_lot_size;
let last_trade_was_loss = false;

fn on_tick() {
    if !initialized {
        stop_loss_threshold = -rng.rand_int(10000, 50000);
        current_lot_size = base_lot_size;
        last_trade_was_loss = false;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < stop_loss_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        } else if account.stock < 0 {
            orders.submit_market_buy(-account.stock);
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock != 0 {
        let price_diff = market.price - account.avg_cost;
        if (account.stock > 0 && price_diff < 0) || (account.stock < 0 && price_diff > 0) {
            last_trade_was_loss = true;
        } else {
            last_trade_was_loss = false;
        }
    } else {
        last_trade_was_loss = false;
    }
    
    if last_trade_was_loss {
        current_lot_size = current_lot_size * 2;
    } else {
        current_lot_size = base_lot_size;
    }
    
    if market.ma_20 == 0 || market.std_dev == 0 { return; }
    
    let lower_band = market.ma_20 - 2 * market.std_dev;
    let upper_band = market.ma_20 + 2 * market.std_dev;
    
    let buy_price = lower_band + 1;
    let sell_price = upper_band;
    
    if buy_price > 0 && account.cash >= buy_price * current_lot_size {
        orders.submit_limit_buy(buy_price, current_lot_size);
    }
    
    if sell_price > 0 && account.stock >= current_lot_size {
        orders.submit_limit_sell(sell_price, current_lot_size);
    }
}