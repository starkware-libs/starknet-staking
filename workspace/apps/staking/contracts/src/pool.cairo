pub mod interface;

pub mod pool;

//convenient reference
pub use pool::Pool;
pub use interface::{IPool, InternalPoolMemberInfo, PoolMemberInfo, Events};

#[cfg(test)]
mod test;
