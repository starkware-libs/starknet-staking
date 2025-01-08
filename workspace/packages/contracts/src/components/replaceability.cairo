pub(crate) mod errors;

pub mod interface;

pub(crate) mod replaceability;

// shorthand for the use of ReplaceabilityComponent
pub use replaceability::ReplaceabilityComponent;

// Due to an issue in snforge, it won't recognize the eic testing contract under #[cfg(test)].
mod eic_test_contract;

// Due to an issue in snforge, it won't recognize the mock under #[cfg(test)].
pub(crate) mod mock;

#[cfg(test)]
mod test;

#[cfg(test)]
pub(crate) mod test_utils;
