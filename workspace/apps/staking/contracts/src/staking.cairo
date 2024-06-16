#[starknet::interface]
trait EmptyContractInterface<T> {
}

#[starknet::contract]
mod my_contract {
    #[storage]
    struct Storage {
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
    }
}
