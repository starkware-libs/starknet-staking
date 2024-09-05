pub fn assert_number_of_messages_to_l1(actual: u32, expected: u32, message: ByteArray) {
    assert_eq!(
        actual,
        expected,
        "{actual} messages_to_l1 were sent instead of {expected}. Context: {message}"
    );
}
