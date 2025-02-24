use core::hash::Hash;
use core::iter::{IntoIterator, Iterator};
use core::pedersen::HashState;
use starknet::Store;
use starknet::storage::StoragePathEntry;
use starknet::storage::StoragePointerReadAccess;
use starknet::storage::StoragePointerWriteAccess;
use starknet::storage::{
    FlattenedStorage, Map, Mutable, MutableVecTrait, PendingStoragePath, PendingStoragePathTrait,
    StorageAsPath, StorageBase, StorageMapReadAccess, StorageMapWriteAccess, StorageNode,
    StorageNodeMut, StoragePath, StorageTrait, StorageTraitMut, Vec, VecTrait,
};

/// A Map like struct that represents a map in a contract storage that can also be iterated over.
/// Another thing that IterableMap is different from Map in that it returns Option<Value>, so values
/// that weren't written into it will return Option::None.
#[phantom]
pub struct IterableMap<K, V> {
    _inner_map: Map<K, Option<V>>,
    _keys: Vec<K>,
}

////////////////////////////////////////////////////////////////////
/// This code will be replaced by auto-generated code in the future.
const INNER_MAP_FIELD_NAME_HASH: felt252 = selector!("_inner_map");
const KEYS_FIELD_NAME_HASH: felt252 = selector!("_keys");

#[derive(Drop, Copy)]
struct IterableMapStorageBase<K, V> {
    _inner_map: StorageBase<Map<K, Option<V>>>,
    _keys: StorageBase<Vec<K>>,
}

impl IterableMapStorageImpl<K, V> of StorageTrait<IterableMap<K, V>> {
    type BaseType = IterableMapStorageBase<K, V>;
    fn storage(self: FlattenedStorage<IterableMap<K, V>>) -> IterableMapStorageBase<K, V> {
        let _inner_map = StorageBase { __base_address__: INNER_MAP_FIELD_NAME_HASH };
        let _keys = StorageBase { __base_address__: KEYS_FIELD_NAME_HASH };
        IterableMapStorageBase { _inner_map, _keys }
    }
}

#[derive(Drop, Copy)]
struct IterableMapStorageBaseMut<K, V> {
    _inner_map: StorageBase<Mutable<Map<K, Option<V>>>>,
    _keys: StorageBase<Mutable<Vec<K>>>,
}

impl IterableMapStorageImplMut<K, V> of StorageTraitMut<IterableMap<K, V>> {
    type BaseType = IterableMapStorageBaseMut<K, V>;
    fn storage_mut(
        self: FlattenedStorage<Mutable<IterableMap<K, V>>>,
    ) -> IterableMapStorageBaseMut<K, V> {
        let _inner_map = StorageBase { __base_address__: INNER_MAP_FIELD_NAME_HASH };
        let _keys = StorageBase { __base_address__: KEYS_FIELD_NAME_HASH };
        IterableMapStorageBaseMut { _inner_map, _keys }
    }
}

#[derive(Copy, Drop)]
struct IterableMapStorageNode<K, V> {
    _inner_map: PendingStoragePath<Map<K, Option<V>>>,
    _keys: PendingStoragePath<Vec<K>>,
}

impl IterableMapStorageNodeImpl<K, V> of StorageNode<IterableMap<K, V>> {
    type NodeType = IterableMapStorageNode<K, V>;
    fn storage_node(self: StoragePath<IterableMap<K, V>>) -> IterableMapStorageNode<K, V> {
        let _inner_map = PendingStoragePathTrait::new(@self, INNER_MAP_FIELD_NAME_HASH);
        let _keys = PendingStoragePathTrait::new(@self, KEYS_FIELD_NAME_HASH);
        IterableMapStorageNode { _inner_map, _keys }
    }
}

#[derive(Copy, Drop)]
struct IterableMapStorageNodeMut<K, V> {
    _inner_map: PendingStoragePath<Mutable<Map<K, Option<V>>>>,
    _keys: PendingStoragePath<Mutable<Vec<K>>>,
}

