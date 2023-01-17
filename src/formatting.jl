# A few helper methods to help formatting string output.

"""
Pad text to the center of output.
This one seems missing from Julia now :(
https://github.com/JuliaLang/julia/pull/23187

```jldoctest
julia> cpad(9, 3)
" 9 "

julia> cpad("test", 1)
"test"

julia> cpad("test", 6, '-'; left = false)
"-test-"

julia> cpad("test", 6, '-'; left = true)
"-test-"

julia> cpad("test", 7, '-'; left = false)
"-test--"

julia> cpad("test", 7, '-'; left = true)
"--test-"
```
"""
function cpad(s, n, p = ' '; left = false)
    s = string(s)
    (l = length(s)) >= n && return s
    h = (n - l) ÷ 2
    fl, fr = Bool((n - l) % 2) .&& (left, !left)
    repeat(p, h + fl) * s * repeat(p, h + fr)
end

r"""

    fitin(floating_number, n_chars)

Attempt to format number to a string so it fits within the desired number of characters.
Here is the priority list regarding the underlying decision process:
1. (absolute) The most significant digit and order of magnitude must not be dropped.
2. Result should fit within n_chars (unless this would break 1.).
3. Result should be as precise as possible (unless this would break 2.).
4. Prefer classical notation to scientific notation (unless this would break 3.).
5. Use as few characters as possible.

```jldoctest
julia> for i in reverse(1:9) println("$i: $(fitin(12.3456, i))") end
9: 12.3456
8: 12.3456
7: 12.3456
6: 12.346
5: 12.35
4: 12.3
3: 12
2: 12
1: 12

julia> for i in reverse(1:9) println("$i: $(fitin(0.123456, i))") end
9: .123456
8: .123456
7: .123456
6: .12346
5: .1235
4: .123
3: .12
2: .1
1: .1

julia> for i in reverse(1:9) println("$i: $(fitin(0.0123456, i))") end
9: .0123456
8: .0123456
7: .012346
6: .01235
5: .0123
4: .012
3: .01
2: .01
1: .01

julia> for i in reverse(1:9) println("$i: $(fitin(12345678, i))") end
9: 12345678
8: 12345678
7: 1.235e7
6: 1.23e7
5: 1.2e7
4: 1e7
3: 1e7
2: 1e7
1: 1e7

julia> for i in reverse(1:10) println("$(rpad(i, 2)): $(fitin(0.000123456, i))") end
10: .00012346
9 : .00012346
8 : .0001235
7 : .000123
6 : .00012
5 : 1e-4
4 : 1e-4
3 : 1e-4
2 : 1e-4
1 : 1e-4

julia> for i in reverse(1:4) println("$i: $(fitin(1, i))") end
4: 1
3: 1
2: 1
1: 1

julia> for i in reverse(1:4) println("$i: $(fitin(0, i))") end
4: 0
3: 0
2: 0
1: 0

julia> for i in reverse(1:9) println("$i: $(fitin(-12.3456, i))") end
9: -12.3456
8: -12.3456
7: -12.346
6: -12.35
5: -12.3
4: -12
3: -12
2: -12
1: -12

julia> fitin(Inf, 5), fitin(-Inf, 5)
("∞", "-∞")

julia> for i in reverse(1:4) println("$i: $(fitin(NaN, i))") end
4: NaN
3: NaN
2: NA
1: N

julia> for i in reverse(1:6) println("$i: $(fitin(1.999, i))") end
6: 1.999
5: 1.999
4: 2
3: 2
2: 2
1: 2

julia> for i in reverse(1:6) println("$i: $(fitin(0.999, i))") end
6: .999
5: .999
4: .999
3: 1
2: 1
1: 1
```
"""
function fitin(f, n)
    f == 0 && return "0"
    isinf(f) && return repeat('-', f < 0) * "∞"
    isnan(f) && return (n == 1) ? "N" : (n == 2) ? "NA" : "NaN"
    ndigits(x) = ceil(Int64, log(10, x + 1))
    # Convert number to decimal representation: sign, mantissa, exponent in base 10.
    d = Decimal(f)
    # Number of digits in the original mantissa.
    onm = ndigits(d.c)
    # Trial and error: pick the highest precision we can have within the constraint n,
    # even if this means not filling exactly n characters.
    # In case of ex-aequo, pick the match with smallest number of characters.
    # TODO: restrict search range or even directly calculate the best rounding?
    for r in reverse(1:onm)
        for i in 1:n
            res = fitin(d, onm, i, r)
            isnothing(res) || return res
        end
    end
    # If nothing matched, within this range, loosen the constraint until the first match.
    while true
        n += 1
        for r in reverse(1:onm)
            res = fitin(d, onm, n, r)
            isnothing(res) || return res
        end
    end
end
function fitin(d, onm, n, r)
    rd = round(Decimal(d.s, d.c, -onm); digits = r) #  convert to 0.<mantissa> form
    rd = Decimal(rd.s, rd.c, rd.q + onm + d.q)  #  shift exponent up again
    s, m, e = rd.s, rd.c, rd.q
    # Number of digits in the mantissa.
    nm = ndigits(m)
    # For each experimented rounding, check various possible output format in turn,
    # from the most to the least human-friendly. The first match is the result.
    sign() = repeat('-', s)
    if e > 0
        # Trailing zeroes notations? 123456000
        if n == s + nm + e
            return sign() * string(m) * repeat('0', e)
        end
        # Scientific notation? 1.23456e78
        e1 = nm + e - 1 # Actual exponent with comma after first position.
        comma = nm > 1
        if n == s + nm + comma + 1 + ndigits(e1)
            mant = string(m)
            return sign() * mant[1] * repeat('.', comma) * mant[2:end] * 'e' * string(e1)
        end
    end
    if e == 0
        # Plain notation? 123456
        if n == s + nm
            return sign() * string(m)
        end
    end
    if -nm <= e <= 0
        # Comma notation? 12.3456
        if n == s + 1 + nm
            mant = string(m)
            return sign() * mant[1:nm+e] * '.' * mant[nm+e+1:end]
        end
    end
    if e < -nm
        # Leading zeroes notation? .000123456
        if n == s + 1 - e
            return sign() * '.' * repeat('0', -(nm + e)) * string(m)
        end
        # Scientific notation? 1.23456e-78
        e1 = nm + e - 1 # Actual exponent with comma after first position.
        comma = nm > 1
        if n == s + nm + comma + 2 + ndigits(-e1)
            mant = string(m)
            return sign() * mant[1] * repeat('.', comma) * mant[2:end] * "e" * string(e1)
        end
    end
    # Give up if none matched.
    nothing
end
