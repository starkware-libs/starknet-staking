use starknet::storage::{
    Mutable, StoragePath, StoragePointer, StoragePointerReadAccess, StoragePointerWriteAccess,
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
