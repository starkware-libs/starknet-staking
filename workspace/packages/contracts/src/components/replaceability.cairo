pub mod interface;

pub mod replaceability;

// shorthand for the use of ReplaceabilityComponent
pub use replaceability::ReplaceabilityComponent;

// Due to an issue in snforge, it won't recognize the mock under #[cfg(test)].
pub mod mock;

#[cfg(test)]
pub mod test_utils;

#[cfg(test)]
pub mod test;
