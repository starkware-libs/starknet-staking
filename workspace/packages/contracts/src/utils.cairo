use contracts_commons::errors::assert_with_byte_array;
use contracts_commons::math::{Abs, FractionTrait};
use contracts_commons::types::time::time::{Time, Timestamp};
use contracts_commons::types::{HashType, PublicKey, Signature};
use openzeppelin::account::utils::is_valid_stark_signature;
use starknet::storage::{
    Mutable, StorageBase, StoragePath, StoragePointer, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};

pub trait AddToStorage<T> {
    type Value;
    fn add_and_write(self: T, value: Self::Value) -> Self::Value;
}
pub impl StoragePathAddImpl<
    T, +Add<T>, +Copy<T>, +starknet::Store<T>, +Drop<T>,
> of AddToStorage<StoragePath<Mutable<T>>> {
    type Value = T;
    fn add_and_write(self: StoragePath<Mutable<T>>, value: Self::Value) -> Self::Value {
        let new_value = self.read() + value;
        self.write(new_value);
        new_value
    }
}
pub impl StoragePointerAddImpl<
    T, +Add<T>, +Copy<T>, +starknet::Store<T>, +Drop<T>,
> of AddToStorage<StoragePointer<Mutable<T>>> {
    type Value = T;
    fn add_and_write(self: StoragePointer<Mutable<T>>, value: Self::Value) -> Self::Value {
        let new_value = self.read() + value;
        self.write(new_value);
        new_value
    }
}

pub impl StorageBaseAddImpl<
    T, +Add<T>, +Copy<T>, +starknet::Store<T>, +Drop<T>,
> of AddToStorage<StorageBase<Mutable<T>>> {
    type Value = T;
    fn add_and_write(self: StorageBase<Mutable<T>>, value: Self::Value) -> Self::Value {
        let new_value = self.read() + value;
        self.write(new_value);
        new_value
    }
}

pub trait SubFromStorage<T> {
    type Value;
    fn sub_and_write(self: T, value: Self::Value) -> Self::Value;
}
pub impl StoragePathSubImpl<
    T, +Sub<T>, +Copy<T>, +starknet::Store<T>, +Drop<T>,
> of SubFromStorage<StoragePath<Mutable<T>>> {
    type Value = T;
    fn sub_and_write(self: StoragePath<Mutable<T>>, value: Self::Value) -> Self::Value {
        let new_value = self.read() - value;
        self.write(new_value);
        new_value
    }
}
pub impl StoragePointerSubImpl<
    T, +Sub<T>, +Copy<T>, +starknet::Store<T>, +Drop<T>,
> of SubFromStorage<StoragePointer<Mutable<T>>> {
    type Value = T;
    fn sub_and_write(self: StoragePointer<Mutable<T>>, value: Self::Value) -> Self::Value {
        let new_value = self.read() - value;
        self.write(new_value);
        new_value
    }
}

pub impl StorageBaseSubImpl<
    T, +Sub<T>, +Copy<T>, +starknet::Store<T>, +Drop<T>,
> of SubFromStorage<StorageBase<Mutable<T>>> {
    type Value = T;
    fn sub_and_write(self: StorageBase<Mutable<T>>, value: Self::Value) -> Self::Value {
        let new_value = self.read() - value;
        self.write(new_value);
        new_value
    }
}

pub fn validate_stark_signature(public_key: PublicKey, msg_hash: HashType, signature: Signature) {
    assert(
        is_valid_stark_signature(:msg_hash, :public_key, :signature), 'INVALID_STARK_KEY_SIGNATURE',
    );
}

pub fn validate_expiration(expiration: Timestamp, err: felt252) {
    assert(Time::now() < expiration, err);
}

pub fn validate_ratio(n1: i64, d1: i64, n2: i64, d2: i64, err: ByteArray) {
    let f1 = FractionTrait::new(numerator: n1, denominator: d1.abs());
    let f2 = FractionTrait::new(numerator: n2, denominator: d2.abs());
    assert_with_byte_array(f1 <= f2, err);
}

