pub(crate) mod errors;

pub mod interface;

pub(crate) mod replaceability;

// shorthand for the use of ReplaceabilityComponent
pub use replaceability::ReplaceabilityComponent;

#[cfg(test)]
mod eic_test_contract;

#[cfg(test)]
pub(crate) mod mock;

#[cfg(test)]
mod test;

#[cfg(test)]
pub(crate) mod test_utils;
