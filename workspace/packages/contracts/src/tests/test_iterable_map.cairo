use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IIterableMapTestContract<TContractState> {
    fn get_value(ref self: TContractState, key: u8) -> Option<i32>;
    fn set_value(ref self: TContractState, key: u8, value: i32);
    fn get_all_values(ref self: TContractState) -> Span<(u8, i32)>;
}

#[starknet::contract]
mod IterableMapTestContract {
    use contracts_commons::iterable_map::{
        IterableMap, IterableMapIntoIterImpl, IterableMapReadAccessImpl, IterableMapWriteAccessImpl,
    };

    #[storage]
    struct Storage {
        iterable_map: IterableMap<u8, i32>,
    }

    #[abi(embed_v0)]
    impl IterableMapTestContractImpl of super::IIterableMapTestContract<ContractState> {
        fn get_value(ref self: ContractState, key: u8) -> Option<i32> {
            self.iterable_map.read(key)
        }

        fn set_value(ref self: ContractState, key: u8, value: i32) {
            self.iterable_map.write(key, value);
        }

        fn get_all_values(ref self: ContractState) -> Span<(u8, i32)> {
            let mut array = array![];
            for (key, value) in self.iterable_map {
                array.append((key, value));
            };

            array.span()
        }
    }
}


fn deploy_iterable_map_test_contract() -> ContractAddress {
    let contract = declare("IterableMapTestContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_read_and_write() {
    let dispatcher = IIterableMapTestContractDispatcher {
        contract_address: deploy_iterable_map_test_contract(),
    };

    assert_eq!(dispatcher.get_value(1_u8), Option::None);
    dispatcher.set_value(1_u8, -10_i32);
    assert_eq!(dispatcher.get_value(1_u8), Option::Some(-10_i32));
}

#[test]
fn test_empty_map() {
    let dispatcher = IIterableMapTestContractDispatcher {
        contract_address: deploy_iterable_map_test_contract(),
    };

    assert_eq!(dispatcher.get_all_values().len(), 0);
}

#[test]
fn test_multiple_writes() {
    let dispatcher = IIterableMapTestContractDispatcher {
        contract_address: deploy_iterable_map_test_contract(),
    };

    dispatcher.set_value(1_u8, -10_i32);
    assert_eq!(dispatcher.get_value(1_u8), Option::Some(-10_i32));
    dispatcher.set_value(1_u8, -20_i32);
    assert_eq!(dispatcher.get_value(1_u8), Option::Some(-20_i32));

    assert_eq!(dispatcher.get_all_values().len(), 1);
}

#[test]
fn test_iterator() {
    let dispatcher = IIterableMapTestContractDispatcher {
        contract_address: deploy_iterable_map_test_contract(),
    };

    let inserted_pairs = array![(1_u8, -10_i32), (2_u8, -20_i32), (3_u8, -30_i32)].span();

    for (key, value) in inserted_pairs {
        dispatcher.set_value(*key, *value);
    };

    let mut read_pairs = array![];
    for (key, value) in dispatcher.get_all_values() {
        read_pairs.append((*key, *value));
    };

    let read_pairs = read_pairs.span();
    assert_eq!(read_pairs.len(), inserted_pairs.len());
    for i in 0..read_pairs.len() {
        assert_eq!(inserted_pairs.at(i), read_pairs.at(i));
    }
}