impl IterableMapStorageNodeMutImpl<K, V> of StorageNodeMut<IterableMap<K, V>> {
    type NodeType = IterableMapStorageNodeMut<K, V>;
    fn storage_node_mut(
        self: StoragePath<Mutable<IterableMap<K, V>>>,
    ) -> IterableMapStorageNodeMut<K, V> {
        let _inner_map = PendingStoragePathTrait::new(@self, INNER_MAP_FIELD_NAME_HASH);
        let _keys = PendingStoragePathTrait::new(@self, KEYS_FIELD_NAME_HASH);
        IterableMapStorageNodeMut { _inner_map, _keys }
    }
}
////////////////////////////////////////////////////////////////////

/// Trait for the interface of a iterable map.
pub trait IterableMapTrait<T> {
    type Key;
    fn len(self: T) -> u64;
}

impl StoragePathIterableMapImpl<
    K, V, +Drop<K>, +Drop<V>, +Store<Option<V>>, +Hash<K, HashState>,
> of IterableMapTrait<StoragePath<IterableMap<K, V>>> {
    type Key = K;
    fn len(self: StoragePath<IterableMap<K, V>>) -> u64 {
        self._keys.len()
    }
}

impl StoragePathMutableIterableMapImpl<
    K, V, +Drop<K>, +Drop<V>, +Store<Option<V>>, +Hash<K, HashState>,
> of IterableMapTrait<StoragePath<Mutable<IterableMap<K, V>>>> {
    type Key = K;
    fn len(self: StoragePath<Mutable<IterableMap<K, V>>>) -> u64 {
        self._keys.len()
    }
}

pub impl IterableMapTraitImpl<
    T,
    +Drop<T>,
    impl StorageAsPathImpl: StorageAsPath<T>,
    impl StoragePathImpl: IterableMapTrait<StoragePath<StorageAsPathImpl::Value>>,
    +Drop<StoragePathImpl::Key>,
> of IterableMapTrait<T> {
    type Key = StoragePathImpl::Key;
    fn len(self: T) -> u64 {
        self.as_path().len()
    }
}

/// Read and write access trait implementations:
impl StoragePathIterableMapReadAccessImpl<
    K, V, +Drop<K>, +Store<Option<V>>, +Hash<K, HashState>,
> of StorageMapReadAccess<StoragePath<IterableMap<K, V>>> {
    type Key = K;
    type Value = Option<V>;
    fn read(self: StoragePath<IterableMap<K, V>>, key: Self::Key) -> Self::Value {
        self._inner_map.entry(key).read()
    }
}

impl StoragePathMutableIterableMapReadAccessImpl<
    K, V, +Drop<K>, +Store<Option<V>>, +Hash<K, HashState>,
> of StorageMapReadAccess<StoragePath<Mutable<IterableMap<K, V>>>> {
    type Key = K;
    type Value = Option<V>;
    fn read(self: StoragePath<Mutable<IterableMap<K, V>>>, key: Self::Key) -> Self::Value {
        self._inner_map.entry(key).read()
    }
}

pub impl IterableMapReadAccessImpl<
    T,
    +Drop<T>,
    impl StorageAsPathImpl: StorageAsPath<T>,
    impl StoragePathImpl: StorageMapReadAccess<StoragePath<StorageAsPathImpl::Value>>,
    +IterableMapTrait<StoragePath<StorageAsPathImpl::Value>>,
    +Drop<StoragePathImpl::Key>,
> of StorageMapReadAccess<T> {
    type Key = StoragePathImpl::Key;
    type Value = StoragePathImpl::Value;
    fn read(self: T, key: Self::Key) -> Self::Value {
        self.as_path().read(key)
    }
}

impl StoragePathIterableMapWriteAccessImpl<
    K, V, +Drop<K>, +Drop<V>, +Store<K>, +Store<V>, +Hash<K, HashState>, +Copy<K>,
> of StorageMapWriteAccess<StoragePath<Mutable<IterableMap<K, V>>>> {
    type Key = K;
    type Value = V;
    fn write(self: StoragePath<Mutable<IterableMap<K, V>>>, key: Self::Key, value: Self::Value) {
        let entry = self._inner_map.entry(key);
        if entry.read().is_none() {
            self._keys.append().write(key);
        }
        entry.write(Option::Some(value));
    }
}

