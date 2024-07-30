pub mod interface;

pub mod replaceability;

// shorthand for the use of ReplaceabilityComponent
pub use replaceability::ReplaceabilityComponent;

// Due to an issue in snforge, it won't recognize the mock under #[cfg(test)].
pub(crate) mod mock;

// Due to an issue in snforge, it won't recognize the eic testing contract under #[cfg(test)].
pub(crate) mod eic_test_contract;

#[cfg(test)]
pub(crate) mod test_utils;

#[cfg(test)]
mod test;
