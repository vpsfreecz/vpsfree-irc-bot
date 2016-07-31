module VpsFree::Irc::Bot
  class MultiLine < ::String
    include ::Enumerable

    def each
      lines = split("\n")
      cnt = lines.count
      digits = cnt.to_s.size

      lines.each_with_index do |line, i|
        yield(sprintf("[%0#{digits}d/%d] %s", i+1, cnt, line))
      end
    end

    def to_s
      to_a.join("\n")
    end
  end
end