pub impl IterableMapWriteAccessImpl<
    T,
    +Drop<T>,
    impl StorageAsPathImpl: StorageAsPath<T>,
    impl StoragePathImpl: StorageMapWriteAccess<StoragePath<StorageAsPathImpl::Value>>,
    +IterableMapTrait<StoragePath<StorageAsPathImpl::Value>>,
    +Drop<StoragePathImpl::Key>,
    +Drop<StoragePathImpl::Value>,
> of StorageMapWriteAccess<T> {
    type Key = StoragePathImpl::Key;
    type Value = StoragePathImpl::Value;
    fn write(self: T, key: Self::Key, value: Self::Value) {
        self.as_path().write(key, value)
    }
}

/// Iterator and IntoItarator implementations:
#[derive(Copy, Drop)]
struct MapIterator<K, V> {
    _inner_map: StoragePath<Map<K, Option<V>>>,
    _keys: StoragePath<Vec<K>>,
    _next_index: u64,
}

pub impl IterableMapIteratorImpl<
    K, V, +Drop<K>, +Store<K>, +Hash<K, HashState>, +Copy<K>, +Store<Option<V>>,
> of Iterator<MapIterator<K, V>> {
    type Item = (K, V);
    fn next(ref self: MapIterator<K, V>) -> Option<Self::Item> {
        if let Option::Some(key) = self._keys.get(self._next_index) {
            self._next_index += 1;
            let key = key.read();
            let value = self._inner_map.read(key).unwrap();
            Option::Some((key, value))
        } else {
            Option::None
        }
    }
}

impl StoragePathIterableMapIntoIteratorImpl<
    K, V, +Drop<K>, +Store<K>, +Hash<K, HashState>, +Copy<K>, +Store<Option<V>>,
> of IntoIterator<StoragePath<IterableMap<K, V>>> {
    type IntoIter = MapIterator<K, V>;
    fn into_iter(self: StoragePath<IterableMap<K, V>>) -> Self::IntoIter {
        MapIterator {
            _inner_map: self._inner_map.as_path(), _keys: self._keys.as_path(), _next_index: 0,
        }
    }
}

#[derive(Copy, Drop)]
struct MapIteratorMut<K, V> {
    _inner_map: StoragePath<Mutable<Map<K, Option<V>>>>,
    _keys: StoragePath<Mutable<Vec<K>>>,
    _next_index: u64,
}

pub impl IterableMapIteratorMutImpl<
    K, V, +Drop<K>, +Store<K>, +Hash<K, HashState>, +Copy<K>, +Store<Option<V>>,
> of Iterator<MapIteratorMut<K, V>> {
    type Item = (K, V);
    fn next(ref self: MapIteratorMut<K, V>) -> Option<Self::Item> {
        if let Option::Some(key) = self._keys.get(self._next_index) {
            self._next_index += 1;
            let key = key.read();
            let value = self._inner_map.read(key).unwrap();
            Option::Some((key, value))
        } else {
            Option::None
        }
    }
}

impl StoragePathMutableIterableMapIntoIteratorImpl<
    K, V, +Drop<K>, +Store<K>, +Hash<K, HashState>, +Copy<K>, +Store<Option<V>>,
> of IntoIterator<StoragePath<Mutable<IterableMap<K, V>>>> {
    type IntoIter = MapIteratorMut<K, V>;
    fn into_iter(self: StoragePath<Mutable<IterableMap<K, V>>>) -> Self::IntoIter {
        MapIteratorMut {
            _inner_map: self._inner_map.as_path(), _keys: self._keys.as_path(), _next_index: 0,
        }
    }
}

pub impl IterableMapIntoIterImpl<
    T,
    +Drop<T>,
    impl StorageAsPathImpl: StorageAsPath<T>,
    impl StoragePathImpl: IntoIterator<StoragePath<StorageAsPathImpl::Value>>,
    +IterableMapTrait<StoragePath<StorageAsPathImpl::Value>>,
> of IntoIterator<T> {
    type IntoIter = StoragePathImpl::IntoIter;
    fn into_iter(self: T) -> Self::IntoIter {
        self.as_path().into_iter()
    }
}
