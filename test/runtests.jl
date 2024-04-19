using DataFrameMacros
using Test

@testset "transform & select" begin
    df = DataFrame(a = 1:100, b = rand('a':'e', 100), c = randn(100))

    df2 = @transform(df, :a + 1)
    @test df2 == transform(df, :a => ByRow(x -> x + 1))
    df3 = @transform(df, :d = :a + 1)
    @test df3 == transform(df, :a => ByRow(x -> x + 1) => :d)
    df4 = @transform(df, :d = :a + 1, :e = :c * 2)
    @test df4 == transform(df,
        :a => ByRow(x -> x + 1) => :d,
        :c => ByRow(x -> x * 2) => :e
    )
    df5 = @transform(df, :d = :a + 1, :e = :c * 2, :f = :a * :c - (:c / :a))
    @test df5 == transform(df,
        :a => ByRow(x -> x + 1) => :d,
        :c => ByRow(x -> x * 2) => :e,
        [:a, :c] => ByRow((x, y) -> x * y - (y / x)) => :f
    )

    col1 = :a
    col2 = :c
    df6 = @transform(df, :d = {col1} + {col2} * :a)
    @test df6 == transform(df, [col1, col2, :a] => ByRow((x, y, z) -> x + y * z) => :d)

    s = "d"
    df7 = @transform(df, Symbol(s) = :a + 1)
    @test df7 == transform(df, :a => ByRow(x -> x + 1) => :d)

    df8 = @transform(df, AsTable = (x = "$(:a) $(:b)", y = :c * 2))

    @test df8 == transform(df,
        [:a, :b, :c] =>
            ByRow((a, b, c) -> (x = "$a $b", y = c * 2)) => AsTable
    )

    df9 = @transform(df, :a)
    @test df9 == transform(df, :a)

    df10 = @select(df, :a * 2)
    @test df10 == select(df, :a => ByRow(x -> x * 2))

    df11 = @select(df, :x = :a * 2)
    @test df11 == select(df, :a => ByRow(x -> x * 2) => :x)

    myfunc(x) = x + 2
    df12 = @transform(df, myfunc(:a))
    @test "a_myfunc" in names(df12)
    @test df12 == transform(df, :a => ByRow(myfunc))

    df13 = @transform(df, :x = @bycol sum(:a) .+ :c)
    @test df13 == transform(df, [:a, :c] => ((x, y) -> sum(x) .+ y) => :x)

    df14 = DataFrame(a = ['a', 'b', missing])
    df15 = @transform(df14, @passmissing uppercase(:a))
    # @test df15 == transform(df14, :a => ByRow(passmissing(uppercase)))
end

@testset "combine" begin
    df = DataFrame(a = 1:100, b = rand('a':'e', 100), c = randn(100))

    df1 = @combine(df, sum(:a))
    @test df1 == combine(df, :a => sum)

    df2 = @combine(df, sum(:a) + 3)
    @test df2 == combine(df, :a => (x -> sum(x) + 3))

    df3 = @combine(df, :x = sum(:a) + 3)
    @test df3 == combine(df, :a => (x -> sum(x) + 3) => :x)

    df4 = @combine(df, :y = @byrow 3 * :a)
    @test df4 == combine(df, :a => ByRow(x -> 3 * x) => :y)
end

@testset "subset" begin
    df = DataFrame(a = [-1, 1, -2, 2, -3, 3], b = randn(6))
    df2 = @subset(df, abs(:a) < 2)
    @test df2 == subset(df, :a => ByRow(x -> abs(x) < 2))
end

@testset "groupby" begin
    df = DataFrame(a = [-1, 1, -2, 2, -3, 3], b = randn(6))
    gdf = @groupby(df, abs(:a))

    gdf2 = @groupby(df, :a = abs(:a))

    gdf3 = @groupby(df, :x = abs(:a))
end

@testset "sort" begin
    df = DataFrame(a = rand(1:10, 100), b = rand('a':'z', 100))
    df2 = @sort(df, :a)
    @test df2 == sort(df, :a)

    df3 = @sort(df, -:a)
    @test df3 == sort(df, :a, rev = true)

    df4 = @sort(df, -:a, :b)
    @test df4 == sort(df, [order(:a, rev = true), :b])

    df5 = @sort(df, :a; rev = true)
    @test df5 == sort(df, :a, rev = true)
end

@testset "escaping symbols" begin
    df = DataFrame(color = [:red, :green, :blue])
    df2 = @transform(df, :color == $:red)
    @test df2[:, 2] == transform(df, :color => ByRow(==(:red)))[:, 2]
end

@testset "mutating" begin
    df = DataFrame(a = 1:100, b = rand('a':'e', 100), c = randn(100))
    @transform!(df, :a = :a * 2)
    @sort!(df, :b)
    @subset!(df, :a > 20)
    @select!(df, :a, :c)
end

