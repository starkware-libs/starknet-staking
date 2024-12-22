pub(crate) trait BitMask<T> {
    // A default bit_mask implementation could reduce duplication, but Cairo has limited support for
    // default implementations in generic traits.
    fn bit_mask(index: usize) -> Result<T, felt252>;
    fn inverse_bit_mask(index: usize) -> Result<T, felt252>;
}

pub(crate) trait PowOfTwo<T> {
    fn two_to_the(power: usize) -> Result<T, felt252>;
}

pub(crate) impl U8PowOfTwo of PowOfTwo<u8> {
    fn two_to_the(power: usize) -> Result<u8, felt252> {
        let val = match power {
            0 => TwoToThe::_0,
            1 => TwoToThe::_1,
            2 => TwoToThe::_2,
            3 => TwoToThe::_3,
            4 => TwoToThe::_4,
            5 => TwoToThe::_5,
            6 => TwoToThe::_6,
            7 => TwoToThe::_7,
            _ => { return Result::Err('Invalid power'); },
        };
        Result::Ok(val)
    }
}

pub(crate) impl U8BitMask of BitMask<u8> {
    fn bit_mask(index: usize) -> Result<u8, felt252> {
        PowOfTwo::two_to_the(index)
    }

    fn inverse_bit_mask(index: usize) -> Result<u8, felt252> {
        let val = match index {
            0 => InverseBitMask::u8_0,
            1 => InverseBitMask::u8_1,
            2 => InverseBitMask::u8_2,
            3 => InverseBitMask::u8_3,
            4 => InverseBitMask::u8_4,
            5 => InverseBitMask::u8_5,
            6 => InverseBitMask::u8_6,
            7 => InverseBitMask::u8_7,
            _ => { return Result::Err('Invalid index'); },
        };
        Result::Ok(val)
    }
}

pub(crate) impl U16PowOfTwo of PowOfTwo<u16> {
    fn two_to_the(power: usize) -> Result<u16, felt252> {
        let val = match power {
            0 => TwoToThe::_0.into(),
            1 => TwoToThe::_1.into(),
            2 => TwoToThe::_2.into(),
            3 => TwoToThe::_3.into(),
            4 => TwoToThe::_4.into(),
            5 => TwoToThe::_5.into(),
            6 => TwoToThe::_6.into(),
            7 => TwoToThe::_7.into(),
            8 => TwoToThe::_8,
            9 => TwoToThe::_9,
            10 => TwoToThe::_10,
            11 => TwoToThe::_11,
            12 => TwoToThe::_12,
            13 => TwoToThe::_13,
            14 => TwoToThe::_14,
            15 => TwoToThe::_15,
            _ => { return Result::Err('Invalid power'); },
        };
        Result::Ok(val)
    }
}

pub(crate) impl U16BitMask of BitMask<u16> {
    fn bit_mask(index: usize) -> Result<u16, felt252> {
        PowOfTwo::two_to_the(index)
    }

    fn inverse_bit_mask(index: usize) -> Result<u16, felt252> {
        let val = match index {
            0 => InverseBitMask::u16_0,
            1 => InverseBitMask::u16_1,
            2 => InverseBitMask::u16_2,
            3 => InverseBitMask::u16_3,
            4 => InverseBitMask::u16_4,
            5 => InverseBitMask::u16_5,
            6 => InverseBitMask::u16_6,
            7 => InverseBitMask::u16_7,
            8 => InverseBitMask::u16_8,
            9 => InverseBitMask::u16_9,
            10 => InverseBitMask::u16_10,
            11 => InverseBitMask::u16_11,
            12 => InverseBitMask::u16_12,
            13 => InverseBitMask::u16_13,
            14 => InverseBitMask::u16_14,
            15 => InverseBitMask::u16_15,
            _ => { return Result::Err('Invalid index'); },
        };
        Result::Ok(val)
    }
}

pub(crate) impl U32PowOfTwo of PowOfTwo<u32> {
    fn two_to_the(power: usize) -> Result<u32, felt252> {
        let val = match power {
            0 => TwoToThe::_0.into(),
            1 => TwoToThe::_1.into(),
            2 => TwoToThe::_2.into(),
            3 => TwoToThe::_3.into(),
            4 => TwoToThe::_4.into(),
            5 => TwoToThe::_5.into(),
            6 => TwoToThe::_6.into(),
            7 => TwoToThe::_7.into(),
            8 => TwoToThe::_8.into(),
            9 => TwoToThe::_9.into(),
            10 => TwoToThe::_10.into(),
            11 => TwoToThe::_11.into(),
            12 => TwoToThe::_12.into(),
            13 => TwoToThe::_13.into(),
            14 => TwoToThe::_14.into(),
            15 => TwoToThe::_15.into(),
            16 => TwoToThe::_16,
            17 => TwoToThe::_17,
            18 => TwoToThe::_18,
            19 => TwoToThe::_19,
            20 => TwoToThe::_20,
            21 => TwoToThe::_21,
            22 => TwoToThe::_22,
            23 => TwoToThe::_23,
            24 => TwoToThe::_24,
            25 => TwoToThe::_25,
            26 => TwoToThe::_26,
            27 => TwoToThe::_27,
            28 => TwoToThe::_28,
            29 => TwoToThe::_29,
            30 => TwoToThe::_30,
            31 => TwoToThe::_31,
            _ => { return Result::Err('Invalid power'); },
        };
        Result::Ok(val)
    }
}

pub(crate) impl U32BitMask of BitMask<u32> {
    fn bit_mask(index: usize) -> Result<u32, felt252> {
        PowOfTwo::two_to_the(index)
    }

