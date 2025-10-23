{
  activesupport = {
    dependencies = ["base64" "bigdecimal" "concurrent-ruby" "connection_pool" "drb" "i18n" "json" "logger" "minitest" "securerandom" "tzinfo" "uri"];
  };
  base64 = {
  };
  bigdecimal = {
  };
  chronic_duration = {
    dependencies = ["numerizer"];
  };
  concurrent-ruby = {
  };
  connection_pool = {
  };
  date = {
  };
  domain_name = {
  };
  drb = {
  };
  grinch = {
  };
  haveapi-client = {
    dependencies = ["activesupport" "highline" "json" "require_all" "rest-client" "ruby-progressbar"];
  };
  highline = {
    dependencies = ["reline"];
  };
  htmlentities = {
  };
  http-accept = {
  };
  http-cookie = {
    dependencies = ["domain_name"];
  };
  i18n = {
    dependencies = ["concurrent-ruby"];
  };
  io-console = {
  };
  json = {
  };
  logger = {
  };
  mail = {
    dependencies = ["logger" "mini_mime" "net-imap" "net-pop" "net-smtp"];
  };
  mime-types = {
    dependencies = ["logger" "mime-types-data"];
  };
  mime-types-data = {
  };
  mini_mime = {
  };
  mini_portile2 = {
  };
  minitest = {
  };
  mustermann = {
    dependencies = ["ruby2_keywords"];
  };
  net-imap = {
    dependencies = ["date" "net-protocol"];
  };
  net-pop = {
    dependencies = ["net-protocol"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1wyz41jd4zpjn0v1xsf9j778qx1vfrl24yc20cpmph8k42c4x2w4";
      type = "gem";
    };
    version = "0.1.2";
  };
  net-protocol = {
    dependencies = ["timeout"];
  };
  net-smtp = {
    dependencies = ["net-protocol"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0dh7nzjp0fiaqq1jz90nv4nxhc2w359d7c199gmzq965cfps15pd";
      type = "gem";
    };
    version = "0.5.1";
  };
  netrc = {
  };
  nio4r = {
  };
  nokogiri = {
    dependencies = ["mini_portile2" "racc"];
  };
  numerizer = {
  };
  puma = {
    dependencies = ["nio4r"];
  };
  racc = {
  };
  rack = {
  };
  rack-protection = {
    dependencies = ["base64" "logger" "rack"];
  };
  rack-session = {
    dependencies = ["base64" "rack"];
  };
  rackup = {
    dependencies = ["rack"];
  };
  rake = {
  };
  reline = {
    dependencies = ["io-console"];
  };
  require_all = {
  };
  rest-client = {
    dependencies = ["http-accept" "http-cookie" "mime-types" "netrc"];
  };
  reverse_markdown = {
    dependencies = ["nokogiri"];
  };
  rexml = {
  };
  rinku = {
  };
  ruby-progressbar = {
  };
  ruby2_keywords = {
  };
  securerandom = {
  };
  sinatra = {
    dependencies = ["logger" "mustermann" "rack" "rack-protection" "rack-session" "tilt"];
  };
  tilt = {
  };
  timeout = {
  };
  tzinfo = {
    dependencies = ["concurrent-ruby"];
  };
  uri = {
  };
  webrick = {
  };
  xmlrpc = {
    dependencies = ["webrick"];
  };
}