@testset "string and int column specification" begin
    df = DataFrame([Symbol("a column") => [1, 2, 3], :b => [4, 5, 6]])
    df2 = @transform(df, :c = {"a column"} * {2})
    #"
    @test df2 == transform(df, ["a column", names(df)[2]] => ByRow(*) => :c)
end

module Mod1
    module Mod2
        export func2
        func2(x) = 3x
    end
    using .Mod2
    export Mod2

    export func
    func(x) = 2x
end

@testset "modules" begin

    using .Mod1

    df = DataFrame(a = [1, 2, 3])
    df2 = @transform(df, :b = Mod1.func(:a), :c = Mod1.Mod2.func2(:a))
    @test df2 == transform(df,
        :a => ByRow(x -> Mod1.func(x)) => :b,
        :a => ByRow(x -> Mod1.Mod2.func2(x)) => :c,
    )
end


@testset "simple formula" begin
    df = DataFrame(a = 1:10)
    df2 = @transform(df, :b = :a + :a)
    @test df2 == transform(df, :a => ByRow(x -> x + x) => :b)

    using .Mod1

    # check that column names are correct for simple function calls
    df3 = @transform(df, Mod1.func(:a), Mod1.Mod2.func2(:a))
    @test df3 == transform(df,
        :a => ByRow(Mod1.func),
        :a => ByRow(Mod1.Mod2.func2),
    )
end

@testset "getproperty dot syntax" begin
    df = DataFrame(a = [(;b = 1), (;b = 3)])
    df2 = @transform(df, :c = :a.b)
    @test df2 == transform(df, :a => ByRow(x -> x.b) => :c)
end


@testset "block syntax" begin
    df = DataFrame(a = 1:3, b = 'a':'c')
    df2 = @transform df begin
        :c = :a + 1
        :d = string(:b) ^ 2
    end
    @test df2 == @transform(df, :c = :a + 1, :d = string(:b) ^ 2)
end

@testset "table shortcut @astable" begin
    df = DataFrame(a = 1:3, b = 4:6)
    df2 = @transform(df, @astable begin
        x = :a + :b
        :y = x * 2
        :z = x + 4
    end)
    @test df2 == transform(df, [:a, :b] => ByRow((a, b) -> begin
        x = a + b
        vary = x * 2
        varz = x + 4
        (y = vary, z = varz)
    end) => AsTable)

    df3 = @transform(df, @astable begin
        if iseven(:a)
            :z = :a
        else
            :z = :b
        end
    end)

    # tuple destructuring
    df4 = @transform(df, @astable begin
        x = :a + :b
        :y, :z = x * 2, x + 4
    end)
    @test df4 == df2

    # tuple destructuring with non symbols mixed in
    df5 = @transform(df, @astable begin
        x = :a + :b
        :y, qqq, :z = x * 2, "hello", x + 4
    end)
    @test df5 == df2 == df4
end

@testset "@subset arg for `transform`" begin
    df = DataFrame(x = 1:4, y = [1, 1, 2, 2])
    df2 = @transform!(df, @subset(:y == 2), :x = 5)
    @test df2.x == [1, 2, 5, 5]
    @test df2 === df

    df3 = @transform!(df, @subset(:y == 2), :x = 5, :y = 3)
    @test df3.x == [1, 2, 5, 5]
    @test df3.y == [1, 1, 3, 3]
    @test df3 === df

    df = DataFrame(x = 1:4, y = [1, 1, 2, 2])
    df4 = @transform! df @subset(:y == 2) begin
        :x = 5
        :y = 3
    end
    @test df4.x == [1, 2, 5, 5]
    @test df4.y == [1, 1, 3, 3]
    @test df4 === df

    df = DataFrame(x = 1:4, y = [1, 1, 2, 2])
    df5 = @transform! df @subset(begin
        :x > 1
        :x < 4
    end) begin
        :x = 5
        :y = 3
    end
    @test df5 === df
    @test df5.x == [1, 5, 5, 4]
    @test df5.y == [1, 3, 3, 2]

    df = DataFrame(x = 1:4, y = [1, 1, 2, 2])
    df6 = @transform! df @subset(:y == 2) @astable begin
        :x = 6
        :y = 7
        :z = 8
    end
    @test df6.x == [1, 2, 6, 6]
    @test df6.y == [1, 1, 7, 7]
    @test isequal(df6.z, [missing, missing, 8, 8])
end

@testset "@transform! with @subset with grouped dataframes" begin
    df = DataFrame(id = [1, 1, 1, 2, 2, 2], val = [0, 1, 3, 1, 2, 3])
    gdf = groupby(df, :id)
    df2 = @transform!(gdf, @subset(:val != 3), :newval = @bycol maximum(:val))

    @test isequal(
        df,
        DataFrame(
            id = [1, 1, 1, 2, 2, 2],
            val = [0, 1, 3, 1, 2, 3],
            newval = [1, 1, missing, 2, 2, missing],
        )
    )
    @test df2 === df
end

