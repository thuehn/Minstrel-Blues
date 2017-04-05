local thread = require ("thread")

function date_fun ()
    return
end

th = thread.create ( date_fun )
if ( th:alive () ) then
    th:resume ()
end
th:detach()
