pub mod interface;
pub mod operator;
pub mod staking_mock;
#[cfg(test)]
mod test;

//convenient reference
pub use operator::Operator;
pub use interface::IOperator;