    fn inverse_bit_mask(index: usize) -> Result<u32, felt252> {
        let val = match index {
            0 => InverseBitMask::u32_0,
            1 => InverseBitMask::u32_1,
            2 => InverseBitMask::u32_2,
            3 => InverseBitMask::u32_3,
            4 => InverseBitMask::u32_4,
            5 => InverseBitMask::u32_5,
            6 => InverseBitMask::u32_6,
            7 => InverseBitMask::u32_7,
            8 => InverseBitMask::u32_8,
            9 => InverseBitMask::u32_9,
            10 => InverseBitMask::u32_10,
            11 => InverseBitMask::u32_11,
            12 => InverseBitMask::u32_12,
            13 => InverseBitMask::u32_13,
            14 => InverseBitMask::u32_14,
            15 => InverseBitMask::u32_15,
            16 => InverseBitMask::u32_16,
            17 => InverseBitMask::u32_17,
            18 => InverseBitMask::u32_18,
            19 => InverseBitMask::u32_19,
            20 => InverseBitMask::u32_20,
            21 => InverseBitMask::u32_21,
            22 => InverseBitMask::u32_22,
            23 => InverseBitMask::u32_23,
            24 => InverseBitMask::u32_24,
            25 => InverseBitMask::u32_25,
            26 => InverseBitMask::u32_26,
            27 => InverseBitMask::u32_27,
            28 => InverseBitMask::u32_28,
            29 => InverseBitMask::u32_29,
            30 => InverseBitMask::u32_30,
            31 => InverseBitMask::u32_31,
            _ => { return Result::Err('Invalid index'); },
        };
        Result::Ok(val)
    }
}

pub(crate) impl U64PowOfTwo of PowOfTwo<u64> {
    fn two_to_the(power: usize) -> Result<u64, felt252> {
        let val = match power {
            0 => TwoToThe::_0.into(),
            1 => TwoToThe::_1.into(),
            2 => TwoToThe::_2.into(),
            3 => TwoToThe::_3.into(),
            4 => TwoToThe::_4.into(),
            5 => TwoToThe::_5.into(),
            6 => TwoToThe::_6.into(),
            7 => TwoToThe::_7.into(),
            8 => TwoToThe::_8.into(),
            9 => TwoToThe::_9.into(),
            10 => TwoToThe::_10.into(),
            11 => TwoToThe::_11.into(),
            12 => TwoToThe::_12.into(),
            13 => TwoToThe::_13.into(),
            14 => TwoToThe::_14.into(),
            15 => TwoToThe::_15.into(),
            16 => TwoToThe::_16.into(),
            17 => TwoToThe::_17.into(),
            18 => TwoToThe::_18.into(),
            19 => TwoToThe::_19.into(),
            20 => TwoToThe::_20.into(),
            21 => TwoToThe::_21.into(),
            22 => TwoToThe::_22.into(),
            23 => TwoToThe::_23.into(),
            24 => TwoToThe::_24.into(),
            25 => TwoToThe::_25.into(),
            26 => TwoToThe::_26.into(),
            27 => TwoToThe::_27.into(),
            28 => TwoToThe::_28.into(),
            29 => TwoToThe::_29.into(),
            30 => TwoToThe::_30.into(),
            31 => TwoToThe::_31.into(),
            32 => TwoToThe::_32,
            33 => TwoToThe::_33,
            34 => TwoToThe::_34,
            35 => TwoToThe::_35,
            36 => TwoToThe::_36,
            37 => TwoToThe::_37,
            38 => TwoToThe::_38,
            39 => TwoToThe::_39,
            40 => TwoToThe::_40,
            41 => TwoToThe::_41,
            42 => TwoToThe::_42,
            43 => TwoToThe::_43,
            44 => TwoToThe::_44,
            45 => TwoToThe::_45,
            46 => TwoToThe::_46,
            47 => TwoToThe::_47,
            48 => TwoToThe::_48,
            49 => TwoToThe::_49,
            50 => TwoToThe::_50,
            51 => TwoToThe::_51,
            52 => TwoToThe::_52,
            53 => TwoToThe::_53,
            54 => TwoToThe::_54,
            55 => TwoToThe::_55,
            56 => TwoToThe::_56,
            57 => TwoToThe::_57,
            58 => TwoToThe::_58,
            59 => TwoToThe::_59,
            60 => TwoToThe::_60,
            61 => TwoToThe::_61,
            62 => TwoToThe::_62,
            63 => TwoToThe::_63,
            _ => { return Result::Err('Invalid power'); },
        };
        Result::Ok(val)
    }
}

pub(crate) impl U64BitMask of BitMask<u64> {
    fn bit_mask(index: usize) -> Result<u64, felt252> {
        PowOfTwo::two_to_the(index)
    }

