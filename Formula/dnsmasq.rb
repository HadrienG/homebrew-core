class Dnsmasq < Formula
  desc "Lightweight DNS forwarder and DHCP server"
  homepage "http://www.thekelleys.org.uk/dnsmasq/doc.html"
  url "http://www.thekelleys.org.uk/dnsmasq/dnsmasq-2.78.tar.gz"
  sha256 "c92e5d78aa6353354d02aabf74590d08980bb1385d8a00b80ef9bc80430aa1dc"

  bottle do
    sha256 "fa112cd1167d0375339fb1f42fa8b276af8ef926609d9cb4000da30cbc3dfc25" => :high_sierra
    sha256 "15494091216fa563b62795bab5445add7671ba8c503d1cf051a2d38056ebd7bd" => :sierra
    sha256 "a8edec8b6f7a08911809780906e52f7609eb3432e6a06e676ba0edd668de1735" => :el_capitan
  end

  option "with-libidn", "Compile with IDN support"
  option "with-dnssec", "Compile with DNSSEC support"

  deprecated_option "with-idn" => "with-libidn"

  depends_on "pkg-config" => :build
  depends_on "libidn" => :optional
  depends_on "gettext" if build.with? "libidn"
  depends_on "nettle" if build.with? "dnssec"

  def install
    ENV.deparallelize

    # Re-evaluate whether this is needed for dnsmasq > 2.77
    # Fix __memcpy_chk crash in strcpy(cache->name.sname, canon);
    # Reported 12 Jul 2017 to simon AT thekelleys DOT org DOT uk
    # See https://github.com/Homebrew/homebrew-core/issues/14463
    if MacOS.version >= :sierra
      inreplace "src/config.h", "#define SMALLDNAME 50 ",
                                "#define SMALLDNAME 255 "
    end

    # Fix etc location
    inreplace %w[dnsmasq.conf.example src/config.h man/dnsmasq.8
                 man/es/dnsmasq.8 man/fr/dnsmasq.8].each do |s|
      s.gsub! "/var/lib/misc/dnsmasq.leases",
              var/"lib/misc/dnsmasq/dnsmasq.leases", false
      s.gsub! "/etc/dnsmasq.conf", etc/"dnsmasq.conf", false
      s.gsub! "/var/run/dnsmasq.pid", var/"run/dnsmasq/dnsmasq.pid", false
      s.gsub! "/etc/dnsmasq.d", etc/"dnsmasq.d", false
      s.gsub! "/etc/ppp/resolv.conf", etc/"dnsmasq.d/ppp/resolv.conf", false
      s.gsub! "/etc/dhcpc/resolv.conf", etc/"dnsmasq.d/dhcpc/resolv.conf", false
      s.gsub! "/usr/sbin/dnsmasq", HOMEBREW_PREFIX/"sbin/dnsmasq", false
    end

    # Optional IDN support
    if build.with? "libidn"
      inreplace "src/config.h", "/* #define HAVE_IDN */", "#define HAVE_IDN"
      ENV.append_to_cflags "-I#{Formula["gettext"].opt_include}"
      ENV.append "LDFLAGS", "-L#{Formula["gettext"].opt_lib} -lintl"
    end

    # Optional DNSSEC support
    if build.with? "dnssec"
      inreplace "src/config.h", "/* #define HAVE_DNSSEC */", "#define HAVE_DNSSEC"
      inreplace "dnsmasq.conf.example" do |s|
        s.gsub! "#conf-file=%%PREFIX%%/share/dnsmasq/trust-anchors.conf",
                "conf-file=#{opt_pkgshare}/trust-anchors.conf"
        s.gsub! "#dnssec", "dnssec"
      end
    end

    # Fix compilation on Lion
    ENV.append_to_cflags "-D__APPLE_USE_RFC_3542" if MacOS.version >= :lion
    inreplace "Makefile" do |s|
      s.change_make_var! "CFLAGS", ENV.cflags
      s.change_make_var! "LDFLAGS", ENV.ldflags
    end

    if build.with? "libidn"
      system "make", "install-i18n", "PREFIX=#{prefix}"
    else
      system "make", "install", "PREFIX=#{prefix}"
    end

    pkgshare.install "trust-anchors.conf" if build.with? "dnssec"
    etc.install "dnsmasq.conf.example" => "dnsmasq.conf"
  end

  def post_install
    (var/"lib/misc/dnsmasq").mkpath
    (var/"run/dnsmasq").mkpath
    (etc/"dnsmasq.d/ppp").mkpath
    (etc/"dnsmasq.d/dhcpc").mkpath
  end

  def caveats; <<-EOS.undent
    To configure dnsmasq, take the default example configuration at
      #{etc}/dnsmasq.conf and edit to taste.
    EOS
  end

  plist_options :startup => true

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_sbin}/dnsmasq</string>
          <string>--keep-in-foreground</string>
          <string>-C</string>
          <string>#{etc}/dnsmasq.conf</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
      </dict>
    </plist>
    EOS
  end

  test do
    system "#{sbin}/dnsmasq", "--test"
  end
end
