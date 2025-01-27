use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin::utils::snip12::{SNIP12Metadata, StarknetDomain, StructHash};
use starknet::get_tx_info;


/// Trait for calculating the hash of a message given the `public_key`
pub trait OffchainMessageHash<T> {
    fn get_message_hash(self: @T, public_key: felt252) -> felt252;
}

pub(crate) impl OffchainMessageHashImpl<
    T, +StructHash<T>, impl metadata: SNIP12Metadata,
> of OffchainMessageHash<T> {
    fn get_message_hash(self: @T, public_key: felt252) -> felt252 {
        let domain = StarknetDomain {
            name: metadata::name(),
            version: metadata::version(),
            chain_id: get_tx_info().unbox().chain_id,
            revision: '1',
        };
        let mut state = PoseidonTrait::new();
        state = state.update_with('StarkNet Message');
        state = state.update_with(domain.hash_struct());
        state = state.update_with(public_key);
        state = state.update_with(self.hash_struct());
        state.finalize()
    }
}