    fn inverse_bit_mask(index: usize) -> Result<u64, felt252> {
        let val = match index {
            0 => InverseBitMask::u64_0,
            1 => InverseBitMask::u64_1,
            2 => InverseBitMask::u64_2,
            3 => InverseBitMask::u64_3,
            4 => InverseBitMask::u64_4,
            5 => InverseBitMask::u64_5,
            6 => InverseBitMask::u64_6,
            7 => InverseBitMask::u64_7,
            8 => InverseBitMask::u64_8,
            9 => InverseBitMask::u64_9,
            10 => InverseBitMask::u64_10,
            11 => InverseBitMask::u64_11,
            12 => InverseBitMask::u64_12,
            13 => InverseBitMask::u64_13,
            14 => InverseBitMask::u64_14,
            15 => InverseBitMask::u64_15,
            16 => InverseBitMask::u64_16,
            17 => InverseBitMask::u64_17,
            18 => InverseBitMask::u64_18,
            19 => InverseBitMask::u64_19,
            20 => InverseBitMask::u64_20,
            21 => InverseBitMask::u64_21,
            22 => InverseBitMask::u64_22,
            23 => InverseBitMask::u64_23,
            24 => InverseBitMask::u64_24,
            25 => InverseBitMask::u64_25,
            26 => InverseBitMask::u64_26,
            27 => InverseBitMask::u64_27,
            28 => InverseBitMask::u64_28,
            29 => InverseBitMask::u64_29,
            30 => InverseBitMask::u64_30,
            31 => InverseBitMask::u64_31,
            32 => InverseBitMask::u64_32,
            33 => InverseBitMask::u64_33,
            34 => InverseBitMask::u64_34,
            35 => InverseBitMask::u64_35,
            36 => InverseBitMask::u64_36,
            37 => InverseBitMask::u64_37,
            38 => InverseBitMask::u64_38,
            39 => InverseBitMask::u64_39,
            40 => InverseBitMask::u64_40,
            41 => InverseBitMask::u64_41,
            42 => InverseBitMask::u64_42,
            43 => InverseBitMask::u64_43,
            44 => InverseBitMask::u64_44,
            45 => InverseBitMask::u64_45,
            46 => InverseBitMask::u64_46,
            47 => InverseBitMask::u64_47,
            48 => InverseBitMask::u64_48,
            49 => InverseBitMask::u64_49,
            50 => InverseBitMask::u64_50,
            51 => InverseBitMask::u64_51,
            52 => InverseBitMask::u64_52,
            53 => InverseBitMask::u64_53,
            54 => InverseBitMask::u64_54,
            55 => InverseBitMask::u64_55,
            56 => InverseBitMask::u64_56,
            57 => InverseBitMask::u64_57,
            58 => InverseBitMask::u64_58,
            59 => InverseBitMask::u64_59,
            60 => InverseBitMask::u64_60,
            61 => InverseBitMask::u64_61,
            62 => InverseBitMask::u64_62,
            63 => InverseBitMask::u64_63,
            _ => { return Result::Err('Invalid index'); },
        };
        Result::Ok(val)
    }
}

pub(crate) impl U128PowOfTwo of PowOfTwo<u128> {
    fn two_to_the(power: usize) -> Result<u128, felt252> {
        let val = match power {
            0 => TwoToThe::_0.into(),
            1 => TwoToThe::_1.into(),
            2 => TwoToThe::_2.into(),
            3 => TwoToThe::_3.into(),
            4 => TwoToThe::_4.into(),
            5 => TwoToThe::_5.into(),
            6 => TwoToThe::_6.into(),
            7 => TwoToThe::_7.into(),
            8 => TwoToThe::_8.into(),
            9 => TwoToThe::_9.into(),
            10 => TwoToThe::_10.into(),
            11 => TwoToThe::_11.into(),
            12 => TwoToThe::_12.into(),
            13 => TwoToThe::_13.into(),
            14 => TwoToThe::_14.into(),
            15 => TwoToThe::_15.into(),
            16 => TwoToThe::_16.into(),
            17 => TwoToThe::_17.into(),
            18 => TwoToThe::_18.into(),
            19 => TwoToThe::_19.into(),
            20 => TwoToThe::_20.into(),
            21 => TwoToThe::_21.into(),
            22 => TwoToThe::_22.into(),
            23 => TwoToThe::_23.into(),
            24 => TwoToThe::_24.into(),
            25 => TwoToThe::_25.into(),
            26 => TwoToThe::_26.into(),
            27 => TwoToThe::_27.into(),
            28 => TwoToThe::_28.into(),
            29 => TwoToThe::_29.into(),
            30 => TwoToThe::_30.into(),
            31 => TwoToThe::_31.into(),
            32 => TwoToThe::_32.into(),
            33 => TwoToThe::_33.into(),
            34 => TwoToThe::_34.into(),
            35 => TwoToThe::_35.into(),
            36 => TwoToThe::_36.into(),
            37 => TwoToThe::_37.into(),
            38 => TwoToThe::_38.into(),
            39 => TwoToThe::_39.into(),
            40 => TwoToThe::_40.into(),
            41 => TwoToThe::_41.into(),
            42 => TwoToThe::_42.into(),
            43 => TwoToThe::_43.into(),
            44 => TwoToThe::_44.into(),
            45 => TwoToThe::_45.into(),
            46 => TwoToThe::_46.into(),
            47 => TwoToThe::_47.into(),
            48 => TwoToThe::_48.into(),
            49 => TwoToThe::_49.into(),
            50 => TwoToThe::_50.into(),
            51 => TwoToThe::_51.into(),
            52 => TwoToThe::_52.into(),
            53 => TwoToThe::_53.into(),
            54 => TwoToThe::_54.into(),
            55 => TwoToThe::_55.into(),
            56 => TwoToThe::_56.into(),
            57 => TwoToThe::_57.into(),
            58 => TwoToThe::_58.into(),
            59 => TwoToThe::_59.into(),
            60 => TwoToThe::_60.into(),
            61 => TwoToThe::_61.into(),
            62 => TwoToThe::_62.into(),
            63 => TwoToThe::_63.into(),
            64 => TwoToThe::_64,
            65 => TwoToThe::_65,
            66 => TwoToThe::_66,
            67 => TwoToThe::_67,
            68 => TwoToThe::_68,
            69 => TwoToThe::_69,
            70 => TwoToThe::_70,
            71 => TwoToThe::_71,
            72 => TwoToThe::_72,
            73 => TwoToThe::_73,
            74 => TwoToThe::_74,
            75 => TwoToThe::_75,
            76 => TwoToThe::_76,
            77 => TwoToThe::_77,
            78 => TwoToThe::_78,
            79 => TwoToThe::_79,
            80 => TwoToThe::_80,
            81 => TwoToThe::_81,
            82 => TwoToThe::_82,
            83 => TwoToThe::_83,
            84 => TwoToThe::_84,
            85 => TwoToThe::_85,
            86 => TwoToThe::_86,
            87 => TwoToThe::_87,
            88 => TwoToThe::_88,
            89 => TwoToThe::_89,
            90 => TwoToThe::_90,
            91 => TwoToThe::_91,
            92 => TwoToThe::_92,
            93 => TwoToThe::_93,
            94 => TwoToThe::_94,
            95 => TwoToThe::_95,
            96 => TwoToThe::_96,
            97 => TwoToThe::_97,
            98 => TwoToThe::_98,
            99 => TwoToThe::_99,
            100 => TwoToThe::_100,
            101 => TwoToThe::_101,
            102 => TwoToThe::_102,
            103 => TwoToThe::_103,
            104 => TwoToThe::_104,
            105 => TwoToThe::_105,
            106 => TwoToThe::_106,
            107 => TwoToThe::_107,
            108 => TwoToThe::_108,
            109 => TwoToThe::_109,
            110 => TwoToThe::_110,
            111 => TwoToThe::_111,
            112 => TwoToThe::_112,
            113 => TwoToThe::_113,
            114 => TwoToThe::_114,
            115 => TwoToThe::_115,
            116 => TwoToThe::_116,
            117 => TwoToThe::_117,
            118 => TwoToThe::_118,
            119 => TwoToThe::_119,
            120 => TwoToThe::_120,
            121 => TwoToThe::_121,
            122 => TwoToThe::_122,
            123 => TwoToThe::_123,
            124 => TwoToThe::_124,
            125 => TwoToThe::_125,
            126 => TwoToThe::_126,
            127 => TwoToThe::_127,
            _ => { return Result::Err('Invalid power'); },
        };
        Result::Ok(val)
    }
}

