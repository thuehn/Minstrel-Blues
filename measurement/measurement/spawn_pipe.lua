require ("ex")

-- spawns process with pipes to stdin, stdout and stderr
-- returns table with 
--   1. struct with process, pid and life cycle state
--   2. pipes
--   3. error
-- exit code with process:wait()
function spawn_pipe(...)
    local in_rd, in_wr = io.pipe()
    local out_rd, out_wr = io.pipe()
    local err_rd, err_wr = io.pipe()
    local proc, err = os.spawn{stdin = in_rd, stdout = out_wr, stderr = err_wr, ...}
    in_rd:close(); out_wr:close(); err_wr:close()
    if not proc then
        in_wr:close(); out_rd:close(); err_rd:close()
    end
    local ret = {}
    ret['proc'] = proc
    ret['err_msg'] = err
    ret['out'] = out_rd
    ret['in'] = in_wr
    ret['err'] = err_rd
    return ret
end

function close_proc_pipes ( proc )
    if ( proc ~= nil ) then
        proc['out']:close()
        proc['in']:close()
        proc['err']:close()
    end
end

-- spawns two piped processes with pipe to stdin of fst and stdout of snd 
-- returns two tables with 
--   1. struct with process, pid and life cycle state
--   2. pipes
--   3. error
-- exit code with process:wait()
--   note: close out of fst and in of snd before waiting for snd
-- todo: err connected?
function spawn_pipe2(fst, snd)
    local in_rd, in_wr = io.pipe()
    local out_rd, out_wr = io.pipe()
    local err1_rd, err1_wr = io.pipe()
    local err2_rd, err2_wr = io.pipe()
    local pipe_rd, pipe_wr = io.pipe()

    local cmd1 = {stdin = in_rd, stdout = pipe_wr, stderr = err1_wr}
    for _, p in ipairs ( fst ) do
        cmd1[#cmd1 + 1] = p
    end

    local cmd2 = {stdin = pipe_rd, stdout = out_wr, stderr = err2_wr}
    for _, p in ipairs ( snd ) do
        cmd2[#cmd2 + 1] = p
    end

    local proc1, err1 = os.spawn(cmd1)
    local proc2, err2 = os.spawn(cmd2)
    in_rd:close(); out_wr:close(); err1_wr:close(); err2_wr:close()

    if not proc1 or not proc2 then
        in_wr:close(); out_rd:close()
        pipe_rd:close(); pipe_wr:close()
        err1_rd:close(); err2:rd_close()
    end

    local ret1 = {}
    ret1['proc'] = proc1
    ret1['err_msg'] = err1
    ret1['in'] = in_wr
    ret1['out'] = pipe_rd
    ret1['err'] = err1_rd

    local ret2 = {}
    ret2['proc'] = proc2
    ret2['err_msg'] = err2
    ret2['out'] = out_rd
    ret2['in'] = pipe_wr
    ret2['err'] = err2_rd

    return ret1, ret2
end

-- NOTE: when using lua interpreter 
--       local vars (for in_rd, in_wr, out_rd, out_wr, ...)
--       will not work (becomes nil)
