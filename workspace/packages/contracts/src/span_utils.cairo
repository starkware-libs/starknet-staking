/// Check that all values in the span are within the range [from, to).
/// The Result is true if all values are within the range, false otherwise.
pub fn check_range<T, +Drop<T>, +Copy<T>, +PartialOrd<T>>(from: T, to: T, span: Span<T>) -> bool {
    let mut result = true;
    for value in span {
        if from > *value || *value >= to {
            result = false;
            break;
        }
    };
    result
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
    use super::{check_range, validate_median};

    #[test]
    fn test_check_range_in_range() {
        let span: Span<u32> = array![0, 9, 1].span();
        assert(check_range(0, 10, span), 'Should be in range');
    }

    #[test]
    fn test_check_range_out_of_range() {
        let span: Span<u32> = array![0, 10, 1].span();
        assert(!check_range(0, 10, span), 'Should be out of range');
    }

    #[test]
    fn test_check_range_empty_span() {
        let span: Span<u32> = array![].span();
        assert(check_range(0, 10, span), 'Should be in range');
        assert(check_range(0, 0, span), 'Should be in range');
        assert(check_range(10, 10, span), 'Should be in range');
    }

    #[test]
    fn test_check_range_single_value() {
        let span: Span<u32> = array![5].span();
        assert(check_range(0, 10, span), 'Should be in range');
        assert(check_range(5, 6, span), 'Should be in range');
        assert(!check_range(0, 5, span), 'Should be out of range');
    }

    #[test]
    fn test_check_range_to_lower_than_from() {
        let span: Span<u32> = array![5].span();
        assert(!check_range(10, 0, span), 'Should be out of range');
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
