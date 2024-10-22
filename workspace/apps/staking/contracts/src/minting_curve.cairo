pub mod interface;

pub mod minting_curve;

//convenient reference
pub use minting_curve::MintingCurve;
pub use interface::{IMintingCurve, Events, ConfigEvents};

#[cfg(test)]
mod test;