pub(crate) impl U128BitMask of BitMask<u128> {
    fn bit_mask(index: usize) -> Result<u128, felt252> {
        PowOfTwo::two_to_the(index)
    }

    fn inverse_bit_mask(index: usize) -> Result<u128, felt252> {
        let val = match index {
            0 => InverseBitMask::u128_0,
            1 => InverseBitMask::u128_1,
            2 => InverseBitMask::u128_2,
            3 => InverseBitMask::u128_3,
            4 => InverseBitMask::u128_4,
            5 => InverseBitMask::u128_5,
            6 => InverseBitMask::u128_6,
            7 => InverseBitMask::u128_7,
            8 => InverseBitMask::u128_8,
            9 => InverseBitMask::u128_9,
            10 => InverseBitMask::u128_10,
            11 => InverseBitMask::u128_11,
            12 => InverseBitMask::u128_12,
            13 => InverseBitMask::u128_13,
            14 => InverseBitMask::u128_14,
            15 => InverseBitMask::u128_15,
            16 => InverseBitMask::u128_16,
            17 => InverseBitMask::u128_17,
            18 => InverseBitMask::u128_18,
            19 => InverseBitMask::u128_19,
            20 => InverseBitMask::u128_20,
            21 => InverseBitMask::u128_21,
            22 => InverseBitMask::u128_22,
            23 => InverseBitMask::u128_23,
            24 => InverseBitMask::u128_24,
            25 => InverseBitMask::u128_25,
            26 => InverseBitMask::u128_26,
            27 => InverseBitMask::u128_27,
            28 => InverseBitMask::u128_28,
            29 => InverseBitMask::u128_29,
            30 => InverseBitMask::u128_30,
            31 => InverseBitMask::u128_31,
            32 => InverseBitMask::u128_32,
            33 => InverseBitMask::u128_33,
            34 => InverseBitMask::u128_34,
            35 => InverseBitMask::u128_35,
            36 => InverseBitMask::u128_36,
            37 => InverseBitMask::u128_37,
            38 => InverseBitMask::u128_38,
            39 => InverseBitMask::u128_39,
            40 => InverseBitMask::u128_40,
            41 => InverseBitMask::u128_41,
            42 => InverseBitMask::u128_42,
            43 => InverseBitMask::u128_43,
            44 => InverseBitMask::u128_44,
            45 => InverseBitMask::u128_45,
            46 => InverseBitMask::u128_46,
            47 => InverseBitMask::u128_47,
            48 => InverseBitMask::u128_48,
            49 => InverseBitMask::u128_49,
            50 => InverseBitMask::u128_50,
            51 => InverseBitMask::u128_51,
            52 => InverseBitMask::u128_52,
            53 => InverseBitMask::u128_53,
            54 => InverseBitMask::u128_54,
            55 => InverseBitMask::u128_55,
            56 => InverseBitMask::u128_56,
            57 => InverseBitMask::u128_57,
            58 => InverseBitMask::u128_58,
            59 => InverseBitMask::u128_59,
            60 => InverseBitMask::u128_60,
            61 => InverseBitMask::u128_61,
            62 => InverseBitMask::u128_62,
            63 => InverseBitMask::u128_63,
            64 => InverseBitMask::u128_64,
            65 => InverseBitMask::u128_65,
            66 => InverseBitMask::u128_66,
            67 => InverseBitMask::u128_67,
            68 => InverseBitMask::u128_68,
            69 => InverseBitMask::u128_69,
            70 => InverseBitMask::u128_70,
            71 => InverseBitMask::u128_71,
            72 => InverseBitMask::u128_72,
            73 => InverseBitMask::u128_73,
            74 => InverseBitMask::u128_74,
            75 => InverseBitMask::u128_75,
            76 => InverseBitMask::u128_76,
            77 => InverseBitMask::u128_77,
            78 => InverseBitMask::u128_78,
            79 => InverseBitMask::u128_79,
            80 => InverseBitMask::u128_80,
            81 => InverseBitMask::u128_81,
            82 => InverseBitMask::u128_82,
            83 => InverseBitMask::u128_83,
            84 => InverseBitMask::u128_84,
            85 => InverseBitMask::u128_85,
            86 => InverseBitMask::u128_86,
            87 => InverseBitMask::u128_87,
            88 => InverseBitMask::u128_88,
            89 => InverseBitMask::u128_89,
            90 => InverseBitMask::u128_90,
            91 => InverseBitMask::u128_91,
            92 => InverseBitMask::u128_92,
            93 => InverseBitMask::u128_93,
            94 => InverseBitMask::u128_94,
            95 => InverseBitMask::u128_95,
            96 => InverseBitMask::u128_96,
            97 => InverseBitMask::u128_97,
            98 => InverseBitMask::u128_98,
            99 => InverseBitMask::u128_99,
            100 => InverseBitMask::u128_100,
            101 => InverseBitMask::u128_101,
            102 => InverseBitMask::u128_102,
            103 => InverseBitMask::u128_103,
            104 => InverseBitMask::u128_104,
            105 => InverseBitMask::u128_105,
            106 => InverseBitMask::u128_106,
            107 => InverseBitMask::u128_107,
            108 => InverseBitMask::u128_108,
            109 => InverseBitMask::u128_109,
            110 => InverseBitMask::u128_110,
            111 => InverseBitMask::u128_111,
            112 => InverseBitMask::u128_112,
            113 => InverseBitMask::u128_113,
            114 => InverseBitMask::u128_114,
            115 => InverseBitMask::u128_115,
            116 => InverseBitMask::u128_116,
            117 => InverseBitMask::u128_117,
            118 => InverseBitMask::u128_118,
            119 => InverseBitMask::u128_119,
            120 => InverseBitMask::u128_120,
            121 => InverseBitMask::u128_121,
            122 => InverseBitMask::u128_122,
            123 => InverseBitMask::u128_123,
            124 => InverseBitMask::u128_124,
            125 => InverseBitMask::u128_125,
            126 => InverseBitMask::u128_126,
            127 => InverseBitMask::u128_127,
            _ => { return Result::Err('Invalid index'); },
        };
        Result::Ok(val)
    }
}

