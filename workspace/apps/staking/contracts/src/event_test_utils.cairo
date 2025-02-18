use contracts_commons::test_utils::assert_expected_event_emitted;
use contracts_commons::types::time::time::{TimeDelta, Timestamp};
use snforge_std::cheatcodes::events::{Event, EventSpy, EventSpyTrait};
use staking::minting_curve::interface::ConfigEvents as MintingCurveConfigEvents;
use staking::pool::interface::Events as PoolEvents;
use staking::reward_supplier::interface::Events as RewardSupplierEvents;
use staking::staking::interface::{
    ConfigEvents as StakingConfigEvents, Events as StakingEvents, PauseEvents as StakingPauseEvents,
};
use staking::types::{Amount, Commission, Index, Inflation};
use starknet::ContractAddress;

pub(crate) fn assert_number_of_events(actual: u32, expected: u32, message: ByteArray) {
    assert_eq!(
        actual, expected, "{actual} events were emitted instead of {expected}. Context: {message}",
    );
}

pub(crate) fn panic_with_event_details(expected_emitted_by: @ContractAddress, details: ByteArray) {
    let start = format!("Could not match expected event from address {:?}", *expected_emitted_by);
    panic!("{}: {}", start, details);
}

pub(crate) fn assert_staker_exit_intent_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    exit_timestamp: Timestamp,
    amount: Amount,
) {
    let expected_event = StakingEvents::StakerExitIntent { staker_address, exit_timestamp, amount };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("StakerExitIntent"),
        expected_event_name: "StakerExitIntent",
    );
}

pub(crate) fn assert_new_staker_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    reward_address: ContractAddress,
    operational_address: ContractAddress,
    self_stake: Amount,
) {
    let expected_event = StakingEvents::NewStaker {
        staker_address, reward_address, operational_address, self_stake,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("NewStaker"),
        expected_event_name: "NewStaker",
    );
}

pub(crate) fn assert_stake_balance_changed_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    old_self_stake: Amount,
    old_delegated_stake: Amount,
    new_self_stake: Amount,
    new_delegated_stake: Amount,
) {
    let expected_event = StakingEvents::StakeBalanceChanged {
        staker_address, old_self_stake, old_delegated_stake, new_self_stake, new_delegated_stake,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("StakeBalanceChanged"),
        expected_event_name: "StakeBalanceChanged",
    );
}

pub(crate) fn assert_pool_member_exit_intent_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    exit_timestamp: Timestamp,
    amount: Amount,
) {
    let expected_event = PoolEvents::PoolMemberExitIntent { pool_member, exit_timestamp, amount };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("PoolMemberExitIntent"),
        expected_event_name: "PoolMemberExitIntent",
    );
}

pub(crate) fn assert_pool_member_exit_action_event(
    spied_event: @(ContractAddress, Event), pool_member: ContractAddress, unpool_amount: Amount,
) {
    let expected_event = PoolEvents::PoolMemberExitAction { pool_member, unpool_amount };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("PoolMemberExitAction"),
        expected_event_name: "PoolMemberExitAction",
    );
}

pub(crate) fn assert_pool_member_reward_claimed_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    reward_address: ContractAddress,
    amount: Amount,
) {
    let expected_event = PoolEvents::PoolMemberRewardClaimed {
        pool_member, reward_address, amount,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("PoolMemberRewardClaimed"),
        expected_event_name: "PoolMemberRewardClaimed",
    );
}

pub(crate) fn assert_delegation_pool_member_balance_changed_event(
    mut spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    old_delegated_stake: Amount,
    new_delegated_stake: Amount,
) {
    let expected_event = PoolEvents::PoolMemberBalanceChanged {
        pool_member, old_delegated_stake, new_delegated_stake,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("PoolMemberBalanceChanged"),
        expected_event_name: "PoolMemberBalanceChanged",
    );
}

pub(crate) fn assert_staker_reward_address_change_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    new_address: ContractAddress,
    old_address: ContractAddress,
) {
    let expected_event = StakingEvents::StakerRewardAddressChanged {
        staker_address, new_address, old_address,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("StakerRewardAddressChanged"),
        expected_event_name: "StakerRewardAddressChanged",
    );
}

pub(crate) fn assert_commission_changed_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    pool_contract: ContractAddress,
    new_commission: Commission,
    old_commission: Commission,
) {
    let expected_event = StakingEvents::CommissionChanged {
        staker_address, pool_contract, new_commission, old_commission,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("CommissionChanged"),
        expected_event_name: "CommissionChanged",
    );
}

