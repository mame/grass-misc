#!/usr/bin/env ruby19

# yagc.rb - Translater from Grass to Ruby

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
#   $ ruby19 hello.rb; echo
#   Hello, world
#
# references:
#   grass: http://www.blue.sky.or.jp/grass/
#

require "erb"

# parse
code = $<.read
code = code.gsub("\uFF37", "W").gsub("\uFF57", "w").gsub("\uFF56", "v")
code = code.gsub(/[^wWv]/, "")
code = code[/w.*\z/m].split(/v/).map.with_index do |sub, i|
  sub = sub.scan(/w+|W+/)
  arity = sub.first[0] == "w" ? sub.shift.size : 0
  body = sub.each_slice(2).map {|n, m| [n.size - 1, m.size - 1] }
  [arity, body]
end

# emit
ERB.new(DATA.read, nil, "%").run(binding)

__END__
class Fixnum
  def [](x)
    (self == x ? ->(t, f) { t } : ->(t, f) { f }).curry
  end
end
_in = ->(x) { c = $stdin.getc; c ? c.ord : x }
_w = 119
_inc = ->(x) { x.succ }
_out = ->(x) { putc(x); x }

# start
% gstack, gname = %w(_out _inc _w _in), "g_0"
% code.each_with_index do |(arity, body), i|
% if arity > 0
%     gname = gname.succ
%     args = (1..arity).map {|i| "l_#{ i }" }
<%= gname %> = ->(<%= args.join(", ") %>) {
%     if body.empty?
  <%= args.last %>
%     else
%       lstack, lname = args.reverse + gstack, args.last
%       body.each_with_index do |(m, n), i|
%         lname = lname.succ
%         if i < body.size - 1
  <%= lname %> = <%= lstack[m] %>[<%= lstack[n] %>]
%         else
  <%= lstack[m] %>[<%= lstack[n] %>]
%         end
%         lstack.unshift(lname)
%       end
%     end
}.curry
%     gstack.unshift(gname)
%   else
%     body.each_with_index do |(m, n), i|
%       gname = gname.succ
<%= gname %> = <%= gstack[m] %>[<%= gstack[n] %>]
%       gstack.unshift(gname)
%     end
%   end
% end
# end

<%= gname %>[<%= gname %>]