mod TwoToThe {
    // TODO: Add an underscore between every 4 digits.
    pub const _0: u8 = 0b1;
    pub const _1: u8 = 0b10;
    pub const _2: u8 = 0b100;
    pub const _3: u8 = 0b1000;
    pub const _4: u8 = 0b10000;
    pub const _5: u8 = 0b100000;
    pub const _6: u8 = 0b1000000;
    pub const _7: u8 = 0b10000000;
    pub const _8: u16 = 0b100000000;
    pub const _9: u16 = 0b1000000000;
    pub const _10: u16 = 0b10000000000;
    pub const _11: u16 = 0b100000000000;
    pub const _12: u16 = 0b1000000000000;
    pub const _13: u16 = 0b10000000000000;
    pub const _14: u16 = 0b100000000000000;
    pub const _15: u16 = 0b1000000000000000;
    pub const _16: u32 = 0b10000000000000000;
    pub const _17: u32 = 0b100000000000000000;
    pub const _18: u32 = 0b1000000000000000000;
    pub const _19: u32 = 0b10000000000000000000;
    pub const _20: u32 = 0b100000000000000000000;
    pub const _21: u32 = 0b1000000000000000000000;
    pub const _22: u32 = 0b10000000000000000000000;
    pub const _23: u32 = 0b100000000000000000000000;
    pub const _24: u32 = 0b1000000000000000000000000;
    pub const _25: u32 = 0b10000000000000000000000000;
    pub const _26: u32 = 0b100000000000000000000000000;
    pub const _27: u32 = 0b1000000000000000000000000000;
    pub const _28: u32 = 0b10000000000000000000000000000;
    pub const _29: u32 = 0b100000000000000000000000000000;
    pub const _30: u32 = 0b1000000000000000000000000000000;
    pub const _31: u32 = 0b10000000000000000000000000000000;
    pub const _32: u64 = 0b100000000000000000000000000000000;
    pub const _33: u64 = 0b1000000000000000000000000000000000;
    pub const _34: u64 = 0b10000000000000000000000000000000000;
    pub const _35: u64 = 0b100000000000000000000000000000000000;
    pub const _36: u64 = 0b1000000000000000000000000000000000000;
    pub const _37: u64 = 0b10000000000000000000000000000000000000;
    pub const _38: u64 = 0b100000000000000000000000000000000000000;
    pub const _39: u64 = 0b1000000000000000000000000000000000000000;
    pub const _40: u64 = 0b10000000000000000000000000000000000000000;
    pub const _41: u64 = 0b100000000000000000000000000000000000000000;
    pub const _42: u64 = 0b1000000000000000000000000000000000000000000;
    pub const _43: u64 = 0b10000000000000000000000000000000000000000000;
    pub const _44: u64 = 0b100000000000000000000000000000000000000000000;
    pub const _45: u64 = 0b1000000000000000000000000000000000000000000000;
    pub const _46: u64 = 0b10000000000000000000000000000000000000000000000;
    pub const _47: u64 = 0b100000000000000000000000000000000000000000000000;
    pub const _48: u64 = 0b1000000000000000000000000000000000000000000000000;
    pub const _49: u64 = 0b10000000000000000000000000000000000000000000000000;
    pub const _50: u64 = 0b100000000000000000000000000000000000000000000000000;
    pub const _51: u64 = 0b1000000000000000000000000000000000000000000000000000;
    pub const _52: u64 = 0b10000000000000000000000000000000000000000000000000000;
    pub const _53: u64 = 0b100000000000000000000000000000000000000000000000000000;
    pub const _54: u64 = 0b1000000000000000000000000000000000000000000000000000000;
    pub const _55: u64 = 0b10000000000000000000000000000000000000000000000000000000;
    pub const _56: u64 = 0b100000000000000000000000000000000000000000000000000000000;
    pub const _57: u64 = 0b1000000000000000000000000000000000000000000000000000000000;
    pub const _58: u64 = 0b10000000000000000000000000000000000000000000000000000000000;
    pub const _59: u64 = 0b100000000000000000000000000000000000000000000000000000000000;
    pub const _60: u64 = 0b1000000000000000000000000000000000000000000000000000000000000;
    pub const _61: u64 = 0b10000000000000000000000000000000000000000000000000000000000000;
    pub const _62: u64 = 0b100000000000000000000000000000000000000000000000000000000000000;
    pub const _63: u64 = 0b1000000000000000000000000000000000000000000000000000000000000000;
    pub const _64: u128 = 0b10000000000000000000000000000000000000000000000000000000000000000;
    pub const _65: u128 = 0b100000000000000000000000000000000000000000000000000000000000000000;
    pub const _66: u128 = 0b1000000000000000000000000000000000000000000000000000000000000000000;
    pub const _67: u128 = 0b10000000000000000000000000000000000000000000000000000000000000000000;
    pub const _68: u128 = 0b100000000000000000000000000000000000000000000000000000000000000000000;
    pub const _69: u128 = 0b1000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _70: u128 = 0b10000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _71: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _72: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _73: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _74: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _75: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _76: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _77: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _78: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _79: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _80: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _81: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _82: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _83: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _84: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _85: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _86: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _87: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _88: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _89: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _90: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _91: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _92: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _93: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _94: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _95: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _96: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _97: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _98: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _99: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _100: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _101: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _102: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _103: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _104: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _105: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _106: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _107: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _108: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _109: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _110: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _111: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _112: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _113: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _114: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _115: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _116: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _117: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _118: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _119: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _120: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _121: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _122: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _123: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _124: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _125: u128 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _126: u128 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    pub const _127: u128 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _128: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _129: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _130: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _131: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _132: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _133: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _134: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _135: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _136: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _137: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _138: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _139: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _140: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _141: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _142: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _143: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _144: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _145: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _146: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _147: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _148: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _149: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _150: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _151: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _152: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _153: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _154: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _155: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _156: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _157: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _158: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _159: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _160: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _161: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _162: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _163: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _164: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _165: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _166: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _167: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _168: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _169: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _170: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _171: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _172: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _173: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _174: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _175: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _176: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _177: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _178: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _179: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _180: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _181: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _182: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _183: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _184: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _185: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _186: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _187: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _188: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _189: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _190: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _191: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _192: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _193: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _194: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _195: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _196: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _197: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _198: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _199: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _200: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _201: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _202: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _203: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _204: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _205: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _206: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _207: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _208: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _209: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _210: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _211: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _212: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _213: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _214: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _215: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _216: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _217: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _218: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _219: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _220: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _221: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _222: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _223: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _224: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _225: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _226: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _227: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _228: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _229: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _230: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _231: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _232: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _233: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _234: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _235: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _236: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _237: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _238: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _239: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _240: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _241: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _242: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _243: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _244: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _245: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _246: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _247: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _248: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _249: felt252 =
        0b1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _250: felt252 =
        0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    const _251: felt252 =
        0b100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
}

