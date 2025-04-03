use staking::pool::interface::PoolMemberInfo;
use starknet::ContractAddress;

/// Pool V0 interface.
#[starknet::interface]
pub trait IPoolV0<TContractState> {
    fn pool_member_info(self: @TContractState, pool_member: ContractAddress) -> PoolMemberInfo;
    fn get_pool_member_info(
        self: @TContractState, pool_member: ContractAddress,
    ) -> Option<PoolMemberInfo>;
}
