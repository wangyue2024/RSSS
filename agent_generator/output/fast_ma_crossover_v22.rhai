let base_lot_size = 100;
let current_lot_size = base_lot_size;
let last_cross_state = 0;
let last_trade_was_loss = false;

fn on_tick() {
    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_cross = 0;
    if market.ma_5 > market.ma_20 {
        current_cross = 1;
    } else if market.ma_5 < market.ma_20 {
        current_cross = -1;
    }

    if last_cross_state <= 0 && current_cross == 1 {
        let buy_amount = current_lot_size;
        if account.cash > market.price * buy_amount {
            orders.submit_market_buy(buy_amount);
        }
        last_cross_state = 1;
    } else if last_cross_state >= 0 && current_cross == -1 {
        let sell_amount = account.stock;
        if sell_amount > 0 {
            let avg_cost = account.avg_cost;
            let sell_price = market.price;
            if sell_price < avg_cost {
                current_lot_size = current_lot_size * 2;
                last_trade_was_loss = true;
            } else {
                current_lot_size = base_lot_size;
                last_trade_was_loss = false;
            }
            orders.submit_market_sell(sell_amount);
        }
        last_cross_state = -1;
    }
}