mod InverseBitMask {
    pub const u8_0: u8 = 0b1111_1110;
    pub const u8_1: u8 = 0b1111_1101;
    pub const u8_2: u8 = 0b1111_1011;
    pub const u8_3: u8 = 0b1111_0111;
    pub const u8_4: u8 = 0b1110_1111;
    pub const u8_5: u8 = 0b1101_1111;
    pub const u8_6: u8 = 0b1011_1111;
    pub const u8_7: u8 = 0b0111_1111;
    pub const u16_0: u16 = 0b1111_1111_1111_1110;
    pub const u16_1: u16 = 0b1111_1111_1111_1101;
    pub const u16_2: u16 = 0b1111_1111_1111_1011;
    pub const u16_3: u16 = 0b1111_1111_1111_0111;
    pub const u16_4: u16 = 0b1111_1111_1110_1111;
    pub const u16_5: u16 = 0b1111_1111_1101_1111;
    pub const u16_6: u16 = 0b1111_1111_1011_1111;
    pub const u16_7: u16 = 0b1111_1111_0111_1111;
    pub const u16_8: u16 = 0b1111_1110_1111_1111;
    pub const u16_9: u16 = 0b1111_1101_1111_1111;
    pub const u16_10: u16 = 0b1111_1011_1111_1111;
    pub const u16_11: u16 = 0b1111_0111_1111_1111;
    pub const u16_12: u16 = 0b1110_1111_1111_1111;
    pub const u16_13: u16 = 0b1101_1111_1111_1111;
    pub const u16_14: u16 = 0b1011_1111_1111_1111;
    pub const u16_15: u16 = 0b0111_1111_1111_1111;
    pub const u32_0: u32 = 0b1111_1111_1111_1111_1111_1111_1111_1110;
    pub const u32_1: u32 = 0b1111_1111_1111_1111_1111_1111_1111_1101;
    pub const u32_2: u32 = 0b1111_1111_1111_1111_1111_1111_1111_1011;
    pub const u32_3: u32 = 0b1111_1111_1111_1111_1111_1111_1111_0111;
    pub const u32_4: u32 = 0b1111_1111_1111_1111_1111_1111_1110_1111;
    pub const u32_5: u32 = 0b1111_1111_1111_1111_1111_1111_1101_1111;
    pub const u32_6: u32 = 0b1111_1111_1111_1111_1111_1111_1011_1111;
    pub const u32_7: u32 = 0b1111_1111_1111_1111_1111_1111_0111_1111;
    pub const u32_8: u32 = 0b1111_1111_1111_1111_1111_1110_1111_1111;
    pub const u32_9: u32 = 0b1111_1111_1111_1111_1111_1101_1111_1111;
    pub const u32_10: u32 = 0b1111_1111_1111_1111_1111_1011_1111_1111;
    pub const u32_11: u32 = 0b1111_1111_1111_1111_1111_0111_1111_1111;
    pub const u32_12: u32 = 0b1111_1111_1111_1111_1110_1111_1111_1111;
    pub const u32_13: u32 = 0b1111_1111_1111_1111_1101_1111_1111_1111;
    pub const u32_14: u32 = 0b1111_1111_1111_1111_1011_1111_1111_1111;
    pub const u32_15: u32 = 0b1111_1111_1111_1111_0111_1111_1111_1111;
    pub const u32_16: u32 = 0b1111_1111_1111_1110_1111_1111_1111_1111;
    pub const u32_17: u32 = 0b1111_1111_1111_1101_1111_1111_1111_1111;
    pub const u32_18: u32 = 0b1111_1111_1111_1011_1111_1111_1111_1111;
    pub const u32_19: u32 = 0b1111_1111_1111_0111_1111_1111_1111_1111;
    pub const u32_20: u32 = 0b1111_1111_1110_1111_1111_1111_1111_1111;
    pub const u32_21: u32 = 0b1111_1111_1101_1111_1111_1111_1111_1111;
    pub const u32_22: u32 = 0b1111_1111_1011_1111_1111_1111_1111_1111;
    pub const u32_23: u32 = 0b1111_1111_0111_1111_1111_1111_1111_1111;
    pub const u32_24: u32 = 0b1111_1110_1111_1111_1111_1111_1111_1111;
    pub const u32_25: u32 = 0b1111_1101_1111_1111_1111_1111_1111_1111;
    pub const u32_26: u32 = 0b1111_1011_1111_1111_1111_1111_1111_1111;
    pub const u32_27: u32 = 0b1111_0111_1111_1111_1111_1111_1111_1111;
    pub const u32_28: u32 = 0b1110_1111_1111_1111_1111_1111_1111_1111;
    pub const u32_29: u32 = 0b1101_1111_1111_1111_1111_1111_1111_1111;
    pub const u32_30: u32 = 0b1011_1111_1111_1111_1111_1111_1111_1111;
    pub const u32_31: u32 = 0b0111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_0: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110;
    pub const u64_1: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101;
    pub const u64_2: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011;
    pub const u64_3: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111;
    pub const u64_4: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111;
    pub const u64_5: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111;
    pub const u64_6: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111;
    pub const u64_7: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111;
    pub const u64_8: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111;
    pub const u64_9: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111;
    pub const u64_10: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111;
    pub const u64_11: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111;
    pub const u64_12: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111;
    pub const u64_13: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111;
    pub const u64_14: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111;
    pub const u64_15: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111;
    pub const u64_16: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111;
    pub const u64_17: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111;
    pub const u64_18: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111;
    pub const u64_19: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111;
    pub const u64_20: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111;
    pub const u64_21: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111;
    pub const u64_22: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111;
    pub const u64_23: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111;
    pub const u64_24: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111;
    pub const u64_25: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111;
    pub const u64_26: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111;
    pub const u64_27: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111;
    pub const u64_28: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_29: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_30: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_31: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_32: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_33: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_34: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_35: u64 =
        0b1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_36: u64 =
        0b1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_37: u64 =
        0b1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_38: u64 =
        0b1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_39: u64 =
        0b1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_40: u64 =
        0b1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_41: u64 =
        0b1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_42: u64 =
        0b1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_43: u64 =
        0b1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_44: u64 =
        0b1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_45: u64 =
        0b1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_46: u64 =
        0b1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_47: u64 =
        0b1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_48: u64 =
        0b1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_49: u64 =
        0b1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_50: u64 =
        0b1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_51: u64 =
        0b1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_52: u64 =
        0b1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_53: u64 =
        0b1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_54: u64 =
        0b1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_55: u64 =
        0b1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_56: u64 =
        0b1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_57: u64 =
        0b1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_58: u64 =
        0b1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_59: u64 =
        0b1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_60: u64 =
        0b1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_61: u64 =
        0b1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_62: u64 =
        0b1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u64_63: u64 =
        0b0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_0: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110;
    pub const u128_1: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101;
    pub const u128_2: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011;
    pub const u128_3: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111;
    pub const u128_4: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111;
    pub const u128_5: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111;
    pub const u128_6: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111;
    pub const u128_7: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111;
    pub const u128_8: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111;
    pub const u128_9: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111;
    pub const u128_10: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111;
    pub const u128_11: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111;
    pub const u128_12: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111;
    pub const u128_13: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111;
    pub const u128_14: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111;
    pub const u128_15: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111;
    pub const u128_16: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111;
    pub const u128_17: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111;
    pub const u128_18: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111;
    pub const u128_19: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111;
    pub const u128_20: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111;
    pub const u128_21: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111;
    pub const u128_22: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111;
    pub const u128_23: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111;
    pub const u128_24: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111;
    pub const u128_25: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111;
    pub const u128_26: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111;
    pub const u128_27: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111;
    pub const u128_28: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_29: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_30: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_31: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_32: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_33: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_34: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_35: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_36: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_37: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_38: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_39: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_40: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_41: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_42: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_43: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_44: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_45: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_46: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_47: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_48: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_49: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_50: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_51: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_52: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_53: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_54: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_55: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_56: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_57: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_58: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_59: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_60: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_61: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_62: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_63: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_64: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_65: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_66: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_67: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_68: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_69: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_70: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_71: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_72: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_73: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_74: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_75: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_76: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_77: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_78: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_79: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_80: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_81: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_82: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_83: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_84: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_85: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_86: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_87: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_88: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_89: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_90: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_91: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_92: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_93: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_94: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_95: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_96: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_97: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_98: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_99: u128 =
        0b1111_1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_100: u128 =
        0b1111_1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_101: u128 =
        0b1111_1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_102: u128 =
        0b1111_1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_103: u128 =
        0b1111_1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_104: u128 =
        0b1111_1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_105: u128 =
        0b1111_1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_106: u128 =
        0b1111_1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_107: u128 =
        0b1111_1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_108: u128 =
        0b1111_1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_109: u128 =
        0b1111_1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_110: u128 =
        0b1111_1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_111: u128 =
        0b1111_1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_112: u128 =
        0b1111_1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_113: u128 =
        0b1111_1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_114: u128 =
        0b1111_1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_115: u128 =
        0b1111_1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_116: u128 =
        0b1111_1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_117: u128 =
        0b1111_1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_118: u128 =
        0b1111_1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_119: u128 =
        0b1111_1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_120: u128 =
        0b1111_1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_121: u128 =
        0b1111_1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_122: u128 =
        0b1111_1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_123: u128 =
        0b1111_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_124: u128 =
        0b1110_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_125: u128 =
        0b1101_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_126: u128 =
        0b1011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
    pub const u128_127: u128 =
        0b0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111;
}

