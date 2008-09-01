#!/usr/bin/env ruby19

# braingrass.rb - brainfuck-grass translater

# Copyright (c) 2008 Yusuke ENDOH
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the author(s) nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

###

#
# example:
#   $ ruby19 braingrass.rb hello.bf > tmp.www
#   $ ruby19 yagi.rb tmp.www
#   Hello, world
#
# references:
#   brainfuck: http://en.wikipedia.org/wiki/Brainfuck
#   grass:     http://www.blue.sky.or.jp/grass/
#

### parse brainfuck code
stack, code = [], []
File.read(ARGV[0]).gsub(/[^+\-,.\[\]><]/, "").each_char do |insn|
  case insn
  when "[" then stack << (code << code = [])
  when "]" then code = stack.pop
  else code << insn
  end
end

### abstract syntax tree
App = Struct.new(:left, :right)
Let = Struct.new(:id, :body, :rest)
Func = Struct.new(:id, :args, :body)

### embedded functional programming language in ruby
#
#  E  ::=  X                                          # variable
#       |  [E, E, ..., E]                             # application
#       |  abs.call {|X1, X2, ..., Xn| E }            # lambda abstraction
#       |  let.call(E) {|X| E }                       # let
#
#  P  ::=  X = global.call {|X1, X2, ..., Xn| E }; P  # global function
#       |  global.call {|X| E }                       # main function
#

program = []
new_id = Enumerator.new {|g| i = 0; loop { g << "v#{ i += 1 }" } }

# application
app = ->(ns) do
  ns = ns.call while ns.is_a?(Proc)
  ns.is_a?(Array) ? ns.map {|n| app[n] }.inject {|z, n| App[z, n] } : ns
end

# let (with k-normalizing)
let = ->(n, &blk) do
  n = app[n]
  if n.is_a?(App)
    let.call(n.left) do |x|
      let.call(n.right) do |y|
        blk ? Let[z = new_id.next, App[x, y], let.call(blk[z])] : App[x, y]
      end
    end
  else
    blk ? blk[n] : n
  end
end

# lambda abstraction
abs = ->(&blk) do
  id, args = new_id.next, (0...blk.arity).map { new_id.next }
  program << Func[id, args, let.call(blk.call(*args))]
  id
end

# global function
global = ->(&blk) do
  id = abs.call(&blk)
  ->(*r) { [id] + r }
end

### global functions
# identity function
id = global.call {|x| x }

# fixed point operator (call-by-value)
fix2 = global.call {|f, x| [f, [abs.call {|x, y| [x, x, y] }, x]] }
fix = global.call {|f| [fix2[f], fix2[f]] }

# basic functions
const = global.call {|x, y| x }
drop  = global.call {|x, y| y }
seq = drop

# church boolean: true = \t -> \f -> t, false = \t -> \f -> f
btrue  = const
bfalse = drop

# church numeric: N = \s -> \z -> s (s (s ... (s z) ...))
succ = global.call {|x, s, z| [s, [x, s, z]] }
pred = global.call do |n, f, x|
  [n, [abs.call {|f, g, h| [h, [g, f]] }, f], [const, x], id]
end
zero = drop
notzero = global.call {|x| [x, [const, btrue], bfalse] }

# primitive functions
_in, _out, _inc, _w = [:IN, :OUT, :INC, :W].map {|i| ->(*r) { [i] + r } }

# high-level I/O functions
chr = global.call do |x|
  let.call(succ[succ[succ[zero]]]) do |n3|
    n135 = [abs.call {|n3, s| [n3, n3, [succ[succ[n3]], s]] }, n3] # 3**3*(3+2)
    c0 = [succ[succ[n135]], _inc, _w]  # 'w'(119) + 135 + 2 = '\0' (mod 256)
    [x, _inc, c0]
  end
end
putc = global.call {|x| _out[chr[x]] }
getc = global.call do |d|
  let.call(chr[zero]) do |c0|
    let.call(_in[c0]) do |v|
      fix[
        abs.call do |f, c, n, v|
          [[c, v], [const, n], [f, _inc[c], succ[n]], v]
        end,
        c0, zero, v]
    end
  end
end

# church triple: (x, y, z) = \f -> f x y z
tuple = global.call {|x, y, z, t| [t, x, y, z] }
fst = global.call {|t| [t, abs.call {|a, b, c| a }] }
snd = global.call {|t| [t, abs.call {|a, b, c| b }] }
thd = global.call {|t| [t, abs.call {|a, b, c| c }] }

# church list: [v, v, ...] = \c -> \n -> c v (c v (c v ... (c v n) ...))
null   = drop
cons   = global.call {|h, t, c, n| [c, h, [t, c, n]] }
isnull = global.call {|l| [l, [const, [const, bfalse]], btrue] }
head   = global.call {|l| [l, btrue, null] }
tail   = global.call do |l|
  [l,
   abs.call {|h, t, f| [f, [t, null], cons[h, [t, null]]] },
   abs.call {|f| [f, null, null] },
   const]
end

# zipper functions
get = snd
set = global.call {|a, b| tuple[fst[b], a, thd[b]] }
right = global.call do |a|
  [isnull[thd[a]],
   abs.call {|a| tuple[cons[snd[a], fst[a]], zero, null] },
   abs.call {|a| tuple[cons[snd[a], fst[a]], head[thd[a]], tail[thd[a]]] },
   a]
end
left = global.call do |a|
  let.call(right[tuple[thd[a], snd[a], fst[a]]]) do |b|
    tuple[thd[b], snd[b], fst[b]]
  end
end

# main function
global.call do |dummy|
  build = ->(state, code, &blk) do
    if code.empty?
      app[blk[state]]
    else
      let.call(
        case insn = code.first
        when "+" then set[succ[get[state]], state]
        when "-" then set[pred[get[state]], state]
        when "," then set[getc[get[state]], state]
        when "." then seq[putc[get[state]], state]
        when "<" then left [state]
        when ">" then right[state]
        when Array
          rec = new_id.next
          fix[
            abs.call do |f, a|
              [notzero[get[a]],
               [abs.call {|f, a| build.call(a, insn) {|ret| [f, ret] } }, f],
               id,
               a]
            end,
            state]
        end
      ) {|state| build.call(state, code.drop(1), &blk) }
    end
  end
  let.call(tuple[null, zero, null]) {|s| build.call(s, code) {|r| r } }
end

### rename variables as de Bruijn Index
debruijn = ->(s, n) do
  case n
  when Let
    l, r = s.index(n.body.left), s.index(n.body.right)
    # optimization: caching value which is far on stack
    if l > 15 # && false
      if n.body.left == app[id]
        i = s.index(app[id])
        [[i, i]] + debruijn.call([app[id]] + s, n)
      else
        debruijn.call(s, Let[n.body.left, app[[id, n.body.left]], n])
      end
    else
      [[l, r]] + debruijn.call([n.id] + s, n.rest)
    end
  when App
    [[s.index(n.left) || raise, s.index(n.right) || raise]]
  else
    s.index(n) == 0 ? [] : debruijn.call(s, app[[id, n]])
  end
end
stack = [:OUT, :INC, :W, :IN]
program = program.map do |func|
  s = func.args.reverse + stack
  stack = [func.id] + stack
  Func[func.id, func.args.size, debruijn.call(s, func.body)]
end

### emit grass code
code = program.map do |func|
  "w" * func.args + func.body.map {|m, n| "W" * (m + 1) + "w" * (n + 1) }.join
end.join("v")
puts code.scan(/.{79}|.*$/)
