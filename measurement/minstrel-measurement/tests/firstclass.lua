
function f ( a )
    return function ( b ) return a + b end
end

local f1 = f ( 1 )

print ( f1 ( 2 ) )

function g ( f, b )
    local f1 = f ( 1 )
    return f1 ( b )
end

print ( g ( f, 2 ) )
