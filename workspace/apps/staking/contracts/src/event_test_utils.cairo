use starknet::{ContractAddress};
use contracts::staking::Events as StakingEvents;
use contracts::staking::PauseEvents;
use contracts::pool::Events as PoolEvents;
use contracts::reward_supplier::Events as RewardSupplierEvents;
use snforge_std::cheatcodes::events::{Event, Events, EventSpy, EventSpyTrait, is_emitted};

pub fn assert_number_of_events(actual: u32, expected: u32, message: ByteArray) {
    assert_eq!(
        actual, expected, "{actual} events were emitted instead of {expected}. Context: {message}"
    );
}

pub fn panic_with_event_details(expected_emitted_by: @ContractAddress, details: ByteArray) {
    let start = format!("Could not match expected event from address {:?}", *expected_emitted_by);
    panic!("{}: {}", start, details);
}

pub fn assert_staker_exit_intent_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    exit_timestamp: u64,
    amount: u128
) {
    let expected_event = @contracts::staking::Staking::Event::StakerExitIntent(
        StakingEvents::StakerExitIntent { staker_address, exit_timestamp, amount }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "StakerExitIntent{{staker_address: {:?}, exit_timestamp: {}, amount: {}}}",
            staker_address,
            exit_timestamp,
            amount
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_new_staker_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    reward_address: ContractAddress,
    operational_address: ContractAddress,
    self_stake: u128,
) {
    let expected_event = @contracts::staking::Staking::Event::NewStaker(
        StakingEvents::NewStaker { staker_address, reward_address, operational_address, self_stake }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "NewStaker{{staker_address: {:?}, reward_address: {:?}, operational_address: {:?}, self_stake: {}}}",
            staker_address,
            reward_address,
            operational_address,
            self_stake
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_stake_balance_changed_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    old_self_stake: u128,
    old_delegated_stake: u128,
    new_self_stake: u128,
    new_delegated_stake: u128
) {
    let expected_event = @contracts::staking::Staking::Event::StakeBalanceChanged(
        StakingEvents::StakeBalanceChanged {
            staker_address, old_self_stake, old_delegated_stake, new_self_stake, new_delegated_stake
        }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "StakingEvents::StakeBalanceChanged{{staker_address: {:?}, old_self_stake: {}, 
                old_delegated_stake: {}, new_self_stake: {}, new_delegated_stake: {}}}",
            staker_address,
            old_self_stake,
            old_delegated_stake,
            new_self_stake,
            new_delegated_stake
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_pool_member_exit_intent_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    exit_timestamp: u64,
    amount: u128,
) {
    let expected_event = @contracts::pool::Pool::Event::PoolMemberExitIntent(
        PoolEvents::PoolMemberExitIntent { pool_member, exit_timestamp, amount }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "PoolMemberExitIntent{{pool_member: {:?}, exit_timestamp: {}, amount: {}}}",
            pool_member,
            exit_timestamp,
            amount
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_pool_member_reward_claimed_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    reward_address: ContractAddress,
    amount: u128,
) {
    let expected_event = @contracts::pool::Pool::Event::PoolMemberRewardClaimed(
        PoolEvents::PoolMemberRewardClaimed { pool_member, reward_address, amount }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "PoolMemberRewardClaimed{{pool_member: {:?}, reward_address: {:?}, amount: {}}}",
            pool_member,
            reward_address,
            amount
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_delegation_pool_member_balance_changed_event(
    mut spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    old_delegated_stake: u128,
    new_delegated_stake: u128,
) {
    let expected_event = @contracts::pool::Pool::Event::DelegationPoolMemberBalanceChanged(
        PoolEvents::DelegationPoolMemberBalanceChanged {
            pool_member, old_delegated_stake, new_delegated_stake
        }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "PoolEvents::DelegationPoolMemberBalanceChanged{{pool_member: {:?}, old_delegated_stake: {}, new_delegated_stake: {}}}",
            pool_member,
            old_delegated_stake,
            new_delegated_stake
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_staker_reward_address_change_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    new_address: ContractAddress,
    old_address: ContractAddress,
) {
    let expected_event = @contracts::staking::Staking::Event::StakerRewardAddressChanged(
        StakingEvents::StakerRewardAddressChanged { staker_address, new_address, old_address }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "StakerRewardAddressChanged{{staker_address: {:?}, new_address: {:?}, old_address: {:?}}}",
            staker_address,
            new_address,
            old_address
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_commission_changed_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    pool_contract: ContractAddress,
    new_commission: u16,
    old_commission: u16,
) {
    let expected_event = @contracts::staking::Staking::Event::CommissionChanged(
        StakingEvents::CommissionChanged {
            staker_address, pool_contract, new_commission, old_commission
        }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "CommissionChanged{{staker_address: {:?}, pool_contract: {:?}, new_commission: {}, old_commission: {}}}",
            staker_address,
            pool_contract,
            new_commission,
            old_commission
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_global_index_updated_event(
    spied_event: @(ContractAddress, Event),
    old_index: u64,
    new_index: u64,
    global_index_last_update_timestamp: u64,
    global_index_current_update_timestamp: u64,
) {
    let expected_event = @contracts::staking::Staking::Event::GlobalIndexUpdated(
        StakingEvents::GlobalIndexUpdated {
            old_index,
            new_index,
            global_index_last_update_timestamp,
            global_index_current_update_timestamp
        }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "GlobalIndexUpdated{{old_index: {}, new_index: {}, global_index_last_update_timestamp: {}, global_index_current_update_timestamp: {}}}",
            old_index,
            new_index,
            global_index_last_update_timestamp,
            global_index_current_update_timestamp
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_new_delegation_pool_event(
    mut spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    pool_contract: ContractAddress,
    commission: u16
) {
    let expected_event = @contracts::staking::Staking::Event::NewDelegationPool(
        StakingEvents::NewDelegationPool { staker_address, pool_contract, commission }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "StakingEvents::NewDelegationPool{{staker_address: {:?}, pool_contract: {:?}, commission: {}}}",
            staker_address,
            pool_contract,
            commission
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_pool_member_reward_address_change_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    new_address: ContractAddress,
    old_address: ContractAddress,
) {
    let expected_event = @contracts::pool::Pool::Event::PoolMemberRewardAddressChanged(
        PoolEvents::PoolMemberRewardAddressChanged { pool_member, new_address, old_address }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "PoolMemberRewardAddressChanged{{pool_member: {:?}, new_address: {:?}, old_address: {:?}}}",
            pool_member,
            new_address,
            old_address
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_staker_reward_claimed_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    reward_address: ContractAddress,
    amount: u128,
) {
    let expected_event = @contracts::staking::Staking::Event::StakerRewardClaimed(
        StakingEvents::StakerRewardClaimed { staker_address, reward_address, amount }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "StakerRewardClaimed{{staker_address: {:?}, reward_address: {:?}, amount: {}}}",
            staker_address,
            reward_address,
            amount
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_change_operational_address_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    new_address: ContractAddress,
    old_address: ContractAddress,
) {
    let expected_event = @contracts::staking::Staking::Event::OperationalAddressChanged(
        StakingEvents::OperationalAddressChanged { staker_address, new_address, old_address }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "OperationalAddressChanged{{staker_address: {:?}, new_address: {:?}, old_address: {:?}}}",
            staker_address,
            new_address,
            old_address
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_final_index_set_event(
    spied_event: @(ContractAddress, Event), staker_address: ContractAddress, final_staker_index: u64
) {
    let expected_event = @contracts::pool::Pool::Event::FinalIndexSet(
        PoolEvents::FinalIndexSet { staker_address, final_staker_index }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "FinalIndexSet{{staker_address: {:?}, final_staker_index: {}}}",
            staker_address,
            final_staker_index
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_calculated_rewards_event(
    spied_event: @(ContractAddress, Event),
    last_timestamp: u64,
    new_timestamp: u64,
    rewards_calculated: u128,
) {
    let expected_event = @contracts::reward_supplier::RewardSupplier::Event::CalculatedRewards(
        RewardSupplierEvents::CalculatedRewards {
            last_timestamp, new_timestamp, rewards_calculated
        }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "CalculatedRewards{{last_timestamp: {}, new_timestamp: {}, rewards_calculated: {}}}",
            last_timestamp,
            new_timestamp,
            rewards_calculated
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_mint_request_event(
    spied_event: @(ContractAddress, Event), total_amount: u128, num_msgs: u128
) {
    let expected_event = @contracts::reward_supplier::RewardSupplier::Event::mintRequest(
        RewardSupplierEvents::MintRequest { total_amount, num_msgs }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "MintRequest{{total_amount: {:?}, num_msgs: {}}}", total_amount, num_msgs
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_delete_staker_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    reward_address: ContractAddress,
    operational_address: ContractAddress,
    pool_contract: Option<ContractAddress>
) {
    let expected_event = @contracts::staking::Staking::Event::DeleteStaker(
        StakingEvents::DeleteStaker {
            staker_address, reward_address, operational_address, pool_contract
        }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "DeleteStaker{{staker_address: {:?}, reward_address: {:?}, operational_address: {:?}, pool_contract: {:?}}}",
            staker_address,
            reward_address,
            operational_address,
            pool_contract
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_delete_pool_member_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    reward_address: ContractAddress
) {
    let expected_event = @contracts::pool::Pool::Event::DeletePoolMember(
        PoolEvents::DeletePoolMember { pool_member, reward_address }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "DeletePoolMember{{pool_member: {:?}, reward_address: {:?}}}",
            pool_member,
            reward_address
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_new_pool_member_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    staker_address: ContractAddress,
    reward_address: ContractAddress,
    amount: u128
) {
    let expected_event = @contracts::pool::Pool::Event::NewPoolMember(
        PoolEvents::NewPoolMember { pool_member, staker_address, reward_address, amount }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "NewPoolMember{{pool_member: {:?}, staker_address: {:?}, reward_address: {:?}, amount: {}}}",
            pool_member,
            staker_address,
            reward_address,
            amount
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_rewards_supplied_to_delegation_pool_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    pool_address: ContractAddress,
    amount: u128
) {
    let expected_event = @contracts::staking::Staking::Event::RewardsSuppliedToDelegationPool(
        StakingEvents::RewardsSuppliedToDelegationPool { staker_address, pool_address, amount }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "RewardsSuppliedToDelegationPool{{staker_address: {:?}, pool_address: {:?}, amount: {}}}",
            staker_address,
            pool_address,
            amount
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_paused_event(spied_event: @(ContractAddress, Event), account: ContractAddress) {
    let expected_event = @contracts::staking::Staking::Event::Paused(
        PauseEvents::Paused { account }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!("Paused{{account: {:?}}}", account);
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_unpaused_event(spied_event: @(ContractAddress, Event), account: ContractAddress) {
    let expected_event = @contracts::staking::Staking::Event::Unpaused(
        PauseEvents::Unpaused { account }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!("Unpaused{{account: {:?}}}", account);
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn debug_dump_spied_events(ref spy: EventSpy) {
    let mut serialized = array![];
    Serde::<
        Array<(starknet::ContractAddress, snforge_std::Event)>
    >::serialize(@(spy.get_events().events), ref serialized);
    println!("{:?}", serialized);
    println!("[#events, (emitterAddress, #keys, keys..., #values, values...)...]");
}
