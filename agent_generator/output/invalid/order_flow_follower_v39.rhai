// Global variables
let initialized = false;
let base_lot = 100;
let current_lot = base_lot;
let last_trade_profit = 0; // 1 = profit, -1 = loss, 0 = unknown
let last_position = 0;
let last_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        current_lot = base_lot;
        last_trade_profit = 0;
        last_position = account.stock;
        last_avg_cost = account.avg_cost;
    }

    if !market.trading_enabled { return; }

    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Check if last trade was a loss for martingale
    if last_position != 0 && account.stock == 0 {
        // Position flattened, check if it was loss
        let current_price = market.price;
        if (last_position > 0 && current_price < last_avg_cost) ||
           (last_position < 0 && current_price > last_avg_cost) {
            last_trade_profit = -1;
        } else {
            last_trade_profit = 1;
        }
    } else if last_position != account.stock {
        // Position changed but not flattened
        let current_price = market.price;
        let new_avg = account.avg_cost;
        
        if (last_position > 0 && account.stock > last_position) {
            // Added to long position
            if current_price < last_avg_cost {
                last_trade_profit = -1;
            } else {
                last_trade_profit = 1;
            }
        } else if (last_position < 0 && account.stock < last_position) {
            // Added to short position
            if current_price > last_avg_cost {
                last_trade_profit = -1;
            } else {
                last_trade_profit = 1;
            }
        }
    }

    // Martingale sizing
    if last_trade_profit == -1 {
        current_lot = current_lot * 2;
    } else {
        current_lot = base_lot;
    }

    // Update position tracking
    last_position = account.stock;
    last_avg_cost = account.avg_cost;

    // Order flow logic (ignore price, only volume)
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;

    if buy_vol > 0 && sell_vol > 0 {
        if buy_vol >= sell_vol * 3 {
            // Join buying crowd
            let max_buy = account.cash / market.price;
            let buy_amount = if current_lot < max_buy { current_lot } else { max_buy };
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        } else if sell_vol >= buy_vol * 3 {
            // Join selling crowd
            let sell_amount = if current_lot < account.stock { current_lot } else { account.stock };
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
            }
        }
    }
}