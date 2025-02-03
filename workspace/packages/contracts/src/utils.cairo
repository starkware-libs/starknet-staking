use contracts_commons::errors::assert_with_byte_array;
use contracts_commons::math::FractionTrait;
use contracts_commons::types::time::time::{Time, Timestamp};
use contracts_commons::types::{HashType, PublicKey, Signature};
use openzeppelin::account::utils::is_valid_stark_signature;
use starknet::Store;
use starknet::storage::{Mutable, StorageAsPointer, StoragePointer};

pub trait AddToStorage<T> {
    type Value;
    fn add_and_write(self: T, value: Self::Value) -> Self::Value;
}

pub impl AddToStorageGeneralImpl<
    T,
    +Drop<T>,
    impl AsPointerImpl: StorageAsPointer<T>,
    impl PointerImpl: AddToStorage<StoragePointer<AsPointerImpl::Value>>,
    +Drop<PointerImpl::Value>,
> of AddToStorage<T> {
    type Value = PointerImpl::Value;
    fn add_and_write(self: T, value: Self::Value) -> Self::Value {
        self.as_ptr().deref().add_and_write(value)
    }
}

pub impl StoragePointerAddToStorageImpl<
    TValue, +Drop<TValue>, +Add<TValue>, +Copy<TValue>, +Store<TValue>,
> of AddToStorage<StoragePointer<Mutable<TValue>>> {
    type Value = TValue;
    fn add_and_write(self: StoragePointer<Mutable<TValue>>, value: TValue) -> TValue {
        let new_value = self.read() + value;
        self.write(new_value);
        new_value
    }
}

pub trait SubFromStorage<T> {
    type Value;
    fn sub_and_write(self: T, value: Self::Value) -> Self::Value;
}

pub impl SubFromStorageGeneralImpl<
    T,
    +Drop<T>,
    impl AsPointerImpl: StorageAsPointer<T>,
    impl PointerImpl: SubFromStorage<StoragePointer<AsPointerImpl::Value>>,
    +Drop<PointerImpl::Value>,
> of SubFromStorage<T> {
    type Value = PointerImpl::Value;
    fn sub_and_write(self: T, value: Self::Value) -> Self::Value {
        self.as_ptr().deref().sub_and_write(value)
    }
}

pub impl StoragePathSubFromStorageImpl<
    TValue, +Drop<TValue>, +Sub<TValue>, +Copy<TValue>, +Store<TValue>,
> of SubFromStorage<StoragePointer<Mutable<TValue>>> {
    type Value = TValue;
    fn sub_and_write(self: StoragePointer<Mutable<TValue>>, value: TValue) -> TValue {
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

pub fn validate_ratio<N, D, +Into<N, i128>, +Drop<N>, +Into<D, u128>, +Drop<D>>(
    n1: N, d1: D, n2: N, d2: D, err: ByteArray,
) {
    let f1 = FractionTrait::new(numerator: n1, denominator: d1);
    let f2 = FractionTrait::new(numerator: n2, denominator: d2);
    assert_with_byte_array(f1 <= f2, err);
}
