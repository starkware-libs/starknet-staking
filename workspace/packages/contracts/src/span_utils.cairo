/// Validate that all values in the span are within the range [from, to).
pub fn validate_range<T, +Drop<T>, +Copy<T>, +PartialOrd<T>>(from: T, to: T, span: Span<T>) {
    for value in span {
        assert(from <= *value && *value < to, 'Value is out of range');
    }
}

pub fn validate_median<T, +Drop<T>, +Copy<T>, +PartialOrd<T>>(median: T, span: Span<T>) {
    let mut lower_amount: usize = 0;
    let mut higher_amount: usize = 0;
    let mut equal_amount: usize = 0;
    for value in span {
        if *value < median {
            lower_amount += 1;
        } else if *value > median {
            higher_amount += 1;
        } else {
            equal_amount += 1;
        }
    };
    assert(2 * (lower_amount + equal_amount) >= span.len(), 'Invalid median: too skewed');
    assert(2 * (higher_amount + equal_amount) >= span.len(), 'Invalid median: too skewed');
}


#[cfg(test)]
mod tests {
    use super::{validate_median, validate_range};

    #[test]
    fn test_validate_range_happy_flow() {
        let span: Span<u32> = array![0, 9, 1].span();
        validate_range(0, 10, span);
    }

    #[test]
    #[should_panic(expected: 'Value is out of range')]
    fn test_validate_range_out_of_range() {
        let span: Span<u32> = array![0, 10, 1].span();
        validate_range(0, 10, span);
    }

    #[test]
    fn test_validate_range_empty_span() {
        let span: Span<u32> = array![].span();
        validate_range(0, 10, span);
        validate_range(0, 0, span);
        validate_range(10, 10, span);
    }

    #[test]
    fn test_validate_range_single_value_happy_flow() {
        let span: Span<u32> = array![5].span();
        validate_range(0, 10, span);
        validate_range(5, 6, span);
    }

    #[test]
    #[should_panic(expected: 'Value is out of range')]
    fn test_validate_range_single_value_out_of_range() {
        let span: Span<u32> = array![10].span();
        validate_range(0, 10, span);
    }

    #[test]
    #[should_panic(expected: 'Value is out of range')]
    fn test_validate_range_to_lower_than_from() {
        let span: Span<u32> = array![5].span();
        validate_range(10, 0, span);
    }


    #[test]
    fn test_validate_median_odd_length_happy_flow() {
        let span: Span<u128> = array![450, 150, 350, 250, 50].span();
        validate_median(median: 250, :span);
    }

    #[test]
    #[should_panic(expected: 'Invalid median: too skewed')]
    fn test_validate_median_odd_length_bad_flow() {
        let span: Span<u128> = array![450, 150, 350, 250, 50].span();
        validate_median(median: 240, :span);
    }

    #[test]
    fn test_validate_median_even_length_happy_flow() {
        let span: Span<u128> = array![150, 50, 250, 350].span();
        validate_median(median: 200, :span);
        validate_median(median: 250, :span);
        validate_median(median: 150, :span);
    }

    #[test]
    #[should_panic(expected: 'Invalid median: too skewed')]
    fn test_validate_median_even_length_bad_flow() {
        let span: Span<u128> = array![150, 50, 250, 350].span();
        validate_median(median: 260, :span);
    }

    #[test]
    fn test_validate_median_single_element() {
        let span: Span<u128> = array![100].span();
        validate_median(median: 100, :span);
    }

    #[test]
    fn test_validate_median_duplicate_values_happy_flow() {
        let span: Span<u128> = array![100, 100, 200, 400, 200, 300, 400].span();
        validate_median(median: 200, :span);
    }

    #[test]
    #[should_panic(expected: 'Invalid median: too skewed')]
    fn test_validate_median_duplicate_values_bad_flow() {
        let span: Span<u128> = array![100, 200, 400, 200, 300, 400, 100].span();
        validate_median(median: 250, :span);
    }

    #[test]
    fn test_validate_median_empty_list() {
        let span: Span<u128> = array![].span();
        validate_median(median: 100, :span);
    }
}
