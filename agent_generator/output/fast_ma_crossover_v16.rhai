// Global persistent state
let initialized = false;
let last_ma5 = 0;
let last_ma20 = 0;
let in_position = false;
let last_trade_was_loss = false;
let base_lot_size = 10000;
let current_lot_size = base_lot_size;
let last_buy_price = 0;

// Rounding functions for round number bias
fn round_down_to_dollar(price) {
    return (price / 1_000_000) * 1_000_000;
}

fn round_up_to_dollar(price) {
    return ((price + 999_999) / 1_000_000) * 1_000_000;
}

fn on_tick() {
    // Initialize on first tick
    if !initialized {
        last_ma5 = market.ma_5;
        last_ma20 = market.ma_20;
        initialized = true;
    }

    if !market.trading_enabled { return; }

    // Cancel all existing orders before taking new action
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    // Check for crossover signals
    let ma5 = market.ma_5;
    let ma20 = market.ma_20;
    let bullish_cross = (last_ma5 <= last_ma20) && (ma5 > ma20);
    let bearish_cross = (last_ma5 >= last_ma20) && (ma5 < ma20);

    // Martingale sizing adjustment
    if in_position {
        // Check if last trade was a loss (current price below average cost)
        if account.stock > 0 {
            if market.price < account.avg_cost {
                last_trade_was_loss = true;
            }
        }
    }

    // Reset lot size after successful trade
    if !last_trade_was_loss {
        current_lot_size = base_lot_size;
    }

    // Trading logic
    if bullish_cross && !in_position {
        // Buy signal: MA5 crossed above MA20
        // Apply martingale sizing if last trade was loss
        if last_trade_was_loss {
            current_lot_size = current_lot_size * 2;
            last_trade_was_loss = false;
        }
        
        // Round number bias: buy at nearest dollar below current price
        let buy_price = round_down_to_dollar(market.price);
        if buy_price < 1_000_000 { buy_price = 1_000_000; }
        
        // Use market order for immediate execution as per strategy
        orders.submit_market_buy(current_lot_size);
        in_position = true;
        last_buy_price = buy_price;
        
    } else if bearish_cross && in_position && account.stock > 0 {
        // Sell signal: MA5 crossed below MA20
        // Sell all inventory at market price
        orders.submit_market_sell(account.stock);
        in_position = false;
    }

    // Update MA history for next tick
    last_ma5 = ma5;
    last_ma20 = ma20;
}