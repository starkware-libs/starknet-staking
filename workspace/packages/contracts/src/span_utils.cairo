pub fn contains<T, +PartialEq<T>, +Drop<T>, +Copy<T>>(span: Span<T>, element: T) -> bool {
    let mut result = false;
    for value in span {
        if *value == element {
            result = true;
        }
    };
    result
}


#[cfg(test)]
mod tests {
    use super::contains;

    #[test]
    fn test_contains() {
        let span: Span<u32> = array![1, 2, 3].span();
        assert(contains(span, 2), 'Should contain 2');
        assert(!contains(span, 4), 'Should not contain 4');
    }

    #[test]
    fn test_contains_empty_span() {
        let span: Span<u32> = array![].span();
        assert(!contains(span, 1), 'Should not contain 1');
    }
}
