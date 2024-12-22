use core::panics::panic_with_byte_array;

pub fn assert_with_byte_array(condition: bool, err: ByteArray) {
    if !condition {
        panic_with_byte_array(err: @err)
    }
}