#[cfg(test)]
mod tests {
    use core::num::traits::{BitSize, Bounded};
    use super::{BitMask, PowOfTwo};

    #[test]
    fn test_u8_two_to_the() {
        let mut power: usize = 0;
        let mut expected: u8 = 1;
        while power < BitSize::<u8>::bits() {
            assert_eq!(PowOfTwo::two_to_the(power).unwrap(), expected);
            power += 1;
            if power < BitSize::<u8>::bits() {
                expected *= 2;
            }
        };
        assert_eq!(PowOfTwo::<u8>::two_to_the(power), Result::Err('Invalid power'));
    }

    #[test]
    fn test_u16_two_to_the() {
        let mut power: usize = 0;
        let mut expected: u16 = 1;
        while power < BitSize::<u16>::bits() {
            assert_eq!(PowOfTwo::two_to_the(power).unwrap(), expected);
            power += 1;
            if power < BitSize::<u16>::bits() {
                expected *= 2;
            }
        };
        assert_eq!(PowOfTwo::<u16>::two_to_the(power), Result::Err('Invalid power'));
    }

    #[test]
    fn test_u32_two_to_the() {
        let mut power: usize = 0;
        let mut expected: u32 = 1;
        while power < BitSize::<u32>::bits() {
            assert_eq!(PowOfTwo::two_to_the(power).unwrap(), expected);
            power += 1;
            if power < BitSize::<u32>::bits() {
                expected *= 2;
            }
        };
        assert_eq!(PowOfTwo::<u32>::two_to_the(power), Result::Err('Invalid power'));
    }

