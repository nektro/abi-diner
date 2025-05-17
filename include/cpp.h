#pragma once

typedef __int128 int128_t;
typedef unsigned __int128 uint128_t;

inline uint128_t operator""_u128(const char* digits) {
    uint128_t result{};
    while(*digits != 0) {
        result *= 10;
        result += *digits - '0';
        ++digits;
    }
    return result;
}