pub(crate) fn assert_global_index_updated_event(
    spied_event: @(ContractAddress, Event),
    old_index: Index,
    new_index: Index,
    global_index_last_update_timestamp: Timestamp,
    global_index_current_update_timestamp: Timestamp,
) {
    let expected_event = StakingEvents::GlobalIndexUpdated {
        old_index,
        new_index,
        global_index_last_update_timestamp,
        global_index_current_update_timestamp,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("GlobalIndexUpdated"),
        expected_event_name: "GlobalIndexUpdated",
    );
}

pub(crate) fn assert_new_delegation_pool_event(
    mut spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    pool_contract: ContractAddress,
    commission: Commission,
) {
    let expected_event = StakingEvents::NewDelegationPool {
        staker_address, pool_contract, commission,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("NewDelegationPool"),
        expected_event_name: "NewDelegationPool",
    );
}

pub(crate) fn assert_remove_from_delegation_pool_intent_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    pool_contract: ContractAddress,
    identifier: felt252,
    old_intent_amount: Amount,
    new_intent_amount: Amount,
) {
    let expected_event = StakingEvents::RemoveFromDelegationPoolIntent {
        staker_address, pool_contract, identifier, old_intent_amount, new_intent_amount,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("RemoveFromDelegationPoolIntent"),
        expected_event_name: "RemoveFromDelegationPoolIntent",
    );
}

pub(crate) fn assert_remove_from_delegation_pool_action_event(
    spied_event: @(ContractAddress, Event),
    pool_contract: ContractAddress,
    identifier: felt252,
    amount: Amount,
) {
    let expected_event = StakingEvents::RemoveFromDelegationPoolAction {
        pool_contract, identifier, amount,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("RemoveFromDelegationPoolAction"),
        expected_event_name: "RemoveFromDelegationPoolAction",
    );
}

pub(crate) fn assert_pool_member_reward_address_change_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    new_address: ContractAddress,
    old_address: ContractAddress,
) {
    let expected_event = PoolEvents::PoolMemberRewardAddressChanged {
        pool_member, new_address, old_address,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("PoolMemberRewardAddressChanged"),
        expected_event_name: "PoolMemberRewardAddressChanged",
    );
}

pub(crate) fn assert_staker_reward_claimed_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    reward_address: ContractAddress,
    amount: Amount,
) {
    let expected_event = StakingEvents::StakerRewardClaimed {
        staker_address, reward_address, amount,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("StakerRewardClaimed"),
        expected_event_name: "StakerRewardClaimed",
    );
}

pub(crate) fn assert_declare_operational_address_event(
    spied_event: @(ContractAddress, Event),
    operational_address: ContractAddress,
    staker_address: ContractAddress,
) {
    let expected_event = StakingEvents::OperationalAddressDeclared {
        operational_address, staker_address,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("OperationalAddressDeclared"),
        expected_event_name: "OperationalAddressDeclared",
    );
}

pub(crate) fn assert_change_operational_address_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    new_address: ContractAddress,
    old_address: ContractAddress,
) {
    let expected_event = StakingEvents::OperationalAddressChanged {
        staker_address, new_address, old_address,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("OperationalAddressChanged"),
        expected_event_name: "OperationalAddressChanged",
    );
}

pub(crate) fn assert_staker_removed_event(
    spied_event: @(ContractAddress, Event), staker_address: ContractAddress,
) {
    let expected_event = PoolEvents::StakerRemoved { staker_address };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("StakerRemoved"),
        expected_event_name: "StakerRemoved",
    );
}

pub(crate) fn assert_calculated_rewards_event(
    spied_event: @(ContractAddress, Event),
    last_timestamp: Timestamp,
    new_timestamp: Timestamp,
    rewards_calculated: Amount,
) {
    let expected_event = RewardSupplierEvents::CalculatedRewards {
        last_timestamp, new_timestamp, rewards_calculated,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("CalculatedRewards"),
        expected_event_name: "CalculatedRewards",
    );
}

pub(crate) fn assert_mint_request_event(
    spied_event: @(ContractAddress, Event), total_amount: Amount, num_msgs: u128,
) {
    let expected_event = RewardSupplierEvents::MintRequest { total_amount, num_msgs };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("MintRequest"),
        expected_event_name: "MintRequest",
    );
}

pub(crate) fn assert_delete_staker_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    reward_address: ContractAddress,
    operational_address: ContractAddress,
    pool_contract: Option<ContractAddress>,
) {
    let expected_event = StakingEvents::DeleteStaker {
        staker_address, reward_address, operational_address, pool_contract,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("DeleteStaker"),
        expected_event_name: "DeleteStaker",
    );
}

