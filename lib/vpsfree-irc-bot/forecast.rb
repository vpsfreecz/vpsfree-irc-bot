require 'net/http'
require 'json'

module VpsFree::Irc::Bot
  class Forecast
    include Cinch::Plugin
    include Command

    timer 0, method: :setup, threaded: false, shots: 1
    command :forecast do
      arg :city, required: true
      desc 'weather forecast'
      channel false
      help false
    end

    class << self
      attr_accessor :api_key

      def get(city)
        res = Net::HTTP.get(
            'api.openweathermap.org',
            "/data/2.5/weather?q=#{city}&APPID=#{api_key}"
        )
        JSON.parse(res, symbolize_names: true)
      end

      def as_text(city)
        data = get(city)

        ret = "#{data[:name]} (#{data[:sys][:country]}): "
        ret << "#{data[:weather].first[:description]}, "
        ret << "#{(data[:main][:temp] - 273.15).round(1)} °C, "
        ret << "wind #{data[:wind][:speed]} m/s (#{wind_dir(data[:wind][:deg])}), "
        ret << "humidity #{data[:main][:humidity]} %, "
        ret << "cloudiness #{data[:clouds][:all]} %"
        ret
      end

      def wind_dir(degrees)
        v = ((degrees / 22.5) + 0.5).to_i
        %w(N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW)[v % 16]
      end
    end

    def setup
      self.class.api_key = config[:api_key]
    end

    def cmd_forecast(m, channel, city)
      m.reply(self.class.as_text(city))
    end
  end
end
