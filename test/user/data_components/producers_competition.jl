FR = EN.ProducersCompetitionFromRawValues
FD = EN.ProducersCompetitionFromDiagonal

@testset "ProducersCompetition component." begin

    base = Model(Foodweb([:a => [:b, :c]]))

    #---------------------------------------------------------------------------------------
    # Construct from raw values.

    pc = ProducersCompetition([
        0 0 0
        0 1 2
        0 3 4
    ])
    m = base + pc
    @test m.producers_competition == [
        0 0 0
        0 1 2
        0 3 4
    ]
    @test typeof(pc) === FR

    # Adjacency list input.
    m = base + ProducersCompetition([:b => [:b => 5, :c => 6], :c => [:b => 7]])
    @test m.producers_competition == [
        0 0 0
        0 5 6
        0 7 0
    ]

    # Only producers links indices allowed.
    @sysfails(
        base + ProducersCompetition([
            0 1 0
            2 0 3
            0 0 0
        ]),
        Check(FR),
        "Non-missing value found for 'alpha' at edge index [2, 1] (2.0), \
         but the template for 'producers link' only allows values \
         at the following indices:\n  [(2, 2), (3, 2), (2, 3), (3, 3)]",
    )
    @sysfails(
        base + ProducersCompetition([:a => [:b => 4]]),
        Check(FR),
        "Invalid 'producers link' edge label in 'alpha': (:a, :b). \
         This template allows no valid edge targets labels for source :a.",
    )

    #---------------------------------------------------------------------------------------
    # Construct as a diagonal matrix.

    pc = ProducersCompetition(; diag = 1, off = 2)
    @test typeof(pc) == FD
    m = base + pc
    @test m.producers_competition == [
        0 0 0
        0 1 2
        0 2 1
    ]
    # Fancy input aliases.
    @test pc == ProducersCompetition(; diagonal = 1, nondiagonal = 2)
    @test pc == ProducersCompetition(; diagonal = 1, offdiagonal = 2)
    @test pc == ProducersCompetition(; diag = 1, offdiag = 2)
    @test pc == ProducersCompetition(; diag = 1, rest = 2)
    @test pc == ProducersCompetition(; d = 1, o = 2)
    @test pc == ProducersCompetition(; d = 1, nd = 2)

    # Guard against inconsistent input.
    @argfails(ProducersCompetition(), "No input provided to specify producers competition.")
    @argfails(
        ProducersCompetition(nothing),
        "No input provided to specify producers competition."
    )
    @argfails(
        ProducersCompetition(; diag = 1, off = 2, d = 3),
        "Cannot specify both aliases :d and :diag arguments."
    )

end