    #[test]
    fn test_u64_two_to_the() {
        let mut power: usize = 0;
        let mut expected: u64 = 1;
        while power < BitSize::<u64>::bits() {
            assert_eq!(PowOfTwo::two_to_the(power).unwrap(), expected);
            power += 1;
            if power < BitSize::<u64>::bits() {
                expected *= 2;
            }
        };
        assert_eq!(PowOfTwo::<u64>::two_to_the(power), Result::Err('Invalid power'));
    }

    #[test]
    fn test_u128_two_to_the() {
        let mut power: usize = 0;
        let mut expected: u128 = 1;
        while power < BitSize::<u128>::bits() {
            assert_eq!(PowOfTwo::two_to_the(power).unwrap(), expected);
            power += 1;
            if power < BitSize::<u128>::bits() {
                expected *= 2;
            }
        };
        assert_eq!(PowOfTwo::<u128>::two_to_the(power), Result::Err('Invalid power'));
    }

    #[test]
    fn test_u8_inverse_bit_mask() {
        let mut index: usize = 0;
        while index < BitSize::<u8>::bits() {
            let mut expected: u8 = Bounded::MAX - PowOfTwo::two_to_the(index).unwrap();
            assert_eq!(BitMask::inverse_bit_mask(index).unwrap(), expected);
            index += 1;
        };
        assert_eq!(BitMask::<u8>::inverse_bit_mask(index), Result::Err('Invalid index'));
    }

    #[test]
    fn test_u16_inverse_bit_mask() {
        let mut index: usize = 0;
        while index < BitSize::<u16>::bits() {
            let mut expected: u16 = Bounded::MAX - PowOfTwo::two_to_the(index).unwrap();
            assert_eq!(BitMask::inverse_bit_mask(index).unwrap(), expected);
            index += 1;
        };
        assert_eq!(BitMask::<u16>::inverse_bit_mask(index), Result::Err('Invalid index'));
    }

    #[test]
    fn test_u32_inverse_bit_mask() {
        let mut index: usize = 0;
        while index < BitSize::<u32>::bits() {
            let mut expected: u32 = Bounded::MAX - PowOfTwo::two_to_the(index).unwrap();
            assert_eq!(BitMask::inverse_bit_mask(index).unwrap(), expected);
            index += 1;
        };
        assert_eq!(BitMask::<u32>::inverse_bit_mask(index), Result::Err('Invalid index'));
    }

    #[test]
    fn test_u64_inverse_bit_mask() {
        let mut index: usize = 0;
        while index < BitSize::<u64>::bits() {
            let mut expected: u64 = Bounded::MAX - PowOfTwo::two_to_the(index).unwrap();
            assert_eq!(BitMask::inverse_bit_mask(index).unwrap(), expected);
            index += 1;
        };
        assert_eq!(BitMask::<u64>::inverse_bit_mask(index), Result::Err('Invalid index'));
    }

    #[test]
    fn test_u128_inverse_bit_mask() {
        let mut index: usize = 0;
        while index < BitSize::<u128>::bits() {
            let mut expected: u128 = Bounded::MAX - PowOfTwo::two_to_the(index).unwrap();
            assert_eq!(BitMask::inverse_bit_mask(index).unwrap(), expected);
            index += 1;
        };
        assert_eq!(BitMask::<u128>::inverse_bit_mask(index), Result::Err('Invalid index'));
    }
}
