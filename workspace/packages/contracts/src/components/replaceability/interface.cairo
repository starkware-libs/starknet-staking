use starknet::class_hash::ClassHash;

/// Holds EIC data.
/// * eic_hash is the EIC class hash.
/// * eic_init_data is a span of the EIC init args.
#[derive(Copy, Drop, Serde, PartialEq)]
pub struct EICData {
    pub eic_hash: ClassHash,
    pub eic_init_data: Span<felt252>
}

/// Holds implementation data.
/// * impl_hash is the implementation class hash.
/// * eic_data is the EIC data when applicable, and empty otherwise.
/// * final indicates whether the implementation is finalized.
#[derive(Copy, Drop, Serde, PartialEq)]
pub struct ImplementationData {
    pub impl_hash: ClassHash,
    pub eic_data: Option<EICData>,
    pub final: bool
}

/// starknet_keccak(eic_initialize).
pub const EIC_INITIALIZE_SELECTOR: felt252 =
    1770792127795049777084697565458798191120226931451376769053057094489776256516;

/// Duration from implementation is eligible until it expires. (1209600 = 2 weeks).
pub const IMPLEMENTATION_EXPIRATION: u64 = 1209600;

#[starknet::interface]
pub trait IEICInitializable<TContractState> {
    fn eic_initialize(ref self: TContractState, eic_init_data: Span<felt252>);
}

#[starknet::interface]
pub trait IReplaceable<TContractState> {
    fn get_upgrade_delay(self: @TContractState) -> u64;
    fn get_impl_activation_time(
        self: @TContractState, implementation_data: ImplementationData
    ) -> u64;
    fn add_new_implementation(ref self: TContractState, implementation_data: ImplementationData);
    fn remove_implementation(ref self: TContractState, implementation_data: ImplementationData);
    fn replace_to(ref self: TContractState, implementation_data: ImplementationData);
}

#[derive(Copy, Drop, PartialEq, starknet::Event)]
pub struct ImplementationAdded {
    pub implementation_data: ImplementationData,
}

#[derive(Copy, Drop, PartialEq, starknet::Event)]
pub struct ImplementationRemoved {
    pub implementation_data: ImplementationData,
}

#[derive(Copy, Drop, PartialEq, starknet::Event)]
pub struct ImplementationReplaced {
    pub implementation_data: ImplementationData,
}

#[derive(Copy, Drop, PartialEq, starknet::Event)]
pub struct ImplementationFinalized {
    pub impl_hash: ClassHash,
}
