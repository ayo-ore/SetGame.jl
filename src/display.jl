using Term

const COLOR_MAP = Dict{Color,String}(
    Red => "red3",
    Green => "green3",
    Blue => "dodger_blue2"
)
const PIXEL_MAP = Dict{Shape,BitMatrix}(
    Diamond => [
        0 0 1 0 0
        1 1 1 1 1
        0 0 1 0 0
        0 0 0 0 0
    ],
    Squiggle => [
        1 1 0 0 0
        1 1 1 1 1
        0 0 0 1 1
        0 0 0 0 0
    ],
    Blob => [
        0 1 1 1 0
        1 1 1 1 1
        0 1 1 1 0
        0 0 0 0 0
    ],
)

const PAD_MAP = Dict{Count,Int}(
    One => 4,
    Two => 2,
    Three => 0
)

const CHAR_MAP = Dict{Shade,Char}(
    Solid => '@', Dashed => 'o', Empty => '⋅'
)

function get_pixels(c::Card)
    pad = falses(PAD_MAP[c.count], 5)
    vcat(
        pad,
        [PIXEL_MAP[c.shape] for _ in 1:(Int(c.count)+1)]...,
        pad
    )
end

function render_card(c::Card, hl::Bool)::Panel
    lines = eachrow(get_pixels(c)[1:end-1, :])
    content = join(
        [join(map(b -> b ? CHAR_MAP[c.shade] : ' ', line))
        for line ∈ lines], '\n'
    )
    text = RenderableText(content, style="$(COLOR_MAP[c.color])")
    return Panel(text; fit=true, style=hl ? "gold1 bold" : "")
end

#TODO: Final column is stuck printed when board reduces in size 
function render_board(board::Vector{Card}, selected::BitVector)::Term.renderables.Renderable
    renderable_board = map(
        x -> render_card(x...), zip(board, selected)
    )
    rows = [
        reduce(*, row)
        for row in eachrow(reshape(renderable_board,(3,:)))
    ]
    reduce(/, rows)
    # Panel(reduce(/, rows), justify=:center)
end
render_board(board::Vector{Card}) = render_board(board, falses(length(board)))
render_board(ctx::GameContext) = render_board(ctx.board, ctx.selected)


function render_screen(ctx::GameContext)
    status = """
    Card in deck: $(length(ctx.deck))
    Sets found  : $(length(ctx.found))
    Time        : $(
        Dates.format(Time(Nanosecond(now() - ctx.start_time)), "MM:SS")
    )
    """
    board = render_board(ctx) 
    screen = Panel(status, justify=:center, width=24, height=board.measure.h) * board
    clear_screen(screen.measure)
    println(screen)
end

function clear_screen(measure::Term.measure.Measure)
    print("\033[$(measure.w)A")
    print("\033[$(measure.h)D")
end