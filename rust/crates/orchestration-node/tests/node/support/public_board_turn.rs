use std::sync::{Mutex, MutexGuard, PoisonError};

static PUBLIC_BOARD_TURN: Mutex<()> = Mutex::new(());

pub fn wait_for_public_board_turn() -> MutexGuard<'static, ()> {
    PUBLIC_BOARD_TURN
        .lock()
        .unwrap_or_else(PoisonError::into_inner)
}
