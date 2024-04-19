# DataFrameMacros.jl

DataFrameMacros.jl offers macros for manipulating DataFrames with a syntax geared towards clarity, brevity and convenience.
Each macro translates expressions into the `source .=> function .=> sink` mini-language from [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl).

The following macros are currently available:
- `@transform` / `@transform!`
- `@select` / `@select!`
- `@groupby`
- `@combine`
- `@subset` / `@subset!`
- `@sort` / `@sort!`
- `@unique`

## Differences to [DataFramesMeta.jl](https://github.com/JuliaData/DataFramesMeta.jl)

- Except `@combine`, all macros work row-wise by default in DataFrameMacros.jl
- DataFrameMacros.jl uses `{}` to signal column expressions instead of `$()`.
- In DataFrameMacros.jl, you can apply the same expression to several columns in `{}` braces at once and even broadcast across multiple sets of columns.
- In DataFrameMacros.jl, you can use special `{{ }}` multi-column expressions where you can operate on a tuple of all values at once which makes it easier to do aggregates across columns.
- DataFrameMacros.jl has a special syntax to make use of `transform!` on a view returned from `subset`, so you can easily transform only some rows of your dataset with `@transform!(df, @subset(...), ...)`.

If any of these points have changed, please open an issue.

# Examples

## `@select`

```@repl
using DataFrameMacros
using Statistics

df = DataFrame(a = 1:5, b = 6:10, c = 11:15)

@select(df, :a)
@select(df, :a, :b)
@select(df, :A = :a, :B = :b)
@select(df, :a + 1)
@select(df, :a_plus_one = :a + 1)
@select(df, {[:a, :b]} / 2)
@select(df, sqrt({Not(:b)}))
@select(df, 5 * {All()})
@select(df, {Between(1, 2)} - {Between(2, 3)})
@select(df, "{1}_plus_{2}" = {Between(1, 2)} + {Between(2, 3)})
@select(df, @bycol :a .- :b)
@select(df, :d = @bycol :a .+ 1)
@select(df, "a_minus_{2}" = :a - {[:b, :c]})
@select(df, "{1}_minus_{2}" = {[:a, :b, :c]} - {[:a, :b, :c]'})
@select(df, :a + mean({{[:b, :c]}}))
```

## `@transform`

```@repl
using DataFrameMacros
using Statistics

df = DataFrame(a = 1:5, b = 6:10, c = 11:15)

@transform(df, :a + 1)
@transform(df, :a_plus_one = :a + 1)
@transform(df, @bycol :a .- mean(:b))
@transform(df, :d = @bycol :a .+ 1)
@transform(df, "a_minus_{2}" = :a - {[:b, :c]})
@transform(df, "{1}_minus_{2}" = {[:a, :b, :c]} - {[:a, :b, :c]'})
```

## `@combine`

```@repl
using DataFrameMacros
using Statistics

df = DataFrame(a = 1:5, b = 6:10, c = 11:15)

@combine(df, :mean_a = mean(:a))
@combine(df, "mean_{}" = mean({All()}))
@combine(df, "first_3_{}" = first({Not(:b)}, 3))
@combine(df, begin
    :mean_a = mean(:a)
    :median_b = median(:b)
    :sum_c = sum(:c)
end)
```

## `@sort`

```@repl
using DataFrameMacros
using Random

Random.seed!(123)

df = DataFrame(randn(5, 5), :auto)

@sort(df, :x1)
@sort(df, -:x1)
@sort(df, :x2 * :x3)

df2 = DataFrame(a = [1, 2, 2, 1, 2], b = [4, 4, 4, 3, 3], c = [5, 7, 5, 7, 5])

@sort(df2, :a, :b)
@sort(df2, :c - :a - :b)
```

## `@groupby`

```@repl
using DataFrameMacros
using Random

Random.seed!(123)

df = DataFrame(
    color = ["red", "red", "red", "blue", "blue"],
    size = ["big", "small", "big", "small", "big"],
    height = [1, 2, 3, 4, 5],
)

@groupby(df, :color)
@groupby(df, :color, :size)
@groupby(df, :evenheight = iseven(:height))
```

## `@astable`

```@repl
using DataFrameMacros

df = DataFrame(name = ["Jeff Bezanson", "Stefan Karpinski", "Alan Edelman", "Viral Shah"])
@select(df, @astable :first, :last = split(:name))
@select(df, @astable begin
    f, l = split(:name)
    :first, :last = f, l
    :initials = first(f) * "." * first(l) * "."
end)
```

## `@passmissing`

```@repl
using DataFrameMacros

df = DataFrame(short = ["cat", "dog", "mouse", "duck"], long = ["catch", "dogged", missing, "docks"])
@transform(df, :startswith = @passmissing startswith(:long, :short))
```

## Multiple columns in `{}`

If `{}` contains a multi-column expression, then the function is run for each combination of arguments determined by broadcasting all sets together.

```@repl
using DataFrameMacros
using Statistics

df = DataFrame(a = 1:5, b = 6:10, c = 11:15)

@select(df, :a + {[:b, :c]})
@select(df, :a + {Not(:a)})
@select(df, {[:a, :b]} + {[:b, :c]})
@select(df, {[:a, :b]} + {[:b, :c]'})
```

## `{{}}` syntax

The double brace syntax refers to multiple columns as a tuple, which means that you can aggregate over a larger number of columns than it would be practical to write out explicitly.

```@repl
using DataFrameMacros
using Random
using Statistics

Random.seed!(123)

df = DataFrame(
    jan = randn(5),
    feb = randn(5),
    mar = randn(5),
    apr = randn(5),
    may = randn(5),
    jun = randn(5),
    jul = randn(5),
)

@select(df, :july_larger = :jul > median({{Between(:jan, :jun)}}))
@select(df, :mean_smaller = mean({{All()}}) < median({{All()}}))
```

## `@transform!` on `@subset`

DataFrames.jl allows `transform!`ing a view returned by `subset(df, ..., view = true)`.
If you pass a `@subset` macro call without a dataframe argument to `@transform!`, a view is created automatically, then the transform is executed and the original argument returned.

```@repl
using DataFrameMacros
using Statistics

df = DataFrame(
    name = ["Chicken", "Pork", "Apple", "Pear", "Beef"],
    type = ["Meat", "Meat", "Fruit", "Fruit", "Meat"],
    price = [4.99, 5.99, 0.99, 1.29, 6.99],
)

@transform!(df, @subset(:type == "Meat"), :price = :price + 2)
@transform!(df, @subset(:price < 7, :name != "Pear"), :n_sold = round(Int, :price * 5))
@transform!(
    @groupby(df, :type),
    @subset(@bycol :price .< mean(:price)),
    :price = 100 * :price)
```

## Special case `@nrow`

```@repl
using DataFrameMacros
using Statistics

df = DataFrame(x = [1, 1, 1, 2, 2])

@transform(df, @nrow)
@combine(groupby(df, :x), :count = @nrow)
```

## Special case `@eachindex`

```@repl
using DataFrameMacros
using Statistics

df = DataFrame(x = [1, 1, 1, 2, 2])

@transform(df, @eachindex)
@combine(groupby(df, :x), :i = @eachindex)
```

## Special case `@proprow`

```@repl
using DataFrameMacros
using Statistics

df = DataFrame(x = [1, 1, 1, 2, 2])

@combine(groupby(df, :x), :p = @proprow)
```

## Special case `@groupindices`

```@repl
using DataFrameMacros
using Statistics

df = DataFrame(x = [1, 1, 1, 2, 2])

@combine(groupby(df, :x), :gi = @groupindices)
```
