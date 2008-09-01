#!/usr/bin/env ruby19

# yagi.rb - yet another grass interpreter

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
#   $ ruby19 yagi.rb hello.www
#   Hello, world
#
# references:
#   grass:     http://www.blue.sky.or.jp/grass/
#

# parse
A, L = Struct.new(:m, :n), Struct.new(:code)
code = File.read(ARGV[0])
code = code.gsub("\uFF37", "W").gsub("\uFF57", "w").gsub("\uFF56", "v")
code = code.gsub(/[^wWv]/, "")
code = code[/w.*\z/m].split(/v/).map do |sub|
  sub = sub.scan(/w+|W+/)
  arity = sub.first[0] == "w" ? sub.shift.size : 0
  sub = sub.each_slice(2).map {|n, m| A[n.size - 1, m.size - 1] }
  arity.times { sub = [L[sub]] }
  sub
end.flatten(1)

# eval
eval = ->(code, env) do
  ctrue = ->(arg) { eval[[L[[A[2, 1]]]], [arg, ->(arg) { eval[[], [arg]] }]] }
  cfalse = ->(arg) { eval[[L[[]]], [arg]] }
  code.inject(env) do |env, insn|
    val = case insn
    when A
      clos, arg = env[insn.m], env[insn.n]
      case clos
      when Proc   then clos[arg]
      when Fixnum then clos == arg ? ctrue : cfalse
      when :out   then putc(arg); arg
      when :in    then ch = $stdin.getc; ch ? ch.ord : arg
      when :succ  then arg.succ & 0xff
      end
    when L
      ->(arg) { eval[insn.code, [arg] + env] }
    end
    [val] + env
  end.first
end
eval[[], [eval[[A[0, 0]], [eval[code, [:out, :succ, "w".ord, :in]]]]]]
