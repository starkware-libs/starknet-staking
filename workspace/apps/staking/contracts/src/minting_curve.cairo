pub mod interface;

pub mod minting_curve;

//convenient reference
pub use minting_curve::MintingCurve;
pub use interface::IMintingCurve;

#[cfg(test)]
mod test;
