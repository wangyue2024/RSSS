let initialized = false;
let total_to_sell = 0;
let remaining_to_sell = 0;
let lot_size = 0;
let base_lot_size = 0;
let panic_threshold = 0;
let last_trade_profit = true;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_to_sell = account.stock;
        remaining_to_sell = total_to_sell;
        base_lot_size = rng.rand_int(1, 10);
        lot_size = base_lot_size;
        panic_threshold = -rng.rand_int(50_000, 200_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        remaining_to_sell = 0;
        return;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let profit_sum = 0;
        let total_filled = 0;
        let j = 0;
        while j < fill_cnt {
            let side = my_orders.fill_side(j);
            if side == "sell" {
                let fill_price = my_orders.fill_price(j);
                let fill_qty = my_orders.fill_amount(j);
                let cost_basis = account.avg_cost * fill_qty;
                let proceeds = fill_price * fill_qty;
                profit_sum += proceeds - cost_basis;
                total_filled += fill_qty;
            }
            j += 1;
        }
        
        if total_filled > 0 {
            last_trade_profit = profit_sum >= 0;
            remaining_to_sell -= total_filled;
            
            if !last_trade_profit {
                lot_size = lot_size * 2;
                if lot_size > 100 { lot_size = 100; }
            } else {
                lot_size = base_lot_size;
            }
        }
    }
    
    if remaining_to_sell <= 0 { return; }
    
    let ask_price = market.ask_price_0;
    if ask_price > 0 && remaining_to_sell > 0 {
        let order_qty = if lot_size < remaining_to_sell { lot_size } else { remaining_to_sell };
        orders.submit_limit_sell(ask_price, order_qty);
    }
}