pub(crate) fn assert_delete_pool_member_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    reward_address: ContractAddress,
) {
    let expected_event = PoolEvents::DeletePoolMember { pool_member, reward_address };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("DeletePoolMember"),
        expected_event_name: "DeletePoolMember",
    );
}

pub(crate) fn assert_switch_delegation_pool_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    new_delegation_pool: ContractAddress,
    amount: Amount,
) {
    let expected_event = PoolEvents::SwitchDelegationPool {
        pool_member, new_delegation_pool, amount,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("SwitchDelegationPool"),
        expected_event_name: "SwitchDelegationPool",
    );
}

pub(crate) fn assert_change_delegation_pool_intent_event(
    spied_event: @(ContractAddress, Event),
    pool_contract: ContractAddress,
    identifier: felt252,
    old_intent_amount: Amount,
    new_intent_amount: Amount,
) {
    let expected_event = StakingEvents::ChangeDelegationPoolIntent {
        pool_contract, identifier, old_intent_amount, new_intent_amount,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("ChangeDelegationPoolIntent"),
        expected_event_name: "ChangeDelegationPoolIntent",
    );
}

pub(crate) fn assert_new_pool_member_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    staker_address: ContractAddress,
    reward_address: ContractAddress,
    amount: Amount,
) {
    let expected_event = PoolEvents::NewPoolMember {
        pool_member, staker_address, reward_address, amount,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("NewPoolMember"),
        expected_event_name: "NewPoolMember",
    );
}

pub(crate) fn assert_rewards_supplied_to_delegation_pool_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    pool_address: ContractAddress,
    amount: Amount,
) {
    let expected_event = StakingEvents::RewardsSuppliedToDelegationPool {
        staker_address, pool_address, amount,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("RewardsSuppliedToDelegationPool"),
        expected_event_name: "RewardsSuppliedToDelegationPool",
    );
}

pub(crate) fn assert_paused_event(
    spied_event: @(ContractAddress, Event), account: ContractAddress,
) {
    let expected_event = StakingPauseEvents::Paused { account };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("Paused"),
        expected_event_name: "Paused",
    );
}

pub(crate) fn assert_unpaused_event(
    spied_event: @(ContractAddress, Event), account: ContractAddress,
) {
    let expected_event = StakingPauseEvents::Unpaused { account };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("Unpaused"),
        expected_event_name: "Unpaused",
    );
}

pub(crate) fn debug_dump_spied_events(ref spy: EventSpy) {
    let mut serialized = array![];
    Serde::<
        Array<(starknet::ContractAddress, snforge_std::Event)>,
    >::serialize(@(spy.get_events().events), ref serialized);
    println!("{:?}", serialized);
    println!("[#events, (emitterAddress, #keys, keys..., #values, values...)...]");
}

pub(crate) fn assert_minting_cap_changed_event(
    spied_event: @(ContractAddress, Event), old_c: Inflation, new_c: Inflation,
) {
    let expected_event = MintingCurveConfigEvents::MintingCapChanged { old_c, new_c };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("MintingCapChanged"),
        expected_event_name: "MintingCapChanged",
    );
}

pub(crate) fn assert_minimum_stake_changed_event(
    spied_event: @(ContractAddress, Event), old_min_stake: Amount, new_min_stake: Amount,
) {
    let expected_event = StakingConfigEvents::MinimumStakeChanged { old_min_stake, new_min_stake };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("MinimumStakeChanged"),
        expected_event_name: "MinimumStakeChanged",
    );
}

pub(crate) fn assert_exit_wait_window_changed_event(
    spied_event: @(ContractAddress, Event), old_exit_window: TimeDelta, new_exit_window: TimeDelta,
) {
    let expected_event = StakingConfigEvents::ExitWaitWindowChanged {
        old_exit_window, new_exit_window,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("ExitWaitWindowChanged"),
        expected_event_name: "ExitWaitWindowChanged",
    );
}

pub(crate) fn assert_reward_supplier_changed_event(
    spied_event: @(ContractAddress, Event),
    old_reward_supplier: ContractAddress,
    new_reward_supplier: ContractAddress,
) {
    let expected_event = StakingConfigEvents::RewardSupplierChanged {
        old_reward_supplier, new_reward_supplier,
    };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("RewardSupplierChanged"),
        expected_event_name: "RewardSupplierChanged",
    );
}
