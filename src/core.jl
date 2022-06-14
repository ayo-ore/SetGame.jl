using Combinatorics
using Dates
using StatsBase: sample
using REPL

# features enumeration
@enum Color Red Green Blue
@enum Count One Two Three
@enum Shade Solid Dashed Empty
@enum Shape Diamond Squiggle Blob

struct Card

    # fields
    color::Color
    count::Count
    shape::Shape
    shade::Shade

    # constructor
    function Card(features::Vararg{Int,4})
        new(
            Color(features[1]), Count(features[2]),
            Shape(features[3]), Shade(features[4])
        )
    end
end

Base.@kwdef struct GameContext
    deck::Vector{Card} = make_full_deck()
    board::Vector{Card} = []
    selected::BitVector = falses(15)
    found::Vector{NTuple{3,Card}} = []
    start_time::DateTime = now()
end

# deck generator
"""
`generate_deck()`

Generates a full deck Set deck as a `Vector{Card}`.
"""
function make_full_deck()::Vector{Card}
    collect(map(
        features -> Card(features...),
        multiset_permutations(repeat(0:2, 4), 4)
    ))
end


# set validator
"""
`isset(a, b, c)`

Evaluates whether or not `Card`s `a`, `b` and `c` form a set.
"""
function isset(trio::Vararg{Card,3})::Bool
    return all(f -> sum(Int.(getfield.(trio, f))) % 3 == 0, fieldnames(Card))
end

# set validator
"""
`hasset(board)`

Evaluates whether or not `board` contains at least one set.
"""
function hasset(board::Vector{Card})::Bool
    if length(board) >= 18
        return true
    else
        return any(cards -> isset(cards...), combinations(board, 3))
    end
end

# Card drawing
"""
`draw_cards(board, deck, num)`

Removes `num` cards at random from `deck` and appends them to `board`.
"""
function draw_cards!(board::Vector{Card}, deck::Vector{Card}, num::Int)::Vector{Card}
    draws = sample(axes(deck, 1), num, replace=false)
    sort!(draws)
    append!(board, splice!(deck, draws))
end
draw_cards!(ctx::GameContext, num::Int) = draw_cards!(ctx.board, ctx.deck, num)

# Set replacement
function replace_cards!(board::Vector{Card}, deck::Vector{Card}, mask::A)::Vector{Card} where A <: AbstractArray
    draws = sample(axes(deck, 1), sum(mask), replace=false)
    sort!(draws)
    board[mask] .= splice!(deck, draws)
end
replace_cards!(ctx::GameContext) = replace_cards!(ctx.board, ctx.deck, view(ctx.selected, 1:length(ctx.board)))

const KEYMAP = [
    'q', 'a', 'z', 'w', 's', 'x', 'e', 'd', 'c', 'r', 'f', 'v', 't', 'g', 'b'
]

function timer(start::DateTime)::Nothing
    @async begin
        while true
            println(Dates.format(
                Time(Nanosecond(now() - start)),
                "MM:SS"
            ))
            sleep(1)
        end
    end
end

function playset!()

    terminal = REPL.Terminals.TTYTerminal(get(ENV, "TERM", Sys.iswindows() ? "" : "dumb"), Base.stdin, Base.stdout, Base.stderr)

    ctx = GameContext()
    check_for_set::Bool = false

    draw_cards!(ctx, 12)

    enableRawMode(terminal)
    while true

        # check if the board contains no sets
        # TODO: maybe only do this if a set was just found
        if check_for_set
            if !hasset(ctx.board)
                # end game if the deck is empty or draw 3 more cards
                if isempty(ctx.deck)
                    print("Game over")
                    break
                    # TODO: Add game timing
                else
                    draw_cards!(ctx, 3)
                end
                check_for_set = false
            end
        end

        render_screen(ctx)
        
        # handle key input
        key = readKey(terminal.in_stream)
        chr = Char(key)
        if key ∈ UInt8.([3, 27]) # Ctrl-C, ESC
            break
        elseif chr ∈ view(KEYMAP, 1:length(ctx.board))
            @. ctx.selected = (KEYMAP == chr) ⊻ ctx.selected
        end

        # when three cards are selected, check if they are a set
        if sum(ctx.selected) == 3
            # selected_trio = ctx.board[ctx.selected[1:length(ctx.board)]]
            selected_trio = view(ctx.board, view(ctx.selected, 1:length(ctx.board)))
        
            if isset(selected_trio...)
                push!(ctx.found, Tuple(selected_trio))
                if length(ctx.board) == 12 && !isempty(ctx.deck)
                    replace_cards!(ctx)
                else
                    deleteat!(ctx.board, view(ctx.selected, 1:length(ctx.board)))
                end
                check_for_set = true
            else
                render_screen(ctx)
                sleep(0.1)
            end
            ctx.selected .= false # clear selections
        end

        # println("CARDS LEFT: $(length(board))")
        # println("SETS FOUND: $(length(found))")
    end
    disableRawMode(terminal)

    return nothing
end