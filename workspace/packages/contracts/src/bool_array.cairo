struct BoolArrayRange {
    // Inclusive.
    lower_bound: usize,
    // Exclusive.
    upper_bound: usize,
}

pub struct BoolArray<T> {
    // TODO: Consider eliminate size limitations.
    bit_array: T,
    _range: BoolArrayRange,
}

pub trait BoolArrayTrait<T> {
    // TODO: Wrap return types with a 'Result'.
    fn get(self: @BoolArray<T>, index: usize) -> bool;
    fn set(ref self: BoolArray<T>, index: usize, value: bool);
    fn count(self: @BoolArray<T>) -> usize;
    fn clear(ref self: BoolArray<T>);
    fn set_all(ref self: BoolArray<T>);
    fn toggle(ref self: BoolArray<T>, index: usize);
    fn all(self: @BoolArray<T>) -> bool;
    fn any(self: @BoolArray<T>) -> bool;
    fn none(self: @BoolArray<T>) -> bool;
    fn get_true_indices(self: @BoolArray<T>) -> Span<usize>;
    fn set_lower_bound(ref self: BoolArray<T>, bound: usize);
    fn set_upper_bound(ref self: BoolArray<T>, bound: usize);
    fn is_initialized(self: @BoolArray<T>) -> bool;
    fn len(self: @BoolArray<T>) -> usize;
}

impl BoolArrayImpl<T, +Drop<T>> of BoolArrayTrait<T> {
    fn get(self: @BoolArray<T>, index: usize) -> bool {
        false
    }

    fn set(ref self: BoolArray<T>, index: usize, value: bool) {
        ()
    }

    fn count(self: @BoolArray<T>) -> usize {
        0
    }

    fn clear(ref self: BoolArray<T>) {
        ()
    }

    fn set_all(ref self: BoolArray<T>) {
        ()
    }

    fn toggle(ref self: BoolArray<T>, index: usize) {
        ()
    }

    fn all(self: @BoolArray<T>) -> bool {
        false
    }

    fn any(self: @BoolArray<T>) -> bool {
        false
    }

    fn none(self: @BoolArray<T>) -> bool {
        false
    }

    fn get_true_indices(self: @BoolArray<T>) -> Span<usize> {
        array![].span()
    }

    fn set_lower_bound(ref self: BoolArray<T>, bound: usize) {
        ()
    }

    fn set_upper_bound(ref self: BoolArray<T>, bound: usize) {
        ()
    }

    fn is_initialized(self: @BoolArray<T>) -> bool {
        false
    }

    fn len(self: @BoolArray<T>) -> usize {
        0
    }
}