@testset "multiple columns" begin
    df = DataFrame(a = 1:3, aa = 4:6, b = 7:9)
    df2 = @select(df, {} = Float32({All()}))
    @test df2 == select(df, names(df, All()) .=> ByRow(Float32) .=> names(df, All()))

    @test @select(df, {Between(1, 3)} + 1) == select(df, Between(1, 3) .=> ByRow(x -> x + 1))
    @test @select(df, {Not(2)} + 1) == select(df, Not(2) .=> ByRow(x -> x + 1))

    @test @transform(df, ["c", "d"] = @bycol sum({Not(2)})) ==
        transform(df, Not(2) .=> sum .=> ["c", "d"])

    @test @select(df, {r"a"}) == select(df, names(df, r"a"))
    df3 = @transform(df, ["x", "y"] = {r"a"} + 1)
    @test df3 == transform(df, names(df, r"a") .=> ByRow(x -> x + 1) .=> ["x", "y"])

    df4 = @select(df, {1:3} + {(1:3)'})
    @test df4 == select(df, vcat.(1:3, (1:3)') .=> +)

    df5 = @select(df, :a + {1:3})
    @test df5 == select(df, vcat.("a", names(df, 1:3)) .=> +)
end

@testset "lefthand brackets" begin
    df = DataFrame(a = 1:3, b = 4:6, c = 7:9)
    @test @select(df, {} * "_plus_" * {2} = :a + {[:b, :c]}) ==
        select(df, vcat.(:a, [:b, :c]) .=> (+) .=> ["a_plus_b", "a_plus_c"])

    # test that {{ }} is not included for brackets on left side
    df2 = @select(df, {} * "_smaller" = maximum({{All()}}) < {[:a, :b, :c]})
    @test names(df2) == ["a_smaller", "b_smaller", "c_smaller"]

    # same test but with escaping check of a local variable
    snippet = "_smaller"
    df3 = @select(df, {} * snippet = maximum({{All()}}) < {[:a, :b, :c]})
    @test df2 == df3
end

@testset "target name shortcut string" begin
    df = DataFrame(a = 1:3, b = 4:6)

    df2 = @select(df, "{1}_plus_{2}" = :a + :b)
    @test df2 == DataFrame(a_plus_b = df.a .+ df.b)

    df3 = @select(df, "sqrt_of_{}" = sqrt({All()}))
    @test df3 == DataFrame(sqrt_of_a = sqrt.(df.a), sqrt_of_b = sqrt.(df.b))

    x = 5
    df4 = @select(df, "{}_plus_$x" = {All()} + x)
    @test df4 == DataFrame(a_plus_5 = df.a .+ 5, b_plus_5 = df.b .+ 5)
end

@testset "double brace syntax" begin
    df = DataFrame(a = 1:3, b = 4:6, c = 7:9)
    @test @select(df, :d = maximum({{All()}})) == @select(df, :d = maximum([:a, :b, :c]))
    @test @select(df, :d = maximum({{Not(:a)}})) == @select(df, :d = maximum([:b, :c]))
    @test @select(df, :d = @bycol sum({{r"[bc]"}})) == @select(df, :d = @bycol sum((:b, :c)))
    @test @select(df, :d = :a < maximum({{[:b, :c]}})) == @select(df, :d = :a < maximum((:b, :c)))
    @test @select(df, :d = :a < maximum({{Not(:a)}})) == @select(df, :d = :a < maximum((:b, :c)))
end

@testset "special cased functions" begin
    df = DataFrame(a = [1, 1, 2, 2, 2])
    result = @combine(@groupby(df, :a), :n = @nrow)
    @test result == combine(groupby(df, :a), nrow => :n)
    result = @combine(@groupby(df, :a), @nrow)
    @test result == combine(groupby(df, :a), nrow)

    result = @combine(@groupby(df, :a), :n = @proprow)
    @test result == combine(groupby(df, :a), proprow => :n)
    result = @combine(@groupby(df, :a), @proprow)
    @test result == combine(groupby(df, :a), proprow)

    result = @combine(@groupby(df, :a), :n = @eachindex)
    @test result == combine(groupby(df, :a), eachindex => :n)
    result = @combine(@groupby(df, :a), @eachindex)
    @test result == combine(groupby(df, :a), eachindex)

    result = @combine(@groupby(df, :a), :n = @groupindices)
    @test result == combine(groupby(df, :a), groupindices => :n)
    result = @combine(@groupby(df, :a), @groupindices)
    @test result == combine(groupby(df, :a), groupindices)

    @test_throws LoadError @eval @combine(@groupby(df, :a), :n = @nrow + 1)
    @test_throws LoadError @eval @combine(@groupby(df, :a), :n = @proprow + 1)
    @test_throws LoadError @eval @combine(@groupby(df, :a), :n = @eachindex + 1)
    @test_throws LoadError @eval @combine(@groupby(df, :a), :n = @groupindices + 1)
end
