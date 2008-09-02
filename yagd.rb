#!/usr/bin/env ruby19

# yagd.rb - Assembler for Grass

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
#   $ ruby19 yagc.rb hello.www > hello.rb
#   $ ruby19 yagd.rb hello.rb > hello2.www
#   $ ruby19 yagi.rb hello2.www; echo
#   Hello, world
#
# references:
#   grass: http://www.blue.sky.or.jp/grass/
#

code = ""
gstack = lstack = %w(_out _inc _w _in)
delim = true
unless $<.read[/^#\s*start\s*$\n(.*)#\s*end\s*$\n/m]
  raise "illegal format"
end
num = $`.count("\n") + 1
$1.each_line do |line|
  num += 1
  case line
  when /^(\w+)\s*=\s*->\(([\w\s,]+)\)\s*\{\s*(?:#|$)/
    gname, args = $1, $2.split(/\s*,\s*/)
    lstack = lstack.dup
    args.each {|a| lstack.unshift(a) }
    gstack.unshift(gname)
    code << "v" unless delim
    code << "w" * args.size
    delim = false
  when /^}\.curry\s*(?:#|$)/
    lstack = gstack
    code << "v"
    delim = true
  when /^\s*(?:(\w+)\s*=\s*)?(\w+)\[(\w+)\]\s*(?:#|$)/
    l, r = lstack.index($2), lstack.index($3)
    raise "line #{ num }: unknown variable : #{ $2 }" unless l
    raise "line #{ num }: unknown variable : #{ $3 }" unless r
    code << "W" * l.succ << "w" * r.succ
    lstack.unshift($1)
    delim = false
  when /^\s*(\w+)\s*(?:#|$)/
  else
    raise "line #{ num }: illegal line : #{ line }"
  end
end
puts code
