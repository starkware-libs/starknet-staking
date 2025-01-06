#[starknet::interface]
pub trait IWork<TContractState> {
    fn work(ref self: TContractState, work_info: WorkInfo);
}

// TODO: implement
pub mod Events {}

// TODO: implement
#[derive(Debug, Copy, Drop, Serde, PartialEq)]
pub struct WorkInfo {}
